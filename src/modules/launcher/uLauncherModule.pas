unit uLauncherModule;

{
  SmartOffice Desktop - Launcher (home) module.

  In-process "home" screen of the launcher. Shows the list of applications
  as tiles (matching the navigation tree). It is hidden from the navigation
  and the tile grid itself; every real application is an EXE module.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, uModule;

type
  TLauncherModule = class(TBaseModule)
  public
    constructor Create; override;
    function CreateView(const AViewID: TModuleID): TControl; override;
    function HasView(const AViewID: TModuleID): Boolean; override;
  end;

implementation

uses
  uModuleView, uLauncherView;

{ TLauncherModule }

constructor TLauncherModule.Create;
begin
  inherited Create;
  ID := 'home';
  Title := 'Daftar Aplikasi';
  Description := 'Layar utama daftar aplikasi';
  Category := 'Umum';
  Version := '1.0';
  Author := 'SmartOffice';
  HiddenInNav := True;
end;

function TLauncherModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := (AViewID = '') or (AViewID = ID);
end;

function TLauncherModule.CreateView(const AViewID: TModuleID): TControl;
begin
  Result := TLauncherView.Create(nil);
  TModuleView(Result).ModuleId := ID;
end;

end.
