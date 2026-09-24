unit SYNC_Lyrics_CharacterPreviewGeometry;

// Measures free-placement text and ruby bounds in preview coordinates.

interface

uses
  System.Types,
  Vcl.Graphics,
  SYNC_Lyrics_DisplaySettingsData;

// Converts stored style bits to the VCL font style used for preview measurement.
function CharacterFontStyle(Value: Byte): TFontStyles;
// Returns ruby glyph bounds before handle inflation, or empty bounds without ruby.
// Measurement changes Canvas.Font and resets GDI character spacing to zero.
function CharacterPreviewRubyTextBounds(Canvas: TCanvas;
  const Common: TDisplayCommonSettings; const Item: TDisplayPlacementItem;
  const BaseText, RubyText: string; const Destination: TRect;
  Scale: Double): TRect;
// Returns base/ruby union in preview pixels, inflated by a PPI-scaled handle margin.
// Measurement changes Canvas.Font and resets GDI character spacing to zero.
function CharacterPreviewElementBounds(Canvas: TCanvas;
  const Common: TDisplayCommonSettings; const Item: TDisplayPlacementItem;
  const BaseText, RubyText: string; const Destination: TRect;
  Scale: Double; PPI: Integer): TRect;

implementation

uses
  System.Math,
  Winapi.Windows;

function CharacterFontStyle(Value: Byte): TFontStyles;
begin
  Result := [];
  if (Value and 1) <> 0 then Include(Result, fsBold);
  if (Value and 2) <> 0 then Include(Result, fsItalic);
  if (Value and 4) <> 0 then Include(Result, fsUnderline);
  if (Value and 8) <> 0 then Include(Result, fsStrikeOut);
end;

function CharacterPreviewRubyTextBounds(Canvas: TCanvas;
  const Common: TDisplayCommonSettings; const Item: TDisplayPlacementItem;
  const BaseText, RubyText: string; const Destination: TRect;
  Scale: Double): TRect;
var
  BaseHeight: Integer;
  BaseSize: TSize;
  BaseStyle: Byte;
  Center: TPoint;
  RubyCenterX: Double;
  RubyCenterY: Double;
  RubyHeight: Integer;
  RubyScaleX: Double;
  RubyScaleY: Double;
  RubySize: TSize;
  RubySpacing: Integer;
  RubyStyle: Byte;
begin
  Result := TRect.Empty;
  if RubyText = '' then Exit;
  Center.X := Destination.Left + Destination.Width div 2 +
    Round(Item.X * Scale);
  Center.Y := Destination.Top + Destination.Height div 2 +
    Round(Item.Y * Scale);
  Canvas.Font.Name := Common.BaseFontName;
  if Item.BaseFontName <> '' then
    Canvas.Font.Name := Item.BaseFontName;
  BaseHeight := Common.BaseFontHeight;
  if Item.HasBaseFontHeight then
    BaseHeight := Item.BaseFontHeight;
  Canvas.Font.Height := -Max(1, BaseHeight);
  BaseStyle := Common.BaseFontStyle;
  if Item.HasBaseFontStyle then
    BaseStyle := Item.BaseFontStyle;
  Canvas.Font.Style := CharacterFontStyle(BaseStyle);
  SetTextCharacterExtra(Canvas.Handle,
    IfThen(Item.HasBaseCharacterSpacing, Item.BaseCharacterSpacing, 0));
  BaseSize := Canvas.TextExtent(BaseText);
  Canvas.Font.Name := Common.RubyFontName;
  if Item.RubyFontName <> '' then
    Canvas.Font.Name := Item.RubyFontName;
  RubyHeight := Common.RubyFontHeight;
  if Item.HasRubyFontHeight then
    RubyHeight := Item.RubyFontHeight;
  Canvas.Font.Height := -Max(1, RubyHeight);
  RubyStyle := Common.RubyFontStyle;
  if Item.HasRubyFontStyle then
    RubyStyle := Item.RubyFontStyle;
  Canvas.Font.Style := CharacterFontStyle(RubyStyle);
  RubySpacing := 0;
  if Item.HasRubyCharacterSpacing then
    RubySpacing := Item.RubyCharacterSpacing;
  SetTextCharacterExtra(Canvas.Handle, RubySpacing);
  RubySize := Canvas.TextExtent(RubyText);
  SetTextCharacterExtra(Canvas.Handle, 0);
  RubyScaleX := IfThen(Item.RubyScaleX > 0, Item.RubyScaleX, 1.0);
  RubyScaleY := IfThen(Item.RubyScaleY > 0, Item.RubyScaleY, 1.0);
  RubyCenterX := IfThen(Item.HasRubyOffsetX, Item.RubyOffsetX, 0);
  // Ruby stays above the unscaled base glyphs while its own scale changes.
  RubyCenterY := -BaseSize.cy * 0.5 - RubySize.cy * 0.5 -
    (4 + Common.RubyGapAdjustment) +
    IfThen(Item.HasRubyOffsetY, Item.RubyOffsetY, 0);
  Result := Rect(
    Center.X + Round((RubyCenterX - RubySize.cx * RubyScaleX * 0.5) *
      Scale * Item.ScaleX),
    Center.Y + Round((RubyCenterY - RubySize.cy * RubyScaleY * 0.5) *
      Scale * Item.ScaleY),
    Center.X + Round((RubyCenterX + RubySize.cx * RubyScaleX * 0.5) *
      Scale * Item.ScaleX),
    Center.Y + Round((RubyCenterY + RubySize.cy * RubyScaleY * 0.5) *
      Scale * Item.ScaleY));
end;

function CharacterPreviewElementBounds(Canvas: TCanvas;
  const Common: TDisplayCommonSettings; const Item: TDisplayPlacementItem;
  const BaseText, RubyText: string; const Destination: TRect;
  Scale: Double; PPI: Integer): TRect;
var
  BaseHeight: Integer;
  BaseSpacing: Integer;
  BaseStyle: Byte;
  BaseRect: TRectF;
  BaseSize: TSize;
  Center: TPoint;
  RubyBounds: TRect;
begin
  Center.X := Destination.Left + Destination.Width div 2 +
    Round(Item.X * Scale);
  Center.Y := Destination.Top + Destination.Height div 2 +
    Round(Item.Y * Scale);
  Canvas.Font.Name := Common.BaseFontName;
  if Item.BaseFontName <> '' then
    Canvas.Font.Name := Item.BaseFontName;
  BaseHeight := Common.BaseFontHeight;
  if Item.HasBaseFontHeight then
    BaseHeight := Item.BaseFontHeight;
  Canvas.Font.Height := -Max(1, BaseHeight);
  BaseStyle := Common.BaseFontStyle;
  if Item.HasBaseFontStyle then BaseStyle := Item.BaseFontStyle;
  Canvas.Font.Style := CharacterFontStyle(BaseStyle);
  BaseSpacing := 0;
  if Item.HasBaseCharacterSpacing then
    BaseSpacing := Item.BaseCharacterSpacing;
  SetTextCharacterExtra(Canvas.Handle, BaseSpacing);
  BaseSize := Canvas.TextExtent(BaseText);
  BaseRect := RectF(-BaseSize.cx * 0.5, -BaseSize.cy * 0.5,
    BaseSize.cx * 0.5, BaseSize.cy * 0.5);
  Result := Rect(Center.X + Round(BaseRect.Left * Scale * Item.ScaleX),
    Center.Y + Round(BaseRect.Top * Scale * Item.ScaleY),
    Center.X + Round(BaseRect.Right * Scale * Item.ScaleX),
    Center.Y + Round(BaseRect.Bottom * Scale * Item.ScaleY));
  RubyBounds := CharacterPreviewRubyTextBounds(Canvas, Common, Item,
    BaseText, RubyText, Destination, Scale);
  if not IsRectEmpty(RubyBounds) then
    UnionRect(Result, Result, RubyBounds);
  SetTextCharacterExtra(Canvas.Handle, 0);
  InflateRect(Result, MulDiv(4, PPI, 96), MulDiv(4, PPI, 96));
end;

end.
