unit uPendaftaranView;

{
  SmartOffice Desktop - Pendaftaran view.
  Data entry + list for patient registrations (modul Pendaftaran).

  Implemented as a TFrame so the layout lives in uPendaftaranView.lfm and can
  be edited visually in the Lazarus IDE (drag & drop). The .lfm is streamed
  automatically when the frame is created at runtime.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqldb, Controls, Graphics, ExtCtrls, StdCtrls,
  Buttons, DBGrids, Forms;

type

  { TPendaftaranView }

  TPendaftaranView = class(TFrame)
  published
    Banner: TPanel;
    LblTitle: TLabel;
    FStatusLabel: TLabel;
    FormPnl: TPanel;
    LblNo: TLabel;
    FEdNo: TEdit;
    LblNama: TLabel;
    FEdNama: TEdit;
    LblTanggal: TLabel;
    FEdTanggal: TEdit;
    LblLayanan: TLabel;
    FEdLayanan: TEdit;
    LblDokter: TLabel;
    FEdDokter: TEdit;
    LblKet: TLabel;
    FEdKet: TEdit;
    FBtnSave: TBitBtn;
    FBtnNew: TBitBtn;
    FBtnDelete: TBitBtn;
    FBtnRefresh: TBitBtn;
    FGrid: TDBGrid;
    procedure DoSave(Sender: TObject);
    procedure DoNew(Sender: TObject);
    procedure DoDelete(Sender: TObject);
    procedure DoRefresh(Sender: TObject);
    procedure LblTitleClick(Sender: TObject);
  private
    FGridQuery: TSQLQuery;
    FDataSource: TDataSource;
    FModuleId: string;
    FSelectedId: Integer;
    FConnected: Boolean;
    procedure ApplyTheme;
    procedure BuildSchema;
    function ExecDML(const ASQL: string; const ANoReg, ANama, ATanggal,
      ALayanan, ADokter, AKet: string): Boolean;
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

{ TPendaftaranView }

constructor TPendaftaranView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); // streams the .lfm (creates Banner, FGrid, ...)
  if csDesigning in ComponentState then
    Exit; // designer instance: no DB wiring
  FModuleId := 'pendaftaran';
  ApplyTheme;
  FConnected := AppDB.Connected;
  if FConnected then
    BuildSchema;
  InitializeGrid;
  UpdateActionState;
end;

procedure TPendaftaranView.ApplyTheme;
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

function TPendaftaranView.CanCreate: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanCreate(FModuleId);
end;

function TPendaftaranView.CanEdit: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanEdit(FModuleId);
end;

function TPendaftaranView.CanDelete: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanDelete(FModuleId);
end;

procedure TPendaftaranView.BuildSchema;
var
  DDL: string;
begin
  if AppDB.Kind = dbPostgreSQL then
    DDL :=
      'create table if not exists registrasi (' +
      ' id serial primary key,' +
      ' no_reg varchar(30),' +
      ' nama varchar(120) not null,' +
      ' tanggal date,' +
      ' layanan varchar(80),' +
      ' dokter varchar(120),' +
      ' keterangan varchar(255))'
  else
    DDL :=
      'create table if not exists registrasi (' +
      ' id integer primary key autoincrement,' +
      ' no_reg varchar(30),' +
      ' nama varchar(120) not null,' +
      ' tanggal date,' +
      ' layanan varchar(80),' +
      ' dokter varchar(120),' +
      ' keterangan varchar(255))';
  AppDB.ExecSQL(DDL);
end;

procedure TPendaftaranView.InitializeGrid;
begin
  if not FConnected then
  begin
    FStatusLabel.Caption := 'Database belum terhubung.';
    FStatusLabel.Font.Color := clRed;
    Exit;
  end;
  FGridQuery := AppDB.NewQuery(
    'select id, no_reg, nama, tanggal, layanan, dokter, keterangan ' +
    'from registrasi order by id');
  FDataSource := TDataSource.Create(Self);
  FDataSource.DataSet := FGridQuery;
  FDataSource.OnDataChange := @GridSelectionChanged;
  FGrid.DataSource := FDataSource;
  RefreshGrid;
end;

function TPendaftaranView.ExecDML(const ASQL: string; const ANoReg, ANama,
  ATanggal, ALayanan, ADokter, AKet: string): Boolean;
var
  q: TSQLQuery;
begin
  Result := False;
  q := AppDB.NewQuery(ASQL);
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    q.Params.ParamByName('no_reg').AsString := ANoReg;
    q.Params.ParamByName('nama').AsString := ANama;
    if Trim(ATanggal) = '' then
      q.Params.ParamByName('tanggal').Clear
    else
      q.Params.ParamByName('tanggal').AsString := ATanggal;
    q.Params.ParamByName('layanan').AsString := ALayanan;
    q.Params.ParamByName('dokter').AsString := ADokter;
    q.Params.ParamByName('keterangan').AsString := AKet;
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

procedure TPendaftaranView.RefreshGrid;
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
    FStatusLabel.Caption := Format('%d pendaftaran', [FGridQuery.RecordCount]);
    FStatusLabel.Font.Color := clWindowText;
  except
    on E: Exception do
    begin
      FStatusLabel.Caption := 'Gagal membaca data: ' + E.Message;
      FStatusLabel.Font.Color := clRed;
    end;
  end;
end;

procedure TPendaftaranView.GridSelectionChanged(Sender: TObject; Field: TField);
begin
  LoadSelected;
end;

procedure TPendaftaranView.LoadSelected;
begin
  if (FGridQuery = nil) or (not FGridQuery.Active) or FGridQuery.EOF then
    Exit;
  FSelectedId := FGridQuery.FieldByName('id').AsInteger;
  FEdNo.Text := FGridQuery.FieldByName('no_reg').AsString;
  FEdNama.Text := FGridQuery.FieldByName('nama').AsString;
  FEdTanggal.Text := FGridQuery.FieldByName('tanggal').AsString;
  FEdLayanan.Text := FGridQuery.FieldByName('layanan').AsString;
  FEdDokter.Text := FGridQuery.FieldByName('dokter').AsString;
  FEdKet.Text := FGridQuery.FieldByName('keterangan').AsString;
  UpdateActionState;
end;

procedure TPendaftaranView.UpdateActionState;
begin
  FBtnSave.Enabled := ((FSelectedId = 0) and CanCreate) or
    ((FSelectedId > 0) and CanEdit);
  FBtnNew.Enabled := CanCreate;
  FBtnDelete.Enabled := CanDelete and (FSelectedId > 0);
end;

procedure TPendaftaranView.DoSave(Sender: TObject);
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
    MessageDlg('Info', 'Nama pasien tidak boleh kosong.', mtWarning, [mbOK], 0);
    Exit;
  end;

  if FSelectedId > 0 then
  begin
    SQL := 'update registrasi set no_reg=:no_reg, nama=:nama, ' +
      'tanggal=cast(:tanggal as date), layanan=:layanan, dokter=:dokter, ' +
      'keterangan=:keterangan where id=:id';
    if ExecDML(SQL, FEdNo.Text, FEdNama.Text, FEdTanggal.Text, FEdLayanan.Text,
      FEdDokter.Text, FEdKet.Text) then
    begin
      AuditLog('UPDATE', 'registrasi', FSelectedId,
        'Ubah: ' + FEdNama.Text + ' (' + FEdLayanan.Text + ')');
      RefreshGrid;
      LoadSelected;
    end;
  end
  else
  begin
    SQL := 'insert into registrasi (no_reg, nama, tanggal, layanan, dokter, ' +
      'keterangan) values (:no_reg, :nama, cast(:tanggal as date), ' +
      ':layanan, :dokter, :keterangan)';
    if ExecDML(SQL, FEdNo.Text, FEdNama.Text, FEdTanggal.Text, FEdLayanan.Text,
      FEdDokter.Text, FEdKet.Text) then
    begin
      AuditLog('CREATE', 'registrasi', 0,
        'Tambah: ' + FEdNama.Text + ' (' + FEdLayanan.Text + ')');
      FSelectedId := 0;
      RefreshGrid;
    end;
  end;
end;

procedure TPendaftaranView.DoNew(Sender: TObject);
begin
  if not CanCreate then
  begin
    MessageDlg('Akses Ditolak', 'Anda tidak memiliki hak menambah data.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  FSelectedId := 0;
  FEdNo.Text := '';
  FEdNama.Text := '';
  FEdTanggal.Text := '';
  FEdLayanan.Text := '';
  FEdDokter.Text := '';
  FEdKet.Text := '';
  UpdateActionState;
  FEdNama.SetFocus;
end;

procedure TPendaftaranView.DoDelete(Sender: TObject);
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
  if MessageDlg('Hapus', 'Hapus pendaftaran ini?', mtConfirmation,
    mbYesNo, 0) <> mrYes then
    Exit;
  q := AppDB.NewQuery('delete from registrasi where id=:id');
  try
    if not AppDB.Transaction.Active then
      AppDB.Transaction.StartTransaction;
    q.Params.ParamByName('id').AsInteger := FSelectedId;
    q.ExecSQL;
    AppDB.Transaction.Commit;
    AuditLog('DELETE', 'registrasi', FSelectedId,
      'Hapus pendaftaran id=' + IntToStr(FSelectedId));
    FSelectedId := 0;
  except
    on E: Exception do
      MessageDlg('Kesalahan', 'Gagal menghapus data:' + sLineBreak + E.Message,
        mtError, [mbOK], 0);
  end;
  q.Free;
  RefreshGrid;
end;

procedure TPendaftaranView.DoRefresh(Sender: TObject);
begin
  RefreshGrid;
end;

procedure TPendaftaranView.LblTitleClick(Sender: TObject);
begin

end;

end.
