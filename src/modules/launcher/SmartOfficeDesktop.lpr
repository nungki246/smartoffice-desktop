program SmartOfficeDesktop;

{
  SmartOffice Desktop Launcher 1.0
  Desktop Application Framework - Windows (Lazarus / Free Pascal)
  Arsitektur Modular / Plugin
  Keamanan    : RBAC (Peran, Hak Akses, Pengguna)
}

{$mode objfpc}{$H+}

uses
  Interfaces,          // LCL widgetset
  Forms,
  SysUtils,
  Dialogs,
  Graphics,            // for TIcon
  uApp,                // app globals (config + database + services)
  uRBAC,               // RBAC globals (RBAC service, session)
  uLaunch,             // single-instance enforcement
  uLoginForm,
  uModuleManager,
  uMainForm,
  uIcons,              // programmatic icons
  uTheme;              // theme colors

{$R *.res}

procedure SetAppIcon;
var
  Bmp: TBitmap;
  Ico: TIcon;
begin
  // Create a 32x32 application icon using the programmatic glyph system
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(32, 32);
    Bmp.PixelFormat := pf32bit;
    // Use the home glyph (gHome) with primary theme color
    DrawAppIcon(Bmp, RGBToColor(31, 78, 121), gHome);
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
  RequireDerivedFormResource := True;
  Application.Scaled := True;
  Application.Initialize;
  InstallExceptionHandler;

  // Set application icon (programmatic, so no external .ico file needed)
  SetAppIcon;

  // Only one launcher per desktop session: launching again just brings the
  // existing window to the foreground instead of starting a second instance.
  if not EnsureSingleInstance('Launcher') then
  begin
    if not FocusExistingWindow('SmartOffice Desktop Launcher') then
      ShowMessage('SmartOffice Desktop sudah berjalan.');
    Exit;
  end;

  InitApp;
  RegisterAllModules;
  ModuleManager.LoadAll;

  try
    AppDB.ConnectFromConfig;
    if AppDB.Connected then
      RBAC.EnsureSchema;
  except
    on E: Exception do
      LogMsg('Startup: ' + E.ClassName + ': ' + E.Message);
  end;

  if not AppDB.Connected then
  begin
    ShowMessage('Database tidak terhubung.' + sLineBreak + sLineBreak +
      'Periksa koneksi PostgreSQL/SQLite pada file smartoffice.ini ' +
      'di folder %APPDATA%\SmartOfficeDesktop sebelum masuk.');
    DoneApp;
    Exit;
  end;

  Application.CreateForm(TMainForm, MainForm);
  Application.ShowMainForm := False;
  MainForm.Show;
  Application.ProcessMessages;

  if ShowLoginDialog then
  begin
    LogMsg('Login diterima. Membuat sesi aplikasi...');
    RBAC.CreateSession;
    if RBAC.SessionToken = '' then
      LogMsg('PERINGATAN: gagal membuat sesi aplikasi (err=' + RBAC.LastError + ').');
    MainForm.AfterLogin;
    LogMsg('Form utama dibuat, menjalankan aplikasi...');
  end
  else
  begin
    // Login dialog was cancelled/closed: exit the app.
    LogMsg('Login dibatalkan atau gagal. Menutup aplikasi.');
    MainForm.Close;
    Exit;
  end;
  Application.Run;

  DoneApp;
end.
