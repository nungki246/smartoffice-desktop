unit uAudit;

{
  SmartOffice Desktop - audit trail.

  Records who did what, when, on which record, into the database table
  `audit_log`. Every process (launcher + module executables) can call
  AuditLog(); the actor is taken from the current RBAC session, so calls
  always carry the logged-in user automatically.

  The audit row is written in its own small transaction so a failure while
  logging never rolls back the business operation that triggered it.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

// AAction: 'CREATE' | 'UPDATE' | 'DELETE' | 'LOGIN' | 'LOGOUT' | 'GRANT'
// AEntity: table/module name (employees, registrasi, users, roles, ...)
// AEntityId: primary key of the affected record (0 when not applicable)
// ADetail: human-readable summary of what changed
procedure AuditLog(const AAction, AEntity: string; AEntityId: Integer;
  const ADetail: string);

implementation

uses
  sqldb, uApp, uDB, uRBAC;

procedure AuditLog(const AAction, AEntity: string; AEntityId: Integer;
  const ADetail: string);
var
  Q: TSQLQuery;
  UID: Integer;
  UName: string;
begin
  if (AppDB = nil) or (not AppDB.Connected) then
    Exit;
  UID := 0;
  UName := '';
  if (RBAC <> nil) and RBAC.IsLoggedIn then
  begin
    UID := RBAC.User.UserId;
    UName := RBAC.Username;
  end;
  Q := AppDB.NewQuery(
    'insert into audit_log (user_id, username, action, entity, entity_id, detail) ' +
    'values (:uid, :uname, :action, :entity, :eid, :detail)');
  try
    try
      if not AppDB.Transaction.Active then
        AppDB.Transaction.StartTransaction;
      Q.Params.ParamByName('uid').AsInteger := UID;
      Q.Params.ParamByName('uname').AsString := UName;
      Q.Params.ParamByName('action').AsString := AAction;
      Q.Params.ParamByName('entity').AsString := AEntity;
      Q.Params.ParamByName('eid').AsInteger := AEntityId;
      Q.Params.ParamByName('detail').AsString := ADetail;
      Q.ExecSQL;
      AppDB.Transaction.Commit;
    except
      on E: Exception do
      begin
        if AppDB.Transaction.Active then
          AppDB.Transaction.Rollback;
      end;
    end;
  finally
    Q.Free;
  end;
end;

end.
