unit uDashboardModule;

{
  SmartOffice Desktop - Dashboard module.
  Provides the home view of the launcher.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, uModule;

type
  TDashboardModule = class(TBaseModule)
  public
    constructor Create; override;
    function CreateView(const AViewID: TModuleID): TControl; override;
    function HasView(const AViewID: TModuleID): Boolean; override;
  end;

implementation

uses
  uModuleView, uDashboardView;

{ TDashboardModule }

constructor TDashboardModule.Create;
begin
  inherited Create;
  ID := 'dashboard';
  Title := 'Dashboard';
   Description := 'Dashboard: ringkasan jumlah pasien dan grafik pendaftaran';
  Category := 'Umum';
  Version := '1.0';
  ExeFile := 'SIMRS-Dashboard.exe';
  Author := 'SmartOffice';
end;

function TDashboardModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := (AViewID = '') or (AViewID = ID);
end;

function TDashboardModule.CreateView(const AViewID: TModuleID): TControl;
begin
  Result := TDashboardView.Create(nil);
  TModuleView(Result).ModuleId := ID;
end;

end.
