unit uModuleView;

{
  SmartOffice Desktop - base class for module views.
  A view is simply a client-aligned panel that a module returns from
  CreateView. Subclasses override BuildUI to lay out their content.

  ModuleId identifies the owning module so views can enforce RBAC
  permissions through the CanCreate/CanEdit/CanDelete helpers.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms, ExtCtrls, uRBAC;

type
  TModuleView = class(TFrame)
  private
    FModuleId: string;
  public
    constructor Create(AOwner: TComponent); override;
    property ModuleId: string read FModuleId write FModuleId;
  protected
    procedure BuildUI; virtual;
    function CanAccess: Boolean;
    function CanCreate: Boolean;
    function CanEdit: Boolean;
    function CanDelete: Boolean;
  end;

implementation

{$R *.lfm}

{ TModuleView }

constructor TModuleView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  if not (csDesigning in ComponentState) then
  begin
    Align := alClient;
    BuildUI;
  end;
end;

procedure TModuleView.BuildUI;
begin
  // overridden in subclasses
end;

function TModuleView.CanAccess: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanView(FModuleId);
end;

function TModuleView.CanCreate: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanCreate(FModuleId);
end;

function TModuleView.CanEdit: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanEdit(FModuleId);
end;

function TModuleView.CanDelete: Boolean;
begin
  Result := (RBAC <> nil) and RBAC.CanDelete(FModuleId);
end;

end.
