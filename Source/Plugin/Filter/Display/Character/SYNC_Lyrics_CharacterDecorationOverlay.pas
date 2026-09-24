unit SYNC_Lyrics_CharacterDecorationOverlay;

// Positions, hit tests, and draws decoration controls around a character selection.

interface

uses
  System.Types,
  Vcl.Graphics,
  SYNC_Lyrics_CharacterLayoutInteraction,
  SYNC_Lyrics_DisplaySettingsData;

type
  TCharacterDecorationOverlay = record
  private
    FBounds: TRect;                       // Union of selected element rectangles.
    FSettings: TDisplayCommonSettings;    // Effective decoration after inheritance.
    FDragMode: TCharacterLayoutDragMode;  // Control whose live value is displayed.
    FScale: Double;                       // Source-image pixels to preview pixels.
    FPreviewRect: TRect;                  // Client area used to clamp controls.
    FPPI: Integer;                        // DPI for control sizes independent of zoom.
  public
    // Captures resolved settings and preview geometry for one paint or hit-test pass.
    class function Create(const Bounds: TRect; const Settings: TDisplayCommonSettings;
      DragMode: TCharacterLayoutDragMode; Scale: Double;
      const PreviewRect: TRect; PPI: Integer): TCharacterDecorationOverlay; static;
    // Returns a control rectangle after decoration offsets and viewport clamping.
    function HandleRect(Mode: TCharacterLayoutDragMode): TRect;
    // Returns an enabled control under PointValue, or cldmNone.
    function HitTest(const PointValue: TPoint): TCharacterLayoutDragMode;
    // Draws enabled controls and the dragged value; leaves Canvas styling changed.
    procedure Draw(Canvas: TCanvas);
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  SYNC_Lyrics_ContrastGuides;

class function TCharacterDecorationOverlay.Create(const Bounds: TRect;
  const Settings: TDisplayCommonSettings; DragMode: TCharacterLayoutDragMode;
  Scale: Double; const PreviewRect: TRect;
  PPI: Integer): TCharacterDecorationOverlay;
begin
  Result.FBounds := Bounds;
  Result.FSettings := Settings;
  Result.FDragMode := DragMode;
  Result.FScale := Scale;
  Result.FPreviewRect := PreviewRect;
  Result.FPPI := PPI;
end;

function TCharacterDecorationOverlay.HandleRect(
  Mode: TCharacterLayoutDragMode): TRect;
var
  Center: TPoint;
  Extent: Integer;
  Gap: Integer;
  Scale: Double;
begin
  Result := TRect.Empty;
  if IsRectEmpty(FBounds) then
    Exit;
  Extent := MulDiv(24, FPPI, 96);
  Gap := MulDiv(10, FPPI, 96);
  Scale := FScale;
  if Scale <= 0 then Scale := 1;
  case Mode of
    cldmOutlineBlur:
      Center := Point(FBounds.Left - Gap - Extent div 2,
        FBounds.Top - Gap - Extent div 2);
    cldmOutlineWidth:
      Center := Point(FBounds.Right + Gap + Extent div 2,
        FBounds.Top - Gap - Extent div 2);
    cldmShadowBlur:
      Center := Point(FBounds.Left - Gap - Extent div 2,
        FBounds.Bottom + Gap + Extent div 2);
    cldmShadowOffset:
      Center := Point(FBounds.Right + Gap + Extent div 2 +
        Round(FSettings.ShadowOffsetX * Scale),
        FBounds.Bottom + Gap + Extent div 2 +
        Round(FSettings.ShadowOffsetY * Scale));
    cldmShadowSpread:
      begin
        Result := HandleRect(cldmShadowOffset);
        Center := Point(Result.Right + Gap + Extent div 2,
          (Result.Top + Result.Bottom) div 2);
      end;
  else
    Exit;
  end;
  case Mode of
    cldmOutlineBlur: Dec(Center.X, Round(FSettings.OutlineBlur * Scale));
    cldmOutlineWidth: Inc(Center.X, Round(FSettings.OutlineWidth * Scale));
    cldmShadowBlur: Dec(Center.X, Round(FSettings.ShadowBlur * Scale));
    cldmShadowSpread:
      Inc(Center.X, Round(FSettings.ShadowSpread * Scale));
  end;
  if Mode = cldmShadowOffset then
    Center.X := EnsureRange(Center.X, Extent div 2,
      Max(Extent div 2, FPreviewRect.Width -
        (3 * Extent) div 2 - Gap))
  else
    Center.X := EnsureRange(Center.X, Extent div 2,
      Max(Extent div 2, FPreviewRect.Width - Extent div 2));
  Center.Y := EnsureRange(Center.Y, Extent div 2,
    Max(Extent div 2, FPreviewRect.Height - Extent div 2));
  Result := Rect(Center.X - Extent div 2, Center.Y - Extent div 2,
    Center.X + Extent div 2, Center.Y + Extent div 2);
end;

function TCharacterDecorationOverlay.HitTest(
  const PointValue: TPoint): TCharacterLayoutDragMode;
begin
  Result := cldmNone;
  if IsRectEmpty(FBounds) then Exit;
  if FSettings.OutlineEnabled then
  begin
    if PtInRect(HandleRect(cldmOutlineBlur), PointValue) then
      Exit(cldmOutlineBlur);
    if PtInRect(HandleRect(cldmOutlineWidth), PointValue) then
      Exit(cldmOutlineWidth);
  end;
  if FSettings.ShadowEnabled then
  begin
    if PtInRect(HandleRect(cldmShadowBlur), PointValue) then
      Exit(cldmShadowBlur);
    if PtInRect(HandleRect(cldmShadowOffset), PointValue) then
      Exit(cldmShadowOffset);
    if PtInRect(HandleRect(cldmShadowSpread), PointValue) then
      Exit(cldmShadowSpread);
  end;
end;

procedure TCharacterDecorationOverlay.Draw(Canvas: TCanvas);
const
  MODES: array[0..4] of TCharacterLayoutDragMode =
    (cldmOutlineBlur, cldmOutlineWidth, cldmShadowBlur,
     cldmShadowOffset, cldmShadowSpread);
  LABELS: array[0..4] of string = (#26580, #32257, #24433, 'XY', #24195);
var
  Anchor: TPoint;
  Handle: TRect;
  I: Integer;
  Mode: TCharacterLayoutDragMode;
  TextRect: TRect;
  ValueRect: TRect;
  ValueText: string;
begin
  if IsRectEmpty(FBounds) then Exit;
  for I := Low(MODES) to High(MODES) do
  begin
    Mode := MODES[I];
    if (Mode in [cldmOutlineBlur, cldmOutlineWidth]) and
      not FSettings.OutlineEnabled then Continue;
    if (Mode in [cldmShadowBlur, cldmShadowOffset, cldmShadowSpread]) and
      not FSettings.ShadowEnabled then Continue;
    Handle := HandleRect(Mode);
    if Mode in [cldmOutlineBlur, cldmShadowBlur] then
      Anchor.X := FBounds.Left
    else
      Anchor.X := FBounds.Right;
    if Mode in [cldmOutlineBlur, cldmOutlineWidth] then
      Anchor.Y := FBounds.Top
    else
      Anchor.Y := FBounds.Bottom;
    DrawContrastDashedLine(Canvas, Anchor, Handle.CenterPoint, FPPI);
    Canvas.Pen.Style := psSolid;
    if FDragMode = Mode then Canvas.Pen.Color := clAqua
    else Canvas.Pen.Color := RGB(210, 210, 210);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := RGB(48, 48, 48);
    Canvas.RoundRect(Handle.Left, Handle.Top, Handle.Right, Handle.Bottom,
      MulDiv(5, FPPI, 96), MulDiv(5, FPPI, 96));
    TextRect := Handle;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Yu Gothic UI';
    Canvas.Font.Height := -MulDiv(11, FPPI, 96);
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := RGB(230, 230, 230);
    DrawText(Canvas.Handle, PChar(LABELS[I]), Length(LABELS[I]), TextRect,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    if FDragMode <> Mode then Continue;
    case Mode of
      cldmOutlineBlur: ValueText := FormatFloat('0.0', FSettings.OutlineBlur);
      cldmOutlineWidth: ValueText := FormatFloat('0.0', FSettings.OutlineWidth);
      cldmShadowBlur: ValueText := FormatFloat('0.0', FSettings.ShadowBlur);
      cldmShadowOffset:
        ValueText := 'X ' + FormatFloat('0.0', FSettings.ShadowOffsetX) +
          '  Y ' + FormatFloat('0.0', FSettings.ShadowOffsetY);
      cldmShadowSpread: ValueText := FormatFloat('0.0', FSettings.ShadowSpread);
    else
      ValueText := '';
    end;
    ValueRect := Handle;
    InflateRect(ValueRect, MulDiv(20, FPPI, 96), 0);
    OffsetRect(ValueRect, 0, Handle.Height + MulDiv(4, FPPI, 96));
    if ValueRect.Bottom > FPreviewRect.Height then
      OffsetRect(ValueRect, 0, -Handle.Height * 2 -
        MulDiv(8, FPPI, 96));
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := RGB(35, 35, 35);
    Canvas.Pen.Color := clAqua;
    Canvas.RoundRect(ValueRect.Left, ValueRect.Top, ValueRect.Right,
      ValueRect.Bottom, MulDiv(5, FPPI, 96),
      MulDiv(5, FPPI, 96));
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Style := [];
    Canvas.Font.Color := RGB(235, 235, 235);
    DrawText(Canvas.Handle, PChar(ValueText), Length(ValueText), ValueRect,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
  end;
end;

end.
