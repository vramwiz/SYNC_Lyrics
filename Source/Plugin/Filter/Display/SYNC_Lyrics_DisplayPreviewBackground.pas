unit SYNC_Lyrics_DisplayPreviewBackground;

// Owns and draws the Filter frame shared by display-setting previews.

interface

uses
  System.SysUtils,
  System.Types,
  Vcl.Graphics;

type
  TDisplayPreviewBackground = class
  private
    FBitmap: TBitmap;
  public
    constructor Create;
    destructor Destroy; override;
    function DestinationRect(const Bounds: TRect): TRect;
    procedure Draw(Canvas: TCanvas; const Bounds: TRect);
    procedure DrawAt(Canvas: TCanvas; const Bounds,
      Destination: TRect);
    procedure DrawCenterGuides(Canvas: TCanvas; const Destination: TRect;
      Vertical, Horizontal: Boolean);
    function ImageHeight: Integer;
    function ImageWidth: Integer;
    function HasImage: Boolean;
    function ScaleForBounds(const Bounds: TRect): Double;
    procedure SetRgba(const Pixels: TBytes; Width, Height: Integer);
  end;

implementation

uses
  System.Math,
  Winapi.Windows,
  SYNC_Lyrics_ContrastGuides;

constructor TDisplayPreviewBackground.Create;
begin
  inherited Create;
  FBitmap := Vcl.Graphics.TBitmap.Create;
  FBitmap.PixelFormat := pf32bit;
end;

destructor TDisplayPreviewBackground.Destroy;
begin
  FBitmap.Free;
  inherited;
end;

function TDisplayPreviewBackground.DestinationRect(
  const Bounds: TRect): TRect;
var
  DrawHeight: Integer;
  DrawWidth: Integer;
  InnerBounds: TRect;
  Scale: Double;
begin
  Result := Bounds;
  if (Bounds.Width <= 0) or (Bounds.Height <= 0) then
    Exit;
  if not HasImage then
  begin
    InflateRect(Result, -Min(24, Bounds.Width div 8),
      -Min(24, Bounds.Height div 8));
    Exit;
  end;
  InnerBounds := Bounds;
  InflateRect(InnerBounds, -Min(20, Bounds.Width div 8),
    -Min(20, Bounds.Height div 8));
  Scale := Min(InnerBounds.Width / FBitmap.Width,
    InnerBounds.Height / FBitmap.Height);
  DrawWidth := Max(1, Round(FBitmap.Width * Scale));
  DrawHeight := Max(1, Round(FBitmap.Height * Scale));
  Result.Left := InnerBounds.Left + (InnerBounds.Width - DrawWidth) div 2;
  Result.Top := InnerBounds.Top + (InnerBounds.Height - DrawHeight) div 2;
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

procedure TDisplayPreviewBackground.Draw(Canvas: TCanvas;
  const Bounds: TRect);
begin
  DrawAt(Canvas, Bounds, DestinationRect(Bounds));
end;

procedure TDisplayPreviewBackground.DrawAt(Canvas: TCanvas;
  const Bounds, Destination: TRect);
const
  MARK_GAP = 4;
  MARK_LENGTH = 14;
var
  RightEdge: Integer;
  BottomEdge: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := RGB(105, 108, 114);
  Canvas.FillRect(Bounds);
  if HasImage then
    Canvas.StretchDraw(Destination, FBitmap)
  else
  begin
    Canvas.Brush.Color := RGB(29, 31, 35);
    Canvas.FillRect(Destination);
  end;
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := RGB(165, 168, 173);
  Canvas.Pen.Width := 1;
  Canvas.Pen.Style := psSolid;
  Canvas.Rectangle(Destination);
  // The marks stay outside the image so its editable boundary remains visible.
  RightEdge := Destination.Right - 1;
  BottomEdge := Destination.Bottom - 1;
  Canvas.Pen.Color := RGB(225, 228, 232);
  Canvas.MoveTo(Destination.Left - MARK_LENGTH, Destination.Top);
  Canvas.LineTo(Destination.Left - MARK_GAP, Destination.Top);
  Canvas.MoveTo(Destination.Left, Destination.Top - MARK_LENGTH);
  Canvas.LineTo(Destination.Left, Destination.Top - MARK_GAP);
  Canvas.MoveTo(RightEdge + MARK_GAP, Destination.Top);
  Canvas.LineTo(RightEdge + MARK_LENGTH, Destination.Top);
  Canvas.MoveTo(RightEdge, Destination.Top - MARK_LENGTH);
  Canvas.LineTo(RightEdge, Destination.Top - MARK_GAP);
  Canvas.MoveTo(Destination.Left - MARK_LENGTH, BottomEdge);
  Canvas.LineTo(Destination.Left - MARK_GAP, BottomEdge);
  Canvas.MoveTo(Destination.Left, BottomEdge + MARK_GAP);
  Canvas.LineTo(Destination.Left, BottomEdge + MARK_LENGTH);
  Canvas.MoveTo(RightEdge + MARK_GAP, BottomEdge);
  Canvas.LineTo(RightEdge + MARK_LENGTH, BottomEdge);
  Canvas.MoveTo(RightEdge, BottomEdge + MARK_GAP);
  Canvas.LineTo(RightEdge, BottomEdge + MARK_LENGTH);
end;

procedure TDisplayPreviewBackground.DrawCenterGuides(Canvas: TCanvas;
  const Destination: TRect; Vertical, Horizontal: Boolean);
begin
  if Vertical then
    DrawContrastDashedLine(Canvas,
      Point(Destination.CenterPoint.X, Destination.Top),
      Point(Destination.CenterPoint.X, Destination.Bottom));
  if Horizontal then
    DrawContrastDashedLine(Canvas,
      Point(Destination.Left, Destination.CenterPoint.Y),
      Point(Destination.Right, Destination.CenterPoint.Y));
end;

function TDisplayPreviewBackground.HasImage: Boolean;
begin
  Result := (FBitmap.Width > 0) and (FBitmap.Height > 0);
end;

function TDisplayPreviewBackground.ImageHeight: Integer;
begin
  Result := FBitmap.Height;
end;

function TDisplayPreviewBackground.ImageWidth: Integer;
begin
  Result := FBitmap.Width;
end;

function TDisplayPreviewBackground.ScaleForBounds(
  const Bounds: TRect): Double;
var
  Destination: TRect;
begin
  Result := 1;
  if not HasImage then
    Exit;
  Destination := DestinationRect(Bounds);
  Result := Destination.Width / FBitmap.Width;
end;

procedure TDisplayPreviewBackground.SetRgba(const Pixels: TBytes;
  Width, Height: Integer);
var
  Destination: PByte;
  Source: PByte;
  X: Integer;
  Y: Integer;
begin
  if (Width <= 0) or (Height <= 0) or
    (Length(Pixels) <> NativeInt(Width) * Height * 4) then
    Exit;
  FBitmap.SetSize(Width, Height);
  Source := @Pixels[0];
  for Y := 0 to Height - 1 do
  begin
    Destination := FBitmap.ScanLine[Y];
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
end;

end.
