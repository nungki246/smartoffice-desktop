program SIMRSPendaftaran;

{
  SmartOffice Desktop - Pendaftaran module (standalone executable).
  Launched by the SmartOffice Desktop launcher with --user and --token.
}

{$mode objfpc}{$H+}

uses
  Interfaces,
  Forms,
  SysUtils,
  Dialogs,
  Graphics,
  uApp,
  uRBAC,
  uLaunch,
  uModuleHost,
  uPendaftaranView,
  uIcons,
  uTheme;

var
  UserName, Token: string;



procedure SetAppIcon;
var
  Bmp: TBitmap;
  Ico: TIcon;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(32, 32);
    Bmp.PixelFormat := pf32bit;
    DrawAppIcon(Bmp, RGBToColor(31, 78, 121), gDocument);
    Ico := TIcon.Create;
    try
      Ico.Assign(Bmp);
      Application.Icon := Ico;
    finally
      Ico.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

begin
  Application.Scaled := True;
  Application.Initialize;
  InstallExceptionHandler;
  SetAppIcon;
  if not EnsureSingleInstance('Pendaftaran') then
    Exit;
  InitApp;
  try
    AppDB.ConnectFromConfig;
    if not AppDB.Connected then
      raise Exception.Create('Database tidak terhubung: ' + AppDB.LastError);
    RBAC.EnsureSchema;
    GetModuleAuth(UserName, Token);
    if IsDevMode then
      RBAC.LoginDev
    else
      RBAC.LoginWithToken(UserName, Token);
    if not RBAC.IsLoggedIn then
      raise Exception.Create('Sesi tidak valid atau telah kedaluwarsa.' + sLineBreak +
        'Buka modul melalui SmartOffice Desktop.');
    Application.CreateForm(TModuleHostForm, ModuleHostForm);
    ModuleHostForm.Setup('Pendaftaran', TPendaftaranView.Create(nil));
    LogMsg('Modul Pendaftaran dibuka oleh ' + RBAC.Username);
    Application.Run;
  except
    on E: Exception do
    begin
      LogMsg('Pendaftaran: ' + E.ClassName + ' at ' +
        IntToHex(PtrUInt(ExceptAddr), 8) + ': ' + E.Message);
      MessageDlg('Kesalahan', E.Message, mtError, [mbOK], 0);
    end;
  end;
  DoneApp;
end.

