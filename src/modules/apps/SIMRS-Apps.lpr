program SIMRSApps;

{
  SmartOffice Desktop - Manajemen Aplikasi module (standalone executable).
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
  uAppsView,
  uIcons,
  uTheme;

var
  UserName, Token: string;
  V: TAppsView;



procedure SetAppIcon;
var
  Bmp: TBitmap;
  Ico: TIcon;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(32, 32);
    Bmp.PixelFormat := pf32bit;
    DrawAppIcon(Bmp, RGBToColor(31, 78, 121), gPackage);
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
  if not EnsureSingleInstance('ManajemenAplikasi') then
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
    V := TAppsView.Create(nil);
    V.RefreshData;
    ModuleHostForm.Setup('Manajemen Aplikasi', V);
    LogMsg('Modul Manajemen Aplikasi dibuka oleh ' + RBAC.Username);
    Application.Run;
  except
    on E: Exception do
    begin
      LogMsg('Manajemen Aplikasi: ' + E.Message);
      MessageDlg('Kesalahan', E.Message, mtError, [mbOK], 0);
    end;
  end;
  DoneApp;
end.

