unit uRBAC;

{
  SmartOffice Desktop - Role Based Access Control (RBAC).

  Provides authentication (login), roles, module-level permissions and the
  current user session. Tables are bootstrapped automatically:
    roles              - role definitions (ADMIN, PETUGAS, ...)
    role_permissions   - per-role access rights per module
    users              - application users bound to a role

  Every check is default-deny: a module is only accessible when the current
  role holds a matching grant. The ADMIN role is a superuser (always allowed).
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqldb, uDB;

const
  RBACSalt = 'SmartOffice::1.0::';
  PBKDF2Prefix = 'pbkdf2-sha1$';
  PBKDF2Iterations = 10000;

type
  TRBACUser = record
    UserId: Integer;
    Username: string;
    FullName: string;
    RoleId: Integer;
    RoleName: string;
    RoleCode: string;
  end;

  TRBACModuleDef = record
    Key: string;
    Title: string;
  end;

const
  RBACModuleList: array[0..6] of TRBACModuleDef = (
    (Key: 'dashboard';    Title: 'Dashboard'),
    (Key: 'pendaftaran';  Title: 'Pendaftaran'),
    (Key: 'perawat';      Title: 'Perawat'),
    (Key: 'employees';    Title: 'Pegawai'),
    (Key: 'settings';     Title: 'Pengaturan'),
    (Key: 'rbac';         Title: 'Hak Akses'),
    (Key: 'apps';         Title: 'Manajemen Aplikasi')
  );

type
  TRBACService = class
  private
    FDB: TDatabaseManager;
    FUser: TRBACUser;
    FLoggedIn: Boolean;
    FSessionToken: string;
    FModules: TStringList;   // lowercase module ids (can view)
    FCreate: TStringList;
    FEdit: TStringList;
    FDelete: TStringList;
    FLoginFails: Integer;
    FLockUntil: TDateTime;
    FLastError: string;
    procedure LoadGrants(ARoleId: Integer);
    procedure SeedIfEmpty;
    function VerifyPassword(const AStored, APassword: string): Boolean;
    procedure UpgradePassword(AUserId: Integer; const ANewPassword: string);
  public
    constructor Create(ADB: TDatabaseManager);
    destructor Destroy; override;

    procedure EnsureSchema;
    function HashPassword(const AValue: string): string;

    function Login(const AUsername, APassword: string): Boolean;
    function LoginWithToken(const AUsername, AToken: string): Boolean;
    function LoginDev: Boolean;
    function CreateSession: string;
    procedure RevokeSession;
    procedure Logout;
    procedure RefreshPermissions;

    // Sliding-session support: pushes the current session's expiry forward
    // (idle timeout) and deletes expired sessions from the sessions table.
    procedure TouchSession;
    procedure PurgeExpiredSessions;

    function IsAdmin: Boolean;
    function IsLoggedIn: Boolean;
    function CanView(const AModule: string): Boolean;
    function CanAccess(const AModule: string): Boolean;
    function CanCreate(const AModule: string): Boolean;
    function CanEdit(const AModule: string): Boolean;
    function CanDelete(const AModule: string): Boolean;

    property User: TRBACUser read FUser;
    property Username: string read FUser.Username;
    property FullName: string read FUser.FullName;
    property RoleName: string read FUser.RoleName;
    property SessionToken: string read FSessionToken;
    property LastError: string read FLastError;
  end;

var
  RBAC: TRBACService = nil;

implementation

uses
  sha1, hmac;

{ TRBACService }

constructor TRBACService.Create(ADB: TDatabaseManager);
begin
  inherited Create;
  FDB := ADB;
  FModules := TStringList.Create;
  FCreate := TStringList.Create;
  FEdit := TStringList.Create;
  FDelete := TStringList.Create;
end;

destructor TRBACService.Destroy;
begin
  FDelete.Free;
  FEdit.Free;
  FCreate.Free;
  FModules.Free;
  inherited Destroy;
end;

{ --- password helpers -------------------------------------------------------- }

function HexEncode(const ABytes: string): string;
const
  HexChars = '0123456789abcdef';
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(ABytes) do
    Result := Result +
      HexChars[((Ord(ABytes[I]) shr 4) and $0F) + 1] +
      HexChars[(Ord(ABytes[I]) and $0F) + 1];
end;

function NewSalt: string;
var
  g: TGUID;
  s: string;
begin
  CreateGUID(g);
  s := GUIDToString(g);
  s := StringReplace(s, '{', '', [rfReplaceAll]);
  s := StringReplace(s, '}', '', [rfReplaceAll]);
  s := StringReplace(s, '-', '', [rfReplaceAll]);
  Result := LowerCase(s);
end;

// PBKDF2-HMAC-SHA1 (RFC 2898), dkLen = 20 bytes.
function PBKDF2_HMAC_SHA1(const APassword, ASalt: string;
  AIterations, ADkLen: Integer): string;
var
  U, T, Block, Dk: string;
  Digest: TSHA1Digest;
  I, J, B: Integer;
begin
  Dk := '';
  B := 1;
  while Length(Dk) < ADkLen do
  begin
    SetLength(Block, Length(ASalt) + 4);
    if Length(ASalt) > 0 then
      Move(ASalt[1], Block[1], Length(ASalt));
    Block[Length(ASalt) + 1] := Chr((B shr 24) and $FF);
    Block[Length(ASalt) + 2] := Chr((B shr 16) and $FF);
    Block[Length(ASalt) + 3] := Chr((B shr 8) and $FF);
    Block[Length(ASalt) + 4] := Chr(B and $FF);
    Digest := HMACSHA1Digest(APassword, Block);
    SetLength(U, 20);
    Move(Digest[0], U[1], 20);
    T := U;
    for I := 2 to AIterations do
    begin
      Digest := HMACSHA1Digest(APassword, U);
      Move(Digest[0], U[1], 20);
      for J := 1 to 20 do
        T[J] := Chr(Ord(T[J]) xor Ord(U[J]));
    end;
    Dk := Dk + T;
    Inc(B);
  end;
  SetLength(Dk, ADkLen);
  Result := Dk;
end;

function TRBACService.HashPassword(const AValue: string): string;
var
  Salt, Dk: string;
begin
  Salt := NewSalt;
  Dk := PBKDF2_HMAC_SHA1(AValue, Salt, PBKDF2Iterations, 20);
  Result := PBKDF2Prefix + IntToStr(PBKDF2Iterations) + '$' + Salt + '$' + HexEncode(Dk);
end;

function TRBACService.VerifyPassword(const AStored, APassword: string): Boolean;
var
  Rest, Salt, Dk: string;
  Iter, P: Integer;
begin
  Result := False;
  if Copy(AStored, 1, Length(PBKDF2Prefix)) = PBKDF2Prefix then
  begin
    // New PBKDF2 format:  pbkdf2-sha1$<iter>$<salt>$<hex>
    Rest := Copy(AStored, Length(PBKDF2Prefix) + 1, MaxInt);
    P := Pos('$', Rest);
    if P <= 0 then Exit;
    Iter := StrToIntDef(Copy(Rest, 1, P - 1), 0);
    Rest := Copy(Rest, P + 1, MaxInt);
    P := Pos('$', Rest);
    if P <= 0 then Exit;
    Salt := Copy(Rest, 1, P - 1);
    Dk := Copy(Rest, P + 1, MaxInt);
    if Iter <= 0 then Exit;
    Result := SameText(HexEncode(PBKDF2_HMAC_SHA1(APassword, Salt, Iter, 20)), Dk);
  end
  else
    // Legacy pre-1.1 format: plain SHA1(static-salt || password)
    Result := SameText(AStored, SHA1Print(SHA1String(RBACSalt + APassword)));
end;

procedure TRBACService.UpgradePassword(AUserId: Integer; const ANewPassword: string);
var
  q: TSQLQuery;
begin
  q := FDB.NewQuery('update users set password=:p where id=:id');
  try
    q.Params.ParamByName('p').AsString := HashPassword(ANewPassword);
    q.Params.ParamByName('id').AsInteger := AUserId;
    if not FDB.Transaction.Active then
      FDB.Transaction.StartTransaction;
    q.ExecSQL;
    FDB.Transaction.Commit;
  except
    // upgrade is best-effort; old hash stays valid otherwise. Always roll
    // back so a failure does not poison the shared transaction.
    if FDB.Transaction.Active then
      FDB.Transaction.Rollback;
  end;
  q.Free;
end;

procedure TRBACService.EnsureSchema;
var
  DDL: string;
begin
  if (FDB = nil) or (not FDB.Connected) then
    Exit;
  // Fast path: on every module startup the schema already exists (the launcher
  // or the first process created it). One cheap metadata query avoids ~15
  // bootstrap round-trips (DDL + seed) per launch.
  if FDB.SchemaReady then
    Exit;
  // Run every DDL + seed statement inside ONE transaction: schema bootstrap is
  // ~8 round-trips; committing once instead of per statement is much faster.
  if not FDB.Transaction.Active then
    FDB.Transaction.StartTransaction;
  try
  if FDB.Kind = dbPostgreSQL then
    DDL :=
      'create table if not exists roles (' +
      ' id serial primary key,' +
      ' kode varchar(30) unique not null,' +
      ' nama varchar(80) not null,' +
      ' keterangan varchar(255))'
  else
    DDL :=
      'create table if not exists roles (' +
      ' id integer primary key autoincrement,' +
      ' kode varchar(30) unique not null,' +
      ' nama varchar(80) not null,' +
      ' keterangan varchar(255))';
  FDB.ExecSQLNoCommit(DDL);

  if FDB.Kind = dbPostgreSQL then
    DDL :=
      'create table if not exists role_permissions (' +
      ' id serial primary key,' +
      ' role_id integer not null,' +
      ' module_id varchar(40) not null,' +
      ' can_view boolean not null default true,' +
      ' can_create boolean not null default false,' +
      ' can_edit boolean not null default false,' +
      ' can_delete boolean not null default false,' +
      ' unique(role_id, module_id))'
  else
    DDL :=
      'create table if not exists role_permissions (' +
      ' id integer primary key autoincrement,' +
      ' role_id integer not null,' +
      ' module_id varchar(40) not null,' +
      ' can_view integer not null default 1,' +
      ' can_create integer not null default 0,' +
      ' can_edit integer not null default 0,' +
      ' can_delete integer not null default 0,' +
      ' unique(role_id, module_id))';
  FDB.ExecSQLNoCommit(DDL);

  if FDB.Kind = dbPostgreSQL then
    DDL :=
      'create table if not exists users (' +
      ' id serial primary key,' +
      ' username varchar(50) unique not null,' +
      ' password varchar(255) not null,' +
      ' full_name varchar(120),' +
      ' role_id integer not null,' +
      ' aktif boolean not null default true)'
  else
    DDL :=
      'create table if not exists users (' +
      ' id integer primary key autoincrement,' +
      ' username varchar(50) unique not null,' +
      ' password varchar(255) not null,' +
      ' full_name varchar(120),' +
      ' role_id integer not null,' +
      ' aktif integer not null default 1)';
  FDB.ExecSQLNoCommit(DDL);

  // Migration: legacy installs created users.password as varchar(64), which is
  // too small for PBKDF2 hashes (~75 chars). Widen it (idempotent; ExecSQL
  // swallows "already exists" style errors).
  if FDB.Kind = dbPostgreSQL then
    FDB.ExecSQLNoCommit('alter table users alter column password type varchar(255)');

  if FDB.Kind = dbPostgreSQL then
    DDL :=
      'create table if not exists sessions (' +
      ' id serial primary key,' +
      ' token varchar(64) unique not null,' +
      ' user_id integer not null,' +
      ' username varchar(50),' +
      ' created_at timestamp default now(),' +
      ' expires_at timestamp not null)'
  else
    DDL :=
      'create table if not exists sessions (' +
      ' id integer primary key autoincrement,' +
      ' token varchar(64) unique not null,' +
      ' user_id integer not null,' +
      ' username varchar(50),' +
      ' created_at datetime default (datetime(''now'')),' +
      ' expires_at datetime not null)';
  FDB.ExecSQLNoCommit(DDL);

  // External applications (EXE) managed through the "Manajemen Aplikasi" module.
  if FDB.Kind = dbPostgreSQL then
    DDL :=
      'create table if not exists apps (' +
      ' id serial primary key,' +
      ' app_id varchar(40) unique not null,' +
      ' title varchar(80) not null,' +
      ' description varchar(255),' +
      ' category varchar(40) not null default ''Umum'',' +
      ' exe_file varchar(255) not null,' +
      ' sort_order integer not null default 0,' +
      ' is_active boolean not null default true)'
  else
    DDL :=
      'create table if not exists apps (' +
      ' id integer primary key autoincrement,' +
      ' app_id varchar(40) unique not null,' +
      ' title varchar(80) not null,' +
      ' description varchar(255),' +
      ' category varchar(40) not null default ''Umum'',' +
      ' exe_file varchar(255) not null,' +
      ' sort_order integer not null default 0,' +
      ' is_active integer not null default 1)';
  FDB.ExecSQLNoCommit(DDL);

  // Audit trail.
  if FDB.Kind = dbPostgreSQL then
    DDL :=
      'create table if not exists audit_log (' +
      ' id serial primary key,' +
      ' user_id integer,' +
      ' username varchar(50),' +
      ' action varchar(20) not null,' +
      ' entity varchar(40) not null,' +
      ' entity_id integer,' +
      ' detail varchar(500),' +
      ' created_at timestamp default now())'
  else
    DDL :=
      'create table if not exists audit_log (' +
      ' id integer primary key autoincrement,' +
      ' user_id integer,' +
      ' username varchar(50),' +
      ' action varchar(20) not null,' +
      ' entity varchar(40) not null,' +
      ' entity_id integer,' +
      ' detail varchar(500),' +
      ' created_at datetime default (datetime(''now'')))';
  FDB.ExecSQLNoCommit(DDL);

  SeedIfEmpty;
  FDB.Transaction.Commit;
  except
    on E: Exception do
    begin
      if FDB.Transaction.Active then
        FDB.Transaction.Rollback;
    end;
  end;
end;

procedure TRBACService.SeedIfEmpty;
var
  q: TSQLQuery;
  EmptyRoles, EmptyPerms, EmptyUsers, EmptyApps: Boolean;
  H1, H2, T, F: string;
  I: Integer;
begin
  if (FDB = nil) or (not FDB.Connected) then
    Exit;

  if FDB.Kind = dbPostgreSQL then
  begin
    T := 'true';
    F := 'false';
  end
  else
  begin
    T := '1';
    F := '0';
  end;

  q := FDB.NewQuery('select count(*) as c from roles');
  try
    q.Open;
    EmptyRoles := q.FieldByName('c').AsInteger = 0;
  finally
    q.Free;
  end;

  q := FDB.NewQuery('select count(*) as c from role_permissions');
  try
    q.Open;
    EmptyPerms := q.FieldByName('c').AsInteger = 0;
  finally
    q.Free;
  end;

  q := FDB.NewQuery('select count(*) as c from users');
  try
    q.Open;
    EmptyUsers := q.FieldByName('c').AsInteger = 0;
  finally
    q.Free;
  end;

  q := FDB.NewQuery('select count(*) as c from apps');
  try
    q.Open;
    EmptyApps := q.FieldByName('c').AsInteger = 0;
  finally
    q.Free;
  end;

  if EmptyRoles then
  begin
    FDB.ExecSQLNoCommit(
      'insert into roles (kode, nama, keterangan) values ' +
      '(''ADMIN'', ''Administrator'', ''Akses penuh ke semua modul''), ' +
      '(''PETUGAS'', ''Petugas'', ''Akses terbatas untuk operasional'')');
  end;

  if EmptyPerms then
  begin
    for I := 0 to High(RBACModuleList) do
      FDB.ExecSQLNoCommit(Format(
        'insert into role_permissions (role_id, module_id, can_view, can_create, can_edit, can_delete) ' +
        'select id, %s, %s, %s, %s, %s from roles where kode=''ADMIN''',
        [QuotedStr(RBACModuleList[I].Key), T, T, T, T]));
    FDB.ExecSQLNoCommit(Format(
      'insert into role_permissions (role_id, module_id, can_view, can_create, can_edit, can_delete) ' +
      'select id, %s, %s, %s, %s, %s from roles where kode=''PETUGAS''',
      [QuotedStr('dashboard'), T, F, F, F]));
    FDB.ExecSQLNoCommit(Format(
      'insert into role_permissions (role_id, module_id, can_view, can_create, can_edit, can_delete) ' +
      'select id, %s, %s, %s, %s, %s from roles where kode=''PETUGAS''',
      [QuotedStr('pendaftaran'), T, T, T, T]));
    FDB.ExecSQLNoCommit(Format(
      'insert into role_permissions (role_id, module_id, can_view, can_create, can_edit, can_delete) ' +
      'select id, %s, %s, %s, %s, %s from roles where kode=''PETUGAS''',
      [QuotedStr('perawat'), T, T, T, T]));
    FDB.ExecSQLNoCommit(Format(
      'insert into role_permissions (role_id, module_id, can_view, can_create, can_edit, can_delete) ' +
      'select id, %s, %s, %s, %s, %s from roles where kode=''PETUGAS''',
      [QuotedStr('employees'), T, F, F, F]));
  end;

  if EmptyUsers then
  begin
    H1 := HashPassword('admin123');
    H2 := HashPassword('petugas123');
    FDB.ExecSQLNoCommit(Format(
      'insert into users (username, password, full_name, role_id, aktif) ' +
      'select %s, %s, %s, id, %s from roles where kode=''ADMIN''',
      [QuotedStr('admin'), QuotedStr(H1), QuotedStr('Administrator'), T]));
    FDB.ExecSQLNoCommit(Format(
      'insert into users (username, password, full_name, role_id, aktif) ' +
      'select %s, %s, %s, id, %s from roles where kode=''PETUGAS''',
      [QuotedStr('petugas'), QuotedStr(H2), QuotedStr('Petugas Frontdesk'), T]));
  end;

  if EmptyApps then
  begin
    FDB.ExecSQLNoCommit(
      'insert into apps (app_id, title, description, category, exe_file, sort_order, is_active) values ' +
      '(''dashboard'', ''Dashboard'', ''Ringkasan pasien dan grafik pendaftaran'', ''Umum'', ''SIMRS-Dashboard.exe'', 1, ' + T + '), ' +
      '(''pendaftaran'', ''Pendaftaran'', ''Registrasi pasien dan pelayanan'', ''Aplikasi'', ''SIMRS-Pendaftaran.exe'', 2, ' + T + '), ' +
      '(''perawat'', ''Perawat'', ''Asuhan keperawatan dan tindakan'', ''Aplikasi'', ''SIMRS-Perawat.exe'', 3, ' + T + '), ' +
      '(''employees'', ''Pegawai'', ''Data pegawai dan sumber daya manusia'', ''Sumber Daya'', ''SIMRS-Employees.exe'', 4, ' + T + '), ' +
      '(''settings'', ''Pengaturan'', ''Konfigurasi koneksi database dan aplikasi'', ''Sistem'', ''SIMRS-Settings.exe'', 5, ' + T + '), ' +
      '(''rbac'', ''Hak Akses'', ''Manajemen peran dan hak akses pengguna'', ''Sistem'', ''SIMRS-RBAC.exe'', 6, ' + T + '), ' +
      '(''apps'', ''Manajemen Aplikasi'', ''Kelola daftar aplikasi EXE (tambah, ubah, hapus)'', ''Sistem'', ''SIMRS-Apps.exe'', 7, ' + T + ')');
  end;
end;

procedure TRBACService.LoadGrants(ARoleId: Integer);
var
  q: TSQLQuery;
  M: string;
begin
  FModules.Clear;
  FCreate.Clear;
  FEdit.Clear;
  FDelete.Clear;
  q := FDB.NewQuery(
    'select module_id, can_view, can_create, can_edit, can_delete ' +
    'from role_permissions where role_id=:role_id');
  try
    q.Params.ParamByName('role_id').AsInteger := ARoleId;
    q.Open;
    while not q.EOF do
    begin
      M := LowerCase(q.FieldByName('module_id').AsString);
      if q.FieldByName('can_view').AsBoolean then
        FModules.Add(M);
      if q.FieldByName('can_create').AsBoolean then
        FCreate.Add(M);
      if q.FieldByName('can_edit').AsBoolean then
        FEdit.Add(M);
      if q.FieldByName('can_delete').AsBoolean then
        FDelete.Add(M);
      q.Next;
    end;
  finally
    q.Free;
  end;
end;

function TRBACService.Login(const AUsername, APassword: string): Boolean;
var
  q: TSQLQuery;
  StoredHash: string;
  UserId: Integer;
begin
  Result := False;
  FLastError := '';
  Logout;
  if (FDB = nil) or (not FDB.Connected) then
  begin
    FLastError := 'Database tidak terhubung.';
    Exit;
  end;
  // Brute-force protection: 5 failed attempts -> 60 second lockout.
  if Now < FLockUntil then
  begin
    FLastError := 'Terlalu banyak percobaan gagal. Coba lagi dalam beberapa saat.';
    Exit;
  end;
  q := FDB.NewQuery(
    'select u.id, u.username, u.full_name, u.aktif, u.password, ' +
    'r.id as role_id, r.nama as role_nama, r.kode as role_kode ' +
    'from users u join roles r on r.id = u.role_id ' +
    'where u.username=:username');
  try
    try
      q.Params.ParamByName('username').AsString := AUsername;
    q.Open;
    if q.EOF then
    begin
      Inc(FLoginFails);
      if FLoginFails >= 5 then
      begin
        FLockUntil := Now + (60 / 1440);
        FLoginFails := 0;
      end;
      Exit;
    end;
    if not q.FieldByName('aktif').AsBoolean then
      Exit;
    StoredHash := q.FieldByName('password').AsString;
    if not VerifyPassword(StoredHash, APassword) then
    begin
      Inc(FLoginFails);
      if FLoginFails >= 5 then
      begin
        FLockUntil := Now + (60 / 1440);
        FLoginFails := 0;
      end;
      Exit;
    end;
    FLoginFails := 0;
    UserId := q.FieldByName('id').AsInteger;
    FUser.UserId := UserId;
    FUser.Username := q.FieldByName('username').AsString;
    FUser.FullName := q.FieldByName('full_name').AsString;
    FUser.RoleId := q.FieldByName('role_id').AsInteger;
    FUser.RoleName := q.FieldByName('role_nama').AsString;
    FUser.RoleCode := q.FieldByName('role_kode').AsString;
    LoadGrants(FUser.RoleId);
    // Migrate legacy SHA1 hashes to PBKDF2 on first successful login.
    if Copy(StoredHash, 1, Length(PBKDF2Prefix)) <> PBKDF2Prefix then
      UpgradePassword(UserId, APassword);
    FLoggedIn := True;
    Result := True;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := False;
      end;
    end;
  finally
    q.Free;
  end;
end;

function TRBACService.LoginWithToken(const AUsername, AToken: string): Boolean;
var
  q: TSQLQuery;
begin
  Result := False;
  FLastError := '';
  Logout;
  if (FDB = nil) or (not FDB.Connected) then
  begin
    FLastError := 'Database tidak terhubung.';
    Exit;
  end;
  if Trim(AToken) = '' then
    Exit;
  if FDB.Kind = dbPostgreSQL then
    q := FDB.NewQuery(
      'select u.id, u.username, u.full_name, u.aktif, ' +
      'r.id as role_id, r.nama as role_nama, r.kode as role_kode ' +
      'from sessions s join users u on u.id = s.user_id ' +
      'join roles r on r.id = u.role_id ' +
      'where s.token=:token and s.username=:username and s.expires_at > now()')
  else
    q := FDB.NewQuery(
      'select u.id, u.username, u.full_name, u.aktif, ' +
      'r.id as role_id, r.nama as role_nama, r.kode as role_kode ' +
      'from sessions s join users u on u.id = s.user_id ' +
      'join roles r on r.id = u.role_id ' +
      'where s.token=:token and s.username=:username ' +
      'and s.expires_at > datetime(''now'')');
  try
    try
      q.Params.ParamByName('token').AsString := Trim(AToken);
      q.Params.ParamByName('username').AsString := AUsername;
      q.Open;
      if q.EOF then
        Exit;
      if not q.FieldByName('aktif').AsBoolean then
        Exit;
      FUser.UserId := q.FieldByName('id').AsInteger;
      FUser.Username := q.FieldByName('username').AsString;
      FUser.FullName := q.FieldByName('full_name').AsString;
      FUser.RoleId := q.FieldByName('role_id').AsInteger;
      FUser.RoleName := q.FieldByName('role_nama').AsString;
      FUser.RoleCode := q.FieldByName('role_kode').AsString;
      LoadGrants(FUser.RoleId);
      FSessionToken := Trim(AToken);
      FLoggedIn := True;
      Result := True;
      // Sliding session: every successful token validation (module launch /
      // activity) pushes the expiry 8h forward.
      TouchSession;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := False;
      end;
    end;
  finally
    q.Free;
  end;
end;

function TRBACService.LoginDev: Boolean;
var
  g: TGUID;
  q: TSQLQuery;
  Token, NowExpr, ExpExpr: string;
  UID: Integer;
  UName: string;
begin
  Result := False;
  FLastError := '';
  if (FDB = nil) or (not FDB.Connected) then
  begin
    FLastError := 'Database tidak terhubung.';
    Exit;
  end;
  // Pick an active user, preferring the seeded 'admin' account.
  if FDB.Kind = dbPostgreSQL then
    q := FDB.NewQuery(
      'select id, username from users where aktif = true ' +
      'order by (username = ''admin'') desc, id asc limit 1')
  else
    q := FDB.NewQuery(
      'select id, username from users where aktif = 1 ' +
      'order by (username = ''admin'') desc, id asc limit 1');
  try
    q.Open;
    if q.EOF then
    begin
      FLastError := 'Tidak ada pengguna aktif untuk mode dev.';
      Exit;
    end;
    UID := q.FieldByName('id').AsInteger;
    UName := q.FieldByName('username').AsString;
  finally
    q.Free;
  end;
  if FDB.Kind = dbPostgreSQL then
  begin
    NowExpr := 'now()';
    ExpExpr := 'now() + interval ''8 hours''';
  end
  else
  begin
    NowExpr := 'datetime(''now'')';
    ExpExpr := 'datetime(''now'', ''+8 hours'')';
  end;
  CreateGUID(g);
  Token := GUIDToString(g);
  Token := StringReplace(Token, '{', '', [rfReplaceAll]);
  Token := StringReplace(Token, '}', '', [rfReplaceAll]);
  q := FDB.NewQuery(
    'insert into sessions (token, user_id, username, created_at, expires_at) ' +
    'values (:t, :u, :n, ' + NowExpr + ', ' + ExpExpr + ')');
  try
    if not FDB.Transaction.Active then
      FDB.Transaction.StartTransaction;
    q.Params.ParamByName('t').AsString := Token;
    q.Params.ParamByName('u').AsInteger := UID;
    q.Params.ParamByName('n').AsString := UName;
    q.ExecSQL;
    FDB.Transaction.Commit;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      if FDB.Transaction.Active then
        FDB.Transaction.Rollback;
      Exit;
    end;
  end;
  q.Free;
  Result := LoginWithToken(UName, Token);
end;

function TRBACService.CreateSession: string;
var
  g: TGUID;
  q: TSQLQuery;
  NowExpr, ExpExpr: string;
begin
  Result := '';
  if (FDB = nil) or (not FDB.Connected) or (not FLoggedIn) then
    Exit;
  if FSessionToken <> '' then
    Exit(FSessionToken);
  PurgeExpiredSessions;
  if FDB.Kind = dbPostgreSQL then
  begin
    NowExpr := 'now()';
    ExpExpr := 'now() + interval ''8 hours''';
  end
  else
  begin
    NowExpr := 'datetime(''now'')';
    ExpExpr := 'datetime(''now'', ''+8 hours'')';
  end;
  CreateGUID(g);
  FSessionToken := GUIDToString(g);
  FSessionToken := StringReplace(FSessionToken, '{', '', [rfReplaceAll]);
  FSessionToken := StringReplace(FSessionToken, '}', '', [rfReplaceAll]);
  q := FDB.NewQuery(
    'insert into sessions (token, user_id, username, created_at, expires_at) ' +
    'values (:t, :u, :n, ' + NowExpr + ', ' + ExpExpr + ')');
  try
    if not FDB.Transaction.Active then
      FDB.Transaction.StartTransaction;
    q.Params.ParamByName('t').AsString := FSessionToken;
    q.Params.ParamByName('u').AsInteger := FUser.UserId;
    q.Params.ParamByName('n').AsString := FUser.Username;
    q.ExecSQL;
    FDB.Transaction.Commit;
    Result := FSessionToken;
  except
    on E: Exception do
    begin
      FSessionToken := '';
      FLastError := E.Message;
      if FDB.Transaction.Active then
        FDB.Transaction.Rollback;
    end;
  end;
  q.Free;
end;

procedure TRBACService.RevokeSession;
var
  q: TSQLQuery;
begin
  if (FSessionToken <> '') and (FDB <> nil) and FDB.Connected then
  begin
    q := FDB.NewQuery('delete from sessions where token=:t');
    try
      if not FDB.Transaction.Active then
        FDB.Transaction.StartTransaction;
      q.Params.ParamByName('t').AsString := FSessionToken;
      q.ExecSQL;
      FDB.Transaction.Commit;
    except
    end;
    q.Free;
  end;
  FSessionToken := '';
end;

procedure TRBACService.Logout;
begin
  FLoggedIn := False;
  FSessionToken := '';
  FModules.Clear;
  FCreate.Clear;
  FEdit.Clear;
  FDelete.Clear;
  FUser.UserId := 0;
  FUser.Username := '';
  FUser.FullName := '';
  FUser.RoleId := 0;
  FUser.RoleName := '';
  FUser.RoleCode := '';
end;

procedure TRBACService.TouchSession;
var
  q: TSQLQuery;
begin
  if (FSessionToken = '') or (FDB = nil) or (not FDB.Connected) then
    Exit;
  q := FDB.NewQuery('');
  try
    try
      if not FDB.Transaction.Active then
        FDB.Transaction.StartTransaction;
      if FDB.Kind = dbPostgreSQL then
        q.SQL.Text :=
          'update sessions set expires_at = now() + interval ''8 hours'' where token=:t'
      else
        q.SQL.Text :=
          'update sessions set expires_at = datetime(''now'', ''+8 hours'') where token=:t';
      q.Params.ParamByName('t').AsString := FSessionToken;
      q.ExecSQL;
      FDB.Transaction.Commit;
    except
      on E: Exception do
      begin
        if FDB.Transaction.Active then
          FDB.Transaction.Rollback;
      end;
    end;
  finally
    q.Free;
  end;
end;

procedure TRBACService.PurgeExpiredSessions;
var
  q: TSQLQuery;
begin
  if (FDB = nil) or (not FDB.Connected) then
    Exit;
  q := FDB.NewQuery('');
  try
    try
      if not FDB.Transaction.Active then
        FDB.Transaction.StartTransaction;
      if FDB.Kind = dbPostgreSQL then
        q.SQL.Text := 'delete from sessions where expires_at <= now()'
      else
        q.SQL.Text := 'delete from sessions where expires_at <= datetime(''now'')';
      q.ExecSQL;
      FDB.Transaction.Commit;
    except
      on E: Exception do
      begin
        if FDB.Transaction.Active then
          FDB.Transaction.Rollback;
      end;
    end;
  finally
    q.Free;
  end;
end;

procedure TRBACService.RefreshPermissions;
begin
  if FLoggedIn then
    LoadGrants(FUser.RoleId);
end;

function TRBACService.IsAdmin: Boolean;
begin
  Result := FLoggedIn and (CompareText(FUser.RoleCode, 'ADMIN') = 0);
end;

function TRBACService.IsLoggedIn: Boolean;
begin
  Result := FLoggedIn;
end;

function TRBACService.CanView(const AModule: string): Boolean;
begin
  Result := False;
  if not FLoggedIn then
    Exit;
  if IsAdmin then
    Exit(True);
  Result := FModules.IndexOf(LowerCase(AModule)) >= 0;
end;

function TRBACService.CanAccess(const AModule: string): Boolean;
begin
  Result := CanView(AModule);
end;

function TRBACService.CanCreate(const AModule: string): Boolean;
begin
  Result := False;
  if not FLoggedIn then
    Exit;
  if IsAdmin then
    Exit(True);
  Result := FCreate.IndexOf(LowerCase(AModule)) >= 0;
end;

function TRBACService.CanEdit(const AModule: string): Boolean;
begin
  Result := False;
  if not FLoggedIn then
    Exit;
  if IsAdmin then
    Exit(True);
  Result := FEdit.IndexOf(LowerCase(AModule)) >= 0;
end;

function TRBACService.CanDelete(const AModule: string): Boolean;
begin
  Result := False;
  if not FLoggedIn then
    Exit;
  if IsAdmin then
    Exit(True);
  Result := FDelete.IndexOf(LowerCase(AModule)) >= 0;
end;

end.
