unit uAppsView;

{
  SmartOffice Desktop - "Manajemen Aplikasi" view.

  Lists the external EXE applications from the database `apps` table with a
  small toolbar (Tambah / Edit / Hapus / Segarkan). Every change notifies the
  main form through OnChanged so the navigation tree, the launcher tiles and
  the "Aplikasi" menu are refreshed immediately.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls, StdCtrls, ComCtrls,
  uModuleView, uApps, uTheme;

type
  TAppsView = class(TModuleView)
  private
    FBanner: TPanel;
    FList: TListView;
    FOnChanged: TNotifyEvent;
    procedure BtnAddClick(Sender: TObject);
    procedure BtnEditClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
    procedure BtnRefreshClick(Sender: TObject);
    procedure ListDblClick(Sender: TObject);
    function SelectedInfo: TAppInfo;
    procedure NotifyChanged;
  public
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
    procedure RefreshData;
    procedure BuildUI; override;
  end;

implementation

uses
  Dialogs, uApp, uAppsEditDlg, uAudit;

{ TAppsView }

procedure TAppsView.BuildUI;
var
  Lbl: TLabel;
  Toolbar: TPanel;
  Btn: TButton;
  Col: TListColumn;
begin
  inherited BuildUI;
  Color := AppTheme.ColorBackgroundAlt;

  FBanner := TPanel.Create(Self);
  FBanner.Parent := Self;
  FBanner.Align := alTop;
  FBanner.BorderSpacing.Top := 10;
  FBanner.Height := 56;
  FBanner.BevelOuter := bvNone;
  FBanner.Color := AppTheme.ColorPrimary;

  Lbl := TLabel.Create(FBanner);
  Lbl.Parent := FBanner;
  Lbl.Left := 24;
  Lbl.Top := 16;
  Lbl.Font.Size := 16;
  Lbl.Font.Style := [fsBold];
  Lbl.Font.Color := clWhite;
  Lbl.Caption := 'Manajemen Aplikasi (EXE)';
  Lbl.AutoSize := True;

  Toolbar := TPanel.Create(Self);
  Toolbar.Parent := Self;
  Toolbar.Align := alTop;
  Toolbar.Height := 44;
  Toolbar.BevelOuter := bvNone;
  Toolbar.Color := AppTheme.ColorBackgroundAlt;
  Toolbar.BorderSpacing.Left := 10;
  Toolbar.BorderSpacing.Top := 10;

  Btn := TButton.Create(Toolbar);
  Btn.Parent := Toolbar;
  Btn.Align := alLeft;
  Btn.Width := 96;
  Btn.BorderSpacing.Right := 8;
  Btn.Caption := 'Tambah';
  Btn.OnClick := @BtnAddClick;

  Btn := TButton.Create(Toolbar);
  Btn.Parent := Toolbar;
  Btn.Align := alLeft;
  Btn.Width := 96;
  Btn.BorderSpacing.Right := 8;
  Btn.Caption := 'Edit';
  Btn.OnClick := @BtnEditClick;

  Btn := TButton.Create(Toolbar);
  Btn.Parent := Toolbar;
  Btn.Align := alLeft;
  Btn.Width := 96;
  Btn.BorderSpacing.Right := 8;
  Btn.Caption := 'Hapus';
  Btn.OnClick := @BtnDeleteClick;

  Btn := TButton.Create(Toolbar);
  Btn.Parent := Toolbar;
  Btn.Align := alLeft;
  Btn.Width := 96;
  Btn.Caption := 'Segarkan';
  Btn.OnClick := @BtnRefreshClick;

  FList := TListView.Create(Self);
  FList.Parent := Self;
  FList.Align := alClient;
  FList.ViewStyle := vsReport;
  FList.ReadOnly := True;
  FList.RowSelect := True;
  FList.MultiSelect := False;
  FList.BorderSpacing.Left := 10;
  FList.BorderSpacing.Top := 6;
  FList.BorderSpacing.Right := 10;
  FList.BorderSpacing.Bottom := 10;
  FList.OnDblClick := @ListDblClick;

  Col := FList.Columns.Add;
  Col.Caption := 'Nama Aplikasi';
  Col.Width := 200;
  Col := FList.Columns.Add;
  Col.Caption := 'ID';
  Col.Width := 110;
  Col := FList.Columns.Add;
  Col.Caption := 'Kategori';
  Col.Width := 120;
  Col := FList.Columns.Add;
  Col.Caption := 'File EXE';
  Col.Width := 210;
  Col := FList.Columns.Add;
  Col.Caption := 'Aktif';
  Col.Width := 60;
end;

procedure TAppsView.RefreshData;
var
  List: TList;
  I: Integer;
  Item: TListItem;
begin
  for I := 0 to FList.Items.Count - 1 do
    if FList.Items[I].Data <> nil then
      TAppInfo(FList.Items[I].Data).Free;
  FList.Items.Clear;

  if Apps = nil then
    Exit;
  List := Apps.LoadApps;
  try
    for I := 0 to List.Count - 1 do
    begin
      Item := FList.Items.Add;
      Item.Caption := TAppInfo(List[I]).Title;
      Item.SubItems.Add(TAppInfo(List[I]).AppId);
      Item.SubItems.Add(TAppInfo(List[I]).Category);
      Item.SubItems.Add(TAppInfo(List[I]).ExeFile);
      if TAppInfo(List[I]).Active then
        Item.SubItems.Add('Ya')
      else
        Item.SubItems.Add('Tidak');
      Item.Data := List[I]; // the view now owns each TAppInfo
      List[I] := nil;       // detach so the list does not double-free it
    end;
  finally
    for I := 0 to List.Count - 1 do
      if List[I] <> nil then
        TAppInfo(List[I]).Free;
    List.Free;
  end;
end;

function TAppsView.SelectedInfo: TAppInfo;
begin
  Result := nil;
  if (FList.Selected <> nil) and (FList.Selected.Data <> nil) then
    Result := TAppInfo(FList.Selected.Data);
end;

procedure TAppsView.BtnAddClick(Sender: TObject);
var
  Info: TAppInfo;
begin
  Info := TAppInfo.Create;
  Info.SortOrder := 1;
  Info.Active := True;
  if EditApp(Info) then
  begin
    if Apps.Insert(Info) then
      AuditLog('CREATE', 'apps', 0, 'Tambah aplikasi: ' + Info.Title);
    RefreshData;
    NotifyChanged;
  end;
  Info.Free;
end;

procedure TAppsView.BtnEditClick(Sender: TObject);
var
  Info: TAppInfo;
begin
  Info := SelectedInfo;
  if Info = nil then
  begin
    MessageDlg('Edit', 'Pilih aplikasi yang akan diedit terlebih dahulu.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if EditApp(Info) then
  begin
    if Apps.Update(Info) then
      AuditLog('UPDATE', 'apps', Info.Id, 'Ubah aplikasi: ' + Info.Title);
    RefreshData;
    NotifyChanged;
  end;
end;

procedure TAppsView.BtnDeleteClick(Sender: TObject);
var
  Info: TAppInfo;
begin
  Info := SelectedInfo;
  if Info = nil then
  begin
    MessageDlg('Hapus', 'Pilih aplikasi yang akan dihapus terlebih dahulu.',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Hapus Aplikasi',
    'Hapus aplikasi "' + Info.Title + '" dari daftar?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    if Apps.Delete(Info.Id) then
      AuditLog('DELETE', 'apps', Info.Id, 'Hapus aplikasi: ' + Info.Title);
    RefreshData;
    NotifyChanged;
  end;
end;

procedure TAppsView.BtnRefreshClick(Sender: TObject);
begin
  RefreshData;
end;

procedure TAppsView.ListDblClick(Sender: TObject);
begin
  BtnEditClick(Sender);
end;

procedure TAppsView.NotifyChanged;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

end.
