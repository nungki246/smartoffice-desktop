unit uApps;

{
  SmartOffice Desktop - external application (EXE) registry.

  The launcher drives every real application as a separate EXE module.
  Unlike the statically compiled in-process modules, the list of external
  applications is stored in the database table `apps` and can be managed at
  runtime (add / edit / delete) through the "Manajemen Aplikasi" module.

  TExternalModule is a lightweight TBaseModule that simply carries the
  navigation identity (title, category) plus the executable file name. It has
  no in-process view: clicking it launches the external process.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, DB, sqldb, uModule, uDB;

type
  TAppInfo = class
  public
    Id: Integer;
    AppId: string;
    Title: string;
    Description: string;
    Category: string;
    ExeFile: string;
    SortOrder: Integer;
    Active: Boolean;
  end;

  TExternalModule = class(TBaseModule)
  public
    function CreateView(const AViewID: TModuleID): TControl; override;
    function HasView(const AViewID: TModuleID): Boolean; override;
  end;

  TAppsService = class
  private
    FDB: TDatabaseManager;
  public
    constructor Create(ADB: TDatabaseManager);
    // Returns all apps ordered by sort_order/title. Caller must free the
    // returned TList and every TAppInfo inside it.
    function LoadApps: TList;
    // Returns a single app or nil. Caller frees the result.
    function FindApp(const AAppId: string): TAppInfo;
    function AppIdExists(const AAppId: string; const AIgnoreId: Integer): Boolean;
    function Insert(const AInfo: TAppInfo): Boolean;
    function Update(const AInfo: TAppInfo): Boolean;
    function Delete(const AId: Integer): Boolean;
  end;

var
  Apps: TAppsService = nil;

implementation

function TExternalModule.CreateView(const AViewID: TModuleID): TControl;
begin
  Result := nil; // external EXE module -> launched as a separate process
end;

function TExternalModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := (AViewID = '') or (AViewID = ID);
end;

{ TAppsService }

constructor TAppsService.Create(ADB: TDatabaseManager);
begin
  inherited Create;
  FDB := ADB;
end;

function TAppsService.LoadApps: TList;
var
  Q: TSQLQuery;
  Info: TAppInfo;
begin
  Result := TList.Create;
  if (FDB = nil) or (not FDB.Connected) then
    Exit;
  Q := FDB.NewQuery(
    'select id, app_id, title, description, category, exe_file, sort_order, is_active ' +
    'from apps order by sort_order, title');
  try
    try
      Q.Open;
      while not Q.EOF do
      begin
        Info := TAppInfo.Create;
        Info.Id := Q.FieldByName('id').AsInteger;
        Info.AppId := Q.FieldByName('app_id').AsString;
        Info.Title := Q.FieldByName('title').AsString;
        Info.Description := Q.FieldByName('description').AsString;
        Info.Category := Q.FieldByName('category').AsString;
        Info.ExeFile := Q.FieldByName('exe_file').AsString;
        Info.SortOrder := Q.FieldByName('sort_order').AsInteger;
        Info.Active := Q.FieldByName('is_active').AsBoolean;
        Result.Add(Info);
        Q.Next;
      end;
    except
      // leave whatever was read; caller sees the partial list
    end;
  finally
    Q.Free;
  end;
end;

function TAppsService.FindApp(const AAppId: string): TAppInfo;
var
  List: TList;
  I: Integer;
begin
  Result := nil;
  List := LoadApps;
  try
    for I := 0 to List.Count - 1 do
      if TAppInfo(List[I]).AppId = AAppId then
      begin
        Result := TAppInfo(List[I]);
        List.Extract(Result); // detach from the list so the caller owns it
        Break;
      end;
  finally
    for I := 0 to List.Count - 1 do
      TAppInfo(List[I]).Free;
    List.Free;
  end;
end;

function TAppsService.AppIdExists(const AAppId: string;
  const AIgnoreId: Integer): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  if (FDB = nil) or (not FDB.Connected) then
    Exit;
  Q := FDB.NewQuery(
    'select 1 from apps where app_id = :app_id and id <> :ignore_id limit 1');
  try
    try
      Q.Params.ParamByName('app_id').AsString := AAppId;
      Q.Params.ParamByName('ignore_id').AsInteger := AIgnoreId;
      Q.Open;
      Result := not Q.EOF;
      Q.Close;
    except
      Result := False;
    end;
  finally
    Q.Free;
  end;
end;

function TAppsService.Insert(const AInfo: TAppInfo): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  if (FDB = nil) or (not FDB.Connected) or (AInfo = nil) then
    Exit;
  Q := FDB.NewQuery(
    'insert into apps (app_id, title, description, category, exe_file, sort_order, is_active) ' +
    'values (:app_id, :title, :description, :category, :exe_file, :sort_order, :is_active)');
  try
    try
      if not FDB.Transaction.Active then
        FDB.Transaction.StartTransaction;
      Q.Params.ParamByName('app_id').AsString := AInfo.AppId;
      Q.Params.ParamByName('title').AsString := AInfo.Title;
      Q.Params.ParamByName('description').AsString := AInfo.Description;
      Q.Params.ParamByName('category').AsString := AInfo.Category;
      Q.Params.ParamByName('exe_file').AsString := AInfo.ExeFile;
      Q.Params.ParamByName('sort_order').AsInteger := AInfo.SortOrder;
      Q.Params.ParamByName('is_active').AsBoolean := AInfo.Active;
      Q.ExecSQL;
      FDB.Transaction.Commit;
      Result := True;
    except
      on E: Exception do
      begin
        if FDB.Transaction.Active then
          FDB.Transaction.Rollback;
      end;
    end;
  finally
    Q.Free;
  end;
end;

function TAppsService.Update(const AInfo: TAppInfo): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  if (FDB = nil) or (not FDB.Connected) or (AInfo = nil) or (AInfo.Id <= 0) then
    Exit;
  Q := FDB.NewQuery(
    'update apps set app_id = :app_id, title = :title, description = :description, ' +
    'category = :category, exe_file = :exe_file, sort_order = :sort_order, ' +
    'is_active = :is_active where id = :id');
  try
    try
      if not FDB.Transaction.Active then
        FDB.Transaction.StartTransaction;
      Q.Params.ParamByName('app_id').AsString := AInfo.AppId;
      Q.Params.ParamByName('title').AsString := AInfo.Title;
      Q.Params.ParamByName('description').AsString := AInfo.Description;
      Q.Params.ParamByName('category').AsString := AInfo.Category;
      Q.Params.ParamByName('exe_file').AsString := AInfo.ExeFile;
      Q.Params.ParamByName('sort_order').AsInteger := AInfo.SortOrder;
      Q.Params.ParamByName('is_active').AsBoolean := AInfo.Active;
      Q.Params.ParamByName('id').AsInteger := AInfo.Id;
      Q.ExecSQL;
      FDB.Transaction.Commit;
      Result := True;
    except
      on E: Exception do
      begin
        if FDB.Transaction.Active then
          FDB.Transaction.Rollback;
      end;
    end;
  finally
    Q.Free;
  end;
end;

function TAppsService.Delete(const AId: Integer): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  if (FDB = nil) or (not FDB.Connected) then
    Exit;
  Q := FDB.NewQuery('delete from apps where id = :id');
  try
    try
      if not FDB.Transaction.Active then
        FDB.Transaction.StartTransaction;
      Q.Params.ParamByName('id').AsInteger := AId;
      Q.ExecSQL;
      FDB.Transaction.Commit;
      Result := True;
    except
      on E: Exception do
      begin
        if FDB.Transaction.Active then
          FDB.Transaction.Rollback;
      end;
    end;
  finally
    Q.Free;
  end;
end;

end.
