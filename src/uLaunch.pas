unit uLaunch;

{
  SmartOffice Desktop - module launcher helpers.

  The launcher runs each module as a separate executable (SIMRS-*.exe).
  The module process receives the logged-in user and a session token on the
  command line and validates them against the database before opening.
  Single-instance enforcement: each module can only run once per session.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

// --command line (used by module executables) --------------------------------
// Reads "--name=value" parameters, e.g. "--user=admin --token=<uuid>".
function GetCmdLineParam(const AName: string; out AValue: string): Boolean;
function GetCmdLineParam(const AName: string): string; overload;

// --authentication hand-over (launcher -> module process) --------------------
// Since FPC 1.1 the launcher passes credentials through environment variables
// instead of the command line so the session token is not visible in the
// process list / Task Manager. Command-line params remain as a fallback.
function GetEnvParam(const AName: string): string;
function GetModuleAuth(var AUser, AToken: string): Boolean;

// --development mode (used by module executables) -----------------------------
// When enabled the module skips token validation so it can be launched
// directly (e.g. from the IDE) for development/testing. It is never enabled
// by the launcher itself.
function IsDevMode: Boolean;

// --launching (used by the launcher) -----------------------------------------
function AppExeDir: string;
function ModuleExePath(const AExeFile: string): string;
function LaunchModuleExe(const AExeFile, AUser, AToken: string;
  out AError: string): Boolean;
procedure TerminateLaunchedModules;

// --single instance (used by module executables) ------------------------------
// Creates a named mutex so a module can only run once per desktop session.
// Returns False when another instance of AKey is already running.
function EnsureSingleInstance(const AKey: string): Boolean;

// Brings an already-running window with ACaption (partial, case-insensitive)
// to the foreground. Used by the launcher so a second launch focuses the
// existing window instead of starting another instance.
function FocusExistingWindow(const ACaption: string): Boolean;

implementation

uses
  Windows;

var
  ModuleProcessMap: TStringList; // ExeFile (key) -> THandle (object)
  SingleInstanceMutex: THandle = 0;

// Toolhelp32 process enumeration (declared locally; FPC ships no tlhelp32 unit).
const
  TH32CS_SNAPPROCESS = $00000002;

type
  TProcessEntry32W = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ProcessID: DWORD;
    th32DefaultHeapID: ULONG_PTR;
    th32ModuleID: DWORD;
    cntThreads: DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase: Longint;
    dwFlags: DWORD;
    szExeFile: array[0..MAX_PATH - 1] of WideChar;
  end;

function CreateToolhelp32Snapshot(dwFlags: DWORD; th32ProcessID: DWORD): THandle;
  stdcall; external 'kernel32.dll' name 'CreateToolhelp32Snapshot';
function Process32FirstW(hSnapshot: THandle; var lppe: TProcessEntry32W): BOOL;
  stdcall; external 'kernel32.dll' name 'Process32FirstW';
function Process32NextW(hSnapshot: THandle; var lppe: TProcessEntry32W): BOOL;
  stdcall; external 'kernel32.dll' name 'Process32NextW';

function IsProcessRunning(hProcess: THandle): Boolean;
var
  ExitCode: DWORD;
begin
  Result := False;
  if (hProcess <> 0) and GetExitCodeProcess(hProcess, ExitCode) then
    Result := (ExitCode = STILL_ACTIVE);
end;

function IsProcessRunningByName(const AExeName: string): Boolean;
var
  Snap: THandle;
  PE: TProcessEntry32W;
begin
  Result := False;
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snap = INVALID_HANDLE_VALUE then
    Exit;
  try
    PE.dwSize := SizeOf(PE);
    if Process32FirstW(Snap, PE) then
      repeat
        if CompareText(PE.szExeFile, AExeName) = 0 then
          Exit(True);
      until not Process32NextW(Snap, PE);
  finally
    CloseHandle(Snap);
  end;
end;

procedure TerminateLaunchedModules;
var
  I: Integer;
  h: THandle;
begin
  if ModuleProcessMap <> nil then
  begin
    for I := 0 to ModuleProcessMap.Count - 1 do
    begin
      h := THandle(ModuleProcessMap.Objects[I]);
      if (h <> 0) and IsProcessRunning(h) then
        TerminateProcess(h, 0);
    end;
    ModuleProcessMap.Free;
    ModuleProcessMap := nil;
  end;
end;

function GetCmdLineParam(const AName: string; out AValue: string): Boolean;
var
  I: Integer;
  Prefix: string;
begin
  Result := False;
  Prefix := '--' + AName + '=';
  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, Length(Prefix)) = Prefix then
    begin
      AValue := Copy(ParamStr(I), Length(Prefix) + 1, MaxInt);
      Exit(True);
    end;
end;

function GetCmdLineParam(const AName: string): string;
begin
  Result := '';
  GetCmdLineParam(AName, Result);
end;

function GetEnvParam(const AName: string): string;
const
  BufLen = 2048;
var
  Buf: array[0..BufLen - 1] of Char;
begin
  Result := '';
  if GetEnvironmentVariableA(PAnsiChar(AName), @Buf, BufLen) > 0 then
    Result := Buf;
end;

function GetModuleAuth(var AUser, AToken: string): Boolean;
begin
  AUser := GetEnvParam('SMARTOFFICE_USER');
  if AUser = '' then
    AUser := GetCmdLineParam('user');
  AToken := GetEnvParam('SMARTOFFICE_TOKEN');
  if AToken = '' then
    AToken := GetCmdLineParam('token');
  Result := (Trim(AUser) <> '') and (Trim(AToken) <> '');
end;

function IsDevMode: Boolean;
var
  I: Integer;
begin
  Result := GetEnvParam('SMARTOFFICE_DEV') = '1';
  if Result then
    Exit;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), '--dev') = 0 then
      Exit(True);
end;

function EnsureSingleInstance(const AKey: string): Boolean;
var
  h: THandle;
  LastErr: DWORD;
begin
  if SingleInstanceMutex <> 0 then
    Exit(True);
  h := CreateMutexA(nil, True, PAnsiChar('Local\SmartOfficeDesktop-' + AKey));
  LastErr := GetLastError;
  if h = 0 then
    Exit(True); // cannot enforce -> do not block startup
  if LastErr = ERROR_ALREADY_EXISTS then
  begin
    CloseHandle(h);
    Exit(False);
  end;
  SingleInstanceMutex := h;
  Result := True;
end;

type
  TFindTitleData = record
    Needle: WideString;
    Wnd: HWND;
  end;

function FindTitleProc(Wnd: HWND; LParam: LPARAM): BOOL; stdcall;
var
  Data: ^TFindTitleData;
  Buf: array[0..511] of WideChar;
  Title: WideString;
begin
  Result := True; // keep enumerating unless found
  Data := Pointer(LParam);
  if Data = nil then
    Exit;
  if GetWindowTextW(Wnd, @Buf, 512) > 0 then
  begin
    Title := Buf;
    if Pos(Data^.Needle, Title) > 0 then
    begin
      Data^.Wnd := Wnd;
      Result := False; // found -> stop
    end;
  end;
end;

function FocusExistingWindow(const ACaption: string): Boolean;
const
  SW_RESTORE = 9;
var
  Data: TFindTitleData;
begin
  Result := False;
  Data.Needle := WideString(ACaption);
  Data.Wnd := 0;
  EnumWindows(@FindTitleProc, LPARAM(@Data));
  if Data.Wnd = 0 then
    Exit;
  if IsIconic(Data.Wnd) then
    ShowWindow(Data.Wnd, SW_RESTORE);
  SetForegroundWindow(Data.Wnd);
  Result := True;
end;

function AppExeDir: string;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

function ModuleExePath(const AExeFile: string): string;
begin
  // Module executables live in <launcher-dir>\apps\.
  Result := AppExeDir + 'apps\' + AExeFile;
  if not FileExists(Result) then
    Result := AExeFile;
end;

function LaunchModuleExe(const AExeFile, AUser, AToken: string;
  out AError: string): Boolean;
var
  ExePath, CmdLine: AnsiString;
  SI: TStartupInfoA;
  PI: TProcessInformation;
  LastErr: DWORD;
begin
  Result := False;
  ExePath := ModuleExePath(AExeFile);
  if not FileExists(ExePath) then
  begin
    AError := 'Berkas tidak ditemukan: ' + ExePath;
    Exit;
  end;

  // Single-instance across sessions: if the module executable is already
  // running on this machine (regardless of who launched it), reject.
  if IsProcessRunningByName(ExtractFileName(ExePath)) then
  begin
    AError := 'Aplikasi sudah berjalan: ' + AExeFile;
    Exit;
  end;

  // Hand credentials over via environment variables (inherited by the child
  // process) instead of the command line to keep the token out of the
  // process list.
  SetEnvironmentVariableA('SMARTOFFICE_USER', PAnsiChar(AUser));
  SetEnvironmentVariableA('SMARTOFFICE_TOKEN', PAnsiChar(AToken));
  CmdLine := '"' + ExePath + '"';
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  if CreateProcessA(nil, PAnsiChar(CmdLine), nil, nil, False,
    CREATE_DEFAULT_ERROR_MODE or NORMAL_PRIORITY_CLASS,
    nil, PAnsiChar(AppExeDir), @SI, @PI) then
  begin
    CloseHandle(PI.hThread);
    if ModuleProcessMap = nil then
      ModuleProcessMap := TStringList.Create;
    ModuleProcessMap.AddObject(AExeFile, TObject(PI.hProcess));
    Result := True;
  end
  else
  begin
    LastErr := GetLastError;
    AError := 'Gagal menjalankan ' + AExeFile +
      ' (kode ' + IntToStr(Integer(LastErr)) + ')';
  end;
  // Always clear the credential environment, even on failure.
  SetEnvironmentVariableA('SMARTOFFICE_USER', nil);
  SetEnvironmentVariableA('SMARTOFFICE_TOKEN', nil);
end;

initialization
finalization
  TerminateLaunchedModules;
  if SingleInstanceMutex <> 0 then
    CloseHandle(SingleInstanceMutex);
end.
