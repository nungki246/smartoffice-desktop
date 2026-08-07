unit uModuleHost;

{
  SmartOffice Desktop - shared host window for module executables.

  Every SIMRS-*.exe opens one module and docks its view into this window:
    * navy header with module title + logged-in user badge
    * client area that hosts the module view
    * status bar

  Level 2 form: all controls live in the .lfm so the Lazarus designer
  can open and edit them visually.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, StdCtrls,
  ComCtrls, Menus;

type
  TModuleHostForm = class(TForm)
  published
    FAppMenu: TMainMenu;
    MenuFile: TMenuItem;
    MenuExit: TMenuItem;
    FHeader: TPanel;
    FTitleLabel: TLabel;
    FUserBadge: TLabel;
    FContent: TPanel;
    FStatusBar: TStatusBar;
    procedure DoAppExit(Sender: TObject);
  private
    FHostedView: TControl;
  protected
    procedure DoClose(var CloseAction: TCloseAction); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Setup(const AModuleTitle: string; AView: TControl);
  end;

var
  ModuleHostForm: TModuleHostForm = nil;

implementation

uses
  uApp, uRBAC;

{$R *.lfm}

{ TModuleHostForm }

constructor TModuleHostForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  // TCustomForm only auto-assigns Form.Menu when NOT streaming, so set it
  // explicitly after the .lfm has loaded the FAppMenu component.
  Menu := FAppMenu;
end;

destructor TModuleHostForm.Destroy;
begin
  FHostedView.Free;
  inherited Destroy;
end;

procedure TModuleHostForm.Setup(const AModuleTitle: string; AView: TControl);
begin
  Caption := AModuleTitle + ' - SmartOffice Desktop';
  FTitleLabel.Caption := AModuleTitle;
  if (RBAC <> nil) and RBAC.IsLoggedIn then
    FUserBadge.Caption := 'Pengguna: ' + RBAC.FullName + '  (' + RBAC.RoleName + ')'
  else
    FUserBadge.Caption := '';
  FHostedView := AView;
  if AView <> nil then
  begin
    AView.Parent := FContent;
    AView.Align := alClient;
  end;
end;

procedure TModuleHostForm.DoClose(var CloseAction: TCloseAction);
begin
  if FHostedView <> nil then
  begin
    FHostedView.Free;
    FHostedView := nil;
  end;
  inherited DoClose(CloseAction);
end;

procedure TModuleHostForm.DoAppExit(Sender: TObject);
begin
  Close;
end;

end.
