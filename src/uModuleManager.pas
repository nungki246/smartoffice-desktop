unit uModuleManager;

{
  SmartOffice Desktop - module registry.

  TModuleManager owns the instantiated modules and knows how to order them
  for the navigation. RegisterAllModules is the single place where the set of
  statically compiled modules for this build is declared.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uModule;

type
  TModuleClassArray = array of TModuleClass;

  TModuleManager = class
  private
    FModules: TList;                 // of TBaseModule (loaded, sorted)
    FClasses: TModuleClassArray;
    FPendingModules: TList;          // of TBaseModule (pre-built instances)
    FDynamicIds: TStringList;        // ids of runtime-loaded EXE modules
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterModuleClass(AClass: TModuleClass);
    procedure RegisterModule(AModule: TBaseModule);
    procedure LoadAll;               // instantiate + initialize all modules
    procedure UnloadAll;
    procedure SortByCategoryAndTitle;

    function Count: Integer;
    function GetModule(AIndex: Integer): TBaseModule;
    function FindModule(const AID: TModuleID): TBaseModule;
    function VisibleCount: Integer;
    function GetVisibleModule(AIndex: Integer): TBaseModule;

    // --- runtime EXE apps (database driven) --------------------------------
    procedure RemoveExternalApps;                    // drop runtime apps
    procedure LoadExternalApps;                      // reload from database
  end;

var
  ModuleManager: TModuleManager = nil;

procedure RegisterAllModules;

implementation

uses
  uLauncherModule, uRBAC, uApps, uApp, uTheme;

{ TModuleManager }

constructor TModuleManager.Create;
begin
  inherited Create;
  FModules := TList.Create;
  FPendingModules := TList.Create;
  FDynamicIds := TStringList.Create;
end;

destructor TModuleManager.Destroy;
begin
  UnloadAll;
  FPendingModules.Free;
  FModules.Free;
  FDynamicIds.Free;
  inherited Destroy;
end;

procedure TModuleManager.RegisterModuleClass(AClass: TModuleClass);
begin
  SetLength(FClasses, Length(FClasses) + 1);
  FClasses[High(FClasses)] := AClass;
end;

procedure TModuleManager.RegisterModule(AModule: TBaseModule);
begin
  FPendingModules.Add(AModule);
end;

procedure TModuleManager.LoadAll;
var
  i: Integer;
  M: TBaseModule;
begin
  for i := 0 to High(FClasses) do
  begin
    M := FClasses[i].Create;
    M.InitializeModule;
    FModules.Add(M);
  end;
  for i := 0 to FPendingModules.Count - 1 do
  begin
    M := TBaseModule(FPendingModules[i]);
    M.InitializeModule;
    FModules.Add(M);
  end;
  FPendingModules.Clear;
  SortByCategoryAndTitle;
end;

procedure TModuleManager.UnloadAll;
var
  i: Integer;
  M: TBaseModule;
begin
  for i := 0 to FModules.Count - 1 do
  begin
    M := TBaseModule(FModules[i]);
    M.FinalizeModule;
    M.Free;
  end;
  FModules.Clear;
end;

function ModuleCompare(Item1, Item2: Pointer): Integer;
var
  A, B: TBaseModule;
begin
  A := TBaseModule(Item1);
  B := TBaseModule(Item2);
  Result := AnsiCompareText(A.Category, B.Category);
  if Result = 0 then
    Result := AnsiCompareText(A.Title, B.Title);
end;

procedure TModuleManager.SortByCategoryAndTitle;
begin
  FModules.Sort(@ModuleCompare);
end;

function TModuleManager.Count: Integer;
begin
  Result := FModules.Count;
end;

function TModuleManager.GetModule(AIndex: Integer): TBaseModule;
begin
  Result := TBaseModule(FModules[AIndex]);
end;

function TModuleManager.FindModule(const AID: TModuleID): TBaseModule;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FModules.Count - 1 do
    if TBaseModule(FModules[i]).ID = AID then
    begin
      Result := TBaseModule(FModules[i]);
      Exit;
    end;
end;

function TModuleManager.VisibleCount: Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to FModules.Count - 1 do
    if (not TBaseModule(FModules[i]).HiddenInNav) and
       (RBAC <> nil) and RBAC.CanView(TBaseModule(FModules[i]).ID) then
      Inc(Result);
end;

function TModuleManager.GetVisibleModule(AIndex: Integer): TBaseModule;
var
  i: Integer;
  M: TBaseModule;
begin
  Result := nil;
  for i := 0 to FModules.Count - 1 do
  begin
    M := TBaseModule(FModules[i]);
    if (not M.HiddenInNav) and (RBAC <> nil) and RBAC.CanView(M.ID) then
    begin
      if AIndex = 0 then
        Exit(M);
      Dec(AIndex);
    end;
  end;
end;

{ Runtime EXE apps -------------------------------------------------------------}

procedure TModuleManager.RemoveExternalApps;
var
  I: Integer;
  M: TBaseModule;
begin
  for I := FDynamicIds.Count - 1 downto 0 do
  begin
    M := FindModule(FDynamicIds[I]);
    if M <> nil then
    begin
      M.FinalizeModule;
      M.Free;
      FModules.Remove(M);
    end;
    FDynamicIds.Delete(I);
  end;
end;

procedure TModuleManager.LoadExternalApps;
var
  List: TList;
  I: Integer;
  Info: TAppInfo;
  M: TBaseModule;
begin
  RemoveExternalApps;
  if Apps = nil then
  begin
    LogMsg('LoadExternalApps: Apps belum diinisialisasi');
    Exit;
  end;
  List := Apps.LoadApps;
  LogMsg(Format('LoadExternalApps: list=%d, db_connected=%s',
    [List.Count, BoolToStr(AppDB.Connected, True)]));
  try
    for I := 0 to List.Count - 1 do
    begin
      Info := TAppInfo(List[I]);
      if not Info.Active then
        Continue;
      M := TExternalModule.Create;
      M.ID := Info.AppId;
      M.Title := Info.Title;
      M.Description := Info.Description;
      M.Category := Info.Category;
      M.ExeFile := Info.ExeFile;
      M.Version := '1.0';
      M.Author := '';
      M.InitializeModule;
      FModules.Add(M);
      FDynamicIds.Add(M.ID);
    end;
  finally
    for I := 0 to List.Count - 1 do
      TAppInfo(List[I]).Free;
    List.Free;
  end;
  SortByCategoryAndTitle;
end;

{ RegisterAllModules }

procedure RegisterAllModules;
begin
  ModuleManager.RegisterModuleClass(TLauncherModule);
end;

initialization
  ModuleManager := TModuleManager.Create;

finalization
  ModuleManager.Free;
  ModuleManager := nil;

end.
