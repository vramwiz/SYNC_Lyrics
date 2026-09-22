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
  Winapi.Windows;

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
  Scale := Min(Bounds.Width / FBitmap.Width,
    Bounds.Height / FBitmap.Height);
  DrawWidth := Max(1, Round(FBitmap.Width * Scale));
  DrawHeight := Max(1, Round(FBitmap.Height * Scale));
  Result.Left := Bounds.Left + (Bounds.Width - DrawWidth) div 2;
  Result.Top := Bounds.Top + (Bounds.Height - DrawHeight) div 2;
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
end;

procedure TDisplayPreviewBackground.DrawCenterGuides(Canvas: TCanvas;
  const Destination: TRect; Vertical, Horizontal: Boolean);
begin
  Canvas.Pen.Color := RGB(99, 204, 220);
  Canvas.Pen.Width := 1;
  Canvas.Pen.Style := psDot;
  if Vertical then
  begin
    Canvas.MoveTo(Destination.CenterPoint.X, Destination.Top);
    Canvas.LineTo(Destination.CenterPoint.X, Destination.Bottom);
  end;
  if Horizontal then
  begin
    Canvas.MoveTo(Destination.Left, Destination.CenterPoint.Y);
    Canvas.LineTo(Destination.Right, Destination.CenterPoint.Y);
  end;
  Canvas.Pen.Style := psSolid;
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
