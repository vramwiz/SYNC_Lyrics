unit SYNC_Lyrics_Renderer;

// 歌詞文字列をAviUtl2のRGBA画像へ変換する最小描画処理を担当する。

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

// 従来の検証済み表示と同じ基本表示設定を返す。
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
  SYNC_Lyrics_Animation,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_ResolvedDisplayUnits,
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

type
  TLyricsFontCacheItem = record
    FontName: string;
    FontHeight: Integer;
    Bold: Boolean;
    Italic: Boolean;
    Underline: Boolean;
    StrikeOut: Boolean;
    Handle: HFONT;
  end;
  TLyricsFontCache = TArray<TLyricsFontCacheItem>;

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

procedure ConvertDibToRgba(ColorBits, MaskBits: Pointer;
  Buffer: PPIXEL_RGBA; PixelCount: NativeInt; Opacity: Double);
var
  Coverage: Byte;
  CoverageSrc: PByte;
  Dst: PPIXEL_RGBA;
  ColorSrc: PByte;
  I: NativeInt;
begin
  Opacity := EnsureRange(Opacity, 0.0, 1.0);
  ColorSrc := ColorBits;
  CoverageSrc := MaskBits;
  Dst := Buffer;
  for I := 0 to PixelCount - 1 do
  begin
    // 色とは別の白文字マスクからカバレッジを取得し、黒や暗色でも透明度を失わないようにする。
    Coverage := Max(CoverageSrc[0], Max(CoverageSrc[1], CoverageSrc[2]));
    Dst^.R := ColorSrc[2];
    Dst^.G := ColorSrc[1];
    Dst^.B := ColorSrc[0];
    Dst^.A := Round(Coverage * Opacity);
    Inc(ColorSrc, 4);
    Inc(CoverageSrc, 4);
    Inc(Dst);
  end;
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

function LyricsColorToColorRef(const Color: TLyricsRenderColor): COLORREF;
begin
  Result := Color.R or (Cardinal(Color.G) shl 8) or
    (Cardinal(Color.B) shl 16);
end;

function LyricsColorToCardinal(const Color: TLyricsRenderColor): Cardinal;
begin
  Result := Color.R or (Cardinal(Color.G) shl 8) or
    (Cardinal(Color.B) shl 16);
end;

function CardinalToLyricsColor(Color: Cardinal): TLyricsRenderColor;
begin
  Result.R := Color and $FF;
  Result.G := (Color shr 8) and $FF;
  Result.B := (Color shr 16) and $FF;
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

function CreateLyricsFont(const FontName: string; FontHeight: Integer;
  Bold, Italic, Underline, StrikeOut: Boolean): HFONT;
var
  FontWeight: Integer;
  ResolvedFontName: string;
begin
  ResolvedFontName := FontName;
  if ResolvedFontName = '' then
    ResolvedFontName := 'Yu Gothic UI';
  FontHeight := EnsureRange(FontHeight, MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  FontWeight := FW_NORMAL;
  if Bold then
    FontWeight := FW_BOLD;
  Result := CreateFontW(FontHeight, 0, 0, 0, FontWeight,
    Ord(Italic), Ord(Underline), Ord(StrikeOut),
    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
    ANTIALIASED_QUALITY, DEFAULT_PITCH or FF_DONTCARE,
    PWideChar(ResolvedFontName));
end;

function MeasureTextWidth(DC: HDC; const Text: string): Integer;
var
  CharacterExtra: Integer;
  TextSize: TSize;
begin
  if Text = '' then
    Exit(0);
  if not GetTextExtentPoint32W(DC, PWideChar(Text), Length(Text), TextSize) then
    Exit(0);
  CharacterExtra := GetTextCharacterExtra(DC);
  Result := Max(0, TextSize.cx - CharacterExtra);
end;

procedure IncludeResolvedRect(var Target: TResolvedLyricsRect;
  var HasTarget: Boolean; const Value: TResolvedLyricsRect);
begin
  if not HasTarget then
  begin
    Target := Value;
    HasTarget := True;
    Exit;
  end;
  Target.Left := Min(Target.Left, Value.Left);
  Target.Top := Min(Target.Top, Value.Top);
  Target.Right := Max(Target.Right, Value.Right);
  Target.Bottom := Max(Target.Bottom, Value.Bottom);
end;

function ResolveLineLyricsGeometry(DC: HDC; Width, Height: Integer;
  const PlainText: string; BaseFont, RubyFont: HFONT;
  BaseCharacterSpacing, RubyCharacterSpacing, RubyGap: Integer;
  PositionX, PositionY: Integer;
  const Units: TResolvedLyricsDisplayUnits;
  out Layout: TResolvedLyricsDisplayLayout): Boolean;
var
  AnyRuby: Boolean;
  BaseHeight: Integer;
  BaseWidth: Integer;
  BaseX: Integer;
  BaseY: Integer;
  GroupHasBounds: Boolean;
  OldCharacterSpacing: Integer;
  OldFont: HGDIOBJ;
  PrefixText: string;
  PrefixWidth: Integer;
  RubyHeight: Integer;
  RubyWidth: Integer;
  RubyX: Integer;
  RubyY: Integer;
  UnitIndex: Integer;
  UnitText: string;
  UnitWidth: Integer;
begin
  Result := False;
  Layout := Default(TResolvedLyricsDisplayLayout);
  Layout.Units := Units;
  if (BaseFont = 0) or (RubyFont = 0) then
    Exit;

  AnyRuby := False;
  for UnitIndex := 0 to High(Layout.Units) do
    if Layout.Units[UnitIndex].HasRuby then
    begin
      AnyRuby := True;
      Break;
    end;

  BaseHeight := 0;
  RubyHeight := 0;
  if Length(Layout.Units) > 0 then
  begin
    BaseHeight := Layout.Units[0].Base.Style.FontHeight;
    RubyHeight := Layout.Units[0].Ruby.Style.FontHeight;
  end;
  OldFont := SelectObject(DC, BaseFont);
  OldCharacterSpacing := GetTextCharacterExtra(DC);
  try
    SetTextCharacterExtra(DC, BaseCharacterSpacing);
    BaseWidth := MeasureTextWidth(DC, PlainText);
    BaseX := (Width - BaseWidth) div 2 + PositionX;
    if not AnyRuby then
      BaseY := (Height - BaseHeight) div 2 + PositionY
    else
      BaseY := (Height - (RubyHeight + RubyGap + BaseHeight)) div 2 +
        RubyHeight + RubyGap + PositionY;
    RubyY := BaseY - RubyGap - RubyHeight;

    for UnitIndex := 0 to High(Layout.Units) do
    begin
      PrefixText := Copy(PlainText, 1,
        Layout.Units[UnitIndex].Base.SourceStart - 1);
      UnitText := Layout.Units[UnitIndex].Base.Text;
      SelectObject(DC, BaseFont);
      SetTextCharacterExtra(DC, BaseCharacterSpacing);
      PrefixWidth := MeasureTextWidth(DC, PrefixText);
      if (PrefixText <> '') and (UnitText <> '') then
        Inc(PrefixWidth, BaseCharacterSpacing);
      UnitWidth := MeasureTextWidth(DC, UnitText);

      Layout.Units[UnitIndex].Base.OriginX := BaseX + PrefixWidth;
      Layout.Units[UnitIndex].Base.OriginY := BaseY;
      Layout.Units[UnitIndex].Base.Bounds.Left :=
        Layout.Units[UnitIndex].Base.OriginX;
      Layout.Units[UnitIndex].Base.Bounds.Top := BaseY;
      Layout.Units[UnitIndex].Base.Bounds.Right :=
        Layout.Units[UnitIndex].Base.OriginX + UnitWidth;
      Layout.Units[UnitIndex].Base.Bounds.Bottom := BaseY + BaseHeight;
      Layout.Units[UnitIndex].PivotX :=
        (Layout.Units[UnitIndex].Base.Bounds.Left +
        Layout.Units[UnitIndex].Base.Bounds.Right) * 0.5;
      Layout.Units[UnitIndex].PivotY :=
        (Layout.Units[UnitIndex].Base.Bounds.Top +
        Layout.Units[UnitIndex].Base.Bounds.Bottom) * 0.5;
      Layout.Units[UnitIndex].Bounds :=
        Layout.Units[UnitIndex].Base.Bounds;
      GroupHasBounds := True;

      if Layout.Units[UnitIndex].HasRuby then
      begin
        SelectObject(DC, RubyFont);
        SetTextCharacterExtra(DC, RubyCharacterSpacing);
        RubyWidth := MeasureTextWidth(DC,
          Layout.Units[UnitIndex].Ruby.Text);
        RubyX := Round(Layout.Units[UnitIndex].Base.OriginX) +
          (UnitWidth - RubyWidth) div 2;
        Layout.Units[UnitIndex].Ruby.OriginX := RubyX;
        Layout.Units[UnitIndex].Ruby.OriginY := RubyY;
        Layout.Units[UnitIndex].Ruby.Bounds.Left := RubyX;
        Layout.Units[UnitIndex].Ruby.Bounds.Top := RubyY;
        Layout.Units[UnitIndex].Ruby.Bounds.Right := RubyX + RubyWidth;
        Layout.Units[UnitIndex].Ruby.Bounds.Bottom := RubyY + RubyHeight;
        IncludeResolvedRect(Layout.Units[UnitIndex].Bounds,
          GroupHasBounds, Layout.Units[UnitIndex].Ruby.Bounds);
      end;
      IncludeResolvedRect(Layout.Bounds, Layout.HasBounds,
        Layout.Units[UnitIndex].Bounds);
    end;
    Result := True;
  finally
    SetTextCharacterExtra(DC, OldCharacterSpacing);
    SelectObject(DC, OldFont);
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

function HasResolvedRuby(const Units: TResolvedLyricsDisplayUnits): Boolean;
var
  UnitIndex: Integer;
begin
  for UnitIndex := 0 to High(Units) do
    if Units[UnitIndex].HasRuby then
      Exit(True);
  Result := False;
end;

function MeasureBaseProgressWidth(
  const Units: TResolvedLyricsDisplayUnits; BaseX: Single;
  ProgressUnits: Double; Effect: TLyricsUnitDisplayEffect): Integer;
var
  State: TLyricsUnitEffectState;
  UnitIndex: Integer;
  UnitWidth: Single;
begin
  Result := 0;
  for UnitIndex := 0 to High(Units) do
  begin
    ResolveLyricsUnitEffect(Effect,
      GetDisplayUnitProgress(Units, UnitIndex, ProgressUnits), State);
    if State.AfterProgress <= 0 then
      Break;
    UnitWidth := Units[UnitIndex].Base.Bounds.Right -
      Units[UnitIndex].Base.Bounds.Left;
    Result := Round(Units[UnitIndex].Base.Bounds.Left - BaseX +
      UnitWidth * State.AfterProgress);
    if State.AfterProgress < 1 then
      Break;
  end;
end;

procedure DrawParsedLyrics(DC: HDC; Width, Height: Integer; const Source: string;
  ProgressUnits: Double; const Settings: TLyricsRenderSettings;
  PositionX, PositionY: Integer);
var
  BaseFont: HFONT;
  BaseFontHeight: Integer;
  BaseCharacterSpacing: Integer;
  DefaultBaseStyle: TResolvedLyricsStyle;
  DefaultRubyStyle: TResolvedLyricsStyle;
  EmptyPlacements: TDisplayPlacementItems;
  Effect: TLyricsUnitDisplayEffect;
  EffectState: TLyricsUnitEffectState;
  BaseProgressWidth: Integer;
  BaseX: Integer;
  BaseY: Integer;
  ClipState: Integer;
  Layout: TResolvedLyricsDisplayLayout;
  OldFont: HGDIOBJ;
  OldCharacterSpacing: Integer;
  PlainText: string;
  RubyFont: HFONT;
  RubyFontHeight: Integer;
  RubyGap: Integer;
  RubySpans: TLyricsRubySpans;
  RubyWidth: Integer;
  RubyX: Integer;
  RubyY: Integer;
  UnitIndex: Integer;
  UnitProgress: Double;
  Units: TLyricsDisplayUnits;
  ResolvedUnits: TResolvedLyricsDisplayUnits;
begin
  DefaultBaseStyle := ResolvedStyleFromSettings(Settings, False);
  DefaultRubyStyle := ResolvedStyleFromSettings(Settings, True);
  Effect := UnitDisplayEffectFromType(Settings.DisplayType);
  if not BuildResolvedLyricsDisplayUnits(Source, DefaultBaseStyle,
    DefaultRubyStyle, EmptyPlacements, False, PlainText, RubySpans,
    Units, ResolvedUnits) then
    Exit;
  BaseFontHeight := EnsureRange(Settings.BaseFontHeight,
    MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  RubyFontHeight := EnsureRange(Settings.RubyFontHeight,
    MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  RubyGap := EnsureRange(DEFAULT_RUBY_GAP + Settings.RubyGapAdjustment,
    MIN_RUBY_GAP, MAX_RUBY_GAP);
  BaseCharacterSpacing := EnsureRange(Settings.BaseCharacterSpacing,
    MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
  BaseFont := CreateLyricsFont(Settings.BaseFontName, BaseFontHeight,
    Settings.BaseBold, Settings.BaseItalic, Settings.BaseUnderline,
    Settings.BaseStrikeOut);
  RubyFont := CreateLyricsFont(Settings.RubyFontName, RubyFontHeight,
    Settings.RubyBold, Settings.RubyItalic, Settings.RubyUnderline,
    Settings.RubyStrikeOut);
  if (BaseFont = 0) or (RubyFont = 0) then
  begin
    if BaseFont <> 0 then
      DeleteObject(BaseFont);
    if RubyFont <> 0 then
      DeleteObject(RubyFont);
    Exit;
  end;
  try
    if not ResolveLineLyricsGeometry(DC, Width, Height, PlainText,
      BaseFont, RubyFont, BaseCharacterSpacing,
      EnsureRange(Settings.RubyCharacterSpacing,
        MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING),
      RubyGap, PositionX, PositionY, ResolvedUnits, Layout) then
      Exit;
    ResolvedUnits := Layout.Units;
    if Length(ResolvedUnits) = 0 then
      Exit;

    OldFont := SelectObject(DC, BaseFont);
    OldCharacterSpacing := GetTextCharacterExtra(DC);
    SetTextCharacterExtra(DC, BaseCharacterSpacing);
    BaseX := Round(ResolvedUnits[0].Base.OriginX);
    BaseY := Round(ResolvedUnits[0].Base.OriginY);
    ResolveLyricsUnitEffect(Effect, 0, EffectState);
    if EffectState.DrawBefore then
    begin
      SetTextColor(DC, LyricsColorToColorRef(Settings.BeforeColor));
      TextOutW(DC, BaseX, BaseY, PWideChar(PlainText), Length(PlainText));
    end;

    if HasResolvedRuby(ResolvedUnits) then
    begin
      SelectObject(DC, RubyFont);
      SetTextCharacterExtra(DC, EnsureRange(Settings.RubyCharacterSpacing,
        MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING));
      for UnitIndex := 0 to High(ResolvedUnits) do
      begin
        if not ResolvedUnits[UnitIndex].HasRuby then
          Continue;
        SelectObject(DC, RubyFont);
        SetTextCharacterExtra(DC, EnsureRange(
          Settings.RubyCharacterSpacing, MIN_CHARACTER_SPACING,
          MAX_CHARACTER_SPACING));
        RubyX := Round(ResolvedUnits[UnitIndex].Ruby.OriginX);
        RubyY := Round(ResolvedUnits[UnitIndex].Ruby.OriginY);
        RubyWidth := Round(ResolvedUnits[UnitIndex].Ruby.Bounds.Right -
          ResolvedUnits[UnitIndex].Ruby.Bounds.Left);
        UnitProgress := GetDisplayUnitProgress(ResolvedUnits, UnitIndex,
          ProgressUnits);
        ResolveLyricsUnitEffect(Effect, UnitProgress, EffectState);
        if EffectState.DrawBefore then
        begin
          SetTextColor(DC, LyricsColorToColorRef(Settings.BeforeColor));
          TextOutW(DC, RubyX, RubyY,
            PWideChar(ResolvedUnits[UnitIndex].Ruby.Text),
            Length(ResolvedUnits[UnitIndex].Ruby.Text));
        end;

        if EffectState.AfterProgress > 0 then
        begin
          ClipState := SaveDC(DC);
          try
            IntersectClipRect(DC, RubyX, RubyY,
              RubyX + Round(RubyWidth * EffectState.AfterProgress),
              RubyY + RubyFontHeight);
            SetTextColor(DC, LyricsColorToColorRef(Settings.AfterColor));
            TextOutW(DC, RubyX, RubyY,
              PWideChar(ResolvedUnits[UnitIndex].Ruby.Text),
              Length(ResolvedUnits[UnitIndex].Ruby.Text));
          finally
            RestoreDC(DC, ClipState);
          end;
        end;
      end;
    end;

    SelectObject(DC, BaseFont);
    SetTextCharacterExtra(DC, BaseCharacterSpacing);
    BaseProgressWidth := MeasureBaseProgressWidth(ResolvedUnits, BaseX,
      ProgressUnits, Effect);
    if BaseProgressWidth > 0 then
    begin
      ClipState := SaveDC(DC);
      try
        IntersectClipRect(DC, BaseX, BaseY, BaseX + BaseProgressWidth,
          BaseY + BaseFontHeight);
        SetTextColor(DC, LyricsColorToColorRef(Settings.AfterColor));
        TextOutW(DC, BaseX, BaseY, PWideChar(PlainText), Length(PlainText));
      finally
        RestoreDC(DC, ClipState);
      end;
    end;
    SetTextCharacterExtra(DC, OldCharacterSpacing);
    SelectObject(DC, OldFont);
  finally
    DeleteObject(RubyFont);
    DeleteObject(BaseFont);
  end;
end;

function ResolveCachedLyricsFont(var Cache: TLyricsFontCache;
  const FontName: string; FontHeight: Integer;
  Bold, Italic, Underline, StrikeOut: Boolean): HFONT;
var
  I: Integer;
begin
  for I := 0 to High(Cache) do
    if SameText(Cache[I].FontName, FontName) and
      (Cache[I].FontHeight = FontHeight) and
      (Cache[I].Bold = Bold) and
      (Cache[I].Italic = Italic) and
      (Cache[I].Underline = Underline) and
      (Cache[I].StrikeOut = StrikeOut) then
      Exit(Cache[I].Handle);
  Result := CreateLyricsFont(FontName, FontHeight, Bold, Italic,
    Underline, StrikeOut);
  if Result = 0 then
    Exit;
  SetLength(Cache, Length(Cache) + 1);
  Cache[High(Cache)].FontName := FontName;
  Cache[High(Cache)].FontHeight := FontHeight;
  Cache[High(Cache)].Bold := Bold;
  Cache[High(Cache)].Italic := Italic;
  Cache[High(Cache)].Underline := Underline;
  Cache[High(Cache)].StrikeOut := StrikeOut;
  Cache[High(Cache)].Handle := Result;
end;

procedure FreeLyricsFontCache(var Cache: TLyricsFontCache);
var
  I: Integer;
begin
  for I := 0 to High(Cache) do
    if Cache[I].Handle <> 0 then
      DeleteObject(Cache[I].Handle);
  Cache := nil;
end;

procedure DrawFreePlacementLyrics(DC: HDC; Width, Height: Integer;
  const Source: string; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  const Placements: TDisplayPlacementItems;
  PositionX, PositionY: Integer);
var
  BaseFont: HFONT;
  BaseFontCache: TLyricsFontCache;
  BaseBold: Boolean;
  BaseItalic: Boolean;
  BaseUnderline: Boolean;
  BaseStrikeOut: Boolean;
  BaseCharacterSpacing: Integer;
  BaseFontHeight: Integer;
  BaseFontName: string;
  BaseText: string;
  BaseWidth: Integer;
  BaseX: Integer;
  BaseY: Integer;
  ClipState: Integer;
  DefaultBaseStyle: TResolvedLyricsStyle;
  DefaultRubyStyle: TResolvedLyricsStyle;
  Effect: TLyricsUnitDisplayEffect;
  EffectState: TLyricsUnitEffectState;
  GroupHasBounds: Boolean;
  Layout: TResolvedLyricsDisplayLayout;
  BeforeColor: TLyricsRenderColor;
  AfterColor: TLyricsRenderColor;
  OldCharacterSpacing: Integer;
  OldFont: HGDIOBJ;
  PlainText: string;
  RubyFont: HFONT;
  RubyFontCache: TLyricsFontCache;
  RubyBold: Boolean;
  RubyItalic: Boolean;
  RubyUnderline: Boolean;
  RubyStrikeOut: Boolean;
  RubyFontHeight: Integer;
  RubyFontName: string;
  RubyGap: Integer;
  RubyCharacterSpacing: Integer;
  RubyOffsetX: Integer;
  RubyOffsetY: Integer;
  RubySpans: TLyricsRubySpans;
  RubyText: string;
  RubyWidth: Integer;
  RubyX: Integer;
  RubyY: Integer;
  UnitIndex: Integer;
  UnitProgress: Double;
  UnitState: Integer;
  Units: TLyricsDisplayUnits;
  ResolvedUnits: TResolvedLyricsDisplayUnits;
  WorldTransform: TXForm;
begin
  DefaultBaseStyle := ResolvedStyleFromSettings(Settings, False);
  DefaultRubyStyle := ResolvedStyleFromSettings(Settings, True);
  Effect := UnitDisplayEffectFromType(Settings.DisplayType);
  if not BuildResolvedLyricsDisplayUnits(Source, DefaultBaseStyle,
    DefaultRubyStyle, Placements, True, PlainText, RubySpans, Units,
    ResolvedUnits) then
    Exit;
  Layout := Default(TResolvedLyricsDisplayLayout);
  Layout.Units := ResolvedUnits;
  ResolvedUnits := Layout.Units;

  BaseFontHeight := EnsureRange(Settings.BaseFontHeight,
    MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  RubyFontHeight := EnsureRange(Settings.RubyFontHeight,
    MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  RubyGap := EnsureRange(DEFAULT_RUBY_GAP + Settings.RubyGapAdjustment,
    MIN_RUBY_GAP, MAX_RUBY_GAP);
  BaseFont := ResolveCachedLyricsFont(BaseFontCache,
    Settings.BaseFontName, BaseFontHeight,
    Settings.BaseBold, Settings.BaseItalic, Settings.BaseUnderline,
    Settings.BaseStrikeOut);
  RubyFont := ResolveCachedLyricsFont(RubyFontCache,
    Settings.RubyFontName, RubyFontHeight,
    Settings.RubyBold, Settings.RubyItalic, Settings.RubyUnderline,
    Settings.RubyStrikeOut);
  if (BaseFont = 0) or (RubyFont = 0) then
  begin
    FreeLyricsFontCache(BaseFontCache);
    FreeLyricsFontCache(RubyFontCache);
    Exit;
  end;
  try
    OldFont := SelectObject(DC, BaseFont);
    OldCharacterSpacing := GetTextCharacterExtra(DC);
    SetBkMode(DC, TRANSPARENT);
    for UnitIndex := 0 to High(Units) do
    begin
      BaseFontName := ResolvedUnits[UnitIndex].Base.Style.FontName;
      RubyFontName := ResolvedUnits[UnitIndex].Ruby.Style.FontName;
      BeforeColor := CardinalToLyricsColor(
        ResolvedUnits[UnitIndex].Base.Style.BeforeColor);
      AfterColor := CardinalToLyricsColor(
        ResolvedUnits[UnitIndex].Base.Style.AfterColor);
      BaseFontHeight := ResolvedUnits[UnitIndex].Base.Style.FontHeight;
      RubyFontHeight := ResolvedUnits[UnitIndex].Ruby.Style.FontHeight;
      BaseBold := (ResolvedUnits[UnitIndex].Base.Style.FontStyle and 1) <> 0;
      BaseItalic := (ResolvedUnits[UnitIndex].Base.Style.FontStyle and 2) <> 0;
      BaseUnderline := (ResolvedUnits[UnitIndex].Base.Style.FontStyle and 4) <> 0;
      BaseStrikeOut := (ResolvedUnits[UnitIndex].Base.Style.FontStyle and 8) <> 0;
      RubyBold := (ResolvedUnits[UnitIndex].Ruby.Style.FontStyle and 1) <> 0;
      RubyItalic := (ResolvedUnits[UnitIndex].Ruby.Style.FontStyle and 2) <> 0;
      RubyUnderline := (ResolvedUnits[UnitIndex].Ruby.Style.FontStyle and 4) <> 0;
      RubyStrikeOut := (ResolvedUnits[UnitIndex].Ruby.Style.FontStyle and 8) <> 0;
      BaseCharacterSpacing :=
        ResolvedUnits[UnitIndex].Base.Style.CharacterSpacing;
      RubyCharacterSpacing :=
        ResolvedUnits[UnitIndex].Ruby.Style.CharacterSpacing;
      RubyOffsetX := ResolvedUnits[UnitIndex].Ruby.OffsetX;
      RubyOffsetY := ResolvedUnits[UnitIndex].Ruby.OffsetY;
      BaseFont := ResolveCachedLyricsFont(BaseFontCache,
        BaseFontName, BaseFontHeight, BaseBold, BaseItalic,
        BaseUnderline, BaseStrikeOut);
      RubyFont := ResolveCachedLyricsFont(RubyFontCache,
        RubyFontName, RubyFontHeight, RubyBold, RubyItalic,
        RubyUnderline, RubyStrikeOut);
      if (BaseFont = 0) or (RubyFont = 0) then
        Continue;
      UnitState := SaveDC(DC);
      if UnitState = 0 then
        Continue;
      SetGraphicsMode(DC, GM_ADVANCED);
      FillChar(WorldTransform, SizeOf(WorldTransform), 0);
      ResolvedUnits[UnitIndex].PivotX := Width * 0.5 +
        ResolvedUnits[UnitIndex].X + PositionX;
      ResolvedUnits[UnitIndex].PivotY := Height * 0.5 +
        ResolvedUnits[UnitIndex].Y + PositionY;
      WorldTransform.eM11 := ResolvedUnits[UnitIndex].ScaleX;
      WorldTransform.eM22 := ResolvedUnits[UnitIndex].ScaleY;
      WorldTransform.eDx := ResolvedUnits[UnitIndex].PivotX;
      WorldTransform.eDy := ResolvedUnits[UnitIndex].PivotY;
      if not SetWorldTransform(DC, WorldTransform) then
      begin
        RestoreDC(DC, UnitState);
        Continue;
      end;
      SelectObject(DC, BaseFont);
      SetTextCharacterExtra(DC, BaseCharacterSpacing);
      BaseText := ResolvedUnits[UnitIndex].Base.Text;
      BaseWidth := MeasureTextWidth(DC, BaseText);
      BaseX := -BaseWidth div 2;
      // Placement Y identifies the vertical center of the base text.
      // Ruby extends upward without moving the base-text bottom edge.
      BaseY := -BaseFontHeight div 2;
      ResolvedUnits[UnitIndex].Base.OriginX :=
        ResolvedUnits[UnitIndex].PivotX +
        BaseX * ResolvedUnits[UnitIndex].ScaleX;
      ResolvedUnits[UnitIndex].Base.OriginY :=
        ResolvedUnits[UnitIndex].PivotY +
        BaseY * ResolvedUnits[UnitIndex].ScaleY;
      ResolvedUnits[UnitIndex].Base.Bounds.Left :=
        ResolvedUnits[UnitIndex].Base.OriginX;
      ResolvedUnits[UnitIndex].Base.Bounds.Top :=
        ResolvedUnits[UnitIndex].Base.OriginY;
      ResolvedUnits[UnitIndex].Base.Bounds.Right :=
        ResolvedUnits[UnitIndex].PivotX +
        (BaseX + BaseWidth) * ResolvedUnits[UnitIndex].ScaleX;
      ResolvedUnits[UnitIndex].Base.Bounds.Bottom :=
        ResolvedUnits[UnitIndex].PivotY +
        (BaseY + BaseFontHeight) * ResolvedUnits[UnitIndex].ScaleY;
      ResolvedUnits[UnitIndex].Bounds :=
        ResolvedUnits[UnitIndex].Base.Bounds;
      GroupHasBounds := True;
      UnitProgress := GetDisplayUnitProgress(ResolvedUnits, UnitIndex,
        ProgressUnits);
      ResolveLyricsUnitEffect(Effect, UnitProgress, EffectState);
      if EffectState.DrawBefore then
      begin
        SetTextColor(DC, LyricsColorToColorRef(BeforeColor));
        TextOutW(DC, BaseX, BaseY, PWideChar(BaseText), Length(BaseText));
      end;

      if EffectState.AfterProgress > 0 then
      begin
        ClipState := SaveDC(DC);
        try
          IntersectClipRect(DC, BaseX, BaseY,
            BaseX + Round(BaseWidth * EffectState.AfterProgress),
            BaseY + BaseFontHeight);
          SetTextColor(DC, LyricsColorToColorRef(AfterColor));
          TextOutW(DC, BaseX, BaseY, PWideChar(BaseText),
            Length(BaseText));
        finally
          RestoreDC(DC, ClipState);
        end;
      end;

      if ResolvedUnits[UnitIndex].HasRuby then
      begin
        RubyText := ResolvedUnits[UnitIndex].Ruby.Text;
        SelectObject(DC, RubyFont);
        SetTextCharacterExtra(DC, RubyCharacterSpacing);
        RubyWidth := MeasureTextWidth(DC, RubyText);
        RubyX := -RubyWidth div 2 + RubyOffsetX;
        RubyY := BaseY - RubyGap - RubyFontHeight + RubyOffsetY;
        ResolvedUnits[UnitIndex].Ruby.OriginX :=
          ResolvedUnits[UnitIndex].PivotX +
          RubyX * ResolvedUnits[UnitIndex].ScaleX;
        ResolvedUnits[UnitIndex].Ruby.OriginY :=
          ResolvedUnits[UnitIndex].PivotY +
          RubyY * ResolvedUnits[UnitIndex].ScaleY;
        ResolvedUnits[UnitIndex].Ruby.Bounds.Left :=
          ResolvedUnits[UnitIndex].Ruby.OriginX;
        ResolvedUnits[UnitIndex].Ruby.Bounds.Top :=
          ResolvedUnits[UnitIndex].Ruby.OriginY;
        ResolvedUnits[UnitIndex].Ruby.Bounds.Right :=
          ResolvedUnits[UnitIndex].PivotX +
          (RubyX + RubyWidth) * ResolvedUnits[UnitIndex].ScaleX;
        ResolvedUnits[UnitIndex].Ruby.Bounds.Bottom :=
          ResolvedUnits[UnitIndex].PivotY +
          (RubyY + RubyFontHeight) * ResolvedUnits[UnitIndex].ScaleY;
        IncludeResolvedRect(ResolvedUnits[UnitIndex].Bounds,
          GroupHasBounds, ResolvedUnits[UnitIndex].Ruby.Bounds);
        if EffectState.DrawBefore then
        begin
          SetTextColor(DC, LyricsColorToColorRef(BeforeColor));
          TextOutW(DC, RubyX, RubyY, PWideChar(RubyText),
            Length(RubyText));
        end;
        if EffectState.AfterProgress > 0 then
        begin
          ClipState := SaveDC(DC);
          try
            IntersectClipRect(DC, RubyX, RubyY,
              RubyX + Round(RubyWidth * EffectState.AfterProgress),
              RubyY + RubyFontHeight);
            SetTextColor(DC, LyricsColorToColorRef(AfterColor));
            TextOutW(DC, RubyX, RubyY, PWideChar(RubyText),
              Length(RubyText));
          finally
            RestoreDC(DC, ClipState);
          end;
        end;
      end;
      IncludeResolvedRect(Layout.Bounds, Layout.HasBounds,
        ResolvedUnits[UnitIndex].Bounds);
      RestoreDC(DC, UnitState);
    end;
    SetTextCharacterExtra(DC, OldCharacterSpacing);
    SelectObject(DC, OldFont);
  finally
    FreeLyricsFontCache(RubyFontCache);
    FreeLyricsFontCache(BaseFontCache);
  end;
end;

function RenderLocked(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  const Placements: TDisplayPlacementItems; FreePlacement: Boolean;
  PositionX, PositionY, Width, Height: Integer): Boolean;
var
  Bitmap: HBITMAP;
  BitmapInfo: TBitmapInfo;
  Bits: Pointer;
  Buffer: PPIXEL_RGBA;
  DC: HDC;
  MaskBitmap: HBITMAP;
  MaskBits: Pointer;
  MaskDC: HDC;
  MaskOldBitmap: HGDIOBJ;
  MaskSettings: TLyricsRenderSettings;
  OldBitmap: HGDIOBJ;
  PixelCount: NativeInt;
begin
  Result := False;
  PixelCount := NativeInt(Width) * Height;
  GetMem(Buffer, PixelCount * SizeOf(TPIXEL_RGBA));
  try
    FillChar(Buffer^, PixelCount * SizeOf(TPIXEL_RGBA), 0);

    // 空文字でも透明画像を確定し、直前フレームの歌詞を残さない。
    if (Lyrics = nil) or (Lyrics^ = #0) then
    begin
      Video^.SetImageData(Buffer, Width, Height);
      Exit(True);
    end;

    FillChar(BitmapInfo, SizeOf(BitmapInfo), 0);
    BitmapInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
    BitmapInfo.bmiHeader.biWidth := Width;
    BitmapInfo.bmiHeader.biHeight := -Height;
    BitmapInfo.bmiHeader.biPlanes := 1;
    BitmapInfo.bmiHeader.biBitCount := 32;
    BitmapInfo.bmiHeader.biCompression := BI_RGB;

    Bits := nil;
    Bitmap := CreateDIBSection(0, BitmapInfo, DIB_RGB_COLORS, Bits, 0, 0);
    if (Bitmap = 0) or (Bits = nil) then
      Exit;
    try
      FillChar(Bits^, PixelCount * 4, 0);
      MaskBits := nil;
      MaskBitmap := CreateDIBSection(0, BitmapInfo, DIB_RGB_COLORS,
        MaskBits, 0, 0);
      if (MaskBitmap = 0) or (MaskBits = nil) then
        Exit;
      try
        FillChar(MaskBits^, PixelCount * 4, 0);
        DC := CreateCompatibleDC(0);
        MaskDC := CreateCompatibleDC(0);
        if (DC = 0) or (MaskDC = 0) then
        begin
          if DC <> 0 then
            DeleteDC(DC);
          if MaskDC <> 0 then
            DeleteDC(MaskDC);
          Exit;
        end;
        try
          OldBitmap := SelectObject(DC, Bitmap);
          MaskOldBitmap := SelectObject(MaskDC, MaskBitmap);
          SetBkMode(DC, TRANSPARENT);
          SetBkMode(MaskDC, TRANSPARENT);
          if FreePlacement then
            DrawFreePlacementLyrics(DC, Width, Height, string(Lyrics),
              ProgressUnits, Settings, Placements, PositionX, PositionY)
          else
            DrawParsedLyrics(DC, Width, Height, string(Lyrics),
              ProgressUnits, Settings, PositionX, PositionY);
          MaskSettings := Settings;
          MaskSettings.BeforeColor.R := 255;
          MaskSettings.BeforeColor.G := 255;
          MaskSettings.BeforeColor.B := 255;
          MaskSettings.AfterColor := MaskSettings.BeforeColor;
          if FreePlacement then
            DrawFreePlacementLyrics(MaskDC, Width, Height, string(Lyrics),
              ProgressUnits, MaskSettings, Placements, PositionX, PositionY)
          else
            DrawParsedLyrics(MaskDC, Width, Height, string(Lyrics),
              ProgressUnits, MaskSettings, PositionX, PositionY);
          SelectObject(MaskDC, MaskOldBitmap);
          SelectObject(DC, OldBitmap);
        finally
          DeleteDC(MaskDC);
          DeleteDC(DC);
        end;

        ConvertDibToRgba(Bits, MaskBits, Buffer, PixelCount,
          Settings.Opacity);
        Video^.SetImageData(Buffer, Width, Height);
        Result := True;
      finally
        DeleteObject(MaskBitmap);
      end;
    finally
      DeleteObject(Bitmap);
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
begin
  if RendererInitialized then
    Exit;
  InitializeCriticalSection(RendererLock);
  RendererInitialized := True;
end;

procedure FinalizeLyricsRenderer;
begin
  if not RendererInitialized then
    Exit;
  DeleteCriticalSection(RendererLock);
  RendererInitialized := False;
end;

end.
