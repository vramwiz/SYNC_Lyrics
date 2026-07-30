unit SYNC_Lyrics_CharacterLayoutInteraction;

// Mouse interaction model for the per-character free-layout editor.

interface

uses
  System.Types,
  SYNC_Lyrics_DisplaySettingsData;

type
  TCharacterLayoutDragMode = (
    cldmNone,
    cldmPan,
    cldmMove,
    cldmResizeLeft,
    cldmResizeRight,
    cldmResizeTop,
    cldmResizeBottom,
    cldmResizeTopLeft,
    cldmResizeTopRight,
    cldmResizeBottomLeft,
    cldmResizeBottomRight,
    cldmSpacingLeft,
    cldmSpacingRight,
    cldmRubyMove,
    cldmSelectionClick
  );

  TCharacterLayoutSelectionMode = (
    clsmTransform,
    clsmCharacterSpacing,
    clsmRuby
  );

function NextCharacterLayoutSelectionMode(
  Current: TCharacterLayoutSelectionMode;
  SupportsRuby: Boolean): TCharacterLayoutSelectionMode;
function HitTestCharacterLayoutModeHandle(const Bounds: TRect;
  Mode: TCharacterLayoutSelectionMode; X, Y: Integer):
  TCharacterLayoutDragMode;
procedure ApplyCharacterLayoutSpacingDrag(
  var Placements: TDisplayPlacementItems;
  const Selected: TArray<Boolean>;
  const CharacterCounts: TArray<Integer>;
  const StartPlacements: TDisplayPlacementItems;
  DragMode: TCharacterLayoutDragMode; DeltaView, ViewScale: Double);
procedure ApplyCharacterLayoutRubySpacingDrag(
  var Placements: TDisplayPlacementItems;
  const Selected: TArray<Boolean>;
  const StartPlacements: TDisplayPlacementItems;
  DragMode: TCharacterLayoutDragMode; DeltaView, ViewScale: Double);
procedure ApplyCharacterLayoutRubyMoveDrag(
  var Placements: TDisplayPlacementItems;
  const Selected: TArray<Boolean>;
  const StartPlacements: TDisplayPlacementItems;
  DeltaViewX, DeltaViewY, ViewScale: Double);

implementation

uses
  System.Math;

const
  HANDLE_HIT_RADIUS = 7;
  MIN_ITEM_SCALE = 0.05;
  MIN_ADJUSTMENT = -1024;
  MAX_ADJUSTMENT = 1024;

function NextCharacterLayoutSelectionMode(
  Current: TCharacterLayoutSelectionMode;
  SupportsRuby: Boolean): TCharacterLayoutSelectionMode;
begin
  case Current of
    clsmTransform:
      Result := clsmCharacterSpacing;
    clsmCharacterSpacing:
      if SupportsRuby then
        Result := clsmRuby
      else
        Result := clsmTransform;
  else
    Result := clsmTransform;
  end;
end;

function HitTestCharacterLayoutModeHandle(const Bounds: TRect;
  Mode: TCharacterLayoutSelectionMode; X, Y: Integer):
  TCharacterLayoutDragMode;
var
  CenterX: Integer;
  CenterY: Integer;
begin
  Result := cldmNone;
  if Mode = clsmTransform then
    Exit;
  CenterX := (Bounds.Left + Bounds.Right) div 2;
  CenterY := (Bounds.Top + Bounds.Bottom) div 2;
  if (Mode = clsmRuby) and
    (Abs(X - CenterX) <= HANDLE_HIT_RADIUS) and
    (Abs(Y - Bounds.Top) <= HANDLE_HIT_RADIUS) then
    Exit(cldmRubyMove);
  if (Abs(Y - CenterY) <= HANDLE_HIT_RADIUS) and
    (Abs(X - Bounds.Left) <= HANDLE_HIT_RADIUS) then
    Exit(cldmSpacingLeft);
  if (Abs(Y - CenterY) <= HANDLE_HIT_RADIUS) and
    (Abs(X - Bounds.Right) <= HANDLE_HIT_RADIUS) then
    Exit(cldmSpacingRight);
end;

procedure ApplyCharacterLayoutSpacingDrag(
  var Placements: TDisplayPlacementItems;
  const Selected: TArray<Boolean>;
  const CharacterCounts: TArray<Integer>;
  const StartPlacements: TDisplayPlacementItems;
  DragMode: TCharacterLayoutDragMode; DeltaView, ViewScale: Double);
var
  DeltaSpacing: Integer;
  GapCount: Integer;
  I: Integer;
  InitialSpacing: Integer;
begin
  if not (DragMode in [cldmSpacingLeft, cldmSpacingRight]) or
    (ViewScale <= 0) or
    (Length(Placements) <> Length(StartPlacements)) then
    Exit;
  for I := 0 to Min(High(Selected), High(Placements)) do
    if Selected[I] then
    begin
      if I > High(CharacterCounts) then
        Continue;
      GapCount := CharacterCounts[I] - 1;
      if GapCount <= 0 then
        Continue;
      InitialSpacing := 0;
      if StartPlacements[I].HasBaseCharacterSpacing then
        InitialSpacing := StartPlacements[I].BaseCharacterSpacing;
      // The text is drawn around its center, so moving one frame edge by D
      // requires changing the full text width by 2D. Character spacing is
      // inserted once per gap, not once per character.
      DeltaSpacing := Round((DeltaView * 2) /
        (ViewScale * Max(MIN_ITEM_SCALE, StartPlacements[I].ScaleX) *
          GapCount));
      if DragMode = cldmSpacingLeft then
        DeltaSpacing := -DeltaSpacing;
      Placements[I].BaseCharacterSpacing :=
        EnsureRange(InitialSpacing + DeltaSpacing,
          MIN_ADJUSTMENT, MAX_ADJUSTMENT);
      Placements[I].HasBaseCharacterSpacing :=
        Placements[I].BaseCharacterSpacing <> 0;
    end;
end;

procedure ApplyCharacterLayoutRubySpacingDrag(
  var Placements: TDisplayPlacementItems;
  const Selected: TArray<Boolean>;
  const StartPlacements: TDisplayPlacementItems;
  DragMode: TCharacterLayoutDragMode; DeltaView, ViewScale: Double);
var
  DeltaSpacing: Integer;
  I: Integer;
  InitialSpacing: Integer;
begin
  if not (DragMode in [cldmSpacingLeft, cldmSpacingRight]) or
    (ViewScale <= 0) or
    (Length(Placements) <> Length(StartPlacements)) then
    Exit;
  for I := 0 to Min(High(Selected), High(Placements)) do
    if Selected[I] then
    begin
      InitialSpacing := 0;
      if StartPlacements[I].HasRubyCharacterSpacing then
        InitialSpacing := StartPlacements[I].RubyCharacterSpacing;
      DeltaSpacing := Round(DeltaView /
        (ViewScale * Max(MIN_ITEM_SCALE, StartPlacements[I].ScaleX)));
      if DragMode = cldmSpacingLeft then
        DeltaSpacing := -DeltaSpacing;
      Placements[I].RubyCharacterSpacing :=
        EnsureRange(InitialSpacing + DeltaSpacing,
          MIN_ADJUSTMENT, MAX_ADJUSTMENT);
      Placements[I].HasRubyCharacterSpacing :=
        Placements[I].RubyCharacterSpacing <> 0;
    end;
end;

procedure ApplyCharacterLayoutRubyMoveDrag(
  var Placements: TDisplayPlacementItems;
  const Selected: TArray<Boolean>;
  const StartPlacements: TDisplayPlacementItems;
  DeltaViewX, DeltaViewY, ViewScale: Double);
var
  I: Integer;
  InitialOffsetX: Integer;
  InitialOffsetY: Integer;
begin
  if (ViewScale <= 0) or
    (Length(Placements) <> Length(StartPlacements)) then
    Exit;
  for I := 0 to Min(High(Selected), High(Placements)) do
    if Selected[I] then
    begin
      InitialOffsetX := 0;
      if StartPlacements[I].HasRubyOffsetX then
        InitialOffsetX := StartPlacements[I].RubyOffsetX;
      InitialOffsetY := 0;
      if StartPlacements[I].HasRubyOffsetY then
        InitialOffsetY := StartPlacements[I].RubyOffsetY;
      Placements[I].RubyOffsetX := EnsureRange(InitialOffsetX +
        Round(DeltaViewX /
          (ViewScale * Max(MIN_ITEM_SCALE, StartPlacements[I].ScaleX))),
        MIN_ADJUSTMENT, MAX_ADJUSTMENT);
      Placements[I].RubyOffsetY := EnsureRange(InitialOffsetY +
        Round(DeltaViewY /
          (ViewScale * Max(MIN_ITEM_SCALE, StartPlacements[I].ScaleY))),
        MIN_ADJUSTMENT, MAX_ADJUSTMENT);
      Placements[I].HasRubyOffsetX := Placements[I].RubyOffsetX <> 0;
      Placements[I].HasRubyOffsetY := Placements[I].RubyOffsetY <> 0;
    end;
end;

end.
