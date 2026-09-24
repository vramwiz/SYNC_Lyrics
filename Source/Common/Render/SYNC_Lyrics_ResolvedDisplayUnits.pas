unit SYNC_Lyrics_ResolvedDisplayUnits;

// Builds mode-independent runtime units with resolved placement and inherited styles.

interface

uses
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_LyricParser;

type
  TResolvedLyricsRect = record
    Left: Single;
    Top: Single;
    Right: Single;
    Bottom: Single;
  end;

  TResolvedLyricsStyle = record
    FontName: string;
    FontHeight: Integer;
    FontStyle: Byte;
    CharacterSpacing: Integer;
    BeforeColor: Cardinal;
    AfterColor: Cardinal;
    BeforeOpacity: Byte;
    AfterOpacity: Byte;
    BeforeOutlineColor: Cardinal;
    AfterOutlineColor: Cardinal;
    BeforeOutlineOpacity: Byte;
    AfterOutlineOpacity: Byte;
    BeforeShadowColor: Cardinal;
    AfterShadowColor: Cardinal;
    BeforeShadowOpacity: Byte;
    AfterShadowOpacity: Byte;
    BeforeBlurColor: Cardinal;
    AfterBlurColor: Cardinal;
    BeforeBlurOpacity: Byte;
    AfterBlurOpacity: Byte;
    OutlineEnabled: Boolean;
    OutlineWidth: Single;
    OutlineBlur: Single;
    ShadowEnabled: Boolean;
    ShadowOffsetX: Single;
    ShadowOffsetY: Single;
    ShadowBlur: Single;
    ShadowSpread: Single;
  end;

  TResolvedLyricsPart = record
    Text: string;
    SourceStart: Integer;
    SourceLength: Integer;
    OffsetX: Integer;
    OffsetY: Integer;
    ScaleX: Single;
    ScaleY: Single;
    OriginX: Single;
    OriginY: Single;
    Bounds: TResolvedLyricsRect;
    Style: TResolvedLyricsStyle;
  end;

  TResolvedLyricsDisplayUnit = record
    Index: Integer;
    SyncUnitIndex: Integer;
    ConsumesNote: Boolean;
    X: Single;
    Y: Single;
    PivotX: Single;
    PivotY: Single;
    ScaleX: Single;
    ScaleY: Single;
    Bounds: TResolvedLyricsRect;
    Base: TResolvedLyricsPart;
    HasRuby: Boolean;
    Ruby: TResolvedLyricsPart;
  end;
  TResolvedLyricsDisplayUnits = TArray<TResolvedLyricsDisplayUnit>;

  TResolvedLyricsDisplayLayout = record
    Units: TResolvedLyricsDisplayUnits;
    HasBounds: Boolean;
    Bounds: TResolvedLyricsRect;
  end;

function BuildResolvedLyricsDisplayUnits(const Source: string;
  const DefaultBaseStyle, DefaultRubyStyle: TResolvedLyricsStyle;
  const Placements: TDisplayPlacementItems; FreePlacement: Boolean;
  out PlainText: string; out RubySpans: TLyricsRubySpans;
  out LogicalUnits: TLyricsDisplayUnits;
  out ResolvedUnits: TResolvedLyricsDisplayUnits): Boolean;

implementation

uses
  System.Math;

const
  MIN_FONT_HEIGHT = 1;
  MAX_FONT_HEIGHT = 1024;
  MIN_CHARACTER_SPACING = -1024;
  MAX_CHARACTER_SPACING = 1024;
  MIN_PLACEMENT_SCALE = 0.05;
  MAX_PLACEMENT_SCALE = 10.0;

procedure ApplyPlacementDecoration(const Placement: TDisplayPlacementItem;
  var Style: TResolvedLyricsStyle);
begin
  if Placement.HasBeforeOpacity then
    Style.BeforeOpacity := Placement.BeforeOpacity;
  if Placement.HasAfterOpacity then
    Style.AfterOpacity := Placement.AfterOpacity;
  if Placement.HasBeforeOutlineColor then
    Style.BeforeOutlineColor := Placement.BeforeOutlineColor;
  if Placement.HasAfterOutlineColor then
    Style.AfterOutlineColor := Placement.AfterOutlineColor;
  if Placement.HasBeforeOutlineOpacity then
    Style.BeforeOutlineOpacity := Placement.BeforeOutlineOpacity;
  if Placement.HasAfterOutlineOpacity then
    Style.AfterOutlineOpacity := Placement.AfterOutlineOpacity;
  if Placement.HasBeforeShadowColor then
    Style.BeforeShadowColor := Placement.BeforeShadowColor;
  if Placement.HasAfterShadowColor then
    Style.AfterShadowColor := Placement.AfterShadowColor;
  if Placement.HasBeforeShadowOpacity then
    Style.BeforeShadowOpacity := Placement.BeforeShadowOpacity;
  if Placement.HasAfterShadowOpacity then
    Style.AfterShadowOpacity := Placement.AfterShadowOpacity;
  if Placement.HasBeforeBlurColor then
    Style.BeforeBlurColor := Placement.BeforeBlurColor;
  if Placement.HasAfterBlurColor then
    Style.AfterBlurColor := Placement.AfterBlurColor;
  if Placement.HasBeforeBlurOpacity then
    Style.BeforeBlurOpacity := Placement.BeforeBlurOpacity;
  if Placement.HasAfterBlurOpacity then
    Style.AfterBlurOpacity := Placement.AfterBlurOpacity;
  if Placement.HasOutlineEnabled then
    Style.OutlineEnabled := Placement.OutlineEnabled;
  if Placement.HasOutlineWidth then
    Style.OutlineWidth := EnsureRange(Placement.OutlineWidth,
      0.0, MAX_DISPLAY_OUTLINE_WIDTH);
  if Placement.HasOutlineBlur then
    Style.OutlineBlur := EnsureRange(Placement.OutlineBlur,
      0.0, MAX_DISPLAY_DECORATION_BLUR);
  if Placement.HasShadowEnabled then
    Style.ShadowEnabled := Placement.ShadowEnabled;
  if Placement.HasShadowOffsetX then
    Style.ShadowOffsetX := EnsureRange(Placement.ShadowOffsetX,
      -MAX_DISPLAY_SHADOW_OFFSET, MAX_DISPLAY_SHADOW_OFFSET);
  if Placement.HasShadowOffsetY then
    Style.ShadowOffsetY := EnsureRange(Placement.ShadowOffsetY,
      -MAX_DISPLAY_SHADOW_OFFSET, MAX_DISPLAY_SHADOW_OFFSET);
  if Placement.HasShadowBlur then
    Style.ShadowBlur := EnsureRange(Placement.ShadowBlur,
      0.0, MAX_DISPLAY_DECORATION_BLUR);
  if Placement.HasShadowSpread then
    Style.ShadowSpread := EnsureRange(Placement.ShadowSpread,
      0.0, MAX_DISPLAY_SHADOW_SPREAD);
end;

procedure ApplyPlacementStyle(const Placement: TDisplayPlacementItem;
  var BaseStyle, RubyStyle: TResolvedLyricsStyle);
begin
  if Placement.BaseFontName <> '' then
    BaseStyle.FontName := Placement.BaseFontName;
  if Placement.RubyFontName <> '' then
    RubyStyle.FontName := Placement.RubyFontName;
  if Placement.HasBeforeColor then
  begin
    BaseStyle.BeforeColor := Placement.BeforeColor;
    RubyStyle.BeforeColor := Placement.BeforeColor;
  end;
  if Placement.HasAfterColor then
  begin
    BaseStyle.AfterColor := Placement.AfterColor;
    RubyStyle.AfterColor := Placement.AfterColor;
  end;
  if Placement.HasBaseFontHeight then
    BaseStyle.FontHeight := EnsureRange(
      Integer(Placement.BaseFontHeight), MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  if Placement.HasRubyFontHeight then
    RubyStyle.FontHeight := EnsureRange(
      Integer(Placement.RubyFontHeight), MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  if Placement.HasBaseFontStyle then
    BaseStyle.FontStyle := Placement.BaseFontStyle;
  if Placement.HasRubyFontStyle then
    RubyStyle.FontStyle := Placement.RubyFontStyle;
  if Placement.HasBaseCharacterSpacing then
    BaseStyle.CharacterSpacing := EnsureRange(
      Integer(Placement.BaseCharacterSpacing),
      MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
  if Placement.HasRubyCharacterSpacing then
    RubyStyle.CharacterSpacing := EnsureRange(
      Integer(Placement.RubyCharacterSpacing),
      MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
  ApplyPlacementDecoration(Placement, BaseStyle);
  ApplyPlacementDecoration(Placement, RubyStyle);
end;

function BuildResolvedLyricsDisplayUnits(const Source: string;
  const DefaultBaseStyle, DefaultRubyStyle: TResolvedLyricsStyle;
  const Placements: TDisplayPlacementItems; FreePlacement: Boolean;
  out PlainText: string; out RubySpans: TLyricsRubySpans;
  out LogicalUnits: TLyricsDisplayUnits;
  out ResolvedUnits: TResolvedLyricsDisplayUnits): Boolean;
var
  BaseStyle: TResolvedLyricsStyle;
  Placement: TDisplayPlacementItem;
  RubyIndex: Integer;
  RubyStyle: TResolvedLyricsStyle;
  UnitIndex: Integer;
begin
  ParseLyrics(Source, PlainText, RubySpans);
  BuildLyricsDisplayUnits(PlainText, RubySpans, LogicalUnits);
  SetLength(ResolvedUnits, 0);
  if FreePlacement and (Length(Placements) <> Length(LogicalUnits)) then
    Exit(False);

  SetLength(ResolvedUnits, Length(LogicalUnits));
  for UnitIndex := 0 to High(LogicalUnits) do
  begin
    BaseStyle := DefaultBaseStyle;
    RubyStyle := DefaultRubyStyle;
    Placement := Default(TDisplayPlacementItem);
    Placement.ScaleX := 1;
    Placement.ScaleY := 1;
    if FreePlacement then
    begin
      Placement := Placements[UnitIndex];
      ApplyPlacementStyle(Placement, BaseStyle, RubyStyle);
    end;

    ResolvedUnits[UnitIndex].Index := UnitIndex;
    ResolvedUnits[UnitIndex].SyncUnitIndex :=
      LogicalUnits[UnitIndex].SyncUnitIndex;
    ResolvedUnits[UnitIndex].ConsumesNote :=
      LogicalUnits[UnitIndex].ConsumesNote;
    ResolvedUnits[UnitIndex].X := Placement.X;
    ResolvedUnits[UnitIndex].Y := Placement.Y;
    ResolvedUnits[UnitIndex].ScaleX := EnsureRange(
      Placement.ScaleX, MIN_PLACEMENT_SCALE, MAX_PLACEMENT_SCALE);
    ResolvedUnits[UnitIndex].ScaleY := EnsureRange(
      Placement.ScaleY, MIN_PLACEMENT_SCALE, MAX_PLACEMENT_SCALE);
    ResolvedUnits[UnitIndex].Base.Text := Copy(PlainText,
      LogicalUnits[UnitIndex].BaseStart,
      LogicalUnits[UnitIndex].BaseLength);
    ResolvedUnits[UnitIndex].Base.SourceStart :=
      LogicalUnits[UnitIndex].BaseStart;
    ResolvedUnits[UnitIndex].Base.SourceLength :=
      LogicalUnits[UnitIndex].BaseLength;
    ResolvedUnits[UnitIndex].Base.Style := BaseStyle;
    ResolvedUnits[UnitIndex].Ruby.Style := RubyStyle;
    ResolvedUnits[UnitIndex].Ruby.ScaleX := 1;
    ResolvedUnits[UnitIndex].Ruby.ScaleY := 1;
    if FreePlacement then
    begin
      if Placement.RubyScaleX > 0 then
        ResolvedUnits[UnitIndex].Ruby.ScaleX := EnsureRange(
          Placement.RubyScaleX, MIN_PLACEMENT_SCALE, MAX_PLACEMENT_SCALE);
      if Placement.RubyScaleY > 0 then
        ResolvedUnits[UnitIndex].Ruby.ScaleY := EnsureRange(
          Placement.RubyScaleY, MIN_PLACEMENT_SCALE, MAX_PLACEMENT_SCALE);
    end;

    RubyIndex := LogicalUnits[UnitIndex].RubyIndex;
    ResolvedUnits[UnitIndex].HasRuby := RubyIndex >= 0;
    if RubyIndex >= 0 then
    begin
      ResolvedUnits[UnitIndex].Ruby.Text := RubySpans[RubyIndex].RubyText;
      ResolvedUnits[UnitIndex].Ruby.SourceStart :=
        RubySpans[RubyIndex].BaseStart;
      ResolvedUnits[UnitIndex].Ruby.SourceLength :=
        RubySpans[RubyIndex].BaseLength;
      if FreePlacement and Placement.HasRubyOffsetX then
        ResolvedUnits[UnitIndex].Ruby.OffsetX := EnsureRange(
          Integer(Placement.RubyOffsetX),
          MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
      if FreePlacement and Placement.HasRubyOffsetY then
        ResolvedUnits[UnitIndex].Ruby.OffsetY := EnsureRange(
          Integer(Placement.RubyOffsetY),
          MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
    end;
  end;
  Result := True;
end;

end.
