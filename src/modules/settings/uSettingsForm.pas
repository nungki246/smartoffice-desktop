unit uSettingsForm;

{
  SmartOffice Desktop - database connection settings dialog.

  Level 2 form: all controls live in the .lfm so the Lazarus designer
  can open and edit them visually.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls, Dialogs;

type
  TSavedCallback = procedure of object;

  TSettingsForm = class(TForm)
  published
    PnlSettings: TPanel;
    LblUsePg: TLabel;
    ChkPostgres: TCheckBox;
    LblHost: TLabel;
    EdHost: TEdit;
    LblPort: TLabel;
    EdPort: TEdit;
    LblUser: TLabel;
    EdUser: TEdit;
    LblPass: TLabel;
    EdPassword: TEdit;
    LblName: TLabel;
    EdName: TEdit;
    LblSqlite: TLabel;
    EdSqlite: TEdit;
    LblRepo: TLabel;
    EdRepo: TEdit;
    LblDbState: TLabel;
    BtnTest: TButton;
    BtnSave: TButton;
    BtnCancel: TButton;
    procedure DoTest(Sender: TObject);
    procedure DoSave(Sender: TObject);
    procedure DoCancel(Sender: TObject);
  private
    FOnSaved: TSavedCallback;
    procedure LoadFromConfig;
    function TryTestConnection: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    property OnSaved: TSavedCallback read FOnSaved write FOnSaved;
  end;

implementation

uses
  uApp, uConfig, uDB, uPaths;

{$R *.lfm}

{ TSettingsForm }

constructor TSettingsForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  LoadFromConfig;
end;

procedure TSettingsForm.LoadFromConfig;
begin
  ChkPostgres.Checked := AppConfig.UsePostgres;
  EdHost.Text := AppConfig.DbHost;
  EdPort.Text := IntToStr(AppConfig.DbPort);
  EdUser.Text := AppConfig.DbUser;
  EdPassword.Text := AppConfig.DbPassword;
  EdName.Text := AppConfig.DbName;
  EdSqlite.Text := AppConfig.SqliteFile;
  EdRepo.Text := AppConfig.UpdateRepo;
end;

function TSettingsForm.TryTestConnection: Boolean;
var
  DB: TDatabaseManager;
begin
  DB := TDatabaseManager.Create;
  try
    if ChkPostgres.Checked then
      Result := DB.ConnectPostgres(EdHost.Text, StrToIntDef(EdPort.Text, 5432),
        EdUser.Text, EdPassword.Text, EdName.Text)
    else
      Result := DB.ConnectSQLite(EdSqlite.Text);
    if Result then
    begin
      LblDbState.Font.Color := clGreen;
      LblDbState.Caption := 'Koneksi berhasil. Server: ' + DB.ServerVersion;
    end
    else
    begin
      LblDbState.Font.Color := clRed;
      LblDbState.Caption := 'Koneksi gagal: ' + DB.LastError;
    end;
  finally
    DB.Free;
  end;
end;

procedure TSettingsForm.DoTest(Sender: TObject);
begin
  TryTestConnection;
end;

procedure TSettingsForm.DoSave(Sender: TObject);
begin
  AppConfig.UsePostgres := ChkPostgres.Checked;
  AppConfig.DbHost := EdHost.Text;
  AppConfig.DbPort := StrToIntDef(EdPort.Text, 5432);
  AppConfig.DbUser := EdUser.Text;
  AppConfig.DbPassword := EdPassword.Text;
  AppConfig.DbName := EdName.Text;
  AppConfig.SqliteFile := EdSqlite.Text;
  AppConfig.UpdateRepo := Trim(EdRepo.Text);
  AppConfig.Save;

  AppDB.ConnectFromConfig;
  if not AppDB.Connected then
    MessageDlg('Peringatan',
      'Pengaturan tersimpan, tetapi koneksi database gagal:' + sLineBreak +
      AppDB.LastError, mtWarning, [mbOK], 0);

  if Assigned(FOnSaved) then
    FOnSaved;
  ModalResult := mrOK;
end;

procedure TSettingsForm.DoCancel(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
