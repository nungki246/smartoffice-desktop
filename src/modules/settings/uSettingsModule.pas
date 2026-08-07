unit uSettingsModule;

{
  SmartOffice Desktop - Settings module.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, uModule;

type
  TSettingsModule = class(TBaseModule)
  public
    constructor Create; override;
    function CreateView(const AViewID: TModuleID): TControl; override;
    function HasView(const AViewID: TModuleID): Boolean; override;
  end;

implementation

uses
  uModuleView, uSettingsView;

{ TSettingsModule }

constructor TSettingsModule.Create;
begin
  inherited Create;
  ID := 'settings';
  Title := 'Pengaturan';
  Description := 'Konfigurasi koneksi database dan aplikasi';
  Category := 'Sistem';
  Version := '1.0';
  ExeFile := 'SIMRS-Settings.exe';
  Author := 'SmartOffice';
end;

function TSettingsModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := (AViewID = '') or (AViewID = ID);
end;

function TSettingsModule.CreateView(const AViewID: TModuleID): TControl;
begin
  Result := TSettingsView.Create(nil);
  TModuleView(Result).ModuleId := ID;
end;

end.
