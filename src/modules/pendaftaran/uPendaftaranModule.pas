unit uPendaftaranModule;

{
  SmartOffice Desktop - Pendaftaran module (Aplikasi A).
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, uModule;

type
  TPendaftaranModule = class(TBaseModule)
  public
    constructor Create; override;
    function CreateView(const AViewID: TModuleID): TControl; override;
    function HasView(const AViewID: TModuleID): Boolean; override;
  end;

implementation

uses
  uPendaftaranView;

{ TPendaftaranModule }

constructor TPendaftaranModule.Create;
begin
  inherited Create;
  ID := 'pendaftaran';
  Title := 'Pendaftaran';
  Description := 'Modul pendaftaran pasien';
  Category := 'Aplikasi';
  Version := '1.0';
  ExeFile := 'SIMRS-Pendaftaran.exe';
  Author := 'SmartOffice';
end;

function TPendaftaranModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := (AViewID = '') or (AViewID = ID);
end;

function TPendaftaranModule.CreateView(const AViewID: TModuleID): TControl;
begin
  Result := TPendaftaranView.Create(nil); // view sets its own ModuleId
end;

end.
