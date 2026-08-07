unit uPaths;

{
  SmartOffice Desktop - path helpers.
  Config and data files live in a per-user application data directory.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

function GetAppDir: string;
function GetConfigFileName: string;
function GetAppDataDir: string;
function GetAppDataFileName(const AFileName: string): string;

implementation

uses
  ShlObj, Windows;

function GetAppDir: string;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

function GetAppDataDir: string;
var
  LPath: array[0..MAX_PATH] of Char;
begin
  if SHGetFolderPath(0, CSIDL_APPDATA, 0, 0, @LPath) = S_OK then
    Result := IncludeTrailingPathDelimiter(LPath) + 'SmartOfficeDesktop'
  else
    Result := IncludeTrailingPathDelimiter(GetAppDir) + 'data';
  ForceDirectories(Result);
end;

function GetConfigFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppDataDir) + 'smartoffice.ini';
end;

function GetAppDataFileName(const AFileName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppDataDir) + AFileName;
end;

end.
