unit SYNC_Lyrics_Renderer;

// 歌詞の本文・ルビをSkiaで測定し、同期色を合成したRGBA画像をAviUtl2へ渡す。

interface

uses
  AviUtl2FilterTypes,
  SYNC_Lyrics_DisplaySettingsData;

type
  TLyricsDisplayType = (
    ldtKaraoke,
    ldtUnitEmphasis,
    ldtUnitReveal
  );
  TLyricsColorFillMode = (lcfCharacter, lcfSmooth);
  TLyricsColorAfterMode = (lcaRestore, lcaKeep);
  TLyricsSyncKind = (lskNone, lskColor, lskFront, lskBacking, lskUnderline,
    lskZoom, lskGlow, lskJump);

  // AviUtl2の色項目から独立して描画処理へ渡す不透明RGB色。
  TLyricsRenderColor = record
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
    SyncShape: Integer;
    SyncOffsetX: Double;
    SyncOffsetY: Double;
    Opacity: Double;
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
    SyncColor: TLyricsRenderColor;
  end;

// 描画用の共有資源を初期化する。Filterの初期化時に1回だけ呼び出す。
procedure InitializeLyricsRenderer;

// 新規歌詞表示に使用する既定の描画設定を返す。
function DefaultLyricsRenderSettings: TLyricsRenderSettings;

// AviUtl2へ渡す歌詞画像の寸法を取得する。
function TryGetLyricsRenderSize(Video: PFILTER_PROC_VIDEO;
  out Width, Height: Integer): Boolean;

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
  PluginFilterSerifDrawSyncHighlight,
  SYNC_Lyrics_Animation,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_ResolvedDisplayUnits,
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
  Result.SyncShape := 0;
  Result.SyncOffsetX := 0;
  Result.SyncOffsetY := 0;
  Result.Opacity := 1;
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
  Result.AfterColor.R := 0;
  Result.AfterColor.G := 255;
  Result.AfterColor.B := 255;
  Result.SyncColor := Result.AfterColor;
end;

function LyricsColorToCardinal(const Color: TLyricsRenderColor): Cardinal;
begin
  Result := Color.R or (Cardinal(Color.G) shl 8) or
    (Cardinal(Color.B) shl 16);
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

function GetDisplayUnitProgress(const Units: TResolvedLyricsDisplayUnits;
  UnitIndex: Integer; ProgressUnits: Double): Double;
begin
  if (UnitIndex < 0) or (UnitIndex >= Length(Units)) then
    Exit(0);
  if Units[UnitIndex].SyncUnitIndex < 0 then
    Exit(0);
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
var
  JumpHeight: Double;
  Phase: Double;
  Scale: Double;
begin
  if not (Settings.SyncKind in [lskZoom, lskJump]) then
    Exit;
  Phase := ResolveSerifSyncPhase(UnitSyncIndex, CurrentIndex,
    CurrentProgress, Settings);
  if Phase <= 0 then
    Exit;
  if Settings.SyncKind = lskZoom then
  begin
    Scale := 1.0 + (Max(0.01, Settings.ColorBandSizePercent) / 100.0 - 1.0) *
      Phase;
    State.ScaleX := State.ScaleX * Scale;
    State.ScaleY := State.ScaleY * Scale;
    State.OffsetX := State.OffsetX + Settings.SyncOffsetX * Phase;
    State.OffsetY := State.OffsetY + Settings.SyncOffsetY * Phase;
  end
  else
  begin
    JumpHeight := Max(1, FontHeight) *
      (Max(0.01, Settings.ColorBandSizePercent) / 100.0 - 1.0);
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

function RendererModuleDirectory: string;
var
  Buffer: array[0..32767] of Char;
  PathLength: DWORD;
begin
  PathLength := GetModuleFileName(HInstance, Buffer, Length(Buffer));
  if PathLength = 0 then
    RaiseLastOSError;
  if PathLength >= DWORD(Length(Buffer)) then
    raise EPathTooLongException.Create('The renderer module path is too long');
  SetString(Result, Buffer, PathLength);
  Result := ExtractFilePath(Result);
end;

function LyricsColorToAlphaColor(Color: Cardinal): TAlphaColor;
begin
  Result := TAlphaColor($FF000000 or
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
  Metrics: TTextRenderMetrics;
  Request: TTextRenderRequest;
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
  Request.FillColor := LyricsColorToAlphaColor(Part.Style.BeforeColor);
  try
    Prepared.BeforeImage := SkiaRenderer.Render(Request, Metrics);
    Request.FillColor := LyricsColorToAlphaColor(Part.Style.AfterColor);
    Prepared.AfterImage := SkiaRenderer.Render(Request, Metrics);
    if Settings.SyncKind = lskGlow then
    begin
      Request.FillColor := TAlphaColorRec.Null;
      Request.Outlines := [TTextRenderOutline.Create(
        Max(1.0, Part.Style.FontHeight * 0.03),
        Max(1.0, Part.Style.FontHeight * 0.075),
        TAlphaColor($FF000000 or
          (Cardinal(Settings.SyncColor.R) shl 16) or
          (Cardinal(Settings.SyncColor.G) shl 8) or
          Cardinal(Settings.SyncColor.B)))];
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
        BlendSyncSolidPixel(Settings, 160, Phase, Destination^);
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
        BlendSyncSolidPixel(Settings, 255, Phase, Destination^);
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
  RubyWidth: Double;
  State: TLyricsUnitEffectState;
  SyncEffectHeight: Double;
  SyncEffectTop: Double;
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
      UnitProgress := GetDisplayUnitProgress(ResolvedUnits, UnitIndex,
        ProgressUnits);
      ResolveLyricsUnitEffect(Effect, UnitProgress, State);
      ApplySerifSyncTransform(ResolvedUnits[UnitIndex].SyncUnitIndex,
        CurrentSyncIndex, CurrentSyncProgress,
        ResolvedUnits[UnitIndex].Base.Style.FontHeight, Settings, State);
      SyncPhase := ResolveSerifSyncPhase(
        ResolvedUnits[UnitIndex].SyncUnitIndex, CurrentSyncIndex,
        CurrentSyncProgress, Settings);
      GlowOpacity := 0;
      if Settings.SyncKind = lskGlow then
        GlowOpacity := SyncPhase *
          Max(0.0, Settings.ColorBandSizePercent) / 100.0;
      AfterClipStart := 0;
      AfterClipEnd := State.AfterProgress;
      if Settings.DisplayType = ldtKaraoke then
        ResolveKaraokeColorClip(UnitProgress, ProgressUnits,
          ResolvedUnits[UnitIndex].SyncUnitIndex, SyncUnitCount, Settings,
          AfterClipStart, AfterClipEnd);
      BaseLeft := (Width - TotalBaseWidth) * 0.5 + PositionX +
        BaseUnitLefts[UnitIndex];
      BaseBaselineX := BaseLeft - PreparedBase[UnitIndex].AdvanceLeft;
      BasePivotX := BaseLeft + BaseUnitWidths[UnitIndex] * 0.5;
      // 拡大しても本文の底辺が動かないよう、表示単位の下端を変形基準にする。
      BasePivotY := BaseBaselineY + BaseLayoutBottom;
      DrawSyncBacking(Buffer, Width, Height, BaseLeft,
        BaseTop, BaseUnitWidths[UnitIndex],
        ResolvedUnits[UnitIndex].Base.Style.FontHeight,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
      DrawPreparedPart(Buffer, Width, Height, PreparedBase[UnitIndex], State,
        BasePivotX + State.OffsetX, BasePivotY + State.OffsetY,
        BaseBaselineX - BasePivotX,
        BaseBaselineY - BasePivotY, State.ScaleX, State.ScaleY,
        AfterClipStart, AfterClipEnd, GlowOpacity,
        Settings.SyncOffsetX, Settings.SyncOffsetY, Settings.Opacity);
      SyncEffectTop := BaseTop;
      SyncEffectHeight := ResolvedUnits[UnitIndex].Base.Style.FontHeight;
      if ResolvedUnits[UnitIndex].HasRuby then
      begin
        RubyWidth := PreparedRuby[UnitIndex].AdvanceRight -
          PreparedRuby[UnitIndex].AdvanceLeft;
        RubyBaselineX := BaseLeft + (BaseUnitWidths[UnitIndex] - RubyWidth) *
          0.5 - PreparedRuby[UnitIndex].AdvanceLeft;
        DrawPreparedPart(Buffer, Width, Height, PreparedRuby[UnitIndex], State,
          BasePivotX + State.OffsetX, BasePivotY + State.OffsetY,
          RubyBaselineX - BasePivotX,
          RubyBaselineY - BasePivotY, State.ScaleX, State.ScaleY,
          AfterClipStart, AfterClipEnd, GlowOpacity,
          Settings.SyncOffsetX, Settings.SyncOffsetY, Settings.Opacity);
        SyncEffectTop := RubyTop;
        SyncEffectHeight := BaseTop +
          ResolvedUnits[UnitIndex].Base.Style.FontHeight - RubyTop;
      end;
      DrawSyncFront(Buffer, Width, Height, BaseLeft, SyncEffectTop,
        BaseUnitWidths[UnitIndex], SyncEffectHeight, AfterClipStart,
        AfterClipEnd, SyncPhase, Settings);
      DrawSyncUnderline(Buffer, Width, Height, BaseLeft, BaseTop,
        BaseUnitWidths[UnitIndex],
        ResolvedUnits[UnitIndex].Base.Style.FontHeight,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
    end;
  finally
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
  Effect: TLyricsUnitDisplayEffect;
  GlowOpacity: Double;
  LogicalUnits: TLyricsDisplayUnits;
  PlainText: string;
  PreparedBase: TPreparedLyricsPart;
  PreparedRuby: TPreparedLyricsPart;
  ResolvedUnits: TResolvedLyricsDisplayUnits;
  RubyBaselineX: Double;
  RubyBaselineY: Double;
  RubyGap: Double;
  RubySpans: TLyricsRubySpans;
  RubyTop: Double;
  ScaleX: Double;
  ScaleY: Double;
  State: TLyricsUnitEffectState;
  SyncEffectHeight: Double;
  SyncEffectLeft: Double;
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
      UnitProgress := GetDisplayUnitProgress(ResolvedUnits, UnitIndex,
        ProgressUnits);
      ResolveLyricsUnitEffect(Effect, UnitProgress, State);
      ApplySerifSyncTransform(ResolvedUnits[UnitIndex].SyncUnitIndex,
        CurrentSyncIndex, CurrentSyncProgress,
        ResolvedUnits[UnitIndex].Base.Style.FontHeight, Settings, State);
      SyncPhase := ResolveSerifSyncPhase(
        ResolvedUnits[UnitIndex].SyncUnitIndex, CurrentSyncIndex,
        CurrentSyncProgress, Settings);
      GlowOpacity := 0;
      if Settings.SyncKind = lskGlow then
        GlowOpacity := SyncPhase *
          Max(0.0, Settings.ColorBandSizePercent) / 100.0;
      AfterClipStart := 0;
      AfterClipEnd := State.AfterProgress;
      if Settings.DisplayType = ldtKaraoke then
        ResolveKaraokeColorClip(UnitProgress, ProgressUnits,
          ResolvedUnits[UnitIndex].SyncUnitIndex, SyncUnitCount, Settings,
          AfterClipStart, AfterClipEnd);
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
      DrawSyncBacking(Buffer, Width, Height, SyncEffectLeft,
        SyncEffectTop, SyncEffectWidth, SyncEffectHeight,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
      DrawPreparedPart(Buffer, Width, Height, PreparedBase, State,
        PivotX + State.OffsetX, TransformPivotY + State.OffsetY,
        BaseBaselineX, BaseBaselineY - BaseBottom, ScaleX, ScaleY,
        AfterClipStart, AfterClipEnd, GlowOpacity,
        Settings.SyncOffsetX, Settings.SyncOffsetY, Settings.Opacity);
      if ResolvedUnits[UnitIndex].HasRuby then
      begin
        RubyTop := BaseTop - RubyGap +
          ResolvedUnits[UnitIndex].Ruby.OffsetY;
        RubyBaselineX := -(PreparedRuby.AdvanceLeft +
          PreparedRuby.AdvanceRight) * 0.5 +
          ResolvedUnits[UnitIndex].Ruby.OffsetX;
        RubyBaselineY := RubyTop -
          PreparedRuby.BeforeImage.LayoutBounds.Bottom;
        DrawPreparedPart(Buffer, Width, Height, PreparedRuby, State,
          PivotX + State.OffsetX, TransformPivotY + State.OffsetY,
          RubyBaselineX, RubyBaselineY - BaseBottom, ScaleX, ScaleY,
          AfterClipStart, AfterClipEnd, GlowOpacity,
          Settings.SyncOffsetX, Settings.SyncOffsetY, Settings.Opacity);
        SyncEffectTop := Min(SyncEffectTop,
          PivotY + RubyTop * ScaleY);
        SyncEffectHeight := PivotY +
          (BaseTop + ResolvedUnits[UnitIndex].Base.Style.FontHeight) *
          ScaleY - SyncEffectTop;
      end;
      DrawSyncFront(Buffer, Width, Height, SyncEffectLeft,
        SyncEffectTop, SyncEffectWidth, SyncEffectHeight,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
      DrawSyncUnderline(Buffer, Width, Height, SyncEffectLeft,
        PivotY + BaseTop * ScaleY, SyncEffectWidth,
        ResolvedUnits[UnitIndex].Base.Style.FontHeight * ScaleY,
        AfterClipStart, AfterClipEnd, SyncPhase, Settings);
    finally
      FreePreparedPart(PreparedRuby);
      FreePreparedPart(PreparedBase);
    end;
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
    FillChar(Buffer^, PixelCount * SizeOf(TPIXEL_RGBA), 0);
    try
      if (Lyrics <> nil) and (Lyrics^ <> #0) then
        if FreePlacement then
          DrawSkiaFreePlacementLyrics(Buffer, Width, Height,
            string(Lyrics), ProgressUnits, Settings, Placements,
            PositionX, PositionY)
        else
          DrawSkiaLineLyrics(Buffer, Width, Height, string(Lyrics),
            ProgressUnits, Settings, PositionX, PositionY);
      // 空文字でも透明画像を確定し、直前フレームの歌詞を残さない。
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
        DrawSkiaLineLyrics(Buffer, Width, Height, string(Lyrics),
          ProgressUnits, Settings, PositionX, PositionY);
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
        DrawSkiaFreePlacementLyrics(Buffer, Width, Height,
          string(Lyrics), ProgressUnits, Settings, Placements,
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
var
  LibraryFileName: string;
begin
  if RendererInitialized then
    Exit;
  LibraryFileName := RendererModuleDirectory + 'sk4d.dll';
  TTextRendererSkiaRuntime.Acquire(LibraryFileName);
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
