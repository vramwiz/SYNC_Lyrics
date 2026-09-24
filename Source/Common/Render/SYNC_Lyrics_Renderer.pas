unit SYNC_Lyrics_Renderer;

// 歌詞の本文・ルビをSkiaで測定し、同期色を合成したRGBA画像をAviUtl2へ渡す。

interface

uses
  AviUtl2FilterTypes,
  SYNC_Lyrics_Animation,
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_ResolvedDisplayUnits;

type
  TLyricsDisplayType = (
    ldtKaraoke,
    ldtUnitEmphasis,
    ldtUnitReveal
  );
  TLyricsColorFillMode = (lcfCharacter, lcfSmooth);
  TLyricsColorAfterMode = (lcaRestore, lcaKeep);
  TLyricsSyncKind = (lskNone, lskColor, lskFront, lskBacking, lskUnderline,
    lskZoom, lskGlow, lskJump, lskBlink, lskGlitch);

  // AviUtl2の色項目から独立して描画処理へ渡すARGB色。
  TLyricsRenderColor = record
    A: Byte;
    R: Byte;
    G: Byte;
    B: Byte;
  end;

  // 1行の本文とルビに適用する基本表示設定。
  TLyricsRenderSettings = record
    DisplayType: TLyricsDisplayType;
    ColorFillMode: TLyricsColorFillMode;
    ColorAfterMode: TLyricsColorAfterMode;
    ColorBandSizePercent: Double;
    CompletionRestoreProgress: Double; // 0 at sync end, 1 at hold end.
    SyncKind: TLyricsSyncKind;
    SyncMotionID: Integer; // 音の切り替わりで再発動する動作。16=拡大、17=ジャンプ。
    HasSyncNoteEvent: Boolean; // 曲同期では音の範囲外も含め、表示単位進捗への代替を禁止する。
    SyncNoteFirstUnit: Integer; // 1音が担当する表示単位範囲の先頭。
    SyncNoteUnitCount: Integer; // 1音が同時に担当する表示単位数。
    SyncNoteProgress: Double; // 現在音の開始0から終了1まで。
    AsyncHoldID: Integer; // 音から独立して周期評価する参考元の表示中演出ID。
    AsyncSpeed: Double; // 非同期演出の1秒当たりの周期数。
    SyncShape: Integer;
    SyncOffsetX: Double;
    SyncOffsetY: Double;
    Opacity: Double;
    LayerOffsetX: Double;
    LayerOffsetY: Double;
    LayerScaleX: Double;
    LayerScaleY: Double;
    LayerRotationDegrees: Double;
    LayerBlurRadius: Double;
    LayerWipeDirection: Integer;
    LayerWipeProgress: Double;
    EdgeSettings: TLyricsEdgeSettings; // 表示単位ごとの登場・退場動作と表示。
    BaseFontName: string;
    RubyFontName: string;
    BaseBold: Boolean;
    BaseItalic: Boolean;
    BaseUnderline: Boolean;
    BaseStrikeOut: Boolean;
    RubyBold: Boolean;
    RubyItalic: Boolean;
    RubyUnderline: Boolean;
    RubyStrikeOut: Boolean;
    BaseFontHeight: Integer;
    RubyFontHeight: Integer;
    RubyGapAdjustment: Integer;
    BaseCharacterSpacing: Integer;
    RubyCharacterSpacing: Integer;
    BeforeColor: TLyricsRenderColor;
    AfterColor: TLyricsRenderColor;
    BeforeOutlineColor: TLyricsRenderColor;
    AfterOutlineColor: TLyricsRenderColor;
    BeforeShadowColor: TLyricsRenderColor;
    AfterShadowColor: TLyricsRenderColor;
    BeforeBlurColor: TLyricsRenderColor;
    AfterBlurColor: TLyricsRenderColor;
    OutlineEnabled: Boolean;
    OutlineWidth: Single;
    OutlineBlur: Single;
    ShadowEnabled: Boolean;
    ShadowOffsetX: Single;
    ShadowOffsetY: Single;
    ShadowBlur: Single;
    ShadowSpread: Single;
    SyncColor: TLyricsRenderColor;
  end;

// 描画用の共有資源を初期化する。Filterの初期化時に1回だけ呼び出す。
procedure InitializeLyricsRenderer;

// 新規歌詞表示に使用する既定の描画設定を返す。
function DefaultLyricsRenderSettings: TLyricsRenderSettings;

// Returns the visual progress of one unit; silent marks switch at a note boundary.
function ResolveLyricsDisplayUnitProgress(
  const Units: TResolvedLyricsDisplayUnits; UnitIndex: Integer;
  ProgressUnits: Double): Double;

// AviUtl2へ渡す歌詞画像の寸法を取得する。
function TryGetLyricsRenderSize(Video: PFILTER_PROC_VIDEO;
  out Width, Height: Integer): Boolean;

// Copies the image received from the preceding timeline stage into Buffer.
// A transparent buffer is used only when no input-image callback is available.
procedure InitializeLyricsRenderBuffer(Video: PFILTER_PROC_VIDEO;
  Buffer: PPIXEL_RGBA; PixelCount: NativeInt);

// 既存RGBAバッファを消去せず、1行配置の歌詞を重ねて描画する。
function DrawLyricsLayer(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  PositionX, PositionY: Integer): Boolean;

// 既存RGBAバッファを消去せず、自由配置の歌詞を重ねて描画する。
function DrawFreePlacementLyricsLayer(Buffer: PPIXEL_RGBA;
  Width, Height: Integer; Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  const Placements: TDisplayPlacementItems;
  PositionX, PositionY: Integer): Boolean;

// 入力文字列を中央基準の指定座標へ配置し、表示単位進捗をクリッピング描画してAviUtl2へ渡す。
function RenderLyrics(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings; PositionX, PositionY: Integer): Boolean;

// 保存済みの各表示単位座標へ本文とルビを個別配置してAviUtl2へ渡す。
function RenderFreePlacementLyrics(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR;
  ProgressUnits: Double; const Settings: TLyricsRenderSettings;
  const Placements: TDisplayPlacementItems;
  PositionX, PositionY: Integer): Boolean;

// 描画用の共有資源を解放する。処理中のコールバックがない状態で呼び出す。
procedure FinalizeLyricsRenderer;

implementation

uses
  System.Math,
  System.SysUtils,
  System.Types,
  System.UITypes,
  MVAnimationTypes,
  MVAnimationCatalog,
  PluginFilterSerifDrawSyncHighlight,
  SYNC_Lyrics_LyricParser,
  TextRendererSkiaBootstrap,
  TextRenderer,
  TextRendererSkia,
  TextRendererSkiaRuntime,
  TextRendererTypes,
  Winapi.Windows;

const
  MAX_RENDER_DIMENSION = 16384;
  DEFAULT_LYRIC_FONT_HEIGHT = 96;
  DEFAULT_RUBY_FONT_HEIGHT = 42;
  DEFAULT_RUBY_GAP = 4;
  MIN_FONT_HEIGHT = 1;
  MAX_FONT_HEIGHT = 1024;
  MIN_RUBY_GAP = -1024;
  MAX_RUBY_GAP = 1024;
  MIN_CHARACTER_SPACING = -1024;
  MAX_CHARACTER_SPACING = 1024;

var
  RendererLock: TRTLCriticalSection;
  RendererInitialized: Boolean;
  RendererSkiaAcquired: Boolean;
  SkiaRenderer: TSkiaTextRenderer;

function ResolveRenderSize(Video: PFILTER_PROC_VIDEO; out Width, Height: Integer): Boolean;
begin
  Width := 0;
  Height := 0;
  if (Video = nil) or not Assigned(Video^.SetImageData) then
    Exit(False);

  if Video^.Object_ <> nil then
  begin
    Width := Video^.Object_^.Width;
    Height := Video^.Object_^.Height;
  end;
  if ((Width <= 0) or (Height <= 0)) and (Video^.Scene <> nil) then
  begin
    Width := Video^.Scene^.Width;
    Height := Video^.Scene^.Height;
  end;

  Result := (Width > 0) and (Height > 0) and
    (Width <= MAX_RENDER_DIMENSION) and (Height <= MAX_RENDER_DIMENSION);
end;

function DefaultLyricsRenderSettings: TLyricsRenderSettings;
begin
  Result.DisplayType := ldtKaraoke;
  Result.ColorFillMode := lcfSmooth;
  Result.ColorAfterMode := lcaKeep;
  Result.ColorBandSizePercent := 100;
  Result.CompletionRestoreProgress := 1;
  Result.SyncKind := lskColor;
  Result.SyncMotionID := 0;
  Result.HasSyncNoteEvent := False;
  Result.SyncNoteFirstUnit := 0;
  Result.SyncNoteUnitCount := 0;
  Result.SyncNoteProgress := 0;
  Result.AsyncHoldID := 0;
  Result.AsyncSpeed := 1;
  Result.SyncShape := 0;
  Result.SyncOffsetX := 0;
  Result.SyncOffsetY := 0;
  Result.Opacity := 1;
  Result.LayerOffsetX := 0;
  Result.LayerOffsetY := 0;
  Result.LayerScaleX := 1;
  Result.LayerScaleY := 1;
  Result.LayerRotationDegrees := 0;
  Result.LayerBlurRadius := 0;
  Result.LayerWipeDirection := 0;
  Result.LayerWipeProgress := 1;
  Result.EdgeSettings := Default(TLyricsEdgeSettings);
  Result.BaseFontName := 'Yu Gothic UI';
  Result.RubyFontName := 'Yu Gothic UI';
  Result.BaseBold := True;
  Result.BaseItalic := False;
  Result.BaseUnderline := False;
  Result.BaseStrikeOut := False;
  Result.RubyBold := True;
  Result.RubyItalic := False;
  Result.RubyUnderline := False;
  Result.RubyStrikeOut := False;
  Result.BaseFontHeight := DEFAULT_LYRIC_FONT_HEIGHT;
  Result.RubyFontHeight := DEFAULT_RUBY_FONT_HEIGHT;
  Result.RubyGapAdjustment := 0;
  Result.BaseCharacterSpacing := 0;
  Result.RubyCharacterSpacing := 0;
  Result.BeforeColor.R := 255;
  Result.BeforeColor.G := 255;
  Result.BeforeColor.B := 255;
  Result.BeforeColor.A := 255;
  Result.AfterColor.R := 0;
  Result.AfterColor.G := 255;
  Result.AfterColor.B := 255;
  Result.AfterColor.A := 255;
  Result.BeforeOutlineColor.A := 255;
  Result.BeforeOutlineColor.R := 0;
  Result.BeforeOutlineColor.G := 0;
  Result.BeforeOutlineColor.B := 0;
  Result.AfterOutlineColor := Result.BeforeOutlineColor;
  Result.BeforeShadowColor.A := 160;
  Result.BeforeShadowColor.R := 0;
  Result.BeforeShadowColor.G := 0;
  Result.BeforeShadowColor.B := 0;
  Result.AfterShadowColor := Result.BeforeShadowColor;
  Result.BeforeBlurColor.A := 255;
  Result.BeforeBlurColor.R := 0;
  Result.BeforeBlurColor.G := 0;
  Result.BeforeBlurColor.B := 0;
  Result.AfterBlurColor := Result.BeforeBlurColor;
  Result.OutlineEnabled := False;
  Result.OutlineWidth := 8;
  Result.OutlineBlur := 0;
  Result.ShadowEnabled := False;
  Result.ShadowOffsetX := 10;
  Result.ShadowOffsetY := 10;
  Result.ShadowBlur := 4;
  Result.ShadowSpread := 0;
  Result.SyncColor.A := 255;
  Result.SyncColor := Result.AfterColor;
end;

function LyricsColorToCardinal(const Color: TLyricsRenderColor): Cardinal;
begin
  Result := Color.R or (Cardinal(Color.G) shl 8) or
    (Cardinal(Color.B) shl 16);
end;

procedure InitializeLyricsRenderBuffer(Video: PFILTER_PROC_VIDEO;
  Buffer: PPIXEL_RGBA; PixelCount: NativeInt);
begin
  if (Buffer = nil) or (PixelCount <= 0) then
    Exit;
  if (Video <> nil) and Assigned(Video^.GetImageData) then
    Video^.GetImageData(Buffer)
  else
    FillChar(Buffer^, PixelCount * SizeOf(TPIXEL_RGBA), 0);
end;

function ResolvedStyleFromSettings(const Settings: TLyricsRenderSettings;
  Ruby: Boolean): TResolvedLyricsStyle;
begin
  if Ruby then
  begin
    Result.FontName := Settings.RubyFontName;
    Result.FontHeight := EnsureRange(Settings.RubyFontHeight,
      MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
    Result.FontStyle := Ord(Settings.RubyBold) or
      (Ord(Settings.RubyItalic) shl 1) or
      (Ord(Settings.RubyUnderline) shl 2) or
      (Ord(Settings.RubyStrikeOut) shl 3);
    Result.CharacterSpacing := EnsureRange(Settings.RubyCharacterSpacing,
      MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
  end
  else
  begin
    Result.FontName := Settings.BaseFontName;
    Result.FontHeight := EnsureRange(Settings.BaseFontHeight,
      MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
    Result.FontStyle := Ord(Settings.BaseBold) or
      (Ord(Settings.BaseItalic) shl 1) or
      (Ord(Settings.BaseUnderline) shl 2) or
      (Ord(Settings.BaseStrikeOut) shl 3);
    Result.CharacterSpacing := EnsureRange(Settings.BaseCharacterSpacing,
      MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
  end;
  Result.BeforeColor := LyricsColorToCardinal(Settings.BeforeColor);
  Result.AfterColor := LyricsColorToCardinal(Settings.AfterColor);
  Result.BeforeOpacity := Settings.BeforeColor.A;
  Result.AfterOpacity := Settings.AfterColor.A;
  Result.BeforeOutlineColor := LyricsColorToCardinal(
    Settings.BeforeOutlineColor);
  Result.AfterOutlineColor := LyricsColorToCardinal(
    Settings.AfterOutlineColor);
  Result.BeforeOutlineOpacity := Settings.BeforeOutlineColor.A;
  Result.AfterOutlineOpacity := Settings.AfterOutlineColor.A;
  Result.BeforeShadowColor := LyricsColorToCardinal(
    Settings.BeforeShadowColor);
  Result.AfterShadowColor := LyricsColorToCardinal(Settings.AfterShadowColor);
  Result.BeforeShadowOpacity := Settings.BeforeShadowColor.A;
  Result.AfterShadowOpacity := Settings.AfterShadowColor.A;
  Result.BeforeBlurColor := LyricsColorToCardinal(Settings.BeforeBlurColor);
  Result.AfterBlurColor := LyricsColorToCardinal(Settings.AfterBlurColor);
  Result.BeforeBlurOpacity := Settings.BeforeBlurColor.A;
  Result.AfterBlurOpacity := Settings.AfterBlurColor.A;
  Result.OutlineEnabled := Settings.OutlineEnabled;
  Result.OutlineWidth := EnsureRange(Settings.OutlineWidth,
    0.0, MAX_DISPLAY_OUTLINE_WIDTH);
  Result.OutlineBlur := EnsureRange(Settings.OutlineBlur,
    0.0, MAX_DISPLAY_DECORATION_BLUR);
  Result.ShadowEnabled := Settings.ShadowEnabled;
  Result.ShadowOffsetX := EnsureRange(Settings.ShadowOffsetX,
    -MAX_DISPLAY_SHADOW_OFFSET, MAX_DISPLAY_SHADOW_OFFSET);
  Result.ShadowOffsetY := EnsureRange(Settings.ShadowOffsetY,
    -MAX_DISPLAY_SHADOW_OFFSET, MAX_DISPLAY_SHADOW_OFFSET);
  Result.ShadowBlur := EnsureRange(Settings.ShadowBlur,
    0.0, MAX_DISPLAY_DECORATION_BLUR);
  Result.ShadowSpread := EnsureRange(Settings.ShadowSpread,
    0.0, MAX_DISPLAY_SHADOW_SPREAD);
end;

function UnitDisplayEffectFromType(
  DisplayType: TLyricsDisplayType): TLyricsUnitDisplayEffect;
begin
  case DisplayType of
    ldtUnitEmphasis:
      Result := ludeUnitEmphasis;
    ldtUnitReveal:
      Result := ludeUnitReveal;
  else
    Result := ludeKaraoke;
  end;
end;

function ResolveLyricsDisplayUnitProgress(const Units: TResolvedLyricsDisplayUnits;
  UnitIndex: Integer; ProgressUnits: Double): Double;
var
  I: Integer;
  IsLeading: Boolean;
begin
  if (UnitIndex < 0) or (UnitIndex >= Length(Units)) then
    Exit(0);
  if Units[UnitIndex].SyncUnitIndex < 0 then
    Exit(0);
  if not Units[UnitIndex].ConsumesNote then
  begin
    IsLeading := True;
    for I := 0 to UnitIndex - 1 do
      if Units[I].ConsumesNote then
      begin
        IsLeading := False;
        Break;
      end;
    if IsLeading then
      Exit(Ord(ProgressUnits > 0));
    Exit(Ord(ProgressUnits >= Units[UnitIndex].SyncUnitIndex + 1));
  end;
  Result := EnsureRange(ProgressUnits -
    Units[UnitIndex].SyncUnitIndex, 0.0, 1.0);
end;

function ResolveKaraokeColorProgress(UnitProgress: Double;
  const Settings: TLyricsRenderSettings): Double;
begin
  UnitProgress := EnsureRange(UnitProgress, 0.0, 1.0);
  if (Settings.ColorAfterMode = lcaRestore) and
    ((UnitProgress <= 0.000001) or (UnitProgress >= 0.999999)) then
    Exit(0);
  if (Settings.ColorFillMode = lcfCharacter) and (UnitProgress > 0) then
    Exit(1);
  Result := UnitProgress;
end;

procedure ResolveKaraokeColorClip(UnitProgress, ProgressUnits: Double;
  SyncUnitIndex, SyncUnitCount: Integer; const Settings: TLyricsRenderSettings;
  out ClipStart, ClipEnd: Double);
var
  CurrentIndex: Integer;
  CurrentProgress: Double;
  NormalizedProgress: Double;
  BandStart: Double;
  BandEnd: Double;
  UnitStart: Double;
begin
  ClipStart := 0;
  ClipEnd := 0;
  if ProgressUnits <= 0.000001 then
    Exit;
  if (Settings.ColorFillMode <> lcfSmooth) or
    (Settings.ColorAfterMode <> lcaRestore) then
  begin
    ClipEnd := ResolveKaraokeColorProgress(UnitProgress, Settings);
    Exit;
  end;

  if SyncUnitCount <= 0 then
    Exit;
  NormalizedProgress := EnsureRange(ProgressUnits / SyncUnitCount,
    0.0, 1.0);
  CalculateSerifSyncHighlightPosition(SyncUnitCount, NormalizedProgress,
    CurrentIndex, CurrentProgress);
  CalculateSerifSyncSmoothWindow(CurrentIndex, CurrentProgress,
    Settings.ColorBandSizePercent, BandStart, BandEnd);
  if ProgressUnits >= SyncUnitCount - 0.000001 then
    BandStart := BandStart + (BandEnd - BandStart) *
      EnsureRange(Settings.CompletionRestoreProgress, 0.0, 1.0);
  UnitStart := SyncUnitIndex;
  ClipStart := EnsureRange(BandStart - UnitStart, 0.0, 1.0);
  ClipEnd := EnsureRange(BandEnd - UnitStart, 0.0, 1.0);
  if ClipEnd <= ClipStart + 0.000001 then
  begin
    ClipStart := 0;
    ClipEnd := 0;
  end;
end;

function ResolveSerifSyncPhase(UnitSyncIndex, CurrentIndex: Integer;
  CurrentProgress: Double; const Settings: TLyricsRenderSettings): Double;
begin
  Result := 0;
  if CurrentIndex < 0 then
    Exit;
  if Settings.ColorFillMode = lcfCharacter then
  begin
    if Settings.ColorAfterMode = lcaKeep then
      Result := Ord(UnitSyncIndex <= CurrentIndex)
    else if (UnitSyncIndex = CurrentIndex) and (CurrentProgress < 1.0) then
      Result := 1;
    Exit;
  end;
  if Settings.ColorAfterMode = lcaKeep then
  begin
    if UnitSyncIndex < CurrentIndex then
      Result := 1
    else if UnitSyncIndex = CurrentIndex then
      Result := Sin(CurrentProgress * Pi * 0.5);
  end
  else if UnitSyncIndex = CurrentIndex then
    Result := Sin(CurrentProgress * Pi);
end;

procedure ApplySerifSyncTransform(UnitSyncIndex, CurrentIndex: Integer;
  CurrentProgress: Double; FontHeight: Integer;
  const Settings: TLyricsRenderSettings; var State: TLyricsUnitEffectState);
const
  SYNC_TRANSFORM_STRENGTH = 0.35;
var
  JumpHeight: Double;
  Phase: Double;
  Scale: Double;
begin
  if not ((Settings.SyncMotionID in [16, 17]) or
    (Settings.SyncKind in [lskZoom, lskJump])) then
    Exit;
  if (Settings.SyncMotionID in [16, 17]) and Settings.HasSyncNoteEvent then
  begin
    Phase := 0;
    if (UnitSyncIndex >= Settings.SyncNoteFirstUnit) and
      (UnitSyncIndex < Settings.SyncNoteFirstUnit + Settings.SyncNoteUnitCount) then
      Phase := Sin(EnsureRange(Settings.SyncNoteProgress, 0.0, 1.0) * Pi);
  end
  else
    Phase := ResolveSerifSyncPhase(UnitSyncIndex, CurrentIndex,
      CurrentProgress, Settings);
  if Phase <= 0 then
    Exit;
  // 同期サイズ100%を効果量の基準とし、倍率1.0や移動量0にしない。
  if (Settings.SyncMotionID = 16) or (Settings.SyncKind = lskZoom) then
  begin
    Scale := 1.0 + EnsureRange(Settings.ColorBandSizePercent,
      1.0, 1000.0) / 100.0 * SYNC_TRANSFORM_STRENGTH * Phase;
    State.ScaleX := State.ScaleX * Scale;
    State.ScaleY := State.ScaleY * Scale;
    State.OffsetX := State.OffsetX + Settings.SyncOffsetX * Phase;
    State.OffsetY := State.OffsetY + Settings.SyncOffsetY * Phase;
  end
  else
  begin
    JumpHeight := Max(1, FontHeight) *
      EnsureRange(Settings.ColorBandSizePercent, 1.0, 1000.0) / 100.0 *
      SYNC_TRANSFORM_STRENGTH;
    State.OffsetX := State.OffsetX + Settings.SyncOffsetX * Phase;
    State.OffsetY := State.OffsetY +
      (Settings.SyncOffsetY - JumpHeight) * Phase;
  end;
end;

type
  TPreparedLyricsPart = record
    AfterImage: TTextRenderImage;
    BeforeImage: TTextRenderImage;
    GlowImage: TTextRenderImage;
    AdvanceLeft: Single;
    AdvanceRight: Single;
    BaselineY: Single;
  end;
  TPreparedLyricsParts = TArray<TPreparedLyricsPart>;

function LyricsColorToAlphaColor(Color: Cardinal; Opacity: Byte): TAlphaColor;
begin
  Result := TAlphaColor((Cardinal(Opacity) shl 24) or
    ((Color and $000000FF) shl 16) or
    (Color and $0000FF00) or
    ((Color and $00FF0000) shr 16));
end;

function TextRenderFontStyle(Style: Byte): TTextRenderFontStyle;
begin
  Result := [];
  if (Style and 1) <> 0 then
    Include(Result, TTextRenderFontStyleItem.Bold);
  if (Style and 2) <> 0 then
    Include(Result, TTextRenderFontStyleItem.Italic);
  if (Style and 4) <> 0 then
    Include(Result, TTextRenderFontStyleItem.Underline);
  if (Style and 8) <> 0 then
    Include(Result, TTextRenderFontStyleItem.StrikeOut);
end;

procedure ResolvePreparedAdvance(var Part: TPreparedLyricsPart);
var
  I: Integer;
  OriginX: Single;
  SegmentLeft: Single;
  SegmentRight: Single;
begin
  Part.AdvanceLeft := 0;
  Part.AdvanceRight := 0;
  Part.BaselineY := 0;
  if (Part.BeforeImage = nil) or
    (Length(Part.BeforeImage.TextUnitOrigins) = 0) then
  begin
    if Part.BeforeImage <> nil then
    begin
      Part.AdvanceLeft := Part.BeforeImage.LayoutBounds.Left;
      Part.AdvanceRight := Part.BeforeImage.LayoutBounds.Right;
    end;
    Exit;
  end;
  Part.BaselineY := Part.BeforeImage.TextUnitOrigins[0].Y +
    Part.BeforeImage.Bounds.Top;
  for I := 0 to High(Part.BeforeImage.TextUnitOrigins) do
  begin
    OriginX := Part.BeforeImage.TextUnitOrigins[I].X +
      Part.BeforeImage.Bounds.Left;
    SegmentLeft := OriginX;
    SegmentRight := OriginX + Part.BeforeImage.TextUnitAdvances[I];
    if SegmentRight < SegmentLeft then
    begin
      OriginX := SegmentLeft;
      SegmentLeft := SegmentRight;
      SegmentRight := OriginX;
    end;
    if I = 0 then
    begin
      Part.AdvanceLeft := SegmentLeft;
      Part.AdvanceRight := SegmentRight;
    end
    else
    begin
      Part.AdvanceLeft := Min(Part.AdvanceLeft, SegmentLeft);
      Part.AdvanceRight := Max(Part.AdvanceRight, SegmentRight);
    end;
  end;
end;

procedure FreePreparedPart(var Part: TPreparedLyricsPart);
begin
  Part.AfterImage.Free;
  Part.BeforeImage.Free;
  Part.GlowImage.Free;
  Part := Default(TPreparedLyricsPart);
end;

procedure FreePreparedParts(var Parts: TPreparedLyricsParts);
var
  I: Integer;
begin
  for I := 0 to High(Parts) do
    FreePreparedPart(Parts[I]);
  Parts := nil;
end;

function PrepareLyricsPart(const Part: TResolvedLyricsPart;
  const Settings: TLyricsRenderSettings;
  out Prepared: TPreparedLyricsPart): Boolean;
var
  GlowColor: TAlphaColor;
  GlowScale: Double;
  Metrics: TTextRenderMetrics;
  Request: TTextRenderRequest;
  Shadow: TTextRenderShadow;

  procedure ApplyPalette(const BeforePhase: Boolean);
  var
    BlurColor: Cardinal;
    BlurOpacity: Byte;
    FillColor: Cardinal;
    FillOpacity: Byte;
    OutlineColor: Cardinal;
    OutlineOpacity: Byte;
    ShadowColor: Cardinal;
    ShadowOpacity: Byte;
  begin
    if BeforePhase then
    begin
      FillColor := Part.Style.BeforeColor;
      FillOpacity := Part.Style.BeforeOpacity;
      OutlineColor := Part.Style.BeforeOutlineColor;
      OutlineOpacity := Part.Style.BeforeOutlineOpacity;
      ShadowColor := Part.Style.BeforeShadowColor;
      ShadowOpacity := Part.Style.BeforeShadowOpacity;
      BlurColor := Part.Style.BeforeBlurColor;
      BlurOpacity := Part.Style.BeforeBlurOpacity;
    end
    else
    begin
      FillColor := Part.Style.AfterColor;
      FillOpacity := Part.Style.AfterOpacity;
      OutlineColor := Part.Style.AfterOutlineColor;
      OutlineOpacity := Part.Style.AfterOutlineOpacity;
      ShadowColor := Part.Style.AfterShadowColor;
      ShadowOpacity := Part.Style.AfterShadowOpacity;
      BlurColor := Part.Style.AfterBlurColor;
      BlurOpacity := Part.Style.AfterBlurOpacity;
    end;
    Request.FillColor := LyricsColorToAlphaColor(FillColor, FillOpacity);
    Request.Outlines := [];
    if Part.Style.OutlineEnabled and (Part.Style.OutlineWidth > 0) then
    begin
      if Part.Style.OutlineBlur <= 0 then
        Request.Outlines := [TTextRenderOutline.Create(
          Part.Style.OutlineWidth,
          LyricsColorToAlphaColor(OutlineColor, OutlineOpacity))]
      else if (BlurColor = OutlineColor) and (BlurOpacity = OutlineOpacity) then
        Request.Outlines := [TTextRenderOutline.Create(
          Part.Style.OutlineWidth, Part.Style.OutlineBlur,
          LyricsColorToAlphaColor(OutlineColor, OutlineOpacity))]
      else
        Request.Outlines := [
          TTextRenderOutline.Create(Part.Style.OutlineWidth,
            Part.Style.OutlineBlur,
            LyricsColorToAlphaColor(BlurColor, BlurOpacity)),
          TTextRenderOutline.Create(Part.Style.OutlineWidth,
            LyricsColorToAlphaColor(OutlineColor, OutlineOpacity))];
    end;
    Request.Shadows := [];
    if Part.Style.ShadowEnabled then
    begin
      Shadow := System.Default(TTextRenderShadow);
      Shadow.Offset := PointF(Part.Style.ShadowOffsetX,
        Part.Style.ShadowOffsetY);
      Shadow.BlurRadius := Part.Style.ShadowBlur;
      Shadow.SpreadRadius := Part.Style.ShadowSpread;
      Shadow.Color := LyricsColorToAlphaColor(ShadowColor, ShadowOpacity);
      Request.Shadows := [Shadow];
    end;
  end;
begin
  Prepared := Default(TPreparedLyricsPart);
  Result := Part.Text <> '';
  if not Result then
    Exit;
  Request := TTextRenderRequest.Default;
  Request.Text := Part.Text;
  Request.FontFamilies := [Part.Style.FontName, 'Yu Gothic UI', 'Meiryo UI',
    'Segoe UI'];
  Request.FontSize := EnsureRange(Part.Style.FontHeight,
    MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  Request.FontStyle := TextRenderFontStyle(Part.Style.FontStyle);
  Request.LetterSpacing := EnsureRange(Part.Style.CharacterSpacing,
    MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
  Request.CaptureTextUnits := True;
  ApplyPalette(True);
  try
    Prepared.BeforeImage := SkiaRenderer.Render(Request, Metrics);
    ApplyPalette(False);
    Prepared.AfterImage := SkiaRenderer.Render(Request, Metrics);
    if Settings.SyncKind = lskGlow then
    begin
      GlowScale := Sqrt(EnsureRange(Settings.ColorBandSizePercent,
        1.0, 1000.0) / 100.0);
      GlowColor := TAlphaColor($FF000000 or
        (Cardinal(Settings.SyncColor.R) shl 16) or
        (Cardinal(Settings.SyncColor.G) shl 8) or
        Cardinal(Settings.SyncColor.B));
      Request.FillColor := TAlphaColorRec.Null;
      Shadow := Default(TTextRenderShadow);
      Shadow.Offset := PointF(0, 0);
      Shadow.BlurRadius := Max(2.0,
        Part.Style.FontHeight * 0.12 * GlowScale);
      Shadow.SpreadRadius := Max(1.0,
        Part.Style.FontHeight * 0.06 * GlowScale);
      Shadow.Color := GlowColor;
      Request.Shadows := [Shadow];
      Request.Outlines := [TTextRenderOutline.Create(
        Max(2.0, Part.Style.FontHeight * 0.075 * GlowScale),
        Max(1.0, Part.Style.FontHeight * 0.025 * GlowScale),
        GlowColor)];
      Prepared.GlowImage := SkiaRenderer.Render(Request, Metrics);
    end;
    ResolvePreparedAdvance(Prepared);
    Result := True;
  except
    FreePreparedPart(Prepared);
    raise;
  end;
end;

procedure BlendStraightTextPixel(const Source: TTextRenderPixel;
  Opacity: Double; var Destination: TPIXEL_RGBA);
var
  AdjustedAlpha: Cardinal;
  AlphaDenominator: Cardinal;
  DestinationAlpha: Cardinal;
begin
  AdjustedAlpha := Round(Source.A * EnsureRange(Opacity, 0.0, 1.0));
  if AdjustedAlpha = 0 then
    Exit;
  if AdjustedAlpha = 255 then
  begin
    Destination.R := Source.R;
    Destination.G := Source.G;
    Destination.B := Source.B;
    Destination.A := 255;
    Exit;
  end;
  DestinationAlpha := Destination.A;
  AlphaDenominator := AdjustedAlpha * 255 +
    DestinationAlpha * (255 - AdjustedAlpha);
  if AlphaDenominator = 0 then
    Exit;
  Destination.R := (Cardinal(Source.R) * AdjustedAlpha * 255 +
    Cardinal(Destination.R) * DestinationAlpha * (255 - AdjustedAlpha) +
    AlphaDenominator div 2) div AlphaDenominator;
  Destination.G := (Cardinal(Source.G) * AdjustedAlpha * 255 +
    Cardinal(Destination.G) * DestinationAlpha * (255 - AdjustedAlpha) +
    AlphaDenominator div 2) div AlphaDenominator;
  Destination.B := (Cardinal(Source.B) * AdjustedAlpha * 255 +
    Cardinal(Destination.B) * DestinationAlpha * (255 - AdjustedAlpha) +
    AlphaDenominator div 2) div AlphaDenominator;
  Destination.A := (AlphaDenominator + 127) div 255;
end;

function IsSyncShapePixelVisible(X, Y, CenterX, CenterY, ShapeWidth,
  ShapeHeight, Shape: Integer): Boolean;
var
  DX: Double;
  DY: Double;
  HalfHeight: Double;
  HalfWidth: Double;
  LocalY: Double;
begin
  HalfWidth := Max(0.5, ShapeWidth * 0.5);
  HalfHeight := Max(0.5, ShapeHeight * 0.5);
  DX := (X + 0.5) - CenterX;
  DY := (Y + 0.5) - CenterY;
  case Shape of
    1:
      Result := Sqr(DX / HalfWidth) + Sqr(DY / HalfHeight) <= 1.0;
    3:
      begin
        LocalY := DY + HalfHeight;
        Result := (LocalY >= 0.0) and (LocalY <= ShapeHeight) and
          (Abs(DX) <= HalfWidth * LocalY / Max(1.0, ShapeHeight));
      end;
  else
    Result := True;
  end;
end;

procedure BlendSyncSolidPixel(const Settings: TLyricsRenderSettings;
  Alpha, Opacity: Double; var Destination: TPIXEL_RGBA);
var
  Source: TTextRenderPixel;
begin
  Source.R := Settings.SyncColor.R;
  Source.G := Settings.SyncColor.G;
  Source.B := Settings.SyncColor.B;
  Source.A := EnsureRange(Round(Alpha), 0, 255);
  BlendStraightTextPixel(Source, Opacity, Destination);
end;

procedure DrawSyncBacking(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  UnitLeft, UnitTop, UnitWidth, UnitHeight, ClipStart, ClipEnd,
  Phase: Double; const Settings: TLyricsRenderSettings);
var
  BoundsBottom: Integer;
  BoundsLeft: Integer;
  BoundsRight: Integer;
  BoundsTop: Integer;
  CenterX: Integer;
  CenterY: Integer;
  Destination: PPIXEL_RGBA;
  ShapeHeight: Integer;
  ShapeWidth: Integer;
  X: Integer;
  Y: Integer;
begin
  if (Settings.SyncKind <> lskBacking) or (Phase <= 0) then
    Exit;
  ShapeHeight := Max(1, Round(UnitHeight *
    Max(0.01, Settings.ColorBandSizePercent) / 100.0));
  CenterY := Round(UnitTop + UnitHeight * 0.5 + Settings.SyncOffsetY);
  if Settings.ColorFillMode = lcfCharacter then
  begin
    ShapeWidth := ShapeHeight;
    CenterX := Round(UnitLeft + UnitWidth * 0.5 + Settings.SyncOffsetX);
    BoundsLeft := CenterX - ShapeWidth div 2;
    BoundsRight := CenterX + (ShapeWidth + 1) div 2;
  end
  else
  begin
    BoundsLeft := Round(UnitLeft + UnitWidth * ClipStart +
      Settings.SyncOffsetX);
    BoundsRight := Round(UnitLeft + UnitWidth * ClipEnd +
      Settings.SyncOffsetX);
    ShapeWidth := Max(1, BoundsRight - BoundsLeft);
    CenterX := (BoundsLeft + BoundsRight) div 2;
  end;
  BoundsTop := CenterY - ShapeHeight div 2;
  BoundsBottom := CenterY + (ShapeHeight + 1) div 2;
  for Y := Max(0, BoundsTop) to Min(Height, BoundsBottom) - 1 do
    for X := Max(0, BoundsLeft) to Min(Width, BoundsRight) - 1 do
      if IsSyncShapePixelVisible(X, Y, CenterX, CenterY, ShapeWidth,
        ShapeHeight, Settings.SyncShape) then
      begin
        Destination := Buffer;
        Inc(Destination, NativeInt(Y) * Width + X);
        BlendSyncSolidPixel(Settings, 160,
          Phase * Settings.Opacity, Destination^);
      end;
end;

procedure DrawSyncUnderline(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  UnitLeft, UnitTop, UnitWidth, UnitHeight, ClipStart, ClipEnd,
  Phase: Double; const Settings: TLyricsRenderSettings);
var
  Bottom: Integer;
  CenterX: Integer;
  CenterY: Integer;
  Destination: PPIXEL_RGBA;
  Left: Integer;
  MarkerWidth: Integer;
  Right: Integer;
  Thickness: Integer;
  Top: Integer;
  X: Integer;
  Y: Integer;
begin
  if (Settings.SyncKind <> lskUnderline) or (Phase <= 0) then
    Exit;
  Thickness := Max(1, Round(Max(2.0, UnitHeight * 0.08) *
    Max(0.01, Settings.ColorBandSizePercent) / 100.0));
  if Settings.ColorFillMode = lcfCharacter then
  begin
    MarkerWidth := Max(1, Round(UnitWidth *
      Max(0.01, Settings.ColorBandSizePercent) / 100.0));
    CenterX := Round(UnitLeft + UnitWidth * 0.5 + Settings.SyncOffsetX);
    Left := CenterX - MarkerWidth div 2;
    Right := CenterX + (MarkerWidth + 1) div 2;
  end
  else
  begin
    Left := Round(UnitLeft + UnitWidth * ClipStart + Settings.SyncOffsetX);
    Right := Round(UnitLeft + UnitWidth * ClipEnd + Settings.SyncOffsetX);
    MarkerWidth := Max(1, Right - Left);
    CenterX := (Left + Right) div 2;
  end;
  CenterY := Round(UnitTop + UnitHeight + 2 + Thickness * 0.5 +
    Settings.SyncOffsetY);
  Top := CenterY - Thickness div 2;
  Bottom := CenterY + (Thickness + 1) div 2;
  for Y := Max(0, Top) to Min(Height, Bottom) - 1 do
    for X := Max(0, Left) to Min(Width, Right) - 1 do
      if IsSyncShapePixelVisible(X, Y, CenterX, CenterY, MarkerWidth,
        Thickness, Settings.SyncShape) then
      begin
        Destination := Buffer;
        Inc(Destination, NativeInt(Y) * Width + X);
        BlendSyncSolidPixel(Settings, 255,
          Phase * Settings.Opacity, Destination^);
      end;
end;

procedure DrawSyncFront(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  UnitLeft, UnitTop, UnitWidth, UnitHeight, ClipStart, ClipEnd,
  Phase: Double; const Settings: TLyricsRenderSettings);
var
  Blue: Integer;
  Destination: PPIXEL_RGBA;
  Green: Integer;
  Left: Integer;
  Red: Integer;
  Right: Integer;
  X: Integer;
  Y: Integer;
begin
  if (Settings.SyncKind <> lskFront) or (Phase <= 0) then
    Exit;
  if Settings.ColorFillMode = lcfCharacter then
  begin
    Left := Round(UnitLeft + Settings.SyncOffsetX);
    Right := Round(UnitLeft + UnitWidth + Settings.SyncOffsetX);
  end
  else
  begin
    Left := Round(UnitLeft + UnitWidth * ClipStart + Settings.SyncOffsetX);
    Right := Round(UnitLeft + UnitWidth * ClipEnd + Settings.SyncOffsetX);
  end;
  Phase := Phase * EnsureRange(Settings.Opacity, 0.0, 1.0);
  if Phase <= 0 then
    Exit;
  Red := Settings.SyncColor.R;
  Green := Settings.SyncColor.G;
  Blue := Settings.SyncColor.B;
  for Y := Max(0, Round(UnitTop + Settings.SyncOffsetY)) to
    Min(Height, Round(UnitTop + UnitHeight + Settings.SyncOffsetY)) - 1 do
    for X := Max(0, Left) to Min(Width, Right) - 1 do
    begin
      Destination := Buffer;
      Inc(Destination, NativeInt(Y) * Width + X);
      if Destination^.A = 0 then
        Continue;
      Destination^.R := EnsureRange(Round(Destination^.R +
        ((255 - Destination^.R) * Red / 255) * 0.56 * Phase), 0, 255);
      Destination^.G := EnsureRange(Round(Destination^.G +
        ((255 - Destination^.G) * Green / 255) * 0.56 * Phase), 0, 255);
      Destination^.B := EnsureRange(Round(Destination^.B +
        ((255 - Destination^.B) * Blue / 255) * 0.56 * Phase), 0, 255);
    end;
end;

procedure BlendPreparedImage(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Prepared: TPreparedLyricsPart; Image: TTextRenderImage;
  PivotX, PivotY, BaselineLocalX, BaselineLocalY, ScaleX, ScaleY,
  ClipStart, ClipEnd, Opacity: Double);
var
  ClipSourceLeft: Double;
  ClipSourceRight: Double;
  Destination: PPIXEL_RGBA;
  DestinationBottom: Integer;
  DestinationLeft: Integer;
  DestinationRight: Integer;
  DestinationTop: Integer;
  DestinationX: Integer;
  DestinationY: Integer;
  ImageLeft: Double;
  ImageTop: Double;
  Source: PTextRenderPixel;
  SourceX: Integer;
  SourceY: Integer;
begin
  if (Image = nil) or Image.IsEmpty or (Opacity <= 0) then
    Exit;
  ScaleX := EnsureRange(ScaleX, 0.01, 100.0);
  ScaleY := EnsureRange(ScaleY, 0.01, 100.0);
  ClipStart := EnsureRange(ClipStart, 0.0, 1.0);
  ClipEnd := EnsureRange(ClipEnd, 0.0, 1.0);
  if ClipEnd <= ClipStart then
    Exit;
  ImageLeft := PivotX + (BaselineLocalX + Image.Bounds.Left) * ScaleX;
  ImageTop := PivotY + (BaselineLocalY + Image.Bounds.Top) * ScaleY;
  DestinationLeft := Floor(ImageLeft);
  DestinationTop := Floor(ImageTop);
  DestinationRight := Ceil(ImageLeft + Image.Width * ScaleX);
  DestinationBottom := Ceil(ImageTop + Image.Height * ScaleY);
  if ClipStart <= 0 then
    ClipSourceLeft := 0
  else
    ClipSourceLeft := Prepared.AdvanceLeft - Image.Bounds.Left +
      (Prepared.AdvanceRight - Prepared.AdvanceLeft) * ClipStart;
  if ClipEnd >= 1 then
    ClipSourceRight := Image.Width
  else
    ClipSourceRight := Prepared.AdvanceLeft - Image.Bounds.Left +
      (Prepared.AdvanceRight - Prepared.AdvanceLeft) * ClipEnd;
  for DestinationY := Max(0, DestinationTop) to
    Min(Height, DestinationBottom) - 1 do
  begin
    SourceY := Floor(((DestinationY + 0.5) - ImageTop) / ScaleY);
    if (SourceY < 0) or (SourceY >= Image.Height) then
      Continue;
    for DestinationX := Max(0, DestinationLeft) to
      Min(Width, DestinationRight) - 1 do
    begin
      SourceX := Floor(((DestinationX + 0.5) - ImageLeft) / ScaleX);
      if (SourceX < 0) or (SourceX >= Image.Width) or
        (SourceX + 0.5 < ClipSourceLeft) or
        (SourceX + 0.5 > ClipSourceRight) then
        Continue;
      Source := PTextRenderPixel(PByte(Image.Data) +
        NativeInt(SourceY) * Image.Stride +
        NativeInt(SourceX) * SizeOf(TTextRenderPixel));
      if Source^.A = 0 then
        Continue;
      Destination := Buffer;
      Inc(Destination, NativeInt(DestinationY) * Width + DestinationX);
      BlendStraightTextPixel(Source^, Opacity, Destination^);
    end;
  end;
end;

procedure DrawPreparedPart(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Prepared: TPreparedLyricsPart; const State: TLyricsUnitEffectState;
  PivotX, PivotY, BaselineLocalX, BaselineLocalY, ScaleX, ScaleY,
  AfterClipStart, AfterClipEnd, GlowOpacity, GlowOffsetX, GlowOffsetY,
  Opacity: Double);
begin
  Opacity := Opacity * State.Opacity;
  if (Prepared.GlowImage <> nil) and (GlowOpacity > 0) then
    BlendPreparedImage(Buffer, Width, Height, Prepared,
      Prepared.GlowImage, PivotX + GlowOffsetX, PivotY + GlowOffsetY,
      BaselineLocalX, BaselineLocalY, ScaleX, ScaleY, 0, 1,
      Opacity * GlowOpacity);
  if State.DrawBefore then
    BlendPreparedImage(Buffer, Width, Height, Prepared,
      Prepared.BeforeImage, PivotX, PivotY, BaselineLocalX,
      BaselineLocalY, ScaleX, ScaleY, 0, 1, Opacity);
  if AfterClipEnd > AfterClipStart then
    BlendPreparedImage(Buffer, Width, Height, Prepared,
      Prepared.AfterImage, PivotX, PivotY, BaselineLocalX,
      BaselineLocalY, ScaleX, ScaleY, AfterClipStart, AfterClipEnd,
      Opacity);
end;

procedure IncludeLyricsImageBounds(var Bounds: TRect; Image: TTextRenderImage;
  PivotX, PivotY, BaselineLocalX, BaselineLocalY, ScaleX, ScaleY: Double);
var Left, Top: Double;
begin
  if (Image = nil) or Image.IsEmpty then Exit;
  ScaleX := EnsureRange(ScaleX, 0.01, 100.0);
  ScaleY := EnsureRange(ScaleY, 0.01, 100.0);
  Left := PivotX + (BaselineLocalX + Image.Bounds.Left) * ScaleX;
  Top := PivotY + (BaselineLocalY + Image.Bounds.Top) * ScaleY;
  Bounds.Left := Min(Bounds.Left, Floor(Left));
  Bounds.Top := Min(Bounds.Top, Floor(Top));
  Bounds.Right := Max(Bounds.Right, Ceil(Left + Image.Width * ScaleX));
  Bounds.Bottom := Max(Bounds.Bottom, Ceil(Top + Image.Height * ScaleY));
end;

procedure IncludeLyricsPartBounds(var Bounds: TRect;
  const Prepared: TPreparedLyricsPart; PivotX, PivotY, BaselineLocalX,
  BaselineLocalY, ScaleX, ScaleY, GlowOffsetX, GlowOffsetY: Double);
begin
  IncludeLyricsImageBounds(Bounds, Prepared.BeforeImage, PivotX, PivotY,
    BaselineLocalX, BaselineLocalY, ScaleX, ScaleY);
  IncludeLyricsImageBounds(Bounds, Prepared.AfterImage, PivotX, PivotY,
    BaselineLocalX, BaselineLocalY, ScaleX, ScaleY);
  IncludeLyricsImageBounds(Bounds, Prepared.GlowImage,
    PivotX + GlowOffsetX, PivotY + GlowOffsetY,
    BaselineLocalX, BaselineLocalY, ScaleX, ScaleY);
end;

procedure FinalizeLyricsUnitBounds(var Bounds: TRect; Width, Height: Integer;
  const Settings: TLyricsRenderSettings; FontHeight: Double);
var Padding: Integer;
begin
  // 同期色の図形と下線は字形画像より外側へ出るため、消去・合成領域へ含める。
  Padding := 16;
  if Settings.SyncKind in [lskBacking, lskFront, lskUnderline] then
    Padding := Max(Padding, Ceil(FontHeight *
      Max(1.0, Settings.ColorBandSizePercent) / 100.0) +
      Ceil(Max(Abs(Settings.SyncOffsetX), Abs(Settings.SyncOffsetY))) + 16);
  Bounds.Inflate(Padding, Padding);
  Bounds.Left := EnsureRange(Bounds.Left, 0, Width);
  Bounds.Right := EnsureRange(Bounds.Right, 0, Width);
  Bounds.Top := EnsureRange(Bounds.Top, 0, Height);
  Bounds.Bottom := EnsureRange(Bounds.Bottom, 0, Height);
end;

procedure ClearLyricsUnitLayer(Buffer: PPIXEL_RGBA; Width: Integer;
  const Bounds: TRect);
var Y: Integer;
begin
  if (Bounds.Right <= Bounds.Left) or (Bounds.Bottom <= Bounds.Top) then Exit;
  for Y := Bounds.Top to Bounds.Bottom - 1 do
    FillChar(PPIXEL_RGBA(PByte(Buffer) +
      (NativeInt(Y) * Width + Bounds.Left) * SizeOf(TPIXEL_RGBA))^,
      (Bounds.Right - Bounds.Left) * SizeOf(TPIXEL_RGBA), 0);
end;

procedure CompositeLyricsEdgeUnit(Destination, Source: PPIXEL_RGBA;
  Width, Height: Integer; const SourceRegion: TRect;
  const Motion: TMVMotion; UnitIndex, UnitCount: Integer); forward;

function NeedsLyricsUnitComposition(const Settings: TLyricsRenderSettings;
  ProgressUnits: Double): Boolean;
var
  NoteActive: Boolean;
begin
  NoteActive := (ProgressUnits > 0) and
    (Abs(Frac(ProgressUnits)) > 0.000001);
  if Settings.HasSyncNoteEvent then
    NoteActive := (Settings.SyncNoteProgress > 0.000001) and
      (Settings.SyncNoteProgress < 0.999999);
  Result := HasActiveLyricsEdgeAnimation(Settings.EdgeSettings) or
    ((Settings.AsyncHoldID <> 0) and (Settings.AsyncSpeed > 0)) or
    (NoteActive and ((Settings.SyncMotionID in [2, 3, 4, 9..14]) or
    (Settings.SyncKind in [lskBlink, lskGlitch])));
end;

function ResolveLyricsUnitMotion(const Settings: TLyricsRenderSettings;
  UnitIndex, UnitCount, UnitSyncIndex, CurrentSyncIndex: Integer;
  CurrentSyncProgress: Double; ConsumesNote: Boolean): TMVMotion;
var
  Descriptor: TMVAnimationDescriptor;
  Input: TMVAnimationInput;
  DisplayHoldID: Integer;
  NoteActive: Boolean;
  NoteProgress: Double;
begin
  Result := ResolveLyricsEdgeMotion(Settings.EdgeSettings, UnitIndex, UnitCount);
  Input := Default(TMVAnimationInput);
  Input.Amount := 60;
  Input.Strength := 1;
  Input.Envelope := 1;
  Input.UnitIndex := UnitIndex;
  if (Settings.AsyncHoldID <> 0) and (Settings.AsyncSpeed > 0) and
    FindMVAnimation(makHold, Settings.AsyncHoldID, Descriptor) and
    Assigned(Descriptor.Evaluate) then
  begin
    Input.Phase := Settings.EdgeSettings.LocalSeconds *
      Settings.AsyncSpeed * 2 * Pi;
    Descriptor.Evaluate(Result, Input);
  end;
  NoteActive := ConsumesNote and (UnitSyncIndex = CurrentSyncIndex);
  NoteProgress := CurrentSyncProgress;
  if Settings.HasSyncNoteEvent then
  begin
    NoteActive := ConsumesNote and
      (UnitSyncIndex >= Settings.SyncNoteFirstUnit) and
      (UnitSyncIndex < Settings.SyncNoteFirstUnit + Settings.SyncNoteUnitCount);
    NoteProgress := Settings.SyncNoteProgress;
  end;
  if not NoteActive or (NoteProgress <= 0) or (NoteProgress >= 1) then Exit;
  Input.Amount := EnsureRange(Settings.ColorBandSizePercent, 1.0, 1000.0) * 0.6;
  Input.Phase := NoteProgress * 2 * Pi;
  Input.Envelope := Sin(NoteProgress * Pi);
  if (Settings.SyncMotionID in [2, 3, 4, 9..14]) and
    FindMVAnimation(makHold, Settings.SyncMotionID, Descriptor) and
    Assigned(Descriptor.Evaluate) then
    Descriptor.Evaluate(Result, Input);
  DisplayHoldID := 0;
  case Settings.SyncKind of
    lskBlink: DisplayHoldID := 5;
    lskGlitch: DisplayHoldID := 15;
  end;
  if (DisplayHoldID <> 0) and
    FindMVAnimation(makHold, DisplayHoldID, Descriptor) and
    Assigned(Descriptor.Evaluate) then
    Descriptor.Evaluate(Result, Input);
end;

procedure DrawSkiaLineLyrics(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Source: string; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings; PositionX, PositionY: Integer);
var
  AfterClipEnd: Double;
  AfterClipStart: Double;
  AnyRuby: Boolean;
  BaseBaselineX: Double;
  BaseBaselineY: Double;
  BaseLayoutBottom: Double;
  BaseLayoutTop: Double;
  BaseLeft: Double;
  BasePivotX: Double;
  BasePivotY: Double;
  BaseTop: Double;
  BaseUnitLefts: TArray<Double>;
  BaseUnitWidths: TArray<Double>;
  CurrentSyncIndex: Integer;
  CurrentSyncProgress: Double;
  DefaultBaseStyle: TResolvedLyricsStyle;
  DefaultRubyStyle: TResolvedLyricsStyle;
  Effect: TLyricsUnitDisplayEffect;
  EdgeActive: Boolean;
  EdgeMotion: TMVMotion;
  EmptyPlacements: TDisplayPlacementItems;
  Gap: Double;
  GlowOpacity: Double;
  HasBaseLayout: Boolean;
  HasRubyLayout: Boolean;
  LogicalUnits: TLyricsDisplayUnits;
  PlainText: string;
  PreparedBase: TPreparedLyricsParts;
  PreparedRuby: TPreparedLyricsParts;
  ResolvedUnits: TResolvedLyricsDisplayUnits;
  RubyBaselineX: Double;
  RubyBaselineY: Double;
  RubyLayoutTop: Double;
  RubySpans: TLyricsRubySpans;
  RubyTop: Double;
  RubyLeft: Double;
  RubyWidth: Double;
  State: TLyricsUnitEffectState;
  TargetBuffer: PPIXEL_RGBA;
  UnitBounds: TRect;
  UnitLayer: PPIXEL_RGBA;
  SyncEffectBottom: Double;
  SyncEffectHeight: Double;
  SyncEffectLeft: Double;
  SyncEffectRight: Double;
  SyncEffectTop: Double;
  SyncEffectWidth: Double;
  SyncPhase: Double;
  SyncUnitCount: Integer;
  TotalBaseWidth: Double;
  UnitIndex: Integer;
  UnitProgress: Double;
begin
  DefaultBaseStyle := ResolvedStyleFromSettings(Settings, False);
  DefaultRubyStyle := ResolvedStyleFromSettings(Settings, True);
  if not BuildResolvedLyricsDisplayUnits(Source, DefaultBaseStyle,
    DefaultRubyStyle, EmptyPlacements, False, PlainText, RubySpans,
    LogicalUnits, ResolvedUnits) then
    Exit;
  SetLength(PreparedBase, Length(ResolvedUnits));
  SetLength(PreparedRuby, Length(ResolvedUnits));
  SetLength(BaseUnitLefts, Length(ResolvedUnits));
  SetLength(BaseUnitWidths, Length(ResolvedUnits));
  EdgeActive := NeedsLyricsUnitComposition(Settings, ProgressUnits);
  UnitLayer := nil;
  if EdgeActive then
  begin
    GetMem(UnitLayer, NativeInt(Width) * Height * SizeOf(TPIXEL_RGBA));
    FillChar(UnitLayer^, NativeInt(Width) * Height * SizeOf(TPIXEL_RGBA), 0);
  end;
  if EdgeActive then TargetBuffer := UnitLayer else TargetBuffer := Buffer;
  try
    TotalBaseWidth := 0;
    AnyRuby := False;
    HasBaseLayout := False;
    HasRubyLayout := False;
    BaseLayoutTop := 0;
    BaseLayoutBottom := 0;
    RubyLayoutTop := 0;
    for UnitIndex := 0 to High(ResolvedUnits) do
    begin
      if not PrepareLyricsPart(ResolvedUnits[UnitIndex].Base, Settings,
        PreparedBase[UnitIndex]) then
        Continue;
      BaseUnitWidths[UnitIndex] := Max(0,
        PreparedBase[UnitIndex].AdvanceRight -
        PreparedBase[UnitIndex].AdvanceLeft);
      if UnitIndex > 0 then
        TotalBaseWidth := TotalBaseWidth +
          ResolvedUnits[UnitIndex].Base.Style.CharacterSpacing;
      BaseUnitLefts[UnitIndex] := TotalBaseWidth;
      TotalBaseWidth := TotalBaseWidth + BaseUnitWidths[UnitIndex];
      if not HasBaseLayout then
      begin
        BaseLayoutTop := PreparedBase[UnitIndex].BeforeImage.LayoutBounds.Top -
          PreparedBase[UnitIndex].BaselineY;
        BaseLayoutBottom :=
          PreparedBase[UnitIndex].BeforeImage.LayoutBounds.Bottom -
          PreparedBase[UnitIndex].BaselineY;
        HasBaseLayout := True;
      end
      else
      begin
        BaseLayoutTop := Min(BaseLayoutTop,
          PreparedBase[UnitIndex].BeforeImage.LayoutBounds.Top -
          PreparedBase[UnitIndex].BaselineY);
        BaseLayoutBottom := Max(BaseLayoutBottom,
          PreparedBase[UnitIndex].BeforeImage.LayoutBounds.Bottom -
          PreparedBase[UnitIndex].BaselineY);
      end;
      if ResolvedUnits[UnitIndex].HasRuby then
      begin
        AnyRuby := True;
        PrepareLyricsPart(ResolvedUnits[UnitIndex].Ruby, Settings,
          PreparedRuby[UnitIndex]);
        if not HasRubyLayout then
        begin
          RubyLayoutTop :=
            PreparedRuby[UnitIndex].BeforeImage.LayoutBounds.Top -
            PreparedRuby[UnitIndex].BaselineY;
          HasRubyLayout := True;
        end
        else
          RubyLayoutTop := Min(RubyLayoutTop,
            PreparedRuby[UnitIndex].BeforeImage.LayoutBounds.Top -
            PreparedRuby[UnitIndex].BaselineY);
      end;
    end;
    Gap := EnsureRange(DEFAULT_RUBY_GAP + Settings.RubyGapAdjustment,
      MIN_RUBY_GAP, MAX_RUBY_GAP);
    SyncUnitCount := 0;
    for UnitIndex := 0 to High(ResolvedUnits) do
      SyncUnitCount := Max(SyncUnitCount,
        ResolvedUnits[UnitIndex].SyncUnitIndex + 1);
    CurrentSyncIndex := -1;
    CurrentSyncProgress := 0;
    if ProgressUnits > 0.000001 then
      CalculateSerifSyncHighlightPosition(SyncUnitCount,
        EnsureRange(ProgressUnits / Max(1, SyncUnitCount), 0.0, 1.0),
        CurrentSyncIndex, CurrentSyncProgress);
    if AnyRuby then
      BaseTop := (Height - (Settings.RubyFontHeight + Gap +
        Settings.BaseFontHeight)) * 0.5 + Settings.RubyFontHeight + Gap +
        PositionY
    else
      BaseTop := (Height - Settings.BaseFontHeight) * 0.5 + PositionY;
    RubyTop := BaseTop - Gap - Settings.RubyFontHeight;
    if HasBaseLayout then
      BaseBaselineY := BaseTop - BaseLayoutTop
    else
      BaseBaselineY := BaseTop;
    if HasRubyLayout then
      RubyBaselineY := RubyTop - RubyLayoutTop
    else
      RubyBaselineY := RubyTop;
    Effect := UnitDisplayEffectFromType(Settings.DisplayType);
    for UnitIndex := 0 to High(ResolvedUnits) do
    begin
      UnitProgress := ResolveLyricsDisplayUnitProgress(ResolvedUnits, UnitIndex,
        ProgressUnits);
      ResolveLyricsUnitEffect(Effect, UnitProgress, State);
      SyncPhase := 0;
      if ResolvedUnits[UnitIndex].ConsumesNote then
      begin
        ApplySerifSyncTransform(ResolvedUnits[UnitIndex].SyncUnitIndex,
          CurrentSyncIndex, CurrentSyncProgress,
          ResolvedUnits[UnitIndex].Base.Style.FontHeight, Settings, State);
        SyncPhase := ResolveSerifSyncPhase(
          ResolvedUnits[UnitIndex].SyncUnitIndex, CurrentSyncIndex,
          CurrentSyncProgress, Settings);
      end;
      GlowOpacity := 0;
      if Settings.SyncKind = lskGlow then
        GlowOpacity := SyncPhase *
          Min(1.0, Sqrt(EnsureRange(Settings.ColorBandSizePercent,
            1.0, 1000.0) / 100.0));
      AfterClipStart := 0;
      AfterClipEnd := State.AfterProgress;
      if Settings.DisplayType = ldtKaraoke then
        if ResolvedUnits[UnitIndex].ConsumesNote then
          ResolveKaraokeColorClip(UnitProgress, ProgressUnits,
            ResolvedUnits[UnitIndex].SyncUnitIndex, SyncUnitCount, Settings,
            AfterClipStart, AfterClipEnd)
        else
          AfterClipEnd := ResolveKaraokeColorProgress(UnitProgress, Settings);
      BaseLeft := (Width - TotalBaseWidth) * 0.5 + PositionX +
        BaseUnitLefts[UnitIndex];
      BaseBaselineX := BaseLeft - PreparedBase[UnitIndex].AdvanceLeft;
      BasePivotX := BaseLeft + BaseUnitWidths[UnitIndex] * 0.5;
      // 拡大しても本文の底辺が動かないよう、表示単位の下端を変形基準にする。
      BasePivotY := BaseBaselineY + BaseLayoutBottom;
      UnitBounds := Rect(Floor(BaseLeft), Floor(BaseTop),
        Ceil(BaseLeft + BaseUnitWidths[UnitIndex]),
        Ceil(BaseTop + ResolvedUnits[UnitIndex].Base.Style.FontHeight));
      SyncEffectLeft := BaseLeft;
      SyncEffectRight := BaseLeft + BaseUnitWidths[UnitIndex];
      SyncEffectTop := BaseTop;
      SyncEffectBottom := BaseTop +
        ResolvedUnits[UnitIndex].Base.Style.FontHeight;
      if ResolvedUnits[UnitIndex].HasRuby then
      begin
        RubyWidth := Max(0, PreparedRuby[UnitIndex].AdvanceRight -
          PreparedRuby[UnitIndex].AdvanceLeft);
        RubyLeft := BaseLeft + (BaseUnitWidths[UnitIndex] - RubyWidth) * 0.5;
        RubyBaselineX := RubyLeft - PreparedRuby[UnitIndex].AdvanceLeft;
        SyncEffectLeft := Min(SyncEffectLeft, RubyLeft);
        SyncEffectRight := Max(SyncEffectRight, RubyLeft + RubyWidth);
        SyncEffectTop := Min(SyncEffectTop, RubyTop);
        SyncEffectBottom := Max(SyncEffectBottom, RubyTop +
          ResolvedUnits[UnitIndex].Ruby.Style.FontHeight);
      end;
      SyncEffectWidth := SyncEffectRight - SyncEffectLeft;
      SyncEffectHeight := SyncEffectBottom - SyncEffectTop;
      DrawSyncBacking(TargetBuffer, Width, Height, SyncEffectLeft,
        SyncEffectTop, SyncEffectWidth, SyncEffectHeight,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
      DrawPreparedPart(TargetBuffer, Width, Height, PreparedBase[UnitIndex], State,
        BasePivotX + State.OffsetX, BasePivotY + State.OffsetY,
        BaseBaselineX - BasePivotX,
        BaseBaselineY - BasePivotY, State.ScaleX, State.ScaleY,
        AfterClipStart, AfterClipEnd, GlowOpacity,
        Settings.SyncOffsetX, Settings.SyncOffsetY, Settings.Opacity);
      if EdgeActive then
        IncludeLyricsPartBounds(UnitBounds, PreparedBase[UnitIndex],
          BasePivotX + State.OffsetX, BasePivotY + State.OffsetY,
          BaseBaselineX - BasePivotX, BaseBaselineY - BasePivotY,
          State.ScaleX, State.ScaleY, Settings.SyncOffsetX,
          Settings.SyncOffsetY);
      if ResolvedUnits[UnitIndex].HasRuby then
      begin
        DrawPreparedPart(TargetBuffer, Width, Height, PreparedRuby[UnitIndex], State,
          BasePivotX + State.OffsetX, BasePivotY + State.OffsetY,
          RubyBaselineX - BasePivotX,
          RubyBaselineY - BasePivotY, State.ScaleX, State.ScaleY,
          AfterClipStart, AfterClipEnd, GlowOpacity,
          Settings.SyncOffsetX, Settings.SyncOffsetY, Settings.Opacity);
        if EdgeActive then
          IncludeLyricsPartBounds(UnitBounds, PreparedRuby[UnitIndex],
            BasePivotX + State.OffsetX, BasePivotY + State.OffsetY,
            RubyBaselineX - BasePivotX, RubyBaselineY - BasePivotY,
            State.ScaleX, State.ScaleY, Settings.SyncOffsetX,
            Settings.SyncOffsetY);
      end;
      DrawSyncFront(TargetBuffer, Width, Height, SyncEffectLeft, SyncEffectTop,
        SyncEffectWidth, SyncEffectHeight, AfterClipStart,
        AfterClipEnd, SyncPhase, Settings);
      DrawSyncUnderline(TargetBuffer, Width, Height, BaseLeft, BaseTop,
        BaseUnitWidths[UnitIndex],
        ResolvedUnits[UnitIndex].Base.Style.FontHeight,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
      if EdgeActive then
      begin
        FinalizeLyricsUnitBounds(UnitBounds, Width, Height, Settings,
          Max(ResolvedUnits[UnitIndex].Base.Style.FontHeight,
          Settings.RubyFontHeight));
        EdgeMotion := ResolveLyricsUnitMotion(Settings, UnitIndex,
          Length(ResolvedUnits), ResolvedUnits[UnitIndex].SyncUnitIndex,
          CurrentSyncIndex, CurrentSyncProgress,
          ResolvedUnits[UnitIndex].ConsumesNote);
        CompositeLyricsEdgeUnit(Buffer, UnitLayer, Width, Height,
          UnitBounds, EdgeMotion, UnitIndex, Length(ResolvedUnits));
        ClearLyricsUnitLayer(UnitLayer, Width, UnitBounds);
      end;
    end;
  finally
    if UnitLayer <> nil then FreeMem(UnitLayer);
    FreePreparedParts(PreparedRuby);
    FreePreparedParts(PreparedBase);
  end;
end;

procedure DrawSkiaFreePlacementLyrics(Buffer: PPIXEL_RGBA;
  Width, Height: Integer; const Source: string; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  const Placements: TDisplayPlacementItems;
  PositionX, PositionY: Integer);
var
  AfterClipEnd: Double;
  AfterClipStart: Double;
  BaseBaselineX: Double;
  BaseBaselineY: Double;
  BaseBottom: Double;
  BaseTop: Double;
  CurrentSyncIndex: Integer;
  CurrentSyncProgress: Double;
  DefaultBaseStyle: TResolvedLyricsStyle;
  DefaultRubyStyle: TResolvedLyricsStyle;
  EdgeActive: Boolean;
  EdgeMotion: TMVMotion;
  Effect: TLyricsUnitDisplayEffect;
  GlowOpacity: Double;
  LogicalUnits: TLyricsDisplayUnits;
  PlainText: string;
  PreparedBase: TPreparedLyricsPart;
  PreparedRuby: TPreparedLyricsPart;
  ResolvedUnits: TResolvedLyricsDisplayUnits;
  RubyBaselineX: Double;
  RubyBaselineY: Double;
  RubyAnchorY: Double;
  RubyGap: Double;
  RubySpans: TLyricsRubySpans;
  RubyLeft: Double;
  RubyTop: Double;
  RubyWidth: Double;
  RubyScaleX: Double;
  RubyScaleY: Double;
  ScaleX: Double;
  ScaleY: Double;
  State: TLyricsUnitEffectState;
  TargetBuffer: PPIXEL_RGBA;
  UnitBounds: TRect;
  UnitLayer: PPIXEL_RGBA;
  SyncEffectBottom: Double;
  SyncEffectHeight: Double;
  SyncEffectLeft: Double;
  SyncEffectRight: Double;
  SyncEffectTop: Double;
  SyncEffectWidth: Double;
  SyncPhase: Double;
  SyncUnitCount: Integer;
  UnitIndex: Integer;
  UnitProgress: Double;
  PivotX: Double;
  PivotY: Double;
  PlacementScaleX: Double;
  PlacementScaleY: Double;
  TransformPivotY: Double;
begin
  DefaultBaseStyle := ResolvedStyleFromSettings(Settings, False);
  DefaultRubyStyle := ResolvedStyleFromSettings(Settings, True);
  if not BuildResolvedLyricsDisplayUnits(Source, DefaultBaseStyle,
    DefaultRubyStyle, Placements, True, PlainText, RubySpans,
    LogicalUnits, ResolvedUnits) then
    Exit;
  EdgeActive := NeedsLyricsUnitComposition(Settings, ProgressUnits);
  UnitLayer := nil;
  if EdgeActive then
  begin
    GetMem(UnitLayer, NativeInt(Width) * Height * SizeOf(TPIXEL_RGBA));
    FillChar(UnitLayer^, NativeInt(Width) * Height * SizeOf(TPIXEL_RGBA), 0);
  end;
  if EdgeActive then TargetBuffer := UnitLayer else TargetBuffer := Buffer;
  try
  RubyGap := EnsureRange(DEFAULT_RUBY_GAP + Settings.RubyGapAdjustment,
    MIN_RUBY_GAP, MAX_RUBY_GAP);
  SyncUnitCount := 0;
  for UnitIndex := 0 to High(ResolvedUnits) do
    SyncUnitCount := Max(SyncUnitCount,
      ResolvedUnits[UnitIndex].SyncUnitIndex + 1);
  CurrentSyncIndex := -1;
  CurrentSyncProgress := 0;
  if ProgressUnits > 0.000001 then
    CalculateSerifSyncHighlightPosition(SyncUnitCount,
      EnsureRange(ProgressUnits / Max(1, SyncUnitCount), 0.0, 1.0),
      CurrentSyncIndex, CurrentSyncProgress);
  Effect := UnitDisplayEffectFromType(Settings.DisplayType);
  for UnitIndex := 0 to High(ResolvedUnits) do
  begin
    PreparedBase := Default(TPreparedLyricsPart);
    PreparedRuby := Default(TPreparedLyricsPart);
    try
      if not PrepareLyricsPart(ResolvedUnits[UnitIndex].Base, Settings,
        PreparedBase) then
        Continue;
      if ResolvedUnits[UnitIndex].HasRuby then
        PrepareLyricsPart(ResolvedUnits[UnitIndex].Ruby, Settings,
          PreparedRuby);
      UnitProgress := ResolveLyricsDisplayUnitProgress(ResolvedUnits, UnitIndex,
        ProgressUnits);
      ResolveLyricsUnitEffect(Effect, UnitProgress, State);
      SyncPhase := 0;
      if ResolvedUnits[UnitIndex].ConsumesNote then
      begin
        ApplySerifSyncTransform(ResolvedUnits[UnitIndex].SyncUnitIndex,
          CurrentSyncIndex, CurrentSyncProgress,
          ResolvedUnits[UnitIndex].Base.Style.FontHeight, Settings, State);
        SyncPhase := ResolveSerifSyncPhase(
          ResolvedUnits[UnitIndex].SyncUnitIndex, CurrentSyncIndex,
          CurrentSyncProgress, Settings);
      end;
      GlowOpacity := 0;
      if Settings.SyncKind = lskGlow then
        GlowOpacity := SyncPhase *
          Min(1.0, Sqrt(EnsureRange(Settings.ColorBandSizePercent,
            1.0, 1000.0) / 100.0));
      AfterClipStart := 0;
      AfterClipEnd := State.AfterProgress;
      if Settings.DisplayType = ldtKaraoke then
        if ResolvedUnits[UnitIndex].ConsumesNote then
          ResolveKaraokeColorClip(UnitProgress, ProgressUnits,
            ResolvedUnits[UnitIndex].SyncUnitIndex, SyncUnitCount, Settings,
            AfterClipStart, AfterClipEnd)
        else
          AfterClipEnd := ResolveKaraokeColorProgress(UnitProgress, Settings);
      PivotX := Width * 0.5 + ResolvedUnits[UnitIndex].X + PositionX;
      PivotY := Height * 0.5 + ResolvedUnits[UnitIndex].Y + PositionY;
      PlacementScaleX := ResolvedUnits[UnitIndex].ScaleX;
      PlacementScaleY := ResolvedUnits[UnitIndex].ScaleY;
      ScaleX := PlacementScaleX * State.ScaleX;
      ScaleY := PlacementScaleY * State.ScaleY;
      BaseTop := -PreparedBase.BeforeImage.LayoutBounds.Height * 0.5;
      BaseBottom := BaseTop +
        PreparedBase.BeforeImage.LayoutBounds.Height;
      TransformPivotY := PivotY + BaseBottom * PlacementScaleY;
      BaseBaselineX := -(PreparedBase.AdvanceLeft +
        PreparedBase.AdvanceRight) * 0.5;
      BaseBaselineY := BaseTop - PreparedBase.BeforeImage.LayoutBounds.Top;
      SyncEffectWidth := Max(0, PreparedBase.AdvanceRight -
        PreparedBase.AdvanceLeft) * ScaleX;
      SyncEffectHeight := ResolvedUnits[UnitIndex].Base.Style.FontHeight *
        ScaleY;
      SyncEffectLeft := PivotX - SyncEffectWidth * 0.5;
      SyncEffectTop := PivotY + BaseTop * ScaleY;
      SyncEffectRight := SyncEffectLeft + SyncEffectWidth;
      SyncEffectBottom := SyncEffectTop + SyncEffectHeight;
      UnitBounds := Rect(Floor(SyncEffectLeft), Floor(SyncEffectTop),
        Ceil(SyncEffectLeft + SyncEffectWidth),
        Ceil(SyncEffectTop + SyncEffectHeight));
      RubyScaleX := 1;
      RubyScaleY := 1;
      if ResolvedUnits[UnitIndex].HasRuby then
      begin
        RubyScaleX := ResolvedUnits[UnitIndex].Ruby.ScaleX;
        RubyScaleY := ResolvedUnits[UnitIndex].Ruby.ScaleY;
        RubyTop := BaseTop - RubyGap +
          ResolvedUnits[UnitIndex].Ruby.OffsetY;
        RubyBaselineX := -(PreparedRuby.AdvanceLeft +
          PreparedRuby.AdvanceRight) * 0.5 +
          ResolvedUnits[UnitIndex].Ruby.OffsetX / RubyScaleX;
        RubyBaselineY := RubyTop -
          PreparedRuby.BeforeImage.LayoutBounds.Bottom;
        RubyAnchorY := RubyTop +
          ResolvedUnits[UnitIndex].Ruby.Style.FontHeight * 0.5;
        RubyBaselineY := RubyBaselineY +
          (RubyAnchorY - BaseBottom) * (1 / RubyScaleY - 1);
        RubyWidth := Max(0, PreparedRuby.AdvanceRight -
          PreparedRuby.AdvanceLeft) * ScaleX * RubyScaleX;
        RubyLeft := PivotX + (RubyBaselineX +
          PreparedRuby.AdvanceLeft) * ScaleX * RubyScaleX;
        SyncEffectLeft := Min(SyncEffectLeft, RubyLeft);
        SyncEffectRight := Max(SyncEffectRight, RubyLeft + RubyWidth);
        SyncEffectTop := Min(SyncEffectTop, PivotY +
          (RubyAnchorY + (RubyTop - RubyAnchorY) * RubyScaleY) * ScaleY);
        SyncEffectBottom := Max(SyncEffectBottom, PivotY +
          (RubyAnchorY + (RubyTop +
          ResolvedUnits[UnitIndex].Ruby.Style.FontHeight - RubyAnchorY) *
          RubyScaleY) * ScaleY);
        SyncEffectWidth := SyncEffectRight - SyncEffectLeft;
        SyncEffectHeight := SyncEffectBottom - SyncEffectTop;
      end;
      DrawSyncBacking(TargetBuffer, Width, Height, SyncEffectLeft,
        SyncEffectTop, SyncEffectWidth, SyncEffectHeight,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
      DrawPreparedPart(TargetBuffer, Width, Height, PreparedBase, State,
        PivotX + State.OffsetX, TransformPivotY + State.OffsetY,
        BaseBaselineX, BaseBaselineY - BaseBottom, ScaleX, ScaleY,
        AfterClipStart, AfterClipEnd, GlowOpacity,
        Settings.SyncOffsetX, Settings.SyncOffsetY, Settings.Opacity);
      if EdgeActive then
        IncludeLyricsPartBounds(UnitBounds, PreparedBase,
          PivotX + State.OffsetX, TransformPivotY + State.OffsetY,
          BaseBaselineX, BaseBaselineY - BaseBottom, ScaleX, ScaleY,
          Settings.SyncOffsetX, Settings.SyncOffsetY);
      if ResolvedUnits[UnitIndex].HasRuby then
      begin
        DrawPreparedPart(TargetBuffer, Width, Height, PreparedRuby, State,
          PivotX + State.OffsetX, TransformPivotY + State.OffsetY,
          RubyBaselineX, RubyBaselineY - BaseBottom,
          ScaleX * RubyScaleX, ScaleY * RubyScaleY,
          AfterClipStart, AfterClipEnd, GlowOpacity,
          Settings.SyncOffsetX, Settings.SyncOffsetY, Settings.Opacity);
        if EdgeActive then
          IncludeLyricsPartBounds(UnitBounds, PreparedRuby,
            PivotX + State.OffsetX, TransformPivotY + State.OffsetY,
            RubyBaselineX, RubyBaselineY - BaseBottom,
            ScaleX * RubyScaleX, ScaleY * RubyScaleY,
            Settings.SyncOffsetX, Settings.SyncOffsetY);
      end;
      DrawSyncFront(TargetBuffer, Width, Height, SyncEffectLeft,
        SyncEffectTop, SyncEffectWidth, SyncEffectHeight,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
      DrawSyncUnderline(TargetBuffer, Width, Height, SyncEffectLeft,
        PivotY + BaseTop * ScaleY, SyncEffectWidth,
        ResolvedUnits[UnitIndex].Base.Style.FontHeight * ScaleY,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
      if EdgeActive then
      begin
        FinalizeLyricsUnitBounds(UnitBounds, Width, Height, Settings,
          Max(ResolvedUnits[UnitIndex].Base.Style.FontHeight,
            Settings.RubyFontHeight) * Max(ScaleX, ScaleY));
        EdgeMotion := ResolveLyricsUnitMotion(Settings, UnitIndex,
          Length(ResolvedUnits), ResolvedUnits[UnitIndex].SyncUnitIndex,
          CurrentSyncIndex, CurrentSyncProgress,
          ResolvedUnits[UnitIndex].ConsumesNote);
        CompositeLyricsEdgeUnit(Buffer, UnitLayer, Width, Height,
          UnitBounds, EdgeMotion, UnitIndex, Length(ResolvedUnits));
        ClearLyricsUnitLayer(UnitLayer, Width, UnitBounds);
      end;
    finally
      FreePreparedPart(PreparedRuby);
      FreePreparedPart(PreparedBase);
    end;
  end;
  finally
    if UnitLayer <> nil then FreeMem(UnitLayer);
  end;
end;

function HasLyricsLayerTransform(
  const Settings: TLyricsRenderSettings): Boolean;
begin
  Result := (Abs(Settings.LayerOffsetX) > 0.0001) or
    (Abs(Settings.LayerOffsetY) > 0.0001) or
    (Abs(Settings.LayerScaleX - 1.0) > 0.0001) or
    (Abs(Settings.LayerScaleY - 1.0) > 0.0001) or
    (Abs(Settings.LayerRotationDegrees) > 0.0001) or
    (Settings.LayerBlurRadius > 0.0001) or
    (Settings.LayerWipeProgress < 0.9999);
end;

procedure ResetLyricsLayerTransform(var Settings: TLyricsRenderSettings);
begin
  Settings.Opacity := 1;
  Settings.LayerOffsetX := 0;
  Settings.LayerOffsetY := 0;
  Settings.LayerScaleX := 1;
  Settings.LayerScaleY := 1;
  Settings.LayerRotationDegrees := 0;
  Settings.LayerBlurRadius := 0;
  Settings.LayerWipeDirection := 0;
  Settings.LayerWipeProgress := 1;
end;

function FindLayerBounds(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  out Bounds: TRect): Boolean;
var
  Pixel: PPIXEL_RGBA;
  X: Integer;
  Y: Integer;
begin
  Bounds := Rect(Width, Height, -1, -1);
  Pixel := Buffer;
  for Y := 0 to Height - 1 do
    for X := 0 to Width - 1 do
    begin
      if Pixel^.A <> 0 then
      begin
        Bounds.Left := Min(Bounds.Left, X);
        Bounds.Top := Min(Bounds.Top, Y);
        Bounds.Right := Max(Bounds.Right, X + 1);
        Bounds.Bottom := Max(Bounds.Bottom, Y + 1);
      end;
      Inc(Pixel);
    end;
  Result := (Bounds.Right > Bounds.Left) and
    (Bounds.Bottom > Bounds.Top);
end;

function IsLayerWipePixelVisible(X, Y: Double; const Bounds: TRect;
  Direction: Integer; Progress: Double): Boolean;
var
  Normalized: Double;
begin
  Progress := EnsureRange(Progress, 0.0, 1.0);
  case Direction of
    1:
      begin
        Normalized := (X - Bounds.Left) / Max(1, Bounds.Width);
        Result := Normalized >= 1.0 - Progress;
      end;
    3:
      begin
        Normalized := (Y - Bounds.Top) / Max(1, Bounds.Height);
        Result := Normalized >= 1.0 - Progress;
      end;
    4:
      begin
        Normalized := (Y - Bounds.Top) / Max(1, Bounds.Height);
        Result := Normalized <= Progress;
      end;
  else
    begin
      Normalized := (X - Bounds.Left) / Max(1, Bounds.Width);
      Result := Normalized <= Progress;
    end;
  end;
end;

function SampleBlurredLayerPixel(Buffer: PPIXEL_RGBA; Width,
  Height, CenterX, CenterY, Radius: Integer): TPIXEL_RGBA;
var
  Count: UInt64;
  Pixel: PPIXEL_RGBA;
  SumA: UInt64;
  SumB: UInt64;
  SumG: UInt64;
  SumR: UInt64;
  X: Integer;
  Y: Integer;
begin
  Result := Default(TPIXEL_RGBA);
  SumA := 0;
  SumR := 0;
  SumG := 0;
  SumB := 0;
  Count := 0;
  for Y := Max(0, CenterY - Radius) to Min(Height - 1,
    CenterY + Radius) do
    for X := Max(0, CenterX - Radius) to Min(Width - 1,
      CenterX + Radius) do
    begin
      Pixel := Buffer;
      Inc(Pixel, NativeInt(Y) * Width + X);
      Inc(Count);
      Inc(SumA, Pixel^.A);
      Inc(SumR, UInt64(Pixel^.R) * Pixel^.A);
      Inc(SumG, UInt64(Pixel^.G) * Pixel^.A);
      Inc(SumB, UInt64(Pixel^.B) * Pixel^.A);
    end;
  if (Count = 0) or (SumA = 0) then
    Exit;
  Result.A := EnsureRange(Integer((SumA + Count div 2) div Count), 0, 255);
  Result.R := EnsureRange(Integer((SumR + SumA div 2) div SumA), 0, 255);
  Result.G := EnsureRange(Integer((SumG + SumA div 2) div SumA), 0, 255);
  Result.B := EnsureRange(Integer((SumB + SumA div 2) div SumA), 0, 255);
end;

function LyricsBlockRank(Index, Seed: Integer): Integer;
var Value: Integer;
begin
  Value := (Index + (Seed and 63)) and 63;
  Value := Value xor (Value shr 3);
  Value := (Value * 37) and 63;
  Result := Value xor (Value shr 2);
end;

procedure BlendLayerPixel(const Source: TPIXEL_RGBA; Opacity: Double;
  var Destination: TPIXEL_RGBA); forward;

function IsLyricsEdgePixelVisible(X, Y: Double; const Bounds: TRect;
  const Motion: TMVMotion): Boolean;
var
  Cell, Column, Row: Integer;
  Fraction, NormalX, NormalY, Visible: Double;
begin
  Result := False;
  if (Bounds.Width <= 0) or (Bounds.Height <= 0) then Exit;
  NormalX := (X - Bounds.Left) / Bounds.Width;
  NormalY := (Y - Bounds.Top) / Bounds.Height;
  if (NormalX < Motion.ClipLeft) or (NormalX >= Motion.ClipRight) or
    (NormalY < Motion.ClipTop) or (NormalY >= Motion.ClipBottom) then Exit;
  Visible := EnsureRange(Motion.MaskVisibility, 0.0, 1.0);
  case Motion.Mask of
    mamBlinds:
      begin
        if Motion.MaskDirection in [madUp, madDown] then
          Fraction := Frac(NormalY * 8)
        else
          Fraction := Frac(NormalX * 8);
        if Motion.MaskDirection in [madUp, madLeft] then
          Result := Fraction < Visible
        else
          Result := Fraction >= 1 - Visible;
      end;
    mamDissolve:
      begin
        Column := EnsureRange(Floor(NormalX * 8), 0, 7);
        Row := EnsureRange(Floor(NormalY * 8), 0, 7);
        Cell := Row * 8 + Column;
        Result := LyricsBlockRank(Cell, Motion.EffectSeed) + 0.5 <
          Visible * 64;
      end;
  else
    Result := True;
  end;
end;

procedure CompositeLyricsEdgeUnit(Destination, Source: PPIXEL_RGBA;
  Width, Height: Integer; const SourceRegion: TRect;
  const Motion: TMVMotion; UnitIndex, UnitCount: Integer);
var
  Actual: TRect;
  Angle, CosAngle, SinAngle, PivotX, PivotY: Double;
  BlurRadius, Margin: Integer;
  CornerX, CornerY, DX, DY, LocalX, LocalY: Double;
  OffsetX, OffsetY, ScaleX, ScaleY: Double;
  DestinationPixel, SourcePixel: PPIXEL_RGBA;
  DestLeft, DestTop, DestRight, DestBottom: Integer;
  Sample: TPIXEL_RGBA;
  SampleX, SampleY, X, Y, I: Integer;
begin
  if (Motion.Opacity <= 0) or (Motion.Scale <= 0) or
    (Motion.ScaleX <= 0.0001) or (Motion.ScaleY <= 0.0001) or
    (SourceRegion.Right <= SourceRegion.Left) or
    (SourceRegion.Bottom <= SourceRegion.Top) then Exit;
  Actual := Rect(SourceRegion.Right, SourceRegion.Bottom,
    SourceRegion.Left, SourceRegion.Top);
  for Y := SourceRegion.Top to SourceRegion.Bottom - 1 do
    for X := SourceRegion.Left to SourceRegion.Right - 1 do
    begin
      SourcePixel := Source;
      Inc(SourcePixel, NativeInt(Y) * Width + X);
      if SourcePixel^.A = 0 then Continue;
      Actual.Left := Min(Actual.Left, X);
      Actual.Top := Min(Actual.Top, Y);
      Actual.Right := Max(Actual.Right, X + 1);
      Actual.Bottom := Max(Actual.Bottom, Y + 1);
    end;
  if (Actual.Right <= Actual.Left) or (Actual.Bottom <= Actual.Top) then Exit;
  PivotX := (Actual.Left + Actual.Right) * 0.5;
  PivotY := (Actual.Top + Actual.Bottom) * 0.5;
  ScaleX := Max(0.01, Motion.Scale * Motion.ScaleX);
  ScaleY := Max(0.01, Motion.Scale * Motion.ScaleY);
  OffsetX := Motion.X + Motion.Tracking *
    (UnitIndex - (UnitCount - 1) * 0.5);
  OffsetY := Motion.Y;
  Angle := DegToRad(Motion.Angle);
  CosAngle := Cos(Angle);
  SinAngle := Sin(Angle);
  BlurRadius := EnsureRange(Ceil(Motion.BlurSigma), 0, 16);
  Margin := BlurRadius + Ceil(Motion.GlitchAmount) + 2;
  DestLeft := Width;
  DestTop := Height;
  DestRight := 0;
  DestBottom := 0;
  for I := 0 to 3 do
  begin
    if (I and 1) = 0 then CornerX := Actual.Left - Margin
    else CornerX := Actual.Right + Margin;
    if (I and 2) = 0 then CornerY := Actual.Top - Margin
    else CornerY := Actual.Bottom + Margin;
    DX := (CornerX - PivotX) * ScaleX;
    DY := (CornerY - PivotY) * ScaleY;
    LocalX := PivotX + OffsetX + CosAngle * DX - SinAngle * DY;
    LocalY := PivotY + OffsetY + SinAngle * DX + CosAngle * DY;
    DestLeft := Min(DestLeft, Floor(LocalX));
    DestTop := Min(DestTop, Floor(LocalY));
    DestRight := Max(DestRight, Ceil(LocalX));
    DestBottom := Max(DestBottom, Ceil(LocalY));
  end;
  for Y := Max(0, DestTop) to Min(Height, DestBottom) - 1 do
    for X := Max(0, DestLeft) to Min(Width, DestRight) - 1 do
    begin
      DX := X + 0.5 - PivotX - OffsetX;
      DY := Y + 0.5 - PivotY - OffsetY;
      LocalX := PivotX + (CosAngle * DX + SinAngle * DY) / ScaleX;
      LocalY := PivotY + (-SinAngle * DX + CosAngle * DY) / ScaleY;
      if not IsLyricsEdgePixelVisible(LocalX, LocalY, Actual, Motion) then
        Continue;
      if Motion.GlitchAmount > 0.01 then
      begin
        I := EnsureRange(Floor((LocalY - Actual.Top) * 8 /
          Max(1, Actual.Height)), 0, 7);
        LocalX := LocalX - Sin((I + 1) * 12.9898 +
          Motion.GlitchStep * 7.233 + Motion.EffectSeed * 1.713) *
          Motion.GlitchAmount;
      end;
      SampleX := Floor(LocalX);
      SampleY := Floor(LocalY);
      if (SampleX < 0) or (SampleX >= Width) or
        (SampleY < 0) or (SampleY >= Height) then Continue;
      if BlurRadius > 0 then
        Sample := SampleBlurredLayerPixel(Source, Width, Height,
          SampleX, SampleY, BlurRadius)
      else
      begin
        SourcePixel := Source;
        Inc(SourcePixel, NativeInt(SampleY) * Width + SampleX);
        Sample := SourcePixel^;
      end;
      if Sample.A = 0 then Continue;
      DestinationPixel := Destination;
      Inc(DestinationPixel, NativeInt(Y) * Width + X);
      BlendLayerPixel(Sample, Motion.Opacity, DestinationPixel^);
    end;
end;

procedure BlendLayerPixel(const Source: TPIXEL_RGBA; Opacity: Double;
  var Destination: TPIXEL_RGBA);
var
  TextPixel: TTextRenderPixel;
begin
  TextPixel.R := Source.R;
  TextPixel.G := Source.G;
  TextPixel.B := Source.B;
  TextPixel.A := Source.A;
  BlendStraightTextPixel(TextPixel, Opacity, Destination);
end;

procedure CompositeLyricsLayer(Destination, Source: PPIXEL_RGBA;
  Width, Height: Integer; const Settings: TLyricsRenderSettings);
var
  Angle: Double;
  BlurRadius: Integer;
  Bounds: TRect;
  CosAngle: Double;
  DestinationPixel: PPIXEL_RGBA;
  DX: Double;
  DY: Double;
  PivotX: Double;
  PivotY: Double;
  Sample: TPIXEL_RGBA;
  SinAngle: Double;
  SourceX: Double;
  SourceY: Double;
  SourceXi: Integer;
  SourceYi: Integer;
  X: Integer;
  Y: Integer;
begin
  if (Settings.Opacity <= 0) or
    not FindLayerBounds(Source, Width, Height, Bounds) then
    Exit;
  PivotX := (Bounds.Left + Bounds.Right) * 0.5;
  PivotY := (Bounds.Top + Bounds.Bottom) * 0.5;
  Angle := DegToRad(Settings.LayerRotationDegrees);
  SinAngle := Sin(Angle);
  CosAngle := Cos(Angle);
  BlurRadius := EnsureRange(Round(Settings.LayerBlurRadius), 0, 16);
  for Y := 0 to Height - 1 do
    for X := 0 to Width - 1 do
    begin
      DX := (X + 0.5) - PivotX - Settings.LayerOffsetX;
      DY := (Y + 0.5) - PivotY - Settings.LayerOffsetY;
      SourceX := PivotX + (CosAngle * DX + SinAngle * DY) /
        EnsureRange(Settings.LayerScaleX, 0.01, 100.0);
      SourceY := PivotY + (-SinAngle * DX + CosAngle * DY) /
        EnsureRange(Settings.LayerScaleY, 0.01, 100.0);
      if (SourceX < Bounds.Left - BlurRadius) or
        (SourceX >= Bounds.Right + BlurRadius) or
        (SourceY < Bounds.Top - BlurRadius) or
        (SourceY >= Bounds.Bottom + BlurRadius) or
        not IsLayerWipePixelVisible(SourceX, SourceY, Bounds,
          Settings.LayerWipeDirection, Settings.LayerWipeProgress) then
        Continue;
      SourceXi := Floor(SourceX);
      SourceYi := Floor(SourceY);
      if BlurRadius > 0 then
        Sample := SampleBlurredLayerPixel(Source, Width, Height,
          SourceXi, SourceYi, BlurRadius)
      else if (SourceXi >= 0) and (SourceXi < Width) and
        (SourceYi >= 0) and (SourceYi < Height) then
      begin
        Sample := PPIXEL_RGBA(PByte(Source) +
          (NativeInt(SourceYi) * Width + SourceXi) *
          SizeOf(TPIXEL_RGBA))^;
      end
      else
        Continue;
      if Sample.A = 0 then
        Continue;
      DestinationPixel := Destination;
      Inc(DestinationPixel, NativeInt(Y) * Width + X);
      BlendLayerPixel(Sample, Settings.Opacity, DestinationPixel^);
    end;
end;

procedure DrawProcessedLyricsLayer(Buffer: PPIXEL_RGBA; Width,
  Height: Integer; const Source: string; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  const Placements: TDisplayPlacementItems; FreePlacement: Boolean;
  PositionX, PositionY: Integer);
var
  Layer: PPIXEL_RGBA;
  LayerSettings: TLyricsRenderSettings;
  PixelCount: NativeInt;
begin
  if not HasLyricsLayerTransform(Settings) then
  begin
    if FreePlacement then
      DrawSkiaFreePlacementLyrics(Buffer, Width, Height, Source,
        ProgressUnits, Settings, Placements, PositionX, PositionY)
    else
      DrawSkiaLineLyrics(Buffer, Width, Height, Source, ProgressUnits,
        Settings, PositionX, PositionY);
    Exit;
  end;
  PixelCount := NativeInt(Width) * Height;
  GetMem(Layer, PixelCount * SizeOf(TPIXEL_RGBA));
  try
    FillChar(Layer^, PixelCount * SizeOf(TPIXEL_RGBA), 0);
    LayerSettings := Settings;
    ResetLyricsLayerTransform(LayerSettings);
    if FreePlacement then
      DrawSkiaFreePlacementLyrics(Layer, Width, Height, Source,
        ProgressUnits, LayerSettings, Placements, PositionX, PositionY)
    else
      DrawSkiaLineLyrics(Layer, Width, Height, Source, ProgressUnits,
        LayerSettings, PositionX, PositionY);
    CompositeLyricsLayer(Buffer, Layer, Width, Height, Settings);
  finally
    FreeMem(Layer);
  end;
end;

function RenderLocked(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  const Placements: TDisplayPlacementItems; FreePlacement: Boolean;
  PositionX, PositionY, Width, Height: Integer): Boolean;
var
  Buffer: PPIXEL_RGBA;
  PixelCount: NativeInt;
begin
  PixelCount := NativeInt(Width) * Height;
  GetMem(Buffer, PixelCount * SizeOf(TPIXEL_RGBA));
  try
    InitializeLyricsRenderBuffer(Video, Buffer, PixelCount);
    try
      if (Lyrics <> nil) and (Lyrics^ <> #0) then
        if FreePlacement then
          DrawProcessedLyricsLayer(Buffer, Width, Height,
            string(Lyrics), ProgressUnits, Settings, Placements, True,
            PositionX, PositionY)
        else
          DrawProcessedLyricsLayer(Buffer, Width, Height,
            string(Lyrics), ProgressUnits, Settings, Placements, False,
            PositionX, PositionY);
      // 空文字でも入力画像を確定し、直前フレームの歌詞を残さない。
      Video^.SetImageData(Buffer, Width, Height);
      Result := True;
    except
      Result := False;
    end;
  finally
    FreeMem(Buffer);
  end;
end;

function RenderLyrics(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  PositionX, PositionY: Integer): Boolean;
var
  EmptyPlacements: TDisplayPlacementItems;
  Height: Integer;
  Width: Integer;
begin
  Result := ResolveRenderSize(Video, Width, Height);
  if not Result then
    Exit;

  EnterCriticalSection(RendererLock);
  try
    EmptyPlacements := nil;
    Result := RenderLocked(Video, Lyrics, ProgressUnits, Settings,
      EmptyPlacements, False, PositionX, PositionY, Width, Height);
  finally
    LeaveCriticalSection(RendererLock);
  end;
end;

function RenderFreePlacementLyrics(Video: PFILTER_PROC_VIDEO;
  Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  const Placements: TDisplayPlacementItems;
  PositionX, PositionY: Integer): Boolean;
var
  Height: Integer;
  Width: Integer;
begin
  Result := ResolveRenderSize(Video, Width, Height);
  if not Result then
    Exit;

  EnterCriticalSection(RendererLock);
  try
    Result := RenderLocked(Video, Lyrics, ProgressUnits, Settings,
      Placements, True, PositionX, PositionY, Width, Height);
  finally
    LeaveCriticalSection(RendererLock);
  end;
end;

function TryGetLyricsRenderSize(Video: PFILTER_PROC_VIDEO;
  out Width, Height: Integer): Boolean;
begin
  Result := ResolveRenderSize(Video, Width, Height);
end;

function DrawLyricsLayer(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  PositionX, PositionY: Integer): Boolean;
begin
  Result := (Buffer <> nil) and (Width > 0) and (Height > 0) and
    (Width <= MAX_RENDER_DIMENSION) and (Height <= MAX_RENDER_DIMENSION);
  if not Result then
    Exit;
  EnterCriticalSection(RendererLock);
  try
    try
      if (Lyrics <> nil) and (Lyrics^ <> #0) then
        DrawProcessedLyricsLayer(Buffer, Width, Height, string(Lyrics),
          ProgressUnits, Settings, nil, False, PositionX, PositionY);
      Result := True;
    except
      Result := False;
    end;
  finally
    LeaveCriticalSection(RendererLock);
  end;
end;

function DrawFreePlacementLyricsLayer(Buffer: PPIXEL_RGBA;
  Width, Height: Integer; Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  const Placements: TDisplayPlacementItems;
  PositionX, PositionY: Integer): Boolean;
begin
  Result := (Buffer <> nil) and (Width > 0) and (Height > 0) and
    (Width <= MAX_RENDER_DIMENSION) and (Height <= MAX_RENDER_DIMENSION);
  if not Result then
    Exit;
  EnterCriticalSection(RendererLock);
  try
    try
      if (Lyrics <> nil) and (Lyrics^ <> #0) then
        DrawProcessedLyricsLayer(Buffer, Width, Height, string(Lyrics),
          ProgressUnits, Settings, Placements, True,
          PositionX, PositionY);
      Result := True;
    except
      Result := False;
    end;
  finally
    LeaveCriticalSection(RendererLock);
  end;
end;

procedure InitializeLyricsRenderer;
begin
  if RendererInitialized then
    Exit;
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  RendererSkiaAcquired := True;
  try
    SkiaRenderer := TSkiaTextRenderer.Create;
    InitializeCriticalSection(RendererLock);
    RendererInitialized := True;
  except
    FreeAndNil(SkiaRenderer);
    TTextRendererSkiaRuntime.Release;
    RendererSkiaAcquired := False;
    raise;
  end;
end;

procedure FinalizeLyricsRenderer;
begin
  if RendererInitialized then
  begin
    DeleteCriticalSection(RendererLock);
    RendererInitialized := False;
  end;
  FreeAndNil(SkiaRenderer);
  if RendererSkiaAcquired then
  begin
    TTextRendererSkiaRuntime.Release;
    RendererSkiaAcquired := False;
  end;
end;

end.
