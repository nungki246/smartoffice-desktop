unit uRBACModule;

{
  SmartOffice Desktop - Hak Akses module (RBAC management).
  Manages roles, module permissions and application users.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, uModule;

type
  TRBACModule = class(TBaseModule)
  public
    constructor Create; override;
    function CreateView(const AViewID: TModuleID): TControl; override;
    function HasView(const AViewID: TModuleID): Boolean; override;
  end;

implementation

uses
  uModuleView, uRBACView;

{ TRBACModule }

constructor TRBACModule.Create;
begin
  inherited Create;
  ID := 'rbac';
  Title := 'Hak Akses';
  Description := 'Manajemen peran, hak akses, dan pengguna';
  Category := 'Sistem';
  Version := '1.0';
  ExeFile := 'SIMRS-RBAC.exe';
  Author := 'SmartOffice';
end;

function TRBACModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := (AViewID = '') or (AViewID = ID);
end;

function TRBACModule.CreateView(const AViewID: TModuleID): TControl;
begin
  Result := TRBACView.Create(nil);
  TModuleView(Result).ModuleId := ID;
end;

end.
