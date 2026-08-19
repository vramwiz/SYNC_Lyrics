unit SYNC_Lyrics_LineDisplaySettingsForm;

// Provides the minimal line-layout preview and whole-base/whole-ruby selection.

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.ComCtrls,
  Vcl.StdCtrls,
  ColorPickerHueBar,
  ColorPickerSVArea,
  TextRendererSkia,
  TextRendererTypes,
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_ToolbarButtons;

type
  TSyncLyricsEmbeddedColorPicker = class(TCustomControl)
  private
    FColor: TColor;
    FCurrentHue: Double;
    FHueBar: TColorPickerHueBar;
    FOnChange: TNotifyEvent;
    FSVArea: TColorPickerSVArea;
    FUpdating: Boolean;
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

  TLineDisplaySelection = (ldsBase, ldsRuby);
  TLineDisplayColorTarget = (ldctFill, ldctOutline, ldctShadow, ldctBlur);
  TLineDisplayDragMode = (lddNone, lddMoveGroup, lddRubyGap,
    lddResizeTopLeft, lddResizeTopRight, lddResizeBottomLeft,
    lddResizeBottomRight, lddSpacingLeft, lddSpacingRight,
    lddOutlineWidth, lddOutlineBlur, lddShadowOffset, lddShadowBlur,
    lddShadowSpread);

  TFormLyricsLineDisplaySettings = class(TForm)
    CandidateLabel: TLabel;
    CandidateCombo: TComboBox;
    BaseFontLabel: TLabel;
    BaseFontCombo: TComboBox;
    RubyFontLabel: TLabel;
    RubyFontCombo: TComboBox;
    PreviewPaintBox: TPaintBox;
    ColorPanel: TPanel;
    ButtonPanel: TPanel;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure CandidateComboChange(Sender: TObject);
    procedure BaseFontComboChange(Sender: TObject);
    procedure RubyFontComboChange(Sender: TObject);
    procedure DarkComboBoxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure PreviewPaintBoxMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PreviewPaintBoxMouseMove(Sender: TObject;
      Shift: TShiftState; X, Y: Integer);
    procedure PreviewPaintBoxMouseUp(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PreviewPaintBoxPaint(Sender: TObject);
  private
    FBackground: TBitmap;
    FBaseBounds: TRect;
    FBaseFontHeight: Integer;
    FBaseFontName: string;
    FBaseFontStyle: Byte;
    FBaseCharacterSpacing: Integer;
    FAfterColor: TColor;
    FBeforeColor: TColor;
    FLyrics: string;
    FPlainText: string;
    FRubyBounds: TRect;
    FRubyFontHeight: Integer;
    FRubyFontName: string;
    FRubyFontStyle: Byte;
    FRubyCharacterSpacing: Integer;
    FRubyGapAdjustment: Integer;
    FRubyRects: TArray<TRect>;
    FRubySpans: TLyricsRubySpans;
    FSelection: TLineDisplaySelection;
    FPositionX: Integer;
    FPositionY: Integer;
    FPreviewRenderer: TSkiaTextRenderer;
    FDragMode: TLineDisplayDragMode;
    FDragStartPoint: TPoint;
    FDragStartBounds: TRect;
    FDragStartBaseBounds: TRect;
    FDragStartBaseFontHeight: Integer;
    FDragStartRubyFontHeight: Integer;
    FDragStartBaseCharacterSpacing: Integer;
    FDragStartRubyCharacterSpacing: Integer;
    FDragStartRubyGapAdjustment: Integer;
    FDragStartPositionX: Integer;
    FDragStartPositionY: Integer;
    FDragStartOutlineWidth: Single;
    FDragStartOutlineBlur: Single;
    FDragStartShadowOffsetX: Single;
    FDragStartShadowOffsetY: Single;
    FDragStartShadowBlur: Single;
    FDragStartShadowSpread: Single;
    FToolbar: TSyncLyricsToolbarButtons;
    FToolbarBold: TSyncLyricsToolbarButton;
    FToolbarItalic: TSyncLyricsToolbarButton;
    FToolbarOutline: TSyncLyricsToolbarButton;
    FToolbarShadow: TSyncLyricsToolbarButton;
    FToolbarStrikeOut: TSyncLyricsToolbarButton;
    FToolbarUnderline: TSyncLyricsToolbarButton;
    FUpdatingControls: Boolean;
    FCandidateLyrics: TArray<string>;
    FCandidateSettings: TArray<TDisplayCommonSettings>;
    FAfterColorPicker: TSyncLyricsEmbeddedColorPicker;
    FAfterColorLabel: TLabel;
    FAfterOpacityLabel: TLabel;
    FAfterOpacityTrack: TTrackBar;
    FBeforeColorPicker: TSyncLyricsEmbeddedColorPicker;
    FBeforeColorLabel: TLabel;
    FBeforeOpacityLabel: TLabel;
    FBeforeOpacityTrack: TTrackBar;
    FColorTarget: TLineDisplayColorTarget;
    FColorTargetToolbar: TSyncLyricsToolbarButtons;
    FColorTargetButtons: array[TLineDisplayColorTarget] of
      TSyncLyricsToolbarButton;
    FBeforePalette: array[TLineDisplayColorTarget] of TColor;
    FAfterPalette: array[TLineDisplayColorTarget] of TColor;
    FBeforePaletteOpacity: array[TLineDisplayColorTarget] of Byte;
    FAfterPaletteOpacity: array[TLineDisplayColorTarget] of Byte;
    FOutlineEnabled: Boolean;
    FOutlineWidth: Single;
    FOutlineBlur: Single;
    FShadowEnabled: Boolean;
    FShadowOffsetX: Single;
    FShadowOffsetY: Single;
    FShadowBlur: Single;
    FShadowSpread: Single;
    function BackgroundDestinationRect: TRect;
    function BackgroundScale: Double;
    procedure CalculateLayout(Canvas: TCanvas; DrawText: Boolean);
    procedure CreateFormattingToolbar;
    procedure CreateColorControls;
    procedure ColorPickerChange(Sender: TObject);
    procedure ColorTargetExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure OpacityTrackChange(Sender: TObject);
    procedure DrawSelection(Canvas: TCanvas);
    procedure DrawDecorationHandles(Canvas: TCanvas);
    procedure DrawDecoratedText(Canvas: TCanvas; X, Y: Integer;
      const Text: string; AfterPhase: Boolean);
    procedure DrawHalfSyncedText(Canvas: TCanvas; X, Y: Integer;
      const Text: string; TransitionX, CharacterSpacing: Integer);
    function RenderPreviewTextImage(Canvas: TCanvas; const Text: string;
      CharacterSpacing: Integer; AfterPhase: Boolean): TTextRenderImage;
    function CreatePreviewBitmap(Image: TTextRenderImage):
      Vcl.Graphics.TBitmap;
    procedure DrawPreviewImage(Canvas: TCanvas; Image: TTextRenderImage;
      X, Y, TransitionX: Integer; AfterPhase: Boolean);
    function DecorationHandleRect(Mode: TLineDisplayDragMode): TRect;
    function HitTestDragMode(const Point: TPoint): TLineDisplayDragMode;
    function RubySpacingIntervalCount: Integer;
    procedure StartDrag(Mode: TLineDisplayDragMode; const Point: TPoint);
    procedure UpdateDrag(const Point: TPoint);
    procedure ParseCurrentLyrics;
    procedure ToolbarButtonExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure UpdateFontCombos;
    procedure UpdateColorControls;
    procedure UpdateFormattingControls;
    procedure LayoutColorControls;
    procedure UpdateTopLayout;
  public
    procedure Configure(const Lyrics: string;
      const CommonSettings: TDisplayCommonSettings);
    procedure ConfigureCandidates(const Captions, Lyrics: TArray<string>;
      const CommonSettings: TArray<TDisplayCommonSettings>;
      InitialIndex: Integer);
    function EnteredLyrics: string;
    function SelectedCandidateIndex: Integer;
    function SelectedCommonSettings: TDisplayCommonSettings;
    procedure SetBackgroundRgba(const Pixels: TBytes;
      Width, Height: Integer);
  end;

implementation

uses
  ColorPickerColorMath,
  System.Math,
  Winapi.Windows,
  TextRendererSkiaRuntime,
  SYNC_Lyrics_DarkTheme;

{$R *.dfm}

type
  TControlAccess = class(TControl);

const
  DEFAULT_RUBY_GAP = 4;
  HANDLE_SIZE = 8;
  HIT_MARGIN = 6;
  MIN_FONT_HEIGHT = 1;
  MAX_FONT_HEIGHT = 1024;
  MIN_CHARACTER_SPACING = -100;
  MAX_CHARACTER_SPACING = 100;
  MIN_RUBY_GAP_ADJUSTMENT = -200;
  MAX_RUBY_GAP_ADJUSTMENT = 500;
  MIN_POSITION = -10000;
  MAX_POSITION = 10000;
  MAX_DECORATION_SIZE = 500;
  MAX_SHADOW_OFFSET = 2000;
  TOOLBAR_BOLD = 2;
  TOOLBAR_ITALIC = 3;
  TOOLBAR_UNDERLINE = 4;
  TOOLBAR_STRIKE_OUT = 5;
  TOOLBAR_OUTLINE = 6;
  TOOLBAR_SHADOW = 7;
  COLOR_TARGET_BASE = 20;

{ TSyncLyricsEmbeddedColorPicker }

constructor TSyncLyricsEmbeddedColorPicker.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FColor := clWhite;
  FCurrentHue := 0;
  FHueBar := TColorPickerHueBar.Create(Self);
  FHueBar.Parent := Self;
  FHueBar.Align := alRight;
  FHueBar.Width := MulDiv(24, CurrentPPI, 96);
  FHueBar.OnChange := HueBarChange;
  FSVArea := TColorPickerSVArea.Create(Self);
  FSVArea.Parent := Self;
  FSVArea.Align := alClient;
  FSVArea.OnChange := SVAreaChange;
  SyncControls;
end;

procedure TSyncLyricsEmbeddedColorPicker.HueBarChange(Sender: TObject);
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

procedure TSyncLyricsEmbeddedColorPicker.Resize;
begin
  inherited;
  FHueBar.Width := MulDiv(24, CurrentPPI, 96);
end;

procedure TSyncLyricsEmbeddedColorPicker.SetColor(const Value: TColor);
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

procedure TSyncLyricsEmbeddedColorPicker.SVAreaChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FColor := FSVArea.Color;
  SyncControls;
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TSyncLyricsEmbeddedColorPicker.SyncControls;
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

function FontStylesFromByte(Value: Byte): TFontStyles;
begin
  Result := [];
  if (Value and 1) <> 0 then
    Include(Result, fsBold);
  if (Value and 2) <> 0 then
    Include(Result, fsItalic);
  if (Value and 4) <> 0 then
    Include(Result, fsUnderline);
  if (Value and 8) <> 0 then
    Include(Result, fsStrikeOut);
end;

function MeasureTextWidth(Canvas: TCanvas; const Text: string): Integer;
var
  CharacterExtra: Integer;
  TextSize: TSize;
begin
  if Text = '' then
    Exit(0);
  if not GetTextExtentPoint32W(Canvas.Handle, PWideChar(Text), Length(Text),
    TextSize) then
    Exit(0);
  CharacterExtra := GetTextCharacterExtra(Canvas.Handle);
  Result := Max(0, TextSize.cx - CharacterExtra);
end;

function PreviewColor(Color: TColor; Opacity: Byte): TColor;
var
  ResolvedColor: Cardinal;
begin
  ResolvedColor := ColorToRGB(Color);
  Result := RGB(
    ((ResolvedColor and $FF) * Opacity) div 255,
    (((ResolvedColor shr 8) and $FF) * Opacity) div 255,
    (((ResolvedColor shr 16) and $FF) * Opacity) div 255);
end;

function HandleRect(const Center: TPoint): TRect;
var
  HalfSize: Integer;
begin
  HalfSize := HANDLE_SIZE div 2;
  Result := Rect(Center.X - HalfSize, Center.Y - HalfSize,
    Center.X + HalfSize + 1, Center.Y + HalfSize + 1);
end;

function TFormLyricsLineDisplaySettings.BackgroundDestinationRect: TRect;
var
  DrawHeight: Integer;
  DrawWidth: Integer;
  Scale: Double;
begin
  Result := PreviewPaintBox.ClientRect;
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  Scale := Min(PreviewPaintBox.ClientWidth / FBackground.Width,
    PreviewPaintBox.ClientHeight / FBackground.Height);
  DrawWidth := Max(1, Round(FBackground.Width * Scale));
  DrawHeight := Max(1, Round(FBackground.Height * Scale));
  Result.Left := (PreviewPaintBox.ClientWidth - DrawWidth) div 2;
  Result.Top := (PreviewPaintBox.ClientHeight - DrawHeight) div 2;
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

function TFormLyricsLineDisplaySettings.BackgroundScale: Double;
var
  Destination: TRect;
begin
  Result := 1;
  if FBackground.Width <= 0 then
    Exit;
  Destination := BackgroundDestinationRect;
  Result := Destination.Width / FBackground.Width;
end;

procedure TFormLyricsLineDisplaySettings.Configure(const Lyrics: string;
  const CommonSettings: TDisplayCommonSettings);
begin
  FBaseFontName := CommonSettings.BaseFontName;
  FRubyFontName := CommonSettings.RubyFontName;
  FBaseFontHeight := Max(1, CommonSettings.BaseFontHeight);
  FRubyFontHeight := Max(1, CommonSettings.RubyFontHeight);
  FRubyGapAdjustment := EnsureRange(CommonSettings.RubyGapAdjustment,
    MIN_RUBY_GAP_ADJUSTMENT, MAX_RUBY_GAP_ADJUSTMENT);
  FBaseCharacterSpacing := EnsureRange(CommonSettings.BaseCharacterSpacing,
    MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
  FRubyCharacterSpacing := EnsureRange(CommonSettings.RubyCharacterSpacing,
    MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
  FPositionX := EnsureRange(CommonSettings.PositionX,
    MIN_POSITION, MAX_POSITION);
  FPositionY := EnsureRange(CommonSettings.PositionY,
    MIN_POSITION, MAX_POSITION);
  FBeforeColor := TColor(CommonSettings.BeforeColor);
  FAfterColor := TColor(CommonSettings.AfterColor);
  FBeforePalette[ldctFill] := FBeforeColor;
  FAfterPalette[ldctFill] := FAfterColor;
  FBeforePalette[ldctOutline] := TColor(CommonSettings.BeforeOutlineColor);
  FAfterPalette[ldctOutline] := TColor(CommonSettings.AfterOutlineColor);
  FBeforePalette[ldctShadow] := TColor(CommonSettings.BeforeShadowColor);
  FAfterPalette[ldctShadow] := TColor(CommonSettings.AfterShadowColor);
  FBeforePalette[ldctBlur] := TColor(CommonSettings.BeforeBlurColor);
  FAfterPalette[ldctBlur] := TColor(CommonSettings.AfterBlurColor);
  FBeforePaletteOpacity[ldctFill] := CommonSettings.BeforeOpacity;
  FAfterPaletteOpacity[ldctFill] := CommonSettings.AfterOpacity;
  FBeforePaletteOpacity[ldctOutline] :=
    CommonSettings.BeforeOutlineOpacity;
  FAfterPaletteOpacity[ldctOutline] := CommonSettings.AfterOutlineOpacity;
  FBeforePaletteOpacity[ldctShadow] := CommonSettings.BeforeShadowOpacity;
  FAfterPaletteOpacity[ldctShadow] := CommonSettings.AfterShadowOpacity;
  FBeforePaletteOpacity[ldctBlur] := CommonSettings.BeforeBlurOpacity;
  FAfterPaletteOpacity[ldctBlur] := CommonSettings.AfterBlurOpacity;
  FOutlineEnabled := CommonSettings.OutlineEnabled;
  FOutlineWidth := CommonSettings.OutlineWidth;
  FOutlineBlur := CommonSettings.OutlineBlur;
  FShadowEnabled := CommonSettings.ShadowEnabled;
  FShadowOffsetX := CommonSettings.ShadowOffsetX;
  FShadowOffsetY := CommonSettings.ShadowOffsetY;
  FShadowBlur := CommonSettings.ShadowBlur;
  FShadowSpread := CommonSettings.ShadowSpread;
  FBaseFontStyle := CommonSettings.BaseFontStyle;
  FRubyFontStyle := CommonSettings.RubyFontStyle;
  FLyrics := Lyrics;
  ParseCurrentLyrics;
  UpdateFontCombos;
  UpdateFormattingControls;
  UpdateColorControls;
  PreviewPaintBox.Invalidate;
end;

procedure TFormLyricsLineDisplaySettings.ConfigureCandidates(
  const Captions, Lyrics: TArray<string>;
  const CommonSettings: TArray<TDisplayCommonSettings>;
  InitialIndex: Integer);
var
  I: Integer;
begin
  FCandidateLyrics := Copy(Lyrics);
  FCandidateSettings := Copy(CommonSettings);
  CandidateCombo.Items.BeginUpdate;
  try
    CandidateCombo.Items.Clear;
    for I := 0 to High(Captions) do
      CandidateCombo.Items.Add(Captions[I]);
  finally
    CandidateCombo.Items.EndUpdate;
  end;
  CandidateLabel.Visible := CandidateCombo.Items.Count > 0;
  CandidateCombo.Visible := CandidateLabel.Visible;
  UpdateTopLayout;
  if CandidateCombo.Items.Count = 0 then
    Exit;
  CandidateCombo.ItemIndex := EnsureRange(InitialIndex, 0,
    CandidateCombo.Items.Count - 1);
  CandidateComboChange(CandidateCombo);
end;

procedure TFormLyricsLineDisplaySettings.CandidateComboChange(
  Sender: TObject);
var
  Index: Integer;
begin
  Index := CandidateCombo.ItemIndex;
  if (Index < 0) or (Index >= Length(FCandidateLyrics)) or
    (Index >= Length(FCandidateSettings)) then
    Exit;
  Configure(FCandidateLyrics[Index], FCandidateSettings[Index]);
end;

procedure TFormLyricsLineDisplaySettings.CreateFormattingToolbar;
var
  Extent: Integer;
begin
  Extent := MulDiv(28, CurrentPPI, 96);
  FToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.SetBounds(RubyFontCombo.Left + RubyFontCombo.Width +
    MulDiv(16, CurrentPPI, 96), BaseFontCombo.Top, MulDiv(200,
    CurrentPPI, 96), Extent);
  FToolbar.Anchors := [akLeft, akTop, akRight];
  FToolbar.ButtonExtent := Extent;
  FToolbar.SeparatorExtent := MulDiv(6, CurrentPPI, 96);
  FToolbar.Color := Color;
  FToolbar.ParentBackground := False;
  FToolbar.OnButtonExecute := ToolbarButtonExecute;
  FToolbarBold := FToolbar.AddToggleButton(#22826#23383,
    tbgBold, TOOLBAR_BOLD);
  FToolbarItalic := FToolbar.AddToggleButton(#26012#20307, tbgItalic,
    TOOLBAR_ITALIC);
  FToolbarUnderline := FToolbar.AddToggleButton(#19979#32218, tbgUnderline,
    TOOLBAR_UNDERLINE);
  FToolbarStrikeOut := FToolbar.AddToggleButton(
    #21462#12426#28040#12375#32218,
    tbgStrikeOut, TOOLBAR_STRIKE_OUT);
  FToolbar.AddSeparator;
  FToolbarOutline := FToolbar.AddToggleButton(
    #32257#21462#12426#12398#26377#21177#65295#28961#21177,
    tbgOutline, TOOLBAR_OUTLINE);
  FToolbarShadow := FToolbar.AddToggleButton(
    #24433#12398#26377#21177#65295#28961#21177,
    tbgShadow, TOOLBAR_SHADOW);
end;

procedure TFormLyricsLineDisplaySettings.CreateColorControls;
const
  HINTS: array[TLineDisplayColorTarget] of string = (
    #22320#33394, #32257#21462#12426#33394, #24433#33394,
    #32257#21462#12426#12412#12363#12375#33394);
  GLYPHS: array[TLineDisplayColorTarget] of TSyncLyricsToolbarGlyph = (
    tbgFillColor, tbgOutlineColor, tbgShadowColor, tbgBlurColor);
var
  Target: TLineDisplayColorTarget;
begin
  FColorTargetToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FColorTargetToolbar.Parent := ColorPanel;
  FColorTargetToolbar.ButtonExtent := MulDiv(28, CurrentPPI, 96);
  FColorTargetToolbar.SeparatorExtent := 0;
  FColorTargetToolbar.Color := ColorPanel.Color;
  FColorTargetToolbar.ParentBackground := False;
  FColorTargetToolbar.OnButtonExecute := ColorTargetExecute;
  for Target := Low(TLineDisplayColorTarget) to High(TLineDisplayColorTarget) do
    FColorTargetButtons[Target] := FColorTargetToolbar.AddToggleButton(
      HINTS[Target], GLYPHS[Target], COLOR_TARGET_BASE + Ord(Target));

  FBeforeColorLabel := TLabel.Create(Self);
  FBeforeColorLabel.Parent := ColorPanel;
  FBeforeColorLabel.Caption := #21516#26399#21069;
  FBeforeColorLabel.Font.Assign(Font);

  FBeforeColorPicker := TSyncLyricsEmbeddedColorPicker.Create(Self);
  FBeforeColorPicker.Parent := ColorPanel;
  FBeforeColorPicker.OnChange := ColorPickerChange;

  FBeforeOpacityTrack := TTrackBar.Create(Self);
  FBeforeOpacityTrack.Parent := ColorPanel;
  FBeforeOpacityTrack.Min := 0;
  FBeforeOpacityTrack.Max := 255;
  FBeforeOpacityTrack.Position := 255;
  FBeforeOpacityTrack.TickStyle := tsNone;
  FBeforeOpacityTrack.OnChange := OpacityTrackChange;
  FBeforeOpacityTrack.ShowHint := True;
  FBeforeOpacityTrack.Hint := #21516#26399#21069#33394#12398#36879#26126#24230;
  FBeforeOpacityLabel := TLabel.Create(Self);
  FBeforeOpacityLabel.Parent := ColorPanel;
  FBeforeOpacityLabel.Caption := #36879#26126#24230;
  FBeforeOpacityLabel.Font.Assign(Font);

  FAfterColorLabel := TLabel.Create(Self);
  FAfterColorLabel.Parent := ColorPanel;
  FAfterColorLabel.Caption := #21516#26399#24460;
  FAfterColorLabel.Font.Assign(Font);

  FAfterColorPicker := TSyncLyricsEmbeddedColorPicker.Create(Self);
  FAfterColorPicker.Parent := ColorPanel;
  FAfterColorPicker.OnChange := ColorPickerChange;

  FAfterOpacityTrack := TTrackBar.Create(Self);
  FAfterOpacityTrack.Parent := ColorPanel;
  FAfterOpacityTrack.Min := 0;
  FAfterOpacityTrack.Max := 255;
  FAfterOpacityTrack.Position := 255;
  FAfterOpacityTrack.TickStyle := tsNone;
  FAfterOpacityTrack.OnChange := OpacityTrackChange;
  FAfterOpacityTrack.ShowHint := True;
  FAfterOpacityTrack.Hint := #21516#26399#24460#33394#12398#36879#26126#24230;
  FAfterOpacityLabel := TLabel.Create(Self);
  FAfterOpacityLabel.Parent := ColorPanel;
  FAfterOpacityLabel.Caption := #36879#26126#24230;
  FAfterOpacityLabel.Font.Assign(Font);
end;

procedure TFormLyricsLineDisplaySettings.ColorPickerChange(Sender: TObject);
begin
  if FUpdatingControls then
    Exit;
  if Sender = FBeforeColorPicker then
  begin
    FBeforePalette[FColorTarget] := FBeforeColorPicker.Color;
    if FColorTarget = ldctFill then
      FBeforeColor := FBeforeColorPicker.Color;
  end
  else if Sender = FAfterColorPicker then
  begin
    FAfterPalette[FColorTarget] := FAfterColorPicker.Color;
    if FColorTarget = ldctFill then
      FAfterColor := FAfterColorPicker.Color;
  end;
  PreviewPaintBox.Invalidate;
end;

procedure TFormLyricsLineDisplaySettings.ColorTargetExecute(Sender: TObject;
  Button: TSyncLyricsToolbarButton);
begin
  if (Button.Tag < COLOR_TARGET_BASE) or
    (Button.Tag > COLOR_TARGET_BASE + Ord(High(TLineDisplayColorTarget))) then
    Exit;
  FColorTarget := TLineDisplayColorTarget(Button.Tag - COLOR_TARGET_BASE);
  UpdateColorControls;
end;

procedure TFormLyricsLineDisplaySettings.OpacityTrackChange(Sender: TObject);
begin
  if FUpdatingControls then
    Exit;
  if Sender = FBeforeOpacityTrack then
  begin
    FBeforePaletteOpacity[FColorTarget] := FBeforeOpacityTrack.Position
  end
  else if Sender = FAfterOpacityTrack then
  begin
    FAfterPaletteOpacity[FColorTarget] := FAfterOpacityTrack.Position;
  end;
  PreviewPaintBox.Invalidate;
end;

procedure TFormLyricsLineDisplaySettings.DarkComboBoxDrawItem(
  Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
begin
  DrawSyncLyricsDarkComboBoxItem(Control as TComboBox, Index, Rect,
    State, CurrentPPI);
end;

procedure TFormLyricsLineDisplaySettings.DrawSelection(Canvas: TCanvas);
var
  Bounds: TRect;
  Handle: TRect;
  Points: array[0..5] of TPoint;
  I: Integer;
begin
  if FSelection = ldsRuby then
  begin
    if IsRectEmpty(FRubyBounds) then
      Exit;
    Bounds := FRubyBounds;
    Canvas.Pen.Color := RGB(180, 80, 255);
  end
  else
  begin
    if IsRectEmpty(FBaseBounds) then
      Exit;
    Bounds := FBaseBounds;
    Canvas.Pen.Color := RGB(255, 210, 40);
  end;
  InflateRect(Bounds, 5, 4);
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Width := 2;
  Canvas.Rectangle(Bounds);
  Points[0] := Point(Bounds.Left, Bounds.Top);
  Points[1] := Point(Bounds.Right, Bounds.Top);
  Points[2] := Point(Bounds.Left, Bounds.Bottom);
  Points[3] := Point(Bounds.Right, Bounds.Bottom);
  Points[4] := Point(Bounds.Left, (Bounds.Top + Bounds.Bottom) div 2);
  Points[5] := Point(Bounds.Right, (Bounds.Top + Bounds.Bottom) div 2);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Canvas.Pen.Color;
  for I := 0 to High(Points) do
  begin
    Handle := HandleRect(Points[I]);
    Canvas.FillRect(Handle);
  end;
  Canvas.Pen.Width := 1;
end;

function TFormLyricsLineDisplaySettings.DecorationHandleRect(
  Mode: TLineDisplayDragMode): TRect;
var
  Bounds: TRect;
  Center: TPoint;
  Extent: Integer;
  Gap: Integer;
  Scale: Double;
begin
  Result := TRect.Empty;
  if FSelection = ldsRuby then
    Bounds := FRubyBounds
  else
    Bounds := FBaseBounds;
  if IsRectEmpty(Bounds) then
    Exit;
  Extent := MulDiv(24, CurrentPPI, 96);
  Gap := MulDiv(10, CurrentPPI, 96);
  Scale := BackgroundScale;
  if Scale <= 0 then
    Scale := 1;
  case Mode of
    lddOutlineBlur:
      Center := Point(Bounds.Left - Gap - Extent div 2,
        Bounds.Top - Gap - Extent div 2);
    lddOutlineWidth:
      Center := Point(Bounds.Right + Gap + Extent div 2,
        Bounds.Top - Gap - Extent div 2);
    lddShadowBlur:
      Center := Point(Bounds.Left - Gap - Extent div 2,
        Bounds.Bottom + Gap + Extent div 2);
    lddShadowOffset:
      Center := Point(Bounds.Right + Gap + Extent div 2 +
        Round(FShadowOffsetX * Scale), Bounds.Bottom + Gap + Extent div 2 +
        Round(FShadowOffsetY * Scale));
    lddShadowSpread:
      begin
        Result := DecorationHandleRect(lddShadowOffset);
        Center := Point(Result.Right + Gap + Extent div 2,
          (Result.Top + Result.Bottom) div 2);
      end;
  else
    Exit;
  end;
  case Mode of
    lddOutlineBlur:
      Dec(Center.X, Round(FOutlineBlur * Scale));
    lddOutlineWidth:
      Inc(Center.X, Round(FOutlineWidth * Scale));
    lddShadowBlur:
      Dec(Center.X, Round(FShadowBlur * Scale));
    lddShadowSpread:
      Inc(Center.X, Round(FShadowSpread * Scale));
  end;
  Center.X := EnsureRange(Center.X, Extent div 2,
    Max(Extent div 2, PreviewPaintBox.ClientWidth - Extent div 2));
  Center.Y := EnsureRange(Center.Y, Extent div 2,
    Max(Extent div 2, PreviewPaintBox.ClientHeight - Extent div 2));
  Result := Rect(Center.X - Extent div 2, Center.Y - Extent div 2,
    Center.X + Extent div 2, Center.Y + Extent div 2);
end;

procedure TFormLyricsLineDisplaySettings.DrawDecorationHandles(
  Canvas: TCanvas);
const
  MODES: array[0..4] of TLineDisplayDragMode = (
    lddOutlineBlur, lddOutlineWidth, lddShadowBlur, lddShadowOffset,
    lddShadowSpread);
  LABELS: array[0..4] of string = (#26580, #32257, #24433, 'XY', #24195);
var
  Anchor: TPoint;
  Bounds: TRect;
  Handle: TRect;
  I: Integer;
  Mode: TLineDisplayDragMode;
  TextRect: TRect;
  ValueHeight: Integer;
  ValueRect: TRect;
  ValueText: string;
  ValueWidth: Integer;

  function DecorationValue(const AMode: TLineDisplayDragMode): string;
  begin
    case AMode of
      lddOutlineBlur:
        Result := #12412#12363#12375 + ' ' + FormatFloat('0.0', FOutlineBlur);
      lddOutlineWidth:
        Result := #32257 + ' ' + FormatFloat('0.0', FOutlineWidth);
      lddShadowBlur:
        Result := #24433#12412#12363#12375 + ' ' +
          FormatFloat('0.0', FShadowBlur);
      lddShadowOffset:
        Result := 'X ' + FormatFloat('0.0', FShadowOffsetX) + '  Y ' +
          FormatFloat('0.0', FShadowOffsetY);
      lddShadowSpread:
        Result := #24195#12364#12426 + ' ' +
          FormatFloat('0.0', FShadowSpread);
    else
      Result := '';
    end;
  end;
begin
  if FSelection = ldsRuby then
    Bounds := FRubyBounds
  else
    Bounds := FBaseBounds;
  if IsRectEmpty(Bounds) then
    Exit;
  for I := Low(MODES) to High(MODES) do
  begin
    Mode := MODES[I];
    if (Mode in [lddOutlineBlur, lddOutlineWidth]) and
      not FOutlineEnabled then
      Continue;
    if (Mode in [lddShadowBlur, lddShadowOffset, lddShadowSpread]) and
      not FShadowEnabled then
      Continue;
    Handle := DecorationHandleRect(Mode);
    if Mode in [lddOutlineBlur, lddShadowBlur] then
      Anchor.X := Bounds.Left
    else
      Anchor.X := Bounds.Right;
    if Mode in [lddOutlineBlur, lddOutlineWidth] then
      Anchor.Y := Bounds.Top
    else
      Anchor.Y := Bounds.Bottom;
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Color := RGB(144, 144, 144);
    Canvas.MoveTo(Anchor.X, Anchor.Y);
    Canvas.LineTo((Handle.Left + Handle.Right) div 2,
      (Handle.Top + Handle.Bottom) div 2);
    Canvas.Pen.Style := psSolid;
    Canvas.Pen.Color := IfThen(FDragMode = Mode, clAqua,
      TColor(RGB(210, 210, 210)));
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := RGB(48, 48, 48);
    Canvas.RoundRect(Handle.Left, Handle.Top, Handle.Right, Handle.Bottom,
      MulDiv(5, CurrentPPI, 96), MulDiv(5, CurrentPPI, 96));
    TextRect := Handle;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Yu Gothic UI';
    Canvas.Font.Height := -MulDiv(11, CurrentPPI, 96);
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := RGB(230, 230, 230);
    DrawText(Canvas.Handle, PChar(LABELS[I]), Length(LABELS[I]), TextRect,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    if FDragMode = Mode then
    begin
      ValueText := DecorationValue(Mode);
      Canvas.Font.Name := 'Yu Gothic UI';
      Canvas.Font.Height := -MulDiv(12, CurrentPPI, 96);
      Canvas.Font.Style := [];
      ValueWidth := Canvas.TextWidth(ValueText) + MulDiv(12, CurrentPPI, 96);
      ValueHeight := Canvas.TextHeight(ValueText) + MulDiv(6, CurrentPPI, 96);
      ValueRect := Rect((Handle.Left + Handle.Right - ValueWidth) div 2,
        Handle.Bottom + MulDiv(4, CurrentPPI, 96),
        (Handle.Left + Handle.Right + ValueWidth) div 2,
        Handle.Bottom + MulDiv(4, CurrentPPI, 96) + ValueHeight);
      if ValueRect.Bottom > PreviewPaintBox.ClientHeight then
        OffsetRect(ValueRect, 0, -ValueRect.Height - Handle.Height -
          MulDiv(8, CurrentPPI, 96));
      if ValueRect.Left < 0 then
        OffsetRect(ValueRect, -ValueRect.Left, 0)
      else if ValueRect.Right > PreviewPaintBox.ClientWidth then
        OffsetRect(ValueRect, PreviewPaintBox.ClientWidth - ValueRect.Right, 0);
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := RGB(35, 35, 35);
      Canvas.Pen.Color := clAqua;
      Canvas.RoundRect(ValueRect.Left, ValueRect.Top, ValueRect.Right,
        ValueRect.Bottom, MulDiv(5, CurrentPPI, 96),
        MulDiv(5, CurrentPPI, 96));
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Color := RGB(235, 235, 235);
      DrawText(Canvas.Handle, PChar(ValueText), Length(ValueText), ValueRect,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    end;
  end;
end;

procedure TFormLyricsLineDisplaySettings.DrawDecoratedText(Canvas: TCanvas;
  X, Y: Integer; const Text: string; AfterPhase: Boolean);
var
  BlurColor: TColor;
  BlurOpacity: Byte;
  FillColor: TColor;
  FillOpacity: Byte;
  I: Integer;
  OutlineColor: TColor;
  OutlineOpacity: Byte;
  Radius: Integer;
  Scale: Double;
  ShadowColor: TColor;
  ShadowOpacity: Byte;
  ShadowRadius: Integer;
begin
  if AfterPhase then
  begin
    FillColor := FAfterPalette[ldctFill];
    FillOpacity := FAfterPaletteOpacity[ldctFill];
    OutlineColor := FAfterPalette[ldctOutline];
    OutlineOpacity := FAfterPaletteOpacity[ldctOutline];
    ShadowColor := FAfterPalette[ldctShadow];
    ShadowOpacity := FAfterPaletteOpacity[ldctShadow];
    BlurColor := FAfterPalette[ldctBlur];
    BlurOpacity := FAfterPaletteOpacity[ldctBlur];
  end
  else
  begin
    FillColor := FBeforePalette[ldctFill];
    FillOpacity := FBeforePaletteOpacity[ldctFill];
    OutlineColor := FBeforePalette[ldctOutline];
    OutlineOpacity := FBeforePaletteOpacity[ldctOutline];
    ShadowColor := FBeforePalette[ldctShadow];
    ShadowOpacity := FBeforePaletteOpacity[ldctShadow];
    BlurColor := FBeforePalette[ldctBlur];
    BlurOpacity := FBeforePaletteOpacity[ldctBlur];
  end;
  Scale := BackgroundScale;
  if Scale <= 0 then
    Scale := 1;
  if FShadowEnabled then
  begin
    ShadowRadius := Min(12, Max(0, Round(FShadowSpread * Scale)));
    Canvas.Font.Color := PreviewColor(ShadowColor, ShadowOpacity);
    if ShadowRadius = 0 then
      Canvas.TextOut(X + Round(FShadowOffsetX * Scale),
        Y + Round(FShadowOffsetY * Scale), Text)
    else
      for I := 0 to 7 do
        Canvas.TextOut(X + Round(FShadowOffsetX * Scale) +
          Round(Cos(I * Pi / 4) * ShadowRadius),
          Y + Round(FShadowOffsetY * Scale) +
          Round(Sin(I * Pi / 4) * ShadowRadius), Text);
  end;
  if FOutlineEnabled and (FOutlineWidth > 0) then
  begin
    Radius := Min(16, Max(1, Round(FOutlineWidth * Scale)));
    if FOutlineBlur > 0 then
    begin
      Canvas.Font.Color := PreviewColor(BlurColor, BlurOpacity);
      for I := 0 to 7 do
        Canvas.TextOut(X + Round(Cos(I * Pi / 4) *
          (Radius + Min(8, Round(FOutlineBlur * Scale)))),
          Y + Round(Sin(I * Pi / 4) *
          (Radius + Min(8, Round(FOutlineBlur * Scale)))), Text);
    end;
    Canvas.Font.Color := PreviewColor(OutlineColor, OutlineOpacity);
    for I := 0 to 7 do
      Canvas.TextOut(X + Round(Cos(I * Pi / 4) * Radius),
        Y + Round(Sin(I * Pi / 4) * Radius), Text);
  end;
  Canvas.Font.Color := PreviewColor(FillColor, FillOpacity);
  Canvas.TextOut(X, Y, Text);
end;

procedure TFormLyricsLineDisplaySettings.DrawHalfSyncedText(Canvas: TCanvas;
  X, Y: Integer; const Text: string; TransitionX,
  CharacterSpacing: Integer);
var
  AfterImage: TTextRenderImage;
  BeforeImage: TTextRenderImage;
  RenderedWithSkia: Boolean;
  SavedDC: Integer;
begin
  BeforeImage := nil;
  AfterImage := nil;
  RenderedWithSkia := False;
  if FPreviewRenderer <> nil then
    try
      BeforeImage := RenderPreviewTextImage(Canvas, Text, CharacterSpacing,
        False);
      AfterImage := RenderPreviewTextImage(Canvas, Text, CharacterSpacing,
        True);
      if (BeforeImage <> nil) and (AfterImage <> nil) then
      begin
        DrawPreviewImage(Canvas, BeforeImage, X, Y, TransitionX, False);
        DrawPreviewImage(Canvas, AfterImage, X, Y, TransitionX, True);
        RenderedWithSkia := True;
      end;
    except
      { If the Skia preview cannot be created, retain the VCL fallback so the
        settings form itself remains usable. }
    end;
  BeforeImage.Free;
  AfterImage.Free;
  if RenderedWithSkia then
    Exit;

  { Keep the settings preview at 50% sync: left is the after palette and
    right is the before palette.  Clip the complete decorated phase image so
    shadows and outlines use the same boundary as the production renderer. }
  SavedDC := SaveDC(Canvas.Handle);
  try
    IntersectClipRect(Canvas.Handle, TransitionX, 0,
      PreviewPaintBox.ClientWidth, PreviewPaintBox.ClientHeight);
    DrawDecoratedText(Canvas, X, Y, Text, False);
  finally
    RestoreDC(Canvas.Handle, SavedDC);
  end;

  SavedDC := SaveDC(Canvas.Handle);
  try
    IntersectClipRect(Canvas.Handle, 0, 0, TransitionX,
      PreviewPaintBox.ClientHeight);
    DrawDecoratedText(Canvas, X, Y, Text, True);
  finally
    RestoreDC(Canvas.Handle, SavedDC);
  end;
end;

function TFormLyricsLineDisplaySettings.RenderPreviewTextImage(
  Canvas: TCanvas; const Text: string; CharacterSpacing: Integer;
  AfterPhase: Boolean): TTextRenderImage;
var
  BlurColor: TColor;
  BlurOpacity: Byte;
  FillColor: TColor;
  FillOpacity: Byte;
  Metrics: TTextRenderMetrics;
  OutlineColor: TColor;
  OutlineOpacity: Byte;
  Request: TTextRenderRequest;
  Scale: Double;
  Shadow: TTextRenderShadow;
  ShadowColor: TColor;
  ShadowOpacity: Byte;

  function AlphaColor(Color: TColor; Opacity: Byte): TAlphaColor;
  var
    Resolved: TColor;
  begin
    Resolved := ColorToRGB(Color);
    Result := TAlphaColor((Cardinal(Opacity) shl 24) or
      (Cardinal(GetRValue(Resolved)) shl 16) or
      (Cardinal(GetGValue(Resolved)) shl 8) or
      Cardinal(GetBValue(Resolved)));
  end;

begin
  Result := nil;
  if (FPreviewRenderer = nil) or (Text = '') then
    Exit;
  if AfterPhase then
  begin
    FillColor := FAfterPalette[ldctFill];
    FillOpacity := FAfterPaletteOpacity[ldctFill];
    OutlineColor := FAfterPalette[ldctOutline];
    OutlineOpacity := FAfterPaletteOpacity[ldctOutline];
    ShadowColor := FAfterPalette[ldctShadow];
    ShadowOpacity := FAfterPaletteOpacity[ldctShadow];
    BlurColor := FAfterPalette[ldctBlur];
    BlurOpacity := FAfterPaletteOpacity[ldctBlur];
  end
  else
  begin
    FillColor := FBeforePalette[ldctFill];
    FillOpacity := FBeforePaletteOpacity[ldctFill];
    OutlineColor := FBeforePalette[ldctOutline];
    OutlineOpacity := FBeforePaletteOpacity[ldctOutline];
    ShadowColor := FBeforePalette[ldctShadow];
    ShadowOpacity := FBeforePaletteOpacity[ldctShadow];
    BlurColor := FBeforePalette[ldctBlur];
    BlurOpacity := FBeforePaletteOpacity[ldctBlur];
  end;
  Scale := BackgroundScale;
  if Scale <= 0 then
    Scale := 1;
  Request := TTextRenderRequest.Default;
  Request.Text := Text;
  Request.FontFamilies := [Canvas.Font.Name, 'Yu Gothic UI', 'Meiryo UI',
    'Segoe UI'];
  Request.FontSize := Max(1, Abs(Canvas.Font.Height));
  Request.LetterSpacing := CharacterSpacing;
  Request.FontStyle := [];
  if fsBold in Canvas.Font.Style then
    Include(Request.FontStyle, TTextRenderFontStyleItem.Bold);
  if fsItalic in Canvas.Font.Style then
    Include(Request.FontStyle, TTextRenderFontStyleItem.Italic);
  if fsUnderline in Canvas.Font.Style then
    Include(Request.FontStyle, TTextRenderFontStyleItem.Underline);
  if fsStrikeOut in Canvas.Font.Style then
    Include(Request.FontStyle, TTextRenderFontStyleItem.StrikeOut);
  Request.FillColor := AlphaColor(FillColor, FillOpacity);
  Request.Outlines := [];
  if FOutlineEnabled and (FOutlineWidth > 0) then
  begin
    if FOutlineBlur <= 0 then
      Request.Outlines := [TTextRenderOutline.Create(FOutlineWidth * Scale,
        AlphaColor(OutlineColor, OutlineOpacity))]
    else if (ColorToRGB(BlurColor) = ColorToRGB(OutlineColor)) and
      (BlurOpacity = OutlineOpacity) then
      Request.Outlines := [TTextRenderOutline.Create(FOutlineWidth * Scale,
        FOutlineBlur * Scale, AlphaColor(OutlineColor, OutlineOpacity))]
    else
      Request.Outlines := [
        TTextRenderOutline.Create(FOutlineWidth * Scale,
          FOutlineBlur * Scale, AlphaColor(BlurColor, BlurOpacity)),
        TTextRenderOutline.Create(FOutlineWidth * Scale,
          AlphaColor(OutlineColor, OutlineOpacity))];
  end;
  Request.Shadows := [];
  if FShadowEnabled then
  begin
    Shadow := System.Default(TTextRenderShadow);
    Shadow.Offset := PointF(FShadowOffsetX * Scale, FShadowOffsetY * Scale);
    Shadow.BlurRadius := FShadowBlur * Scale;
    Shadow.SpreadRadius := FShadowSpread * Scale;
    Shadow.Color := AlphaColor(ShadowColor, ShadowOpacity);
    Request.Shadows := [Shadow];
  end;
  Result := FPreviewRenderer.Render(Request, Metrics);
end;

function TFormLyricsLineDisplaySettings.CreatePreviewBitmap(
  Image: TTextRenderImage): Vcl.Graphics.TBitmap;
var
  Destination: PByte;
  Source: PTextRenderPixel;
  X: Integer;
  Y: Integer;
begin
  Result := nil;
  if (Image = nil) or Image.IsEmpty then
    Exit;
  Result := Vcl.Graphics.TBitmap.Create;
  try
    Result.PixelFormat := pf32bit;
    Result.SetSize(Image.Width, Image.Height);
    for Y := 0 to Image.Height - 1 do
    begin
      Source := PTextRenderPixel(PByte(Image.Data) +
        NativeInt(Y) * Image.Stride);
      Destination := Result.ScanLine[Y];
      for X := 0 to Image.Width - 1 do
      begin
        Destination[0] := (Cardinal(Source^.B) * Source^.A + 127) div 255;
        Destination[1] := (Cardinal(Source^.G) * Source^.A + 127) div 255;
        Destination[2] := (Cardinal(Source^.R) * Source^.A + 127) div 255;
        Destination[3] := Source^.A;
        Inc(Destination, 4);
        Inc(Source);
      end;
    end;
    Result.AlphaFormat := afPremultiplied;
  except
    FreeAndNil(Result);
    raise;
  end;
end;

procedure TFormLyricsLineDisplaySettings.DrawPreviewImage(Canvas: TCanvas;
  Image: TTextRenderImage; X, Y, TransitionX: Integer;
  AfterPhase: Boolean);
var
  Bitmap: Vcl.Graphics.TBitmap;
  Blend: BLENDFUNCTION;
  ImageLeft: Integer;
  ImageTop: Integer;
  SavedDC: Integer;
begin
  Bitmap := CreatePreviewBitmap(Image);
  if Bitmap = nil then
    Exit;
  try
    ImageLeft := X + Image.Bounds.Left - Image.LayoutBounds.Left;
    ImageTop := Y + Image.Bounds.Top - Image.LayoutBounds.Top;
    SavedDC := SaveDC(Canvas.Handle);
    try
      if AfterPhase then
        IntersectClipRect(Canvas.Handle, 0, 0, TransitionX,
          PreviewPaintBox.ClientHeight)
      else
        IntersectClipRect(Canvas.Handle, TransitionX, 0,
          PreviewPaintBox.ClientWidth, PreviewPaintBox.ClientHeight);
      Blend.BlendOp := AC_SRC_OVER;
      Blend.BlendFlags := 0;
      Blend.SourceConstantAlpha := 255;
      Blend.AlphaFormat := AC_SRC_ALPHA;
      Winapi.Windows.AlphaBlend(Canvas.Handle, ImageLeft, ImageTop,
        Bitmap.Width, Bitmap.Height, Bitmap.Canvas.Handle, 0, 0,
        Bitmap.Width, Bitmap.Height, Blend);
    finally
      RestoreDC(Canvas.Handle, SavedDC);
    end;
  finally
    Bitmap.Free;
  end;
end;

function TFormLyricsLineDisplaySettings.EnteredLyrics: string;
begin
  Result := FLyrics;
end;

function TFormLyricsLineDisplaySettings.SelectedCandidateIndex: Integer;
begin
  Result := CandidateCombo.ItemIndex;
end;

function TFormLyricsLineDisplaySettings.SelectedCommonSettings:
  TDisplayCommonSettings;
begin
  Result.PositionX := FPositionX;
  Result.PositionY := FPositionY;
  Result.BaseFontName := FBaseFontName;
  Result.RubyFontName := FRubyFontName;
  Result.BaseFontHeight := FBaseFontHeight;
  Result.RubyFontHeight := FRubyFontHeight;
  Result.BaseFontStyle := FBaseFontStyle and $0F;
  Result.RubyFontStyle := FRubyFontStyle and $0F;
  Result.BeforeColor := Cardinal(ColorToRGB(FBeforeColor)) and $FFFFFF;
  Result.AfterColor := Cardinal(ColorToRGB(FAfterColor)) and $FFFFFF;
  Result.BeforeOpacity := FBeforePaletteOpacity[ldctFill];
  Result.AfterOpacity := FAfterPaletteOpacity[ldctFill];
  Result.BeforeOutlineColor :=
    Cardinal(ColorToRGB(FBeforePalette[ldctOutline])) and $FFFFFF;
  Result.AfterOutlineColor :=
    Cardinal(ColorToRGB(FAfterPalette[ldctOutline])) and $FFFFFF;
  Result.BeforeOutlineOpacity := FBeforePaletteOpacity[ldctOutline];
  Result.AfterOutlineOpacity := FAfterPaletteOpacity[ldctOutline];
  Result.BeforeShadowColor :=
    Cardinal(ColorToRGB(FBeforePalette[ldctShadow])) and $FFFFFF;
  Result.AfterShadowColor :=
    Cardinal(ColorToRGB(FAfterPalette[ldctShadow])) and $FFFFFF;
  Result.BeforeShadowOpacity := FBeforePaletteOpacity[ldctShadow];
  Result.AfterShadowOpacity := FAfterPaletteOpacity[ldctShadow];
  Result.BeforeBlurColor :=
    Cardinal(ColorToRGB(FBeforePalette[ldctBlur])) and $FFFFFF;
  Result.AfterBlurColor :=
    Cardinal(ColorToRGB(FAfterPalette[ldctBlur])) and $FFFFFF;
  Result.BeforeBlurOpacity := FBeforePaletteOpacity[ldctBlur];
  Result.AfterBlurOpacity := FAfterPaletteOpacity[ldctBlur];
  Result.OutlineEnabled := FOutlineEnabled;
  Result.OutlineWidth := FOutlineWidth;
  Result.OutlineBlur := FOutlineBlur;
  Result.ShadowEnabled := FShadowEnabled;
  Result.ShadowOffsetX := FShadowOffsetX;
  Result.ShadowOffsetY := FShadowOffsetY;
  Result.ShadowBlur := FShadowBlur;
  Result.ShadowSpread := FShadowSpread;
  Result.RubyGapAdjustment := FRubyGapAdjustment;
  Result.BaseCharacterSpacing := FBaseCharacterSpacing;
  Result.RubyCharacterSpacing := FRubyCharacterSpacing;
end;

procedure TFormLyricsLineDisplaySettings.FormCreate(Sender: TObject);
var
  DefaultSettings: TDisplayCommonSettings;
begin
  ApplySyncLyricsDarkForm(Self);
  ApplySyncLyricsDarkPanel(ButtonPanel);
  ApplySyncLyricsDarkPanel(ColorPanel);
  ApplySyncLyricsDarkComboBox(CandidateCombo, DarkComboBoxDrawItem);
  ApplySyncLyricsDarkComboBox(BaseFontCombo, DarkComboBoxDrawItem);
  ApplySyncLyricsDarkComboBox(RubyFontCombo, DarkComboBoxDrawItem);
  ApplySyncLyricsDarkButton(ButtonOK);
  ApplySyncLyricsDarkButton(ButtonCancel);
  FBackground := Vcl.Graphics.TBitmap.Create;
  FPreviewRenderer := nil;
  if TTextRendererSkiaRuntime.IsAcquired then
    try
      FPreviewRenderer := TSkiaTextRenderer.Create;
    except
      FPreviewRenderer := nil;
    end;
  FBaseFontHeight := 96;
  FRubyFontHeight := 42;
  FBaseFontName := 'Yu Gothic UI';
  FRubyFontName := FBaseFontName;
  FBaseCharacterSpacing := 0;
  FRubyCharacterSpacing := 0;
  FRubyGapAdjustment := 0;
  FPositionX := 0;
  FPositionY := 0;
  FDragMode := lddNone;
  DefaultSettings := DefaultDisplayCommonSettings;
  FBeforeColor := TColor(DefaultSettings.BeforeColor);
  FAfterColor := TColor(DefaultSettings.AfterColor);
  FColorTarget := ldctFill;
  FBeforePalette[ldctFill] := FBeforeColor;
  FAfterPalette[ldctFill] := FAfterColor;
  FBeforePalette[ldctOutline] := TColor(DefaultSettings.BeforeOutlineColor);
  FAfterPalette[ldctOutline] := TColor(DefaultSettings.AfterOutlineColor);
  FBeforePalette[ldctShadow] := TColor(DefaultSettings.BeforeShadowColor);
  FAfterPalette[ldctShadow] := TColor(DefaultSettings.AfterShadowColor);
  FBeforePalette[ldctBlur] := TColor(DefaultSettings.BeforeBlurColor);
  FAfterPalette[ldctBlur] := TColor(DefaultSettings.AfterBlurColor);
  FBeforePaletteOpacity[ldctFill] := DefaultSettings.BeforeOpacity;
  FAfterPaletteOpacity[ldctFill] := DefaultSettings.AfterOpacity;
  FBeforePaletteOpacity[ldctOutline] :=
    DefaultSettings.BeforeOutlineOpacity;
  FAfterPaletteOpacity[ldctOutline] := DefaultSettings.AfterOutlineOpacity;
  FBeforePaletteOpacity[ldctShadow] := DefaultSettings.BeforeShadowOpacity;
  FAfterPaletteOpacity[ldctShadow] := DefaultSettings.AfterShadowOpacity;
  FBeforePaletteOpacity[ldctBlur] := DefaultSettings.BeforeBlurOpacity;
  FAfterPaletteOpacity[ldctBlur] := DefaultSettings.AfterBlurOpacity;
  FOutlineEnabled := DefaultSettings.OutlineEnabled;
  FOutlineWidth := DefaultSettings.OutlineWidth;
  FOutlineBlur := DefaultSettings.OutlineBlur;
  FShadowEnabled := DefaultSettings.ShadowEnabled;
  FShadowOffsetX := DefaultSettings.ShadowOffsetX;
  FShadowOffsetY := DefaultSettings.ShadowOffsetY;
  FShadowBlur := DefaultSettings.ShadowBlur;
  FShadowSpread := DefaultSettings.ShadowSpread;
  FSelection := ldsBase;
  FUpdatingControls := False;
  DoubleBuffered := True;
  BaseFontCombo.Items.Assign(Screen.Fonts);
  RubyFontCombo.Items.Assign(Screen.Fonts);
  CreateFormattingToolbar;
  CreateColorControls;
  UpdateTopLayout;
  ParseCurrentLyrics;
  UpdateFormattingControls;
  UpdateColorControls;
end;

procedure TFormLyricsLineDisplaySettings.FormDestroy(Sender: TObject);
begin
  FPreviewRenderer.Free;
  FBackground.Free;
end;

procedure TFormLyricsLineDisplaySettings.FormResize(Sender: TObject);
begin
  UpdateTopLayout;
end;

procedure TFormLyricsLineDisplaySettings.BaseFontComboChange(
  Sender: TObject);
begin
  if FUpdatingControls or (BaseFontCombo.ItemIndex < 0) then
    Exit;
  FBaseFontName := BaseFontCombo.Items[BaseFontCombo.ItemIndex];
  PreviewPaintBox.Invalidate;
end;

procedure TFormLyricsLineDisplaySettings.RubyFontComboChange(
  Sender: TObject);
begin
  if FUpdatingControls or (RubyFontCombo.ItemIndex < 0) then
    Exit;
  FRubyFontName := RubyFontCombo.Items[RubyFontCombo.ItemIndex];
  PreviewPaintBox.Invalidate;
end;

procedure TFormLyricsLineDisplaySettings.ParseCurrentLyrics;
begin
  ParseLyrics(FLyrics, FPlainText, FRubySpans);
  if (FSelection = ldsRuby) and (Length(FRubySpans) = 0) then
    FSelection := ldsBase;
  UpdateFormattingControls;
end;

procedure TFormLyricsLineDisplaySettings.PreviewPaintBoxMouseDown(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  DragMode: TLineDisplayDragMode;
  I: Integer;
  Point: TPoint;
begin
  if Button <> mbLeft then
    Exit;
  Point := System.Types.Point(X, Y);
  DragMode := HitTestDragMode(Point);
  if DragMode <> lddNone then
  begin
    StartDrag(DragMode, Point);
    Exit;
  end;
  for I := 0 to High(FRubyRects) do
    if FRubyRects[I].Contains(Point) then
    begin
      FSelection := ldsRuby;
      UpdateFormattingControls;
      PreviewPaintBox.Invalidate;
      StartDrag(lddRubyGap, Point);
      Exit;
    end;
  if FBaseBounds.Contains(Point) then
  begin
    FSelection := ldsBase;
    UpdateFormattingControls;
    PreviewPaintBox.Invalidate;
    StartDrag(lddMoveGroup, Point);
  end;
end;

procedure TFormLyricsLineDisplaySettings.PreviewPaintBoxMouseMove(
  Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Mode: TLineDisplayDragMode;
begin
  if FDragMode <> lddNone then
  begin
    UpdateDrag(Point(X, Y));
    Exit;
  end;
  Mode := HitTestDragMode(Point(X, Y));
  case Mode of
    lddMoveGroup, lddShadowOffset:
      PreviewPaintBox.Cursor := crSizeAll;
    lddRubyGap:
      PreviewPaintBox.Cursor := crSizeNS;
    lddSpacingLeft, lddSpacingRight, lddOutlineWidth, lddOutlineBlur,
    lddShadowBlur, lddShadowSpread:
      PreviewPaintBox.Cursor := crSizeWE;
    lddResizeTopLeft, lddResizeBottomRight:
      PreviewPaintBox.Cursor := crSizeNWSE;
    lddResizeTopRight, lddResizeBottomLeft:
      PreviewPaintBox.Cursor := crSizeNESW;
  else
    PreviewPaintBox.Cursor := crDefault;
  end;
end;

procedure TFormLyricsLineDisplaySettings.PreviewPaintBoxMouseUp(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button <> mbLeft) or (FDragMode = lddNone) then
    Exit;
  FDragMode := lddNone;
  TControlAccess(PreviewPaintBox).MouseCapture := False;
  PreviewPaintBoxMouseMove(Sender, Shift, X, Y);
end;

procedure TFormLyricsLineDisplaySettings.ToolbarButtonExecute(
  Sender: TObject; Button: TSyncLyricsToolbarButton);
var
  StyleBit: Byte;
  StyleValue: Byte;
begin
  case Button.Tag of
    TOOLBAR_BOLD, TOOLBAR_ITALIC, TOOLBAR_UNDERLINE, TOOLBAR_STRIKE_OUT:
      begin
        case Button.Tag of
          TOOLBAR_BOLD:
            StyleBit := 1;
          TOOLBAR_ITALIC:
            StyleBit := 2;
          TOOLBAR_UNDERLINE:
            StyleBit := 4;
        else
          StyleBit := 8;
        end;
        if FSelection = ldsRuby then
          StyleValue := FRubyFontStyle
        else
          StyleValue := FBaseFontStyle;
        if Button.CheckState = tbcsChecked then
          StyleValue := StyleValue or StyleBit
        else
          StyleValue := StyleValue and not StyleBit;
        if FSelection = ldsRuby then
          FRubyFontStyle := StyleValue and $0F
        else
          FBaseFontStyle := StyleValue and $0F;
      end;
    TOOLBAR_OUTLINE:
      FOutlineEnabled := Button.CheckState = tbcsChecked;
    TOOLBAR_SHADOW:
      FShadowEnabled := Button.CheckState = tbcsChecked;
  end;
  UpdateFormattingControls;
  PreviewPaintBox.Invalidate;
end;

procedure TFormLyricsLineDisplaySettings.UpdateColorControls;
var
  Target: TLineDisplayColorTarget;
begin
  if (FBeforeColorPicker = nil) or (FAfterColorPicker = nil) then
    Exit;
  FUpdatingControls := True;
  try
    FBeforePalette[ldctFill] := FBeforeColor;
    FAfterPalette[ldctFill] := FAfterColor;
    for Target := Low(TLineDisplayColorTarget) to High(TLineDisplayColorTarget) do
      FColorTargetButtons[Target].CheckState :=
        TSyncLyricsToolbarCheckState(Ord(Target = FColorTarget));
    FBeforeColorPicker.Color := FBeforePalette[FColorTarget];
    FAfterColorPicker.Color := FAfterPalette[FColorTarget];
    FBeforeOpacityTrack.Position := FBeforePaletteOpacity[FColorTarget];
    FAfterOpacityTrack.Position := FAfterPaletteOpacity[FColorTarget];
  finally
    FUpdatingControls := False;
  end;
end;

procedure TFormLyricsLineDisplaySettings.UpdateFontCombos;
var
  FontIndex: Integer;
begin
  FUpdatingControls := True;
  try
    FontIndex := BaseFontCombo.Items.IndexOf(FBaseFontName);
    if FontIndex < 0 then
      FontIndex := BaseFontCombo.Items.Add(FBaseFontName);
    BaseFontCombo.ItemIndex := FontIndex;
    FontIndex := RubyFontCombo.Items.IndexOf(FRubyFontName);
    if FontIndex < 0 then
      FontIndex := RubyFontCombo.Items.Add(FRubyFontName);
    RubyFontCombo.ItemIndex := FontIndex;
  finally
    FUpdatingControls := False;
  end;
end;

procedure TFormLyricsLineDisplaySettings.UpdateFormattingControls;
var
  StyleValue: Byte;
begin
  if FToolbar = nil then
    Exit;
  FUpdatingControls := True;
  try
    if FSelection = ldsRuby then
      StyleValue := FRubyFontStyle
    else
      StyleValue := FBaseFontStyle;
    FToolbarBold.CheckState :=
      TSyncLyricsToolbarCheckState(Ord((StyleValue and 1) <> 0));
    FToolbarItalic.CheckState :=
      TSyncLyricsToolbarCheckState(Ord((StyleValue and 2) <> 0));
    FToolbarUnderline.CheckState :=
      TSyncLyricsToolbarCheckState(Ord((StyleValue and 4) <> 0));
    FToolbarStrikeOut.CheckState :=
      TSyncLyricsToolbarCheckState(Ord((StyleValue and 8) <> 0));
    FToolbarOutline.CheckState :=
      TSyncLyricsToolbarCheckState(Ord(FOutlineEnabled));
    FToolbarShadow.CheckState :=
      TSyncLyricsToolbarCheckState(Ord(FShadowEnabled));
  finally
    FUpdatingControls := False;
  end;
end;

function TFormLyricsLineDisplaySettings.HitTestDragMode(
  const Point: TPoint): TLineDisplayDragMode;
var
  Bounds: TRect;
  ExpandedBounds: TRect;
  Points: array[0..5] of TPoint;
  I: Integer;
begin
  Result := lddNone;
  if FSelection = ldsRuby then
    Bounds := FRubyBounds
  else
    Bounds := FBaseBounds;
  if IsRectEmpty(Bounds) then
    Exit;
  if FOutlineEnabled then
  begin
    if DecorationHandleRect(lddOutlineBlur).Contains(Point) then
      Exit(lddOutlineBlur);
    if DecorationHandleRect(lddOutlineWidth).Contains(Point) then
      Exit(lddOutlineWidth);
  end;
  if FShadowEnabled then
  begin
    if DecorationHandleRect(lddShadowBlur).Contains(Point) then
      Exit(lddShadowBlur);
    if DecorationHandleRect(lddShadowOffset).Contains(Point) then
      Exit(lddShadowOffset);
    if DecorationHandleRect(lddShadowSpread).Contains(Point) then
      Exit(lddShadowSpread);
  end;
  InflateRect(Bounds, 5, 4);
  Points[0] := System.Types.Point(Bounds.Left, Bounds.Top);
  Points[1] := System.Types.Point(Bounds.Right, Bounds.Top);
  Points[2] := System.Types.Point(Bounds.Left, Bounds.Bottom);
  Points[3] := System.Types.Point(Bounds.Right, Bounds.Bottom);
  Points[4] := System.Types.Point(Bounds.Left,
    (Bounds.Top + Bounds.Bottom) div 2);
  Points[5] := System.Types.Point(Bounds.Right,
    (Bounds.Top + Bounds.Bottom) div 2);
  for I := 0 to High(Points) do
    if HandleRect(Points[I]).Contains(Point) then
    begin
      case I of
        0: Result := lddResizeTopLeft;
        1: Result := lddResizeTopRight;
        2: Result := lddResizeBottomLeft;
        3: Result := lddResizeBottomRight;
        4: Result := lddSpacingLeft;
        5: Result := lddSpacingRight;
      end;
      if (Result in [lddSpacingLeft, lddSpacingRight]) and
        (((FSelection = ldsBase) and (Length(FPlainText) < 2)) or
        ((FSelection = ldsRuby) and (RubySpacingIntervalCount = 0))) then
        Result := lddNone;
      Exit;
    end;
  ExpandedBounds := Bounds;
  InflateRect(ExpandedBounds, HIT_MARGIN, HIT_MARGIN);
  if ExpandedBounds.Contains(Point) then
  begin
    if FSelection = ldsRuby then
      Result := lddRubyGap
    else
      Result := lddMoveGroup;
  end;
end;

function TFormLyricsLineDisplaySettings.RubySpacingIntervalCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FRubySpans) do
    Result := Max(Result, Length(FRubySpans[I].RubyText) - 1);
end;

procedure TFormLyricsLineDisplaySettings.StartDrag(
  Mode: TLineDisplayDragMode; const Point: TPoint);
begin
  FDragMode := Mode;
  FDragStartPoint := Point;
  if FSelection = ldsRuby then
    FDragStartBounds := FRubyBounds
  else
    FDragStartBounds := FBaseBounds;
  FDragStartBaseBounds := FBaseBounds;
  FDragStartBaseFontHeight := FBaseFontHeight;
  FDragStartRubyFontHeight := FRubyFontHeight;
  FDragStartBaseCharacterSpacing := FBaseCharacterSpacing;
  FDragStartRubyCharacterSpacing := FRubyCharacterSpacing;
  FDragStartRubyGapAdjustment := FRubyGapAdjustment;
  FDragStartPositionX := FPositionX;
  FDragStartPositionY := FPositionY;
  FDragStartOutlineWidth := FOutlineWidth;
  FDragStartOutlineBlur := FOutlineBlur;
  FDragStartShadowOffsetX := FShadowOffsetX;
  FDragStartShadowOffsetY := FShadowOffsetY;
  FDragStartShadowBlur := FShadowBlur;
  FDragStartShadowSpread := FShadowSpread;
  TControlAccess(PreviewPaintBox).MouseCapture := True;
end;

procedure TFormLyricsLineDisplaySettings.UpdateDrag(const Point: TPoint);
var
  AnchorAfter: TPoint;
  AnchorBefore: TPoint;
  Bounds: TRect;
  DeltaX: Integer;
  DeltaY: Integer;
  Height: Integer;
  HorizontalRatio: Double;
  IntervalCount: Integer;
  Scale: Double;
  ScaleRatio: Double;
  VerticalRatio: Double;
begin
  Scale := BackgroundScale;
  if Scale <= 0 then
    Scale := 1;
  DeltaX := Round((Point.X - FDragStartPoint.X) / Scale);
  DeltaY := Round((Point.Y - FDragStartPoint.Y) / Scale);
  FPositionX := FDragStartPositionX;
  FPositionY := FDragStartPositionY;
  FBaseFontHeight := FDragStartBaseFontHeight;
  FRubyFontHeight := FDragStartRubyFontHeight;
  FBaseCharacterSpacing := FDragStartBaseCharacterSpacing;
  FRubyCharacterSpacing := FDragStartRubyCharacterSpacing;
  FRubyGapAdjustment := FDragStartRubyGapAdjustment;
  FOutlineWidth := FDragStartOutlineWidth;
  FOutlineBlur := FDragStartOutlineBlur;
  FShadowOffsetX := FDragStartShadowOffsetX;
  FShadowOffsetY := FDragStartShadowOffsetY;
  FShadowBlur := FDragStartShadowBlur;
  FShadowSpread := FDragStartShadowSpread;

  case FDragMode of
    lddMoveGroup:
      begin
        FPositionX := EnsureRange(FDragStartPositionX + DeltaX,
          MIN_POSITION, MAX_POSITION);
        FPositionY := EnsureRange(FDragStartPositionY + DeltaY,
          MIN_POSITION, MAX_POSITION);
      end;
    lddRubyGap:
      FRubyGapAdjustment := EnsureRange(
        FDragStartRubyGapAdjustment - DeltaY,
        MIN_RUBY_GAP_ADJUSTMENT, MAX_RUBY_GAP_ADJUSTMENT);
    lddSpacingLeft, lddSpacingRight:
      begin
        if FSelection = ldsRuby then
          IntervalCount := RubySpacingIntervalCount
        else
          IntervalCount := Length(FPlainText) - 1;
        if IntervalCount > 0 then
        begin
          if FDragMode = lddSpacingLeft then
            DeltaX := -DeltaX;
          if FSelection = ldsRuby then
            FRubyCharacterSpacing := EnsureRange(
              FDragStartRubyCharacterSpacing +
              Round(DeltaX / IntervalCount),
              MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING)
          else
            FBaseCharacterSpacing := EnsureRange(
              FDragStartBaseCharacterSpacing +
              Round(DeltaX / IntervalCount),
              MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
        end;
      end;
    lddOutlineWidth:
      FOutlineWidth := EnsureRange(FDragStartOutlineWidth + DeltaX,
        0.0, MAX_DECORATION_SIZE * 1.0);
    lddOutlineBlur:
      FOutlineBlur := EnsureRange(FDragStartOutlineBlur - DeltaX,
        0.0, MAX_DECORATION_SIZE * 1.0);
    lddShadowOffset:
      begin
        FShadowOffsetX := EnsureRange(FDragStartShadowOffsetX + DeltaX,
          -MAX_SHADOW_OFFSET * 1.0, MAX_SHADOW_OFFSET * 1.0);
        FShadowOffsetY := EnsureRange(FDragStartShadowOffsetY + DeltaY,
          -MAX_SHADOW_OFFSET * 1.0, MAX_SHADOW_OFFSET * 1.0);
      end;
    lddShadowBlur:
      FShadowBlur := EnsureRange(FDragStartShadowBlur - DeltaX,
        0.0, MAX_DECORATION_SIZE * 1.0);
    lddShadowSpread:
      FShadowSpread := EnsureRange(FDragStartShadowSpread + DeltaX,
        0.0, MAX_DECORATION_SIZE * 1.0);
    lddResizeTopLeft, lddResizeTopRight, lddResizeBottomLeft,
    lddResizeBottomRight:
      begin
        if FDragMode in [lddResizeTopLeft, lddResizeBottomLeft] then
          DeltaX := -DeltaX;
        if FDragMode in [lddResizeTopLeft, lddResizeTopRight] then
          DeltaY := -DeltaY;
        HorizontalRatio := (Max(1, FDragStartBounds.Width) +
          Round(DeltaX * Scale)) / Max(1, FDragStartBounds.Width);
        VerticalRatio := (Max(1, FDragStartBounds.Height) +
          Round(DeltaY * Scale)) / Max(1, FDragStartBounds.Height);
        if Abs(HorizontalRatio - 1) >= Abs(VerticalRatio - 1) then
          ScaleRatio := HorizontalRatio
        else
          ScaleRatio := VerticalRatio;
        Height := Max(MIN_FONT_HEIGHT, Round(
          IfThen(FSelection = ldsRuby, FDragStartRubyFontHeight,
          FDragStartBaseFontHeight) * ScaleRatio));
        Height := Min(MAX_FONT_HEIGHT, Height);
        if FSelection = ldsRuby then
          FRubyFontHeight := Height
        else
          FBaseFontHeight := Height;
      end;
  end;

  if FDragMode = lddRubyGap then
  begin
    CalculateLayout(PreviewPaintBox.Canvas, False);
    FPositionX := EnsureRange(FPositionX +
      Round((FDragStartBaseBounds.Left - FBaseBounds.Left) / Scale),
      MIN_POSITION, MAX_POSITION);
    FPositionY := EnsureRange(FPositionY +
      Round((FDragStartBaseBounds.Top - FBaseBounds.Top) / Scale),
      MIN_POSITION, MAX_POSITION);
  end
  else if FDragMode in [lddResizeTopLeft, lddResizeTopRight,
    lddResizeBottomLeft, lddResizeBottomRight] then
  begin
    if FDragMode in [lddResizeTopLeft, lddResizeTopRight] then
      AnchorBefore.Y := FDragStartBounds.Bottom
    else
      AnchorBefore.Y := FDragStartBounds.Top;
    if FDragMode in [lddResizeTopLeft, lddResizeBottomLeft] then
      AnchorBefore.X := FDragStartBounds.Right
    else
      AnchorBefore.X := FDragStartBounds.Left;
    CalculateLayout(PreviewPaintBox.Canvas, False);
    if FSelection = ldsRuby then
      Bounds := FRubyBounds
    else
      Bounds := FBaseBounds;
    if FDragMode in [lddResizeTopLeft, lddResizeTopRight] then
      AnchorAfter.Y := Bounds.Bottom
    else
      AnchorAfter.Y := Bounds.Top;
    if FDragMode in [lddResizeTopLeft, lddResizeBottomLeft] then
      AnchorAfter.X := Bounds.Right
    else
      AnchorAfter.X := Bounds.Left;
    FPositionX := EnsureRange(FPositionX +
      Round((AnchorBefore.X - AnchorAfter.X) / Scale),
      MIN_POSITION, MAX_POSITION);
    FPositionY := EnsureRange(FPositionY +
      Round((AnchorBefore.Y - AnchorAfter.Y) / Scale),
      MIN_POSITION, MAX_POSITION);
  end;
  PreviewPaintBox.Invalidate;
end;

procedure TFormLyricsLineDisplaySettings.CalculateLayout(Canvas: TCanvas;
  DrawText: Boolean);
var
  BaseHeight: Integer;
  BaseWidth: Integer;
  BaseX: Integer;
  BaseY: Integer;
  Destination: TRect;
  I: Integer;
  PrefixText: string;
  PrefixWidth: Integer;
  RubyHeight: Integer;
  RubyRect: TRect;
  RubyWidth: Integer;
  RubyX: Integer;
  RubyY: Integer;
  Scale: Double;
  OldCharacterSpacing: Integer;
  RubyGap: Integer;
  SpanText: string;
  SpanWidth: Integer;
  TransitionX: Integer;
begin
  Destination := BackgroundDestinationRect;
  SetRectEmpty(FBaseBounds);
  SetRectEmpty(FRubyBounds);
  SetLength(FRubyRects, 0);
  if FPlainText = '' then
    Exit;

  Scale := BackgroundScale;
  Canvas.Brush.Style := bsClear;
  Canvas.Font.Name := FBaseFontName;
  Canvas.Font.Height := -Max(1, Round(FBaseFontHeight * Scale));
  Canvas.Font.Style := FontStylesFromByte(FBaseFontStyle);
  Canvas.Font.Color := FBeforeColor;
  OldCharacterSpacing := GetTextCharacterExtra(Canvas.Handle);
  SetTextCharacterExtra(Canvas.Handle,
    Round(FBaseCharacterSpacing * Scale));
  BaseWidth := MeasureTextWidth(Canvas, FPlainText);
  BaseHeight := Canvas.TextHeight(FPlainText);

  RubyHeight := 0;
  if Length(FRubySpans) > 0 then
  begin
    Canvas.Font.Name := FRubyFontName;
    Canvas.Font.Height := -Max(1, Round(FRubyFontHeight * Scale));
    Canvas.Font.Style := FontStylesFromByte(FRubyFontStyle);
    RubyHeight := Canvas.TextHeight('Ag');
  end;

  RubyGap := Round((DEFAULT_RUBY_GAP + FRubyGapAdjustment) * Scale);
  BaseX := Destination.Left + (Destination.Width - BaseWidth) div 2 +
    Round(FPositionX * Scale);
  if Length(FRubySpans) = 0 then
    BaseY := Destination.Top + (Destination.Height - BaseHeight) div 2 +
      Round(FPositionY * Scale)
  else
  BaseY := Destination.Top +
      (Destination.Height - RubyHeight -
      RubyGap - BaseHeight) div 2 +
      RubyHeight + RubyGap + Round(FPositionY * Scale);
  TransitionX := BaseX + BaseWidth div 2;

  Canvas.Font.Name := FBaseFontName;
  Canvas.Font.Height := -Max(1, Round(FBaseFontHeight * Scale));
  Canvas.Font.Style := FontStylesFromByte(FBaseFontStyle);
  Canvas.Font.Color := FBeforeColor;
  SetTextCharacterExtra(Canvas.Handle,
    Round(FBaseCharacterSpacing * Scale));
  if DrawText then
    DrawHalfSyncedText(Canvas, BaseX, BaseY, FPlainText, TransitionX,
      Round(FBaseCharacterSpacing * Scale));
  FBaseBounds := Rect(BaseX, BaseY, BaseX + BaseWidth, BaseY + BaseHeight);

  if Length(FRubySpans) > 0 then
  begin
    RubyY := BaseY - RubyGap - RubyHeight;
    SetLength(FRubyRects, Length(FRubySpans));
    for I := 0 to High(FRubySpans) do
    begin
      Canvas.Font.Name := FBaseFontName;
      Canvas.Font.Height := -Max(1, Round(FBaseFontHeight * Scale));
      Canvas.Font.Style := FontStylesFromByte(FBaseFontStyle);
      SetTextCharacterExtra(Canvas.Handle,
        Round(FBaseCharacterSpacing * Scale));
      PrefixText := Copy(FPlainText, 1, FRubySpans[I].BaseStart - 1);
      SpanText := Copy(FPlainText, FRubySpans[I].BaseStart,
        FRubySpans[I].BaseLength);
      PrefixWidth := MeasureTextWidth(Canvas, PrefixText);
      if PrefixText <> '' then
        Inc(PrefixWidth, Round(FBaseCharacterSpacing * Scale));
      SpanWidth := MeasureTextWidth(Canvas, SpanText);

      Canvas.Font.Name := FRubyFontName;
      Canvas.Font.Height := -Max(1, Round(FRubyFontHeight * Scale));
      Canvas.Font.Style := FontStylesFromByte(FRubyFontStyle);
      Canvas.Font.Color := FBeforeColor;
      SetTextCharacterExtra(Canvas.Handle,
        Round(FRubyCharacterSpacing * Scale));
      RubyWidth := MeasureTextWidth(Canvas, FRubySpans[I].RubyText);
      RubyX := BaseX + PrefixWidth + (SpanWidth - RubyWidth) div 2;
      if DrawText then
        DrawHalfSyncedText(Canvas, RubyX, RubyY, FRubySpans[I].RubyText,
          TransitionX, Round(FRubyCharacterSpacing * Scale));
      RubyRect := Rect(RubyX, RubyY, RubyX + RubyWidth, RubyY + RubyHeight);
      FRubyRects[I] := RubyRect;
      if I = 0 then
        FRubyBounds := RubyRect
      else
      begin
        FRubyBounds.Left := Min(FRubyBounds.Left, RubyRect.Left);
        FRubyBounds.Top := Min(FRubyBounds.Top, RubyRect.Top);
        FRubyBounds.Right := Max(FRubyBounds.Right, RubyRect.Right);
        FRubyBounds.Bottom := Max(FRubyBounds.Bottom, RubyRect.Bottom);
      end;
    end;
  end;
  SetTextCharacterExtra(Canvas.Handle, OldCharacterSpacing);
end;

procedure TFormLyricsLineDisplaySettings.PreviewPaintBoxPaint(Sender: TObject);
var
  Canvas: TCanvas;
  Destination: TRect;
begin
  Canvas := PreviewPaintBox.Canvas;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clBlack;
  Canvas.FillRect(PreviewPaintBox.ClientRect);
  Destination := BackgroundDestinationRect;
  if (FBackground.Width > 0) and (FBackground.Height > 0) then
    Canvas.StretchDraw(Destination, FBackground);
  CalculateLayout(Canvas, True);
  DrawSelection(Canvas);
  DrawDecorationHandles(Canvas);
end;

procedure TFormLyricsLineDisplaySettings.SetBackgroundRgba(
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
  PreviewPaintBox.Invalidate;
end;

procedure TFormLyricsLineDisplaySettings.UpdateTopLayout;
var
  FontTop: Integer;
  Gap: Integer;
  ToolbarLeft: Integer;
begin
  Gap := MulDiv(8, CurrentPPI, 96);
  if CandidateCombo.Visible then
    FontTop := MulDiv(40, CurrentPPI, 96)
  else
    FontTop := MulDiv(8, CurrentPPI, 96);
  BaseFontCombo.Top := FontTop;
  RubyFontCombo.Top := FontTop;
  BaseFontCombo.Width := MulDiv(150, CurrentPPI, 96);
  RubyFontLabel.Left := BaseFontCombo.Left + BaseFontCombo.Width +
    MulDiv(18, CurrentPPI, 96);
  RubyFontCombo.Left := RubyFontLabel.Left + MulDiv(80, CurrentPPI, 96);
  RubyFontCombo.Width := MulDiv(150, CurrentPPI, 96);
  BaseFontLabel.Top := FontTop + MulDiv(5, CurrentPPI, 96);
  RubyFontLabel.Top := BaseFontLabel.Top;
  if FToolbar <> nil then
  begin
    ToolbarLeft := RubyFontCombo.Left + RubyFontCombo.Width +
      MulDiv(16, CurrentPPI, 96);
    FToolbar.Left := ToolbarLeft;
    FToolbar.Top := FontTop - MulDiv(2, CurrentPPI, 96);
    FToolbar.Width := Max(MulDiv(180, CurrentPPI, 96),
      ClientWidth - ToolbarLeft - MulDiv(12, CurrentPPI, 96));
    PreviewPaintBox.Top := FToolbar.Top + FToolbar.Height + Gap;
  end;
  ColorPanel.Width := MulDiv(188, CurrentPPI, 96);
  ColorPanel.Left := ClientWidth - ColorPanel.Width - MulDiv(12,
    CurrentPPI, 96);
  ColorPanel.Top := PreviewPaintBox.Top;
  ColorPanel.Height := Max(1,
    ButtonPanel.Top - ColorPanel.Top - MulDiv(12, CurrentPPI, 96));
  PreviewPaintBox.Width := Max(1,
    ColorPanel.Left - PreviewPaintBox.Left - Gap);
  PreviewPaintBox.Height := Max(1,
    ButtonPanel.Top - PreviewPaintBox.Top - MulDiv(12, CurrentPPI, 96));
  LayoutColorControls;
end;

procedure TFormLyricsLineDisplaySettings.LayoutColorControls;
var
  AlphaHeight: Integer;
  Extent: Integer;
  Gap: Integer;
  LabelHeight: Integer;
  Margin: Integer;
  PickerHeight: Integer;
  TopValue: Integer;
begin
  if FColorTargetToolbar = nil then
    Exit;
  Margin := MulDiv(8, CurrentPPI, 96);
  Gap := MulDiv(6, CurrentPPI, 96);
  Extent := MulDiv(28, CurrentPPI, 96);
  LabelHeight := MulDiv(18, CurrentPPI, 96);
  AlphaHeight := MulDiv(24, CurrentPPI, 96);
  PickerHeight := Min(
    Max(MulDiv(72, CurrentPPI, 96), ColorPanel.ClientWidth - Margin * 2 -
      MulDiv(24, CurrentPPI, 96)),
    Max(MulDiv(72, CurrentPPI, 96),
      (ColorPanel.ClientHeight - Margin * 2 - Extent - Gap * 5 -
        LabelHeight * 2 - AlphaHeight * 2) div 2));

  FColorTargetToolbar.ButtonExtent := Extent;
  FColorTargetToolbar.SetBounds(Margin, Margin,
    ColorPanel.ClientWidth - Margin * 2, Extent);
  TopValue := FColorTargetToolbar.Top + Extent + Gap;
  FBeforeColorLabel.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, LabelHeight);
  Inc(TopValue, LabelHeight);
  FBeforeColorPicker.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, PickerHeight);
  Inc(TopValue, PickerHeight + Gap);
  FBeforeOpacityTrack.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, AlphaHeight);
  FBeforeOpacityLabel.SetBounds(Margin,
    TopValue + (AlphaHeight - FBeforeOpacityLabel.Height) div 2,
    MulDiv(42, CurrentPPI, 96), FBeforeOpacityLabel.Height);
  FBeforeOpacityTrack.Left := FBeforeOpacityLabel.Left +
    FBeforeOpacityLabel.Width;
  FBeforeOpacityTrack.Width := ColorPanel.ClientWidth - Margin -
    FBeforeOpacityTrack.Left;
  Inc(TopValue, AlphaHeight + Gap);
  FAfterColorLabel.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, LabelHeight);
  Inc(TopValue, LabelHeight);
  FAfterColorPicker.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, PickerHeight);
  Inc(TopValue, PickerHeight + Gap);
  FAfterOpacityTrack.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, AlphaHeight);
  FAfterOpacityLabel.SetBounds(Margin,
    TopValue + (AlphaHeight - FAfterOpacityLabel.Height) div 2,
    MulDiv(42, CurrentPPI, 96), FAfterOpacityLabel.Height);
  FAfterOpacityTrack.Left := FAfterOpacityLabel.Left +
    FAfterOpacityLabel.Width;
  FAfterOpacityTrack.Width := ColorPanel.ClientWidth - Margin -
    FAfterOpacityTrack.Left;
end;

end.
