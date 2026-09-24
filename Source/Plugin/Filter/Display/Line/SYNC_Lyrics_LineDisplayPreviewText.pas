unit SYNC_Lyrics_LineDisplayPreviewText;

// Renders the line placement preview text, including Skia decorations and phase clipping.

interface

uses
  System.Types,
  Vcl.Graphics,
  TextRendererSkia,
  SYNC_Lyrics_DisplaySettingsData;

// Draws both phases around preview-client TransitionX. Decoration sizes use PreviewScale;
// a Skia failure falls back to unadorned GDI text on Canvas.
procedure DrawLineHalfSyncedText(Canvas: TCanvas; Renderer: TSkiaTextRenderer;
  const Common: TDisplayCommonSettings; PreviewScale: Double;
  PreviewWidth, PreviewHeight, X, Y: Integer; const Text: string;
  TransitionX, CharacterSpacing: Integer);

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  Winapi.Windows,
  TextRendererTypes;

function PreviewAlphaColor(Color: TColor; Opacity: Byte): TAlphaColor;
var
  Resolved: TColor;
begin
  Resolved := ColorToRGB(Color);
  Result := TAlphaColor((Cardinal(Opacity) shl 24) or
    (Cardinal(GetRValue(Resolved)) shl 16) or
    (Cardinal(GetGValue(Resolved)) shl 8) or
    Cardinal(GetBValue(Resolved)));
end;

function CreatePreviewBitmap(
  Image: TTextRenderImage): Vcl.Graphics.TBitmap;
var
  Destination: PByte;
  Source: PTextRenderPixel;
  X: Integer;
  Y: Integer;
begin
  Result := nil;
  if (Image = nil) or Image.IsEmpty then
    Exit;
  Result := Vcl.Graphics.TBitmap.Create;
  try
    Result.PixelFormat := pf32bit;
    Result.SetSize(Image.Width, Image.Height);
    // AlphaBlend expects premultiplied BGRA, whereas Skia supplies straight RGBA.
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
    FreeAndNil(Result);
    raise;
  end;
end;

function RenderLinePreviewTextImage(
  Renderer: TSkiaTextRenderer; const Common: TDisplayCommonSettings;
  PreviewScale: Double; Canvas: TCanvas; const Text: string; CharacterSpacing: Integer;
  AfterPhase, IncludeDecoration: Boolean): TTextRenderImage;
var
  BlurColor: TColor;
  BlurOpacity: Byte;
  FillColor: TColor;
  FillOpacity: Byte;
  Metrics: TTextRenderMetrics;
  OutlineColor: TColor;
  OutlineOpacity: Byte;
  Request: TTextRenderRequest;
  Shadow: TTextRenderShadow;
  ShadowColor: TColor;
  ShadowOpacity: Byte;
begin
  Result := nil;
  if (Renderer = nil) or (Text = '') then
    Exit;
  if AfterPhase then
  begin
    FillColor := TColor(Common.AfterColor);
    FillOpacity := Common.AfterOpacity;
    OutlineColor := TColor(Common.AfterOutlineColor);
    OutlineOpacity := Common.AfterOutlineOpacity;
    ShadowColor := TColor(Common.AfterShadowColor);
    ShadowOpacity := Common.AfterShadowOpacity;
    BlurColor := TColor(Common.AfterBlurColor);
    BlurOpacity := Common.AfterBlurOpacity;
  end
  else
  begin
    FillColor := TColor(Common.BeforeColor);
    FillOpacity := Common.BeforeOpacity;
    OutlineColor := TColor(Common.BeforeOutlineColor);
    OutlineOpacity := Common.BeforeOutlineOpacity;
    ShadowColor := TColor(Common.BeforeShadowColor);
    ShadowOpacity := Common.BeforeShadowOpacity;
    BlurColor := TColor(Common.BeforeBlurColor);
    BlurOpacity := Common.BeforeBlurOpacity;
  end;
  if PreviewScale <= 0 then
    PreviewScale := 1;
  Request := TTextRenderRequest.Default;
  Request.Text := Text;
  Request.FontFamilies := [Canvas.Font.Name, 'Yu Gothic UI', 'Meiryo UI',
    'Segoe UI'];
  Request.FontSize := Max(1, Abs(Canvas.Font.Height));
  Request.LetterSpacing := CharacterSpacing;
  Request.FontStyle := [];
  if fsBold in Canvas.Font.Style then
    Include(Request.FontStyle, TTextRenderFontStyleItem.Bold);
  if fsItalic in Canvas.Font.Style then
    Include(Request.FontStyle, TTextRenderFontStyleItem.Italic);
  if fsUnderline in Canvas.Font.Style then
    Include(Request.FontStyle, TTextRenderFontStyleItem.Underline);
  if fsStrikeOut in Canvas.Font.Style then
    Include(Request.FontStyle, TTextRenderFontStyleItem.StrikeOut);
  Request.FillColor := PreviewAlphaColor(FillColor, FillOpacity);
  Request.CaptureTextUnits := True;
  Request.Outlines := [];
  if IncludeDecoration and Common.OutlineEnabled and
    (Common.OutlineWidth > 0) then
  begin
    if Common.OutlineBlur <= 0 then
      Request.Outlines := [TTextRenderOutline.Create(
        Common.OutlineWidth * PreviewScale,
        PreviewAlphaColor(OutlineColor, OutlineOpacity))]
    else if (ColorToRGB(BlurColor) = ColorToRGB(OutlineColor)) and
      (BlurOpacity = OutlineOpacity) then
      Request.Outlines := [TTextRenderOutline.Create(
        Common.OutlineWidth * PreviewScale,
        Common.OutlineBlur * PreviewScale,
        PreviewAlphaColor(OutlineColor, OutlineOpacity))]
    else
      Request.Outlines := [
        TTextRenderOutline.Create(Common.OutlineWidth * PreviewScale,
          Common.OutlineBlur * PreviewScale,
          PreviewAlphaColor(BlurColor, BlurOpacity)),
        TTextRenderOutline.Create(Common.OutlineWidth * PreviewScale,
          PreviewAlphaColor(OutlineColor, OutlineOpacity))];
  end;
  Request.Shadows := [];
  if IncludeDecoration and Common.ShadowEnabled then
  begin
    Shadow := System.Default(TTextRenderShadow);
    Shadow.Offset := PointF(Common.ShadowOffsetX * PreviewScale,
      Common.ShadowOffsetY * PreviewScale);
    Shadow.BlurRadius := Common.ShadowBlur * PreviewScale;
    Shadow.SpreadRadius := Common.ShadowSpread * PreviewScale;
    Shadow.Color := PreviewAlphaColor(ShadowColor, ShadowOpacity);
    Request.Shadows := [Shadow];
  end;
  Result := Renderer.Render(Request, Metrics);
end;

procedure DrawLinePreviewImage(
  Canvas: TCanvas; Image, AnchorImage: TTextRenderImage; X, Y,
  TransitionX, PreviewWidth, PreviewHeight: Integer; AfterPhase: Boolean);
var
  Bitmap: Vcl.Graphics.TBitmap;
  Blend: BLENDFUNCTION;
  ImageLeft: Integer;
  ImageTop: Integer;
  SavedDC: Integer;
begin
  Bitmap := CreatePreviewBitmap(Image);
  if Bitmap = nil then
    Exit;
  try
    if (Length(AnchorImage.TextUnitOrigins) > 0) and
      (Length(Image.TextUnitOrigins) > 0) then
    begin
      // The undecorated glyph origin stays fixed as outline and shadow expand bounds.
      ImageLeft := X + Round(AnchorImage.TextUnitOrigins[0].X +
        AnchorImage.Bounds.Left - AnchorImage.LayoutBounds.Left -
        Image.TextUnitOrigins[0].X);
      ImageTop := Y + Round(AnchorImage.TextUnitOrigins[0].Y +
        AnchorImage.Bounds.Top - AnchorImage.LayoutBounds.Top -
        Image.TextUnitOrigins[0].Y);
    end
    else
    begin
      ImageLeft := X + Image.Bounds.Left - Image.LayoutBounds.Left;
      ImageTop := Y + Image.Bounds.Top - Image.LayoutBounds.Top;
    end;
    SavedDC := SaveDC(Canvas.Handle);
    try
      if AfterPhase then
        IntersectClipRect(Canvas.Handle, 0, 0, TransitionX,
          PreviewHeight)
      else
        IntersectClipRect(Canvas.Handle, TransitionX, 0,
          PreviewWidth, PreviewHeight);
      Blend.BlendOp := AC_SRC_OVER;
      Blend.BlendFlags := 0;
      Blend.SourceConstantAlpha := 255;
      Blend.AlphaFormat := AC_SRC_ALPHA;
      AlphaBlend(Canvas.Handle, ImageLeft, ImageTop, Bitmap.Width,
        Bitmap.Height, Bitmap.Canvas.Handle, 0, 0, Bitmap.Width,
        Bitmap.Height, Blend);
    finally
      RestoreDC(Canvas.Handle, SavedDC);
    end;
  finally
    Bitmap.Free;
  end;
end;

procedure DrawLineHalfSyncedText(
  Canvas: TCanvas; Renderer: TSkiaTextRenderer;
  const Common: TDisplayCommonSettings; PreviewScale: Double;
  PreviewWidth, PreviewHeight, X, Y: Integer; const Text: string; TransitionX,
  CharacterSpacing: Integer);
var
  AfterImage: TTextRenderImage;
  AnchorImage: TTextRenderImage;
  BeforeImage: TTextRenderImage;
  RenderedWithSkia: Boolean;
  SavedDC: Integer;
begin
  BeforeImage := nil;
  AfterImage := nil;
  AnchorImage := nil;
  RenderedWithSkia := False;
  if Renderer <> nil then
    try
      AnchorImage := RenderLinePreviewTextImage(Renderer, Common, PreviewScale, Canvas,
        Text, CharacterSpacing,
        False, False);
      BeforeImage := RenderLinePreviewTextImage(Renderer, Common, PreviewScale, Canvas,
        Text, CharacterSpacing,
        False, True);
      AfterImage := RenderLinePreviewTextImage(Renderer, Common, PreviewScale, Canvas,
        Text, CharacterSpacing,
        True, True);
      if (AnchorImage <> nil) and (BeforeImage <> nil) and
        (AfterImage <> nil) then
      begin
        DrawLinePreviewImage(Canvas, BeforeImage, AnchorImage, X, Y,
          TransitionX, PreviewWidth, PreviewHeight, False);
        DrawLinePreviewImage(Canvas, AfterImage, AnchorImage, X, Y,
          TransitionX, PreviewWidth, PreviewHeight, True);
        RenderedWithSkia := True;
      end;
    except
      { Retain the transparent GDI preview if Skia cannot render a font. }
    end;
  BeforeImage.Free;
  AfterImage.Free;
  AnchorImage.Free;
  if RenderedWithSkia then
    Exit;

  Canvas.Font.Color := TColor(Common.BeforeColor);
  Canvas.TextOut(X, Y, Text);
  SavedDC := SaveDC(Canvas.Handle);
  try
    IntersectClipRect(Canvas.Handle, 0, 0, TransitionX,
      PreviewHeight);
    Canvas.Font.Color := TColor(Common.AfterColor);
    Canvas.TextOut(X, Y, Text);
  finally
    RestoreDC(Canvas.Handle, SavedDC);
  end;
end;

end.
