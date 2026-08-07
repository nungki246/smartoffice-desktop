unit uAppsEditDlg;

{
  SmartOffice Desktop - edit dialog for an external EXE application.
  Code-built modal form (no .lfm) with validation and unique ID checking.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Forms, Graphics, ExtCtrls, StdCtrls, Spin,
  Dialogs, uApps, uTheme;

// Shows the modal editor. AInfo is filled with the saved values on success.
// Returns True when the user pressed "Simpan".
function EditApp(AInfo: TAppInfo): Boolean;

implementation

type
  TAppsEditForm = class(TForm)
  private
    EdTitle: TEdit;
    EdAppId: TEdit;
    EdDescription: TEdit;
    EdExeFile: TEdit;
    CbCategory: TComboBox;
    SeSort: TSpinEdit;
    ChkActive: TCheckBox;
    FApp: TAppInfo;
    function AddLabeledEdit(const ACaption: string; var AY: Integer): TEdit;
    procedure BtnOkClick(Sender: TObject);
  end;

function EditApp(AInfo: TAppInfo): Boolean;
var
  F: TAppsEditForm;
  Lbl: TLabel;
  Btn: TButton;
  Panel: TPanel;
  Y: Integer;
begin
  Result := False;
  if AInfo = nil then
    Exit;
  F := TAppsEditForm.CreateNew(nil);
  try
    F.FApp := AInfo;
    F.Caption := 'Aplikasi EXE';
    F.Width := 440;
    F.Height := 420;
    F.Position := poScreenCenter;
    F.BorderStyle := bsDialog;
    F.Color := AppTheme.ColorBackground;

    Y := 16;
    F.EdTitle := F.AddLabeledEdit('Nama Aplikasi', Y);
    F.EdAppId := F.AddLabeledEdit('ID Aplikasi (unik, tanpa spasi)', Y);
    F.EdDescription := F.AddLabeledEdit('Deskripsi', Y);
    F.EdExeFile := F.AddLabeledEdit('File EXE (mis. SIMRS-X.exe)', Y);

    Lbl := TLabel.Create(F);
    Lbl.Parent := F;
    Lbl.Left := 16;
    Lbl.Top := Y;
    Lbl.Caption := 'Kategori';
    F.CbCategory := TComboBox.Create(F);
    F.CbCategory.Parent := F;
    F.CbCategory.Left := 16;
    F.CbCategory.Top := Y + 22;
    F.CbCategory.Width := 392;
    F.CbCategory.Style := csDropDown;
    F.CbCategory.Items.Add('Umum');
    F.CbCategory.Items.Add('Aplikasi');
    F.CbCategory.Items.Add('Sistem');
    F.CbCategory.Items.Add('Sumber Daya');
    F.CbCategory.Items.Add('Lainnya');
    Inc(Y, 54);

    Lbl := TLabel.Create(F);
    Lbl.Parent := F;
    Lbl.Left := 16;
    Lbl.Top := Y;
    Lbl.Caption := 'Urutan Tampil';
    F.SeSort := TSpinEdit.Create(F);
    F.SeSort.Parent := F;
    F.SeSort.Left := 16;
    F.SeSort.Top := Y + 22;
    F.SeSort.Width := 120;
    Inc(Y, 54);

    F.ChkActive := TCheckBox.Create(F);
    F.ChkActive.Parent := F;
    F.ChkActive.Left := 16;
    F.ChkActive.Top := Y;
    F.ChkActive.Caption := 'Aktif (ditampilkan di menu & launcher)';
    Inc(Y, 40);

    Panel := TPanel.Create(F);
    Panel.Parent := F;
    Panel.Align := alBottom;
    Panel.Height := 52;
    Panel.BevelOuter := bvNone;
    Panel.Color := AppTheme.ColorBackground;

    Btn := TButton.Create(Panel);
    Btn.Parent := Panel;
    Btn.Caption := 'Simpan';
    Btn.Left := F.Width - 216;
    Btn.Top := 10;
    Btn.Width := 96;
    Btn.Default := True;
    Btn.OnClick := @F.BtnOkClick;

    Btn := TButton.Create(Panel);
    Btn.Parent := Panel;
    Btn.Caption := 'Batal';
    Btn.Left := F.Width - 112;
    Btn.Top := 10;
    Btn.Width := 96;
    Btn.Cancel := True;
    Btn.ModalResult := mrCancel;

    // initial values
    F.EdTitle.Text := AInfo.Title;
    F.EdAppId.Text := AInfo.AppId;
    F.EdDescription.Text := AInfo.Description;
    F.EdExeFile.Text := AInfo.ExeFile;
    F.CbCategory.Text := AInfo.Category;
    F.SeSort.Value := AInfo.SortOrder;
    F.ChkActive.Checked := AInfo.Active;

    if F.ShowModal = mrOk then
      Result := True;
  finally
    F.Free;
  end;
end;

function TAppsEditForm.AddLabeledEdit(const ACaption: string; var AY: Integer): TEdit;
var
  Lbl: TLabel;
  Ed: TEdit;
begin
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Self;
  Lbl.Left := 16;
  Lbl.Top := AY;
  Lbl.Caption := ACaption;
  Ed := TEdit.Create(Self);
  Ed.Parent := Self;
  Ed.Left := 16;
  Ed.Top := AY + 22;
  Ed.Width := 392;
  Result := Ed;
  Inc(AY, 54);
end;

procedure TAppsEditForm.BtnOkClick(Sender: TObject);
var
  Id: string;
begin
  if Trim(EdTitle.Text) = '' then
  begin
    MessageDlg('Validasi', 'Nama aplikasi tidak boleh kosong.',
      mtWarning, [mbOK], 0);
    ModalResult := mrNone;
    Exit;
  end;
  Id := Trim(EdAppId.Text);
  if Id = '' then
  begin
    MessageDlg('Validasi', 'ID aplikasi tidak boleh kosong.',
      mtWarning, [mbOK], 0);
    ModalResult := mrNone;
    Exit;
  end;
  if (Pos(' ', Id) > 0) or (Pos('/', Id) > 0) or (Pos('\', Id) > 0) then
  begin
    MessageDlg('Validasi', 'ID aplikasi tidak boleh mengandung spasi, / atau \.',
      mtWarning, [mbOK], 0);
    ModalResult := mrNone;
    Exit;
  end;
  if Trim(EdExeFile.Text) = '' then
  begin
    MessageDlg('Validasi', 'Nama file EXE tidak boleh kosong.',
      mtWarning, [mbOK], 0);
    ModalResult := mrNone;
    Exit;
  end;
  if Apps.AppIdExists(Id, FApp.Id) then
  begin
    MessageDlg('Validasi', 'ID aplikasi "' + Id + '" sudah dipakai.',
      mtWarning, [mbOK], 0);
    ModalResult := mrNone;
    Exit;
  end;

  FApp.Title := Trim(EdTitle.Text);
  FApp.AppId := Id;
  FApp.Description := Trim(EdDescription.Text);
  FApp.Category := Trim(CbCategory.Text);
  if FApp.Category = '' then
    FApp.Category := 'Umum';
  FApp.ExeFile := Trim(EdExeFile.Text);
  FApp.SortOrder := SeSort.Value;
  FApp.Active := ChkActive.Checked;
  ModalResult := mrOk;
end;

end.
