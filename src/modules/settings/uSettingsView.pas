unit uSettingsView;

{
  SmartOffice Desktop - Settings view.
  Shows the current database configuration and opens the connection dialog.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls, StdCtrls, uModuleView;

type
  TSettingsView = class(TModuleView)
  private
    FInfo: TMemo;
    procedure OpenSettings(Sender: TObject);
    procedure RefreshInfo;
  protected
    procedure BuildUI; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  Dialogs, Forms, uApp, uConfig, uSettingsForm, uTheme;

{$R *.lfm}

{ TSettingsView }

constructor TSettingsView.Create(AOwner: TComponent);
begin
  ModuleId := 'settings';
  inherited Create(AOwner);
end;

procedure TSettingsView.BuildUI;
var
  Pnl: TPanel;
  Lbl: TLabel;
  Btn: TButton;
begin
  inherited BuildUI;
  Color := AppTheme.ColorBackgroundAlt;

  Pnl := TPanel.Create(Self);
  Pnl.Parent := Self;
  Pnl.Align := alTop;
  Pnl.Height := 120;
  Pnl.BevelOuter := bvNone;
  Pnl.Color := AppTheme.ColorBackgroundAlt;

  Lbl := TLabel.Create(Pnl);
  Lbl.Parent := Pnl;
  Lbl.Left := 24; Lbl.Top := 20;
  Lbl.Font.Size := AppTheme.FontSizeXL;
  Lbl.Font.Name := AppTheme.FontFamily;
  Lbl.Font.Style := [fsBold];
  Lbl.Caption := 'Pengaturan';
  Lbl.AutoSize := True;

  Btn := TButton.Create(Pnl);
  Btn.Parent := Pnl;
  Btn.Caption := 'Buka Pengaturan Koneksi...';
  Btn.Left := 24; Btn.Top := 60;
  Btn.Width := 220;
  Btn.OnClick := @OpenSettings;

  FInfo := TMemo.Create(Self);
  FInfo.Parent := Self;
  FInfo.Align := alClient;
  FInfo.BorderSpacing.Left := 24;
  FInfo.BorderSpacing.Right := 24;
  FInfo.BorderSpacing.Top := 12;
  FInfo.BorderSpacing.Bottom := 24;
  FInfo.ReadOnly := True;
  FInfo.Color := AppTheme.ColorBackground;
  FInfo.Font.Name := AppTheme.FontFamily;
  FInfo.Font.Size := AppTheme.FontSizeMD;
  FInfo.BorderStyle := bsNone;

  RefreshInfo;
end;

procedure TSettingsView.RefreshInfo;
var
  S: string;
begin
  if AppConfig.UsePostgres then
    S := 'Backend   : PostgreSQL' + sLineBreak +
         'Host      : ' + AppConfig.DbHost + ':' + IntToStr(AppConfig.DbPort) + sLineBreak +
         'Pengguna  : ' + AppConfig.DbUser + sLineBreak +
         'Database  : ' + AppConfig.DbName + sLineBreak
  else
    S := 'Backend   : SQLite' + sLineBreak +
         'File      : ' + AppConfig.SqliteFile + sLineBreak;

  if AppDB.Connected then
    S := S + sLineBreak + 'Status    : TERHUBUNG  (' + AppDB.ServerVersion + ')'
  else
    S := S + sLineBreak + 'Status    : TIDAK TERHUBUNG' + sLineBreak +
         'Pesan     : ' + AppDB.LastError;

  if FInfo <> nil then
    FInfo.Text := S;
end;

procedure TSettingsView.OpenSettings(Sender: TObject);
var
  Frm: TSettingsForm;
begin
  Frm := TSettingsForm.Create(Application);
  try
    Frm.ShowModal;
    RefreshInfo;
  finally
    Frm.Free;
  end;
end;

end.
