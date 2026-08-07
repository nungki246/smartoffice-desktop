unit uLoginForm;

{
  SmartOffice Desktop - login dialog.
  Validates credentials against the users table via the RBAC service.

  Split-panel layout: left = colored brand panel, right = white form panel.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls;

type

  { TLoginForm }

  TLoginForm = class(TForm)
  published
    PnlBackground: TPanel;
    PnlLeft: TPanel;
    PnlRight: TPanel;
    LblAppIcon: TLabel;
    LblAppName: TLabel;
    LblAppTagline: TLabel;
    LblVersion: TLabel;
    LblTitle: TLabel;
    LblSubtitle: TLabel;
    LblUserCap: TLabel;
    PnlUserWrap: TPanel;
    EdUser: TEdit;
    LblPassCap: TLabel;
    PnlPassWrap: TPanel;
    EdPass: TEdit;
    PnlBtnLogin: TPanel;
    LblBtnLogin: TLabel;
    LblStatus: TLabel;
    LblClose: TLabel;
    procedure DoLogin(Sender: TObject);
    procedure EdKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure LblCloseClick(Sender: TObject);
    procedure LblCloseMouseEnter(Sender: TObject);
    procedure LblCloseMouseLeave(Sender: TObject);
    procedure PnlBackgroundMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure EdEnter(Sender: TObject);
    procedure EdExit(Sender: TObject);
    procedure BtnLoginMouseEnter(Sender: TObject);
    procedure BtnLoginMouseLeave(Sender: TObject);
  private
    FInputIdle: TColor;
    FInputFocus: TColor;
    procedure DoShow; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

function ShowLoginDialog: Boolean;

implementation

uses
  Dialogs, LCLType, Windows, Messages, uApp, uRBAC, uAudit, uTheme;

{$R *.lfm}

function ShowLoginDialog: Boolean;
var
  Frm: TLoginForm;
begin
  Result := False;
  Frm := TLoginForm.Create(Application);
  try
    Frm.FormStyle := fsStayOnTop;
    if Frm.ShowModal = mrOK then
      Result := RBAC.IsLoggedIn;
  finally
    Frm.Free;
  end;
end;

{ TLoginForm }

constructor TLoginForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  EdUser.OnEnter := @EdEnter;
  EdUser.OnExit := @EdExit;
  EdPass.OnEnter := @EdEnter;
  EdPass.OnExit := @EdExit;
  PnlBtnLogin.OnMouseEnter := @BtnLoginMouseEnter;
  PnlBtnLogin.OnMouseLeave := @BtnLoginMouseLeave;
  LblBtnLogin.OnMouseEnter := @BtnLoginMouseEnter;
  LblBtnLogin.OnMouseLeave := @BtnLoginMouseLeave;
end;

procedure TLoginForm.DoShow;
begin
  inherited DoShow;

  // Apply Theme Fonts globally
  Font.Name := AppTheme.FontFamily;
  Font.Size := AppTheme.FontSizeMD;

  // Form Color = border color (primary blue, 2px visible around PnlBackground)
  Color := AppTheme.ColorPrimary;

  // Make PnlBackground fill form minus 2px border on all sides
  PnlBackground.SetBounds(2, 2, ClientWidth - 4, ClientHeight - 4);

  // ---- Left brand panel (Primary color) ----
  PnlLeft.Color := AppTheme.ColorPrimary;
  LblAppIcon.Font.Color := clWhite;
  LblAppName.Font.Color := clWhite;
  LblAppName.Font.Name := AppTheme.FontFamily;
  LblAppTagline.Font.Color := RGBToColor(180, 225, 255);
  LblVersion.Font.Color := RGBToColor(150, 200, 240);

  // ---- Right form panel (White / Surface) ----
  PnlRight.Color := AppTheme.ColorSurface;

  LblTitle.Font.Color := AppTheme.ColorTextPrimary;
  LblTitle.Font.Size := AppTheme.FontSizeXL;

  LblSubtitle.Font.Color := AppTheme.ColorTextSecondary;
  LblSubtitle.Font.Size := AppTheme.FontSizeSM;

  LblUserCap.Font.Color := AppTheme.ColorTextPrimary;
  LblUserCap.Font.Size := AppTheme.FontSizeSM;

  LblPassCap.Font.Color := AppTheme.ColorTextPrimary;
  LblPassCap.Font.Size := AppTheme.FontSizeSM;

  // Input: wrapper panel = border color, Edit inset 1px to show border
  FInputIdle  := AppTheme.ColorSurface;     // Input background
  FInputFocus := AppTheme.ColorSurface;     // Same when focused

  // Idle border (abu-abu)
  PnlUserWrap.Color := AppTheme.ColorBorder;
  PnlPassWrap.Color := AppTheme.ColorBorder;
  EdUser.Color := FInputIdle;
  EdPass.Color := FInputIdle;
  EdUser.Font.Color := AppTheme.ColorTextPrimary;
  EdPass.Font.Color := AppTheme.ColorTextPrimary;
  EdUser.Font.Size := AppTheme.FontSizeMD;
  EdPass.Font.Size := AppTheme.FontSizeMD;

  // Position Edit with exactly 1px inset on all sides → uniform thin 1px border
  EdUser.SetBounds(1, 1, PnlUserWrap.ClientWidth - 2, PnlUserWrap.ClientHeight - 2);
  EdPass.SetBounds(1, 1, PnlPassWrap.ClientWidth - 2, PnlPassWrap.ClientHeight - 2);

  // Login button
  PnlBtnLogin.Color := AppTheme.ColorPrimary;
  LblBtnLogin.Font.Color := clWhite;
  LblBtnLogin.Font.Size := AppTheme.FontSizeMD;

  // Status label
  LblStatus.Font.Color := AppTheme.ColorError;

  BringToFront;
  SetWindowPos(Handle, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_SHOWWINDOW);
  SetForegroundWindow(Handle);
  SetActiveWindow(Handle);
end;

procedure TLoginForm.DoLogin(Sender: TObject);
var
  Ok: Boolean;
begin
  LblStatus.Caption := '';
  LogMsg('Login: mencoba ' + Trim(EdUser.Text));
  if (Trim(EdUser.Text) = '') or (EdPass.Text = '') then
  begin
    LblStatus.Caption := 'Isi pengguna dan kata sandi.';
    Exit;
  end;
  Ok := False;
  try
    Ok := RBAC.Login(Trim(EdUser.Text), EdPass.Text);
  except
    on E: Exception do
    begin
      LogMsg('Login: exception ' + E.ClassName + ': ' + E.Message);
      LblStatus.Caption := 'Kesalahan sistem saat login: ' + E.Message;
      Exit;
    end;
  end;
  if Ok then
  begin
    LogMsg('Login: berhasil untuk ' + RBAC.Username);
    AuditLog('LOGIN', 'auth', RBAC.User.UserId, 'Login: ' + RBAC.Username);
    ModalResult := mrOK;
  end
  else
  begin
    LogMsg('Login: gagal untuk ' + Trim(EdUser.Text) +
      ' (err=' + RBAC.LastError + ')');
    AuditLog('LOGIN', 'auth', 0, 'Gagal login: ' + Trim(EdUser.Text));
    LblStatus.Caption := 'Pengguna atau kata sandi salah, atau akun nonaktif.';
    if RBAC.LastError <> '' then
      LblStatus.Caption := LblStatus.Caption + sLineBreak + RBAC.LastError;
    EdPass.SelectAll;
  end;
end;

procedure TLoginForm.EdKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
    DoLogin(Sender);
end;

procedure TLoginForm.LblCloseClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TLoginForm.LblCloseMouseEnter(Sender: TObject);
begin
  LblClose.Font.Color := AppTheme.ColorError;
end;

procedure TLoginForm.LblCloseMouseLeave(Sender: TObject);
begin
  LblClose.Font.Color := clGray;
end;

procedure TLoginForm.PnlBackgroundMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    ReleaseCapture;
    SendMessage(Handle, WM_SYSCOMMAND, $F012, 0);
  end;
end;

procedure TLoginForm.EdEnter(Sender: TObject);
begin
  // On focus: border turns primary blue (Fluent focus ring)
  if Sender = EdUser then
    PnlUserWrap.Color := AppTheme.ColorBorderFocus
  else if Sender = EdPass then
    PnlPassWrap.Color := AppTheme.ColorBorderFocus;
end;

procedure TLoginForm.EdExit(Sender: TObject);
begin
  // On blur: back to grey border
  if Sender = EdUser then
    PnlUserWrap.Color := AppTheme.ColorBorder
  else if Sender = EdPass then
    PnlPassWrap.Color := AppTheme.ColorBorder;
end;

procedure TLoginForm.BtnLoginMouseEnter(Sender: TObject);
begin
  PnlBtnLogin.Color := AppTheme.ColorPrimaryHover;
end;

procedure TLoginForm.BtnLoginMouseLeave(Sender: TObject);
begin
  PnlBtnLogin.Color := AppTheme.ColorPrimary;
end;

end.
