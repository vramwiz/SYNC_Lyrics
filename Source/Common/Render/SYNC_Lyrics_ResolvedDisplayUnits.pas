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
  end;

  TResolvedLyricsPart = record
    Text: string;
    SourceStart: Integer;
    SourceLength: Integer;
    OffsetX: Integer;
    OffsetY: Integer;
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
