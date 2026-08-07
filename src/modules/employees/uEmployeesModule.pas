unit uEmployeesModule;

{
  SmartOffice Desktop - Employees module.
  Registers the employee CRUD screen in the module system.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, uModule;

type
  TEmployeesModule = class(TBaseModule)
  public
    constructor Create; override;
    function CreateView(const AViewID: TModuleID): TControl; override;
    function HasView(const AViewID: TModuleID): Boolean; override;
  end;

implementation

uses
  uEmployeesView;

{ TEmployeesModule }

constructor TEmployeesModule.Create;
begin
  inherited Create;
  ID := 'employees';
  Title := 'Pegawai';
  Description := 'Kelola data pegawai (contoh modul CRUD)';
  Category := 'Sumber Daya';
  Version := '1.0';
  ExeFile := 'SIMRS-Employees.exe';
  Author := 'SmartOffice';
end;

function TEmployeesModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := (AViewID = '') or (AViewID = ID);
end;

function TEmployeesModule.CreateView(const AViewID: TModuleID): TControl;
begin
  Result := TEmployeesView.Create(nil);
end;

end.
