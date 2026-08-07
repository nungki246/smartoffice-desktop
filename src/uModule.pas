unit uModule;

{
  SmartOffice Desktop - Module / Plugin interface.

  Every feature of the application is delivered as a "module". A module is a
  self-contained package that registers itself into the module manager and
  provides navigation entries plus a control (view) for its content.

  Modules are statically compiled in for v1.0 (see RegisterAllModules in
  uModuleManager.pas). The interface is kept abstract so the same design could
  later host dynamically loaded packages.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls;

type
  TModuleID = String;

  TBaseModule = class
  private
    FID: TModuleID;
    FTitle: string;
    FDescription: string;
    FCategory: string;
    FVersion: string;
    FAuthor: string;
    FExeFile: string;
    FHiddenInNav: Boolean;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    // --- lifecycle ------------------------------------------------------
    procedure InitializeModule; virtual;   // called once when registered
    procedure FinalizeModule; virtual;     // called once when unregistered

    // --- view factory -----------------------------------------------------
    // Return a new view control for AViewID. Return nil if not supported.
    function CreateView(const AViewID: TModuleID): TControl; virtual; abstract;
    function HasView(const AViewID: TModuleID): Boolean; virtual;

    // --- identity ----------------------------------------------------------
    property ID: TModuleID read FID write FID;
    property Title: string read FTitle write FTitle;
    property Description: string read FDescription write FDescription;
    property Category: string read FCategory write FCategory;
    property Version: string read FVersion write FVersion;
    property Author: string read FAuthor write FAuthor;

    // --- external launch --------------------------------------------------
    // Executable file (same folder as launcher) that hosts this module.
    // Empty means the module runs in-process (dashboard).
    property ExeFile: string read FExeFile write FExeFile;

    // --- navigation --------------------------------------------------------
    // True hides the module from the navigation tree and the app tiles.
    // Used for helper screens such as the launcher home view.
    property HiddenInNav: Boolean read FHiddenInNav write FHiddenInNav;
  end;

  TModuleClass = class of TBaseModule;

implementation

{ TBaseModule }

constructor TBaseModule.Create;
begin
  inherited Create;
  FID := 'unnamed';
  FTitle := 'Untitled';
  FDescription := '';
  FCategory := 'Umum';
  FVersion := '1.0';
  FAuthor := '';
end;

destructor TBaseModule.Destroy;
begin
  inherited Destroy;
end;

procedure TBaseModule.InitializeModule;
begin
  // nothing by default
end;

procedure TBaseModule.FinalizeModule;
begin
  // nothing by default
end;

function TBaseModule.HasView(const AViewID: TModuleID): Boolean;
begin
  Result := False;
end;

end.
