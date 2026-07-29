unit ColorPickerColorMath;

interface

uses
  Vcl.Graphics;

procedure ColorToHsv(Color: TColor; out Hue, Saturation, Value: Double);
function ColorHue(Color: TColor): Double;
procedure ColorToSv(Color: TColor; out Saturation, Value: Double);
function HsvToColor(Hue, Saturation, Value: Double): TColor;

implementation

uses
  System.Math,
  Winapi.Windows;

procedure ColorToHsv(Color: TColor; out Hue, Saturation, Value: Double);
var
  Blue: Double;
  Delta: Double;
  Green: Double;
  Maximum: Double;
  Minimum: Double;
  Red: Double;
begin
  Color := ColorToRGB(Color);
  Red := GetRValue(Color) / 255;
  Green := GetGValue(Color) / 255;
  Blue := GetBValue(Color) / 255;
  Maximum := Max(Red, Max(Green, Blue));
  Minimum := Min(Red, Min(Green, Blue));
  Delta := Maximum - Minimum;
  Value := Maximum;
  if Maximum <= 0 then
    Saturation := 0
  else
    Saturation := Delta / Maximum;
  if Delta <= 0 then
    Hue := 0
  else if SameValue(Maximum, Red) then
    Hue := 60 * ((Green - Blue) / Delta)
  else if SameValue(Maximum, Green) then
    Hue := 120 + 60 * ((Blue - Red) / Delta)
  else
    Hue := 240 + 60 * ((Red - Green) / Delta);
  if Hue < 0 then
    Hue := Hue + 360;
end;

function ColorHue(Color: TColor): Double;
var
  Saturation: Double;
  Value: Double;
begin
  ColorToHsv(Color, Result, Saturation, Value);
end;

procedure ColorToSv(Color: TColor; out Saturation, Value: Double);
var
  Hue: Double;
begin
  ColorToHsv(Color, Hue, Saturation, Value);
end;

function HsvToColor(Hue, Saturation, Value: Double): TColor;
var
  Blue: Double;
  Chroma: Double;
  Green: Double;
  Match: Double;
  Red: Double;
  Sector: Double;
  X: Double;
begin
  Hue := Hue - Floor(Hue / 360) * 360;
  Saturation := EnsureRange(Saturation, 0.0, 1.0);
  Value := EnsureRange(Value, 0.0, 1.0);
  Chroma := Value * Saturation;
  Sector := Hue / 60;
  X := Chroma * (1 - Abs((Sector - 2 * Floor(Sector / 2)) - 1));
  Red := 0;
  Green := 0;
  Blue := 0;
  if Sector < 1 then
  begin
    Red := Chroma;
    Green := X;
  end
  else if Sector < 2 then
  begin
    Red := X;
    Green := Chroma;
  end
  else if Sector < 3 then
  begin
    Green := Chroma;
    Blue := X;
  end
  else if Sector < 4 then
  begin
    Green := X;
    Blue := Chroma;
  end
  else if Sector < 5 then
  begin
    Red := X;
    Blue := Chroma;
  end
  else
  begin
    Red := Chroma;
    Blue := X;
  end;
  Match := Value - Chroma;
  Result := RGB(
    Round((Red + Match) * 255),
    Round((Green + Match) * 255),
    Round((Blue + Match) * 255));
end;

end.
