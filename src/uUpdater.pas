unit uUpdater;

{
  SmartOffice Desktop - automatic updater.

  The version source of truth is GitHub Releases. The launcher queries
  https://api.github.com/repos/<owner>/<repo>/releases/latest, compares the
  release tag against AppVersion (uVersion.pas) and, when newer, downloads
  every release asset into a staging folder and applies them:

    * SIMRS-*.exe  -> <launcher-dir>\apps\
    * SmartOfficeDesktop.exe -> self-update (the running EXE cannot overwrite
      itself, so a small batch helper waits for the launcher to exit, replaces
      the file and starts the new version).
    * anything else -> <launcher-dir>\

  TLS is done through OpenSSL 3; the DLL names are overridden at runtime
  because FPC 3.2.2 looks for the OpenSSL 1.1 DLL names by default.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TUpdateAsset = record
    Name: string;
    Url: string;
    Size: Int64;
  end;
  TUpdateAssetArray = array of TUpdateAsset;

// Returns True when a newer version exists; ANewVersion holds the release tag.
// Returns False only on an error (AError filled).
function CheckForUpdates(const ARepo: string; out ANewVersion: string;
  out AError: string): Boolean;

// Downloads all release assets of the latest release into AStagingDir.
function StageUpdates(const ARepo: string; const AStagingDir: string;
  out AError: string): Boolean;

// Copies the staged files to their destinations. Running module executables
// are terminated first so their files are not locked. When the launcher itself
// is staged, a self-update batch is spawned and ALauncherUpdated is set True
// (the caller should then close the application).
function ApplyStagedUpdates(const AStagingDir: string;
  out ALauncherUpdated: Boolean; out AError: string): Boolean;

implementation

uses
  Windows, fpjson, jsonparser, fphttpclient, openssl, opensslsockets,
  uApp, uPaths, uLaunch, uVersion;

var
  SSLLibraryReady: Boolean = False;

procedure EnsureSSLLibrary;
begin
  if SSLLibraryReady then
    Exit;
  // FPC 3.2.2 defaults to the OpenSSL 1.1 DLL names; this app ships OpenSSL 3.
  DLLSSLName := 'libssl-3-x64.dll';
  DLLUtilName := 'libcrypto-3-x64.dll';
  InitSSLInterface;
  SSLLibraryReady := True;
end;

function NormalizeVersion(const A: string): string;
var
  S: string;
begin
  S := Trim(A);
  if (S <> '') and (S[1] in ['v', 'V']) then
    Delete(S, 1, 1);
  Result := S;
end;

// Numeric dot-separated comparison. Returns -1/0/1 for A<B/A=B/A>B.
function CompareVersions(const A, B: string): Integer;
var
  X, Y: string;
  Px, Py: Integer;
  Nx, Ny: Integer;
begin
  X := NormalizeVersion(A);
  Y := NormalizeVersion(B);
  Px := 1;
  Py := 1;
  Result := 0;
  while True do
  begin
    Nx := 0;
    while (Px <= Length(X)) and (X[Px] <> '.') do
    begin
      if X[Px] in ['0'..'9'] then
        Nx := Nx * 10 + Ord(X[Px]) - Ord('0');
      Inc(Px);
    end;
    Inc(Px); // skip the dot (or move past end)
    Ny := 0;
    while (Py <= Length(Y)) and (Y[Py] <> '.') do
    begin
      if Y[Py] in ['0'..'9'] then
        Ny := Ny * 10 + Ord(Y[Py]) - Ord('0');
      Inc(Py);
    end;
    Inc(Py);
    if Nx > Ny then
      Exit(1);
    if Nx < Ny then
      Exit(-1);
    if (Px > Length(X)) and (Py > Length(Y)) then
      Exit(0);
  end;
end;

function FileSizeByName(const AFileName: string): Int64;
var
  SR: TSearchRec;
begin
  if FindFirst(AFileName, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    SysUtils.FindClose(SR);
  end
  else
    Result := -1;
end;

function DownloadFile(const AUrl, ADest: string; out AError: string): Boolean;
var
  Cli: TFPHTTPClient;
  FS: TFileStream;
begin
  Result := False;
  AError := '';
  EnsureSSLLibrary;
  Cli := TFPHTTPClient.Create(nil);
  try
    Cli.AllowRedirect := True;
    Cli.ConnectTimeout := 8000;
    Cli.IOTimeout := 60000;
    Cli.AddHeader('User-Agent', AppTitle + '/' + AppVersion);
    ForceDirectories(ExtractFilePath(ADest));
    FS := TFileStream.Create(ADest, fmCreate);
    try
      Cli.Get(AUrl, FS);
    finally
      FS.Free;
    end;
    Result := FileExists(ADest);
  except
    on E: Exception do
    begin
      AError := E.Message;
      if FileExists(ADest) then
        SysUtils.DeleteFile(ADest);
    end;
  end;
  Cli.Free;
end;

function FetchLatestRelease(const ARepo: string; out ATag: string;
  out AAssets: TUpdateAssetArray; out AError: string): Boolean;
var
  Cli: TFPHTTPClient;
  Res: string;
  J, Jd: TJSONData;
  JA: TJSONArray;
  I: Integer;
  A: TJSONObject;
begin
  Result := False;
  ATag := '';
  SetLength(AAssets, 0);
  AError := '';
  EnsureSSLLibrary;
  Cli := TFPHTTPClient.Create(nil);
  try
    Cli.AllowRedirect := True;
    Cli.ConnectTimeout := 8000;
    Cli.IOTimeout := 20000;
    Cli.AddHeader('User-Agent', AppTitle + '/' + AppVersion);
    Res := Cli.Get('https://api.github.com/repos/' + ARepo + '/releases/latest');
    J := GetJSON(Res);
    try
      Jd := J.GetPath('tag_name');
      if Jd <> nil then
        ATag := Jd.AsString;
      JA := TJSONArray(J.FindPath('assets'));
      if JA <> nil then
      begin
        SetLength(AAssets, JA.Count);
        for I := 0 to JA.Count - 1 do
        begin
          A := JA.Items[I] as TJSONObject;
          AAssets[I].Name := A.Get('name', '');
          AAssets[I].Url := A.Get('browser_download_url', '');
          AAssets[I].Size := A.Get('size', 0);
        end;
      end;
      Result := True;
    finally
      J.Free;
    end;
  except
    on E: Exception do
      AError := E.Message;
  end;
  Cli.Free;
end;

function CheckForUpdates(const ARepo: string; out ANewVersion: string;
  out AError: string): Boolean;
var
  Tag: string;
  Assets: TUpdateAssetArray;
begin
  ANewVersion := '';
  AError := '';
  if not FetchLatestRelease(ARepo, Tag, Assets, AError) then
  begin
    Result := False;
    if AError = '' then
      AError := 'Tidak dapat memeriksa pembaruan dari GitHub.';
    Exit;
  end;
  if CompareVersions(Tag, AppVersion) > 0 then
    ANewVersion := Tag;
  Result := True;
end;

function StageUpdates(const ARepo: string; const AStagingDir: string;
  out AError: string): Boolean;
var
  Tag: string;
  Assets: TUpdateAssetArray;
  I: Integer;
  Dest: string;
begin
  Result := False;
  AError := '';
  if not FetchLatestRelease(ARepo, Tag, Assets, AError) then
  begin
    if AError = '' then
      AError := 'Gagal mengambil rilis terbaru dari GitHub.';
    Exit;
  end;
  if Length(Assets) = 0 then
  begin
    AError := 'Rilis tidak memiliki file (aset) untuk diunduh.';
    Exit;
  end;
  ForceDirectories(AStagingDir);
  for I := 0 to High(Assets) do
  begin
    if Assets[I].Name = '' then
      Continue;
    Dest := IncludeTrailingPathDelimiter(AStagingDir) + Assets[I].Name;
    LogMsg('Mengunduh ' + Assets[I].Name);
    if not DownloadFile(Assets[I].Url, Dest, AError) then
    begin
      AError := 'Gagal mengunduh ' + Assets[I].Name + ': ' + AError;
      Exit;
    end;
    if (Assets[I].Size > 0) and (FileSizeByName(Dest) <> Assets[I].Size) then
    begin
      AError := 'Ukuran file tidak cocok: ' + Assets[I].Name;
      SysUtils.DeleteFile(Dest);
      Exit;
    end;
  end;
  Result := True;
end;

function SpawnSelfUpdate(const AStagedExe, AInstallExe: string;
  out AError: string): Boolean;
var
  Batch, Cmd: string;
  SI: TStartupInfo;
  PI: TProcessInformation;
  Created: Boolean;
begin
  Result := False;
  AError := '';
  Batch := IncludeTrailingPathDelimiter(GetAppDataDir) +
    'updates\apply-launcher.bat';
  ForceDirectories(IncludeTrailingPathDelimiter(GetAppDataDir) + 'updates');
  Cmd := '@echo off' + sLineBreak +
    ':wait' + sLineBreak +
    'tasklist /fi "imagename eq SmartOfficeDesktop.exe" | find /i "SmartOfficeDesktop.exe" >nul' + sLineBreak +
    'if not errorlevel 1 (' + sLineBreak +
    '  timeout /t 1 /nobreak >nul' + sLineBreak +
    '  goto wait' + sLineBreak +
    ')' + sLineBreak +
    'copy /y "' + AStagedExe + '" "' + AInstallExe + '" >nul' + sLineBreak +
    'if errorlevel 1 goto :fail' + sLineBreak +
    'start "" "' + AInstallExe + '"' + sLineBreak +
    'del "%~f0" >nul 2>&1' + sLineBreak +
    'exit /b 0' + sLineBreak +
    ':fail' + sLineBreak +
    'del "%~f0" >nul 2>&1' + sLineBreak +
    'exit /b 1';
  try
    with TStringList.Create do
    try
      Text := Cmd;
      SaveToFile(Batch);
    finally
      Free;
    end;
  except
    on E: Exception do
    begin
      AError := 'Gagal menyiapkan pembaruan: ' + E.Message;
      Exit;
    end;
  end;
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  FillChar(PI, SizeOf(PI), 0);
  Created := CreateProcess(nil, PChar('cmd.exe /c "' + Batch + '"'), nil, nil,
    False, CREATE_NO_WINDOW, nil, nil, SI, PI);
  if not Created then
  begin
    AError := 'Gagal memulai proses pembaruan: ' + SysErrorMessage(GetLastError);
    Exit;
  end;
  CloseHandle(PI.hThread);
  CloseHandle(PI.hProcess);
  Result := True;
end;

function ApplyStagedUpdates(const AStagingDir: string;
  out ALauncherUpdated: Boolean; out AError: string): Boolean;
var
  SR: TSearchRec;
  Base, Dest, Src: string;
  LauncherStaged: Boolean;
begin
  Result := False;
  ALauncherUpdated := False;
  AError := '';
  LauncherStaged := False;
  Base := IncludeTrailingPathDelimiter(AStagingDir);

  // Terminate running module executables so their files are not locked.
  TerminateLaunchedModules;

  if FindFirst(Base + '*.exe', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        Src := Base + SR.Name;
        if CompareText(SR.Name, 'SmartOfficeDesktop.exe') = 0 then
        begin
          LauncherStaged := True;
          Continue;
        end;
        if Pos('SIMRS-', SR.Name) = 1 then
          Dest := AppExeDir + 'apps\' + SR.Name
        else
          Dest := AppExeDir + SR.Name;
        LogMsg('Memasang ' + SR.Name + ' -> ' + Dest);
        if not CopyFile(PChar(Src), PChar(Dest), False) then
        begin
          AError := 'Gagal menyalin ' + SR.Name +
            ' (' + SysErrorMessage(GetLastError) + ')';
          Exit;
        end;
      until FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
    end;
  end;

  // Copy non-EXE assets (e.g. DLLs) to the launcher root.
  if FindFirst(Base + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Attr and faDirectory) <> 0 then
          Continue;
        if LowerCase(ExtractFileExt(SR.Name)) = '.exe' then
          Continue;
        Src := Base + SR.Name;
        Dest := AppExeDir + SR.Name;
        LogMsg('Memasang ' + SR.Name + ' -> ' + Dest);
        if not CopyFile(PChar(Src), PChar(Dest), False) then
        begin
          AError := 'Gagal menyalin ' + SR.Name +
            ' (' + SysErrorMessage(GetLastError) + ')';
          Exit;
        end;
      until FindNext(SR) <> 0;
    finally
      SysUtils.FindClose(SR);
    end;
  end;

  if LauncherStaged then
  begin
    if not SpawnSelfUpdate(Base + 'SmartOfficeDesktop.exe',
      AppExeDir + 'SmartOfficeDesktop.exe', AError) then
      Exit;
    ALauncherUpdated := True;
  end;

  Result := True;
end;

end.
