unit uRBACView;

{
  SmartOffice Desktop - Hak Akses view.
  Three tabs:
    * Peran       - manage roles
    * Hak Akses   - manage per-module permissions (view/create/edit/delete)
    * Pengguna    - manage application users
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqldb, Controls, Graphics, ExtCtrls, StdCtrls,
  ComCtrls, Buttons, DBGrids, Forms, uModuleView;

type
  TRBACView = class(TModuleView)
  private
    FPages: TPageControl;

    // --- roles ---
    FGridRole: TDBGrid;
    FRoleQuery: TSQLQuery;
    FRoleDS: TDataSource;
    FEdRoleKode, FEdRoleNama, FEdRoleKet: TEdit;
    FRoleSelId: Integer;

    // --- permissions ---
    FComboRole: TComboBox;
    FPermBox: TScrollBox;
    FChkView, FChkCreate, FChkEdit, FChkDelete: array of TCheckBox;
    FPermModule: array of string;
    FPermRoleId: Integer;

    // --- users ---
    FGridUser: TDBGrid;
    FUserQuery: TSQLQuery;
    FUserDS: TDataSource;
    FEdUserName, FEdUserPass, FEdUserFull: TEdit;
    FComboUserRole: TComboBox;
    FChkUserAktif: TCheckBox;
    FUserSelId: Integer;

    procedure BuildRolesTab(ATab: TTabSheet);
    procedure BuildPermsTab(ATab: TTabSheet);
    procedure BuildUsersTab(ATab: TTabSheet);

    procedure RefreshRoles;
    procedure LoadRole(Sender: TObject; Field: TField);
    procedure DoRoleSave(Sender: TObject);
    procedure DoRoleNew(Sender: TObject);
    procedure DoRoleDelete(Sender: TObject);

    procedure RefreshRoleCombos;
    procedure PermRoleChange(Sender: TObject);
    procedure RefreshPerms;
    procedure DoPermSave(Sender: TObject);

    procedure RefreshUsers;
    procedure LoadUser(Sender: TObject; Field: TField);
    procedure DoUserSave(Sender: TObject);
    procedure DoUserNew(Sender: TObject);
    procedure DoUserDelete(Sender: TObject);
  protected
    procedure BuildUI; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  Dialogs, uApp, uDB, uRBAC, uAudit, uTheme;

{$R *.lfm}

{ TRBACView }

constructor TRBACView.Create(AOwner: TComponent);
begin
  ModuleId := 'rbac';
  inherited Create(AOwner);
end;

procedure TRBACView.BuildUI;
var
  Banner: TPanel;
  Lbl: TLabel;
  TabRole, TabPerm, TabUser: TTabSheet;
begin
  inherited BuildUI;
  Color := AppTheme.ColorBackgroundAlt;

  Banner := TPanel.Create(Self);
  Banner.Parent := Self;
  Banner.Align := alTop;
  Banner.Height := 72;
  Banner.BevelOuter := bvNone;
  Banner.Color := AppTheme.ColorPrimary;

  Lbl := TLabel.Create(Banner);
  Lbl.Parent := Banner;
  Lbl.Left := 24; Lbl.Top := 16;
  Lbl.Font.Size := AppTheme.FontSizeXL;
  Lbl.Font.Name := AppTheme.FontFamily;
  Lbl.Font.Style := [fsBold];
  Lbl.Font.Color := clWhite;
  Lbl.Caption := 'Manajemen Hak Akses';
  Lbl.AutoSize := True;

  FPages := TPageControl.Create(Self);
  FPages.Parent := Self;
  FPages.Align := alClient;
  FPages.BorderSpacing.Left := 8;
  FPages.BorderSpacing.Right := 8;
  FPages.BorderSpacing.Top := 4;
  FPages.BorderSpacing.Bottom := 8;

  TabRole := TTabSheet.Create(FPages);
  TabRole.Parent := FPages;
  TabRole.Caption := 'Peran';

  TabPerm := TTabSheet.Create(FPages);
  TabPerm.Parent := FPages;
  TabPerm.Caption := 'Hak Akses';

  TabUser := TTabSheet.Create(FPages);
  TabUser.Parent := FPages;
  TabUser.Caption := 'Pengguna';

  BuildRolesTab(TabRole);
  BuildPermsTab(TabPerm);
  BuildUsersTab(TabUser);

  RefreshRoleCombos;
end;

{ ---------------- Roles ---------------- }

procedure TRBACView.BuildRolesTab(ATab: TTabSheet);
var
  Lbl: TLabel;
  FormPnl: TPanel;
  Btn: TBitBtn;
  procedure AddField(const ACaption: string; X, Y: Integer; var AEdit: TEdit);
  var
    L: TLabel;
  begin
    L := TLabel.Create(FormPnl);
    L.Parent := FormPnl;
    L.Left := X;
    L.Top := Y + 6;
    L.Caption := ACaption;
    AEdit := TEdit.Create(FormPnl);
    AEdit.Parent := FormPnl;
    AEdit.Left := X + 104;
    AEdit.Top := Y;
    AEdit.Width := 190;
  end;
begin
  FormPnl := TPanel.Create(ATab);
  FormPnl.Parent := ATab;
  FormPnl.Align := alTop;
  FormPnl.Height := 150;
  FormPnl.BevelOuter := bvNone;
  FormPnl.Color := AppTheme.ColorBackground;
  FormPnl.BorderSpacing.Left := 8;
  FormPnl.BorderSpacing.Right := 8;
  FormPnl.BorderSpacing.Top := 8;

  AddField('Kode Peran', 16, 14, FEdRoleKode);
  AddField('Nama Peran', 216, 14, FEdRoleNama);
  AddField('Keterangan', 16, 58, FEdRoleKet);

  Btn := TBitBtn.Create(FormPnl);
  Btn.Parent := FormPnl;
  Btn.Caption := 'Simpan';
  Btn.Left := 16; Btn.Top := 104; Btn.Width := 100;
  Btn.OnClick := @DoRoleSave;
  Btn.Enabled := CanCreate or CanEdit;

  Btn := TBitBtn.Create(FormPnl);
  Btn.Parent := FormPnl;
  Btn.Caption := 'Baru';
  Btn.Left := 124; Btn.Top := 104; Btn.Width := 100;
  Btn.OnClick := @DoRoleNew;
  Btn.Enabled := CanCreate;

  Btn := TBitBtn.Create(FormPnl);
  Btn.Parent := FormPnl;
  Btn.Caption := 'Hapus';
  Btn.Left := 232; Btn.Top := 104; Btn.Width := 100;
  Btn.OnClick := @DoRoleDelete;
  Btn.Enabled := CanDelete;

  FGridRole := TDBGrid.Create(ATab);
  FGridRole.Parent := ATab;
  FGridRole.Align := alClient;
  FGridRole.BorderSpacing.Left := 8;
  FGridRole.BorderSpacing.Right := 8;
  FGridRole.BorderSpacing.Top := 8;
  FGridRole.BorderSpacing.Bottom := 8;
  FGridRole.AlternateColor := $00F5F5F5;
  FGridRole.Options := FGridRole.Options + [dgRowSelect, dgAlwaysShowSelection] - [dgColLines];
  FGridRole.ReadOnly := True;
  FGridRole.Color := clWhite;

  FRoleQuery := AppDB.NewQuery(
    'select id, kode, nama, keterangan from roles order by kode');
  FRoleDS := TDataSource.Create(Self);
  FRoleDS.DataSet := FRoleQuery;
  FRoleDS.OnDataChange := @LoadRole;
  FGridRole.DataSource := FRoleDS;
  RefreshRoles;
end;

procedure TRBACView.RefreshRoles;
begin
  if FRoleQuery = nil then
    Exit;
  try
    FRoleQuery.Close;
    if AppDB.Transaction.Active then
      AppDB.Transaction.Commit;
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    FRoleQuery.Open;
    // Force column creation so data is visible
    if FGridRole <> nil then
    begin
      FGridRole.DataSource := nil;
      FGridRole.DataSource := FRoleDS;
    end;
  except
    on E: Exception do
      MessageDlg('Kesalahan', 'Gagal membaca peran:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TRBACView.LoadRole(Sender: TObject; Field: TField);
begin
  if (FRoleQuery = nil) or (not FRoleQuery.Active) or FRoleQuery.EOF then
    Exit;
  FRoleSelId := FRoleQuery.FieldByName('id').AsInteger;
  FEdRoleKode.Text := FRoleQuery.FieldByName('kode').AsString;
  FEdRoleNama.Text := FRoleQuery.FieldByName('nama').AsString;
  FEdRoleKet.Text := FRoleQuery.FieldByName('keterangan').AsString;
end;

procedure TRBACView.DoRoleSave(Sender: TObject);
var
  q: TSQLQuery;
begin
  if (Trim(FEdRoleKode.Text) = '') or (Trim(FEdRoleNama.Text) = '') then
  begin
    MessageDlg('Info', 'Kode dan nama peran tidak boleh kosong.', mtWarning, [mbOK], 0);
    Exit;
  end;
  q := AppDB.NewQuery('');
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    if FRoleSelId > 0 then
    begin
      q.SQL.Text :=
        'update roles set kode=:kode, nama=:nama, keterangan=:ket where id=:id';
      q.Params.ParamByName('id').AsInteger := FRoleSelId;
    end
    else
    begin
      q.SQL.Text :=
        'insert into roles (kode, nama, keterangan) values (:kode, :nama, :ket)';
    end;
    q.Params.ParamByName('kode').AsString := FEdRoleKode.Text;
    q.Params.ParamByName('nama').AsString := FEdRoleNama.Text;
    q.Params.ParamByName('ket').AsString := FEdRoleKet.Text;
    q.ExecSQL;
    AppDB.Transaction.Commit;
    if FRoleSelId > 0 then
      AuditLog('UPDATE', 'roles', FRoleSelId,
        'Ubah peran: ' + FEdRoleKode.Text + ' - ' + FEdRoleNama.Text)
    else
      AuditLog('CREATE', 'roles', 0,
        'Tambah peran: ' + FEdRoleKode.Text + ' - ' + FEdRoleNama.Text);
  except
    on E: Exception do
    begin
      if AppDB.Transaction.Active then
        AppDB.Transaction.Rollback;
      MessageDlg('Kesalahan', 'Gagal menyimpan peran:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
    end;
  end;
  q.Free;
  RefreshRoles;
  RefreshRoleCombos;
end;

procedure TRBACView.DoRoleNew(Sender: TObject);
begin
  FRoleSelId := 0;
  FEdRoleKode.Text := '';
  FEdRoleNama.Text := '';
  FEdRoleKet.Text := '';
  FEdRoleKode.SetFocus;
end;

procedure TRBACView.DoRoleDelete(Sender: TObject);
var
  q: TSQLQuery;
begin
  if (FRoleQuery = nil) or (not FRoleQuery.Active) or FRoleQuery.EOF then
  begin
    MessageDlg('Info', 'Pilih peran terlebih dahulu.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if CompareText(FRoleQuery.FieldByName('kode').AsString, 'ADMIN') = 0 then
  begin
    MessageDlg('Info', 'Peran ADMIN tidak dapat dihapus.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Hapus', 'Hapus peran ini?', mtConfirmation, mbYesNo, 0) <> mrYes then
    Exit;
  q := AppDB.NewQuery('delete from roles where id=:id');
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    q.Params.ParamByName('id').AsInteger := FRoleQuery.FieldByName('id').AsInteger;
    q.ExecSQL;
    AppDB.Transaction.Commit;
    AuditLog('DELETE', 'roles', FRoleQuery.FieldByName('id').AsInteger,
      'Hapus peran: ' + FRoleQuery.FieldByName('kode').AsString);
  except
    on E: Exception do
    begin
      if AppDB.Transaction.Active then
        AppDB.Transaction.Rollback;
      MessageDlg('Kesalahan', 'Gagal menghapus peran:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
    end;
  end;
  q.Free;
  FRoleSelId := 0;
  RefreshRoles;
  RefreshRoleCombos;
end;

{ ---------------- Permissions ---------------- }

procedure TRBACView.BuildPermsTab(ATab: TTabSheet);
var
  Lbl: TLabel;
  Toolbar: TPanel;
  Btn: TBitBtn;
  Row: TPanel;
  I: Integer;
begin
  Toolbar := TPanel.Create(ATab);
  Toolbar.Parent := ATab;
  Toolbar.Align := alTop;
  Toolbar.Height := 52;
  Toolbar.BevelOuter := bvNone;
  Toolbar.Color := AppTheme.ColorBackground;
  Toolbar.BorderSpacing.Left := 8;
  Toolbar.BorderSpacing.Right := 8;
  Toolbar.BorderSpacing.Top := 8;

  Lbl := TLabel.Create(Toolbar);
  Lbl.Parent := Toolbar;
  Lbl.Left := 8; Lbl.Top := 14;
  Lbl.Caption := 'Peran:';

  FComboRole := TComboBox.Create(Toolbar);
  FComboRole.Parent := Toolbar;
  FComboRole.Left := 64; FComboRole.Top := 10;
  FComboRole.Width := 220;
  FComboRole.Style := csDropDownList;
  FComboRole.OnChange := @PermRoleChange;

  Btn := TBitBtn.Create(Toolbar);
  Btn.Parent := Toolbar;
  Btn.Caption := 'Simpan Hak Akses';
  Btn.Left := 300; Btn.Top := 8; Btn.Width := 140;
  Btn.OnClick := @DoPermSave;
  Btn.Enabled := CanEdit;

  FPermBox := TScrollBox.Create(ATab);
  FPermBox.Parent := ATab;
  FPermBox.Align := alClient;
  FPermBox.BorderSpacing.Left := 8;
  FPermBox.BorderSpacing.Right := 8;
  FPermBox.BorderSpacing.Top := 8;
  FPermBox.BorderSpacing.Bottom := 8;

  SetLength(FChkView, High(RBACModuleList) + 1);
  SetLength(FChkCreate, High(RBACModuleList) + 1);
  SetLength(FChkEdit, High(RBACModuleList) + 1);
  SetLength(FChkDelete, High(RBACModuleList) + 1);
  SetLength(FPermModule, High(RBACModuleList) + 1);

  for I := 0 to High(RBACModuleList) do
  begin
    FPermModule[I] := RBACModuleList[I].Key;
    Row := TPanel.Create(FPermBox);
    Row.Parent := FPermBox;
    Row.Left := 4;
    Row.Top := 4 + I * 40;
    Row.Width := FPermBox.ClientWidth - 24;
    Row.Height := 36;
    Row.BevelOuter := bvNone;
    Row.ParentColor := False;
    Row.Color := AppTheme.ColorBackground;
    Row.Anchors := [akLeft, akTop, akRight];

    Lbl := TLabel.Create(Row);
    Lbl.Parent := Row;
    Lbl.Left := 12; Lbl.Top := 8;
    Lbl.Caption := RBACModuleList[I].Title;

    FChkView[I] := TCheckBox.Create(Row);
    FChkView[I].Parent := Row;
    FChkView[I].Left := 200; FChkView[I].Top := 6;
    FChkView[I].Caption := 'Lihat';

    FChkCreate[I] := TCheckBox.Create(Row);
    FChkCreate[I].Parent := Row;
    FChkCreate[I].Left := 300; FChkCreate[I].Top := 6;
    FChkCreate[I].Caption := 'Tambah';

    FChkEdit[I] := TCheckBox.Create(Row);
    FChkEdit[I].Parent := Row;
    FChkEdit[I].Left := 400; FChkEdit[I].Top := 6;
    FChkEdit[I].Caption := 'Ubah';

    FChkDelete[I] := TCheckBox.Create(Row);
    FChkDelete[I].Parent := Row;
    FChkDelete[I].Left := 500; FChkDelete[I].Top := 6;
    FChkDelete[I].Caption := 'Hapus';
  end;

  FPermRoleId := -1;
end;

procedure TRBACView.RefreshRoleCombos;
var
  q: TSQLQuery;
  CurRole: Integer;
  I: Integer;
begin
  if FComboRole = nil then
    Exit;
  CurRole := FPermRoleId;
  FComboRole.Items.Clear;
  q := AppDB.NewQuery('select id, kode, nama from roles order by kode');
  try
    q.Open;
    while not q.EOF do
    begin
      FComboRole.Items.AddObject(
        q.FieldByName('nama').AsString + ' (' + q.FieldByName('kode').AsString + ')',
        TObject(PtrInt(q.FieldByName('id').AsInteger)));
      q.Next;
    end;
  finally
    q.Free;
  end;

  if FComboUserRole <> nil then
  begin
    FComboUserRole.Items.Clear;
    q := AppDB.NewQuery('select id, kode, nama from roles order by kode');
    try
      q.Open;
      while not q.EOF do
      begin
        FComboUserRole.Items.AddObject(
          q.FieldByName('nama').AsString + ' (' + q.FieldByName('kode').AsString + ')',
          TObject(PtrInt(q.FieldByName('id').AsInteger)));
        q.Next;
      end;
    finally
      q.Free;
    end;
  end;

  if FComboRole.Items.Count > 0 then
    FComboRole.ItemIndex := 0;
  if FComboUserRole <> nil then
    if FComboUserRole.Items.Count > 0 then
      FComboUserRole.ItemIndex := 0;

  for I := 0 to FComboRole.Items.Count - 1 do
    if PtrInt(FComboRole.Items.Objects[I]) = CurRole then
      FComboRole.ItemIndex := I;
  PermRoleChange(nil);
end;

procedure TRBACView.PermRoleChange(Sender: TObject);
begin
  if (FComboRole = nil) or (FComboRole.ItemIndex < 0) then
  begin
    FPermRoleId := -1;
    Exit;
  end;
  FPermRoleId := PtrInt(FComboRole.Items.Objects[FComboRole.ItemIndex]);
  RefreshPerms;
end;

procedure TRBACView.RefreshPerms;
var
  q: TSQLQuery;
  M: string;
  I: Integer;
  Idx: Integer;
begin
  if FPermRoleId <= 0 then
    Exit;
  for I := 0 to High(FChkView) do
  begin
    FChkView[I].Checked := False;
    FChkCreate[I].Checked := False;
    FChkEdit[I].Checked := False;
    FChkDelete[I].Checked := False;
  end;
  q := AppDB.NewQuery(
    'select module_id, can_view, can_create, can_edit, can_delete ' +
    'from role_permissions where role_id=:role_id');
  try
    q.Params.ParamByName('role_id').AsInteger := FPermRoleId;
    q.Open;
    while not q.EOF do
    begin
      M := q.FieldByName('module_id').AsString;
      Idx := -1;
      for I := 0 to High(FPermModule) do
        if CompareText(FPermModule[I], M) = 0 then
        begin
          Idx := I;
          Break;
        end;
      if Idx >= 0 then
      begin
        FChkView[Idx].Checked := q.FieldByName('can_view').AsBoolean;
        FChkCreate[Idx].Checked := q.FieldByName('can_create').AsBoolean;
        FChkEdit[Idx].Checked := q.FieldByName('can_edit').AsBoolean;
        FChkDelete[Idx].Checked := q.FieldByName('can_delete').AsBoolean;
      end;
      q.Next;
    end;
  finally
    q.Free;
  end;
end;

procedure TRBACView.DoPermSave(Sender: TObject);
var
  dq, iq: TSQLQuery;
  I: Integer;
  SavedForOwnRole: Boolean;
begin
  if FPermRoleId <= 0 then
  begin
    MessageDlg('Info', 'Pilih peran terlebih dahulu.', mtInformation, [mbOK], 0);
    Exit;
  end;
  SavedForOwnRole := FPermRoleId = RBAC.User.RoleId;

  dq := AppDB.NewQuery('delete from role_permissions where role_id=:id');
  iq := AppDB.NewQuery(
    'insert into role_permissions (role_id, module_id, can_view, can_create, can_edit, can_delete) ' +
    'values (:role_id, :module_id, :v, :c, :e, :d)');
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    dq.Params.ParamByName('id').AsInteger := FPermRoleId;
    dq.ExecSQL;
    for I := 0 to High(FPermModule) do
    begin
      iq.Params.ParamByName('role_id').AsInteger := FPermRoleId;
      iq.Params.ParamByName('module_id').AsString := FPermModule[I];
      iq.Params.ParamByName('v').AsInteger := Integer(FChkView[I].Checked);
      iq.Params.ParamByName('c').AsInteger := Integer(FChkCreate[I].Checked);
      iq.Params.ParamByName('e').AsInteger := Integer(FChkEdit[I].Checked);
      iq.Params.ParamByName('d').AsInteger := Integer(FChkDelete[I].Checked);
      iq.ExecSQL;
    end;
    AppDB.Transaction.Commit;
    AuditLog('GRANT', 'role_permissions', FPermRoleId,
      'Perbarui hak akses peran id=' + IntToStr(FPermRoleId));
  except
    on E: Exception do
    begin
      if AppDB.Transaction.Active then
        AppDB.Transaction.Rollback;
      MessageDlg('Kesalahan', 'Gagal menyimpan hak akses:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
    end;
  end;
  dq.Free;
  iq.Free;

  if SavedForOwnRole then
    RBAC.RefreshPermissions;
  RefreshPerms;
  MessageDlg('Info', 'Hak akses disimpan.', mtInformation, [mbOK], 0);
end;

{ ---------------- Users ---------------- }

procedure TRBACView.BuildUsersTab(ATab: TTabSheet);
var
  Lbl: TLabel;
  FormPnl: TPanel;
  Btn: TBitBtn;
  procedure AddField(const ACaption: string; X, Y: Integer; var AEdit: TEdit);
  var
    L: TLabel;
  begin
    L := TLabel.Create(FormPnl);
    L.Parent := FormPnl;
    L.Left := X;
    L.Top := Y + 6;
    L.Caption := ACaption;
    AEdit := TEdit.Create(FormPnl);
    AEdit.Parent := FormPnl;
    AEdit.Left := X + 120;
    AEdit.Top := Y;
    AEdit.Width := 200;
  end;
begin
  FormPnl := TPanel.Create(ATab);
  FormPnl.Parent := ATab;
  FormPnl.Align := alTop;
  FormPnl.Height := 156;
  FormPnl.BevelOuter := bvNone;
  FormPnl.Color := AppTheme.ColorBackground;
  FormPnl.BorderSpacing.Left := 8;
  FormPnl.BorderSpacing.Right := 8;
  FormPnl.BorderSpacing.Top := 8;

  AddField('Pengguna', 16, 14, FEdUserName);
  AddField('Kata Sandi', 380, 14, FEdUserPass);
  AddField('Nama Lengkap', 16, 58, FEdUserFull);

  Lbl := TLabel.Create(FormPnl);
  Lbl.Parent := FormPnl;
  Lbl.Left := 380; Lbl.Top := 64;
  Lbl.Caption := 'Peran';

  FComboUserRole := TComboBox.Create(FormPnl);
  FComboUserRole.Parent := FormPnl;
  FComboUserRole.Left := 500; FComboUserRole.Top := 58;
  FComboUserRole.Width := 200;
  FComboUserRole.Style := csDropDownList;

  Lbl := TLabel.Create(FormPnl);
  Lbl.Parent := FormPnl;
  Lbl.Left := 16; Lbl.Top := 110;
  Lbl.Caption := 'Aktif';

  FChkUserAktif := TCheckBox.Create(FormPnl);
  FChkUserAktif.Parent := FormPnl;
  FChkUserAktif.Left := 136; FChkUserAktif.Top := 104;
  FChkUserAktif.Checked := True;

  Btn := TBitBtn.Create(FormPnl);
  Btn.Parent := FormPnl;
  Btn.Caption := 'Simpan';
  Btn.Left := 300; Btn.Top := 100; Btn.Width := 100;
  Btn.OnClick := @DoUserSave;
  Btn.Enabled := CanCreate or CanEdit;

  Btn := TBitBtn.Create(FormPnl);
  Btn.Parent := FormPnl;
  Btn.Caption := 'Baru';
  Btn.Left := 408; Btn.Top := 100; Btn.Width := 100;
  Btn.OnClick := @DoUserNew;
  Btn.Enabled := CanCreate;

  Btn := TBitBtn.Create(FormPnl);
  Btn.Parent := FormPnl;
  Btn.Caption := 'Hapus';
  Btn.Left := 516; Btn.Top := 100; Btn.Width := 100;
  Btn.OnClick := @DoUserDelete;
  Btn.Enabled := CanDelete;

  FGridUser := TDBGrid.Create(ATab);
  FGridUser.Parent := ATab;
  FGridUser.Align := alClient;
  FGridUser.BorderSpacing.Left := 8;
  FGridUser.BorderSpacing.Right := 8;
  FGridUser.BorderSpacing.Top := 8;
  FGridUser.BorderSpacing.Bottom := 8;
  FGridUser.AlternateColor := $00F5F5F5;
  FGridUser.Options := FGridUser.Options + [dgRowSelect, dgAlwaysShowSelection] - [dgColLines];
  FGridUser.ReadOnly := True;
  FGridUser.Color := clWhite;

  FUserQuery := AppDB.NewQuery(
    'select u.id, u.username, u.full_name, u.aktif, r.id as role_id, ' +
    'r.nama as role_nama from users u join roles r on r.id = u.role_id ' +
    'order by u.username');
  FUserDS := TDataSource.Create(Self);
  FUserDS.DataSet := FUserQuery;
  FUserDS.OnDataChange := @LoadUser;
  FGridUser.DataSource := FUserDS;
  RefreshUsers;
end;

procedure TRBACView.RefreshUsers;
begin
  if FUserQuery = nil then
    Exit;
  try
    FUserQuery.Close;
    if AppDB.Transaction.Active then
      AppDB.Transaction.Commit;
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    FUserQuery.Open;
    // Force column creation so data is visible
    if FGridUser <> nil then
    begin
      FGridUser.DataSource := nil;
      FGridUser.DataSource := FUserDS;
    end;
  except
    on E: Exception do
      MessageDlg('Kesalahan', 'Gagal membaca pengguna:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
  end;
end;

procedure TRBACView.LoadUser(Sender: TObject; Field: TField);
var
  I: Integer;
begin
  if (FUserQuery = nil) or (not FUserQuery.Active) or FUserQuery.EOF then
    Exit;
  FUserSelId := FUserQuery.FieldByName('id').AsInteger;
  FEdUserName.Text := FUserQuery.FieldByName('username').AsString;
  FEdUserPass.Text := '';
  FEdUserFull.Text := FUserQuery.FieldByName('full_name').AsString;
  FChkUserAktif.Checked := FUserQuery.FieldByName('aktif').AsBoolean;
  for I := 0 to FComboUserRole.Items.Count - 1 do
    if PtrInt(FComboUserRole.Items.Objects[I]) =
      FUserQuery.FieldByName('role_id').AsInteger then
    begin
      FComboUserRole.ItemIndex := I;
      Break;
    end;
end;

procedure TRBACView.DoUserSave(Sender: TObject);
var
  q: TSQLQuery;
  NewUser: Boolean;
  RoleId: Integer;
begin
  if Trim(FEdUserName.Text) = '' then
  begin
    MessageDlg('Info', 'Nama pengguna tidak boleh kosong.', mtWarning, [mbOK], 0);
    Exit;
  end;
  NewUser := FUserSelId = 0;
  if NewUser and (FEdUserPass.Text = '') then
  begin
    MessageDlg('Info', 'Kata sandi wajib diisi untuk pengguna baru.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if (FComboUserRole.ItemIndex < 0) or (FComboUserRole.ItemIndex >= FComboUserRole.Items.Count) then
  begin
    MessageDlg('Info', 'Pilih peran untuk pengguna.', mtWarning, [mbOK], 0);
    Exit;
  end;
  RoleId := PtrInt(FComboUserRole.Items.Objects[FComboUserRole.ItemIndex]);

  q := AppDB.NewQuery('');
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    if NewUser then
    begin
      q.SQL.Text :=
        'insert into users (username, password, full_name, role_id, aktif) ' +
        'values (:username, :password, :full_name, :role_id, :aktif)';
      q.Params.ParamByName('password').AsString := RBAC.HashPassword(FEdUserPass.Text);
    end
    else
    begin
      if FEdUserPass.Text = '' then
        q.SQL.Text :=
          'update users set username=:username, full_name=:full_name, ' +
          'role_id=:role_id, aktif=:aktif where id=:id'
      else
      begin
        q.SQL.Text :=
          'update users set username=:username, password=:password, ' +
          'full_name=:full_name, role_id=:role_id, aktif=:aktif where id=:id';
        q.Params.ParamByName('password').AsString := RBAC.HashPassword(FEdUserPass.Text);
      end;
      q.Params.ParamByName('id').AsInteger := FUserSelId;
    end;
    q.Params.ParamByName('username').AsString := Trim(FEdUserName.Text);
    q.Params.ParamByName('full_name').AsString := FEdUserFull.Text;
    q.Params.ParamByName('role_id').AsInteger := RoleId;
    q.Params.ParamByName('aktif').AsInteger := Integer(FChkUserAktif.Checked);
    q.ExecSQL;
    AppDB.Transaction.Commit;
    if NewUser then
      AuditLog('CREATE', 'users', 0,
        'Tambah pengguna: ' + Trim(FEdUserName.Text))
    else
      AuditLog('UPDATE', 'users', FUserSelId,
        'Ubah pengguna: ' + Trim(FEdUserName.Text));
  except
    on E: Exception do
    begin
      if AppDB.Transaction.Active then
        AppDB.Transaction.Rollback;
      MessageDlg('Kesalahan', 'Gagal menyimpan pengguna:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
    end;
  end;
  q.Free;
  RefreshUsers;
end;

procedure TRBACView.DoUserNew(Sender: TObject);
begin
  FUserSelId := 0;
  FEdUserName.Text := '';
  FEdUserPass.Text := '';
  FEdUserFull.Text := '';
  FChkUserAktif.Checked := True;
  FEdUserName.SetFocus;
end;

procedure TRBACView.DoUserDelete(Sender: TObject);
var
  q: TSQLQuery;
begin
  if (FUserQuery = nil) or (not FUserQuery.Active) or FUserQuery.EOF then
  begin
    MessageDlg('Info', 'Pilih pengguna terlebih dahulu.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if FUserQuery.FieldByName('id').AsInteger = RBAC.User.UserId then
  begin
    MessageDlg('Info', 'Tidak dapat menghapus pengguna yang sedang masuk.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Hapus', 'Hapus pengguna ini?', mtConfirmation, mbYesNo, 0) <> mrYes then
    Exit;
  q := AppDB.NewQuery('delete from users where id=:id');
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    q.Params.ParamByName('id').AsInteger := FUserQuery.FieldByName('id').AsInteger;
    q.ExecSQL;
    AppDB.Transaction.Commit;
    AuditLog('DELETE', 'users', FUserQuery.FieldByName('id').AsInteger,
      'Hapus pengguna: ' + FUserQuery.FieldByName('username').AsString);
  except
    on E: Exception do
    begin
      if AppDB.Transaction.Active then
        AppDB.Transaction.Rollback;
      MessageDlg('Kesalahan', 'Gagal menghapus pengguna:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
    end;
  end;
  q.Free;
  FUserSelId := 0;
  RefreshUsers;
end;

end.
