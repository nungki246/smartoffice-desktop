unit uDashboardView;

{
  SmartOffice Desktop - Dashboard view (charts + summary).

  Home screen for the launcher. It renders a set of summary cards
  (jumlah pasien) and a bar chart of registrasi (patient registration)
  activity over the last 7 days, read from the `registrasi` table that is
  populated by the Pendaftaran module.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, ExtCtrls, StdCtrls, DateUtils,
  DB, sqldb, uModuleView;

type
  TDashboardView = class(TModuleView)
  private
    FBanner: TPanel;
    FCards: TPanel;
    FChart: TPanel;
    FTotal: TLabel;
    FToday: TLabel;
    FMonth: TLabel;
    FDayCount: array[0..6] of Integer;
    FDayMax: Integer;
    procedure ChartPaint(Sender: TObject);
    procedure EnsureSchema;
    function ScalarInt(const ASQL: string): Integer;
    function DayCountSQL(const ADate: string): string;
  public
    procedure AfterShow;
    procedure RefreshData;
    procedure BuildUI; override;
  end;

implementation

uses
  uDB, uApp, uRBAC, uTheme;

{$R *.lfm}

{ TDashboardView }

procedure TDashboardView.EnsureSchema;
begin
  if not AppDB.Connected then
    Exit;
  if AppDB.TableExists('registrasi') then
    Exit;
  AppDB.ExecSQL(
    'create table if not exists registrasi (' +
    ' id integer primary key autoincrement,' +
    ' no_reg varchar(30),' +
    ' nama varchar(120) not null,' +
    ' tanggal date,' +
    ' layanan varchar(80),' +
    ' dokter varchar(120),' +
    ' keterangan varchar(255))');
end;

function TDashboardView.ScalarInt(const ASQL: string): Integer;
var
  Q: TSQLQuery;
begin
  Result := 0;
  if not AppDB.Connected then
    Exit;
  Q := AppDB.NewQuery(ASQL);
  try
    try
      Q.Open;
      if not Q.EOF then
        Result := Q.Fields[0].AsInteger;
      Q.Close;
    except
      on E: Exception do
        LogMsg('Dashboard query failed: ' + E.Message);
    end;
  finally
    Q.Free;
  end;
end;

function TDashboardView.DayCountSQL(const ADate: string): string;
begin
  if AppDB.Kind = dbPostgreSQL then
    Result := 'select count(*) from registrasi where tanggal::date = ' + QuotedStr(ADate)
  else
    Result := 'select count(*) from registrasi where date(tanggal) = ' + QuotedStr(ADate);
end;

procedure TDashboardView.RefreshData;
var
  I: Integer;
  D: TDateTime;
begin
  EnsureSchema;
  if (RBAC = nil) or (not RBAC.IsLoggedIn) then
  begin
    FTotal.Caption := '-';
    FToday.Caption := '-';
    FMonth.Caption := '-';
    FillChar(FDayCount, SizeOf(FDayCount), 0);
    FDayMax := 1;
    FChart.Repaint;
    Exit;
  end;
  if not AppDB.Connected then
  begin
    FTotal.Caption := '-';
    FToday.Caption := '-';
    FMonth.Caption := '-';
    Exit;
  end;

  FDayMax := 0;
  for I := 0 to 6 do
  begin
    D := IncDay(Date, I - 6);
    FDayCount[I] := ScalarInt(DayCountSQL(FormatDateTime('YYYY-MM-DD', D)));
    if FDayCount[I] > FDayMax then
      FDayMax := FDayCount[I];
    if FDayCount[I] = 0 then
      FDayCount[I] := 0;
  end;
  if FDayMax = 0 then
    FDayMax := 1;

  FTotal.Caption := IntToStr(ScalarInt('select count(*) from registrasi')) + ' pasien';
  FToday.Caption := IntToStr(ScalarInt(
    'select count(*) from registrasi where date(tanggal) = ' +
    QuotedStr(FormatDateTime('YYYY-MM-DD', Date)))) + ' pasien hari ini';

  if AppDB.Kind = dbPostgreSQL then
    FMonth.Caption := IntToStr(ScalarInt(
      'select count(*) from registrasi where date_trunc(''month'', tanggal)::date = ' +
      'date_trunc(''month'', current_date)::date')) + ' pasien bulan ini'
  else
    FMonth.Caption := IntToStr(ScalarInt(
      'select count(*) from registrasi where strftime(''%Y-%m'', tanggal) = ' +
      'strftime(''%Y-%m'', ''now'')')) + ' pasien bulan ini';

  FChart.Repaint;
end;

procedure TDashboardView.ChartPaint(Sender: TObject);
const
  LeftPad = 48;
  RightPad = 16;
  TopPad = 32;
  BottomPad = 36;
var
  R: TRect;
  W, H, ColW, BarW, Gap, I, BarH, X, Y: Integer;
  MaxVal: Integer;
  Day: TDateTime;
  BarColor, AxisColor: TColor;
begin
  BarColor := AppTheme.ColorPrimary;
  AxisColor := AppTheme.ColorBorder;
  R := FChart.ClientRect;
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  MaxVal := FDayMax;
  if MaxVal < 1 then
    MaxVal := 1;
  ColW := (W - LeftPad - RightPad) div 7;
  BarW := Round(ColW * 0.55);
  Gap := (ColW - BarW) div 2;
  FChart.Canvas.Brush.Style := bsClear;
  FChart.Canvas.Pen.Color := AxisColor;
  // baseline
  FChart.Canvas.MoveTo(LeftPad, H - BottomPad);
  FChart.Canvas.LineTo(W - RightPad, H - BottomPad);
  // axis
  FChart.Canvas.MoveTo(LeftPad, TopPad);
  FChart.Canvas.LineTo(LeftPad, H - BottomPad);
  for I := 0 to 6 do
  begin
    BarH := Round((FDayCount[I] / MaxVal) * (H - TopPad - BottomPad));
    X := LeftPad + I * ColW + Gap;
    Y := H - BottomPad - BarH;
    if BarH > 0 then
    begin
      FChart.Canvas.Brush.Color := BarColor;
      FChart.Canvas.Brush.Style := bsSolid;
      FChart.Canvas.FillRect(Rect(X, Y, X + BarW, H - BottomPad));
      FChart.Canvas.Brush.Style := bsClear;
      FChart.Canvas.Pen.Color := clBlack;
      FChart.Canvas.TextOut(X, Y - 15, IntToStr(FDayCount[I]));
      FChart.Canvas.Pen.Color := AxisColor;
    end;
    Day := IncDay(Date, I - 6);
    FChart.Canvas.Font.Color := clGrayText;
    FChart.Canvas.TextOut(X, H - BottomPad + 6, FormatDateTime('dd', Day));
    FChart.Canvas.TextOut(X, H - BottomPad + 20, FormatDateTime('mm-dd', Day));
  end;
  // title
  FChart.Canvas.Font.Style := [fsBold];
  FChart.Canvas.Font.Color := clWindowText;
  FChart.Canvas.TextOut(LeftPad, 6, 'Pendaftaran per hari (7 hari terakhir)');
  FChart.Canvas.Font.Style := [];
end;

procedure TDashboardView.AfterShow;
begin
  RefreshData;
end;

procedure TDashboardView.BuildUI;
var
  Lbl: TLabel;
  Card: TPanel;
begin
  inherited BuildUI;
  Color := AppTheme.ColorBackgroundAlt;

  FBanner := TPanel.Create(Self);
  FBanner.Parent := Self;
  FBanner.Align := alTop;
  FBanner.Height := 72;
  FBanner.BevelOuter := bvNone;
  FBanner.Color := AppTheme.ColorPrimary;

  Lbl := TLabel.Create(FBanner);
  Lbl.Parent := FBanner;
  Lbl.Left := 24;
  Lbl.Top := 16;
  Lbl.Font.Size := AppTheme.FontSizeXL;
  Lbl.Font.Style := [fsBold];
  Lbl.Font.Name := AppTheme.FontFamily;
  Lbl.Font.Color := clWhite;
  Lbl.Caption := 'Dashboard';
  Lbl.AutoSize := True;

  Lbl := TLabel.Create(FBanner);
  Lbl.Parent := FBanner;
  Lbl.Left := 24;
  Lbl.Top := 44;
  Lbl.Font.Size := AppTheme.FontSizeXS;
  Lbl.Font.Name := AppTheme.FontFamily;
  Lbl.Font.Color := $00E0E0E0;
  Lbl.Caption := 'Ringkasan jumlah pasien dan grafik pendaftaran';
  Lbl.AutoSize := True;

  FCards := TPanel.Create(Self);
  FCards.Parent := Self;
  FCards.Align := alTop;
  FCards.Height := 108;
  FCards.BevelOuter := bvNone;
  FCards.Color := AppTheme.ColorBackgroundAlt;
  FCards.BorderSpacing.Bottom := 16;

  Card := TPanel.Create(FCards);
  Card.Parent := FCards;
  Card.Align := alLeft;
  Card.Width := 200;
  Card.BevelOuter := bvNone;
  Card.Color := AppTheme.ColorCategorySystem;
  Card.BorderSpacing.Left := 16;
  Card.BorderSpacing.Top := 16;
  FTotal := TLabel.Create(Card);
  FTotal.Parent := Card;
  FTotal.Align := alClient;
  FTotal.Layout := tlCenter;
  FTotal.Alignment := taCenter;
  FTotal.Font.Size := 16;
  FTotal.Font.Style := [fsBold];
  FTotal.Font.Color := clWhite;
  FTotal.Caption := '0 pasien';

  Card := TPanel.Create(FCards);
  Card.Parent := FCards;
  Card.Align := alLeft;
  Card.Width := 200;
  Card.BevelOuter := bvNone;
  Card.Color := AppTheme.ColorCategoryHR;
  Card.BorderSpacing.Left := 16;
  Card.BorderSpacing.Top := 16;
  FToday := TLabel.Create(Card);
  FToday.Parent := Card;
  FToday.Align := alClient;
  FToday.Layout := tlCenter;
  FToday.Alignment := taCenter;
  FToday.Font.Size := 16;
  FToday.Font.Style := [fsBold];
  FToday.Font.Color := clWhite;
  FToday.Caption := '0 pasien hari ini';

  Card := TPanel.Create(FCards);
  Card.Parent := FCards;
  Card.Align := alLeft;
  Card.Width := 200;
  Card.BevelOuter := bvNone;
  Card.Color := AppTheme.ColorCategoryAdmin;
  Card.BorderSpacing.Left := 16;
  Card.BorderSpacing.Top := 16;
  FMonth := TLabel.Create(Card);
  FMonth.Parent := Card;
  FMonth.Align := alClient;
  FMonth.Layout := tlCenter;
  FMonth.Alignment := taCenter;
  FMonth.Font.Size := 16;
  FMonth.Font.Style := [fsBold];
  FMonth.Font.Color := clWhite;
  FMonth.Caption := '0 pasien bulan ini';

  FChart := TPanel.Create(Self);
  FChart.Parent := Self;
  FChart.Align := alClient;
  FChart.BevelOuter := bvNone;
  FChart.Color := AppTheme.ColorBackgroundAlt;
  FChart.BorderSpacing.Around := 16;
  FChart.OnPaint := @ChartPaint;
end;

end.
