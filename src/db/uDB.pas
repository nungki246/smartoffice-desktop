unit uDB;

{
  SmartOffice Desktop - database layer.

  Thin wrapper over SQLDB so modules never touch connection classes directly.
  Two back-ends are supported:
    * PostgreSQL (default) via TPQConnection + libpq.dll
    * SQLite    (embedded fallback) via TSQLite3Connection
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqldb;

type
  TDatabaseKind = (dbPostgreSQL, dbSQLite);

  TDatabaseManager = class
  private
    FConnection: TSQLConnection;
    FTransaction: TSQLTransaction;
    FKind: TDatabaseKind;
    FLastError: string;
    function GetConnected: Boolean;
    function GetServerVersion: string;
  public
    constructor Create;
    destructor Destroy; override;

    // --- connection ------------------------------------------------------
    function ConnectPostgres(const AHost: string; APort: Integer;
      const AUser, APassword, ADatabase: string): Boolean;
    function ConnectSQLite(const AFileName: string): Boolean;
    function ConnectFromConfig: Boolean;
    procedure Disconnect;

    // --- helpers -----------------------------------------------------------
    function ExecSQL(const ASQL: string): Boolean;
    function ExecSQLNoCommit(const ASQL: string): Boolean;
    function TableExists(const ATableName: string): Boolean;
    function SchemaReady: Boolean;
    function NewQuery(const ASQL: string): TSQLQuery;

    property Connection: TSQLConnection read FConnection;
    property Transaction: TSQLTransaction read FTransaction;
    property Kind: TDatabaseKind read FKind;
    property Connected: Boolean read GetConnected;
    property LastError: string read FLastError;
    property ServerVersion: string read GetServerVersion;
  end;

implementation

uses
  uConfig, uApp, pqconnection, sqlite3conn;

{ TDatabaseManager }

constructor TDatabaseManager.Create;
begin
  inherited Create;
  FKind := dbPostgreSQL;
end;

destructor TDatabaseManager.Destroy;
begin
  Disconnect;
  inherited Destroy;
end;

function TDatabaseManager.GetConnected: Boolean;
begin
  Result := (FConnection <> nil) and FConnection.Connected;
end;

function TDatabaseManager.GetServerVersion: string;
begin
  Result := '';
  if Connected then
    Result := FConnection.GetConnectionInfo(citServerVersion);
end;

function TDatabaseManager.ConnectPostgres(const AHost: string; APort: Integer;
  const AUser, APassword, ADatabase: string): Boolean;
begin
  Result := False;
  Disconnect;
  FKind := dbPostgreSQL;
  FLastError := '';
  try
    FTransaction := TSQLTransaction.Create(nil);
    FConnection := TPQConnection.Create(nil);
    TPQConnection(FConnection).HostName := AHost;
    FConnection.Params.Values['port'] := IntToStr(APort);
    FConnection.UserName := AUser;
    FConnection.Password := APassword;
    FConnection.DatabaseName := ADatabase;
    FConnection.Transaction := FTransaction;
    FConnection.Connected := True;
    Result := FConnection.Connected;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FreeAndNil(FConnection);
      FreeAndNil(FTransaction);
    end;
  end;
end;

function TDatabaseManager.ConnectSQLite(const AFileName: string): Boolean;
begin
  Result := False;
  Disconnect;
  FKind := dbSQLite;
  FLastError := '';
  try
    FTransaction := TSQLTransaction.Create(nil);
    FConnection := TSQLite3Connection.Create(nil);
    FConnection.DatabaseName := AFileName;
    FConnection.Transaction := FTransaction;
    FConnection.Connected := True;
    Result := FConnection.Connected;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      FreeAndNil(FConnection);
      FreeAndNil(FTransaction);
    end;
  end;
end;

function TDatabaseManager.ConnectFromConfig: Boolean;
begin
  if AppConfig.UsePostgres then
    Result := ConnectPostgres(AppConfig.DbHost, AppConfig.DbPort,
      AppConfig.DbUser, AppConfig.DbPassword, AppConfig.DbName)
  else
    Result := ConnectSQLite(AppConfig.SqliteFile);
end;

procedure TDatabaseManager.Disconnect;
begin
  try
    if FConnection <> nil then
    begin
      if FConnection.Connected then
        FConnection.Connected := False;
      FConnection.Free;
      FConnection := nil;
    end;
    if FTransaction <> nil then
    begin
      FTransaction.Free;
      FTransaction := nil;
    end;
  except
    // ignore errors during teardown
  end;
end;

function TDatabaseManager.ExecSQL(const ASQL: string): Boolean;
begin
  Result := False;
  if not Connected then
  begin
    FLastError := 'Database is not connected';
    Exit;
  end;
  try
    if not FTransaction.Active then
      FTransaction.StartTransaction;
    FConnection.ExecuteDirect(ASQL);
    FTransaction.Commit;
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      if FTransaction.Active then
        FTransaction.Rollback;
    end;
  end;
end;

function TDatabaseManager.ExecSQLNoCommit(const ASQL: string): Boolean;
begin
  Result := False;
  if not Connected then
  begin
    FLastError := 'Database is not connected';
    Exit;
  end;
  try
    if not FTransaction.Active then
      FTransaction.StartTransaction;
    FConnection.ExecuteDirect(ASQL);
    Result := True;
  except
    on E: Exception do
      FLastError := E.Message;
    // NOTE: no commit/rollback here - the caller owns the surrounding
    // transaction (used to batch schema/seed statements in one commit).
  end;
end;

function TDatabaseManager.TableExists(const ATableName: string): Boolean;
var
  q: TSQLQuery;
begin
  Result := False;
  if not Connected then
    Exit;
  q := NewQuery('select 1 from ' + ATableName + ' limit 1');
  try
    q.Open;
    Result := True;
    q.Close;
  except
    Result := False;
  end;
  q.Free;
end;

function TDatabaseManager.SchemaReady: Boolean;
var
  q: TSQLQuery;
begin
  Result := False;
  if not Connected then
    Exit;
  q := NewQuery('');
  try
    if FKind = dbPostgreSQL then
      q.SQL.Text :=
        'select 1 from information_schema.tables ' +
        'where table_schema = current_schema() and table_name = ''roles'' limit 1'
    else
      q.SQL.Text :=
        'select 1 from sqlite_master ' +
        'where type = ''table'' and name = ''roles'' limit 1';
    try
      q.Open;
      Result := not q.EOF;
      q.Close;
    except
      Result := False;
    end;
  finally
    q.Free;
  end;
end;

function TDatabaseManager.NewQuery(const ASQL: string): TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConnection;
  Result.Transaction := FTransaction;
  Result.SQL.Text := ASQL;
end;

end.
