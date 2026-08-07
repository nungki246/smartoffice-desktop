unit uConfig;

{
  SmartOffice Desktop - application configuration.
  Persisted as an INI file next to the executable.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles;

type
  TAppConfig = class
  private
    FIni: TIniFile;
    FDbHost: string;
    FDbPort: Integer;
    FDbUser: string;
    FDbPassword: string;
    FDbName: string;
    FUsePostgres: Boolean;
    FSqliteFile: string;
    FLastModule: string;
    FMainWidth: Integer;
    FMainHeight: Integer;
    FShowNavPanel: Boolean;
    FUpdateRepo: string;
    FExternalApps: TStringList;
    procedure Load;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Save;

    function GetExternalAppPath(const AKey: string): string;
    procedure SetExternalAppPath(const AKey, APath: string);

    property DbHost: string read FDbHost write FDbHost;
    property DbPort: Integer read FDbPort write FDbPort;
    property DbUser: string read FDbUser write FDbUser;
    property DbPassword: string read FDbPassword write FDbPassword;
    property DbName: string read FDbName write FDbName;
    property UsePostgres: Boolean read FUsePostgres write FUsePostgres;
    property SqliteFile: string read FSqliteFile write FSqliteFile;
    property LastModule: string read FLastModule write FLastModule;
    property MainWidth: Integer read FMainWidth write FMainWidth;
    property MainHeight: Integer read FMainHeight write FMainHeight;
    property ShowNavPanel: Boolean read FShowNavPanel write FShowNavPanel;
    property UpdateRepo: string read FUpdateRepo write FUpdateRepo;
    property ExternalApps: TStringList read FExternalApps;
  end;

implementation

uses
  uPaths, Windows, base64;

type
  PDATA_BLOB = ^TDATA_BLOB;
  TDATA_BLOB = record
    cbData: DWORD;
    pbData: PByte;
  end;

const
  CRYPTPROTECT_UI_FORBIDDEN = $1;
  DPAPIPrefix = 'DPAPI:';

function CryptProtectData(pDataIn: PDATA_BLOB; szDataDescr: PWideChar;
  pOptionalEntropy: PDATA_BLOB; pvReserved: Pointer; pPromptStruct: Pointer;
  dwFlags: DWORD; pDataOut: PDATA_BLOB): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptProtectData';

function CryptUnprotectData(pDataIn: PDATA_BLOB; ppszDataDescr: PPWideChar;
  pOptionalEntropy: PDATA_BLOB; pvReserved: Pointer; pPromptStruct: Pointer;
  dwFlags: DWORD; pDataOut: PDATA_BLOB): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptUnprotectData';

// ProtectString encrypts AValue with the current user's DPAPI key. The result
// is bound to this Windows user account and this machine.
function ProtectString(const AValue: string): string;
var
  InBlob, OutBlob: TDATA_BLOB;
  Blob: AnsiString;
begin
  Result := '';
  if AValue = '' then
    Exit;
  SetLength(Blob, Length(AValue));
  Move(AValue[1], Blob[1], Length(AValue));
  InBlob.cbData := Length(Blob);
  InBlob.pbData := PByte(@Blob[1]);
  OutBlob.cbData := 0;
  OutBlob.pbData := nil;
  if CryptProtectData(@InBlob, nil, nil, nil, nil,
    CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then
  begin
    try
      SetLength(Blob, OutBlob.cbData);
      Move(OutBlob.pbData^, Blob[1], OutBlob.cbData);
      Result := EncodeStringBase64(Blob);
    finally
      LocalFree(HLOCAL(OutBlob.pbData));
    end;
  end;
end;

function UnprotectString(const AEncoded: string): string;
var
  InBlob, OutBlob: TDATA_BLOB;
  Blob: AnsiString;
begin
  Result := '';
  if AEncoded = '' then
    Exit;
  try
    Blob := DecodeStringBase64(AEncoded);
  except
    Exit;
  end;
  InBlob.cbData := Length(Blob);
  InBlob.pbData := PByte(@Blob[1]);
  OutBlob.cbData := 0;
  OutBlob.pbData := nil;
  if CryptUnprotectData(@InBlob, nil, nil, nil, nil,
    CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then
  begin
    try
      SetLength(Result, OutBlob.cbData);
      if OutBlob.cbData > 0 then
        Move(OutBlob.pbData^, Result[1], OutBlob.cbData);
    finally
      LocalFree(HLOCAL(OutBlob.pbData));
    end;
  end;
end;

{ TAppConfig }

constructor TAppConfig.Create;
begin
  inherited Create;
  FIni := TIniFile.Create(GetConfigFileName);
  FExternalApps := TStringList.Create;
  // defaults
  FDbHost := 'localhost';
  FDbPort := 5433;
  FDbUser := 'postgres';
  FDbPassword := 'admin';
  FDbName := 'smartoffice';
  FUsePostgres := True;
  FSqliteFile := GetAppDataFileName('smartoffice.db');
  FLastModule := 'home';
  FMainWidth := 1080;
  FMainHeight := 680;
  FShowNavPanel := True;
  FUpdateRepo := '';
  Load;
end;

destructor TAppConfig.Destroy;
begin
  FExternalApps.Free;
  FIni.Free;
  inherited Destroy;
end;

procedure TAppConfig.Load;
var
  I: Integer;
  S: string;
begin
  FDbHost := FIni.ReadString('Database', 'Host', FDbHost);
  FDbPort := FIni.ReadInteger('Database', 'Port', FDbPort);
  FDbUser := FIni.ReadString('Database', 'User', FDbUser);
  S := FIni.ReadString('Database', 'Password', '');
  if Copy(S, 1, Length(DPAPIPrefix)) = DPAPIPrefix then
    FDbPassword := UnprotectString(Copy(S, Length(DPAPIPrefix) + 1, MaxInt))
  else
    FDbPassword := S; // legacy plaintext value -> re-encrypted on next Save
  FDbName := FIni.ReadString('Database', 'Name', FDbName);
  FUsePostgres := FIni.ReadBool('Database', 'UsePostgres', FUsePostgres);
  FSqliteFile := FIni.ReadString('Database', 'SqliteFile', FSqliteFile);
  FLastModule := FIni.ReadString('App', 'LastModule', FLastModule);
  FMainWidth := FIni.ReadInteger('App', 'MainWidth', FMainWidth);
  FMainHeight := FIni.ReadInteger('App', 'MainHeight', FMainHeight);
  FShowNavPanel := FIni.ReadBool('App', 'ShowNavPanel', FShowNavPanel);
  FUpdateRepo := Trim(FIni.ReadString('Update', 'Repo', FUpdateRepo));
  FIni.ReadSection('ExternalApps', FExternalApps);
  for I := 0 to FExternalApps.Count - 1 do
    FExternalApps[I] := FExternalApps[I] + '=' +
      FIni.ReadString('ExternalApps', FExternalApps[I], '');
end;

procedure TAppConfig.Save;
var
  I: Integer;
  EncPw: string;
begin
  FIni.WriteString('Database', 'Host', FDbHost);
  FIni.WriteInteger('Database', 'Port', FDbPort);
  FIni.WriteString('Database', 'User', FDbUser);
  EncPw := ProtectString(FDbPassword);
  if EncPw = '' then
    FIni.WriteString('Database', 'Password', '')
  else
    FIni.WriteString('Database', 'Password', DPAPIPrefix + EncPw);
  FIni.WriteString('Database', 'Name', FDbName);
  FIni.WriteBool('Database', 'UsePostgres', FUsePostgres);
  FIni.WriteString('Database', 'SqliteFile', FSqliteFile);
  FIni.WriteString('App', 'LastModule', FLastModule);
  FIni.WriteInteger('App', 'MainWidth', FMainWidth);
  FIni.WriteInteger('App', 'MainHeight', FMainHeight);
  FIni.WriteBool('App', 'ShowNavPanel', FShowNavPanel);
  FIni.WriteString('Update', 'Repo', FUpdateRepo);
  FIni.EraseSection('ExternalApps');
  for I := 0 to FExternalApps.Count - 1 do
    FIni.WriteString('ExternalApps', FExternalApps.Names[I], FExternalApps.ValueFromIndex[I]);
  FIni.UpdateFile;
end;

function TAppConfig.GetExternalAppPath(const AKey: string): string;
var
  Idx: Integer;
begin
  Idx := FExternalApps.IndexOfName(AKey);
  if Idx >= 0 then
    Result := FExternalApps.ValueFromIndex[Idx]
  else
    Result := '';
end;

procedure TAppConfig.SetExternalAppPath(const AKey, APath: string);
var
  Idx: Integer;
begin
  Idx := FExternalApps.IndexOfName(AKey);
  if Idx >= 0 then
    FExternalApps[Idx] := AKey + '=' + APath
  else
    FExternalApps.Add(AKey + '=' + APath);
end;

end.
