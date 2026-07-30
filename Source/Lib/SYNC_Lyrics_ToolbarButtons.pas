unit SYNC_Lyrics_ToolbarButtons;

// Provides the state and input layer for the character-formatting toolbar.
// Glyph rendering and form integration are intentionally kept outside this unit.

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Types,
  System.UITypes,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics;

type
  TSyncLyricsToolbarButtonKind = (
    tbkCommand,
    tbkToggle,
    tbkDialog,
    tbkSeparator
  );

  TSyncLyricsToolbarCheckState = (
    tbcsUnchecked,
    tbcsChecked,
    tbcsMixed
  );

  // Identifies the future procedural glyph without tying the button to images.
  TSyncLyricsToolbarGlyph = (
    tbgNone,
    tbgBold,
    tbgItalic,
    tbgUnderline,
    tbgStrikeOut,
    tbgFont,
    tbgBeforeColor,
    tbgAfterColor,
    tbgMoveToCenter,
    tbgResetSelected,
    tbgResetAll,
    tbgAlignHorizontal,
    tbgDistributeHorizontal
  );

  TSyncLyricsToolbarButton = class;

  TSyncLyricsToolbarButtonExecuteEvent = procedure(Sender: TObject;
    Button: TSyncLyricsToolbarButton) of object;

  // One toolbar item. Execution occurs only after a left-button MouseUp,
  // allowing a handler to open a modal dialog without leaving Pressed set.
  TSyncLyricsToolbarButton = class(TCustomControl)
  private
    FAccentColor: TColor;
    FCheckState: TSyncLyricsToolbarCheckState;
    FGlyph: TSyncLyricsToolbarGlyph;
    FHasAccentColor: Boolean;
    FHot: Boolean;
    FKind: TSyncLyricsToolbarButtonKind;
    FOnExecute: TSyncLyricsToolbarButtonExecuteEvent;
    FOnOwnerExecute: TSyncLyricsToolbarButtonExecuteEvent;
    FPressed: Boolean;
    procedure SetAccentColor(const Value: TColor);
    procedure SetCheckState(
      const Value: TSyncLyricsToolbarCheckState);
    procedure SetGlyph(const Value: TSyncLyricsToolbarGlyph);
    procedure SetHasAccentColor(const Value: Boolean);
    procedure SetKind(const Value: TSyncLyricsToolbarButtonKind);
  protected
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure Paint; override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure RequestExecution; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Execute;
    property Pressed: Boolean read FPressed;
  published
    property AccentColor: TColor read FAccentColor write SetAccentColor;
    property Align;
    property Anchors;
    property CheckState: TSyncLyricsToolbarCheckState read FCheckState
      write SetCheckState default tbcsUnchecked;
    property Enabled;
    property Glyph: TSyncLyricsToolbarGlyph read FGlyph write SetGlyph
      default tbgNone;
    property HasAccentColor: Boolean read FHasAccentColor
      write SetHasAccentColor default False;
    property Hint;
    property Kind: TSyncLyricsToolbarButtonKind read FKind write SetKind
      default tbkCommand;
    property OnExecute: TSyncLyricsToolbarButtonExecuteEvent read FOnExecute
      write FOnExecute;
    property ParentShowHint;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;

  TSyncLyricsToolbarButtons = class(TCustomPanel)
  private
    FButtonExtent: Integer;
    FItems: TObjectList<TSyncLyricsToolbarButton>;
    FOnButtonExecute: TSyncLyricsToolbarButtonExecuteEvent;
    FSeparatorExtent: Integer;
    procedure ButtonExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    function GetItem(Index: Integer): TSyncLyricsToolbarButton;
    function GetItemCount: Integer;
    procedure SetButtonExtent(const Value: Integer);
    procedure SetSeparatorExtent(const Value: Integer);
    procedure UpdateLayout;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function AddButton(const HintText: string;
      Glyph: TSyncLyricsToolbarGlyph;
      Kind: TSyncLyricsToolbarButtonKind = tbkCommand;
      TagValue: NativeInt = 0;
      ExecuteEvent: TSyncLyricsToolbarButtonExecuteEvent = nil):
      TSyncLyricsToolbarButton;
    function AddCommandButton(const HintText: string;
      Glyph: TSyncLyricsToolbarGlyph; TagValue: NativeInt = 0):
      TSyncLyricsToolbarButton;
    function AddDialogButton(const HintText: string;
      Glyph: TSyncLyricsToolbarGlyph; TagValue: NativeInt = 0):
      TSyncLyricsToolbarButton;
    function AddSeparator: TSyncLyricsToolbarButton;
    function AddToggleButton(const HintText: string;
      Glyph: TSyncLyricsToolbarGlyph; TagValue: NativeInt = 0):
      TSyncLyricsToolbarButton;
    function FindByTag(TagValue: NativeInt): TSyncLyricsToolbarButton;
    procedure Relayout;
    property ItemCount: Integer read GetItemCount;
    property Items[Index: Integer]: TSyncLyricsToolbarButton read GetItem;
  published
    property Align;
    property Anchors;
    property BevelOuter;
    property ButtonExtent: Integer read FButtonExtent write SetButtonExtent
      default 28;
    property Color;
    property Enabled;
    property OnButtonExecute: TSyncLyricsToolbarButtonExecuteEvent
      read FOnButtonExecute write FOnButtonExecute;
    property ParentBackground;
    property ParentColor;
    property SeparatorExtent: Integer read FSeparatorExtent
      write SetSeparatorExtent default 6;
    property ShowHint;
    property Visible;
  end;

implementation

uses
  System.Math,
  Winapi.Windows;

{ TSyncLyricsToolbarButton }

constructor TSyncLyricsToolbarButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csClickEvents, csCaptureMouse,
    csDoubleClicks];
  FAccentColor := clNone;
  FCheckState := tbcsUnchecked;
  FGlyph := tbgNone;
  FHasAccentColor := False;
  FHot := False;
  FKind := tbkCommand;
  FPressed := False;
  ParentShowHint := True;
  TabStop := True;
end;

procedure TSyncLyricsToolbarButton.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  if not FHot then
  begin
    FHot := True;
    Invalidate;
  end;
end;

procedure TSyncLyricsToolbarButton.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FHot then
  begin
    FHot := False;
    Invalidate;
  end;
end;

procedure TSyncLyricsToolbarButton.Execute;
begin
  RequestExecution;
end;

procedure TSyncLyricsToolbarButton.KeyDown(var Key: Word;
  Shift: TShiftState);
begin
  inherited;
  if Enabled and (FKind <> tbkSeparator) and
    (Key in [VK_SPACE, VK_RETURN]) then
  begin
    Key := 0;
    RequestExecution;
  end;
end;

procedure TSyncLyricsToolbarButton.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button <> mbLeft) or not Enabled or
    (FKind = tbkSeparator) then
    Exit;
  SetFocus;
  FPressed := True;
  MouseCapture := True;
  Invalidate;
end;

procedure TSyncLyricsToolbarButton.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  ExecuteRequested: Boolean;
begin
  inherited;
  if (Button <> mbLeft) or not FPressed then
    Exit;
  ExecuteRequested := Enabled and (FKind <> tbkSeparator) and
    PtInRect(ClientRect, Point(X, Y));
  FPressed := False;
  MouseCapture := False;
  Invalidate;
  if ExecuteRequested then
    RequestExecution;
end;

procedure TSyncLyricsToolbarButton.Paint;
const
  TEXT_FLAGS = DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX;
var
  Accent: TColor;
  BackColor: TColor;
  BorderColor: TColor;
  GlyphRect: TRect;
  H: Integer;
  MidX: Integer;
  MidY: Integer;
  R: TRect;
  TextColor: TColor;

  function BlendColor(Base, Overlay: TColor; OverlayAmount: Byte): TColor;
  var
    BaseRgb: Cardinal;
    OverlayRgb: Cardinal;
    Red: Cardinal;
    Green: Cardinal;
    Blue: Cardinal;
    InverseAmount: Cardinal;
  begin
    BaseRgb := ColorToRGB(Base);
    OverlayRgb := ColorToRGB(Overlay);
    InverseAmount := Cardinal(255 - OverlayAmount);
    Red := ((BaseRgb and $FF) * InverseAmount +
      (OverlayRgb and $FF) * OverlayAmount) div 255;
    Green := (((BaseRgb shr 8) and $FF) * InverseAmount +
      ((OverlayRgb shr 8) and $FF) * OverlayAmount) div 255;
    Blue := (((BaseRgb shr 16) and $FF) * InverseAmount +
      ((OverlayRgb shr 16) and $FF) * OverlayAmount) div 255;
    Result := TColor(Red or (Green shl 8) or (Blue shl 16));
  end;

  procedure DrawTextGlyph(const Text: string; Style: TFontStyles;
    HeightPercent: Integer = 58);
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -Max(8, H * HeightPercent div 100);
    Canvas.Font.Style := Style;
    Canvas.Font.Color := TextColor;
    DrawText(Canvas.Handle, PChar(Text), Length(Text), GlyphRect,
      TEXT_FLAGS);
  end;

  procedure DrawColorGlyph(PointRight: Boolean);
  var
    ArrowX: Integer;
  begin
    R := GlyphRect;
    Dec(R.Bottom, Max(3, H div 6));
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -Max(8, H * 50 div 100);
    Canvas.Font.Style := [];
    Canvas.Font.Color := TextColor;
    DrawText(Canvas.Handle, 'A', 1, R, TEXT_FLAGS);
    Canvas.Pen.Width := Max(3, H div 7);
    Canvas.Pen.Color := BlendColor(BackColor, clWindowText, 150);
    Canvas.MoveTo(GlyphRect.Left + H div 5, GlyphRect.Bottom - H div 6);
    Canvas.LineTo(GlyphRect.Right - H div 5, GlyphRect.Bottom - H div 6);
    Canvas.Pen.Width := Max(2, H div 10);
    Canvas.Pen.Color := Accent;
    Canvas.MoveTo(GlyphRect.Left + H div 5, GlyphRect.Bottom - H div 6);
    Canvas.LineTo(GlyphRect.Right - H div 5, GlyphRect.Bottom - H div 6);
    Canvas.Pen.Width := 1;
    Canvas.Brush.Color := TextColor;
    if PointRight then
      ArrowX := GlyphRect.Right - 2
    else
      ArrowX := GlyphRect.Left + 2;
    if PointRight then
      Canvas.Polygon([Point(ArrowX - 4, MidY - 3),
        Point(ArrowX, MidY), Point(ArrowX - 4, MidY + 3)])
    else
      Canvas.Polygon([Point(ArrowX + 4, MidY - 3),
        Point(ArrowX, MidY), Point(ArrowX + 4, MidY + 3)]);
  end;

  procedure DrawResetGlyph(AllItems: Boolean);
  var
    Offset: Integer;
  begin
    Canvas.Pen.Color := TextColor;
    Canvas.Pen.Width := 1;
    Canvas.Brush.Style := bsClear;
    Offset := Ord(AllItems) * 3;
    Canvas.Rectangle(MidX - 7 - Offset, MidY - 4,
      MidX + 5 - Offset, MidY + 5);
    if AllItems then
      Canvas.Rectangle(MidX - 3, MidY - 7, MidX + 8, MidY + 2);
    Canvas.Arc(MidX - 9, MidY - 10, MidX + 10, MidY + 9,
      MidX + 8, MidY - 5, MidX - 7, MidY - 7);
    Canvas.Brush.Color := TextColor;
    Canvas.Polygon([Point(MidX - 9, MidY - 8),
      Point(MidX - 3, MidY - 9), Point(MidX - 7, MidY - 3)]);
  end;

begin
  H := Min(ClientWidth, ClientHeight);
  MidX := ClientWidth div 2;
  MidY := ClientHeight div 2;
  if Parent <> nil then
    BackColor := Parent.Brush.Color
  else
    BackColor := clBtnFace;
  BorderColor := BlendColor(BackColor, clBtnShadow, 100);
  if FPressed then
    BackColor := BlendColor(BackColor, clHighlight, 90)
  else if FCheckState = tbcsChecked then
    BackColor := BlendColor(BackColor, clHighlight, 65)
  else if FCheckState = tbcsMixed then
    BackColor := BlendColor(BackColor, clHighlight, 38)
  else if FHot then
    BackColor := BlendColor(BackColor, clHighlight, 28);

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := BackColor;
  Canvas.Pen.Color := BackColor;
  Canvas.Rectangle(ClientRect);
  if FPressed or FHot or (FCheckState <> tbcsUnchecked) then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := BorderColor;
    Canvas.Rectangle(0, 0, ClientWidth, ClientHeight);
  end;
  if FKind = tbkSeparator then
  begin
    Canvas.Pen.Color := BorderColor;
    Canvas.MoveTo(MidX, H div 4);
    Canvas.LineTo(MidX, H - H div 4);
    Exit;
  end;

  if Enabled then
    TextColor := clWindowText
  else
    TextColor := clGrayText;
  if FHasAccentColor then
    Accent := FAccentColor
  else
    Accent := TextColor;
  GlyphRect := Rect(2, 2, ClientWidth - 2, ClientHeight - 2);
  Canvas.Pen.Color := TextColor;
  Canvas.Brush.Color := TextColor;
  Canvas.Pen.Width := 1;
  case FGlyph of
    tbgBold:
      DrawTextGlyph('B', [fsBold]);
    tbgItalic:
      DrawTextGlyph('I', [fsItalic]);
    tbgUnderline:
      DrawTextGlyph('U', [fsUnderline]);
    tbgStrikeOut:
      DrawTextGlyph('S', [fsStrikeOut]);
    tbgFont:
      DrawTextGlyph('Aa', []);
    tbgBeforeColor:
      DrawColorGlyph(False);
    tbgAfterColor:
      DrawColorGlyph(True);
    tbgMoveToCenter:
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Rectangle(MidX - 6, MidY - 5, MidX + 7, MidY + 6);
        Canvas.MoveTo(MidX - 10, MidY);
        Canvas.LineTo(MidX + 11, MidY);
        Canvas.MoveTo(MidX, MidY - 10);
        Canvas.LineTo(MidX, MidY + 11);
      end;
    tbgResetSelected:
      DrawResetGlyph(False);
    tbgResetAll:
      DrawResetGlyph(True);
    tbgAlignHorizontal:
      begin
        Canvas.Pen.Style := psDot;
        Canvas.MoveTo(MidX - 10, MidY + 5);
        Canvas.LineTo(MidX + 11, MidY + 5);
        Canvas.Pen.Style := psSolid;
        Canvas.Brush.Color := TextColor;
        Canvas.Rectangle(MidX - 10, MidY - 4, MidX - 5, MidY + 5);
        Canvas.Rectangle(MidX - 2, MidY - 8, MidX + 3, MidY + 5);
        Canvas.Rectangle(MidX + 6, MidY - 2, MidX + 11, MidY + 5);
      end;
    tbgDistributeHorizontal:
      begin
        Canvas.MoveTo(MidX - 10, MidY - 8);
        Canvas.LineTo(MidX - 10, MidY + 9);
        Canvas.MoveTo(MidX + 10, MidY - 8);
        Canvas.LineTo(MidX + 10, MidY + 9);
        Canvas.Brush.Color := TextColor;
        Canvas.Rectangle(MidX - 7, MidY - 4, MidX - 3, MidY + 5);
        Canvas.Rectangle(MidX - 1, MidY - 4, MidX + 2, MidY + 5);
        Canvas.Rectangle(MidX + 4, MidY - 4, MidX + 8, MidY + 5);
      end;
  end;
  if FCheckState = tbcsMixed then
  begin
    Canvas.Pen.Color := TextColor;
    Canvas.MoveTo(ClientWidth div 4, ClientHeight - 3);
    Canvas.LineTo(ClientWidth - ClientWidth div 4, ClientHeight - 3);
  end;
  if Focused then
  begin
    R := ClientRect;
    InflateRect(R, -3, -3);
    DrawFocusRect(Canvas.Handle, R);
  end;
end;

procedure TSyncLyricsToolbarButton.RequestExecution;
begin
  if not Enabled or (FKind = tbkSeparator) then
    Exit;
  if FKind = tbkToggle then
    case FCheckState of
      tbcsChecked:
        CheckState := tbcsUnchecked;
      tbcsUnchecked, tbcsMixed:
        CheckState := tbcsChecked;
    end;
  if Assigned(FOnExecute) then
    FOnExecute(Self, Self);
  if Assigned(FOnOwnerExecute) then
    FOnOwnerExecute(Self, Self);
end;

procedure TSyncLyricsToolbarButton.SetAccentColor(const Value: TColor);
begin
  if FAccentColor = Value then
    Exit;
  FAccentColor := Value;
  Invalidate;
end;

procedure TSyncLyricsToolbarButton.SetCheckState(
  const Value: TSyncLyricsToolbarCheckState);
begin
  if FCheckState = Value then
    Exit;
  FCheckState := Value;
  Invalidate;
end;

procedure TSyncLyricsToolbarButton.SetGlyph(
  const Value: TSyncLyricsToolbarGlyph);
begin
  if FGlyph = Value then
    Exit;
  FGlyph := Value;
  Invalidate;
end;

procedure TSyncLyricsToolbarButton.SetHasAccentColor(
  const Value: Boolean);
begin
  if FHasAccentColor = Value then
    Exit;
  FHasAccentColor := Value;
  Invalidate;
end;

procedure TSyncLyricsToolbarButton.SetKind(
  const Value: TSyncLyricsToolbarButtonKind);
begin
  if FKind = Value then
    Exit;
  FKind := Value;
  if FKind <> tbkToggle then
    FCheckState := tbcsUnchecked;
  TabStop := FKind <> tbkSeparator;
  Invalidate;
end;

{ TSyncLyricsToolbarButtons }

constructor TSyncLyricsToolbarButtons.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  FButtonExtent := 28;
  FSeparatorExtent := 6;
  FItems := TObjectList<TSyncLyricsToolbarButton>.Create(True);
  Height := FButtonExtent;
end;

destructor TSyncLyricsToolbarButtons.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TSyncLyricsToolbarButtons.AddButton(const HintText: string;
  Glyph: TSyncLyricsToolbarGlyph; Kind: TSyncLyricsToolbarButtonKind;
  TagValue: NativeInt;
  ExecuteEvent: TSyncLyricsToolbarButtonExecuteEvent):
  TSyncLyricsToolbarButton;
begin
  Result := TSyncLyricsToolbarButton.Create(Self);
  Result.Parent := Self;
  Result.Hint := HintText;
  Result.ShowHint := HintText <> '';
  Result.Glyph := Glyph;
  Result.Kind := Kind;
  Result.Tag := TagValue;
  Result.OnExecute := ExecuteEvent;
  Result.FOnOwnerExecute := ButtonExecute;
  FItems.Add(Result);
  UpdateLayout;
end;

function TSyncLyricsToolbarButtons.AddCommandButton(
  const HintText: string; Glyph: TSyncLyricsToolbarGlyph;
  TagValue: NativeInt): TSyncLyricsToolbarButton;
begin
  Result := AddButton(HintText, Glyph, tbkCommand, TagValue);
end;

function TSyncLyricsToolbarButtons.AddDialogButton(
  const HintText: string; Glyph: TSyncLyricsToolbarGlyph;
  TagValue: NativeInt): TSyncLyricsToolbarButton;
begin
  Result := AddButton(HintText, Glyph, tbkDialog, TagValue);
end;

function TSyncLyricsToolbarButtons.AddSeparator:
  TSyncLyricsToolbarButton;
begin
  Result := AddButton('', tbgNone, tbkSeparator, -1);
end;

function TSyncLyricsToolbarButtons.AddToggleButton(
  const HintText: string; Glyph: TSyncLyricsToolbarGlyph;
  TagValue: NativeInt): TSyncLyricsToolbarButton;
begin
  Result := AddButton(HintText, Glyph, tbkToggle, TagValue);
end;

procedure TSyncLyricsToolbarButtons.ButtonExecute(Sender: TObject;
  Button: TSyncLyricsToolbarButton);
begin
  if Assigned(FOnButtonExecute) then
    FOnButtonExecute(Self, Button);
end;

function TSyncLyricsToolbarButtons.FindByTag(
  TagValue: NativeInt): TSyncLyricsToolbarButton;
var
  Item: TSyncLyricsToolbarButton;
begin
  Result := nil;
  for Item in FItems do
    if Item.Tag = TagValue then
      Exit(Item);
end;

function TSyncLyricsToolbarButtons.GetItem(
  Index: Integer): TSyncLyricsToolbarButton;
begin
  Result := FItems[Index];
end;

function TSyncLyricsToolbarButtons.GetItemCount: Integer;
begin
  Result := FItems.Count;
end;

procedure TSyncLyricsToolbarButtons.Relayout;
begin
  UpdateLayout;
end;

procedure TSyncLyricsToolbarButtons.Resize;
begin
  inherited;
  UpdateLayout;
end;

procedure TSyncLyricsToolbarButtons.SetButtonExtent(
  const Value: Integer);
begin
  if FButtonExtent = EnsureRange(Value, 16, 128) then
    Exit;
  FButtonExtent := EnsureRange(Value, 16, 128);
  UpdateLayout;
end;

procedure TSyncLyricsToolbarButtons.SetSeparatorExtent(
  const Value: Integer);
begin
  if FSeparatorExtent = EnsureRange(Value, 1, 32) then
    Exit;
  FSeparatorExtent := EnsureRange(Value, 1, 32);
  UpdateLayout;
end;

procedure TSyncLyricsToolbarButtons.UpdateLayout;
var
  Item: TSyncLyricsToolbarButton;
  ItemWidth: Integer;
  X: Integer;
begin
  X := 0;
  for Item in FItems do
  begin
    if Item.Kind = tbkSeparator then
      ItemWidth := FSeparatorExtent
    else
      ItemWidth := FButtonExtent;
    Item.SetBounds(X, 0, ItemWidth, FButtonExtent);
    Inc(X, ItemWidth);
  end;
end;

end.
