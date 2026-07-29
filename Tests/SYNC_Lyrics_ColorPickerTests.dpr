program SYNC_Lyrics_ColorPickerTests;

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  Vcl.Forms,
  Vcl.Graphics,
  Winapi.Windows,
  ColorPickerColorMath in
    'Source\Lib\ColorPicker\ColorPickerColorMath.pas',
  ColorPickerRGBEditFrame in
    'Source\Lib\ColorPicker\ColorPickerRGBEditFrame.pas'
    {FrameColorPickerRGBEdit: TFrame},
  ColorPickerHueBar in
    'Source\Lib\ColorPicker\ColorPickerHueBar.pas',
  ColorPickerSVArea in
    'Source\Lib\ColorPicker\ColorPickerSVArea.pas',
  ColorPickerPick in
    'Source\Lib\ColorPicker\ColorPickerPick.pas',
  ColorPickerDialogFrame in
    'Source\Lib\ColorPicker\ColorPickerDialogFrame.pas'
    {FrameColorPickerDialog: TFrame},
  ColorPickerDialog in
    'Source\Lib\ColorPicker\ColorPickerDialog.pas'
    {FormColorPickerDialog};

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckRgb(Color: TColor; Red, Green, Blue: Byte;
  const MessageText: string);
var
  RgbColor: TColor;
begin
  RgbColor := ColorToRGB(Color);
  Check((Abs(GetRValue(RgbColor) - Red) <= 1) and
    (Abs(GetGValue(RgbColor) - Green) <= 1) and
    (Abs(GetBValue(RgbColor) - Blue) <= 1), MessageText);
end;

procedure TestColorMath;
var
  Color: TColor;
  Hue: Double;
  Saturation: Double;
  Value: Double;
begin
  CheckRgb(HsvToColor(0, 1, 1), 255, 0, 0,
    'HSV red conversion failed');
  CheckRgb(HsvToColor(120, 1, 1), 0, 255, 0,
    'HSV green conversion failed');
  CheckRgb(HsvToColor(240, 1, 1), 0, 0, 255,
    'HSV blue conversion failed');

  Color := RGB(12, 200, 90);
  ColorToHsv(Color, Hue, Saturation, Value);
  CheckRgb(HsvToColor(Hue, Saturation, Value),
    12, 200, 90, 'RGB/HSV round-trip failed');
  ColorToHsv(RGB(128, 128, 128), Hue, Saturation, Value);
  Check(SameValue(Saturation, 0.0),
    'gray color returned nonzero saturation');
end;

procedure TestDialogConstruction;
var
  Color: TColor;
  Dialog: TFormColorPickerDialog;
begin
  Color := RGB(10, 20, 30);
  Dialog := TFormColorPickerDialog.Create(nil);
  try
    Dialog.Color := Color;
    Check(ColorToRGB(Dialog.Color) = ColorToRGB(Color),
      'dialog color property did not round-trip');
    Check((Dialog.ClientWidth = 320) and
      (Dialog.ClientHeight = 267),
      'dialog design size mismatch');
  finally
    Dialog.Free;
  end;
end;

begin
  try
    Application.Initialize;
    TestColorMath;
    TestDialogConstruction;
    Writeln('PASS');
    ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln('FAIL: ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
