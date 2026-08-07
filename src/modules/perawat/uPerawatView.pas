unit uPerawatView;

{
  SmartOffice Desktop - Perawat view.
  CRUD for nurse data (modul Aplikasi B).

  Implemented as a TFrame so the layout lives in uPerawatView.lfm and can
  be edited visually in the Lazarus IDE (drag & drop). The .lfm is streamed
  automatically when the frame is created at runtime.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqldb, Controls, Graphics, ExtCtrls, StdCtrls,
  Buttons, DBGrids, Forms;

type

  { TPerawatView }

  TPerawatView = class(TFrame)
  published
    Banner: TPanel;
    LblTitle: TLabel;
    FStatusLabel: TLabel;
    FormPnl: TPanel;
    LblNip: TLabel;
    FEdNip: TEdit;
    LblNama: TLabel;
    FEdNama: TEdit;
    LblUnit: TLabel;
    FEdUnit: TEdit;
    LblShift: TLabel;
    FEdShift: TEdit;
    LblStatus: TLabel;
    FEdStatus: TEdit;
    FBtnSave: TBitBtn;
    FBtnNew: TBitBtn;
    FBtnDelete: TBitBtn;
    FBtnRefresh: TBitBtn;
    FGrid: TDBGrid;
    procedure DoSave(Sender: TObject);
    procedure DoNew(Sender: TObject);
    procedure DoDelete(Sender: TObject);
    procedure DoRefresh(Sender: TObject);
  private
    FGridQuery: TSQLQuery;
    FDataSource: TDataSource;
    FModuleId: string;
    FSelectedId: Integer;
    FConnected: Boolean;
    procedure ApplyTheme;
    procedure BuildSchema;
    function ExecDML(const ASQL: string; const ANip, ANama, AUnit, AShift,
      AStatus: string): Boolean;
    procedure InitializeGrid;
    procedure RefreshGrid;
    procedure GridSelectionChanged(Sender: TObject; Field: TField);
    procedure LoadSelected;
    procedure UpdateActionState;
    function CanCreate: Boolean;
    function CanEdit: Boolean;
    function CanDelete: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    property ModuleId: string read FModuleId write FModuleId;
  end;

implementation

uses
  Dialogs, uApp, uDB, uRBAC, uAudit, uTheme;

{$R *.lfm}

{ TPerawatView }

constructor TPerawatView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); // streams the .lfm (creates Banner, FGrid, ...)
  if csDesigning in ComponentState then
    Exit; // designer instance: no DB wiring
  FModuleId := 'perawat';
  ApplyTheme;
  FConnected := AppDB.Connected;
  if FConnected then
    BuildSchema;
  InitializeGrid;
  UpdateActionState;
end;

procedure TPerawatView.ApplyTheme;
begin
  Color := AppTheme.ColorBackgroundAlt;
  Font.Name := AppTheme.FontFamily;
  Font.Size := AppTheme.FontSizeMD;

  if Assigned(Banner) then
  begin
    Banner.Color := AppTheme.ColorPrimary;
    if Assigned(LblTitle) then
    begin
      LblTitle.Font.Color := clWhite;
      LblTitle.Font.Size := AppTheme.FontSizeXL;
    end;
    if Assigned(FStatusLabel) then
      FStatusLabel.Font.Color := clWhite;
  end;

  if Assigned(FormPnl) then
    FormPnl.Color := AppTheme.ColorBackground;

  if Assigned(FGrid) then
  begin
    FGrid.AlternateColor := $00F5F5F5;
    FGrid.Options := FGrid.Options - [dgColLines];
    FGrid.Color := clWhite;
  end;
end;

function TPerawatView.CanCreate: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanCreate(FModuleId);
end;

function TPerawatView.CanEdit: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanEdit(FModuleId);
end;

function TPerawatView.CanDelete: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanDelete(FModuleId);
end;

procedure TPerawatView.BuildSchema;
var
  DDL: string;
begin
  if AppDB.Kind = dbPostgreSQL then
    DDL :=
      'create table if not exists perawat (' +
      ' id serial primary key,' +
      ' nip varchar(30),' +
      ' nama varchar(120) not null,' +
      ' unit varchar(80),' +
      ' shift varchar(40),' +
      ' status varchar(40))'
  else
    DDL :=
      'create table if not exists perawat (' +
      ' id integer primary key autoincrement,' +
      ' nip varchar(30),' +
      ' nama varchar(120) not null,' +
      ' unit varchar(80),' +
      ' shift varchar(40),' +
      ' status varchar(40))';
  AppDB.ExecSQL(DDL);
  // Index backing the 'order by nama' grid query.
  AppDB.ExecSQL('create index if not exists ix_perawat_nama on perawat(nama)');
end;

procedure TPerawatView.InitializeGrid;
begin
  if not FConnected then
  begin
    FStatusLabel.Caption := 'Database belum terhubung.';
    FStatusLabel.Font.Color := clRed;
    Exit;
  end;
  FGridQuery := AppDB.NewQuery(
    'select id, nip, nama, unit, shift, status ' +
    'from perawat order by nama');
  FDataSource := TDataSource.Create(Self);
  FDataSource.DataSet := FGridQuery;
  FDataSource.OnDataChange := @GridSelectionChanged;
  FGrid.DataSource := FDataSource;
  RefreshGrid;
end;

function TPerawatView.ExecDML(const ASQL: string; const ANip, ANama, AUnit,
  AShift, AStatus: string): Boolean;
var
  q: TSQLQuery;
begin
  Result := False;
  q := AppDB.NewQuery(ASQL);
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    q.Params.ParamByName('nip').AsString := ANip;
    q.Params.ParamByName('nama').AsString := ANama;
    q.Params.ParamByName('unit').AsString := AUnit;
    q.Params.ParamByName('shift').AsString := AShift;
    q.Params.ParamByName('status').AsString := AStatus;
    q.ExecSQL;
    AppDB.Transaction.Commit;
    Result := True;
  except
    on E: Exception do
      MessageDlg('Kesalahan', 'Gagal menyimpan data:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
  end;
  q.Free;
end;

procedure TPerawatView.RefreshGrid;
begin
  if (FGridQuery = nil) or (not AppDB.Connected) then
    Exit;
  try
    FGridQuery.Close;
    if AppDB.Transaction.Active then
      AppDB.Transaction.Commit;
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    FGridQuery.Open;
    FStatusLabel.Caption := Format('%d perawat', [FGridQuery.RecordCount]);
    FStatusLabel.Font.Color := clWindowText;
  except
    on E: Exception do
    begin
      FStatusLabel.Caption := 'Gagal membaca data: ' + E.Message;
      FStatusLabel.Font.Color := clRed;
    end;
  end;
end;

procedure TPerawatView.GridSelectionChanged(Sender: TObject; Field: TField);
begin
  LoadSelected;
end;

procedure TPerawatView.LoadSelected;
begin
  if (FGridQuery = nil) or (not FGridQuery.Active) or FGridQuery.EOF then
    Exit;
  FSelectedId := FGridQuery.FieldByName('id').AsInteger;
  FEdNip.Text := FGridQuery.FieldByName('nip').AsString;
  FEdNama.Text := FGridQuery.FieldByName('nama').AsString;
  FEdUnit.Text := FGridQuery.FieldByName('unit').AsString;
  FEdShift.Text := FGridQuery.FieldByName('shift').AsString;
  FEdStatus.Text := FGridQuery.FieldByName('status').AsString;
  UpdateActionState;
end;

procedure TPerawatView.UpdateActionState;
begin
  FBtnSave.Enabled := ((FSelectedId = 0) and CanCreate) or
    ((FSelectedId > 0) and CanEdit);
  FBtnNew.Enabled := CanCreate;
  FBtnDelete.Enabled := CanDelete and (FSelectedId > 0);
end;

procedure TPerawatView.DoSave(Sender: TObject);
var
  SQL: string;
begin
  if not AppDB.Connected then
  begin
    MessageDlg('Info', 'Database belum terhubung.', mtInformation, [mbOK], 0);
    Exit;
  end;
  if (FSelectedId = 0) and (not CanCreate) then
  begin
    MessageDlg('Akses Ditolak', 'Anda tidak memiliki hak menambah data.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if (FSelectedId > 0) and (not CanEdit) then
  begin
    MessageDlg('Akses Ditolak', 'Anda tidak memiliki hak mengubah data.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if Trim(FEdNama.Text) = '' then
  begin
    MessageDlg('Info', 'Nama perawat tidak boleh kosong.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if FSelectedId > 0 then
  begin
    SQL := 'update perawat set nip=:nip, nama=:nama, unit=:unit, ' +
      'shift=:shift, status=:status where id=:id';
    if ExecDML(SQL, FEdNip.Text, FEdNama.Text, FEdUnit.Text, FEdShift.Text,
      FEdStatus.Text) then
    begin
      AuditLog('UPDATE', 'perawat', FSelectedId,
        'Ubah: ' + FEdNama.Text + ' (' + FEdUnit.Text + ')');
      RefreshGrid;
      LoadSelected;
    end;
  end
  else
  begin
    SQL := 'insert into perawat (nip, nama, unit, shift, status) values ' +
      '(:nip, :nama, :unit, :shift, :status)';
    if ExecDML(SQL, FEdNip.Text, FEdNama.Text, FEdUnit.Text, FEdShift.Text,
      FEdStatus.Text) then
    begin
      AuditLog('CREATE', 'perawat', 0,
        'Tambah: ' + FEdNama.Text + ' (' + FEdUnit.Text + ')');
      FSelectedId := 0;
      RefreshGrid;
    end;
  end;
end;

procedure TPerawatView.DoNew(Sender: TObject);
begin
  if not CanCreate then
  begin
    MessageDlg('Akses Ditolak', 'Anda tidak memiliki hak menambah data.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  FSelectedId := 0;
  FEdNip.Text := '';
  FEdNama.Text := '';
  FEdUnit.Text := '';
  FEdShift.Text := '';
  FEdStatus.Text := '';
  UpdateActionState;
  FEdNama.SetFocus;
end;

procedure TPerawatView.DoDelete(Sender: TObject);
var
  q: TSQLQuery;
begin
  if not CanDelete then
  begin
    MessageDlg('Akses Ditolak', 'Anda tidak memiliki hak menghapus data.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if (FGridQuery = nil) or (FGridQuery.Active = False) or FGridQuery.EOF then
  begin
    MessageDlg('Info', 'Pilih baris data terlebih dahulu.', mtInformation, [mbOK], 0);
    Exit;
  end;
  FSelectedId := FGridQuery.FieldByName('id').AsInteger;
  if MessageDlg('Hapus', 'Hapus perawat ini?', mtConfirmation,
    mbYesNo, 0) <> mrYes then
    Exit;
  q := AppDB.NewQuery('delete from perawat where id=:id');
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    q.Params.ParamByName('id').AsInteger := FSelectedId;
    q.ExecSQL;
    AppDB.Transaction.Commit;
    AuditLog('DELETE', 'perawat', FSelectedId,
      'Hapus perawat id=' + IntToStr(FSelectedId));
    FSelectedId := 0;
  except
    on E: Exception do
      MessageDlg('Kesalahan', 'Gagal menghapus data:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
  end;
  q.Free;
  RefreshGrid;
end;

procedure TPerawatView.DoRefresh(Sender: TObject);
begin
  RefreshGrid;
end;

end.
