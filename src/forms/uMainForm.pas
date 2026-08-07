unit uMainForm;

{
  SmartOffice Desktop Launcher - main window.

  Layout:
    * Top header bar with application title and database status
    * Left: navigation tree grouped by module category
    * Center: view host that swaps the active module view
    * Bottom: status bar

  The form is built entirely in code (no .lfm) so it can be opened directly
  with lazbuild and extended easily.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls,
  ComCtrls, Buttons, Menus, uModule, uIcons, uTheme;

type

  { TMainForm }

  TMainForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FViewHostClick(Sender: TObject);
    procedure HTitleClick(Sender: TObject);
    procedure MenuFileClick(Sender: TObject);
  published
    FHeader: TPanel;
    FDbChip: TPanel;
    FUserChip: TPanel;
    FNavTree: TTreeView;
    FNavPanel: TPanel;
    FViewHost: TPanel;
    FStatusBar: TStatusBar;
    FDbBadge: TLabel;
    FDbDot: TShape;
    FUserBadge: TLabel;
    FUserAvatar: TShape;
    FAvatarText: TLabel;
  private
    FNavImages: TImageList;
    FCurrentModule: TBaseModule;
    FCurrentView: TControl;
    FAppMenu: TMainMenu;
    FSettingsMenu: TMenuItem;
    FAppsMenuItem: TMenuItem;
    FNavMenuItem: TMenuItem;
    FNavToggleBtn: TSpeedButton;
    FLoginMenuItem: TMenuItem;       // Sesi > Login
    FSwitchUserMenuItem: TMenuItem;  // Sesi > Ganti Pengguna
    FAppMenuMap: TStringList;
    FAppMenuIndex: Integer;
    FInNavSelection: Boolean;
    FHomeFilter: string;
    FLastOpenId: TModuleID;
    FLastOpenTick: QWord;
    FLastAppsReloadTick: QWord;
    FUpdateTimer: TTimer;

    procedure BuildUI;
    procedure BuildMenu;
    procedure DoFormActivate(Sender: TObject);
    function NavGlyphForModule(const AID: string): TAppGlyph;
    function TileColorForCategory(const ACategory: string): TColor;
    function MakeNavIcon(AColor: TColor; AGlyph: TAppGlyph): TBitmap;
    procedure LoadExternalModules;
    procedure RefreshAppsMenu;
    procedure ShowAppsManager(Sender: TObject);
    procedure ShowAllApps(Sender: TObject);
    procedure AppMenuItemClick(Sender: TObject);
    procedure PopulateModuleTree;
    procedure NavSelectionChanged(Sender: TObject);
    procedure OpenModule(const AID: TModuleID);
    procedure LaunchExternal(M: TBaseModule);
    procedure ShowSettings(Sender: TObject);
    procedure ShowAbout(Sender: TObject);
    procedure DoCheckUpdates(Sender: TObject);
    procedure DoAutoCheckUpdate(Sender: TObject);
    procedure DoAppExit(Sender: TObject);
    procedure DoLogout(Sender: TObject);
    procedure DoLogin(Sender: TObject);
    procedure ClearAppContent;
    procedure DoConnect(Sender: TObject);
    procedure DoSwitchUser(Sender: TObject);
    procedure UpdateStatusBar;
    procedure UpdateDbBadge;
    procedure UpdateUserBadge;
    procedure UpdateSessionMenu;
    function IsInProcessModule(const AID: TModuleID): Boolean;
    procedure ApplyNavPanel;
    procedure DoToggleNav(Sender: TObject);
  protected
    procedure DoShow; override;
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AfterLogin;
  end;

var
  MainForm: TMainForm;

implementation

uses
  uApp, uDB, uModuleManager, uLauncherView, uRBAC, uApps,
  uLoginForm, uLaunch, uAudit, uPaths, uUpdater, uVersion,
  Types, Dialogs, Windows;

{$R *.lfm}

{ TMainForm }

constructor TMainForm.Create(AOwner: TComponent);
begin
  // Load the form layout from the .lfm (designer-editable).
  inherited Create(AOwner);
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  BuildMenu;
  BuildUI;
  OnActivate := @DoFormActivate;
  FUpdateTimer := TTimer.Create(Self);
  FUpdateTimer.Interval := 2500;
  FUpdateTimer.Enabled := False;
  FUpdateTimer.OnTimer := @DoAutoCheckUpdate;
end;

destructor TMainForm.Destroy;
begin
  FAppMenuMap.Free;
  inherited Destroy;
end;

procedure TMainForm.DoShow;
begin
  inherited DoShow;
  try
    if WindowState <> wsMaximized then
    begin
      if AppConfig.MainWidth > 0 then
        Width := AppConfig.MainWidth;
      if AppConfig.MainHeight > 0 then
        Height := AppConfig.MainHeight;
    end;
    if not AppDB.Connected then
    begin
      LogMsg('Menghubungkan ke database...');
      AppDB.ConnectFromConfig;
      if AppDB.Connected then
        LogMsg('Database terhubung: ' + AppDB.ServerVersion)
      else
        LogMsg('Koneksi database gagal: ' + AppDB.LastError);
    end;
    // Keep the UI empty until a successful login (login can happen later via
    // menu Sesi > Login...). Without this the nav tree and view host get
    // populated before any session exists.
    if (RBAC = nil) or (not RBAC.IsLoggedIn) then
    begin
      ClearAppContent;
      Exit;
    end;
    LoadExternalModules;
    UpdateDbBadge;
    UpdateUserBadge;
    UpdateStatusBar;
    UpdateSessionMenu;
    ApplyNavPanel;
    FSettingsMenu.Visible := RBAC.CanView('settings');
    if not IsInProcessModule(AppConfig.LastModule) then
      AppConfig.LastModule := 'home';
    LogMsg('Membuka modul: ' + AppConfig.LastModule);
    OpenModule(AppConfig.LastModule);
  except
    on E: Exception do
    begin
      LogMsg('Exception di DoShow: ' + E.ClassName + ': ' + E.Message);
      MessageDlg('Error', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.ApplyNavPanel;
begin
  FNavPanel.Visible := AppConfig.ShowNavPanel;
  if FNavMenuItem <> nil then
    FNavMenuItem.Checked := FNavPanel.Visible;
end;

procedure TMainForm.DoToggleNav(Sender: TObject);
begin
  AppConfig.ShowNavPanel := not FNavPanel.Visible;
  ApplyNavPanel;
  AppConfig.Save;
end;

procedure TMainForm.AfterLogin;
begin
  LoadExternalModules;
  ApplyNavPanel;
  UpdateDbBadge;
  UpdateUserBadge;
  UpdateStatusBar;
  UpdateSessionMenu;
  FSettingsMenu.Visible := RBAC.CanView('settings');
  if not IsInProcessModule(AppConfig.LastModule) then
    AppConfig.LastModule := 'home';
  if FCurrentView is TLauncherView then
    TLauncherView(FCurrentView).RefreshData
  else
    OpenModule(AppConfig.LastModule);
  if (AppConfig.UpdateRepo <> '') or (DefaultUpdateRepo <> '') then
  begin
    FUpdateTimer.Enabled := False;
    FUpdateTimer.Enabled := True;
  end;
  BringToFront;
end;

procedure TMainForm.DoClose(var CloseAction: TCloseAction);
begin
  if (RBAC <> nil) and RBAC.IsLoggedIn then
  begin
    AuditLog('LOGOUT', 'auth', RBAC.User.UserId, 'Logout: ' + RBAC.Username);
    RBAC.RevokeSession;
  end;
  TerminateLaunchedModules;
  if WindowState <> wsMaximized then
  begin
    AppConfig.MainWidth := Width;
    AppConfig.MainHeight := Height;
  end;
  AppConfig.Save;
  inherited DoClose(CloseAction);
end;

procedure TMainForm.BuildMenu;
var
  Mi, Mi2: TMenuItem;
begin
  FAppMenu := TMainMenu.Create(Self);
  FAppMenu.OwnerDraw := False;
  Menu := FAppMenu;

  // ---- Menu: Sesi ----
  // Semua tindakan yang berhubungan dengan pengguna dan sesi
  Mi := TMenuItem.Create(FAppMenu);
  Mi.Caption := '&Sesi';
  FAppMenu.Items.Add(Mi);

  FLoginMenuItem := TMenuItem.Create(FAppMenu);
  FLoginMenuItem.Caption := '&Login...';
  FLoginMenuItem.ShortCut := ShortCut(Ord('L'), [ssCtrl, ssShift]);
  FLoginMenuItem.OnClick := @DoLogin;
  Mi.Add(FLoginMenuItem);

  FSwitchUserMenuItem := TMenuItem.Create(FAppMenu);
  FSwitchUserMenuItem.Caption := 'Ganti &Pengguna...';
  FSwitchUserMenuItem.ShortCut := ShortCut(Ord('U'), [ssCtrl, ssShift]);
  FSwitchUserMenuItem.OnClick := @DoSwitchUser;
  Mi.Add(FSwitchUserMenuItem);

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := '-';
  Mi.Add(Mi2);

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := '&Keluar Aplikasi';
  Mi2.ShortCut := ShortCut(Ord('Q'), [ssCtrl]);
  Mi2.OnClick := @DoLogout;
  Mi.Add(Mi2);

  // ---- Menu: Aplikasi ----
  // Semua tindakan yang berhubungan dengan modul/aplikasi
  Mi := TMenuItem.Create(FAppMenu);
  Mi.Caption := '&Aplikasi';
  FAppMenu.Items.Add(Mi);
  FAppsMenuItem := Mi;
  FAppMenuMap := TStringList.Create;

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := 'Tampilkan &Semua Aplikasi';
  Mi2.ShortCut := ShortCut(Ord('A'), [ssCtrl]);
  Mi2.OnClick := @ShowAllApps;
  Mi.Add(Mi2);

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := '-';
  Mi.Add(Mi2);

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := '&Kelola Aplikasi...';
  Mi2.OnClick := @ShowAppsManager;
  Mi.Add(Mi2);

  // ---- Menu: Tampilan ----
  // Tata letak dan tampilan antarmuka
  Mi := TMenuItem.Create(FAppMenu);
  Mi.Caption := '&Tampilan';
  FAppMenu.Items.Add(Mi);

  FNavMenuItem := TMenuItem.Create(FAppMenu);
  FNavMenuItem.Caption := 'Tampilkan &Panel Navigasi';
  FNavMenuItem.ShortCut := ShortCut(Ord('B'), [ssCtrl]);
  FNavMenuItem.OnClick := @DoToggleNav;
  Mi.Add(FNavMenuItem);

  // ---- Menu: Alat ----
  // Konfigurasi teknis dan alat bantu
  Mi := TMenuItem.Create(FAppMenu);
  Mi.Caption := '&Alat';
  FAppMenu.Items.Add(Mi);

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := 'Sambungkan &Database...';
  Mi2.ShortCut := ShortCut(Ord('D'), [ssCtrl]);
  Mi2.OnClick := @DoConnect;
  Mi.Add(Mi2);

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := '-';
  Mi.Add(Mi2);

  FSettingsMenu := TMenuItem.Create(FAppMenu);
  FSettingsMenu.Caption := '&Pengaturan Sistem...';
  FSettingsMenu.ShortCut := ShortCut(Ord(','), [ssCtrl]);
  FSettingsMenu.OnClick := @ShowSettings;
  Mi.Add(FSettingsMenu);

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := '-';
  Mi.Add(Mi2);

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := 'Periksa &Pembaruan...';
  Mi2.ShortCut := ShortCut(Ord('R'), [ssCtrl, ssShift]);
  Mi2.OnClick := @DoCheckUpdates;
  Mi.Add(Mi2);

  // ---- Menu: Bantuan ----
  Mi := TMenuItem.Create(FAppMenu);
  Mi.Caption := '&Bantuan';
  FAppMenu.Items.Add(Mi);

  Mi2 := TMenuItem.Create(FAppMenu);
  Mi2.Caption := '&Tentang SmartOffice...';
  Mi2.OnClick := @ShowAbout;
  Mi.Add(Mi2);
end;


procedure TMainForm.FormCreate(Sender: TObject);
begin

end;

procedure TMainForm.FViewHostClick(Sender: TObject);
begin

end;

procedure TMainForm.HTitleClick(Sender: TObject);
begin

end;

procedure TMainForm.MenuFileClick(Sender: TObject);
begin

end;

procedure TMainForm.BuildUI;
var
  HTTL: TComponent;
  FNavSep: TPanel;      // 1px separator right of nav
begin
  // Apply theme fonts globally
  Font.Name := AppTheme.FontFamily;
  Font.Size := AppTheme.FontSizeMD;
  Color := AppTheme.ColorBackground;

  // Brand title
  if FindComponent('HTitle') is TLabel then
  begin
    TLabel(FindComponent('HTitle')).Caption := 'SmartOffice Desktop';
    TLabel(FindComponent('HTitle')).Font.Color := AppTheme.ColorTextPrimary;
    TLabel(FindComponent('HTitle')).Font.Name  := AppTheme.FontFamily;
    TLabel(FindComponent('HTitle')).Font.Size  := AppTheme.FontSizeLG;
  end;

  // ---- Header bar (Biru solid, teks & ikon putih) ----
  FHeader.Color := AppTheme.ColorPrimary;
  FHeader.ParentBackground := False;
  FHeader.BevelOuter := bvNone;

  // Hamburger / nav toggle button (putih di atas biru)
  FNavToggleBtn := TSpeedButton.Create(FHeader);
  FNavToggleBtn.Parent := FHeader;
  FNavToggleBtn.Align := alLeft;
  FNavToggleBtn.Width := 48;
  FNavToggleBtn.Flat := True;
  FNavToggleBtn.Color := AppTheme.ColorPrimary;
  FNavToggleBtn.Font.Color := clWhite;
  FNavToggleBtn.Font.Size := AppTheme.FontSizeXL;
  FNavToggleBtn.Caption := #$E2#$98#$A0;
  FNavToggleBtn.ShowHint := True;
  FNavToggleBtn.Hint := 'Tampilkan / sembunyikan panel navigasi (Ctrl+B)';
  FNavToggleBtn.OnClick := @DoToggleNav;

  // Push title to the right of the toggle button
  HTTL := FindComponent('HTitle');
  if HTTL is TLabel then
  begin
    TLabel(HTTL).Left := FNavToggleBtn.Width + AppTheme.SpaceSM;
    TLabel(HTTL).Font.Color := clWhite;
  end;

  // User chip: biru, teks putih
  FUserChip.Color := AppTheme.ColorPrimary;
  FUserChip.ParentBackground := False;
  FUserBadge.Font.Color := clWhite;
  FUserBadge.Font.Size := AppTheme.FontSizeSM;
  FUserBadge.Alignment := taRightJustify;
  FUserBadge.Caption := '';

  // Avatar circle: lingkaran putih + inisial biru
  FUserAvatar.Pen.Color := clWhite;
  FUserAvatar.Brush.Color := clWhite;
  FUserAvatar.Visible := False;
  FAvatarText.Font.Color := AppTheme.ColorPrimary;
  FAvatarText.Font.Size := AppTheme.FontSizeSM;
  FAvatarText.Caption := '';
  FAvatarText.Visible := False;

  // DB chip hidden (info in status bar)
  FDbChip.Visible := False;
  FDbChip.ParentBackground := False;
  FDbBadge.Font.Color := clWhite;
  FDbBadge.Caption := 'Menghubungkan...';
  FDbDot.Brush.Color := AppTheme.ColorTextDisabled;

  // ---- Navigation sidebar (Fluent: white, thin right border) ----
  FNavPanel.Color := AppTheme.ColorSurface;

  // 1px right separator
  FNavSep := TPanel.Create(FNavPanel);
  FNavSep.Parent := FNavPanel;
  FNavSep.Align := alRight;
  FNavSep.Width := 1;
  FNavSep.BevelOuter := bvNone;
  FNavSep.Color := AppTheme.ColorBorder;

  FNavImages := TImageList.Create(Self);
  FNavImages.Width := 20;
  FNavImages.Height := 20;

  FNavTree.Color := AppTheme.ColorSurface;
  FNavTree.Font.Color := AppTheme.ColorTextPrimary;
  FNavTree.Font.Size := AppTheme.FontSizeMD;
  FNavTree.Font.Name := AppTheme.FontFamily;
  FNavTree.SelectionColor := RGBToColor(235, 246, 255);  // very light blue bg
  FNavTree.SelectionFontColor := AppTheme.ColorPrimary;  // primary blue text
  FNavTree.ShowLines := False;
  FNavTree.ShowRoot := False;
  FNavTree.RowSelect := True;
  FNavTree.HotTrack := True;
  FNavTree.HideSelection := False;
  FNavTree.BorderStyle := bsNone;
  FNavTree.DefaultItemHeight := 38;
  FNavTree.Indent := AppTheme.SpaceLG;
  FNavTree.Images := FNavImages;
  FNavTree.OnSelectionChanged := @NavSelectionChanged;
  FNavTree.OnClick := @NavSelectionChanged;

  // ---- Status bar (Fluent: white bg, light top border) ----
  FStatusBar.Font.Size := AppTheme.FontSizeXS;
  FStatusBar.Font.Name := AppTheme.FontFamily;
  FStatusBar.Font.Color := AppTheme.ColorTextSecondary;
  FStatusBar.Color := AppTheme.ColorSurface;

  // ---- View host (Fluent: light grey = content area) ----
  FViewHost.Color := AppTheme.ColorBackground;
end;

function TMainForm.NavGlyphForModule(const AID: string): TAppGlyph;
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

function TMainForm.TileColorForCategory(const ACategory: string): TColor;
begin
  case ACategory of
    'Aplikasi':    Result := AppTheme.ColorCategoryClinical;
    'Sistem':      Result := AppTheme.ColorCategoryAdmin;
    'Sumber Daya': Result := AppTheme.ColorCategoryHR;
    else           Result := AppTheme.ColorCategorySystem;
  end;
end;

procedure TMainForm.PopulateModuleTree;
var
  I: Integer;
  M: TBaseModule;
  CatNode: TTreeNode;
  ItemNode: TTreeNode;
begin
  FNavTree.Items.BeginUpdate;
  try
    FNavTree.Items.Clear;
    FNavImages.Clear;
    for I := 0 to ModuleManager.VisibleCount - 1 do
    begin
      M := ModuleManager.GetVisibleModule(I);
      if M = nil then
        Continue;
      CatNode := FNavTree.Items.FindNodeWithText(M.Category);
      if CatNode = nil then
        CatNode := FNavTree.Items.Add(nil, M.Category);
      ItemNode := FNavTree.Items.AddChild(CatNode, M.Title);
      ItemNode.Data := M;
      ItemNode.ImageIndex := FNavImages.Add(
        MakeNavIcon(TileColorForCategory(M.Category), NavGlyphForModule(M.ID)), nil);
    end;
    FNavTree.FullExpand;
  finally
    FNavTree.Items.EndUpdate;
  end;
end;

function TMainForm.MakeNavIcon(AColor: TColor; AGlyph: TAppGlyph): Graphics.TBitmap;
var
  Tmp: Graphics.TBitmap;
begin
  Tmp := Graphics.TBitmap.Create;
  try
    DrawAppIcon(Tmp, AColor, AGlyph);
    Result := Graphics.TBitmap.Create;
    Result.Width := 16;
    Result.Height := 16;
    Result.Canvas.StretchDraw(Types.Rect(0, 0, 16, 16), Tmp);
  finally
    Tmp.Free;
  end;
end;

procedure TMainForm.NavSelectionChanged(Sender: TObject);
var
  Node: TTreeNode;
  M: TBaseModule;
begin
  if FInNavSelection then
    Exit;
  FInNavSelection := True;
  try
    Node := FNavTree.Selected;
    if Node = nil then
      Exit;

    // Category node (no module): show the launcher home filtered to this
    // category (only the applications it contains).
    if Node.Data = nil then
    begin
      FHomeFilter := Node.Text;
      OpenModule('home');
      Exit;
    end;

    M := TBaseModule(Node.Data);
    if M <> nil then
      OpenModule(M.ID);
  finally
    FInNavSelection := False;
  end;
end;

procedure TMainForm.OpenModule(const AID: TModuleID);
var
  M: TBaseModule;
  V: TControl;
  Target: TModuleID;
  NowTick: QWord;
begin
  // Debounce: a double-click (or the OnClick + OnSelectionChanged pair) can
  // request the same module twice within a few hundred ms. Ignore repeats.
  NowTick := GetTickCount64;
  if (AID = FLastOpenId) and (NowTick - FLastOpenTick < 500) then
    Exit;
  FLastOpenId := AID;
  FLastOpenTick := NowTick;

  Target := AID;
  if (RBAC = nil) or (not RBAC.CanView(Target)) then
    Target := 'home';
  M := ModuleManager.FindModule(Target);
  if M = nil then
    M := ModuleManager.FindModule('home');
  if M = nil then
    Exit;
  if not M.HasView('') then
    Exit;
  LogMsg('OpenModule: ' + Target + ' -> ' + M.ID);

  // External module: launch its own executable and keep the current view.
  if M.ExeFile <> '' then
  begin
    LaunchExternal(M);
    Exit;
  end;

  FCurrentView.Free;
  FCurrentView := nil;

  V := M.CreateView('');
  if V = nil then
    Exit;

  FCurrentView := V;
  V.Parent := FViewHost;
  if V is TLauncherView then
  begin
    TLauncherView(V).OnOpenModule := @OpenModule;
    TLauncherView(V).SetCategory(FHomeFilter);
    TLauncherView(V).Recenter;
  end;
  FCurrentModule := M;
  AppConfig.LastModule := M.ID;
  UpdateStatusBar;
end;

procedure TMainForm.LoadExternalModules;
begin
  ModuleManager.LoadExternalApps;
  PopulateModuleTree;
  RefreshAppsMenu;
  LogMsg(Format('LoadExternalModules: total=%d, menu_apps=%d',
    [ModuleManager.Count, FAppMenuIndex]));
end;

procedure TMainForm.DoFormActivate(Sender: TObject);
const
  AppsReloadIntervalMs = 8000;
var
  NowTick: QWord;
begin
  if (RBAC = nil) or (not RBAC.IsLoggedIn) or (not AppDB.Connected) then
    Exit;
  NowTick := GetTickCount64;
  if (FLastAppsReloadTick = 0) or
     (NowTick - FLastAppsReloadTick >= AppsReloadIntervalMs) then
  begin
    FLastAppsReloadTick := NowTick;
    LoadExternalModules;
  end;
end;

procedure TMainForm.RefreshAppsMenu;
var
  I: Integer;
  M: TBaseModule;
  Mi: TMenuItem;
begin
  if FAppsMenuItem = nil then
    Exit;
  FAppMenuMap.Clear;
  while FAppsMenuItem.Count > 2 do
    FAppsMenuItem.Items[2].Free;
  FAppMenuIndex := 0;
  for I := 0 to ModuleManager.Count - 1 do
  begin
    M := ModuleManager.GetModule(I);
    if M.ExeFile = '' then
      Continue;
    Inc(FAppMenuIndex);
    Mi := TMenuItem.Create(FAppMenu);
    Mi.Caption := Format('%d. %s', [FAppMenuIndex, M.Title]);
    Mi.OnClick := @AppMenuItemClick;
    FAppsMenuItem.Add(Mi);
    FAppMenuMap.AddObject(M.ID, Mi);
  end;
end;

procedure TMainForm.AppMenuItemClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to FAppMenuMap.Count - 1 do
  begin
    if FAppMenuMap.Objects[I] = Sender then
    begin
      OpenModule(FAppMenuMap[I]);
      Exit;
    end;
  end;
end;

procedure TMainForm.ShowAppsManager(Sender: TObject);
begin
  OpenModule('apps');
end;

procedure TMainForm.ShowAllApps(Sender: TObject);
begin
  OpenModule('home');
  if FCurrentView is TLauncherView then
    TLauncherView(FCurrentView).SetCategory('');
end;

procedure TMainForm.LaunchExternal(M: TBaseModule);
var
  Err: string;
begin
  if (M = nil) or (RBAC = nil) or (not RBAC.IsLoggedIn) then
    Exit;
  if not RBAC.CanView(M.ID) then
  begin
    MessageDlg('Akses Ditolak', 'Anda tidak memiliki hak akses ke modul ini.',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if RBAC.SessionToken = '' then
    RBAC.CreateSession;
  if RBAC.SessionToken = '' then
  begin
    MessageDlg('Error', 'Gagal membuat sesi aplikasi.', mtError, [mbOK], 0);
    Exit;
  end;
  if LaunchModuleExe(M.ExeFile, RBAC.Username, RBAC.SessionToken, Err) then
    LogMsg('Meluncurkan modul: ' + M.ID + ' (' + M.ExeFile + ')')
  else
  begin
    LogMsg('Gagal meluncurkan modul: ' + M.ID + ' -> ' + Err);
    MessageDlg('Error', Err, mtError, [mbOK], 0);
  end;
end;

function TMainForm.IsInProcessModule(const AID: TModuleID): Boolean;
var
  M: TBaseModule;
begin
  M := ModuleManager.FindModule(AID);
  Result := (M <> nil) and (M.ExeFile = '');
end;

procedure TMainForm.UpdateStatusBar;
begin
  if FCurrentModule <> nil then
    FStatusBar.Panels[0].Text := 'Modul aktif: ' + FCurrentModule.Title;
  if AppDB.Connected then
    FStatusBar.Panels[1].Text := 'Database: Terhubung'
  else
    FStatusBar.Panels[1].Text := 'Database: Tidak terhubung';
end;

procedure TMainForm.UpdateDbBadge;
begin
  if AppDB.Connected then
  begin
    FDbBadge.Caption := 'Database Terhubung';
    FDbBadge.Font.Color := clWhite;
    FDbDot.Brush.Color := clLime;
  end
  else
  begin
    FDbBadge.Caption := 'Database Terputus';
    FDbBadge.Font.Color := clWhite;
    FDbDot.Brush.Color := clRed;
  end;
end;

procedure TMainForm.ShowSettings(Sender: TObject);
var
  M: TBaseModule;
begin
  M := ModuleManager.FindModule('settings');
  if M <> nil then
    LaunchExternal(M)
  else
    MessageDlg('Info', 'Modul pengaturan tidak tersedia.', mtInformation, [mbOK], 0);
end;

procedure TMainForm.DoConnect(Sender: TObject);
begin
  AppDB.ConnectFromConfig;
  UpdateDbBadge;
  UpdateStatusBar;
  if AppDB.Connected then
    ShowMessage('Koneksi berhasil: ' + AppDB.ServerVersion)
  else
    ShowMessage('Koneksi gagal: ' + sLineBreak + AppDB.LastError);
end;

procedure TMainForm.UpdateUserBadge;
var
  S: string;
  SpacePos: Integer;
begin
  if (RBAC <> nil) and RBAC.IsLoggedIn then
  begin
    FUserBadge.Caption := RBAC.FullName + '  (' + RBAC.RoleName + ')';
    S := Trim(RBAC.FullName);
    FAvatarText.Caption := '';
    if S <> '' then
      FAvatarText.Caption := S[1];
    SpacePos := Pos(' ', S);
    if SpacePos > 0 then
      FAvatarText.Caption := FAvatarText.Caption + S[SpacePos + 1];
    FAvatarText.Caption := UpperCase(FAvatarText.Caption);
    FUserAvatar.Visible := True;
    FAvatarText.Visible := True;
  end
  else
  begin
    FUserBadge.Caption := '';
    FAvatarText.Caption := '';
    FUserAvatar.Visible := False;
    FAvatarText.Visible := False;
  end;
end;

procedure TMainForm.DoSwitchUser(Sender: TObject);
begin
  if RBAC.SessionToken <> '' then
    RBAC.RevokeSession;
  ClearAppContent;
  if ShowLoginDialog then
  begin
    RBAC.CreateSession;
    PopulateModuleTree;
    ApplyNavPanel;
    UpdateUserBadge;
    UpdateStatusBar;
    OpenModule('home');
  end;
end;

procedure TMainForm.ShowAbout(Sender: TObject);
begin
  ShowMessage(
    AppTitle + ' Launcher ' + AppVersion + sLineBreak + sLineBreak +
    'Desktop Application Framework' + sLineBreak +
    'Platform : Windows (Lazarus / Free Pascal)' + sLineBreak +
    'Bahasa   : Object Pascal' + sLineBreak +
    'Database : PostgreSQL / SQLite' + sLineBreak +
    'Arsitektur : Modular / Plugin' + sLineBreak + sLineBreak +
    '(c) 2026 SmartOffice');
end;

procedure TMainForm.DoCheckUpdates(Sender: TObject);
var
  Repo, NewVer, Err, Stage: string;
  LauncherUpdated: Boolean;
begin
  Repo := AppConfig.UpdateRepo;
  if Repo = '' then
    Repo := DefaultUpdateRepo;
  if Repo = '' then
  begin
    MessageDlg('Pembaruan',
      'Repo GitHub belum diatur.' + sLineBreak +
      'Buka Alat > Pengaturan Sistem lalu isi kolom "Repo GitHub" ' +
      '(format: pemilik/repo).',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if not CheckForUpdates(Repo, NewVer, Err) then
  begin
    MessageDlg('Pembaruan', 'Tidak dapat memeriksa pembaruan:' + sLineBreak +
      Err, mtError, [mbOK], 0);
    Exit;
  end;
  if NewVer = '' then
  begin
    MessageDlg('Pembaruan',
      'Aplikasi sudah versi terbaru (v' + AppVersion + ').',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Pembaruan',
    Format('Versi baru tersedia: %s' + sLineBreak +
    'Terpasang: %s' + sLineBreak + sLineBreak +
    'Unduh dan pasang sekarang?', [NewVer, AppVersion]),
    mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  Stage := IncludeTrailingPathDelimiter(GetAppDataDir) + 'updates\' + NewVer;
  if not StageUpdates(Repo, Stage, Err) then
  begin
    MessageDlg('Pembaruan', 'Gagal mengunduh:' + sLineBreak + Err,
      mtError, [mbOK], 0);
    Exit;
  end;
  if not ApplyStagedUpdates(Stage, LauncherUpdated, Err) then
  begin
    MessageDlg('Pembaruan', 'Gagal memasang:' + sLineBreak + Err,
      mtError, [mbOK], 0);
    Exit;
  end;
  if LauncherUpdated then
  begin
    MessageDlg('Pembaruan',
      'Pembaruan selesai. Aplikasi akan ditutup lalu dibuka otomatis ' +
      'dengan versi baru.', mtInformation, [mbOK], 0);
    Close;
  end
  else
    MessageDlg('Pembaruan', 'Pembaruan berhasil dipasang.',
      mtInformation, [mbOK], 0);
end;

procedure TMainForm.DoAutoCheckUpdate(Sender: TObject);
var
  Repo, NewVer, Err: string;
begin
  FUpdateTimer.Enabled := False;
  Repo := AppConfig.UpdateRepo;
  if Repo = '' then
    Repo := DefaultUpdateRepo;
  if Repo = '' then
    Exit;
  if not CheckForUpdates(Repo, NewVer, Err) then
    Exit;
  if NewVer <> '' then
    MessageDlg('Pembaruan',
      Format('Pembaruan tersedia: %s (terpasang: %s).' + sLineBreak +
      'Pilih Alat > Periksa Pembaruan untuk memasang.', [NewVer, AppVersion]),
      mtInformation, [mbOK], 0);
end;

procedure TMainForm.ClearAppContent;
begin
  // Tear down everything that exposes the logged-in app state so nothing is
  // visible behind the login dialog.
  if FCurrentView <> nil then
  begin
    FCurrentView.Free;
    FCurrentView := nil;
  end;
  FCurrentModule := nil;
  FNavTree.Items.Clear;
  FNavImages.Clear;
  FLastOpenId := '';
  // Hide the navigation panel while there is no session/content; it is shown
  // again (per the saved preference) after a successful login.
  FNavPanel.Visible := False;
  if FNavMenuItem <> nil then
    FNavMenuItem.Checked := False;
  RefreshAppsMenu;
  UpdateUserBadge;
  UpdateStatusBar;
  UpdateSessionMenu;
  // Close any externally-launched applications (Pendaftaran, dll.) that are
  // still running, so nothing leaks after the session ends.
  TerminateLaunchedModules;
end;

procedure TMainForm.UpdateSessionMenu;
var
  LoggedIn: Boolean;
begin
  LoggedIn := (RBAC <> nil) and RBAC.IsLoggedIn;
  // Saat sudah login: sembunyikan Login, tampilkan Ganti Pengguna
  if FLoginMenuItem <> nil then
  begin
    FLoginMenuItem.Enabled := not LoggedIn;
    FLoginMenuItem.Visible := not LoggedIn;
  end;
  // Ganti Pengguna hanya relevan saat sudah login
  if FSwitchUserMenuItem <> nil then
  begin
    FSwitchUserMenuItem.Enabled := LoggedIn;
    FSwitchUserMenuItem.Visible := LoggedIn;
  end;
end;

procedure TMainForm.DoLogin(Sender: TObject);
begin
  // Show the login dialog (also usable when the session is not active yet).
  if ShowLoginDialog then
  begin
    RBAC.CreateSession;
    PopulateModuleTree;
    ApplyNavPanel;
    UpdateUserBadge;
    UpdateStatusBar;
    UpdateSessionMenu;
    FSettingsMenu.Visible := RBAC.CanView('settings');
    if not IsInProcessModule(AppConfig.LastModule) then
      AppConfig.LastModule := 'home';
    OpenModule(AppConfig.LastModule);
  end;
end;

procedure TMainForm.DoLogout(Sender: TObject);
begin
  if (RBAC <> nil) and RBAC.IsLoggedIn then
  begin
    AuditLog('LOGOUT', 'auth', RBAC.User.UserId, 'Logout: ' + RBAC.Username);
    RBAC.RevokeSession;
  end;
  ClearAppContent;  // UpdateSessionMenu dipanggil di sini
  if ShowLoginDialog then
  begin
    RBAC.CreateSession;
    PopulateModuleTree;
    ApplyNavPanel;
    UpdateUserBadge;
    UpdateStatusBar;
    UpdateSessionMenu;
    OpenModule('home');
  end
  else
  begin
    LogMsg('Login setelah logout dibatalkan. Menutup aplikasi.');
    Close;
  end;
end;

procedure TMainForm.DoAppExit(Sender: TObject);
begin
  Close;
end;

end.

