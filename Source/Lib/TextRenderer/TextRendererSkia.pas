unit TextRendererSkia;

// System.Skiaを使い、文字と装飾を直接RGBA画像へ描画する。

interface

uses
  TextRendererSkiaBootstrap,
  System.Skia,
  TextRenderer,
  TextRendererTypes;

type
  TSkiaTextRenderer = class(TCustomTextRenderer)
  private
    function CreateTypeface(const AFontFamilies: TArray<string>;
      const AFontStyle: TTextRenderFontStyle): ISkTypeface;
  public
    // 指定フォントファミリーをSkiaが解決できるか返す。
    class function IsFontFamilyAvailable(const AFontFamily: string): Boolean; static;
    // 診断表示用のSkiaバックエンド名を返す。
    function BackendName: string; override;
    // 文字配置を測定し、装飾と文字単位情報を含むRGBA画像を生成する。
    function Render(const ARequest: TTextRenderRequest;
      out AMetrics: TTextRenderMetrics): TTextRenderImage; override;
  end;

implementation

uses
  System.Diagnostics,
  System.Math,
  System.SysUtils,
  System.Types,
  System.UITypes,
  TextRendererSkiaRuntime;

const
  ANTI_ALIAS_PADDING = 2;

function CreateSkiaFontStyle(const AStyle: TTextRenderFontStyle): TSkFontStyle;
var
  Slant: TSkFontSlant;
  Weight: TSkFontWeight;
begin
  if TTextRenderFontStyleItem.Bold in AStyle then
    Weight := TSkFontWeight.Bold
  else
    Weight := TSkFontWeight.Normal;
  if TTextRenderFontStyleItem.Italic in AStyle then
    Slant := TSkFontSlant.Italic
  else
    Slant := TSkFontSlant.Upright;
  Result := TSkFontStyle.Create(Weight, TSkFontWidth.Normal, Slant);
end;

procedure IncludeBounds(var ATarget: TRectF; var AHasBounds: Boolean;
  const ASource: TRectF);
begin
  if not AHasBounds then
  begin
    ATarget := ASource;
    AHasBounds := True;
    Exit;
  end;
  ATarget.Left := Min(ATarget.Left, ASource.Left);
  ATarget.Top := Min(ATarget.Top, ASource.Top);
  ATarget.Right := Max(ATarget.Right, ASource.Right);
  ATarget.Bottom := Max(ATarget.Bottom, ASource.Bottom);
end;

function CountNonTransparentPixels(const AImage: TTextRenderImage): NativeUInt;
var
  I: NativeInt;
  Pixel: PTextRenderPixel;
begin
  Result := 0;
  Pixel := AImage.Data;
  for I := 0 to AImage.PixelCount - 1 do
  begin
    if Pixel^.A <> 0 then
      Inc(Result);
    Inc(Pixel);
  end;
end;

{ TSkiaTextRenderer }

function TSkiaTextRenderer.BackendName: string;
begin
  Result := 'Skia raster-direct';
end;

class function TSkiaTextRenderer.IsFontFamilyAvailable(
  const AFontFamily: string): Boolean;
begin
  Result := (Trim(AFontFamily) <> '') and
    (TSkTypeface.MakeFromName(AFontFamily, TSkFontStyle.Normal) <> nil);
end;

function TSkiaTextRenderer.CreateTypeface(
  const AFontFamilies: TArray<string>;
  const AFontStyle: TTextRenderFontStyle): ISkTypeface;
var
  FamilyName: string;
  SkiaStyle: TSkFontStyle;
begin
  SkiaStyle := CreateSkiaFontStyle(AFontStyle);
  for FamilyName in AFontFamilies do
  begin
    Result := TSkTypeface.MakeFromName(FamilyName, SkiaStyle);
    if Result <> nil then
      Exit;
  end;
  Result := TSkTypeface.MakeDefault;
  if Result = nil then
    raise EInvalidOp.Create('No usable typeface is available');
end;

function TSkiaTextRenderer.Render(const ARequest: TTextRenderRequest;
  out AMetrics: TTextRenderMetrics): TTextRenderImage;
type
  TTextLine = record
    Advances: TArray<Single>;
    BaselineY: Single;
    Blob: ISkTextBlob;
    Glyphs: TArray<Word>;
    LayoutBounds: TRectF;
    Positioned: Boolean;
    Positions: TArray<TPointF>;
    Text: string;
    X: Single;
  end;
var
  Bounds: TRect;
  Canvas: ISkCanvas;
  FillPaint: ISkPaint;
  FloatBounds: TRectF;
  Font: ISkFont;
  FontMetrics: TSkFontMetrics;
  HasBounds: Boolean;
  HasLayoutBounds: Boolean;
  HasUnitBounds: TArray<Boolean>;
  I: Integer;
  ImageInfo: TSkImageInfo;
  J: Integer;
  LineAdvance: Single;
  LineBounds: TRectF;
  Lines: TArray<TTextLine>;
  LayoutStopwatch: TStopwatch;
  LayoutBounds: TRect;
  LineLayoutBounds: TArray<TRect>;
  LineUnitBounds: TArray<TRectF>;
  LayoutFloatBounds: TRectF;
  MaxLineWidth: Single;
  MeasuredBounds: TRectF;
  NormalizedText: string;
  OutlineLayoutPaints: TArray<ISkPaint>;
  OutlinePaints: TArray<ISkPaint>;
  ShadowBounds: TRectF;
  ShadowPaints: TArray<ISkPaint>;
  Surface: ISkSurface;
  TextLines: TArray<string>;
  TextUnitAdvances: TArray<Single>;
  TextUnitBounds: TArray<TRect>;
  TextUnitImages: TArray<TTextRenderImage>;
  TextUnitOrigins: TArray<TPointF>;
  TotalStopwatch: TStopwatch;
  Typeface: ISkTypeface;
  DrawStopwatch: TStopwatch;
  UnitBounds: TArray<TRectF>;
  UnitIndex: Integer;
  UnitRect: TRect;
  UnderlinePosition: Single;
  UnderlineThickness: Single;
  StrikeoutPosition: Single;
  StrikeoutThickness: Single;
  procedure MeasureLine(const ALine: TTextLine; const APaint: ISkPaint;
    out ABounds: TRectF);
  var
    GlyphBounds: TArray<TRectF>;
    GlyphIndex: Integer;
    HasGlyphBounds: Boolean;
    R: TRectF;
  begin
    if not ALine.Positioned then
    begin
      Font.MeasureText(ALine.Text, ABounds, APaint);
      Exit;
    end;
    GlyphBounds := Font.GetBounds(ALine.Glyphs, APaint);
    HasGlyphBounds := False;
    for GlyphIndex := 0 to High(GlyphBounds) do
    begin
      R := GlyphBounds[GlyphIndex];
      R.Offset(ALine.Positions[GlyphIndex]);
      IncludeBounds(ABounds, HasGlyphBounds, R);
    end;
    if not HasGlyphBounds then
      ABounds := TRectF.Empty;
  end;

  procedure DrawLine(const ALine: TTextLine; const AX, AY: Single;
    const APaint: ISkPaint);
  begin
    if ALine.Positioned then
      Canvas.DrawGlyphs(ALine.Glyphs, ALine.Positions, PointF(AX, AY),
        Font, APaint)
    else
      Canvas.DrawTextBlob(ALine.Blob, AX, AY, APaint);
  end;

  procedure GetDecorationRange(const ALine: TTextLine;
    const AGlyphIndex: Integer; out ALeft, ARight: Single);
  var
    K: Integer;
    SegmentLeft: Single;
    SegmentRight: Single;
    Temporary: Single;
  begin
    ALeft := 0;
    ARight := 0;
    if Length(ALine.Glyphs) = 0 then
      Exit;
    if AGlyphIndex >= 0 then
    begin
      ALeft := ALine.Positions[AGlyphIndex].X;
      ARight := ALeft + ALine.Advances[AGlyphIndex];
      if ARight < ALeft then
      begin
        Temporary := ALeft;
        ALeft := ARight;
        ARight := Temporary;
      end;
      Exit;
    end;
    ALeft := ALine.Positions[0].X;
    ARight := ALeft + ALine.Advances[0];
    if ARight < ALeft then
    begin
      Temporary := ALeft;
      ALeft := ARight;
      ARight := Temporary;
    end;
    for K := 1 to High(ALine.Glyphs) do
    begin
      SegmentLeft := ALine.Positions[K].X;
      SegmentRight := SegmentLeft + ALine.Advances[K];
      if SegmentRight < SegmentLeft then
      begin
        Temporary := SegmentLeft;
        SegmentLeft := SegmentRight;
        SegmentRight := Temporary;
      end;
      ALeft := Min(ALeft, SegmentLeft);
      ARight := Max(ARight, SegmentRight);
    end;
  end;

  procedure IncludeLineDecorationBounds(const ALine: TTextLine;
    var ABounds: TRectF);
  var
    DecorationBounds: TRectF;
    HasBounds: Boolean;
    Left: Single;
    Right: Single;
  begin
    if not ((TTextRenderFontStyleItem.Underline in ARequest.FontStyle) or
      (TTextRenderFontStyleItem.StrikeOut in ARequest.FontStyle)) then
      Exit;
    GetDecorationRange(ALine, -1, Left, Right);
    HasBounds := (ABounds.Width <> 0) or (ABounds.Height <> 0);
    if TTextRenderFontStyleItem.Underline in ARequest.FontStyle then
    begin
      DecorationBounds := TRectF.Create(Left,
        UnderlinePosition - UnderlineThickness * 0.5, Right,
        UnderlinePosition + UnderlineThickness * 0.5);
      IncludeBounds(ABounds, HasBounds, DecorationBounds);
    end;
    if TTextRenderFontStyleItem.StrikeOut in ARequest.FontStyle then
    begin
      DecorationBounds := TRectF.Create(Left,
        StrikeoutPosition - StrikeoutThickness * 0.5, Right,
        StrikeoutPosition + StrikeoutThickness * 0.5);
      IncludeBounds(ABounds, HasBounds, DecorationBounds);
    end;
  end;

  procedure DrawLineDecorations(const ACanvas: ISkCanvas;
    const ALine: TTextLine; const AX, AY: Single;
    const AGlyphIndex: Integer = -1);
  var
    Left: Single;
    Right: Single;
  begin
    GetDecorationRange(ALine, AGlyphIndex, Left, Right);
    if Right <= Left then
      Exit;
    if TTextRenderFontStyleItem.Underline in ARequest.FontStyle then
      ACanvas.DrawRect(TRectF.Create(AX + Left,
        AY + UnderlinePosition - UnderlineThickness * 0.5, AX + Right,
        AY + UnderlinePosition + UnderlineThickness * 0.5), FillPaint);
    if TTextRenderFontStyleItem.StrikeOut in ARequest.FontStyle then
      ACanvas.DrawRect(TRectF.Create(AX + Left,
        AY + StrikeoutPosition - StrikeoutThickness * 0.5, AX + Right,
        AY + StrikeoutPosition + StrikeoutThickness * 0.5), FillPaint);
  end;

  procedure IncludeLineUnitPaintBounds(const ALine: TTextLine;
    const APaint: ISkPaint; const AOffsetX, AOffsetY,
    AInflate: Single);
  var
    K: Integer;
    R: TRectF;
  begin
    UnitBounds := Font.GetBounds(ALine.Glyphs, APaint);
    for K := 0 to Min(High(UnitBounds), High(LineUnitBounds)) do
    begin
      R := UnitBounds[K];
      if (R.Width <= 0) and (R.Height <= 0) then
        Continue;
      R.Offset(ALine.Positions[K].X + ALine.X + AOffsetX,
        ALine.Positions[K].Y + ALine.BaselineY + AOffsetY);
      if AInflate > 0 then
        R.Inflate(AInflate, AInflate);
      IncludeBounds(LineUnitBounds[K], HasUnitBounds[K], R);
    end;
  end;

  procedure IncludeLineUnitDecorationBounds(const ALine: TTextLine);
  var
    DecorationBounds: TRectF;
    K: Integer;
    Left: Single;
    Right: Single;
  begin
    for K := 0 to High(LineUnitBounds) do
    begin
      GetDecorationRange(ALine, K, Left, Right);
      if Right <= Left then
        Continue;
      if TTextRenderFontStyleItem.Underline in ARequest.FontStyle then
      begin
        DecorationBounds := TRectF.Create(ALine.X + Left,
          ALine.BaselineY + UnderlinePosition - UnderlineThickness * 0.5,
          ALine.X + Right, ALine.BaselineY + UnderlinePosition +
          UnderlineThickness * 0.5);
        IncludeBounds(LineUnitBounds[K], HasUnitBounds[K], DecorationBounds);
      end;
      if TTextRenderFontStyleItem.StrikeOut in ARequest.FontStyle then
      begin
        DecorationBounds := TRectF.Create(ALine.X + Left,
          ALine.BaselineY + StrikeoutPosition - StrikeoutThickness * 0.5,
          ALine.X + Right, ALine.BaselineY + StrikeoutPosition +
          StrikeoutThickness * 0.5);
        IncludeBounds(LineUnitBounds[K], HasUnitBounds[K], DecorationBounds);
      end;
    end;
  end;

  function RenderLineUnit(const ALine: TTextLine; const AGlyphIndex: Integer;
    const AUnitRect: TRect): TTextRenderImage;
  var
    Glyph: TArray<Word>;
    LocalCanvas: ISkCanvas;
    LocalImageInfo: TSkImageInfo;
    LocalPosition: TArray<TPointF>;
    LocalSurface: ISkSurface;
    OriginX: Single;
    OriginY: Single;
    PaintIndex: Integer;
  begin
    Result := TTextRenderImage.Create(AUnitRect, AUnitRect);
    try
      LocalImageInfo := TSkImageInfo.Create(Result.Width, Result.Height,
        TSkColorType.RGBA8888, TSkAlphaType.Unpremul);
      LocalSurface := TSkSurface.MakeRasterDirect(LocalImageInfo, Result.Data,
        Result.Stride);
      if LocalSurface = nil then
        raise EInvalidOp.Create('Cannot create text-unit raster surface');
      LocalCanvas := LocalSurface.Canvas;
      LocalCanvas.Clear(TAlphaColorRec.Null);
      Glyph := [ALine.Glyphs[AGlyphIndex]];
      LocalPosition := [ALine.Positions[AGlyphIndex]];
      OriginX := ALine.X - Bounds.Left - AUnitRect.Left;
      OriginY := ALine.BaselineY - Bounds.Top - AUnitRect.Top;
      for PaintIndex := 0 to High(ShadowPaints) do
        LocalCanvas.DrawGlyphs(Glyph, LocalPosition,
          PointF(OriginX + ARequest.Shadows[PaintIndex].Offset.X,
            OriginY + ARequest.Shadows[PaintIndex].Offset.Y), Font,
          ShadowPaints[PaintIndex]);
      for PaintIndex := 0 to High(OutlinePaints) do
        LocalCanvas.DrawGlyphs(Glyph, LocalPosition, PointF(OriginX, OriginY),
          Font, OutlinePaints[PaintIndex]);
      LocalCanvas.DrawGlyphs(Glyph, LocalPosition, PointF(OriginX, OriginY),
        Font, FillPaint);
      DrawLineDecorations(LocalCanvas, ALine, OriginX, OriginY, AGlyphIndex);
      LocalSurface.Flush;
    except
      Result.Free;
      raise;
    end;
  end;
begin
  AMetrics := System.Default(TTextRenderMetrics);
  TotalStopwatch := TStopwatch.StartNew;
  if not TTextRendererSkiaRuntime.IsAcquired then
    raise EInvalidOp.Create('Skia runtime is not acquired');
  if ARequest.FontSize <= 0 then
    raise EArgumentOutOfRangeException.Create('FontSize must be greater than zero');
  if ARequest.Direction <> TTextRenderDirection.Horizontal then
    raise ENotSupportedException.Create('Vertical text is not implemented yet');
  if (ARequest.MaxWidth <> 0) or (ARequest.MaxHeight <> 0) then
    raise ENotSupportedException.Create('Constrained layout is not implemented yet');
  if not ARequest.TrimTransparentBounds then
    raise ENotSupportedException.Create('Untrimmed output is not implemented yet');
  if ARequest.Text = '' then
  begin
    Result := TTextRenderImage.Create(TRect.Empty);
    AMetrics.TotalMilliseconds := TotalStopwatch.Elapsed.TotalMilliseconds;
    Exit;
  end;

  LayoutStopwatch := TStopwatch.StartNew;
  Typeface := CreateTypeface(ARequest.FontFamilies, ARequest.FontStyle);
  Font := TSkFont.Create(Typeface, ARequest.FontSize);
  Font.Edging := TSkFontEdging.AntiAlias;

  FillPaint := TSkPaint.Create(TSkPaintStyle.Fill);
  FillPaint.AntiAlias := True;
  FillPaint.Color := ARequest.FillColor;

  SetLength(OutlinePaints, Length(ARequest.Outlines));
  SetLength(OutlineLayoutPaints, Length(ARequest.Outlines));
  for I := 0 to High(ARequest.Outlines) do
  begin
    if ARequest.Outlines[I].Width < 0 then
      raise EArgumentOutOfRangeException.Create('Outline width must not be negative');
    if ARequest.Outlines[I].BlurRadius < 0 then
      raise EArgumentOutOfRangeException.Create(
        'Outline blur must not be negative');
    OutlinePaints[I] := TSkPaint.Create(TSkPaintStyle.Stroke);
    OutlinePaints[I].AntiAlias := True;
    OutlinePaints[I].Color := ARequest.Outlines[I].Color;
    OutlinePaints[I].StrokeWidth := ARequest.Outlines[I].Width;
    OutlinePaints[I].StrokeJoin := TSkStrokeJoin.Round;
    OutlineLayoutPaints[I] := TSkPaint.Create(TSkPaintStyle.Stroke);
    OutlineLayoutPaints[I].AntiAlias := True;
    OutlineLayoutPaints[I].Color := ARequest.Outlines[I].Color;
    OutlineLayoutPaints[I].StrokeWidth := ARequest.Outlines[I].Width;
    OutlineLayoutPaints[I].StrokeJoin := TSkStrokeJoin.Round;
    if ARequest.Outlines[I].BlurRadius > 0 then
      OutlinePaints[I].MaskFilter := TSkMaskFilter.MakeBlur(
        TSkBlurStyle.Normal, ARequest.Outlines[I].BlurRadius);
  end;

  SetLength(ShadowPaints, Length(ARequest.Shadows));
  for I := 0 to High(ARequest.Shadows) do
  begin
    if (ARequest.Shadows[I].BlurRadius < 0) or
      (ARequest.Shadows[I].SpreadRadius < 0) then
      raise EArgumentOutOfRangeException.Create(
        'Shadow blur and spread must not be negative');
    if ARequest.Shadows[I].SpreadRadius > 0 then
      ShadowPaints[I] := TSkPaint.Create(TSkPaintStyle.StrokeAndFill)
    else
      ShadowPaints[I] := TSkPaint.Create(TSkPaintStyle.Fill);
    ShadowPaints[I].AntiAlias := True;
    ShadowPaints[I].Color := ARequest.Shadows[I].Color;
    ShadowPaints[I].StrokeJoin := TSkStrokeJoin.Round;
    ShadowPaints[I].StrokeWidth := ARequest.Shadows[I].SpreadRadius * 2;
    if ARequest.Shadows[I].BlurRadius > 0 then
      ShadowPaints[I].MaskFilter := TSkMaskFilter.MakeBlur(
        TSkBlurStyle.Normal, ARequest.Shadows[I].BlurRadius);
  end;

  NormalizedText := StringReplace(ARequest.Text, #13#10, #10,
    [rfReplaceAll]);
  NormalizedText := StringReplace(NormalizedText, #13, #10,
    [rfReplaceAll]);
  TextLines := NormalizedText.Split([#10], TStringSplitOptions.None);
  SetLength(Lines, Length(TextLines));
  Font.GetMetrics(FontMetrics);
  if (TSkFontMetricsFlag.UnderlinePositionIsValid in FontMetrics.Flags) then
    UnderlinePosition := FontMetrics.UnderlinePosition
  else
    UnderlinePosition := Max(1, ARequest.FontSize * 0.08);
  if (TSkFontMetricsFlag.UnderlineThicknessIsValid in FontMetrics.Flags) and
    (FontMetrics.UnderlineThickness > 0) then
    UnderlineThickness := FontMetrics.UnderlineThickness
  else
    UnderlineThickness := Max(1, ARequest.FontSize * 0.06);
  if (TSkFontMetricsFlag.StrikeoutPositionIsValid in FontMetrics.Flags) then
    StrikeoutPosition := FontMetrics.StrikeoutPosition
  else
    StrikeoutPosition := FontMetrics.XHeight * -0.5;
  if (TSkFontMetricsFlag.StrikeoutThicknessIsValid in FontMetrics.Flags) and
    (FontMetrics.StrikeoutThickness > 0) then
    StrikeoutThickness := FontMetrics.StrikeoutThickness
  else
    StrikeoutThickness := UnderlineThickness;
  LineAdvance := Max(1, Font.GetSpacing + ARequest.LineSpacing);
  MaxLineWidth := 0;
  for I := 0 to High(Lines) do
  begin
    Lines[I].Text := TextLines[I];
    Lines[I].BaselineY := I * LineAdvance;
    if Lines[I].Text <> '' then
    begin
      Lines[I].Glyphs := Font.GetGlyphs(Lines[I].Text);
      Lines[I].Positions := Font.GetPositions(Lines[I].Glyphs);
      Lines[I].Advances := Font.GetWidths(Lines[I].Glyphs);
      // 本体と文字単位レイヤーを同じグリフ座標から描く。これにより可変幅、
      // 句読点、空白を等分推測せず、拡大・ジャンプ時にも位置が一致する。
      Lines[I].Positioned := True;
      for J := 0 to High(Lines[I].Positions) do
      begin
        Lines[I].Positions[J].X := Lines[I].Positions[J].X +
          J * ARequest.LetterSpacing;
        if J < High(Lines[I].Advances) then
          Lines[I].Advances[J] := Lines[I].Advances[J] +
            ARequest.LetterSpacing;
      end;
      MeasureLine(Lines[I], FillPaint, LineBounds);
      for J := 0 to High(OutlineLayoutPaints) do
      begin
        MeasureLine(Lines[I], OutlineLayoutPaints[J], MeasuredBounds);
        LineBounds.Left := Min(LineBounds.Left, MeasuredBounds.Left);
        LineBounds.Top := Min(LineBounds.Top, MeasuredBounds.Top);
        LineBounds.Right := Max(LineBounds.Right, MeasuredBounds.Right);
        LineBounds.Bottom := Max(LineBounds.Bottom, MeasuredBounds.Bottom);
      end;
      IncludeLineDecorationBounds(Lines[I], LineBounds);
    end
    else
      LineBounds := TRectF.Create(0, FontMetrics.Ascent, 0,
        FontMetrics.Descent);
    Lines[I].LayoutBounds := LineBounds;
    MaxLineWidth := Max(MaxLineWidth, LineBounds.Width);
  end;

  HasLayoutBounds := False;
  for I := 0 to High(Lines) do
  begin
    case ARequest.Alignment of
      TTextRenderAlignment.Center:
        Lines[I].X := (MaxLineWidth - Lines[I].LayoutBounds.Width) * 0.5 -
          Lines[I].LayoutBounds.Left;
      TTextRenderAlignment.Trailing:
        Lines[I].X := MaxLineWidth - Lines[I].LayoutBounds.Width -
          Lines[I].LayoutBounds.Left;
    else
      Lines[I].X := -Lines[I].LayoutBounds.Left;
    end;
    LineBounds := Lines[I].LayoutBounds;
    LineBounds.Offset(Lines[I].X, Lines[I].BaselineY);
    Lines[I].LayoutBounds := LineBounds;
    IncludeBounds(LayoutFloatBounds, HasLayoutBounds, LineBounds);
  end;

  FloatBounds := LayoutFloatBounds;
  HasBounds := HasLayoutBounds;
  for I := 0 to High(Lines) do
    if Lines[I].Text <> '' then
      for J := 0 to High(OutlinePaints) do
        if ARequest.Outlines[J].BlurRadius > 0 then
        begin
          MeasureLine(Lines[I], OutlineLayoutPaints[J], MeasuredBounds);
          MeasuredBounds.Offset(Lines[I].X, Lines[I].BaselineY);
          MeasuredBounds.Inflate(ARequest.Outlines[J].BlurRadius * 3,
            ARequest.Outlines[J].BlurRadius * 3);
          IncludeBounds(FloatBounds, HasBounds, MeasuredBounds);
        end;
  for I := 0 to High(Lines) do
    if Lines[I].Text <> '' then
      for J := 0 to High(ShadowPaints) do
      begin
        MeasureLine(Lines[I], ShadowPaints[J], ShadowBounds);
        ShadowBounds.Offset(Lines[I].X + ARequest.Shadows[J].Offset.X,
          Lines[I].BaselineY + ARequest.Shadows[J].Offset.Y);
        ShadowBounds.Inflate(ARequest.Shadows[J].BlurRadius * 3,
          ARequest.Shadows[J].BlurRadius * 3);
        IncludeBounds(FloatBounds, HasBounds, ShadowBounds);
      end;

  LayoutBounds := TRect.Create(
    Floor(LayoutFloatBounds.Left) - ANTI_ALIAS_PADDING,
    Floor(LayoutFloatBounds.Top) - ANTI_ALIAS_PADDING,
    Ceil(LayoutFloatBounds.Right) + ANTI_ALIAS_PADDING,
    Ceil(LayoutFloatBounds.Bottom) + ANTI_ALIAS_PADDING);
  Bounds := TRect.Create(
    Floor(FloatBounds.Left) - ANTI_ALIAS_PADDING,
    Floor(FloatBounds.Top) - ANTI_ALIAS_PADDING,
    Ceil(FloatBounds.Right) + ANTI_ALIAS_PADDING,
    Ceil(FloatBounds.Bottom) + ANTI_ALIAS_PADDING);
  Result := TTextRenderImage.Create(Bounds, LayoutBounds);
  SetLength(LineLayoutBounds, Length(Lines));
  for I := 0 to High(Lines) do
    if Lines[I].Text = '' then
      LineLayoutBounds[I] := TRect.Create(
        Round(Lines[I].LayoutBounds.Left),
        Floor(Lines[I].LayoutBounds.Top) - ANTI_ALIAS_PADDING,
        Round(Lines[I].LayoutBounds.Left),
        Ceil(Lines[I].LayoutBounds.Bottom) + ANTI_ALIAS_PADDING)
    else
      LineLayoutBounds[I] := TRect.Create(
        Floor(Lines[I].LayoutBounds.Left) - ANTI_ALIAS_PADDING,
        Floor(Lines[I].LayoutBounds.Top) - ANTI_ALIAS_PADDING,
        Ceil(Lines[I].LayoutBounds.Right) + ANTI_ALIAS_PADDING,
        Ceil(Lines[I].LayoutBounds.Bottom) + ANTI_ALIAS_PADDING);
  Result.LineLayoutBounds := LineLayoutBounds;
  if ARequest.CaptureTextUnits then
  begin
    TextUnitAdvances := nil;
    TextUnitBounds := nil;
    TextUnitImages := nil;
    TextUnitOrigins := nil;
    try
      for I := 0 to High(Lines) do
      begin
        if Length(Lines[I].Glyphs) = 0 then
        begin
          UnitIndex := Length(TextUnitBounds);
          SetLength(TextUnitAdvances, UnitIndex + 1);
          SetLength(TextUnitBounds, UnitIndex + 1);
          SetLength(TextUnitImages, UnitIndex + 1);
          SetLength(TextUnitOrigins, UnitIndex + 1);
          TextUnitAdvances[UnitIndex] := 0;
          TextUnitBounds[UnitIndex] := TRect.Empty;
          TextUnitImages[UnitIndex] := nil;
          TextUnitOrigins[UnitIndex] := PointF(0, 0);
          Continue;
        end;
        SetLength(LineUnitBounds, Length(Lines[I].Glyphs));
        SetLength(HasUnitBounds, Length(Lines[I].Glyphs));
        for J := 0 to High(HasUnitBounds) do
        begin
          LineUnitBounds[J] := TRectF.Empty;
          HasUnitBounds[J] := False;
        end;
        IncludeLineUnitPaintBounds(Lines[I], FillPaint, 0, 0, 0);
        for J := 0 to High(OutlineLayoutPaints) do
          IncludeLineUnitPaintBounds(Lines[I], OutlineLayoutPaints[J], 0, 0,
            ARequest.Outlines[J].BlurRadius * 3);
        for J := 0 to High(ShadowPaints) do
          IncludeLineUnitPaintBounds(Lines[I], ShadowPaints[J],
            ARequest.Shadows[J].Offset.X, ARequest.Shadows[J].Offset.Y,
            ARequest.Shadows[J].BlurRadius * 3);
        IncludeLineUnitDecorationBounds(Lines[I]);
        UnitIndex := Length(TextUnitBounds);
        SetLength(TextUnitAdvances, UnitIndex + Length(LineUnitBounds));
        SetLength(TextUnitBounds, UnitIndex + Length(LineUnitBounds));
        SetLength(TextUnitImages, UnitIndex + Length(LineUnitBounds));
        SetLength(TextUnitOrigins, UnitIndex + Length(LineUnitBounds));
        for J := 0 to High(LineUnitBounds) do
        begin
          TextUnitAdvances[UnitIndex + J] := Lines[I].Advances[J];
          TextUnitOrigins[UnitIndex + J] := PointF(
            Lines[I].X + Lines[I].Positions[J].X - Bounds.Left,
            Lines[I].BaselineY + Lines[I].Positions[J].Y - Bounds.Top);
          if HasUnitBounds[J] then
          begin
            UnitRect := TRect.Create(
              Floor(LineUnitBounds[J].Left) - Bounds.Left - ANTI_ALIAS_PADDING,
              Floor(LineUnitBounds[J].Top) - Bounds.Top - ANTI_ALIAS_PADDING,
              Ceil(LineUnitBounds[J].Right) - Bounds.Left + ANTI_ALIAS_PADDING,
              Ceil(LineUnitBounds[J].Bottom) - Bounds.Top + ANTI_ALIAS_PADDING);
            UnitRect.Intersect(TRect.Create(0, 0, Result.Width, Result.Height));
            TextUnitBounds[UnitIndex + J] := UnitRect;
            TextUnitImages[UnitIndex + J] := RenderLineUnit(Lines[I], J,
              UnitRect);
          end
          else
          begin
            TextUnitBounds[UnitIndex + J] := TRect.Empty;
            TextUnitImages[UnitIndex + J] := nil;
          end;
        end;
      end;
      Result.TextUnitAdvances := TextUnitAdvances;
      Result.TextUnitBounds := TextUnitBounds;
      Result.TextUnitOrigins := TextUnitOrigins;
      Result.SetTextUnitImages(TextUnitImages);
      TextUnitImages := nil;
    except
      for I := 0 to High(TextUnitImages) do
        TextUnitImages[I].Free;
      Result.Free;
      raise;
    end;
  end;
  LayoutStopwatch.Stop;
  AMetrics.LayoutMilliseconds := LayoutStopwatch.Elapsed.TotalMilliseconds;

  try
    DrawStopwatch := TStopwatch.StartNew;
    ImageInfo := TSkImageInfo.Create(Result.Width, Result.Height,
      TSkColorType.RGBA8888, TSkAlphaType.Unpremul);
    Surface := TSkSurface.MakeRasterDirect(ImageInfo, Result.Data, Result.Stride);
    if Surface = nil then
      raise EInvalidOp.Create('Cannot create raster-direct surface');
    Canvas := Surface.Canvas;
    Canvas.Clear(TAlphaColorRec.Null);
    for I := 0 to High(Lines) do
      if Lines[I].Text <> '' then
      begin
        for J := 0 to High(ShadowPaints) do
          DrawLine(Lines[I],
            Lines[I].X - Bounds.Left + ARequest.Shadows[J].Offset.X,
            Lines[I].BaselineY - Bounds.Top + ARequest.Shadows[J].Offset.Y,
            ShadowPaints[J]);
        for J := 0 to High(OutlinePaints) do
          DrawLine(Lines[I], Lines[I].X - Bounds.Left,
            Lines[I].BaselineY - Bounds.Top, OutlinePaints[J]);
        DrawLine(Lines[I], Lines[I].X - Bounds.Left,
          Lines[I].BaselineY - Bounds.Top, FillPaint);
        DrawLineDecorations(Canvas, Lines[I], Lines[I].X - Bounds.Left,
          Lines[I].BaselineY - Bounds.Top);
      end;
    Surface.Flush;
    DrawStopwatch.Stop;
    AMetrics.DrawMilliseconds := DrawStopwatch.Elapsed.TotalMilliseconds;
    AMetrics.NonTransparentPixelCount := CountNonTransparentPixels(Result);
    AMetrics.TotalMilliseconds := TotalStopwatch.Elapsed.TotalMilliseconds;
  except
    Result.Free;
    raise;
  end;
end;

end.
