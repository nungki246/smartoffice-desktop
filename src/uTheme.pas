unit uTheme;

{
  SmartOffice Desktop - Theme system.

  Centralized design tokens for colors, spacing, typography, and visual style.
  Enables consistent theming, high-DPI support, and easy appearance changes.
}

{$mode objfpc}{$H+}

interface

uses
  Graphics;

type
  TThemeType = (ttLight, ttDark);

  TAppTheme = class
  private
    FThemeType: TThemeType;
    FColorPrimary: TColor;
    FColorPrimaryHover: TColor;
    FColorPrimaryPressed: TColor;
    FColorSurface: TColor;
    FColorSurfaceHover: TColor;
    FColorSurfacePressed: TColor;
    FColorBackground: TColor;
    FColorBackgroundAlt: TColor;
    FColorTextPrimary: TColor;
    FColorTextSecondary: TColor;
    FColorTextDisabled: TColor;
    FColorBorder: TColor;
    FColorBorderFocus: TColor;
    FColorSuccess: TColor;
    FColorWarning: TColor;
    FColorError: TColor;
    FColorCategoryClinical: TColor;
    FColorCategoryAdmin: TColor;
    FColorCategoryHR: TColor;
    FColorCategorySystem: TColor;
    FColorShadow: TColor;
    FColorGlow: TColor;

    FSpaceXS: Integer;
    FSpaceSM: Integer;
    FSpaceMD: Integer;
    FSpaceLG: Integer;
    FSpaceXL: Integer;

    FRadiusSM: Integer;
    FRadiusMD: Integer;
    FRadiusLG: Integer;

    FFontFamily: string;
    FFontSizeXS: Integer;
    FFontSizeSM: Integer;
    FFontSizeMD: Integer;
    FFontSizeLG: Integer;
    FFontSizeXL: Integer;
    FFontSize2XL: Integer;

    procedure SetThemeType(const AValue: TThemeType);
  public
    constructor Create;
    destructor Destroy; override;

    // Theme switching
    property ThemeType: TThemeType read FThemeType write SetThemeType;

    // Color tokens
    property ColorPrimary: TColor read FColorPrimary;
    property ColorPrimaryHover: TColor read FColorPrimaryHover;
    property ColorPrimaryPressed: TColor read FColorPrimaryPressed;
    property ColorSurface: TColor read FColorSurface;
    property ColorSurfaceHover: TColor read FColorSurfaceHover;
    property ColorSurfacePressed: TColor read FColorSurfacePressed;
    property ColorBackground: TColor read FColorBackground;
    property ColorBackgroundAlt: TColor read FColorBackgroundAlt;
    property ColorTextPrimary: TColor read FColorTextPrimary;
    property ColorTextSecondary: TColor read FColorTextSecondary;
    property ColorTextDisabled: TColor read FColorTextDisabled;
    property ColorBorder: TColor read FColorBorder;
    property ColorBorderFocus: TColor read FColorBorderFocus;
    property ColorSuccess: TColor read FColorSuccess;
    property ColorWarning: TColor read FColorWarning;
    property ColorError: TColor read FColorError;
    property ColorCategoryClinical: TColor read FColorCategoryClinical;
    property ColorCategoryAdmin: TColor read FColorCategoryAdmin;
    property ColorCategoryHR: TColor read FColorCategoryHR;
    property ColorCategorySystem: TColor read FColorCategorySystem;
    property ColorShadow: TColor read FColorShadow;
    property ColorGlow: TColor read FColorGlow;

    // Spacing tokens
    property SpaceXS: Integer read FSpaceXS;
    property SpaceSM: Integer read FSpaceSM;
    property SpaceMD: Integer read FSpaceMD;
    property SpaceLG: Integer read FSpaceLG;
    property SpaceXL: Integer read FSpaceXL;

    // Border radius tokens
    property RadiusSM: Integer read FRadiusSM;
    property RadiusMD: Integer read FRadiusMD;
    property RadiusLG: Integer read FRadiusLG;

    // Typography tokens
    property FontFamily: string read FFontFamily;
    property FontSizeXS: Integer read FFontSizeXS;
    property FontSizeSM: Integer read FFontSizeSM;
    property FontSizeMD: Integer read FFontSizeMD;
    property FontSizeLG: Integer read FFontSizeLG;
    property FontSizeXL: Integer read FFontSizeXL;
    property FontSize2XL: Integer read FFontSize2XL;

    procedure ApplyDarkTheme;
    procedure ApplyLightTheme;
  end;

var
  AppTheme: TAppTheme = nil;

implementation

uses
  SysUtils, Classes;

constructor TAppTheme.Create;
begin
  inherited Create;
  FThemeType := ttLight;
  FFontFamily := 'Segoe UI Variable, Segoe UI, Tahoma, Arial, sans-serif';
  FFontSizeXS := 11;
  FFontSizeSM := 12;
  FFontSizeMD := 13;
  FFontSizeLG := 15;
  FFontSizeXL := 18;
  FFontSize2XL := 24;

  FSpaceXS := 4;
  FSpaceSM := 8;
  FSpaceMD := 16;
  FSpaceLG := 24;
  FSpaceXL := 32;

  FRadiusSM := 4;
  FRadiusMD := 8;
  FRadiusLG := 12;

  ApplyLightTheme;
end;

destructor TAppTheme.Destroy;
begin
  inherited Destroy;
end;

procedure TAppTheme.SetThemeType(const AValue: TThemeType);
begin
  if FThemeType <> AValue then
  begin
    FThemeType := AValue;
    case FThemeType of
      ttLight: ApplyLightTheme;
      ttDark: ApplyDarkTheme;
    end;
  end;
end;

procedure TAppTheme.ApplyLightTheme;
begin
  // Primary colors - Windows 11 Fluent Blue
  FColorPrimary := RGBToColor(0, 103, 192); // #0067C0
  FColorPrimaryHover := RGBToColor(25, 117, 197);
  FColorPrimaryPressed := RGBToColor(0, 84, 153);

  // Surface colors
  FColorSurface := RGBToColor(255, 255, 255); // #FFFFFF
  FColorSurfaceHover := RGBToColor(243, 243, 243);
  FColorSurfacePressed := RGBToColor(237, 237, 237);

  // Background colors - Solid Mica simulation
  FColorBackground := RGBToColor(243, 243, 243); // #F3F3F3
  FColorBackgroundAlt := RGBToColor(255, 255, 255);

  // Text colors
  FColorTextPrimary := RGBToColor(26, 26, 26); // #1A1A1A
  FColorTextSecondary := RGBToColor(93, 93, 93); // #5D5D5D
  FColorTextDisabled := RGBToColor(153, 153, 153); // #999999

  // Borders
  FColorBorder := RGBToColor(229, 229, 229); // #E5E5E5
  FColorBorderFocus := RGBToColor(0, 103, 192);

  // Status colors
  FColorSuccess := RGBToColor(16, 124, 16); // #107C10
  FColorWarning := RGBToColor(216, 59, 1); // #D83B01
  FColorError := RGBToColor(232, 17, 35); // #E81123

  // Category colors (semantic)
  FColorCategoryClinical := RGBToColor(0, 103, 192);
  FColorCategoryAdmin := RGBToColor(232, 17, 35);
  FColorCategoryHR := RGBToColor(16, 124, 16);
  FColorCategorySystem := RGBToColor(93, 93, 93);

  // Shadow and Glow
  FColorShadow := RGBToColor(230, 230, 230);
  FColorGlow := RGBToColor(200, 225, 255);
end;

procedure TAppTheme.ApplyDarkTheme;
begin
  // Primary colors - Windows 11 Fluent Blue (Dark Mode)
  FColorPrimary := RGBToColor(76, 194, 255); // #4CC2FF
  FColorPrimaryHover := RGBToColor(96, 205, 255);
  FColorPrimaryPressed := RGBToColor(40, 168, 234);

  // Surface colors
  FColorSurface := RGBToColor(45, 45, 45); // #2D2D2D
  FColorSurfaceHover := RGBToColor(50, 50, 50);
  FColorSurfacePressed := RGBToColor(40, 40, 40);

  // Background colors
  FColorBackground := RGBToColor(32, 32, 32); // #202020
  FColorBackgroundAlt := RGBToColor(40, 40, 40);

  // Text colors
  FColorTextPrimary := RGBToColor(255, 255, 255); // #FFFFFF
  FColorTextSecondary := RGBToColor(160, 160, 160); // #A0A0A0
  FColorTextDisabled := RGBToColor(120, 120, 120);

  // Borders
  FColorBorder := RGBToColor(51, 51, 51); // #333333
  FColorBorderFocus := RGBToColor(76, 194, 255);

  // Status colors
  FColorSuccess := RGBToColor(16, 137, 62); // #10893E
  FColorWarning := RGBToColor(252, 225, 0); // #FCE100
  FColorError := RGBToColor(232, 17, 35); // #E81123

  // Category colors (semantic)
  FColorCategoryClinical := RGBToColor(76, 194, 255);
  FColorCategoryAdmin := RGBToColor(232, 17, 35);
  FColorCategoryHR := RGBToColor(16, 137, 62);
  FColorCategorySystem := RGBToColor(160, 160, 160);

  // Shadow and Glow
  FColorShadow := RGBToColor(20, 20, 20);
  FColorGlow := RGBToColor(0, 60, 100);
end;

initialization
  AppTheme := TAppTheme.Create;

finalization
  AppTheme.Free;
  AppTheme := nil;

end.