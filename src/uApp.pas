unit uApp;

{
  SmartOffice Desktop - application globals.
  Owns the shared services used by every module:
    * AppConfig - persisted settings (INI file)
    * AppDB     - database connection manager

  Logging is safe for concurrent processes (launcher + module executables
  write to the same file), size-limited (auto-rotation) and used by the
  global exception handler to capture unhandled errors.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, uConfig, uDB, uRBAC, uApps;

const
  MaxLogSize = 4 * 1024 * 1024; // 4 MB before rotating to smartoffice.log.1

type
  TAppExceptionHandler = class
    procedure Handle(Sender: TObject; E: Exception);
  end;

var
  AppConfig: TAppConfig = nil;
  AppDB: TDatabaseManager = nil;
  Apps: TAppsService = nil;

procedure InitApp;
procedure DoneApp;
procedure LogMsg(const AMessage: string);
procedure InstallExceptionHandler;

implementation

uses
  Windows, Dialogs, uPaths;

var
  AppExceptionHandler: TAppExceptionHandler = nil;
  LogMutex: THandle = 0;   // created lazily, reused for the whole process
  LogWrites: Integer = 0;  // throttles the rotation size check

function LogFilePath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppDataDir) + 'smartoffice.log';
end;

procedure RotateLog(const ALogPath: string);
var
  BackupPath: string;
begin
  BackupPath := ChangeFileExt(ALogPath, '.log.1');
  if SysUtils.FileExists(BackupPath) then
    SysUtils.DeleteFile(BackupPath);
  SysUtils.RenameFile(ALogPath, BackupPath);
end;

function OpenLogStream(const ALogPath: string): TFileStream;
begin
  if SysUtils.FileExists(ALogPath) then
    Result := TFileStream.Create(ALogPath, fmOpenReadWrite or fmShareDenyNone)
  else
    Result := TFileStream.Create(ALogPath, fmCreate or fmShareDenyNone);
  Result.Seek(0, soFromEnd);
end;

procedure LogMsg(const AMessage: string);
var
  Fs: TFileStream;
  Line: string;
  LogPath: string;
begin
  try
    LogPath := LogFilePath;

    // Reuse one named mutex for the process lifetime (created lazily) instead
    // of creating and destroying a kernel object on every single log call.
    if LogMutex = 0 then
      LogMutex := CreateMutexA(nil, False, PAnsiChar('Local\SmartOfficeDesktopLog'));
    if LogMutex <> 0 then
      WaitForSingleObject(LogMutex, 5000);
    try
      // A stream is opened per line because multiple processes (launcher + app)
      // share this file. A persistent handle would lack FILE_SHARE_DELETE and
      // make the 4 MB rotation rename fail when a peer holds the file open.
      Fs := OpenLogStream(LogPath);
      try
        // Rotation: check the size on the already-open handle, but only every
        // 32nd write so the shared 4 MB file is not re-stated per line.
        Inc(LogWrites);
        if (LogWrites and 31) = 0 then
        begin
          if Fs.Size >= MaxLogSize then
          begin
            Fs.Free;
            Fs := nil;
            RotateLog(LogPath);
            Fs := OpenLogStream(LogPath);
          end;
        end;
        Line := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + AMessage + sLineBreak;
        Fs.Write(Line[1], Length(Line));
      finally
        Fs.Free;
      end;
    finally
      if LogMutex <> 0 then
        ReleaseMutex(LogMutex);
    end;
  except
    // ignore logging errors
  end;
end;

procedure TAppExceptionHandler.Handle(Sender: TObject; E: Exception);
begin
  try
    LogMsg('UNHANDLED[' + ExtractFileName(ParamStr(0)) + ']: ' + E.ClassName + ': ' +
      E.Message + ' @ ' + BackTraceStrFunc(ExceptAddr));
    MessageDlg('Kesalahan', 'Terjadi kesalahan yang tidak terduga:' + sLineBreak +
      E.Message, mtError, [mbOK], 0);
  except
    // never raise from the exception handler
  end;
end;

procedure InstallExceptionHandler;
begin
  if AppExceptionHandler = nil then
    AppExceptionHandler := TAppExceptionHandler.Create;
  Application.OnException := @AppExceptionHandler.Handle;
end;

procedure InitApp;
begin
  AppConfig := TAppConfig.Create;
  AppDB := TDatabaseManager.Create;
  RBAC := TRBACService.Create(AppDB);
  Apps := TAppsService.Create(AppDB);
end;

procedure DoneApp;
begin
  if LogMutex <> 0 then
  begin
    CloseHandle(LogMutex);
    LogMutex := 0;
  end;
  AppExceptionHandler.Free;
  AppExceptionHandler := nil;
  Apps.Free;
  Apps := nil;
  RBAC.Free;
  RBAC := nil;
  AppDB.Free;
  AppDB := nil;
  AppConfig.Free;
  AppConfig := nil;
end;

end.
