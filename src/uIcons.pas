unit uIcons;

{
  SmartOffice Desktop - programmatic application icons.

  Draws simple flat icons at runtime so the launcher needs no image assets.
  Each module gets a colored tile with a white glyph.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Types, uTheme;

type
  TAppGlyph = (gHome, gDocument, gPerson, gNurse, gSettings, gUsers, gShield, gPackage);

procedure DrawAppIcon(ABitmap: TBitmap; AColor: TColor; AGlyph: TAppGlyph);

// Draws a single glyph at (X0,Y0) scaled to S pixels, using AColor for the
// foreground and ABg for the hollow parts. Used by DrawAppIcon and by the
// launcher chrome (brand mark) which needs glyphs on arbitrary backgrounds.
procedure DrawAppGlyph(AC: TCanvas; AGlyph: TAppGlyph; ABg, AColor: TColor;
  X0, Y0, S: Integer);

implementation

procedure DrawAppGlyph(AC: TCanvas; AGlyph: TAppGlyph; ABg, AColor: TColor;
  X0, Y0, S: Integer);
begin
  AC.Pen.Style := psClear;
  AC.Brush.Color := AColor;

  case AGlyph of
    gHome:
      begin
        // roof
        AC.Polygon([Point(X0, Y0 + (S * 2) div 5),
                    Point(X0 + S, Y0 + (S * 2) div 5),
                    Point(X0 + (S div 2), Y0)]);
        // body
        AC.Rectangle(X0 + (S div 4), Y0 + (S * 2) div 5,
                     X0 + (S * 3) div 4, Y0 + S);
        // door
        AC.Brush.Color := ABg;
        AC.Rectangle(X0 + (S * 2) div 5, Y0 + (S * 2) div 3,
                     X0 + (S * 3) div 5, Y0 + S);
      end;

    gDocument:
      begin
        AC.RoundRect(X0, Y0, X0 + S, Y0 + S, 6, 6);
        AC.Brush.Color := ABg;
        AC.Pen.Color := ABg;
        AC.Rectangle(X0 + 8, Y0 + 8, X0 + S - 8, Y0 + 13);
        AC.Rectangle(X0 + 8, Y0 + 17, X0 + S - 8, Y0 + 22);
        AC.Rectangle(X0 + 8, Y0 + 26, X0 + S - 16, Y0 + 31);
      end;

    gPerson:
      begin
        // head
        AC.Ellipse(X0 + (S * 3) div 8, Y0,
                   X0 + (S * 5) div 8, Y0 + (S * 3) div 8);
        // shoulders / body
        AC.Ellipse(X0 + (S * 1) div 8, Y0 + (S * 2) div 5,
                   X0 + (S * 7) div 8, Y0 + S);
      end;

    gNurse:
      begin
        // medical cross
        AC.RoundRect(X0 + (S * 2) div 5, Y0 + (S div 4),
                     X0 + (S * 3) div 5, Y0 + (S * 3) div 4, 4, 4);
        AC.RoundRect(X0 + (S div 4), Y0 + (S * 2) div 5,
                     X0 + (S * 3) div 4, Y0 + (S * 3) div 5, 4, 4);
      end;

    gUsers:
      begin
        // back person
        AC.Ellipse(X0 + (S * 3) div 16, Y0,
                   X0 + (S * 7) div 16, Y0 + (S * 3) div 8);
        AC.Ellipse(X0 + (S * 1) div 16, Y0 + (S * 3) div 8,
                   X0 + (S * 9) div 16, Y0 + S);
        // front person
        AC.Ellipse(X0 + (S * 9) div 16, Y0 + (S div 8),
                   X0 + (S * 13) div 16, Y0 + (S * 7) div 16);
        AC.Ellipse(X0 + (S * 7) div 16, Y0 + (S * 7) div 16,
                   X0 + (S * 15) div 16, Y0 + S);
      end;

    gSettings:
      begin
        AC.Pen.Style := psSolid;
        AC.Pen.Color := AColor;
        AC.Pen.Width := 4;
        // top slider (short)
        AC.Line(X0, Y0 + (S div 6), X0 + (S * 2) div 3, Y0 + (S div 6));
        AC.Brush.Color := ABg;
        AC.Ellipse(X0 + (S * 2) div 3 - 5, Y0 + (S div 6) - 5,
                   X0 + (S * 2) div 3 + 5, Y0 + (S div 6) + 5);
        // middle slider (full)
        AC.Line(X0 + (S div 6), Y0 + (S div 2), X0 + S, Y0 + (S div 2));
        AC.Ellipse(X0 + (S div 6) - 5, Y0 + (S div 2) - 5,
                   X0 + (S div 6) + 5, Y0 + (S div 2) + 5);
        AC.Brush.Color := ABg;
        // bottom slider (short)
        AC.Line(X0, Y0 + (S * 5) div 6, X0 + (S * 2) div 3, Y0 + (S * 5) div 6);
        AC.Ellipse(X0 + (S * 2) div 3 - 5, Y0 + (S * 5) div 6 - 5,
                   X0 + (S * 2) div 3 + 5, Y0 + (S * 5) div 6 + 5);
        AC.Brush.Color := ABg;
        AC.Pen.Width := 1;
      end;

    gShield:
      begin
        // shield body
        AC.Polygon([Point(X0, Y0 + (S div 8)),
                    Point(X0 + S, Y0 + (S div 8)),
                    Point(X0 + S, Y0 + (S div 2)),
                    Point(X0 + (S div 2), Y0 + S),
                    Point(X0, Y0 + (S div 2))]);
      end;

    gPackage:
      begin
        // box body
        AC.Rectangle(X0 + 2, Y0 + (S div 4) + 2, X0 + S - 2, Y0 + S - 2);
        // lid + flap
        AC.Pen.Style := psSolid;
        AC.Pen.Color := AColor;
        AC.Pen.Width := 2;
        AC.MoveTo(X0 + 2, Y0 + (S div 4) + 2);
        AC.LineTo(X0 + (S div 2), Y0 + (S div 8));
        AC.LineTo(X0 + S - 2, Y0 + (S div 4) + 2);
        AC.LineTo(X0 + (S div 2), Y0 + (S div 2));
        AC.LineTo(X0 + 2, Y0 + (S div 4) + 2);
        AC.Pen.Width := 1;
        AC.Pen.Style := psClear;
      end;
  end;
end;

procedure DrawAppIcon(ABitmap: TBitmap; AColor: TColor; AGlyph: TAppGlyph);
begin
  ABitmap.Width := 64;
  ABitmap.Height := 64;
  ABitmap.Canvas.Brush.Color := clWhite;
  ABitmap.Canvas.FillRect(0, 0, 64, 64);
  ABitmap.Canvas.Pen.Style := psClear;
  ABitmap.Canvas.Brush.Color := AColor;
  ABitmap.Canvas.RoundRect(2, 2, 62, 62, AppTheme.RadiusMD, AppTheme.RadiusMD);
  DrawAppGlyph(ABitmap.Canvas, AGlyph, AColor, clWhite, 12, 12, 40);
end;

end.
