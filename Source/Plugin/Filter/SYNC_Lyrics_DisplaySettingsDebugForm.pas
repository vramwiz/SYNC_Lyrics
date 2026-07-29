unit SYNC_Lyrics_DisplaySettingsDebugForm;

// Provides the first usable free-placement editor.

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Winapi.Windows,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_LyricParser;

type
  TPlacementDragMode = (
    pdmNone,
    pdmMove,
    pdmResizeLeft,
    pdmResizeRight,
    pdmResizeTop,
    pdmResizeBottom,
    pdmResizeTopLeft,
    pdmResizeTopRight,
    pdmResizeBottomLeft,
    pdmResizeBottomRight
  );

  TFormLyricsDisplaySettingsDebug = class(TForm)
    DescriptionLabel: TLabel;
    BackgroundPaintBox: TPaintBox;
    ButtonPanel: TPanel;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    procedure BackgroundPaintBoxMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BackgroundPaintBoxMouseMove(Sender: TObject;
      Shift: TShiftState; X, Y: Integer);
    procedure BackgroundPaintBoxMouseUp(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BackgroundPaintBoxPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FBackground: TBitmap;
    FBaseFontHeight: Integer;
    FBaseFontName: string;
    FDragMode: TPlacementDragMode;
    FDragStartMouse: TPoint;
    FDragStartGroupBounds: TRectF;
    FDragStartPlacement: TDisplayPlacementItem;
    FDragStartPlacements: TDisplayPlacementItems;
    FLyrics: string;
    FPlainText: string;
    FPlacements: TDisplayPlacementItems;
    FRubyGap: Integer;
    FRubyFontHeight: Integer;
    FRubyFontName: string;
    FRubySpans: TLyricsRubySpans;
    FSelected: TArray<Boolean>;
    FSelectedIndex: Integer;
    FSelectionCurrent: TPoint;
    FSelectionStart: TPoint;
    FSelectingRectangle: Boolean;
    FUnits: TLyricsDisplayUnits;
    function BackgroundDestinationRect: TRect;
    function BackgroundScale: Double;
    procedure BuildInitialPlacements;
    procedure ClearSelection;
    function DisplayUnitBaseText(Index: Integer): string;
    function DisplayUnitBounds(Index: Integer): TRect;
    function DisplayUnitNaturalBounds(Index: Integer): TRectF;
    function DisplayUnitRubyText(Index: Integer): string;
    procedure DrawResizeHandles(const Bounds: TRect);
    procedure DrawSelectionRectangle;
    function GroupSelectionBounds: TRect;
    function GroupSelectionSceneBounds: TRectF;
    function HitTestDisplayUnit(X, Y: Integer): Integer;
    function HitTestResizeHandle(X, Y: Integer): TPlacementDragMode;
    procedure PaintDisplayUnit(Index: Integer);
    procedure ResizeSelectedElement(X, Y: Integer);
    procedure ResizeSelection(X, Y: Integer);
    procedure SelectOnly(Index: Integer);
    function SelectionCount: Integer;
    function ScenePointToScreen(X, Y: Single): TPoint;
  public
    procedure Configure(const Lyrics, BaseFontName, RubyFontName: string;
      BaseFontHeight, RubyFontHeight, RubyGapAdjustment: Integer;
      const Data: TDisplaySettingsData);
    procedure SetBackgroundRgba(const Pixels: TBytes;
      Width, Height: Integer);
    procedure SetCaptureStatus(const Value: string);
    function TryBuildSettingsData(out Data: TDisplaySettingsData): Boolean;
  end;

implementation

uses
  System.Math;

{$R *.dfm}

procedure TFormLyricsDisplaySettingsDebug.FormCreate(Sender: TObject);
begin
  FBackground := TBitmap.Create;
  FBackground.PixelFormat := pf32bit;
  FSelectedIndex := -1;
  FDragMode := pdmNone;
  DoubleBuffered := True;
end;

procedure TFormLyricsDisplaySettingsDebug.FormDestroy(Sender: TObject);
begin
  FBackground.Free;
end;

procedure TFormLyricsDisplaySettingsDebug.ClearSelection;
var
  I: Integer;
begin
  for I := 0 to High(FSelected) do
    FSelected[I] := False;
  FSelectedIndex := -1;
end;

procedure TFormLyricsDisplaySettingsDebug.SelectOnly(Index: Integer);
begin
  ClearSelection;
  if (Index >= 0) and (Index < Length(FSelected)) then
  begin
    FSelected[Index] := True;
    FSelectedIndex := Index;
  end;
end;

function TFormLyricsDisplaySettingsDebug.SelectionCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
      Inc(Result);
end;

function TFormLyricsDisplaySettingsDebug.BackgroundDestinationRect: TRect;
var
  DrawHeight: Integer;
  DrawWidth: Integer;
  Scale: Double;
begin
  Result := BackgroundPaintBox.ClientRect;
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  Scale := Min(BackgroundPaintBox.ClientWidth / FBackground.Width,
    BackgroundPaintBox.ClientHeight / FBackground.Height);
  DrawWidth := Max(1, Round(FBackground.Width * Scale));
  DrawHeight := Max(1, Round(FBackground.Height * Scale));
  Result.Left := (BackgroundPaintBox.ClientWidth - DrawWidth) div 2;
  Result.Top := (BackgroundPaintBox.ClientHeight - DrawHeight) div 2;
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

function TFormLyricsDisplaySettingsDebug.BackgroundScale: Double;
var
  Destination: TRect;
begin
  Result := 0;
  if FBackground.Width <= 0 then
    Exit;
  Destination := BackgroundDestinationRect;
  Result := Destination.Width / FBackground.Width;
end;

function TFormLyricsDisplaySettingsDebug.DisplayUnitBaseText(
  Index: Integer): string;
begin
  Result := Copy(FPlainText, FUnits[Index].BaseStart,
    FUnits[Index].BaseLength);
end;

function TFormLyricsDisplaySettingsDebug.DisplayUnitRubyText(
  Index: Integer): string;
var
  RubyIndex: Integer;
begin
  Result := '';
  RubyIndex := FUnits[Index].RubyIndex;
  if (RubyIndex >= 0) and (RubyIndex < Length(FRubySpans)) then
    Result := FRubySpans[RubyIndex].RubyText;
end;

function TFormLyricsDisplaySettingsDebug.ScenePointToScreen(
  X, Y: Single): TPoint;
var
  Destination: TRect;
  Scale: Double;
begin
  Destination := BackgroundDestinationRect;
  Scale := BackgroundScale;
  Result.X := Destination.Left +
    Round((FBackground.Width * 0.5 + X) * Scale);
  Result.Y := Destination.Top +
    Round((FBackground.Height * 0.5 + Y) * Scale);
end;

function TFormLyricsDisplaySettingsDebug.DisplayUnitBounds(
  Index: Integer): TRect;
var
  Center: TPoint;
  NaturalBounds: TRectF;
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (Index < 0) or (Index >= Length(FUnits)) or
    (Index >= Length(FPlacements)) then
    Exit;
  Scale := BackgroundScale;
  if Scale <= 0 then
    Exit;
  NaturalBounds := DisplayUnitNaturalBounds(Index);
  Center := ScenePointToScreen(FPlacements[Index].X,
    FPlacements[Index].Y);
  Result.Left := Center.X + Round(NaturalBounds.Left *
    FPlacements[Index].ScaleX * Scale) - 4;
  Result.Right := Center.X + Round(NaturalBounds.Right *
    FPlacements[Index].ScaleX * Scale) + 4;
  Result.Top := Center.Y + Round(NaturalBounds.Top *
    FPlacements[Index].ScaleY * Scale) - 4;
  Result.Bottom := Center.Y + Round(NaturalBounds.Bottom *
    FPlacements[Index].ScaleY * Scale) + 4;
end;

function TFormLyricsDisplaySettingsDebug.DisplayUnitNaturalBounds(
  Index: Integer): TRectF;
var
  BaseSize: TSize;
  RubySize: TSize;
begin
  BackgroundPaintBox.Canvas.Font.Name := FBaseFontName;
  BackgroundPaintBox.Canvas.Font.Height := -Max(1, FBaseFontHeight);
  BackgroundPaintBox.Canvas.Font.Style := [];
  BaseSize := BackgroundPaintBox.Canvas.TextExtent(
    DisplayUnitBaseText(Index));
  RubySize.cx := 0;
  RubySize.cy := 0;
  if DisplayUnitRubyText(Index) <> '' then
  begin
    BackgroundPaintBox.Canvas.Font.Name := FRubyFontName;
    BackgroundPaintBox.Canvas.Font.Height := -Max(1, FRubyFontHeight);
    RubySize := BackgroundPaintBox.Canvas.TextExtent(
      DisplayUnitRubyText(Index));
  end;
  Result.Left := -Max(8, Max(BaseSize.cx, RubySize.cx)) * 0.5;
  Result.Right := -Result.Left;
  Result.Top := -BaseSize.cy * 0.5;
  if RubySize.cy > 0 then
    Result.Top := Result.Top - RubySize.cy - FRubyGap;
  Result.Bottom := -BaseSize.cy * 0.5 + BaseSize.cy;
end;

procedure TFormLyricsDisplaySettingsDebug.PaintDisplayUnit(
  Index: Integer);
var
  BaseSize: TSize;
  BaseText: string;
  Bounds: TRect;
  Canvas: TCanvas;
  Center: TPoint;
  IdentityTransform: TXForm;
  RubySize: TSize;
  RubyText: string;
  Scale: Double;
  TextTop: Integer;
  WorldTransform: TXForm;

  procedure DrawOutlinedText(X, Y: Integer; const Text: string);
  begin
    Canvas.Font.Color := clBlack;
    Canvas.TextOut(X - 1, Y, Text);
    Canvas.TextOut(X + 1, Y, Text);
    Canvas.TextOut(X, Y - 1, Text);
    Canvas.TextOut(X, Y + 1, Text);
    Canvas.Font.Color := clWhite;
    Canvas.TextOut(X, Y, Text);
  end;

begin
  Scale := BackgroundScale;
  if Scale <= 0 then
    Exit;
  Canvas := BackgroundPaintBox.Canvas;
  Canvas.Brush.Style := bsClear;
  Center := ScenePointToScreen(FPlacements[Index].X,
    FPlacements[Index].Y);
  BaseText := DisplayUnitBaseText(Index);
  RubyText := DisplayUnitRubyText(Index);

  Canvas.Font.Name := FBaseFontName;
  Canvas.Font.Height := -Max(1, FBaseFontHeight);
  Canvas.Font.Style := [];
  BaseSize := Canvas.TextExtent(BaseText);
  RubySize.cx := 0;
  RubySize.cy := 0;
  if RubyText <> '' then
  begin
    Canvas.Font.Name := FRubyFontName;
    Canvas.Font.Height := -Max(1, FRubyFontHeight);
    RubySize := Canvas.TextExtent(RubyText);
  end;
  TextTop := -BaseSize.cy div 2;
  SetGraphicsMode(Canvas.Handle, GM_ADVANCED);
  FillChar(WorldTransform, SizeOf(WorldTransform), 0);
  WorldTransform.eM11 := Scale * FPlacements[Index].ScaleX;
  WorldTransform.eM22 := Scale * FPlacements[Index].ScaleY;
  WorldTransform.eDx := Center.X;
  WorldTransform.eDy := Center.Y;
  if SetWorldTransform(Canvas.Handle, WorldTransform) then
  begin
    try
    begin
      if RubyText <> '' then
      begin
        Canvas.Font.Name := FRubyFontName;
        Canvas.Font.Height := -Max(1, FRubyFontHeight);
        DrawOutlinedText(-RubySize.cx div 2,
          TextTop - RubySize.cy - FRubyGap, RubyText);
      end;
      Canvas.Font.Name := FBaseFontName;
      Canvas.Font.Height := -Max(1, FBaseFontHeight);
      DrawOutlinedText(-BaseSize.cx div 2, TextTop, BaseText);
    end;
    finally
      FillChar(IdentityTransform, SizeOf(IdentityTransform), 0);
      IdentityTransform.eM11 := 1;
      IdentityTransform.eM22 := 1;
      SetWorldTransform(Canvas.Handle, IdentityTransform);
    end;
  end;

  if (Index >= 0) and (Index < Length(FSelected)) and FSelected[Index] then
  begin
    Bounds := DisplayUnitBounds(Index);
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := clYellow;
    Canvas.Pen.Width := 2;
    Canvas.Rectangle(Bounds);
    if SelectionCount = 1 then
      DrawResizeHandles(Bounds);
  end;
end;

procedure TFormLyricsDisplaySettingsDebug.DrawResizeHandles(
  const Bounds: TRect);
const
  HANDLE_RADIUS = 4;
var
  Points: array[0..7] of TPoint;
  I: Integer;
begin
  Points[0] := Point(Bounds.Left, Bounds.Top);
  Points[1] := Point((Bounds.Left + Bounds.Right) div 2, Bounds.Top);
  Points[2] := Point(Bounds.Right, Bounds.Top);
  Points[3] := Point(Bounds.Left, (Bounds.Top + Bounds.Bottom) div 2);
  Points[4] := Point(Bounds.Right, (Bounds.Top + Bounds.Bottom) div 2);
  Points[5] := Point(Bounds.Left, Bounds.Bottom);
  Points[6] := Point((Bounds.Left + Bounds.Right) div 2, Bounds.Bottom);
  Points[7] := Point(Bounds.Right, Bounds.Bottom);
  BackgroundPaintBox.Canvas.Brush.Style := bsSolid;
  BackgroundPaintBox.Canvas.Brush.Color := clWhite;
  BackgroundPaintBox.Canvas.Pen.Color := clBlack;
  BackgroundPaintBox.Canvas.Pen.Width := 1;
  for I := Low(Points) to High(Points) do
    BackgroundPaintBox.Canvas.Rectangle(
      Points[I].X - HANDLE_RADIUS, Points[I].Y - HANDLE_RADIUS,
      Points[I].X + HANDLE_RADIUS + 1, Points[I].Y + HANDLE_RADIUS + 1);
end;

function TFormLyricsDisplaySettingsDebug.GroupSelectionBounds: TRect;
var
  Bounds: TRect;
  I: Integer;
  Initialized: Boolean;
begin
  Result := Rect(0, 0, 0, 0);
  Initialized := False;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      Bounds := DisplayUnitBounds(I);
      if not Initialized then
      begin
        Result := Bounds;
        Initialized := True;
      end
      else
      begin
        Result.Left := Min(Result.Left, Bounds.Left);
        Result.Top := Min(Result.Top, Bounds.Top);
        Result.Right := Max(Result.Right, Bounds.Right);
        Result.Bottom := Max(Result.Bottom, Bounds.Bottom);
      end;
    end;
end;

function TFormLyricsDisplaySettingsDebug.GroupSelectionSceneBounds: TRectF;
var
  I: Integer;
  Initialized: Boolean;
  Natural: TRectF;
begin
  Result := TRectF.Empty;
  Initialized := False;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      Natural := DisplayUnitNaturalBounds(I);
      Natural.Left := FPlacements[I].X +
        Natural.Left * FPlacements[I].ScaleX;
      Natural.Right := FPlacements[I].X +
        Natural.Right * FPlacements[I].ScaleX;
      Natural.Top := FPlacements[I].Y +
        Natural.Top * FPlacements[I].ScaleY;
      Natural.Bottom := FPlacements[I].Y +
        Natural.Bottom * FPlacements[I].ScaleY;
      if not Initialized then
      begin
        Result := Natural;
        Initialized := True;
      end
      else
      begin
        Result.Left := Min(Result.Left, Natural.Left);
        Result.Top := Min(Result.Top, Natural.Top);
        Result.Right := Max(Result.Right, Natural.Right);
        Result.Bottom := Max(Result.Bottom, Natural.Bottom);
      end;
    end;
end;

procedure TFormLyricsDisplaySettingsDebug.DrawSelectionRectangle;
var
  Bounds: TRect;
begin
  Bounds.Left := Min(FSelectionStart.X, FSelectionCurrent.X);
  Bounds.Top := Min(FSelectionStart.Y, FSelectionCurrent.Y);
  Bounds.Right := Max(FSelectionStart.X, FSelectionCurrent.X);
  Bounds.Bottom := Max(FSelectionStart.Y, FSelectionCurrent.Y);
  BackgroundPaintBox.Canvas.Brush.Style := bsClear;
  BackgroundPaintBox.Canvas.Pen.Color := clWhite;
  BackgroundPaintBox.Canvas.Pen.Width := 1;
  BackgroundPaintBox.Canvas.Pen.Style := psDot;
  BackgroundPaintBox.Canvas.Rectangle(Bounds);
  BackgroundPaintBox.Canvas.Pen.Style := psSolid;
end;

procedure TFormLyricsDisplaySettingsDebug.BackgroundPaintBoxPaint(
  Sender: TObject);
var
  Destination: TRect;
  I: Integer;
begin
  BackgroundPaintBox.Canvas.Brush.Color := clBlack;
  BackgroundPaintBox.Canvas.FillRect(BackgroundPaintBox.ClientRect);
  if (FBackground.Width > 0) and (FBackground.Height > 0) then
  begin
    Destination := BackgroundDestinationRect;
    BackgroundPaintBox.Canvas.StretchDraw(Destination, FBackground);
  end;
  for I := 0 to Min(High(FUnits), High(FPlacements)) do
    PaintDisplayUnit(I);
  if SelectionCount > 1 then
  begin
    Destination := GroupSelectionBounds;
    BackgroundPaintBox.Canvas.Brush.Style := bsClear;
    BackgroundPaintBox.Canvas.Pen.Color := clAqua;
    BackgroundPaintBox.Canvas.Pen.Width := 1;
    BackgroundPaintBox.Canvas.Pen.Style := psDash;
    BackgroundPaintBox.Canvas.Rectangle(Destination);
    BackgroundPaintBox.Canvas.Pen.Style := psSolid;
    DrawResizeHandles(Destination);
  end;
  if FSelectingRectangle then
    DrawSelectionRectangle;
end;

function TFormLyricsDisplaySettingsDebug.HitTestDisplayUnit(
  X, Y: Integer): Integer;
var
  I: Integer;
begin
  for I := Min(High(FUnits), High(FPlacements)) downto 0 do
    if PtInRect(DisplayUnitBounds(I), Point(X, Y)) then
      Exit(I);
  Result := -1;
end;

function TFormLyricsDisplaySettingsDebug.HitTestResizeHandle(
  X, Y: Integer): TPlacementDragMode;
const
  HIT_RADIUS = 7;
var
  Bounds: TRect;
  CenterX: Integer;
  CenterY: Integer;

  function NearPoint(PointX, PointY: Integer): Boolean;
  begin
    Result := (Abs(X - PointX) <= HIT_RADIUS) and
      (Abs(Y - PointY) <= HIT_RADIUS);
  end;

begin
  Result := pdmNone;
  if (FSelectedIndex < 0) or (SelectionCount = 0) then
    Exit;
  if SelectionCount = 1 then
    Bounds := DisplayUnitBounds(FSelectedIndex)
  else
    Bounds := GroupSelectionBounds;
  CenterX := (Bounds.Left + Bounds.Right) div 2;
  CenterY := (Bounds.Top + Bounds.Bottom) div 2;
  if NearPoint(Bounds.Left, Bounds.Top) then
    Exit(pdmResizeTopLeft);
  if NearPoint(Bounds.Right, Bounds.Top) then
    Exit(pdmResizeTopRight);
  if NearPoint(Bounds.Left, Bounds.Bottom) then
    Exit(pdmResizeBottomLeft);
  if NearPoint(Bounds.Right, Bounds.Bottom) then
    Exit(pdmResizeBottomRight);
  if NearPoint(CenterX, Bounds.Top) then
    Exit(pdmResizeTop);
  if NearPoint(CenterX, Bounds.Bottom) then
    Exit(pdmResizeBottom);
  if NearPoint(Bounds.Left, CenterY) then
    Exit(pdmResizeLeft);
  if NearPoint(Bounds.Right, CenterY) then
    Exit(pdmResizeRight);
end;

procedure TFormLyricsDisplaySettingsDebug.BackgroundPaintBoxMouseDown(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  HitIndex: Integer;
  I: Integer;
begin
  if Button = mbRight then
  begin
    FSelectingRectangle := True;
    FSelectionStart := Point(X, Y);
    FSelectionCurrent := FSelectionStart;
    FDragMode := pdmNone;
    BackgroundPaintBox.Invalidate;
    Exit;
  end;
  if Button <> mbLeft then
    Exit;
  FDragMode := HitTestResizeHandle(X, Y);
  if FDragMode = pdmNone then
  begin
    HitIndex := HitTestDisplayUnit(X, Y);
    if ssShift in Shift then
    begin
      if HitIndex >= 0 then
      begin
        FSelected[HitIndex] := not FSelected[HitIndex];
        if FSelected[HitIndex] then
          FSelectedIndex := HitIndex
        else
        begin
          FSelectedIndex := -1;
          for I := 0 to High(FSelected) do
            if FSelected[I] then
            begin
              FSelectedIndex := I;
              Break;
            end;
        end;
      end;
    end
    else if HitIndex < 0 then
      ClearSelection
    else if not FSelected[HitIndex] then
      SelectOnly(HitIndex)
    else
      FSelectedIndex := HitIndex;
    if (HitIndex >= 0) and FSelected[HitIndex] then
      FDragMode := pdmMove;
  end;
  if FSelectedIndex >= 0 then
  begin
    FDragStartMouse := Point(X, Y);
    FDragStartPlacement := FPlacements[FSelectedIndex];
    FDragStartPlacements := Copy(FPlacements);
    FDragStartGroupBounds := GroupSelectionSceneBounds;
  end;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsDisplaySettingsDebug.BackgroundPaintBoxMouseMove(
  Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  HoverMode: TPlacementDragMode;
  Scale: Double;
begin
  if FSelectingRectangle then
  begin
    FSelectionCurrent := Point(X, Y);
    BackgroundPaintBox.Invalidate;
    Exit;
  end;
  if (FDragMode = pdmNone) or (FSelectedIndex < 0) then
  begin
    HoverMode := HitTestResizeHandle(X, Y);
    case HoverMode of
      pdmResizeLeft, pdmResizeRight:
        BackgroundPaintBox.Cursor := crSizeWE;
      pdmResizeTop, pdmResizeBottom:
        BackgroundPaintBox.Cursor := crSizeNS;
      pdmResizeTopLeft, pdmResizeBottomRight:
        BackgroundPaintBox.Cursor := crSizeNWSE;
      pdmResizeTopRight, pdmResizeBottomLeft:
        BackgroundPaintBox.Cursor := crSizeNESW;
    else
      BackgroundPaintBox.Cursor := crDefault;
    end;
    Exit;
  end;
  Scale := BackgroundScale;
  if Scale <= 0 then
    Exit;
  if FDragMode = pdmMove then
  begin
    for var I := 0 to High(FSelected) do
      if FSelected[I] then
      begin
        FPlacements[I].X := FDragStartPlacements[I].X +
          (X - FDragStartMouse.X) / Scale;
        FPlacements[I].Y := FDragStartPlacements[I].Y +
          (Y - FDragStartMouse.Y) / Scale;
      end;
  end
  else
    ResizeSelectedElement(X, Y);
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsDisplaySettingsDebug.BackgroundPaintBoxMouseUp(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Bounds: TRect;
  I: Integer;
  Intersection: TRect;
begin
  if (Button = mbRight) and FSelectingRectangle then
  begin
    FSelectionCurrent := Point(X, Y);
    Bounds.Left := Min(FSelectionStart.X, FSelectionCurrent.X);
    Bounds.Top := Min(FSelectionStart.Y, FSelectionCurrent.Y);
    Bounds.Right := Max(FSelectionStart.X, FSelectionCurrent.X);
    Bounds.Bottom := Max(FSelectionStart.Y, FSelectionCurrent.Y);
    if not (ssShift in Shift) then
      ClearSelection;
    for I := 0 to High(FSelected) do
      if IntersectRect(Intersection, Bounds, DisplayUnitBounds(I)) then
      begin
        FSelected[I] := True;
        FSelectedIndex := I;
      end;
    FSelectingRectangle := False;
    BackgroundPaintBox.Invalidate;
    Exit;
  end;
  if Button = mbLeft then
    FDragMode := pdmNone;
end;

procedure TFormLyricsDisplaySettingsDebug.ResizeSelectedElement(
  X, Y: Integer);
const
  MIN_SCALE = 0.05;
  MAX_SCALE = 10.0;
var
  DeltaX: Double;
  DeltaY: Double;
  Natural: TRectF;
  NewBottom: Double;
  NewLeft: Double;
  NewRight: Double;
  NewScale: Double;
  NewTop: Double;
  OriginalBottom: Double;
  OriginalLeft: Double;
  OriginalRight: Double;
  OriginalTop: Double;
  Scale: Double;
begin
  if FSelectedIndex < 0 then
    Exit;
  if SelectionCount > 1 then
  begin
    ResizeSelection(X, Y);
    Exit;
  end;
  Scale := BackgroundScale;
  if Scale <= 0 then
    Exit;
  Natural := DisplayUnitNaturalBounds(FSelectedIndex);
  if (Natural.Width <= 0) or (Natural.Height <= 0) then
    Exit;
  DeltaX := (X - FDragStartMouse.X) / Scale;
  DeltaY := (Y - FDragStartMouse.Y) / Scale;
  OriginalLeft := FDragStartPlacement.X +
    Natural.Left * FDragStartPlacement.ScaleX;
  OriginalRight := FDragStartPlacement.X +
    Natural.Right * FDragStartPlacement.ScaleX;
  OriginalTop := FDragStartPlacement.Y +
    Natural.Top * FDragStartPlacement.ScaleY;
  OriginalBottom := FDragStartPlacement.Y +
    Natural.Bottom * FDragStartPlacement.ScaleY;

  if FDragMode in [pdmResizeLeft, pdmResizeTopLeft,
    pdmResizeBottomLeft] then
  begin
    NewLeft := Min(OriginalLeft + DeltaX,
      OriginalRight - Natural.Width * MIN_SCALE);
    NewScale := EnsureRange((OriginalRight - NewLeft) /
      Natural.Width, MIN_SCALE, MAX_SCALE);
    FPlacements[FSelectedIndex].ScaleX := NewScale;
    FPlacements[FSelectedIndex].X := OriginalRight -
      Natural.Right * NewScale;
  end
  else if FDragMode in [pdmResizeRight, pdmResizeTopRight,
    pdmResizeBottomRight] then
  begin
    NewRight := Max(OriginalRight + DeltaX,
      OriginalLeft + Natural.Width * MIN_SCALE);
    NewScale := EnsureRange((NewRight - OriginalLeft) /
      Natural.Width, MIN_SCALE, MAX_SCALE);
    FPlacements[FSelectedIndex].ScaleX := NewScale;
    FPlacements[FSelectedIndex].X := OriginalLeft -
      Natural.Left * NewScale;
  end;

  if FDragMode in [pdmResizeTop, pdmResizeTopLeft,
    pdmResizeTopRight] then
  begin
    NewTop := Min(OriginalTop + DeltaY,
      OriginalBottom - Natural.Height * MIN_SCALE);
    NewScale := EnsureRange((OriginalBottom - NewTop) /
      Natural.Height, MIN_SCALE, MAX_SCALE);
    FPlacements[FSelectedIndex].ScaleY := NewScale;
    FPlacements[FSelectedIndex].Y := OriginalBottom -
      Natural.Bottom * NewScale;
  end
  else if FDragMode in [pdmResizeBottom, pdmResizeBottomLeft,
    pdmResizeBottomRight] then
  begin
    NewBottom := Max(OriginalBottom + DeltaY,
      OriginalTop + Natural.Height * MIN_SCALE);
    NewScale := EnsureRange((NewBottom - OriginalTop) /
      Natural.Height, MIN_SCALE, MAX_SCALE);
    FPlacements[FSelectedIndex].ScaleY := NewScale;
    FPlacements[FSelectedIndex].Y := OriginalTop -
      Natural.Top * NewScale;
  end;
end;

procedure TFormLyricsDisplaySettingsDebug.ResizeSelection(
  X, Y: Integer);
const
  MIN_SCALE = 0.05;
  MAX_SCALE = 10.0;
var
  AnchorX: Double;
  AnchorY: Double;
  DeltaX: Double;
  DeltaY: Double;
  FactorX: Double;
  FactorY: Double;
  I: Integer;
  MaximumFactor: Double;
  MinimumFactor: Double;
  Scale: Double;
begin
  Scale := BackgroundScale;
  if (Scale <= 0) or (FDragStartGroupBounds.Width <= 0) or
    (FDragStartGroupBounds.Height <= 0) then
    Exit;
  DeltaX := (X - FDragStartMouse.X) / Scale;
  DeltaY := (Y - FDragStartMouse.Y) / Scale;
  AnchorX := 0;
  AnchorY := 0;
  FactorX := 1;
  FactorY := 1;

  if FDragMode in [pdmResizeLeft, pdmResizeTopLeft,
    pdmResizeBottomLeft] then
  begin
    AnchorX := FDragStartGroupBounds.Right;
    FactorX := (FDragStartGroupBounds.Width - DeltaX) /
      FDragStartGroupBounds.Width;
  end
  else if FDragMode in [pdmResizeRight, pdmResizeTopRight,
    pdmResizeBottomRight] then
  begin
    AnchorX := FDragStartGroupBounds.Left;
    FactorX := (FDragStartGroupBounds.Width + DeltaX) /
      FDragStartGroupBounds.Width;
  end;

  if FDragMode in [pdmResizeTop, pdmResizeTopLeft,
    pdmResizeTopRight] then
  begin
    AnchorY := FDragStartGroupBounds.Bottom;
    FactorY := (FDragStartGroupBounds.Height - DeltaY) /
      FDragStartGroupBounds.Height;
  end
  else if FDragMode in [pdmResizeBottom, pdmResizeBottomLeft,
    pdmResizeBottomRight] then
  begin
    AnchorY := FDragStartGroupBounds.Top;
    FactorY := (FDragStartGroupBounds.Height + DeltaY) /
      FDragStartGroupBounds.Height;
  end;

  MinimumFactor := 0;
  MaximumFactor := MaxDouble;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      MinimumFactor := Max(MinimumFactor,
        MIN_SCALE / FDragStartPlacements[I].ScaleX);
      MaximumFactor := Min(MaximumFactor,
        MAX_SCALE / FDragStartPlacements[I].ScaleX);
    end;
  FactorX := EnsureRange(FactorX, MinimumFactor, MaximumFactor);
  MinimumFactor := 0;
  MaximumFactor := MaxDouble;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      MinimumFactor := Max(MinimumFactor,
        MIN_SCALE / FDragStartPlacements[I].ScaleY);
      MaximumFactor := Min(MaximumFactor,
        MAX_SCALE / FDragStartPlacements[I].ScaleY);
    end;
  FactorY := EnsureRange(FactorY, MinimumFactor, MaximumFactor);

  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      FPlacements[I] := FDragStartPlacements[I];
      if FDragMode in [pdmResizeLeft, pdmResizeRight,
        pdmResizeTopLeft, pdmResizeTopRight,
        pdmResizeBottomLeft, pdmResizeBottomRight] then
      begin
        FPlacements[I].X := AnchorX +
          (FDragStartPlacements[I].X - AnchorX) * FactorX;
        FPlacements[I].ScaleX :=
          FDragStartPlacements[I].ScaleX * FactorX;
      end;
      if FDragMode in [pdmResizeTop, pdmResizeBottom,
        pdmResizeTopLeft, pdmResizeTopRight,
        pdmResizeBottomLeft, pdmResizeBottomRight] then
      begin
        FPlacements[I].Y := AnchorY +
          (FDragStartPlacements[I].Y - AnchorY) * FactorY;
        FPlacements[I].ScaleY :=
          FDragStartPlacements[I].ScaleY * FactorY;
      end;
    end;
end;

procedure TFormLyricsDisplaySettingsDebug.BuildInitialPlacements;
const
  ITEM_SPACING = 12;
var
  BaseSize: TSize;
  CursorX: Double;
  I: Integer;
  ItemWidths: TArray<Integer>;
  RubySize: TSize;
  TotalWidth: Integer;
begin
  SetLength(FPlacements, Length(FUnits));
  SetLength(ItemWidths, Length(FUnits));
  TotalWidth := 0;
  FBackground.Canvas.Font.Style := [];
  for I := 0 to High(FUnits) do
  begin
    FBackground.Canvas.Font.Name := FBaseFontName;
    FBackground.Canvas.Font.Height := -Max(1, FBaseFontHeight);
    BaseSize := FBackground.Canvas.TextExtent(DisplayUnitBaseText(I));
    RubySize.cx := 0;
    if DisplayUnitRubyText(I) <> '' then
    begin
      FBackground.Canvas.Font.Name := FRubyFontName;
      FBackground.Canvas.Font.Height := -Max(1, FRubyFontHeight);
      RubySize := FBackground.Canvas.TextExtent(DisplayUnitRubyText(I));
    end;
    ItemWidths[I] := Max(BaseSize.cx, RubySize.cx);
    Inc(TotalWidth, ItemWidths[I]);
    if I > 0 then
      Inc(TotalWidth, ITEM_SPACING);
  end;

  CursorX := -TotalWidth * 0.5;
  for I := 0 to High(FPlacements) do
  begin
    FPlacements[I].Index := I;
    FPlacements[I].X := CursorX + ItemWidths[I] * 0.5;
    FPlacements[I].Y := 0;
    FPlacements[I].ScaleX := 1;
    FPlacements[I].ScaleY := 1;
    CursorX := CursorX + ItemWidths[I] + ITEM_SPACING;
  end;
end;

procedure TFormLyricsDisplaySettingsDebug.Configure(
  const Lyrics, BaseFontName, RubyFontName: string;
  BaseFontHeight, RubyFontHeight, RubyGapAdjustment: Integer;
  const Data: TDisplaySettingsData);
begin
  FLyrics := Lyrics;
  FBaseFontName := BaseFontName;
  FRubyFontName := RubyFontName;
  FBaseFontHeight := Max(1, BaseFontHeight);
  FRubyFontHeight := Max(1, RubyFontHeight);
  FRubyGap := EnsureRange(4 + RubyGapAdjustment, -1024, 1024);
  ParseLyrics(FLyrics, FPlainText, FRubySpans);
  BuildLyricsDisplayUnits(FPlainText, FRubySpans, FUnits);
  if not TryDecodeDisplayPlacements(Data, FLyrics, Length(FUnits),
    FPlacements) then
    BuildInitialPlacements;
  SetLength(FSelected, Length(FUnits));
  ClearSelection;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsDisplaySettingsDebug.SetBackgroundRgba(
  const Pixels: TBytes; Width, Height: Integer);
var
  Destination: PByte;
  Source: PByte;
  X: Integer;
  Y: Integer;
begin
  if (Width <= 0) or (Height <= 0) or
    (Length(Pixels) <> NativeInt(Width) * Height * 4) then
    Exit;

  FBackground.PixelFormat := pf32bit;
  FBackground.SetSize(Width, Height);
  Source := @Pixels[0];
  for Y := 0 to Height - 1 do
  begin
    Destination := FBackground.ScanLine[Y];
    for X := 0 to Width - 1 do
    begin
      Destination[0] := Source[2];
      Destination[1] := Source[1];
      Destination[2] := Source[0];
      Destination[3] := Source[3];
      Inc(Destination, 4);
      Inc(Source, 4);
    end;
  end;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsDisplaySettingsDebug.SetCaptureStatus(
  const Value: string);
begin
  DescriptionLabel.Caption := Value;
end;

function TFormLyricsDisplaySettingsDebug.TryBuildSettingsData(
  out Data: TDisplaySettingsData): Boolean;
begin
  Result := TryEncodeDisplayPlacements(FLyrics, FPlacements, Data);
end;

end.
