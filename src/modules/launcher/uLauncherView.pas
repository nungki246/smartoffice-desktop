unit uLauncherView;

{
  SmartOffice Desktop - Launcher (home) view.

  Modern production home screen: a gradient hero banner with a personalized
  greeting, current date and a rounded live-search box on top; below it a
  responsive grid of application tiles. Tiles are custom painted vertical
  cards (rounded corners, soft hover ring, category pill that turns into a
  "Buka" affordance on hover) so the launcher needs no image assets. The
  grid wraps automatically when the window is resized (TFlowPanel).
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Controls, Graphics, ExtCtrls, StdCtrls,
  uModuleView, uModule, uIcons, uTheme;

type
  TModuleOpenEvent = procedure(const AID: TModuleID) of object;

  { Mixes AColor towards BColor by AFrac (0..1). }
  function MixColor(AColor, BColor: TColor; AFrac: Double): TColor;

type
  { TSearchBox - a custom painted rounded search field with a magnifier icon
    and a small caption. The whole control aligns right and fills the full
    hero height; on Resize it re-centers the field and positions the caption. }
  TSearchBox = class(TPanel)
  private
    FEdit: TEdit;
    FFocused: Boolean;
    FFieldRect: TRect;
    procedure EditEnter(Sender: TObject);
    procedure EditExit(Sender: TObject);
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    property SearchEdit: TEdit read FEdit;
  end;



  { TAppTile - a single clickable application card. }
  TAppTile = class(TPanel)
  private
    FModule: TBaseModule;
    FColor: TColor;
    FGlyph: TAppGlyph;
    FHover: Boolean;
    FDown: Boolean;
    FIcon: TBitmap;
    FOnOpen: TNotifyEvent;
    procedure DoMouseEnter(Sender: TObject);
    procedure DoMouseLeave(Sender: TObject);
    procedure DoMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DoMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure DoClick(Sender: TObject);
  protected
    procedure Paint; override;
  public
    constructor CreateTile(AOwner: TComponent; AModule: TBaseModule;
      AColor: TColor; AGlyph: TAppGlyph);
    destructor Destroy; override;
    property TileModule: TBaseModule read FModule;
    property OnOpen: TNotifyEvent read FOnOpen write FOnOpen;
  end;

  TLauncherView = class(TModuleView)
  private
    FFlow: TFlowPanel;
    FSearch: TEdit;
    FEmptyLabel: TLabel;
    FSectionLabel: TLabel;
    FCategory: string;
    FOnOpenModule: TModuleOpenEvent;
    function TileColorFor(const ACategory: string): TColor;
    function GlyphForModule(const AID: string): TAppGlyph;
    procedure SearchChanged(Sender: TObject);
    procedure TileOpen(Sender: TObject);
    procedure CenterColumns(Sender: TObject);
  public
    property OnOpenModule: TModuleOpenEvent read FOnOpenModule write FOnOpenModule;
    procedure SetCategory(const ACategory: string);
    procedure RefreshData;
    procedure Recenter;
    procedure BuildUI; override;
  end;

implementation

uses
  uModuleManager, uRBAC, Types;

{$R *.lfm}

{ --- color helpers ------------------------------------------------------ }

function MixColor(AColor, BColor: TColor; AFrac: Double): TColor;
var
  R1, G1, B1, R2, G2, B2: Byte;
  A1, A2: LongInt;
begin
  A1 := ColorToRGB(AColor);
  A2 := ColorToRGB(BColor);
  R1 := A1 and $FF;
  G1 := (A1 shr 8) and $FF;
  B1 := (A1 shr 16) and $FF;
  R2 := A2 and $FF;
  G2 := (A2 shr 8) and $FF;
  B2 := (A2 shr 16) and $FF;
  Result := RGBToColor(
    Round(R1 + (R2 - R1) * AFrac),
    Round(G1 + (G2 - G1) * AFrac),
    Round(B1 + (B2 - B1) * AFrac));
end;

function LightenColor(AColor: TColor; AFrac: Double): TColor;
begin
  Result := MixColor(AColor, clWhite, AFrac);
end;

function DarkenColor(AColor: TColor; AFrac: Double): TColor;
begin
  Result := MixColor(AColor, clBlack, AFrac);
end;

{ TSearchBox }

constructor TSearchBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Color := clNone;
  ParentColor := False;
  DoubleBuffered := True;

  FEdit := TEdit.Create(Self);
  FEdit.Parent := Self;
  FEdit.BorderStyle := bsNone;
  FEdit.AutoSize := False;
  FEdit.Font.Name := AppTheme.FontFamily;
  FEdit.Font.Size := AppTheme.FontSizeSM;
  FEdit.TextHint := 'Cari aplikasi...';
  FEdit.OnEnter := @EditEnter;
  FEdit.OnExit := @EditExit;
end;

procedure TSearchBox.EditEnter(Sender: TObject);
begin
  FFocused := True;
  Invalidate;
end;

procedure TSearchBox.EditExit(Sender: TObject);
begin
  FFocused := False;
  Invalidate;
end;

procedure TSearchBox.Resize;
var
  FieldW, FieldH, FieldX, FieldY: Integer;
begin
  inherited Resize;
  // Resize can fire during construction (layout of the caption label) before
  // FEdit is created; skip until all children exist.
  if FEdit = nil then
    Exit;
  // Keep the field wide, centered horizontally and vertically in the box.
  FieldW := Min(440, Width - 32);
  FieldH := 44;
  FieldX := (Width - FieldW) div 2;
  FieldY := (Height - FieldH) div 2;
  FFieldRect := Bounds(FieldX, FieldY, FieldW, FieldH);
  FEdit.SetBounds(FieldX + 48, FieldY + 10, FieldW - 60, FieldH - 20);
end;

procedure TSearchBox.Paint;
var
  Bg: TColor;
  MRect: TRect;
begin
  // Rounded white field with a colored focus ring.
  if FFocused then
    Bg := LightenColor(AppTheme.ColorPrimary, 0.95)
  else
    Bg := clWhite;

  Canvas.Pen.Style := psClear;
  
  // Shadow or Glow
  if FFocused then
  begin
    Canvas.Brush.Color := AppTheme.ColorGlow;
    Canvas.RoundRect(FFieldRect.Left - 2, FFieldRect.Top - 2, FFieldRect.Right + 2, FFieldRect.Bottom + 2, AppTheme.RadiusLG + 2, AppTheme.RadiusLG + 2);
  end
  else
  begin
    Canvas.Brush.Color := AppTheme.ColorShadow;
    Canvas.RoundRect(FFieldRect.Left, FFieldRect.Top + 2, FFieldRect.Right, FFieldRect.Bottom + 2, AppTheme.RadiusLG, AppTheme.RadiusLG);
  end;

  Canvas.Brush.Color := Bg;
  Canvas.RoundRect(FFieldRect, AppTheme.RadiusLG, AppTheme.RadiusLG);

  if FFocused then
    Canvas.Pen.Color := AppTheme.ColorPrimary
  else
    Canvas.Pen.Color := AppTheme.ColorBorder;
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsClear;
  Canvas.RoundRect(FFieldRect.Left, FFieldRect.Top, FFieldRect.Right, FFieldRect.Bottom, AppTheme.RadiusLG, AppTheme.RadiusLG);

  // Magnifier glyph (left inside the field).
  MRect := FFieldRect;
  Canvas.Pen.Style := psSolid;
  if FFocused then
    Canvas.Pen.Color := AppTheme.ColorPrimary
  else
    Canvas.Pen.Color := AppTheme.ColorTextSecondary;
  Canvas.Pen.Width := 2;
  Canvas.Brush.Style := bsClear;
  Canvas.Ellipse(MRect.Left + 16, MRect.Top + (MRect.Height - 16) div 2,
    MRect.Left + 32, MRect.Top + (MRect.Height - 16) div 2 + 16);
  Canvas.Pen.Width := 2;
  Canvas.MoveTo(MRect.Left + 29, MRect.Top + (MRect.Height - 16) div 2 + 13);
  Canvas.LineTo(MRect.Left + 38, MRect.Top + (MRect.Height - 16) div 2 + 22);
  Canvas.Pen.Width := 1;
  Canvas.Pen.Style := psClear;
end;



{ TAppTile }

constructor TAppTile.CreateTile(AOwner: TComponent; AModule: TBaseModule;
  AColor: TColor; AGlyph: TAppGlyph);
begin
  inherited Create(AOwner);
  FModule := AModule;
  FColor := AColor;
  FGlyph := AGlyph;
  FHover := False;
  FDown := False;
  FIcon := TBitmap.Create;
  DrawAppIcon(FIcon, FColor, FGlyph);
  Width := 280;
  Height := 140;
  BevelOuter := bvNone;
  Color := AppTheme.ColorSurface;
  Cursor := crHandPoint;
  ParentColor := False;
  OnClick := @DoClick;
  OnMouseEnter := @DoMouseEnter;
  OnMouseLeave := @DoMouseLeave;
  OnMouseDown := @DoMouseDown;
  OnMouseUp := @DoMouseUp;
  Hint := FModule.Title + sLineBreak + FModule.Description;
  ShowHint := True;
  DoubleBuffered := True;
end;

destructor TAppTile.Destroy;
begin
  FIcon.Free;
  inherited Destroy;
end;

procedure TAppTile.DoMouseEnter(Sender: TObject);
begin
  FHover := True;
  Invalidate;
end;

procedure TAppTile.DoMouseLeave(Sender: TObject);
begin
  FHover := False;
  FDown := False;
  Invalidate;
end;

procedure TAppTile.DoMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDown := True;
  Invalidate;
end;

procedure TAppTile.DoMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FDown := False;
  Invalidate;
end;

procedure TAppTile.DoClick(Sender: TObject);
begin
  if Assigned(FOnOpen) and (FModule <> nil) then
    FOnOpen(Self);
end;

procedure TAppTile.Paint;
var
  IconRect: TRect;
  IconBg: TRect;
  TitleRect: TRect;
  DescRect: TRect;
  PillRect: TRect;
  PillW: Integer;
  Style: TTextStyle;
  Bg, Border: TColor;
begin
  inherited Paint;
  Canvas.Pen.Style := psClear;
  Canvas.Brush.Style := bsSolid;

  // Drop shadow
  Canvas.Brush.Color := AppTheme.ColorShadow;
  Canvas.RoundRect(2, 4, Width, Height, AppTheme.RadiusLG + 4, AppTheme.RadiusLG + 4);

  // Card background (pressed state gives tactile feedback).
  if FDown then
    Bg := AppTheme.ColorSurfacePressed
  else if FHover then
    Bg := AppTheme.ColorSurfaceHover
  else
    Bg := AppTheme.ColorSurface;
  Canvas.Brush.Color := Bg;
  Canvas.RoundRect(0, 0, Width - 2, Height - 2, AppTheme.RadiusLG + 4, AppTheme.RadiusLG + 4);

  // Brand accent line on the left side on hover
  if FHover then
  begin
    Canvas.Brush.Color := FColor;
    Canvas.RoundRect(0, 0, 8, Height - 2, AppTheme.RadiusLG + 4, AppTheme.RadiusLG + 4);
    Canvas.FillRect(4, 0, 8, Height - 2); // Overdraw right side of accent
  end;

  // Border
  Border := AppTheme.ColorBorder;
  Canvas.Pen.Color := Border;
  Canvas.Pen.Width := 1;
  Canvas.Brush.Style := bsClear;
  Canvas.RoundRect(0, 0, Width - 2, Height - 2, AppTheme.RadiusLG + 4, AppTheme.RadiusLG + 4);
  Canvas.Pen.Width := 1;
  Canvas.Pen.Style := psClear;
  Canvas.Brush.Style := bsSolid;

  // Icon inside a soft circle background, aligned left
  IconBg := Bounds(20, 20, 48, 48);
  Canvas.Brush.Color := MixColor(FColor, Bg, 0.15);
  Canvas.Ellipse(IconBg.Left, IconBg.Top, IconBg.Right, IconBg.Bottom);
  
  Canvas.Brush.Style := bsClear;
  IconRect := Bounds(IconBg.Left + 10, IconBg.Top + 10, 28, 28);
  Canvas.StretchDraw(IconRect, FIcon);

  // Title (left aligned, next to icon).
  Style := Default(TTextStyle);
  Style.Alignment := taLeftJustify;
  Style.Layout := tlCenter;
  Style.SingleLine := True;
  Style.Clipping := True;
  Style.EndEllipsis := True;
  Canvas.Font.Name := AppTheme.FontFamily;
  Canvas.Font.Size := AppTheme.FontSizeMD;
  Canvas.Font.Style := [fsBold];
  if FHover then
    Canvas.Font.Color := FColor
  else
    Canvas.Font.Color := AppTheme.ColorTextPrimary;
  TitleRect := Bounds(82, 22, Width - 100, 24);
  Canvas.TextRect(TitleRect, TitleRect.Left, TitleRect.Top, FModule.Title, Style);

  // Description (secondary, wrapped, below title).
  Canvas.Font.Style := [];
  Canvas.Font.Color := AppTheme.ColorTextSecondary;
  Canvas.Font.Size := AppTheme.FontSizeXS;
  Style.SingleLine := False;
  Style.EndEllipsis := True;
  Style.Wordbreak := True;
  Style.Layout := tlTop;
  DescRect := Bounds(82, 48, Width - 100, 38);
  Canvas.TextRect(DescRect, DescRect.Left, DescRect.Top, FModule.Description, Style);

  // Bottom pill: category normally, "Buka" affordance on hover (bottom right).
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Size := AppTheme.FontSizeXS;
  if FHover then
  begin
    PillW := Canvas.TextWidth('Buka  >') + 24;
    PillRect := Bounds(Width - PillW - 20, Height - 40, PillW, 26);
    Canvas.Pen.Style := psClear;
    Canvas.Brush.Color := FColor;
    Canvas.RoundRect(PillRect.Left, PillRect.Top, PillRect.Right, PillRect.Bottom, 13, 13);
    Canvas.Font.Color := clWhite;
    Style.SingleLine := True;
    Style.Alignment := taCenter;
    Style.Layout := tlCenter;
    Canvas.TextRect(PillRect, PillRect.Left, PillRect.Top, 'Buka  >', Style);
  end
  else
  begin
    PillW := Canvas.TextWidth(FModule.Category) + 20;
    PillRect := Bounds(Width - PillW - 20, Height - 40, PillW, 26);
    Canvas.Pen.Width := 1;
    Canvas.Pen.Color := AppTheme.ColorBorder;
    Canvas.Brush.Color := MixColor(AppTheme.ColorBorder, Bg, 0.2);
    Canvas.RoundRect(PillRect.Left, PillRect.Top, PillRect.Right, PillRect.Bottom, 13, 13);
    Canvas.Pen.Style := psClear;
    Canvas.Font.Color := AppTheme.ColorTextSecondary;
    Style.SingleLine := True;
    Style.Alignment := taCenter;
    Style.Layout := tlCenter;
    Canvas.TextRect(PillRect, PillRect.Left, PillRect.Top, FModule.Category, Style);
  end;
  Canvas.Font.Style := [];
end;

{ TLauncherView }

procedure TLauncherView.BuildUI;
var
  LSearchBox: TSearchBox;
begin
  inherited BuildUI;
  Color := AppTheme.ColorBackgroundAlt;
  ParentColor := False;

  // ---- search box ----
  LSearchBox := TSearchBox.Create(Self);
  LSearchBox.Parent := Self;
  LSearchBox.Align := alTop;
  LSearchBox.Height := 72;

  FSearch := LSearchBox.SearchEdit;
  FSearch.OnChange := @SearchChanged;

  // ---- section heading (small caption above the grid) ----
  FSectionLabel := TLabel.Create(Self);
  FSectionLabel.Parent := Self;
  FSectionLabel.Align := alTop;
  FSectionLabel.Height := 44;
  FSectionLabel.AutoSize := False;
  FSectionLabel.Transparent := True;
  FSectionLabel.BorderSpacing.Left := AppTheme.SpaceLG;
  FSectionLabel.BorderSpacing.Top := AppTheme.SpaceSM;
  FSectionLabel.Font.Name := AppTheme.FontFamily;
  FSectionLabel.Font.Size := AppTheme.FontSizeXS;
  FSectionLabel.Font.Style := [fsBold];
  FSectionLabel.Font.Color := AppTheme.ColorTextSecondary;
  FSectionLabel.Caption := '';

  // ---- app grid ----
  FFlow := TFlowPanel.Create(Self);
  FFlow.Parent := Self;
  FFlow.Align := alClient;
  FFlow.BevelOuter := bvNone;
  FFlow.Color := AppTheme.ColorBackgroundAlt;
  FFlow.ParentColor := False;
  FFlow.AutoSize := False;
  FFlow.AutoWrap := True;
  FFlow.FlowStyle := fsLeftRightTopBottom;
  FFlow.BorderSpacing.Left := AppTheme.SpaceLG;
  FFlow.BorderSpacing.Right := AppTheme.SpaceLG;
  FFlow.BorderSpacing.Top := AppTheme.SpaceMD;
  FFlow.ChildSizing.LeftRightSpacing := 0;
  FFlow.ChildSizing.TopBottomSpacing := 0;
  FFlow.ChildSizing.HorizontalSpacing := AppTheme.SpaceLG;
  FFlow.ChildSizing.VerticalSpacing := AppTheme.SpaceLG;
  // Re-center every time the flow gets laid out (resize of the view, tiles
  // added/removed, etc.). Computing from ClientWidth keeps this loop-free.
  FFlow.OnResize := @CenterColumns;

  // Empty state (shown when search has no hits).
  FEmptyLabel := TLabel.Create(Self);
  FEmptyLabel.Parent := Self;
  FEmptyLabel.Align := alClient;
  FEmptyLabel.Alignment := taCenter;
  FEmptyLabel.Layout := tlCenter;
  FEmptyLabel.Transparent := True;
  FEmptyLabel.Visible := False;
  FEmptyLabel.Font.Name := AppTheme.FontFamily;
  FEmptyLabel.Font.Size := AppTheme.FontSizeMD;
  FEmptyLabel.Font.Color := AppTheme.ColorTextSecondary;
  FEmptyLabel.Caption := 'Tidak ada aplikasi ditemukan.';

  CenterColumns(nil);
end;

function TLauncherView.TileColorFor(const ACategory: string): TColor;
begin
  if ACategory = 'Aplikasi' then
    Result := AppTheme.ColorCategoryClinical
  else if ACategory = 'Sistem' then
    Result := AppTheme.ColorCategoryAdmin
  else if ACategory = 'Sumber Daya' then
    Result := AppTheme.ColorCategoryHR
  else
    Result := AppTheme.ColorCategorySystem;
end;

function TLauncherView.GlyphForModule(const AID: string): TAppGlyph;
begin
  case LowerCase(AID) of
    'dashboard':   Result := gHome;
    'pendaftaran': Result := gDocument;
    'perawat':     Result := gNurse;
    'employees':   Result := gPerson;
    'settings':    Result := gSettings;
    'rbac':        Result := gShield;
    'apps':        Result := gPackage;
    else           Result := gDocument;
  end;
end;

procedure TLauncherView.SearchChanged(Sender: TObject);
begin
  RefreshData;
end;

procedure TLauncherView.TileOpen(Sender: TObject);
begin
  if Assigned(FOnOpenModule) and
     (Sender is TAppTile) and (TAppTile(Sender).TileModule <> nil) then
    FOnOpenModule(TAppTile(Sender).TileModule.ID);
end;

procedure TLauncherView.CenterColumns(Sender: TObject);
var
  Available, TileW, Gap, Cols, ContentW, Margin, NewL, NewR: Integer;
begin
  if FFlow = nil then
    Exit;
  TileW := 280;
  Gap := AppTheme.SpaceLG;
  // Base the math on the view's client width: it never changes when we alter
  // FFlow.BorderSpacing, so this cannot feed a resize <-> re-center loop.
  Available := ClientWidth;
  if Available <= 0 then
    Exit;
  Cols := (Available + Gap) div (TileW + Gap);
  if Cols < 1 then
    Cols := 1;
  ContentW := Cols * TileW + (Cols - 1) * Gap;
  Margin := (Available - ContentW) div 2;
  if Margin < 0 then
    Margin := 0;
  NewL := Margin;
  NewR := Margin;
  // Only touch BorderSpacing when it actually changes, otherwise the setter
  // re-flows the panel and we end up in an endless resize/invalidate loop.
  if (FFlow.BorderSpacing.Left <> NewL) or (FFlow.BorderSpacing.Right <> NewR) then
  begin
    FFlow.BorderSpacing.Left := NewL;
    FFlow.BorderSpacing.Right := NewR;
  end;
end;

procedure TLauncherView.Recenter;
begin
  CenterColumns(nil);
end;

procedure TLauncherView.SetCategory(const ACategory: string);
begin
  FCategory := ACategory;
  RefreshData;
end;

procedure TLauncherView.RefreshData;
var
  I, MCount: Integer;
  M: TBaseModule;
  Tile: TAppTile;
  Keyword, Title, Desc: string;
begin
  // Release old tiles.
  while FFlow.ControlCount > 0 do
    FFlow.Controls[0].Free;

  Keyword := Trim(LowerCase(FSearch.Text));

  MCount := ModuleManager.VisibleCount;
  for I := 0 to MCount - 1 do
  begin
    M := ModuleManager.GetVisibleModule(I);
    if M = nil then
      Continue;
    if (FCategory <> '') and (M.Category <> FCategory) then
      Continue;

    Title := LowerCase(M.Title);
    Desc := LowerCase(M.Description);
    if (Keyword <> '') and
       (Pos(Keyword, Title) = 0) and (Pos(Keyword, Desc) = 0) then
      Continue;

    Tile := TAppTile.CreateTile(FFlow, M, TileColorFor(M.Category),
      GlyphForModule(M.ID));
    Tile.Parent := FFlow;
    Tile.OnOpen := @TileOpen;
  end;

  // Toggle empty state when the search yields nothing.
  if FFlow.ControlCount = 0 then
  begin
    FEmptyLabel.Visible := True;
    FFlow.Visible := False;
  end
  else
  begin
    FEmptyLabel.Visible := False;
    FFlow.Visible := True;
  end;

  // Section heading: category name, or a friendly default when showing all.
  if FCategory <> '' then
    FSectionLabel.Caption := UpperCase(FCategory)
  else
    FSectionLabel.Caption := 'SEMUA APLIKASI';

  CenterColumns(nil);
end;

end.
