unit SYNC_Lyrics_ContrastGuides;

// Draws two-tone editing guides that remain visible over light or dark images.

interface

uses
  System.Types,
  Vcl.Graphics;

// Draws black-bordered white dashes and restores the canvas pen state.
procedure DrawContrastDashedLine(Canvas: TCanvas; const A, B: TPoint;
  Dpi: Integer = 96);
// Draws a two-tone marquee around the inside edge of Bounds.
procedure DrawContrastDashedRect(Canvas: TCanvas; const Bounds: TRect;
  Dpi: Integer = 96);

implementation

uses
  System.Math,
  System.UITypes,
  Winapi.Windows;

procedure DrawContrastDashedLine(Canvas: TCanvas; const A, B: TPoint;
  Dpi: Integer);
var
  Dash: Integer;
  Distance: Double;
  EndDistance: Double;
  Gap: Integer;
  OldColor: TColor;
  OldMode: TPenMode;
  OldStyle: TPenStyle;
  OldWidth: Integer;
  Pass: Integer;
  StartDistance: Double;
  X1, X2, Y1, Y2: Integer;
begin
  Distance := Hypot(B.X - A.X, B.Y - A.Y);
  if Distance < 1 then
    Exit;
  Dash := Max(2, MulDiv(4, Dpi, 96));
  Gap := Max(2, MulDiv(3, Dpi, 96));
  OldColor := Canvas.Pen.Color;
  OldMode := Canvas.Pen.Mode;
  OldStyle := Canvas.Pen.Style;
  OldWidth := Canvas.Pen.Width;
  try
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Mode := pmCopy;
    for Pass := 0 to 1 do
    begin
      if Pass = 0 then
      begin
        Canvas.Pen.Color := clBlack;
        Canvas.Pen.Width := Max(3, MulDiv(3, Dpi, 96));
      end
      else
      begin
        Canvas.Pen.Color := clWhite;
        Canvas.Pen.Width := Max(1, MulDiv(1, Dpi, 96));
      end;
      StartDistance := 0;
      while StartDistance < Distance do
      begin
        EndDistance := Min(Distance, StartDistance + Dash);
        X1 := A.X + Round((B.X - A.X) * StartDistance / Distance);
        Y1 := A.Y + Round((B.Y - A.Y) * StartDistance / Distance);
        X2 := A.X + Round((B.X - A.X) * EndDistance / Distance);
        Y2 := A.Y + Round((B.Y - A.Y) * EndDistance / Distance);
        Canvas.MoveTo(X1, Y1);
        Canvas.LineTo(X2, Y2);
        StartDistance := StartDistance + Dash + Gap;
      end;
    end;
  finally
    Canvas.Pen.Color := OldColor;
    Canvas.Pen.Mode := OldMode;
    Canvas.Pen.Style := OldStyle;
    Canvas.Pen.Width := OldWidth;
  end;
end;

procedure DrawContrastDashedRect(Canvas: TCanvas; const Bounds: TRect;
  Dpi: Integer);
var
  RightEdge: Integer;
  BottomEdge: Integer;
begin
  if (Bounds.Width < 2) or (Bounds.Height < 2) then
    Exit;
  RightEdge := Bounds.Right - 1;
  BottomEdge := Bounds.Bottom - 1;
  DrawContrastDashedLine(Canvas, Point(Bounds.Left, Bounds.Top),
    Point(RightEdge, Bounds.Top), Dpi);
  DrawContrastDashedLine(Canvas, Point(RightEdge, Bounds.Top),
    Point(RightEdge, BottomEdge), Dpi);
  DrawContrastDashedLine(Canvas, Point(RightEdge, BottomEdge),
    Point(Bounds.Left, BottomEdge), Dpi);
  DrawContrastDashedLine(Canvas, Point(Bounds.Left, BottomEdge),
    Point(Bounds.Left, Bounds.Top), Dpi);
end;

end.
