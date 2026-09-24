unit SYNC_Lyrics_DisplayPreviewText;

// Draws free-layout preview text with the same Skia decorations and alpha as output.

interface

uses
  Vcl.Graphics,
  TextRendererSkia,
  SYNC_Lyrics_DisplaySettingsData;

// Draws the before image under the left-half after image, matching output layering.
function DrawDisplayPreviewText(Canvas: TCanvas; Renderer: TSkiaTextRenderer;
  const Value, FontName: string; FontSize, CharacterSpacing: Integer;
  FontStyle: TFontStyles; const Decoration: TDisplayCommonSettings;
  CenterX, CenterY, ScaleX, ScaleY: Double): Boolean;

implementation

uses
  System.Math,
  System.Types,
  System.UITypes,
  Winapi.Windows,
  TextRendererTypes;

type
  TPreviewBitmap = Vcl.Graphics.TBitmap;

function AlphaColor(Color: Cardinal; Opacity: Byte): TAlphaColor;
var
  Resolved: Cardinal;
begin
  Resolved := Color and $FFFFFF;
  Result := TAlphaColor((Cardinal(Opacity) shl 24) or
    ((Resolved and $FF) shl 16) or
    (Resolved and $FF00) or
    ((Resolved shr 16) and $FF));
end;

function RenderPhase(Renderer: TSkiaTextRenderer;
  const Value, FontName: string; FontSize, CharacterSpacing: Integer;
  FontStyle: TFontStyles; const Decoration: TDisplayCommonSettings;
  AfterPhase: Boolean): TTextRenderImage;
var
  BlurColor: Cardinal;
  BlurOpacity: Byte;
  FillColor: Cardinal;
  FillOpacity: Byte;
  Metrics: TTextRenderMetrics;
  OutlineColor: Cardinal;
  OutlineOpacity: Byte;
  Request: TTextRenderRequest;
  Shadow: TTextRenderShadow;
  ShadowColor: Cardinal;
  ShadowOpacity: Byte;
begin
  if AfterPhase then
  begin
    FillColor := Decoration.AfterColor;
    FillOpacity := Decoration.AfterOpacity;
    OutlineColor := Decoration.AfterOutlineColor;
    OutlineOpacity := Decoration.AfterOutlineOpacity;
    BlurColor := Decoration.AfterBlurColor;
    BlurOpacity := Decoration.AfterBlurOpacity;
    ShadowColor := Decoration.AfterShadowColor;
    ShadowOpacity := Decoration.AfterShadowOpacity;
  end
  else
  begin
    FillColor := Decoration.BeforeColor;
    FillOpacity := Decoration.BeforeOpacity;
    OutlineColor := Decoration.BeforeOutlineColor;
    OutlineOpacity := Decoration.BeforeOutlineOpacity;
    BlurColor := Decoration.BeforeBlurColor;
    BlurOpacity := Decoration.BeforeBlurOpacity;
    ShadowColor := Decoration.BeforeShadowColor;
    ShadowOpacity := Decoration.BeforeShadowOpacity;
  end;
  Request := TTextRenderRequest.Default;
  Request.Text := Value;
  Request.FontFamilies := [FontName, 'Yu Gothic UI', 'Meiryo UI',
    'Segoe UI'];
  Request.FontSize := Max(1, FontSize);
  Request.LetterSpacing := CharacterSpacing;
  Request.FillColor := AlphaColor(FillColor, FillOpacity);
  if fsBold in FontStyle then
    Include(Request.FontStyle, TTextRenderFontStyleItem.Bold);
  if fsItalic in FontStyle then
    Include(Request.FontStyle, TTextRenderFontStyleItem.Italic);
  if fsUnderline in FontStyle then
    Include(Request.FontStyle, TTextRenderFontStyleItem.Underline);
  if fsStrikeOut in FontStyle then
    Include(Request.FontStyle, TTextRenderFontStyleItem.StrikeOut);
  if Decoration.OutlineEnabled and (Decoration.OutlineWidth > 0) then
  begin
    if Decoration.OutlineBlur <= 0 then
      Request.Outlines := [TTextRenderOutline.Create(
        Decoration.OutlineWidth, AlphaColor(OutlineColor, OutlineOpacity))]
    else if (BlurColor = OutlineColor) and
      (BlurOpacity = OutlineOpacity) then
      Request.Outlines := [TTextRenderOutline.Create(
        Decoration.OutlineWidth, Decoration.OutlineBlur,
        AlphaColor(OutlineColor, OutlineOpacity))]
    else
      Request.Outlines := [
        TTextRenderOutline.Create(Decoration.OutlineWidth,
          Decoration.OutlineBlur, AlphaColor(BlurColor, BlurOpacity)),
        TTextRenderOutline.Create(Decoration.OutlineWidth,
          AlphaColor(OutlineColor, OutlineOpacity))];
  end;
  if Decoration.ShadowEnabled then
  begin
    Shadow := Default(TTextRenderShadow);
    Shadow.Offset := PointF(Decoration.ShadowOffsetX,
      Decoration.ShadowOffsetY);
    Shadow.BlurRadius := Decoration.ShadowBlur;
    Shadow.SpreadRadius := Decoration.ShadowSpread;
    Shadow.Color := AlphaColor(ShadowColor, ShadowOpacity);
    Request.Shadows := [Shadow];
  end;
  Result := Renderer.Render(Request, Metrics);
end;

function CreatePreviewBitmap(Image: TTextRenderImage): TPreviewBitmap;
var
  Destination: PByte;
  Source: PTextRenderPixel;
  X, Y: Integer;
begin
  Result := nil;
  if (Image = nil) or Image.IsEmpty then
    Exit;
  Result := TPreviewBitmap.Create;
  try
    Result.PixelFormat := pf32bit;
    Result.SetSize(Image.Width, Image.Height);
    for Y := 0 to Image.Height - 1 do
    begin
      Source := PTextRenderPixel(PByte(Image.Data) +
        NativeInt(Y) * Image.Stride);
      Destination := Result.ScanLine[Y];
      for X := 0 to Image.Width - 1 do
      begin
        Destination[0] := (Cardinal(Source^.B) * Source^.A + 127) div 255;
        Destination[1] := (Cardinal(Source^.G) * Source^.A + 127) div 255;
        Destination[2] := (Cardinal(Source^.R) * Source^.A + 127) div 255;
        Destination[3] := Source^.A;
        Inc(Destination, 4);
        Inc(Source);
      end;
    end;
    Result.AlphaFormat := afPremultiplied;
  except
    Result.Free;
    raise;
  end;
end;

procedure DrawPhase(Canvas: TCanvas; Image: TTextRenderImage;
  CenterX, CenterY, ScaleX, ScaleY: Double; AfterPhase: Boolean);
var
  Bitmap: TPreviewBitmap;
  Blend: BLENDFUNCTION;
  DrawHeight, DrawWidth: Integer;
  DrawLeft, DrawTop: Integer;
  LayoutCenterX, LayoutCenterY: Double;
  SavedDC: Integer;
begin
  Bitmap := CreatePreviewBitmap(Image);
  if Bitmap = nil then Exit;
  try
    LayoutCenterX := (Image.LayoutBounds.Left +
      Image.LayoutBounds.Right) / 2;
    LayoutCenterY := (Image.LayoutBounds.Top +
      Image.LayoutBounds.Bottom) / 2;
    DrawLeft := Round(CenterX +
      (Image.Bounds.Left - LayoutCenterX) * ScaleX);
    DrawTop := Round(CenterY +
      (Image.Bounds.Top - LayoutCenterY) * ScaleY);
    DrawWidth := Max(1, Round(Bitmap.Width * ScaleX));
    DrawHeight := Max(1, Round(Bitmap.Height * ScaleY));
    SavedDC := SaveDC(Canvas.Handle);
    try
      if AfterPhase then
        IntersectClipRect(Canvas.Handle, 0, 0, Round(CenterX),
          GetDeviceCaps(Canvas.Handle, VERTRES));
      Blend.BlendOp := AC_SRC_OVER;
      Blend.BlendFlags := 0;
      Blend.SourceConstantAlpha := 255;
      Blend.AlphaFormat := AC_SRC_ALPHA;
      AlphaBlend(Canvas.Handle, DrawLeft, DrawTop, DrawWidth, DrawHeight,
        Bitmap.Canvas.Handle, 0, 0, Bitmap.Width, Bitmap.Height, Blend);
    finally
      RestoreDC(Canvas.Handle, SavedDC);
    end;
  finally
    Bitmap.Free;
  end;
end;

function DrawDisplayPreviewText(Canvas: TCanvas; Renderer: TSkiaTextRenderer;
  const Value, FontName: string; FontSize, CharacterSpacing: Integer;
  FontStyle: TFontStyles; const Decoration: TDisplayCommonSettings;
  CenterX, CenterY, ScaleX, ScaleY: Double): Boolean;
var
  AfterImage: TTextRenderImage;
  BeforeImage: TTextRenderImage;
  LimitedDecoration: TDisplayCommonSettings;
begin
  Result := False;
  if (Renderer = nil) or (Value = '') or (ScaleX <= 0) or
    (ScaleY <= 0) then Exit;
  BeforeImage := nil;
  AfterImage := nil;
  LimitedDecoration := Decoration;
  ClampDisplayCommonDecoration(LimitedDecoration);
  try
    BeforeImage := RenderPhase(Renderer, Value, FontName,
      FontSize, CharacterSpacing, FontStyle, LimitedDecoration, False);
    AfterImage := RenderPhase(Renderer, Value, FontName,
      FontSize, CharacterSpacing, FontStyle, LimitedDecoration, True);
    if (BeforeImage <> nil) and (AfterImage <> nil) then
    begin
      DrawPhase(Canvas, BeforeImage, CenterX, CenterY, ScaleX, ScaleY,
        False);
      DrawPhase(Canvas, AfterImage, CenterX, CenterY, ScaleX, ScaleY,
        True);
      Result := True;
    end;
  except
    Result := False;
  end;
  BeforeImage.Free;
  AfterImage.Free;
end;

end.
