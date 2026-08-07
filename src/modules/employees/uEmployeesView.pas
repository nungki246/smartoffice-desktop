unit uEmployeesView;

{
  SmartOffice Desktop - Employees view (CRUD example module).

  Demonstrates a full create/read/update/delete screen against the active
  database (PostgreSQL or SQLite). The module bootstraps its own table so the
  demo works on a fresh database.

  Implemented as a TFrame so the layout lives in uEmployeesView.lfm and can
  be edited visually in the Lazarus IDE (drag & drop). The .lfm is streamed
  automatically when the frame is created at runtime.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqldb, Controls, Graphics, ExtCtrls, StdCtrls,
  Buttons, DBGrids, Forms;

type

  { TEmployeesView }

  TEmployeesView = class(TFrame)
  published
    Toolbar: TPanel;
    FStatusLabel: TLabel;
    FBtnAdd: TBitBtn;
    FBtnEdit: TBitBtn;
    FBtnDelete: TBitBtn;
    FBtnRefresh: TBitBtn;
    FGrid: TDBGrid;
    procedure DoAdd(Sender: TObject);
    procedure DoEdit(Sender: TObject);
    procedure DoDelete(Sender: TObject);
    procedure DoRefresh(Sender: TObject);
  private
    FGridQuery: TSQLQuery;
    FDataSource: TDataSource;
    FModuleId: string;
    FConnected: Boolean;
    procedure ApplyTheme;
    procedure BuildSchema;
    function ExecDML(const ASQL: string; const AName, ADepartment, AEmail,
      AHireDate: string): Boolean;
    procedure InitializeGrid;
    procedure RefreshGrid;
    function CanCreate: Boolean;
    function CanEdit: Boolean;
    function CanDelete: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    property ModuleId: string read FModuleId write FModuleId;
  end;

implementation

uses
  Dialogs, uApp, uDB, uRBAC, uAudit, uTheme;

{$R *.lfm}

{ TEmployeesView }

constructor TEmployeesView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); // streams the .lfm (creates Toolbar, FGrid, ...)
  if csDesigning in ComponentState then
    Exit; // designer instance: no DB wiring
  FModuleId := 'employees';
  ApplyTheme;
  FConnected := AppDB.Connected;
  if FConnected then
    BuildSchema;
  InitializeGrid;
end;

procedure TEmployeesView.ApplyTheme;
begin
  Color := AppTheme.ColorBackgroundAlt;
  Font.Name := AppTheme.FontFamily;
  Font.Size := AppTheme.FontSizeMD;

  if Assigned(Toolbar) then
    Toolbar.Color := AppTheme.ColorBackground;
  
  if Assigned(FStatusLabel) then
    FStatusLabel.Font.Color := AppTheme.ColorTextSecondary;

  if Assigned(FGrid) then
  begin
    FGrid.AlternateColor := $00F5F5F5;
    FGrid.Options := FGrid.Options - [dgColLines];
    FGrid.Color := clWhite;
  end;
end;

function TEmployeesView.CanCreate: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanCreate(FModuleId);
end;

function TEmployeesView.CanEdit: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanEdit(FModuleId);
end;

function TEmployeesView.CanDelete: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanDelete(FModuleId);
end;

procedure TEmployeesView.BuildSchema;
var
  DDL: string;
begin
  if AppDB.Kind = dbPostgreSQL then
    DDL :=
      'create table if not exists employees (' +
      ' id serial primary key,' +
      ' name varchar(120) not null,' +
      ' department varchar(80),' +
      ' email varchar(120),' +
      ' hire_date date)'
  else
    DDL :=
      'create table if not exists employees (' +
      ' id integer primary key autoincrement,' +
      ' name varchar(120) not null,' +
      ' department varchar(80),' +
      ' email varchar(120),' +
      ' hire_date date)';
  AppDB.ExecSQL(DDL);
  // Index backing the 'order by name' grid query.
  AppDB.ExecSQL('create index if not exists ix_employees_name on employees(name)');
end;

procedure TEmployeesView.InitializeGrid;
begin
  if not FConnected then
  begin
    FStatusLabel.Caption := 'Database belum terhubung. Buka Pengaturan untuk koneksi.';
    FStatusLabel.Font.Color := clRed;
    Exit;
  end;
  FGridQuery := AppDB.NewQuery(
    'select id, name, department, email, hire_date ' +
    'from employees order by name');
  FDataSource := TDataSource.Create(Self);
  FDataSource.DataSet := FGridQuery;
  FGrid.DataSource := FDataSource;
  RefreshGrid;
end;

function TEmployeesView.ExecDML(const ASQL: string; const AName, ADepartment,
  AEmail, AHireDate: string): Boolean;
var
  q: TSQLQuery;
begin
  Result := False;
  q := AppDB.NewQuery(ASQL);
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    q.Params.ParamByName('name').AsString := AName;
    q.Params.ParamByName('department').AsString := ADepartment;
    q.Params.ParamByName('email').AsString := AEmail;
    if Trim(AHireDate) = '' then
      q.Params.ParamByName('hire_date').Clear
    else
      q.Params.ParamByName('hire_date').AsString := AHireDate;
    q.ExecSQL;
    Result := True;
  except
    on E: Exception do
      MessageDlg('Kesalahan', 'Gagal menyimpan data:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
  end;
  q.Free;
end;

procedure TEmployeesView.RefreshGrid;
begin
  if (FGridQuery = nil) or (not AppDB.Connected) then
    Exit;
  try
    FGridQuery.Close;
    if AppDB.Transaction.Active then
      AppDB.Transaction.Commit;
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    FGridQuery.Open;
    FStatusLabel.Caption := Format('%d pegawai', [FGridQuery.RecordCount]);
    FStatusLabel.Font.Color := clWindowText;
  except
    on E: Exception do
    begin
      FStatusLabel.Caption := 'Gagal membaca data: ' + E.Message;
      FStatusLabel.Font.Color := clRed;
    end;
  end;
end;

procedure TEmployeesView.DoAdd(Sender: TObject);
var
  AName, ADepartment, AEmail, AHireDate: string;
  Values: array of string;
begin
  if not CanCreate then
  begin
    MessageDlg('Akses Ditolak', 'Anda tidak memiliki hak menambah data.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if not AppDB.Connected then
  begin
    MessageDlg('Info', 'Database belum terhubung.', mtInformation, [mbOK], 0);
    Exit;
  end;
  SetLength(Values, 4);
  Values[0] := '';
  Values[1] := '';
  Values[2] := '';
  Values[3] := '';
  if InputQuery('Tambah Pegawai',
    ['Nama', 'Departemen', 'Email', 'Tanggal (YYYY-MM-DD)'], Values) then
  begin
    AName := Values[0];
    ADepartment := Values[1];
    AEmail := Values[2];
    AHireDate := Values[3];
    if Trim(AName) = '' then
    begin
      MessageDlg('Info', 'Nama tidak boleh kosong.', mtWarning, [mbOK], 0);
      Exit;
    end;
    if ExecDML(
      'insert into employees (name, department, email, hire_date) values ' +
      '(:name, :department, :email, cast(:hire_date as date))',
      AName, ADepartment, AEmail, AHireDate) then
    begin
      AuditLog('CREATE', 'employees', 0,
        'Tambah: ' + AName + ' (' + ADepartment + ')');
      RefreshGrid;
    end;
  end;
end;

procedure TEmployeesView.DoEdit(Sender: TObject);
var
  AName, ADepartment, AEmail, AHireDate: string;
  ID: Integer;
  Values: array of string;
begin
  if not CanEdit then
  begin
    MessageDlg('Akses Ditolak', 'Anda tidak memiliki hak mengubah data.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if (FGridQuery = nil) or FGridQuery.EOF then
  begin
    MessageDlg('Info', 'Pilih baris data terlebih dahulu.', mtInformation, [mbOK], 0);
    Exit;
  end;
  ID := FGridQuery.FieldByName('id').AsInteger;
  AName := FGridQuery.FieldByName('name').AsString;
  ADepartment := FGridQuery.FieldByName('department').AsString;
  AEmail := FGridQuery.FieldByName('email').AsString;
  AHireDate := FGridQuery.FieldByName('hire_date').AsString;
  SetLength(Values, 4);
  Values[0] := AName;
  Values[1] := ADepartment;
  Values[2] := AEmail;
  Values[3] := AHireDate;
  if InputQuery('Edit Pegawai',
    ['Nama', 'Departemen', 'Email', 'Tanggal (YYYY-MM-DD)'], Values) then
  begin
    AName := Values[0];
    ADepartment := Values[1];
    AEmail := Values[2];
    AHireDate := Values[3];
    if Trim(AName) = '' then
    begin
      MessageDlg('Info', 'Nama tidak boleh kosong.', mtWarning, [mbOK], 0);
      Exit;
    end;
    if ExecDML(
      'update employees set name=:name, department=:department, ' +
      'email=:email, hire_date=cast(:hire_date as date) where id=:id',
      AName, ADepartment, AEmail, AHireDate) then
    begin
      AppDB.Transaction.Commit;
      AuditLog('UPDATE', 'employees', ID,
        'Ubah: ' + AName + ' (' + ADepartment + ')');
      RefreshGrid;
    end;
  end;
end;

procedure TEmployeesView.DoDelete(Sender: TObject);
var
  ID: Integer;
  q: TSQLQuery;
begin
  if not CanDelete then
  begin
    MessageDlg('Akses Ditolak', 'Anda tidak memiliki hak menghapus data.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if (FGridQuery = nil) or FGridQuery.EOF then
  begin
    MessageDlg('Info', 'Pilih baris data terlebih dahulu.', mtInformation, [mbOK], 0);
    Exit;
  end;
  ID := FGridQuery.FieldByName('id').AsInteger;
  if MessageDlg('Hapus', 'Hapus pegawai ini?', mtConfirmation,
    mbYesNo, 0) <> mrYes then
    Exit;
  q := AppDB.NewQuery('delete from employees where id=:id');
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    q.Params.ParamByName('id').AsInteger := ID;
    q.ExecSQL;
    AppDB.Transaction.Commit;
    AuditLog('DELETE', 'employees', ID, 'Hapus pegawai id=' + IntToStr(ID));
  except
    on E: Exception do
      MessageDlg('Kesalahan', 'Gagal menghapus data:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
  end;
  q.Free;
  RefreshGrid;
end;

procedure TEmployeesView.DoRefresh(Sender: TObject);
begin
  RefreshGrid;
end;

end.
