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

  // AviUtl2の色項目から独立して描画処理へ渡す不透明RGB色。
  TLyricsRenderColor = record
    R: Byte;
    G: Byte;
    B: Byte;
  end;

  // 1行の本文とルビに適用する基本表示設定。
  TLyricsRenderSettings = record
    DisplayType: TLyricsDisplayType;
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
  end;

// 描画用の共有資源を初期化する。Filterの初期化時に1回だけ呼び出す。
procedure InitializeLyricsRenderer;

// 新規歌詞表示に使用する既定の描画設定を返す。
function DefaultLyricsRenderSettings: TLyricsRenderSettings;

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

type
  TPreparedLyricsPart = record
    AfterImage: TTextRenderImage;
    BeforeImage: TTextRenderImage;
    AdvanceLeft: Single;
    AdvanceRight: Single;
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

procedure BlendPreparedImage(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Prepared: TPreparedLyricsPart; Image: TTextRenderImage;
  PivotX, PivotY, BaselineLocalX, BaselineLocalY, ScaleX, ScaleY,
  ClipProgress, Opacity: Double);
var
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
  ClipProgress := EnsureRange(ClipProgress, 0.0, 1.0);
  if ClipProgress <= 0 then
    Exit;
  ImageLeft := PivotX + (BaselineLocalX + Image.Bounds.Left) * ScaleX;
  ImageTop := PivotY + (BaselineLocalY + Image.Bounds.Top) * ScaleY;
  DestinationLeft := Floor(ImageLeft);
  DestinationTop := Floor(ImageTop);
  DestinationRight := Ceil(ImageLeft + Image.Width * ScaleX);
  DestinationBottom := Ceil(ImageTop + Image.Height * ScaleY);
  if ClipProgress >= 1 then
    ClipSourceRight := Image.Width
  else
    ClipSourceRight := Prepared.AdvanceLeft - Image.Bounds.Left +
      (Prepared.AdvanceRight - Prepared.AdvanceLeft) * ClipProgress;
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
  Opacity: Double);
begin
  Opacity := Opacity * State.Opacity;
  if State.DrawBefore then
    BlendPreparedImage(Buffer, Width, Height, Prepared,
      Prepared.BeforeImage, PivotX, PivotY, BaselineLocalX,
      BaselineLocalY, ScaleX, ScaleY, 1, Opacity);
  if State.AfterProgress > 0 then
    BlendPreparedImage(Buffer, Width, Height, Prepared,
      Prepared.AfterImage, PivotX, PivotY, BaselineLocalX,
      BaselineLocalY, ScaleX, ScaleY, State.AfterProgress, Opacity);
end;

procedure DrawSkiaLineLyrics(Buffer: PPIXEL_RGBA; Width, Height: Integer;
  const Source: string; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings; PositionX, PositionY: Integer);
var
  AnyRuby: Boolean;
  BaseBaselineX: Double;
  BaseBaselineY: Double;
  BaseLeft: Double;
  BaseTop: Double;
  BaseUnitLefts: TArray<Double>;
  BaseUnitWidths: TArray<Double>;
  DefaultBaseStyle: TResolvedLyricsStyle;
  DefaultRubyStyle: TResolvedLyricsStyle;
  Effect: TLyricsUnitDisplayEffect;
  EmptyPlacements: TDisplayPlacementItems;
  Gap: Double;
  LogicalUnits: TLyricsDisplayUnits;
  PlainText: string;
  PreparedBase: TPreparedLyricsParts;
  PreparedRuby: TPreparedLyricsParts;
  ResolvedUnits: TResolvedLyricsDisplayUnits;
  RubyBaselineX: Double;
  RubyBaselineY: Double;
  RubySpans: TLyricsRubySpans;
  RubyTop: Double;
  RubyWidth: Double;
  State: TLyricsUnitEffectState;
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
    for UnitIndex := 0 to High(ResolvedUnits) do
    begin
      if not PrepareLyricsPart(ResolvedUnits[UnitIndex].Base,
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
      if ResolvedUnits[UnitIndex].HasRuby then
      begin
        AnyRuby := True;
        PrepareLyricsPart(ResolvedUnits[UnitIndex].Ruby,
          PreparedRuby[UnitIndex]);
      end;
    end;
    Gap := EnsureRange(DEFAULT_RUBY_GAP + Settings.RubyGapAdjustment,
      MIN_RUBY_GAP, MAX_RUBY_GAP);
    if AnyRuby then
      BaseTop := (Height - (Settings.RubyFontHeight + Gap +
        Settings.BaseFontHeight)) * 0.5 + Settings.RubyFontHeight + Gap +
        PositionY
    else
      BaseTop := (Height - Settings.BaseFontHeight) * 0.5 + PositionY;
    RubyTop := BaseTop - Gap - Settings.RubyFontHeight;
    Effect := UnitDisplayEffectFromType(Settings.DisplayType);
    for UnitIndex := 0 to High(ResolvedUnits) do
    begin
      UnitProgress := GetDisplayUnitProgress(ResolvedUnits, UnitIndex,
        ProgressUnits);
      ResolveLyricsUnitEffect(Effect, UnitProgress, State);
      BaseLeft := (Width - TotalBaseWidth) * 0.5 + PositionX +
        BaseUnitLefts[UnitIndex];
      BaseBaselineX := BaseLeft - PreparedBase[UnitIndex].AdvanceLeft;
      BaseBaselineY := BaseTop -
        PreparedBase[UnitIndex].BeforeImage.LayoutBounds.Top;
      DrawPreparedPart(Buffer, Width, Height, PreparedBase[UnitIndex], State,
        0, 0, BaseBaselineX, BaseBaselineY, State.ScaleX, State.ScaleY,
        Settings.Opacity);
      if not ResolvedUnits[UnitIndex].HasRuby then
        Continue;
      RubyWidth := PreparedRuby[UnitIndex].AdvanceRight -
        PreparedRuby[UnitIndex].AdvanceLeft;
      RubyBaselineX := BaseLeft + (BaseUnitWidths[UnitIndex] - RubyWidth) *
        0.5 - PreparedRuby[UnitIndex].AdvanceLeft;
      RubyBaselineY := RubyTop -
        PreparedRuby[UnitIndex].BeforeImage.LayoutBounds.Top;
      DrawPreparedPart(Buffer, Width, Height, PreparedRuby[UnitIndex], State,
        0, 0, RubyBaselineX, RubyBaselineY, State.ScaleX, State.ScaleY,
        Settings.Opacity);
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
  BaseBaselineX: Double;
  BaseBaselineY: Double;
  BaseTop: Double;
  DefaultBaseStyle: TResolvedLyricsStyle;
  DefaultRubyStyle: TResolvedLyricsStyle;
  Effect: TLyricsUnitDisplayEffect;
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
  UnitIndex: Integer;
  UnitProgress: Double;
  PivotX: Double;
  PivotY: Double;
begin
  DefaultBaseStyle := ResolvedStyleFromSettings(Settings, False);
  DefaultRubyStyle := ResolvedStyleFromSettings(Settings, True);
  if not BuildResolvedLyricsDisplayUnits(Source, DefaultBaseStyle,
    DefaultRubyStyle, Placements, True, PlainText, RubySpans,
    LogicalUnits, ResolvedUnits) then
    Exit;
  RubyGap := EnsureRange(DEFAULT_RUBY_GAP + Settings.RubyGapAdjustment,
    MIN_RUBY_GAP, MAX_RUBY_GAP);
  Effect := UnitDisplayEffectFromType(Settings.DisplayType);
  for UnitIndex := 0 to High(ResolvedUnits) do
  begin
    PreparedBase := Default(TPreparedLyricsPart);
    PreparedRuby := Default(TPreparedLyricsPart);
    try
      if not PrepareLyricsPart(ResolvedUnits[UnitIndex].Base,
        PreparedBase) then
        Continue;
      if ResolvedUnits[UnitIndex].HasRuby then
        PrepareLyricsPart(ResolvedUnits[UnitIndex].Ruby, PreparedRuby);
      UnitProgress := GetDisplayUnitProgress(ResolvedUnits, UnitIndex,
        ProgressUnits);
      ResolveLyricsUnitEffect(Effect, UnitProgress, State);
      PivotX := Width * 0.5 + ResolvedUnits[UnitIndex].X + PositionX +
        State.OffsetX;
      PivotY := Height * 0.5 + ResolvedUnits[UnitIndex].Y + PositionY +
        State.OffsetY;
      ScaleX := ResolvedUnits[UnitIndex].ScaleX * State.ScaleX;
      ScaleY := ResolvedUnits[UnitIndex].ScaleY * State.ScaleY;
      BaseTop := -PreparedBase.BeforeImage.LayoutBounds.Height * 0.5;
      BaseBaselineX := -(PreparedBase.AdvanceLeft +
        PreparedBase.AdvanceRight) * 0.5;
      BaseBaselineY := BaseTop - PreparedBase.BeforeImage.LayoutBounds.Top;
      DrawPreparedPart(Buffer, Width, Height, PreparedBase, State,
        PivotX, PivotY, BaseBaselineX, BaseBaselineY, ScaleX, ScaleY,
        Settings.Opacity);
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
          PivotX, PivotY, RubyBaselineX, RubyBaselineY, ScaleX, ScaleY,
          Settings.Opacity);
      end;
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
