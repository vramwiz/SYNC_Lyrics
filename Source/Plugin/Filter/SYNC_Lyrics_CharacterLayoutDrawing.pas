unit SYNC_Lyrics_CharacterLayoutDrawing;

// Selection-frame drawing helpers for the per-character layout editor.

interface

uses
  System.Types,
  Vcl.Graphics,
  SYNC_Lyrics_CharacterLayoutInteraction;

function CharacterLayoutSelectionColor(
  Mode: TCharacterLayoutSelectionMode): TColor;
procedure DrawCharacterLayoutSpacingHandles(Canvas: TCanvas;
  const Bounds: TRect; IncludeRubyMoveHandle: Boolean);
procedure DrawCharacterLayoutResizeHandles(Canvas: TCanvas;
  const Bounds: TRect);

implementation

function CharacterLayoutSelectionColor(
  Mode: TCharacterLayoutSelectionMode): TColor;
begin
  case Mode of
    clsmCharacterSpacing:
      Result := clAqua;
    clsmRuby:
      Result := clFuchsia;
  else
    Result := clYellow;
  end;
end;

procedure DrawCharacterLayoutSpacingHandles(Canvas: TCanvas;
  const Bounds: TRect; IncludeRubyMoveHandle: Boolean);
const
  HANDLE_RADIUS = 5;
var
  CenterX: Integer;
  CenterY: Integer;
begin
  CenterX := (Bounds.Left + Bounds.Right) div 2;
  CenterY := (Bounds.Top + Bounds.Bottom) div 2;
  Canvas.Brush.Style := bsSolid;
  if IncludeRubyMoveHandle then
    Canvas.Brush.Color := clFuchsia
  else
    Canvas.Brush.Color := clAqua;
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Width := 1;
  Canvas.Rectangle(
    Bounds.Left - HANDLE_RADIUS, CenterY - HANDLE_RADIUS,
    Bounds.Left + HANDLE_RADIUS + 1, CenterY + HANDLE_RADIUS + 1);
  Canvas.Rectangle(
    Bounds.Right - HANDLE_RADIUS, CenterY - HANDLE_RADIUS,
    Bounds.Right + HANDLE_RADIUS + 1, CenterY + HANDLE_RADIUS + 1);
  if IncludeRubyMoveHandle then
    Canvas.Rectangle(
      CenterX - HANDLE_RADIUS, Bounds.Top - HANDLE_RADIUS,
      CenterX + HANDLE_RADIUS + 1, Bounds.Top + HANDLE_RADIUS + 1);
end;

procedure DrawCharacterLayoutResizeHandles(Canvas: TCanvas;
  const Bounds: TRect);
const
  HANDLE_RADIUS = 4;
var
  I: Integer;
  Points: array[0..7] of TPoint;
begin
  Points[0] := Point(Bounds.Left, Bounds.Top);
  Points[1] := Point((Bounds.Left + Bounds.Right) div 2, Bounds.Top);
  Points[2] := Point(Bounds.Right, Bounds.Top);
  Points[3] := Point(Bounds.Left, (Bounds.Top + Bounds.Bottom) div 2);
  Points[4] := Point(Bounds.Right, (Bounds.Top + Bounds.Bottom) div 2);
  Points[5] := Point(Bounds.Left, Bounds.Bottom);
  Points[6] := Point((Bounds.Left + Bounds.Right) div 2, Bounds.Bottom);
  Points[7] := Point(Bounds.Right, Bounds.Bottom);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clWhite;
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Width := 1;
  for I := Low(Points) to High(Points) do
    Canvas.Rectangle(
      Points[I].X - HANDLE_RADIUS, Points[I].Y - HANDLE_RADIUS,
      Points[I].X + HANDLE_RADIUS + 1, Points[I].Y + HANDLE_RADIUS + 1);
end;

end.
