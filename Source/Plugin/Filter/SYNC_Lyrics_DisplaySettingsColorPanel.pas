unit SYNC_Lyrics_DisplaySettingsColorPanel;

// Shared visual color sidebar for all display-setting mode pages.

interface

uses
  System.Classes,
  System.UITypes,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Vcl.StdCtrls,
  ColorPickerHueBar,
  ColorPickerSVArea,
  SYNC_Lyrics_ToolbarButtons;

type
  TDisplaySettingsEmbeddedColorPicker = class(TCustomControl)
  private
    FColor: TColor;
    FCurrentHue: Double;
    FHueBar: TColorPickerHueBar;
    FSVArea: TColorPickerSVArea;
    FUpdating: Boolean;
    FOnChange: TNotifyEvent;
    procedure HueBarChange(Sender: TObject);
    procedure SetColor(const Value: TColor);
    procedure SVAreaChange(Sender: TObject);
    procedure SyncControls;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Color: TColor read FColor write SetColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  TDisplaySettingsColorPanel = class(TPanel)
  private
    FAfterLabel: TLabel;
    FAfterOpacityLabel: TLabel;
    FAfterOpacityTrack: TTrackBar;
    FAfterPicker: TDisplaySettingsEmbeddedColorPicker;
    FBeforeLabel: TLabel;
    FBeforeOpacityLabel: TLabel;
    FBeforeOpacityTrack: TTrackBar;
    FBeforePicker: TDisplaySettingsEmbeddedColorPicker;
    FTargetToolbar: TSyncLyricsToolbarButtons;
    FTargetIndex: Integer;
    FUpdating: Boolean;
    FOnChange: TNotifyEvent;
    FOnTargetChange: TNotifyEvent;
    function GetAfterOpacity: Byte;
    function GetBeforeOpacity: Byte;
    procedure OpacityChange(Sender: TObject);
    procedure PickerChange(Sender: TObject);
    procedure TargetExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Configure(TargetIndex: Integer; BeforeColor, AfterColor: TColor;
      BeforeOpacity, AfterOpacity: Byte);
    property AfterPicker: TDisplaySettingsEmbeddedColorPicker
      read FAfterPicker;
    property BeforePicker: TDisplaySettingsEmbeddedColorPicker
      read FBeforePicker;
    property AfterOpacity: Byte read GetAfterOpacity;
    property AfterOpacityTrack: TTrackBar read FAfterOpacityTrack;
    property BeforeOpacity: Byte read GetBeforeOpacity;
    property BeforeOpacityTrack: TTrackBar read FBeforeOpacityTrack;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnTargetChange: TNotifyEvent read FOnTargetChange
      write FOnTargetChange;
    property TargetIndex: Integer read FTargetIndex;
    property TargetToolbar: TSyncLyricsToolbarButtons read FTargetToolbar;
  end;

implementation

uses
  System.Math,
  Winapi.Windows,
  ColorPickerColorMath,
  SYNC_Lyrics_DarkTheme;

constructor TDisplaySettingsEmbeddedColorPicker.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  if AOwner is TWinControl then
    Parent := TWinControl(AOwner);
  FCurrentHue := 0;
  FHueBar := TColorPickerHueBar.Create(Self);
  FHueBar.Parent := Self;
  FHueBar.Align := alRight;
  FHueBar.OnChange := HueBarChange;
  FSVArea := TColorPickerSVArea.Create(Self);
  FSVArea.Parent := Self;
  FSVArea.Align := alClient;
  FSVArea.OnChange := SVAreaChange;
  Color := clWhite;
end;

procedure TDisplaySettingsEmbeddedColorPicker.HueBarChange(Sender: TObject);
var
  Saturation: Double;
  Value: Double;
begin
  if FUpdating then
    Exit;
  FCurrentHue := ColorHue(FHueBar.Color);
  ColorToSv(FColor, Saturation, Value);
  FColor := HsvToColor(FCurrentHue, Saturation, Value);
  SyncControls;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TDisplaySettingsEmbeddedColorPicker.Resize;
begin
  inherited;
  FHueBar.Width := MulDiv(24, CurrentPPI, 96);
end;

procedure TDisplaySettingsEmbeddedColorPicker.SetColor(const Value: TColor);
var
  ColorValue: Double;
  Hue: Double;
  Saturation: Double;
begin
  FColor := ColorToRGB(Value);
  ColorToHsv(FColor, Hue, Saturation, ColorValue);
  if (Saturation > 0.000001) and (ColorValue > 0) then
    FCurrentHue := Hue;
  SyncControls;
end;

procedure TDisplaySettingsEmbeddedColorPicker.SVAreaChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FColor := FSVArea.Color;
  SyncControls;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TDisplaySettingsEmbeddedColorPicker.SyncControls;
begin
  if FUpdating then
    Exit;
  FUpdating := True;
  try
    FHueBar.Color := HsvToColor(FCurrentHue, 1, 1);
    FSVArea.BaseColor := HsvToColor(FCurrentHue, 1, 1);
    FSVArea.Color := FColor;
  finally
    FUpdating := False;
  end;
end;

constructor TDisplaySettingsColorPanel.Create(AOwner: TComponent);
const
  TARGET_HINTS: array[0..3] of string = (
    #22320#33394, #32257#21462#12426#33394, #24433#33394,
    #32257#21462#12426#12412#12363#12375#33394);
  TARGET_GLYPHS: array[0..3] of TSyncLyricsToolbarGlyph = (
    tbgFillColor, tbgOutlineColor, tbgShadowColor, tbgBlurColor);
var
  I: Integer;
begin
  inherited Create(AOwner);
  if AOwner is TWinControl then
    Parent := TWinControl(AOwner);
  BevelOuter := bvNone;
  Caption := '';
  ApplySyncLyricsDarkPanel(Self);
  FTargetToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FTargetToolbar.Parent := Self;
  FTargetToolbar.Color := Color;
  FTargetToolbar.ParentBackground := False;
  FTargetToolbar.SeparatorExtent := 0;
  FTargetToolbar.OnButtonExecute := TargetExecute;
  for I := 0 to 3 do
    FTargetToolbar.AddToggleButton(TARGET_HINTS[I], TARGET_GLYPHS[I], I);
  FTargetToolbar.FindByTag(0).CheckState := tbcsChecked;
  FTargetIndex := 0;

  FBeforeLabel := TLabel.Create(Self);
  FBeforeLabel.Parent := Self;
  FBeforeLabel.Caption := #21516#26399#21069;
  FBeforeLabel.Font.Assign(Font);
  FBeforePicker := TDisplaySettingsEmbeddedColorPicker.Create(Self);
  FBeforePicker.Parent := Self;
  FBeforePicker.Color := clWhite;
  FBeforePicker.OnChange := PickerChange;
  FBeforeOpacityLabel := TLabel.Create(Self);
  FBeforeOpacityLabel.Parent := Self;
  FBeforeOpacityLabel.Caption := #36879#26126#24230;
  FBeforeOpacityLabel.Font.Assign(Font);
  FBeforeOpacityTrack := TTrackBar.Create(Self);
  FBeforeOpacityTrack.Parent := Self;
  FBeforeOpacityTrack.Min := 0;
  FBeforeOpacityTrack.Max := 255;
  FBeforeOpacityTrack.Position := 255;
  FBeforeOpacityTrack.TickStyle := tsNone;
  FBeforeOpacityTrack.OnChange := OpacityChange;

  FAfterLabel := TLabel.Create(Self);
  FAfterLabel.Parent := Self;
  FAfterLabel.Caption := #21516#26399#24460;
  FAfterLabel.Font.Assign(Font);
  FAfterPicker := TDisplaySettingsEmbeddedColorPicker.Create(Self);
  FAfterPicker.Parent := Self;
  FAfterPicker.Color := TColor($0000FFFF);
  FAfterPicker.OnChange := PickerChange;
  FAfterOpacityLabel := TLabel.Create(Self);
  FAfterOpacityLabel.Parent := Self;
  FAfterOpacityLabel.Caption := #36879#26126#24230;
  FAfterOpacityLabel.Font.Assign(Font);
  FAfterOpacityTrack := TTrackBar.Create(Self);
  FAfterOpacityTrack.Parent := Self;
  FAfterOpacityTrack.Min := 0;
  FAfterOpacityTrack.Max := 255;
  FAfterOpacityTrack.Position := 255;
  FAfterOpacityTrack.TickStyle := tsNone;
  FAfterOpacityTrack.OnChange := OpacityChange;
end;

procedure TDisplaySettingsColorPanel.Configure(TargetIndex: Integer;
  BeforeColor, AfterColor: TColor; BeforeOpacity, AfterOpacity: Byte);
var
  Button: TSyncLyricsToolbarButton;
  I: Integer;
begin
  FUpdating := True;
  try
    FTargetIndex := EnsureRange(TargetIndex, 0, 3);
    for I := 0 to 3 do
    begin
      Button := FTargetToolbar.FindByTag(I);
      if Button <> nil then
        Button.CheckState := TSyncLyricsToolbarCheckState(
          Ord(I = FTargetIndex));
    end;
    FBeforePicker.Color := BeforeColor;
    FAfterPicker.Color := AfterColor;
    FBeforeOpacityTrack.Position := BeforeOpacity;
    FAfterOpacityTrack.Position := AfterOpacity;
  finally
    FUpdating := False;
  end;
end;

function TDisplaySettingsColorPanel.GetAfterOpacity: Byte;
begin
  Result := Byte(FAfterOpacityTrack.Position);
end;

function TDisplaySettingsColorPanel.GetBeforeOpacity: Byte;
begin
  Result := Byte(FBeforeOpacityTrack.Position);
end;

procedure TDisplaySettingsColorPanel.OpacityChange(Sender: TObject);
begin
  if not FUpdating and Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TDisplaySettingsColorPanel.PickerChange(Sender: TObject);
begin
  if not FUpdating and Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TDisplaySettingsColorPanel.TargetExecute(Sender: TObject;
  Button: TSyncLyricsToolbarButton);
var
  I: Integer;
  TargetButton: TSyncLyricsToolbarButton;
begin
  if FUpdating then
    Exit;
  FTargetIndex := EnsureRange(Button.Tag, 0, 3);
  FUpdating := True;
  try
    for I := 0 to 3 do
    begin
      TargetButton := FTargetToolbar.FindByTag(I);
      if TargetButton <> nil then
        TargetButton.CheckState := TSyncLyricsToolbarCheckState(
          Ord(I = FTargetIndex));
    end;
  finally
    FUpdating := False;
  end;
  if Assigned(FOnTargetChange) then
    FOnTargetChange(Self);
end;

procedure TDisplaySettingsColorPanel.Resize;
var
  AlphaHeight: Integer;
  Extent: Integer;
  Gap: Integer;
  LabelHeight: Integer;
  Margin: Integer;
  PickerHeight: Integer;
  TopValue: Integer;
begin
  inherited;
  if FTargetToolbar = nil then
    Exit;
  Margin := MulDiv(8, CurrentPPI, 96);
  Gap := MulDiv(6, CurrentPPI, 96);
  Extent := MulDiv(28, CurrentPPI, 96);
  LabelHeight := MulDiv(18, CurrentPPI, 96);
  AlphaHeight := MulDiv(24, CurrentPPI, 96);
  PickerHeight := Min(Max(MulDiv(72, CurrentPPI, 96),
    ClientWidth - Margin * 2 - MulDiv(24, CurrentPPI, 96)),
    Max(MulDiv(72, CurrentPPI, 96),
      (ClientHeight - Margin * 2 - Extent - Gap * 5 - LabelHeight * 2 -
        AlphaHeight * 2) div 2));
  FTargetToolbar.ButtonExtent := Extent;
  FTargetToolbar.SetBounds(Margin, Margin, ClientWidth - Margin * 2, Extent);
  TopValue := Margin + Extent + Gap;
  FBeforeLabel.SetBounds(Margin, TopValue, ClientWidth - Margin * 2,
    LabelHeight);
  Inc(TopValue, LabelHeight);
  FBeforePicker.SetBounds(Margin, TopValue, ClientWidth - Margin * 2,
    PickerHeight);
  Inc(TopValue, PickerHeight + Gap);
  FBeforeOpacityLabel.SetBounds(Margin, TopValue,
    MulDiv(42, CurrentPPI, 96), AlphaHeight);
  FBeforeOpacityTrack.SetBounds(FBeforeOpacityLabel.Left +
    FBeforeOpacityLabel.Width, TopValue,
    ClientWidth - Margin - FBeforeOpacityLabel.Left -
      FBeforeOpacityLabel.Width, AlphaHeight);
  Inc(TopValue, AlphaHeight + Gap);
  FAfterLabel.SetBounds(Margin, TopValue, ClientWidth - Margin * 2,
    LabelHeight);
  Inc(TopValue, LabelHeight);
  FAfterPicker.SetBounds(Margin, TopValue, ClientWidth - Margin * 2,
    PickerHeight);
  Inc(TopValue, PickerHeight + Gap);
  FAfterOpacityLabel.SetBounds(Margin, TopValue,
    MulDiv(42, CurrentPPI, 96), AlphaHeight);
  FAfterOpacityTrack.SetBounds(FAfterOpacityLabel.Left +
    FAfterOpacityLabel.Width, TopValue,
    ClientWidth - Margin - FAfterOpacityLabel.Left -
      FAfterOpacityLabel.Width, AlphaHeight);
end;

end.
