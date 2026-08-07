unit uPerawatModule;

{
  SmartOffice Desktop - Perawat module (Aplikasi B).
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, uModule;

type
  TPerawatModule = class(TBaseModule)
  public
    constructor Create; override;
    function CreateView(const AViewID: TModuleID): TControl; override;
    function HasView(const AViewID: TModuleID): Boolean; override;
  end;

implementation

uses
  uPerawatView;

{ TPerawatModule }

constructor TPerawatModule.Create;
begin
  inherited Create;
  ID := 'perawat';
  Title := 'Perawat';
  Description := 'Modul data perawat';
  Category := 'Aplikasi';
  Version := '1.0';
  ExeFile := 'SIMRS-Perawat.exe';
  Author := 'SmartOffice';
end;

function TPerawatModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := (AViewID = '') or (AViewID = ID);
end;

function TPerawatModule.CreateView(const AViewID: TModuleID): TControl;
begin
  Result := TPerawatView.Create(nil);
end;

end.
