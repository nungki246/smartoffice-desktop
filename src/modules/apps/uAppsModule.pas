unit uAppsModule;

{
  SmartOffice Desktop - "Manajemen Aplikasi" module.
  In-process management screen for the external EXE applications stored in
  the database table `apps`.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, uModule;

type
  TAppsModule = class(TBaseModule)
  public
    constructor Create; override;
    function CreateView(const AViewID: TModuleID): TControl; override;
    function HasView(const AViewID: TModuleID): Boolean; override;
  end;

implementation

uses
  uModuleView, uAppsView;

{ TAppsModule }

constructor TAppsModule.Create;
begin
  inherited Create;
  ID := 'apps';
  Title := 'Manajemen Aplikasi';
  Description := 'Kelola daftar aplikasi EXE (tambah, ubah, hapus)';
  Category := 'Sistem';
  Version := '1.0';
  Author := 'SmartOffice';
end;

function TAppsModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := (AViewID = '') or (AViewID = ID);
end;

function TAppsModule.CreateView(const AViewID: TModuleID): TControl;
begin
  Result := TAppsView.Create(nil);
  TModuleView(Result).ModuleId := ID;
end;

end.
