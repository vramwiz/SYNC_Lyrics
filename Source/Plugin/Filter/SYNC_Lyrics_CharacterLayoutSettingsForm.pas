unit SYNC_Lyrics_CharacterLayoutSettingsForm;

// Provides the free-placement display settings editor.

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Winapi.Windows,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_CharacterLayoutInteraction,
  SYNC_Lyrics_LineDisplaySettingsForm,
  SYNC_Lyrics_ToolbarButtons,
  TextRendererSkia,
  TextRendererTypes;

type
  TFormLyricsCharacterLayoutSettings = class(TForm)
    CandidateLabel: TLabel;
    CandidateCombo: TComboBox;
    DescriptionLabel: TLabel;
    BackgroundPaintBox: TPaintBox;
    ButtonPanel: TPanel;
    PlacementModeLabel: TLabel;
    PlacementModeCombo: TComboBox;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    ElementPanel: TPanel;
    ElementListLabel: TLabel;
    ElementListView: TListView;
    ColorPanel: TPanel;
    procedure BackgroundPaintBoxMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BackgroundPaintBoxMouseMove(Sender: TObject;
      Shift: TShiftState; X, Y: Integer);
    procedure BackgroundPaintBoxMouseUp(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure BackgroundPaintBoxMouseWheel(Sender: TObject;
      Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
      var Handled: Boolean);
    procedure BackgroundPaintBoxPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure CandidateComboChange(Sender: TObject);
    procedure DarkComboBoxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure ElementListViewSelectItem(Sender: TObject; Item: TListItem;
      Selected: Boolean);
    procedure ButtonMoveToCenterClick(Sender: TObject);
    procedure ButtonResetSelectedClick(Sender: TObject);
    procedure ButtonResetAllClick(Sender: TObject);
    procedure ButtonAlignHorizontalClick(Sender: TObject);
    procedure ButtonDistributeHorizontalClick(Sender: TObject);
    procedure ButtonFontClick(Sender: TObject);
    procedure ButtonBeforeColorClick(Sender: TObject);
    procedure ButtonAfterColorClick(Sender: TObject);
  private
    FBackground: TBitmap;
    FBackgroundPixels: TBytes;
    FBackgroundPixelWidth: Integer;
    FBackgroundPixelHeight: Integer;
    FBaseFontHeight: Integer;
    FBaseFontName: string;
    FBaseFontStyle: Byte;
    FBeforeColor: TColor;
    FDragMode: TCharacterLayoutDragMode;
    FDragChanged: Boolean;
    FClickCandidateModeToggle: Boolean;
    FCommonSettings: TDisplayCommonSettings;
    FDragStartMouse: TPoint;
    FDragStartGroupBounds: TRectF;
    FDragStartPlacement: TDisplayPlacementItem;
    FDragStartPlacements: TDisplayPlacementItems;
    FLyrics: string;
    FPlainText: string;
    FPlacements: TDisplayPlacementItems;
    FPreviewRenderer: TSkiaTextRenderer;
    FRubyGap: Integer;
    FRubyFontHeight: Integer;
    FRubyFontName: string;
    FRubyFontStyle: Byte;
    FAfterColor: TColor;
    FRubySpans: TLyricsRubySpans;
    FSelected: TArray<Boolean>;
    FSelectedIndex: Integer;
    FSelectionMode: TCharacterLayoutSelectionMode;
    FSelectionCurrent: TPoint;
    FSelectionStart: TPoint;
    FSelectingRectangle: Boolean;
    FUnits: TLyricsDisplayUnits;
    FUpdatingElementList: Boolean;
    FUpdatingSelectedSettings: Boolean;
    FToolbar: TSyncLyricsToolbarButtons;
    FToolbarAfterColor: TSyncLyricsToolbarButton;
    FToolbarBeforeColor: TSyncLyricsToolbarButton;
    FToolbarBold: TSyncLyricsToolbarButton;
    FToolbarItalic: TSyncLyricsToolbarButton;
    FToolbarStrikeOut: TSyncLyricsToolbarButton;
    FToolbarUnderline: TSyncLyricsToolbarButton;
    FPlacementModeButton: TSyncLyricsToolbarButton;
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
    FUpdatingColorControls: Boolean;
    FCandidateLyrics: TArray<string>;
    FCandidateSettings: TArray<TDisplayCommonSettings>;
    FCandidateSettingsText: TArray<string>;
    FViewPan: TPointF;
    FViewZoom: Double;
    FDragStartViewPan: TPointF;
    function BackgroundDestinationRect: TRect;
    function BackgroundScale: Double;
    procedure BuildInitialPlacements;
    procedure BuildDefaultPlacements(out Placements: TDisplayPlacementItems);
    procedure EditCommonSettings;
    procedure EditSelectedDecoration;
    function ResolvedDecorationSettings(
      Index: Integer): TDisplayCommonSettings;
    procedure ApplyDecorationOverrides(Index: Integer;
      const Settings: TDisplayCommonSettings);
    procedure CreateFormattingToolbar;
    procedure CreateColorControls;
    procedure ColorPickerChange(Sender: TObject);
    procedure ColorTargetExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure OpacityTrackChange(Sender: TObject);
    procedure ApplySelectedColorControls;
    procedure UpdateColorControls;
    procedure LayoutRightPanels;
    procedure LayoutColorControls;
    procedure ClearSelection;
    function DisplayUnitBaseText(Index: Integer): string;
    function DisplayUnitBaseFontName(Index: Integer): string;
    function DisplayUnitBaseFontHeight(Index: Integer): Integer;
    function DisplayUnitBaseFontStyle(Index: Integer): Byte;
    function DisplayUnitBaseCharacterSpacing(Index: Integer): Integer;
    function DisplayUnitBeforeColor(Index: Integer): TColor;
    function DisplayUnitBounds(Index: Integer): TRect;
    function DisplayUnitNaturalBounds(Index: Integer): TRectF;
    function DisplayUnitSceneBounds(Index: Integer): TRectF;
    function DisplayUnitRubyText(Index: Integer): string;
    function DisplayUnitRubyFontName(Index: Integer): string;
    function DisplayUnitRubyFontHeight(Index: Integer): Integer;
    function DisplayUnitRubyFontStyle(Index: Integer): Byte;
    function DisplayUnitRubyCharacterSpacing(Index: Integer): Integer;
    function DisplayUnitRubyOffsetX(Index: Integer): Integer;
    function DisplayUnitRubyOffsetY(Index: Integer): Integer;
    function DisplayUnitAfterColor(Index: Integer): TColor;
    procedure DrawSelectionRectangle;
    function GroupSelectionBounds: TRect;
    function GroupSelectionSceneBounds: TRectF;
    function HitTestDisplayUnit(X, Y: Integer): Integer;
    function HitTestModeHandle(X, Y: Integer): TCharacterLayoutDragMode;
    function HitTestResizeHandle(X, Y: Integer): TCharacterLayoutDragMode;
    procedure PaintDisplayUnit(Index: Integer);
    function RenderDisplayUnitTextImage(Index: Integer;
      const Text: string; Ruby, AfterPhase: Boolean): TTextRenderImage;
    function CreatePreviewBitmap(Image: TTextRenderImage): TBitmap;
    procedure DrawDisplayUnitTextImage(Index: Integer;
      Image: TTextRenderImage; LayoutLeft, LayoutTop: Single;
      TransitionX: Integer; AfterPhase: Boolean);
    procedure PopulateElementList;
    procedure ResizeSelectedElement(X, Y: Integer);
    procedure ResizeSelection(X, Y: Integer);
    procedure SelectOnly(Index: Integer);
    function SelectionCount: Integer;
    function SelectionSupportsRubyMode: Boolean;
    function ScenePointToScreen(X, Y: Single): TPoint;
    procedure UpdateElementListSelection;
    procedure UpdateSelectedSettings;
    procedure UpdateToolbarButtons;
    procedure ToolbarButtonExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
  public
    procedure Configure(const Lyrics: string;
      const CommonSettings: TDisplayCommonSettings;
      const SettingsText: string);
    procedure ConfigureCandidates(const Captions, Lyrics: TArray<string>;
      const CommonSettings: TArray<TDisplayCommonSettings>;
      const SettingsText: TArray<string>; InitialIndex: Integer);
    procedure ConfigurePlacementMode(PlacementMode: Integer);
    procedure SetPlacementModeSwitchVisible(Value: Boolean);
    function SelectedCandidateIndex: Integer;
    function SelectedPlacementMode: Integer;
    procedure SetBackgroundRgba(const Pixels: TBytes;
      Width, Height: Integer);
    procedure SetCaptureStatus(const Value: string);
    function TryBuildSettingsText(out SettingsText: string): Boolean;
  end;

implementation

uses
  System.Math,
  ColorPickerDialog,
  SYNC_Lyrics_CharacterLayoutDrawing,
  SYNC_Lyrics_FontSettingsForm,
  SYNC_Lyrics_DarkTheme,
  TextRendererSkiaRuntime;

{$R *.dfm}

const
  TOOLBAR_COMMON_SETTINGS = 0;
  TOOLBAR_FONT = 1;
  TOOLBAR_BOLD = 2;
  TOOLBAR_ITALIC = 3;
  TOOLBAR_UNDERLINE = 4;
  TOOLBAR_STRIKE_OUT = 5;
  TOOLBAR_BEFORE_COLOR = 6;
  TOOLBAR_AFTER_COLOR = 7;
  TOOLBAR_DECORATION = 8;
  TOOLBAR_SWITCH_TO_LINE = 9;
  TOOLBAR_MOVE_TO_CENTER = 20;
  TOOLBAR_RESET_SELECTED = 21;
  TOOLBAR_RESET_ALL = 22;
  TOOLBAR_ALIGN_HORIZONTAL = 23;
  TOOLBAR_DISTRIBUTE_HORIZONTAL = 24;
  CHARACTER_COLOR_TARGET_BASE = 200;

function FontStyleByteToSet(Value: Byte): TFontStyles;
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

function FontStyleSetToByte(const Value: TFontStyles): Byte;
begin
  Result := 0;
  if fsBold in Value then
    Result := Result or 1;
  if fsItalic in Value then
    Result := Result or 2;
  if fsUnderline in Value then
    Result := Result or 4;
  if fsStrikeOut in Value then
    Result := Result or 8;
end;

function MeasureVisibleCanvasText(Canvas: TCanvas;
  const Text: string): TSize;
begin
  Result := Canvas.TextExtent(Text);
  if Text <> '' then
    Result.cx := Max(0, Result.cx -
      GetTextCharacterExtra(Canvas.Handle));
end;

procedure TFormLyricsCharacterLayoutSettings.CreateFormattingToolbar;
var
  Extent: Integer;
  ToolbarTop: Integer;
begin
  Extent := MulDiv(28, CurrentPPI, 96);
  ToolbarTop := DescriptionLabel.Top + DescriptionLabel.Height +
    MulDiv(6, CurrentPPI, 96);
  FToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.SetBounds(DescriptionLabel.Left, ToolbarTop,
    ClientWidth - DescriptionLabel.Left * 2, Extent);
  FToolbar.Anchors := [akLeft, akTop, akRight];
  FToolbar.ButtonExtent := Extent;
  FToolbar.SeparatorExtent := MulDiv(6, CurrentPPI, 96);
  FToolbar.Color := Color;
  FToolbar.ParentBackground := False;
  FToolbar.OnButtonExecute := ToolbarButtonExecute;

  FPlacementModeButton := FToolbar.AddCommandButton(
    '1行配置へ切替', tbgLinePlacement, TOOLBAR_SWITCH_TO_LINE);
  FToolbar.AddSeparator;
  FToolbar.AddDialogButton('行共通設定', tbgOutline,
    TOOLBAR_COMMON_SETTINGS);
  FToolbar.AddSeparator;
  FToolbar.AddDialogButton('フォント設定', tbgFont, TOOLBAR_FONT);
  FToolbar.AddSeparator;
  FToolbarBold := FToolbar.AddToggleButton('太字', tbgBold,
    TOOLBAR_BOLD);
  FToolbarItalic := FToolbar.AddToggleButton('斜体', tbgItalic,
    TOOLBAR_ITALIC);
  FToolbarUnderline := FToolbar.AddToggleButton('下線',
    tbgUnderline, TOOLBAR_UNDERLINE);
  FToolbarStrikeOut := FToolbar.AddToggleButton('取り消し線',
    tbgStrikeOut, TOOLBAR_STRIKE_OUT);
  FToolbar.AddSeparator;
  FToolbarBeforeColor := FToolbar.AddDialogButton('同期前色',
    tbgBeforeColor, TOOLBAR_BEFORE_COLOR);
  FToolbarAfterColor := FToolbar.AddDialogButton('同期後色',
    tbgAfterColor, TOOLBAR_AFTER_COLOR);
  FToolbar.AddDialogButton('選択要素の装飾', tbgOutline,
    TOOLBAR_DECORATION);
  FToolbar.AddSeparator;
  FToolbar.AddCommandButton('選択を画面中央へ', tbgMoveToCenter,
    TOOLBAR_MOVE_TO_CENTER);
  FToolbar.AddCommandButton('選択を初期位置へ', tbgResetSelected,
    TOOLBAR_RESET_SELECTED);
  FToolbar.AddCommandButton('すべて初期配置', tbgResetAll,
    TOOLBAR_RESET_ALL);
  FToolbar.AddCommandButton('選択を横一列へ', tbgAlignHorizontal,
    TOOLBAR_ALIGN_HORIZONTAL);
  FToolbar.AddCommandButton('選択間隔を均等に',
    tbgDistributeHorizontal, TOOLBAR_DISTRIBUTE_HORIZONTAL);
end;

procedure TFormLyricsCharacterLayoutSettings.CreateColorControls;
const
  HINTS: array[TLineDisplayColorTarget] of string = (
    '地色', '縁取り色', '影色', '縁取りぼかし色');
  GLYPHS: array[TLineDisplayColorTarget] of TSyncLyricsToolbarGlyph = (
    tbgFillColor, tbgOutlineColor, tbgShadowColor, tbgBlurColor);
var
  Target: TLineDisplayColorTarget;
begin
  FColorTargetToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FColorTargetToolbar.Parent := ColorPanel;
  FColorTargetToolbar.SeparatorExtent := 0;
  FColorTargetToolbar.Color := ColorPanel.Color;
  FColorTargetToolbar.ParentBackground := False;
  FColorTargetToolbar.OnButtonExecute := ColorTargetExecute;
  for Target := Low(TLineDisplayColorTarget) to High(TLineDisplayColorTarget) do
    FColorTargetButtons[Target] := FColorTargetToolbar.AddToggleButton(
      HINTS[Target], GLYPHS[Target],
      CHARACTER_COLOR_TARGET_BASE + Ord(Target));

  FBeforeColorLabel := TLabel.Create(Self);
  FBeforeColorLabel.Parent := ColorPanel;
  FBeforeColorLabel.Caption := '同期前';
  FBeforeColorLabel.Font.Assign(Font);
  FBeforeColorPicker := TSyncLyricsEmbeddedColorPicker.Create(Self);
  FBeforeColorPicker.Parent := ColorPanel;
  FBeforeColorPicker.OnChange := ColorPickerChange;
  FBeforeOpacityTrack := TTrackBar.Create(Self);
  FBeforeOpacityTrack.Parent := ColorPanel;
  FBeforeOpacityTrack.Min := 0;
  FBeforeOpacityTrack.Max := 255;
  FBeforeOpacityTrack.TickStyle := tsNone;
  FBeforeOpacityTrack.OnChange := OpacityTrackChange;
  FBeforeOpacityLabel := TLabel.Create(Self);
  FBeforeOpacityLabel.Parent := ColorPanel;
  FBeforeOpacityLabel.Caption := '透明度';
  FBeforeOpacityLabel.Font.Assign(Font);

  FAfterColorLabel := TLabel.Create(Self);
  FAfterColorLabel.Parent := ColorPanel;
  FAfterColorLabel.Caption := '同期後';
  FAfterColorLabel.Font.Assign(Font);
  FAfterColorPicker := TSyncLyricsEmbeddedColorPicker.Create(Self);
  FAfterColorPicker.Parent := ColorPanel;
  FAfterColorPicker.OnChange := ColorPickerChange;
  FAfterOpacityTrack := TTrackBar.Create(Self);
  FAfterOpacityTrack.Parent := ColorPanel;
  FAfterOpacityTrack.Min := 0;
  FAfterOpacityTrack.Max := 255;
  FAfterOpacityTrack.TickStyle := tsNone;
  FAfterOpacityTrack.OnChange := OpacityTrackChange;
  FAfterOpacityLabel := TLabel.Create(Self);
  FAfterOpacityLabel.Parent := ColorPanel;
  FAfterOpacityLabel.Caption := '透明度';
  FAfterOpacityLabel.Font.Assign(Font);
end;

procedure TFormLyricsCharacterLayoutSettings.ColorTargetExecute(
  Sender: TObject; Button: TSyncLyricsToolbarButton);
begin
  if (Button.Tag < CHARACTER_COLOR_TARGET_BASE) or
    (Button.Tag > CHARACTER_COLOR_TARGET_BASE +
      Ord(High(TLineDisplayColorTarget))) then
    Exit;
  FColorTarget := TLineDisplayColorTarget(
    Button.Tag - CHARACTER_COLOR_TARGET_BASE);
  UpdateColorControls;
end;

procedure TFormLyricsCharacterLayoutSettings.ColorPickerChange(
  Sender: TObject);
begin
  if FUpdatingColorControls or (SelectionCount = 0) then
    Exit;
  if Sender = FBeforeColorPicker then
    FBeforePalette[FColorTarget] := FBeforeColorPicker.Color
  else if Sender = FAfterColorPicker then
    FAfterPalette[FColorTarget] := FAfterColorPicker.Color
  else
    Exit;
  ApplySelectedColorControls;
end;

procedure TFormLyricsCharacterLayoutSettings.OpacityTrackChange(
  Sender: TObject);
begin
  if FUpdatingColorControls or (SelectionCount = 0) then
    Exit;
  if Sender = FBeforeOpacityTrack then
    FBeforePaletteOpacity[FColorTarget] := FBeforeOpacityTrack.Position
  else if Sender = FAfterOpacityTrack then
    FAfterPaletteOpacity[FColorTarget] := FAfterOpacityTrack.Position
  else
    Exit;
  ApplySelectedColorControls;
end;

procedure TFormLyricsCharacterLayoutSettings.ApplySelectedColorControls;
var
  I: Integer;
  Settings: TDisplayCommonSettings;
begin
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      Settings := ResolvedDecorationSettings(I);
      case FColorTarget of
        ldctFill:
          begin
            Settings.BeforeColor := Cardinal(FBeforePalette[ldctFill]);
            Settings.AfterColor := Cardinal(FAfterPalette[ldctFill]);
            Settings.BeforeOpacity := FBeforePaletteOpacity[ldctFill];
            Settings.AfterOpacity := FAfterPaletteOpacity[ldctFill];
          end;
        ldctOutline:
          begin
            Settings.BeforeOutlineColor :=
              Cardinal(FBeforePalette[ldctOutline]);
            Settings.AfterOutlineColor :=
              Cardinal(FAfterPalette[ldctOutline]);
            Settings.BeforeOutlineOpacity :=
              FBeforePaletteOpacity[ldctOutline];
            Settings.AfterOutlineOpacity :=
              FAfterPaletteOpacity[ldctOutline];
          end;
        ldctShadow:
          begin
            Settings.BeforeShadowColor :=
              Cardinal(FBeforePalette[ldctShadow]);
            Settings.AfterShadowColor :=
              Cardinal(FAfterPalette[ldctShadow]);
            Settings.BeforeShadowOpacity :=
              FBeforePaletteOpacity[ldctShadow];
            Settings.AfterShadowOpacity :=
              FAfterPaletteOpacity[ldctShadow];
          end;
        ldctBlur:
          begin
            Settings.BeforeBlurColor :=
              Cardinal(FBeforePalette[ldctBlur]);
            Settings.AfterBlurColor :=
              Cardinal(FAfterPalette[ldctBlur]);
            Settings.BeforeBlurOpacity :=
              FBeforePaletteOpacity[ldctBlur];
            Settings.AfterBlurOpacity :=
              FAfterPaletteOpacity[ldctBlur];
          end;
      end;
      ApplyDecorationOverrides(I, Settings);
    end;
  UpdateToolbarButtons;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.UpdateColorControls;
var
  Settings: TDisplayCommonSettings;
  Target: TLineDisplayColorTarget;
begin
  if (FBeforeColorPicker = nil) or (FAfterColorPicker = nil) then
    Exit;
  ColorPanel.Enabled := SelectionCount > 0;
  if SelectionCount = 0 then
    Exit;
  Settings := ResolvedDecorationSettings(FSelectedIndex);
  FBeforePalette[ldctFill] := TColor(Settings.BeforeColor);
  FAfterPalette[ldctFill] := TColor(Settings.AfterColor);
  FBeforePaletteOpacity[ldctFill] := Settings.BeforeOpacity;
  FAfterPaletteOpacity[ldctFill] := Settings.AfterOpacity;
  FBeforePalette[ldctOutline] := TColor(Settings.BeforeOutlineColor);
  FAfterPalette[ldctOutline] := TColor(Settings.AfterOutlineColor);
  FBeforePaletteOpacity[ldctOutline] := Settings.BeforeOutlineOpacity;
  FAfterPaletteOpacity[ldctOutline] := Settings.AfterOutlineOpacity;
  FBeforePalette[ldctShadow] := TColor(Settings.BeforeShadowColor);
  FAfterPalette[ldctShadow] := TColor(Settings.AfterShadowColor);
  FBeforePaletteOpacity[ldctShadow] := Settings.BeforeShadowOpacity;
  FAfterPaletteOpacity[ldctShadow] := Settings.AfterShadowOpacity;
  FBeforePalette[ldctBlur] := TColor(Settings.BeforeBlurColor);
  FAfterPalette[ldctBlur] := TColor(Settings.AfterBlurColor);
  FBeforePaletteOpacity[ldctBlur] := Settings.BeforeBlurOpacity;
  FAfterPaletteOpacity[ldctBlur] := Settings.AfterBlurOpacity;
  FUpdatingColorControls := True;
  try
    for Target := Low(TLineDisplayColorTarget) to
      High(TLineDisplayColorTarget) do
      FColorTargetButtons[Target].CheckState :=
        TSyncLyricsToolbarCheckState(Ord(Target = FColorTarget));
    FBeforeColorPicker.Color := FBeforePalette[FColorTarget];
    FAfterColorPicker.Color := FAfterPalette[FColorTarget];
    FBeforeOpacityTrack.Position := FBeforePaletteOpacity[FColorTarget];
    FAfterOpacityTrack.Position := FAfterPaletteOpacity[FColorTarget];
  finally
    FUpdatingColorControls := False;
  end;
end;

procedure TFormLyricsCharacterLayoutSettings.DarkComboBoxDrawItem(
  Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
begin
  DrawSyncLyricsDarkComboBoxItem(Control as TComboBox, Index, Rect,
    State, CurrentPPI);
end;

procedure TFormLyricsCharacterLayoutSettings.LayoutRightPanels;
var
  Gap: Integer;
  Margin: Integer;
begin
  Margin := MulDiv(12, CurrentPPI, 96);
  Gap := MulDiv(12, CurrentPPI, 96);
  ColorPanel.Width := MulDiv(188, CurrentPPI, 96);
  ColorPanel.Left := ClientWidth - Margin - ColorPanel.Width;
  ColorPanel.Top := BackgroundPaintBox.Top;
  ColorPanel.Height := Max(1, ButtonPanel.Top - ColorPanel.Top - MulDiv(8,
    CurrentPPI, 96));
  ElementPanel.Width := MulDiv(128, CurrentPPI, 96);
  ElementPanel.Left := ColorPanel.Left - Gap - ElementPanel.Width;
  ElementPanel.Top := ColorPanel.Top;
  ElementPanel.Height := ColorPanel.Height;
  BackgroundPaintBox.Width := Max(1,
    ElementPanel.Left - Gap - BackgroundPaintBox.Left);
  BackgroundPaintBox.Height := ElementPanel.Height;
  LayoutColorControls;
end;

procedure TFormLyricsCharacterLayoutSettings.LayoutColorControls;
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
  TopValue := Margin + Extent + Gap;
  FBeforeColorLabel.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, LabelHeight);
  Inc(TopValue, LabelHeight);
  FBeforeColorPicker.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, PickerHeight);
  Inc(TopValue, PickerHeight + Gap);
  FBeforeOpacityLabel.SetBounds(Margin, TopValue,
    MulDiv(42, CurrentPPI, 96), AlphaHeight);
  FBeforeOpacityTrack.SetBounds(FBeforeOpacityLabel.Left +
    FBeforeOpacityLabel.Width, TopValue,
    ColorPanel.ClientWidth - Margin - FBeforeOpacityLabel.Left -
      FBeforeOpacityLabel.Width, AlphaHeight);
  Inc(TopValue, AlphaHeight + Gap);
  FAfterColorLabel.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, LabelHeight);
  Inc(TopValue, LabelHeight);
  FAfterColorPicker.SetBounds(Margin, TopValue,
    ColorPanel.ClientWidth - Margin * 2, PickerHeight);
  Inc(TopValue, PickerHeight + Gap);
  FAfterOpacityLabel.SetBounds(Margin, TopValue,
    MulDiv(42, CurrentPPI, 96), AlphaHeight);
  FAfterOpacityTrack.SetBounds(FAfterOpacityLabel.Left +
    FAfterOpacityLabel.Width, TopValue,
    ColorPanel.ClientWidth - Margin - FAfterOpacityLabel.Left -
      FAfterOpacityLabel.Width, AlphaHeight);
end;

procedure TFormLyricsCharacterLayoutSettings.FormResize(Sender: TObject);
begin
  LayoutRightPanels;
end;

procedure TFormLyricsCharacterLayoutSettings.FormCreate(Sender: TObject);
begin
  ApplySyncLyricsDarkForm(Self);
  ApplySyncLyricsDarkPanel(ElementPanel);
  ApplySyncLyricsDarkPanel(ColorPanel);
  ApplySyncLyricsDarkPanel(ButtonPanel);
  ApplySyncLyricsDarkListView(ElementListView);
  ApplySyncLyricsDarkComboBox(CandidateCombo, DarkComboBoxDrawItem);
  PlacementModeCombo.Items.Clear;
  PlacementModeCombo.Items.Add('1行配置');
  PlacementModeCombo.Items.Add('文字自由配置');
  PlacementModeCombo.ItemIndex := 1;
  ApplySyncLyricsDarkComboBox(PlacementModeCombo, DarkComboBoxDrawItem);
  ApplySyncLyricsDarkButton(ButtonOK);
  ApplySyncLyricsDarkButton(ButtonCancel);
  FBackground := TBitmap.Create;
  FBackground.PixelFormat := pf32bit;
  FPreviewRenderer := nil;
  if TTextRendererSkiaRuntime.IsAcquired then
    FPreviewRenderer := TSkiaTextRenderer.Create;
  FSelectedIndex := -1;
  FSelectionMode := clsmTransform;
  FDragMode := cldmNone;
  FViewPan := TPointF.Zero;
  FViewZoom := 1;
  OnMouseWheel := BackgroundPaintBoxMouseWheel;
  DoubleBuffered := True;
  CreateFormattingToolbar;
  CreateColorControls;
  LayoutRightPanels;
  UpdateToolbarButtons;
  UpdateColorControls;
end;

procedure TFormLyricsCharacterLayoutSettings.FormDestroy(Sender: TObject);
begin
  FPreviewRenderer.Free;
  FBackground.Free;
end;

procedure TFormLyricsCharacterLayoutSettings.ClearSelection;
var
  I: Integer;
begin
  for I := 0 to High(FSelected) do
    FSelected[I] := False;
  FSelectedIndex := -1;
  FSelectionMode := clsmTransform;
end;

procedure TFormLyricsCharacterLayoutSettings.UpdateElementListSelection;
var
  I: Integer;
begin
  if FUpdatingElementList then
    Exit;
  FUpdatingElementList := True;
  try
    for I := 0 to ElementListView.Items.Count - 1 do
      ElementListView.Items[I].Selected :=
        (I < Length(FSelected)) and FSelected[I];
  finally
    FUpdatingElementList := False;
  end;
end;

procedure TFormLyricsCharacterLayoutSettings.UpdateSelectedSettings;
begin
  if FUpdatingSelectedSettings then
    Exit;
  FUpdatingSelectedSettings := True;
  try
    UpdateToolbarButtons;
    UpdateColorControls;
  finally
    FUpdatingSelectedSettings := False;
  end;
end;

procedure TFormLyricsCharacterLayoutSettings.UpdateToolbarButtons;
var
  Count: Integer;
  Item: TSyncLyricsToolbarButton;

  function ResolveStyleState(StyleBit: Byte):
    TSyncLyricsToolbarCheckState;
  var
    AnyOff: Boolean;
    AnyOn: Boolean;
    I: Integer;
  begin
    AnyOff := False;
    AnyOn := False;
    for I := 0 to High(FSelected) do
      if FSelected[I] then
      begin
        if (DisplayUnitBaseFontStyle(I) and StyleBit) <> 0 then
          AnyOn := True
        else
          AnyOff := True;
        if DisplayUnitRubyText(I) <> '' then
          if (DisplayUnitRubyFontStyle(I) and StyleBit) <> 0 then
            AnyOn := True
          else
            AnyOff := True;
      end;
    if AnyOn and AnyOff then
      Result := tbcsMixed
    else if AnyOn then
      Result := tbcsChecked
    else
      Result := tbcsUnchecked;
  end;

  procedure SetEnabled(TagValue: NativeInt; Value: Boolean);
  begin
    Item := FToolbar.FindByTag(TagValue);
    if Item <> nil then
      Item.Enabled := Value;
  end;

begin
  if FToolbar = nil then
    Exit;
  Count := SelectionCount;
  SetEnabled(TOOLBAR_FONT, Count > 0);
  SetEnabled(TOOLBAR_BOLD, Count > 0);
  SetEnabled(TOOLBAR_ITALIC, Count > 0);
  SetEnabled(TOOLBAR_UNDERLINE, Count > 0);
  SetEnabled(TOOLBAR_STRIKE_OUT, Count > 0);
  SetEnabled(TOOLBAR_BEFORE_COLOR, Count > 0);
  SetEnabled(TOOLBAR_AFTER_COLOR, Count > 0);
  SetEnabled(TOOLBAR_MOVE_TO_CENTER, Count > 0);
  SetEnabled(TOOLBAR_RESET_SELECTED, Count > 0);
  SetEnabled(TOOLBAR_RESET_ALL, Length(FPlacements) > 0);
  SetEnabled(TOOLBAR_ALIGN_HORIZONTAL, Count >= 2);
  SetEnabled(TOOLBAR_DISTRIBUTE_HORIZONTAL, Count >= 3);
  SetEnabled(TOOLBAR_DECORATION, Count > 0);

  FToolbarBold.CheckState := ResolveStyleState(1);
  FToolbarItalic.CheckState := ResolveStyleState(2);
  FToolbarUnderline.CheckState := ResolveStyleState(4);
  FToolbarStrikeOut.CheckState := ResolveStyleState(8);
  if Count > 0 then
  begin
    FToolbarBeforeColor.AccentColor :=
      DisplayUnitBeforeColor(FSelectedIndex);
    FToolbarBeforeColor.HasAccentColor := True;
    FToolbarAfterColor.AccentColor :=
      DisplayUnitAfterColor(FSelectedIndex);
    FToolbarAfterColor.HasAccentColor := True;
  end
  else
  begin
    FToolbarBeforeColor.HasAccentColor := False;
    FToolbarAfterColor.HasAccentColor := False;
  end;
end;

procedure TFormLyricsCharacterLayoutSettings.ToolbarButtonExecute(
  Sender: TObject; Button: TSyncLyricsToolbarButton);

  procedure ApplyStyleBit(StyleBit: Byte; TurnOn: Boolean);
  var
    I: Integer;
    StyleValue: Byte;
  begin
    for I := 0 to High(FSelected) do
      if FSelected[I] then
      begin
        StyleValue := DisplayUnitBaseFontStyle(I);
        if TurnOn then
          StyleValue := StyleValue or StyleBit
        else
          StyleValue := StyleValue and not StyleBit;
        FPlacements[I].BaseFontStyle := StyleValue and $0F;
        FPlacements[I].HasBaseFontStyle :=
          FPlacements[I].BaseFontStyle <> FBaseFontStyle;

        if DisplayUnitRubyText(I) <> '' then
        begin
          StyleValue := DisplayUnitRubyFontStyle(I);
          if TurnOn then
            StyleValue := StyleValue or StyleBit
          else
            StyleValue := StyleValue and not StyleBit;
          FPlacements[I].RubyFontStyle := StyleValue and $0F;
          FPlacements[I].HasRubyFontStyle :=
            FPlacements[I].RubyFontStyle <> FRubyFontStyle;
        end;
      end;
    UpdateSelectedSettings;
    BackgroundPaintBox.Invalidate;
  end;

begin
  case Button.Tag of
    TOOLBAR_SWITCH_TO_LINE:
      begin
        PlacementModeCombo.ItemIndex := 0;
        ModalResult := PLACEMENT_MODE_SWITCH_MODAL_RESULT;
        Exit;
      end;
    TOOLBAR_COMMON_SETTINGS:
      EditCommonSettings;
    TOOLBAR_FONT:
      ButtonFontClick(Button);
    TOOLBAR_BOLD:
      ApplyStyleBit(1, Button.CheckState = tbcsChecked);
    TOOLBAR_ITALIC:
      ApplyStyleBit(2, Button.CheckState = tbcsChecked);
    TOOLBAR_UNDERLINE:
      ApplyStyleBit(4, Button.CheckState = tbcsChecked);
    TOOLBAR_STRIKE_OUT:
      ApplyStyleBit(8, Button.CheckState = tbcsChecked);
    TOOLBAR_BEFORE_COLOR:
      ButtonBeforeColorClick(Button);
    TOOLBAR_AFTER_COLOR:
      ButtonAfterColorClick(Button);
    TOOLBAR_DECORATION:
      EditSelectedDecoration;
    TOOLBAR_MOVE_TO_CENTER:
      ButtonMoveToCenterClick(Button);
    TOOLBAR_RESET_SELECTED:
      ButtonResetSelectedClick(Button);
    TOOLBAR_RESET_ALL:
      ButtonResetAllClick(Button);
    TOOLBAR_ALIGN_HORIZONTAL:
      ButtonAlignHorizontalClick(Button);
    TOOLBAR_DISTRIBUTE_HORIZONTAL:
      ButtonDistributeHorizontalClick(Button);
  end;
end;

function TFormLyricsCharacterLayoutSettings.ResolvedDecorationSettings(
  Index: Integer): TDisplayCommonSettings;
var
  Item: TDisplayPlacementItem;
begin
  Result := FCommonSettings;
  if (Index < 0) or (Index >= Length(FPlacements)) then
    Exit;
  Item := FPlacements[Index];
  if Item.HasBeforeColor then Result.BeforeColor := Item.BeforeColor;
  if Item.HasAfterColor then Result.AfterColor := Item.AfterColor;
  if Item.HasBeforeOpacity then Result.BeforeOpacity := Item.BeforeOpacity;
  if Item.HasAfterOpacity then Result.AfterOpacity := Item.AfterOpacity;
  if Item.HasBeforeOutlineColor then
    Result.BeforeOutlineColor := Item.BeforeOutlineColor;
  if Item.HasAfterOutlineColor then
    Result.AfterOutlineColor := Item.AfterOutlineColor;
  if Item.HasBeforeOutlineOpacity then
    Result.BeforeOutlineOpacity := Item.BeforeOutlineOpacity;
  if Item.HasAfterOutlineOpacity then
    Result.AfterOutlineOpacity := Item.AfterOutlineOpacity;
  if Item.HasBeforeShadowColor then
    Result.BeforeShadowColor := Item.BeforeShadowColor;
  if Item.HasAfterShadowColor then
    Result.AfterShadowColor := Item.AfterShadowColor;
  if Item.HasBeforeShadowOpacity then
    Result.BeforeShadowOpacity := Item.BeforeShadowOpacity;
  if Item.HasAfterShadowOpacity then
    Result.AfterShadowOpacity := Item.AfterShadowOpacity;
  if Item.HasBeforeBlurColor then
    Result.BeforeBlurColor := Item.BeforeBlurColor;
  if Item.HasAfterBlurColor then
    Result.AfterBlurColor := Item.AfterBlurColor;
  if Item.HasBeforeBlurOpacity then
    Result.BeforeBlurOpacity := Item.BeforeBlurOpacity;
  if Item.HasAfterBlurOpacity then
    Result.AfterBlurOpacity := Item.AfterBlurOpacity;
  if Item.HasOutlineEnabled then
    Result.OutlineEnabled := Item.OutlineEnabled;
  if Item.HasOutlineWidth then Result.OutlineWidth := Item.OutlineWidth;
  if Item.HasOutlineBlur then Result.OutlineBlur := Item.OutlineBlur;
  if Item.HasShadowEnabled then Result.ShadowEnabled := Item.ShadowEnabled;
  if Item.HasShadowOffsetX then
    Result.ShadowOffsetX := Item.ShadowOffsetX;
  if Item.HasShadowOffsetY then
    Result.ShadowOffsetY := Item.ShadowOffsetY;
  if Item.HasShadowBlur then Result.ShadowBlur := Item.ShadowBlur;
  if Item.HasShadowSpread then Result.ShadowSpread := Item.ShadowSpread;
end;

procedure TFormLyricsCharacterLayoutSettings.ApplyDecorationOverrides(
  Index: Integer; const Settings: TDisplayCommonSettings);
var
  Item: TDisplayPlacementItem;
begin
  if (Index < 0) or (Index >= Length(FPlacements)) then
    Exit;
  Item := FPlacements[Index];
  Item.BeforeColor := Settings.BeforeColor;
  Item.HasBeforeColor := Settings.BeforeColor <> FCommonSettings.BeforeColor;
  Item.AfterColor := Settings.AfterColor;
  Item.HasAfterColor := Settings.AfterColor <> FCommonSettings.AfterColor;
  Item.BeforeOpacity := Settings.BeforeOpacity;
  Item.HasBeforeOpacity :=
    Settings.BeforeOpacity <> FCommonSettings.BeforeOpacity;
  Item.AfterOpacity := Settings.AfterOpacity;
  Item.HasAfterOpacity :=
    Settings.AfterOpacity <> FCommonSettings.AfterOpacity;
  Item.BeforeOutlineColor := Settings.BeforeOutlineColor;
  Item.HasBeforeOutlineColor :=
    Settings.BeforeOutlineColor <> FCommonSettings.BeforeOutlineColor;
  Item.AfterOutlineColor := Settings.AfterOutlineColor;
  Item.HasAfterOutlineColor :=
    Settings.AfterOutlineColor <> FCommonSettings.AfterOutlineColor;
  Item.BeforeOutlineOpacity := Settings.BeforeOutlineOpacity;
  Item.HasBeforeOutlineOpacity :=
    Settings.BeforeOutlineOpacity <> FCommonSettings.BeforeOutlineOpacity;
  Item.AfterOutlineOpacity := Settings.AfterOutlineOpacity;
  Item.HasAfterOutlineOpacity :=
    Settings.AfterOutlineOpacity <> FCommonSettings.AfterOutlineOpacity;
  Item.BeforeShadowColor := Settings.BeforeShadowColor;
  Item.HasBeforeShadowColor :=
    Settings.BeforeShadowColor <> FCommonSettings.BeforeShadowColor;
  Item.AfterShadowColor := Settings.AfterShadowColor;
  Item.HasAfterShadowColor :=
    Settings.AfterShadowColor <> FCommonSettings.AfterShadowColor;
  Item.BeforeShadowOpacity := Settings.BeforeShadowOpacity;
  Item.HasBeforeShadowOpacity :=
    Settings.BeforeShadowOpacity <> FCommonSettings.BeforeShadowOpacity;
  Item.AfterShadowOpacity := Settings.AfterShadowOpacity;
  Item.HasAfterShadowOpacity :=
    Settings.AfterShadowOpacity <> FCommonSettings.AfterShadowOpacity;
  Item.BeforeBlurColor := Settings.BeforeBlurColor;
  Item.HasBeforeBlurColor :=
    Settings.BeforeBlurColor <> FCommonSettings.BeforeBlurColor;
  Item.AfterBlurColor := Settings.AfterBlurColor;
  Item.HasAfterBlurColor :=
    Settings.AfterBlurColor <> FCommonSettings.AfterBlurColor;
  Item.BeforeBlurOpacity := Settings.BeforeBlurOpacity;
  Item.HasBeforeBlurOpacity :=
    Settings.BeforeBlurOpacity <> FCommonSettings.BeforeBlurOpacity;
  Item.AfterBlurOpacity := Settings.AfterBlurOpacity;
  Item.HasAfterBlurOpacity :=
    Settings.AfterBlurOpacity <> FCommonSettings.AfterBlurOpacity;
  Item.OutlineEnabled := Settings.OutlineEnabled;
  Item.HasOutlineEnabled :=
    Settings.OutlineEnabled <> FCommonSettings.OutlineEnabled;
  Item.OutlineWidth := Settings.OutlineWidth;
  Item.HasOutlineWidth :=
    Abs(Settings.OutlineWidth - FCommonSettings.OutlineWidth) > 0.0001;
  Item.OutlineBlur := Settings.OutlineBlur;
  Item.HasOutlineBlur :=
    Abs(Settings.OutlineBlur - FCommonSettings.OutlineBlur) > 0.0001;
  Item.ShadowEnabled := Settings.ShadowEnabled;
  Item.HasShadowEnabled :=
    Settings.ShadowEnabled <> FCommonSettings.ShadowEnabled;
  Item.ShadowOffsetX := Settings.ShadowOffsetX;
  Item.HasShadowOffsetX :=
    Abs(Settings.ShadowOffsetX - FCommonSettings.ShadowOffsetX) > 0.0001;
  Item.ShadowOffsetY := Settings.ShadowOffsetY;
  Item.HasShadowOffsetY :=
    Abs(Settings.ShadowOffsetY - FCommonSettings.ShadowOffsetY) > 0.0001;
  Item.ShadowBlur := Settings.ShadowBlur;
  Item.HasShadowBlur :=
    Abs(Settings.ShadowBlur - FCommonSettings.ShadowBlur) > 0.0001;
  Item.ShadowSpread := Settings.ShadowSpread;
  Item.HasShadowSpread :=
    Abs(Settings.ShadowSpread - FCommonSettings.ShadowSpread) > 0.0001;
  FPlacements[Index] := Item;
end;

procedure TFormLyricsCharacterLayoutSettings.EditSelectedDecoration;
var
  DecorationForm: TFormLyricsLineDisplaySettings;
  I: Integer;
  Settings: TDisplayCommonSettings;
begin
  if SelectionCount = 0 then
    Exit;
  Settings := ResolvedDecorationSettings(FSelectedIndex);
  DecorationForm := TFormLyricsLineDisplaySettings.Create(Self);
  try
    DecorationForm.Caption := '選択要素の装飾';
    if (Length(FBackgroundPixels) > 0) and
      (FBackgroundPixelWidth > 0) and
      (FBackgroundPixelHeight > 0) then
      DecorationForm.SetBackgroundRgba(FBackgroundPixels,
        FBackgroundPixelWidth, FBackgroundPixelHeight);
    DecorationForm.Configure(DisplayUnitBaseText(FSelectedIndex), Settings);
    DecorationForm.ConfigurePlacementMode(1);
    DecorationForm.SetPlacementModeSwitchVisible(False);
    if DecorationForm.ShowModal <> mrOk then
      Exit;
    Settings := DecorationForm.SelectedCommonSettings;
  finally
    DecorationForm.Free;
  end;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
      ApplyDecorationOverrides(I, Settings);
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.EditCommonSettings;
var
  CommonForm: TFormLyricsLineDisplaySettings;
begin
  CommonForm := TFormLyricsLineDisplaySettings.Create(Self);
  try
    CommonForm.Caption := '行共通設定';
    if (Length(FBackgroundPixels) > 0) and
      (FBackgroundPixelWidth > 0) and
      (FBackgroundPixelHeight > 0) then
      CommonForm.SetBackgroundRgba(FBackgroundPixels,
        FBackgroundPixelWidth, FBackgroundPixelHeight);
    CommonForm.Configure(FLyrics, FCommonSettings);
    if CommonForm.ShowModal <> mrOk then
      Exit;
    FCommonSettings := CommonForm.SelectedCommonSettings;
    FBaseFontName := FCommonSettings.BaseFontName;
    FRubyFontName := FCommonSettings.RubyFontName;
    FBaseFontHeight := Max(1, FCommonSettings.BaseFontHeight);
    FRubyFontHeight := Max(1, FCommonSettings.RubyFontHeight);
    FBaseFontStyle := FCommonSettings.BaseFontStyle and $0F;
    FRubyFontStyle := FCommonSettings.RubyFontStyle and $0F;
    FBeforeColor := TColor(FCommonSettings.BeforeColor);
    FAfterColor := TColor(FCommonSettings.AfterColor);
    FRubyGap := EnsureRange(4 + FCommonSettings.RubyGapAdjustment,
      -1024, 1024);
  finally
    CommonForm.Free;
  end;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.PopulateElementList;
var
  BaseText: string;
  I: Integer;
  Item: TListItem;
  RubyText: string;
begin
  FUpdatingElementList := True;
  ElementListView.Items.BeginUpdate;
  try
    ElementListView.Items.Clear;
    for I := 0 to High(FUnits) do
    begin
      BaseText := DisplayUnitBaseText(I);
      RubyText := DisplayUnitRubyText(I);
      Item := ElementListView.Items.Add;
      Item.Caption := IntToStr(I + 1);
      if RubyText <> '' then
        Item.SubItems.Add(Format('[%s](%s)', [BaseText, RubyText]))
      else
        Item.SubItems.Add(BaseText);
    end;
  finally
    ElementListView.Items.EndUpdate;
    FUpdatingElementList := False;
  end;
  UpdateElementListSelection;
end;

procedure TFormLyricsCharacterLayoutSettings.ElementListViewSelectItem(
  Sender: TObject; Item: TListItem; Selected: Boolean);
var
  I: Integer;
begin
  if FUpdatingElementList then
    Exit;
  ClearSelection;
  for I := 0 to ElementListView.Items.Count - 1 do
    if ElementListView.Items[I].Selected and
      (I < Length(FSelected)) then
    begin
      FSelected[I] := True;
      FSelectedIndex := I;
    end;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.SelectOnly(Index: Integer);
begin
  ClearSelection;
  if (Index >= 0) and (Index < Length(FSelected)) then
  begin
    FSelected[Index] := True;
    FSelectedIndex := Index;
  end;
end;

function TFormLyricsCharacterLayoutSettings.SelectionCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
      Inc(Result);
end;

function TFormLyricsCharacterLayoutSettings.SelectionSupportsRubyMode:
  Boolean;
var
  I: Integer;
begin
  Result := SelectionCount > 0;
  if not Result then
    Exit;
  for I := 0 to High(FSelected) do
    if FSelected[I] and (DisplayUnitRubyText(I) = '') then
      Exit(False);
end;

function TFormLyricsCharacterLayoutSettings.BackgroundDestinationRect: TRect;
var
  DrawHeight: Integer;
  DrawWidth: Integer;
  Scale: Double;
begin
  Result := BackgroundPaintBox.ClientRect;
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  Scale := Min(BackgroundPaintBox.ClientWidth / FBackground.Width,
    BackgroundPaintBox.ClientHeight / FBackground.Height) * FViewZoom;
  DrawWidth := Max(1, Round(FBackground.Width * Scale));
  DrawHeight := Max(1, Round(FBackground.Height * Scale));
  Result.Left := (BackgroundPaintBox.ClientWidth - DrawWidth) div 2 +
    Round(FViewPan.X);
  Result.Top := (BackgroundPaintBox.ClientHeight - DrawHeight) div 2 +
    Round(FViewPan.Y);
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

function TFormLyricsCharacterLayoutSettings.BackgroundScale: Double;
var
  Destination: TRect;
begin
  Result := 0;
  if FBackground.Width <= 0 then
    Exit;
  Destination := BackgroundDestinationRect;
  Result := Destination.Width / FBackground.Width;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitBaseText(
  Index: Integer): string;
begin
  Result := Copy(FPlainText, FUnits[Index].BaseStart,
    FUnits[Index].BaseLength);
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitBaseFontName(
  Index: Integer): string;
begin
  Result := FPlacements[Index].BaseFontName;
  if Result = '' then
    Result := FBaseFontName;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitBaseFontHeight(
  Index: Integer): Integer;
begin
  Result := FBaseFontHeight;
  if FPlacements[Index].HasBaseFontHeight then
    Result := FPlacements[Index].BaseFontHeight;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitBaseFontStyle(
  Index: Integer): Byte;
begin
  Result := FBaseFontStyle;
  if FPlacements[Index].HasBaseFontStyle then
    Result := FPlacements[Index].BaseFontStyle;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitBeforeColor(
  Index: Integer): TColor;
begin
  Result := FBeforeColor;
  if FPlacements[Index].HasBeforeColor then
    Result := TColor(FPlacements[Index].BeforeColor);
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitRubyText(
  Index: Integer): string;
var
  RubyIndex: Integer;
begin
  Result := '';
  RubyIndex := FUnits[Index].RubyIndex;
  if (RubyIndex >= 0) and (RubyIndex < Length(FRubySpans)) then
    Result := FRubySpans[RubyIndex].RubyText;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitRubyFontName(
  Index: Integer): string;
begin
  Result := FPlacements[Index].RubyFontName;
  if Result = '' then
    Result := FRubyFontName;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitRubyFontHeight(
  Index: Integer): Integer;
begin
  Result := FRubyFontHeight;
  if FPlacements[Index].HasRubyFontHeight then
    Result := FPlacements[Index].RubyFontHeight;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitRubyFontStyle(
  Index: Integer): Byte;
begin
  Result := FRubyFontStyle;
  if FPlacements[Index].HasRubyFontStyle then
    Result := FPlacements[Index].RubyFontStyle;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitBaseCharacterSpacing(
  Index: Integer): Integer;
begin
  Result := 0;
  if FPlacements[Index].HasBaseCharacterSpacing then
    Result := FPlacements[Index].BaseCharacterSpacing;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitRubyCharacterSpacing(
  Index: Integer): Integer;
begin
  Result := 0;
  if FPlacements[Index].HasRubyCharacterSpacing then
    Result := FPlacements[Index].RubyCharacterSpacing;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitRubyOffsetX(
  Index: Integer): Integer;
begin
  Result := 0;
  if FPlacements[Index].HasRubyOffsetX then
    Result := FPlacements[Index].RubyOffsetX;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitRubyOffsetY(
  Index: Integer): Integer;
begin
  Result := 0;
  if FPlacements[Index].HasRubyOffsetY then
    Result := FPlacements[Index].RubyOffsetY;
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitAfterColor(
  Index: Integer): TColor;
begin
  Result := FAfterColor;
  if FPlacements[Index].HasAfterColor then
    Result := TColor(FPlacements[Index].AfterColor);
end;

function TFormLyricsCharacterLayoutSettings.ScenePointToScreen(
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

function TFormLyricsCharacterLayoutSettings.DisplayUnitBounds(
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

function TFormLyricsCharacterLayoutSettings.DisplayUnitNaturalBounds(
  Index: Integer): TRectF;
var
  BaseSize: TSize;
  RubySize: TSize;
begin
  BackgroundPaintBox.Canvas.Font.Name := DisplayUnitBaseFontName(Index);
  BackgroundPaintBox.Canvas.Font.Height :=
    -Max(1, DisplayUnitBaseFontHeight(Index));
  BackgroundPaintBox.Canvas.Font.Style :=
    FontStyleByteToSet(DisplayUnitBaseFontStyle(Index));
  SetTextCharacterExtra(BackgroundPaintBox.Canvas.Handle,
    DisplayUnitBaseCharacterSpacing(Index));
  BaseSize := MeasureVisibleCanvasText(BackgroundPaintBox.Canvas,
    DisplayUnitBaseText(Index));
  RubySize.cx := 0;
  RubySize.cy := 0;
  if DisplayUnitRubyText(Index) <> '' then
  begin
    BackgroundPaintBox.Canvas.Font.Name := DisplayUnitRubyFontName(Index);
    BackgroundPaintBox.Canvas.Font.Height :=
      -Max(1, DisplayUnitRubyFontHeight(Index));
    BackgroundPaintBox.Canvas.Font.Style :=
      FontStyleByteToSet(DisplayUnitRubyFontStyle(Index));
    SetTextCharacterExtra(BackgroundPaintBox.Canvas.Handle,
      DisplayUnitRubyCharacterSpacing(Index));
    RubySize := MeasureVisibleCanvasText(BackgroundPaintBox.Canvas,
      DisplayUnitRubyText(Index));
  end;
  SetTextCharacterExtra(BackgroundPaintBox.Canvas.Handle, 0);
  Result.Left := -Max(8, BaseSize.cx) * 0.5;
  Result.Right := Max(8, BaseSize.cx) * 0.5;
  Result.Top := -BaseSize.cy * 0.5;
  if RubySize.cy > 0 then
  begin
    Result.Left := Min(Result.Left, -RubySize.cx * 0.5 +
      DisplayUnitRubyOffsetX(Index));
    Result.Right := Max(Result.Right, RubySize.cx * 0.5 +
      DisplayUnitRubyOffsetX(Index));
    Result.Top := Min(Result.Top, -BaseSize.cy * 0.5 -
      RubySize.cy - FRubyGap + DisplayUnitRubyOffsetY(Index));
  end;
  Result.Bottom := -BaseSize.cy * 0.5 + BaseSize.cy;
  if RubySize.cy > 0 then
    Result.Bottom := Max(Result.Bottom, -BaseSize.cy * 0.5 -
      FRubyGap + DisplayUnitRubyOffsetY(Index));
end;

function TFormLyricsCharacterLayoutSettings.DisplayUnitSceneBounds(
  Index: Integer): TRectF;
var
  Natural: TRectF;
begin
  Natural := DisplayUnitNaturalBounds(Index);
  Result.Left := FPlacements[Index].X +
    Natural.Left * FPlacements[Index].ScaleX;
  Result.Right := FPlacements[Index].X +
    Natural.Right * FPlacements[Index].ScaleX;
  Result.Top := FPlacements[Index].Y +
    Natural.Top * FPlacements[Index].ScaleY;
  Result.Bottom := FPlacements[Index].Y +
    Natural.Bottom * FPlacements[Index].ScaleY;
end;

function TFormLyricsCharacterLayoutSettings.RenderDisplayUnitTextImage(
  Index: Integer; const Text: string; Ruby, AfterPhase: Boolean):
  TTextRenderImage;
var
  BlurColor: Cardinal;
  BlurOpacity: Byte;
  Decoration: TDisplayCommonSettings;
  FillColor: TColor;
  FillOpacity: Byte;
  Metrics: TTextRenderMetrics;
  OutlineColor: Cardinal;
  OutlineOpacity: Byte;
  Request: TTextRenderRequest;
  Shadow: TTextRenderShadow;
  ShadowColor: Cardinal;
  ShadowOpacity: Byte;

  function AlphaColor(Color: Cardinal; Opacity: Byte): TAlphaColor;
  var
    Resolved: TColor;
  begin
    Resolved := ColorToRGB(TColor(Color));
    Result := TAlphaColor((Cardinal(Opacity) shl 24) or
      (Cardinal(GetRValue(Resolved)) shl 16) or
      (Cardinal(GetGValue(Resolved)) shl 8) or
      Cardinal(GetBValue(Resolved)));
  end;

begin
  Result := nil;
  if (FPreviewRenderer = nil) or (Text = '') then
    Exit;
  Decoration := ResolvedDecorationSettings(Index);
  Request := TTextRenderRequest.Default;
  Request.Text := Text;
  if Ruby then
  begin
    Request.FontFamilies := [DisplayUnitRubyFontName(Index),
      'Yu Gothic UI', 'Meiryo UI', 'Segoe UI'];
    Request.FontSize := Max(1, DisplayUnitRubyFontHeight(Index));
    Request.FontStyle := [];
    if (DisplayUnitRubyFontStyle(Index) and 1) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Bold);
    if (DisplayUnitRubyFontStyle(Index) and 2) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Italic);
    if (DisplayUnitRubyFontStyle(Index) and 4) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Underline);
    if (DisplayUnitRubyFontStyle(Index) and 8) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.StrikeOut);
    Request.LetterSpacing := DisplayUnitRubyCharacterSpacing(Index);
  end
  else
  begin
    Request.FontFamilies := [DisplayUnitBaseFontName(Index),
      'Yu Gothic UI', 'Meiryo UI', 'Segoe UI'];
    Request.FontSize := Max(1, DisplayUnitBaseFontHeight(Index));
    Request.FontStyle := [];
    if (DisplayUnitBaseFontStyle(Index) and 1) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Bold);
    if (DisplayUnitBaseFontStyle(Index) and 2) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Italic);
    if (DisplayUnitBaseFontStyle(Index) and 4) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.Underline);
    if (DisplayUnitBaseFontStyle(Index) and 8) <> 0 then
      Include(Request.FontStyle, TTextRenderFontStyleItem.StrikeOut);
    Request.LetterSpacing := DisplayUnitBaseCharacterSpacing(Index);
  end;
  if AfterPhase then
  begin
    FillColor := DisplayUnitAfterColor(Index);
    FillOpacity := Decoration.AfterOpacity;
    OutlineColor := Decoration.AfterOutlineColor;
    OutlineOpacity := Decoration.AfterOutlineOpacity;
    ShadowColor := Decoration.AfterShadowColor;
    ShadowOpacity := Decoration.AfterShadowOpacity;
    BlurColor := Decoration.AfterBlurColor;
    BlurOpacity := Decoration.AfterBlurOpacity;
  end
  else
  begin
    FillColor := DisplayUnitBeforeColor(Index);
    FillOpacity := Decoration.BeforeOpacity;
    OutlineColor := Decoration.BeforeOutlineColor;
    OutlineOpacity := Decoration.BeforeOutlineOpacity;
    ShadowColor := Decoration.BeforeShadowColor;
    ShadowOpacity := Decoration.BeforeShadowOpacity;
    BlurColor := Decoration.BeforeBlurColor;
    BlurOpacity := Decoration.BeforeBlurOpacity;
  end;
  Request.FillColor := AlphaColor(Cardinal(ColorToRGB(FillColor)),
    FillOpacity);
  Request.Outlines := [];
  if Decoration.OutlineEnabled and
    (Decoration.OutlineWidth > 0) then
  begin
    if Decoration.OutlineBlur <= 0 then
      Request.Outlines := [TTextRenderOutline.Create(
        Decoration.OutlineWidth,
        AlphaColor(OutlineColor, OutlineOpacity))]
    else if (BlurColor = OutlineColor) and
      (BlurOpacity = OutlineOpacity) then
      Request.Outlines := [TTextRenderOutline.Create(
        Decoration.OutlineWidth, Decoration.OutlineBlur,
        AlphaColor(OutlineColor, OutlineOpacity))]
    else
      Request.Outlines := [
        TTextRenderOutline.Create(Decoration.OutlineWidth,
          Decoration.OutlineBlur,
          AlphaColor(BlurColor, BlurOpacity)),
        TTextRenderOutline.Create(Decoration.OutlineWidth,
          AlphaColor(OutlineColor, OutlineOpacity))];
  end;
  Request.Shadows := [];
  if Decoration.ShadowEnabled then
  begin
    Shadow := System.Default(TTextRenderShadow);
    Shadow.Offset := PointF(Decoration.ShadowOffsetX,
      Decoration.ShadowOffsetY);
    Shadow.BlurRadius := Decoration.ShadowBlur;
    Shadow.SpreadRadius := Decoration.ShadowSpread;
    Shadow.Color := AlphaColor(ShadowColor, ShadowOpacity);
    Request.Shadows := [Shadow];
  end;
  Result := FPreviewRenderer.Render(Request, Metrics);
end;

function TFormLyricsCharacterLayoutSettings.CreatePreviewBitmap(
  Image: TTextRenderImage): TBitmap;
var
  Destination: PByte;
  Source: PTextRenderPixel;
  X: Integer;
  Y: Integer;
begin
  Result := nil;
  if (Image = nil) or Image.IsEmpty then
    Exit;
  Result := TBitmap.Create;
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

procedure TFormLyricsCharacterLayoutSettings.DrawDisplayUnitTextImage(
  Index: Integer; Image: TTextRenderImage; LayoutLeft, LayoutTop: Single;
  TransitionX: Integer; AfterPhase: Boolean);
var
  Bitmap: TBitmap;
  Blend: BLENDFUNCTION;
  Center: TPoint;
  DrawHeight: Integer;
  DrawLeft: Integer;
  DrawTop: Integer;
  DrawWidth: Integer;
  SavedDC: Integer;
  ScaleX: Double;
  ScaleY: Double;
begin
  Bitmap := CreatePreviewBitmap(Image);
  if Bitmap = nil then
    Exit;
  try
    Center := ScenePointToScreen(FPlacements[Index].X,
      FPlacements[Index].Y);
    ScaleX := BackgroundScale * FPlacements[Index].ScaleX;
    ScaleY := BackgroundScale * FPlacements[Index].ScaleY;
    DrawLeft := Center.X + Round((LayoutLeft + Image.Bounds.Left -
      Image.LayoutBounds.Left) * ScaleX);
    DrawTop := Center.Y + Round((LayoutTop + Image.Bounds.Top -
      Image.LayoutBounds.Top) * ScaleY);
    DrawWidth := Max(1, Round(Bitmap.Width * ScaleX));
    DrawHeight := Max(1, Round(Bitmap.Height * ScaleY));
    SavedDC := SaveDC(BackgroundPaintBox.Canvas.Handle);
    try
      if AfterPhase then
        IntersectClipRect(BackgroundPaintBox.Canvas.Handle, 0, 0,
          TransitionX, BackgroundPaintBox.ClientHeight)
      else
        IntersectClipRect(BackgroundPaintBox.Canvas.Handle, TransitionX, 0,
          BackgroundPaintBox.ClientWidth, BackgroundPaintBox.ClientHeight);
      Blend.BlendOp := AC_SRC_OVER;
      Blend.BlendFlags := 0;
      Blend.SourceConstantAlpha := 255;
      Blend.AlphaFormat := AC_SRC_ALPHA;
      Winapi.Windows.AlphaBlend(BackgroundPaintBox.Canvas.Handle,
        DrawLeft, DrawTop, DrawWidth, DrawHeight, Bitmap.Canvas.Handle,
        0, 0, Bitmap.Width, Bitmap.Height, Blend);
    finally
      RestoreDC(BackgroundPaintBox.Canvas.Handle, SavedDC);
    end;
  finally
    Bitmap.Free;
  end;
end;

procedure TFormLyricsCharacterLayoutSettings.PaintDisplayUnit(
  Index: Integer);
var
  BaseAfterImage: TTextRenderImage;
  BaseBeforeImage: TTextRenderImage;
  BaseLayoutLeft: Single;
  BaseLayoutTop: Single;
  BaseSize: TSize;
  BaseText: string;
  Bounds: TRect;
  Canvas: TCanvas;
  Center: TPoint;
  IdentityTransform: TXForm;
  RubyAfterImage: TTextRenderImage;
  RubyBeforeImage: TTextRenderImage;
  RubyLayoutLeft: Single;
  RubyLayoutTop: Single;
  RubySize: TSize;
  RubyText: string;
  Scale: Double;
  TextTop: Integer;
  WorldTransform: TXForm;

  procedure DrawOutlinedText(X, Y: Integer; const Text: string;
    TextColor: TColor);
  begin
    Canvas.Font.Color := clBlack;
    Canvas.TextOut(X - 1, Y, Text);
    Canvas.TextOut(X + 1, Y, Text);
    Canvas.TextOut(X, Y - 1, Text);
    Canvas.TextOut(X, Y + 1, Text);
    Canvas.Font.Color := TextColor;
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

  Canvas.Font.Name := DisplayUnitBaseFontName(Index);
  Canvas.Font.Height := -Max(1, DisplayUnitBaseFontHeight(Index));
  Canvas.Font.Style :=
    FontStyleByteToSet(DisplayUnitBaseFontStyle(Index));
  SetTextCharacterExtra(Canvas.Handle,
    DisplayUnitBaseCharacterSpacing(Index));
  BaseSize := MeasureVisibleCanvasText(Canvas, BaseText);
  RubySize.cx := 0;
  RubySize.cy := 0;
  if RubyText <> '' then
  begin
    Canvas.Font.Name := DisplayUnitRubyFontName(Index);
    Canvas.Font.Height := -Max(1, DisplayUnitRubyFontHeight(Index));
    Canvas.Font.Style :=
      FontStyleByteToSet(DisplayUnitRubyFontStyle(Index));
    SetTextCharacterExtra(Canvas.Handle,
      DisplayUnitRubyCharacterSpacing(Index));
    RubySize := MeasureVisibleCanvasText(Canvas, RubyText);
  end;
  SetTextCharacterExtra(Canvas.Handle, 0);
  TextTop := -BaseSize.cy div 2;
  if FPreviewRenderer <> nil then
  begin
    BaseLayoutTop := 0;
    BaseBeforeImage := nil;
    BaseAfterImage := nil;
    RubyBeforeImage := nil;
    RubyAfterImage := nil;
    try
      BaseBeforeImage := RenderDisplayUnitTextImage(Index, BaseText,
        False, False);
      BaseAfterImage := RenderDisplayUnitTextImage(Index, BaseText,
        False, True);
      if BaseBeforeImage <> nil then
      begin
        BaseLayoutLeft := -BaseBeforeImage.LayoutBounds.Width * 0.5;
        BaseLayoutTop := -BaseBeforeImage.LayoutBounds.Height * 0.5;
        DrawDisplayUnitTextImage(Index, BaseAfterImage, BaseLayoutLeft,
          BaseLayoutTop, Center.X, True);
        DrawDisplayUnitTextImage(Index, BaseBeforeImage, BaseLayoutLeft,
          BaseLayoutTop, Center.X, False);
      end;
      if RubyText <> '' then
      begin
        RubyBeforeImage := RenderDisplayUnitTextImage(Index, RubyText,
          True, False);
        RubyAfterImage := RenderDisplayUnitTextImage(Index, RubyText,
          True, True);
        if (RubyBeforeImage <> nil) and (BaseBeforeImage <> nil) then
        begin
          RubyLayoutLeft := -RubyBeforeImage.LayoutBounds.Width * 0.5 +
            DisplayUnitRubyOffsetX(Index);
          RubyLayoutTop := BaseLayoutTop -
            RubyBeforeImage.LayoutBounds.Height - FRubyGap +
            DisplayUnitRubyOffsetY(Index);
          DrawDisplayUnitTextImage(Index, RubyAfterImage, RubyLayoutLeft,
            RubyLayoutTop, Center.X, True);
          DrawDisplayUnitTextImage(Index, RubyBeforeImage, RubyLayoutLeft,
            RubyLayoutTop, Center.X, False);
        end;
      end;
    finally
      RubyAfterImage.Free;
      RubyBeforeImage.Free;
      BaseAfterImage.Free;
      BaseBeforeImage.Free;
    end;
  end
  else
  begin
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
          Canvas.Font.Name := DisplayUnitRubyFontName(Index);
          Canvas.Font.Height := -Max(1,
            DisplayUnitRubyFontHeight(Index));
          Canvas.Font.Style :=
            FontStyleByteToSet(DisplayUnitRubyFontStyle(Index));
          SetTextCharacterExtra(Canvas.Handle,
            DisplayUnitRubyCharacterSpacing(Index));
          DrawOutlinedText(-RubySize.cx div 2 +
            DisplayUnitRubyOffsetX(Index),
            TextTop - RubySize.cy - FRubyGap +
            DisplayUnitRubyOffsetY(Index), RubyText,
            DisplayUnitBeforeColor(Index));
        end;
        Canvas.Font.Name := DisplayUnitBaseFontName(Index);
        Canvas.Font.Height := -Max(1,
          DisplayUnitBaseFontHeight(Index));
        Canvas.Font.Style :=
          FontStyleByteToSet(DisplayUnitBaseFontStyle(Index));
        SetTextCharacterExtra(Canvas.Handle,
          DisplayUnitBaseCharacterSpacing(Index));
        DrawOutlinedText(-BaseSize.cx div 2, TextTop, BaseText,
          DisplayUnitBeforeColor(Index));
      end;
      finally
        FillChar(IdentityTransform, SizeOf(IdentityTransform), 0);
        IdentityTransform.eM11 := 1;
        IdentityTransform.eM22 := 1;
        SetWorldTransform(Canvas.Handle, IdentityTransform);
        SetTextCharacterExtra(Canvas.Handle, 0);
      end;
    end;
  end;

  if (Index >= 0) and (Index < Length(FSelected)) and FSelected[Index] then
  begin
    Bounds := DisplayUnitBounds(Index);
    Canvas.Brush.Style := bsClear;
    Canvas.Pen.Color := CharacterLayoutSelectionColor(FSelectionMode);
    Canvas.Pen.Width := 2;
    Canvas.Rectangle(Bounds);
    if (FSelectionMode in [clsmCharacterSpacing, clsmRuby]) and
      (SelectionCount = 1) then
      DrawCharacterLayoutSpacingHandles(Canvas, Bounds,
        FSelectionMode = clsmRuby)
    else if SelectionCount = 1 then
      DrawCharacterLayoutResizeHandles(Canvas, Bounds);
  end;
end;

function TFormLyricsCharacterLayoutSettings.GroupSelectionBounds: TRect;
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

function TFormLyricsCharacterLayoutSettings.GroupSelectionSceneBounds: TRectF;
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
      Natural := DisplayUnitSceneBounds(I);
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

procedure TFormLyricsCharacterLayoutSettings.DrawSelectionRectangle;
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

procedure TFormLyricsCharacterLayoutSettings.BackgroundPaintBoxPaint(
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
    BackgroundPaintBox.Canvas.Pen.Color :=
      CharacterLayoutSelectionColor(FSelectionMode);
    BackgroundPaintBox.Canvas.Pen.Width := 1;
    BackgroundPaintBox.Canvas.Pen.Style := psDash;
    BackgroundPaintBox.Canvas.Rectangle(Destination);
    BackgroundPaintBox.Canvas.Pen.Style := psSolid;
    if FSelectionMode in [clsmCharacterSpacing, clsmRuby] then
      DrawCharacterLayoutSpacingHandles(BackgroundPaintBox.Canvas,
        Destination, FSelectionMode = clsmRuby)
    else
      DrawCharacterLayoutResizeHandles(BackgroundPaintBox.Canvas,
        Destination);
  end;
  if FSelectingRectangle then
    DrawSelectionRectangle;
end;

function TFormLyricsCharacterLayoutSettings.HitTestDisplayUnit(
  X, Y: Integer): Integer;
var
  I: Integer;
begin
  for I := Min(High(FUnits), High(FPlacements)) downto 0 do
    if PtInRect(DisplayUnitBounds(I), Point(X, Y)) then
      Exit(I);
  Result := -1;
end;

function TFormLyricsCharacterLayoutSettings.HitTestModeHandle(
  X, Y: Integer): TCharacterLayoutDragMode;
var
  Bounds: TRect;
begin
  Result := cldmNone;
  if (FSelectionMode = clsmTransform) or
    (FSelectedIndex < 0) or (SelectionCount = 0) then
    Exit;
  if SelectionCount = 1 then
    Bounds := DisplayUnitBounds(FSelectedIndex)
  else
    Bounds := GroupSelectionBounds;
  Result := HitTestCharacterLayoutModeHandle(
    Bounds, FSelectionMode, X, Y);
end;

function TFormLyricsCharacterLayoutSettings.HitTestResizeHandle(
  X, Y: Integer): TCharacterLayoutDragMode;
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
  Result := cldmNone;
  if (FSelectionMode <> clsmTransform) or
    (FSelectedIndex < 0) or (SelectionCount = 0) then
    Exit;
  if SelectionCount = 1 then
    Bounds := DisplayUnitBounds(FSelectedIndex)
  else
    Bounds := GroupSelectionBounds;
  CenterX := (Bounds.Left + Bounds.Right) div 2;
  CenterY := (Bounds.Top + Bounds.Bottom) div 2;
  if NearPoint(Bounds.Left, Bounds.Top) then
    Exit(cldmResizeTopLeft);
  if NearPoint(Bounds.Right, Bounds.Top) then
    Exit(cldmResizeTopRight);
  if NearPoint(Bounds.Left, Bounds.Bottom) then
    Exit(cldmResizeBottomLeft);
  if NearPoint(Bounds.Right, Bounds.Bottom) then
    Exit(cldmResizeBottomRight);
  if NearPoint(CenterX, Bounds.Top) then
    Exit(cldmResizeTop);
  if NearPoint(CenterX, Bounds.Bottom) then
    Exit(cldmResizeBottom);
  if NearPoint(Bounds.Left, CenterY) then
    Exit(cldmResizeLeft);
  if NearPoint(Bounds.Right, CenterY) then
    Exit(cldmResizeRight);
end;

procedure TFormLyricsCharacterLayoutSettings.BackgroundPaintBoxMouseDown(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  HitIndex: Integer;
  I: Integer;
begin
  FClickCandidateModeToggle := False;
  FDragChanged := False;
  if Button = mbRight then
  begin
    FSelectingRectangle := True;
    FSelectionStart := Point(X, Y);
    FSelectionCurrent := FSelectionStart;
    FDragMode := cldmNone;
    BackgroundPaintBox.Invalidate;
    Exit;
  end;
  if Button <> mbLeft then
    Exit;
  FDragMode := HitTestModeHandle(X, Y);
  if FDragMode = cldmNone then
    FDragMode := HitTestResizeHandle(X, Y);
  if FDragMode = cldmNone then
  begin
    HitIndex := HitTestDisplayUnit(X, Y);
    if ssShift in Shift then
    begin
      FSelectionMode := clsmTransform;
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
    begin
      ClearSelection;
      FDragMode := cldmPan;
      FDragStartMouse := Point(X, Y);
      FDragStartViewPan := FViewPan;
    end
    else if not FSelected[HitIndex] then
    begin
      SelectOnly(HitIndex)
    end
    else
    begin
      FSelectedIndex := HitIndex;
      FClickCandidateModeToggle := True;
    end;
    if (HitIndex >= 0) and FSelected[HitIndex] then
      case FSelectionMode of
        clsmCharacterSpacing, clsmRuby:
          FDragMode := cldmSelectionClick;
      else
        FDragMode := cldmMove;
      end;
  end;
  if FSelectedIndex >= 0 then
  begin
    FDragStartMouse := Point(X, Y);
    FDragStartPlacement := FPlacements[FSelectedIndex];
    FDragStartPlacements := Copy(FPlacements);
    FDragStartGroupBounds := GroupSelectionSceneBounds;
  end;
  UpdateElementListSelection;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.BackgroundPaintBoxMouseMove(
  Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  CharacterCounts: TArray<Integer>;
  HoverMode: TCharacterLayoutDragMode;
  I: Integer;
  Scale: Double;
begin
  if FSelectingRectangle then
  begin
    FSelectionCurrent := Point(X, Y);
    BackgroundPaintBox.Invalidate;
    Exit;
  end;
  if FDragMode = cldmPan then
  begin
    FViewPan.X := FDragStartViewPan.X + X - FDragStartMouse.X;
    FViewPan.Y := FDragStartViewPan.Y + Y - FDragStartMouse.Y;
    BackgroundPaintBox.Cursor := crSizeAll;
    BackgroundPaintBox.Invalidate;
    Exit;
  end;
  if (FDragMode = cldmNone) or (FSelectedIndex < 0) then
  begin
    if FSelectionMode in [clsmCharacterSpacing, clsmRuby] then
    begin
      HoverMode := HitTestModeHandle(X, Y);
      case HoverMode of
        cldmSpacingLeft, cldmSpacingRight:
          BackgroundPaintBox.Cursor := crSizeWE;
        cldmRubyMove:
          BackgroundPaintBox.Cursor := crSizeAll;
      else
        BackgroundPaintBox.Cursor := crDefault;
      end;
      Exit;
    end;
    HoverMode := HitTestResizeHandle(X, Y);
    case HoverMode of
      cldmResizeLeft, cldmResizeRight:
        BackgroundPaintBox.Cursor := crSizeWE;
      cldmResizeTop, cldmResizeBottom:
        BackgroundPaintBox.Cursor := crSizeNS;
      cldmResizeTopLeft, cldmResizeBottomRight:
        BackgroundPaintBox.Cursor := crSizeNWSE;
      cldmResizeTopRight, cldmResizeBottomLeft:
        BackgroundPaintBox.Cursor := crSizeNESW;
    else
      BackgroundPaintBox.Cursor := crDefault;
    end;
    Exit;
  end;
  Scale := BackgroundScale;
  if Scale <= 0 then
    Exit;
  if not FDragChanged then
  begin
    FDragChanged := (Abs(X - FDragStartMouse.X) > 3) or
      (Abs(Y - FDragStartMouse.Y) > 3);
    if not FDragChanged then
      Exit;
  end;
  if FDragMode = cldmMove then
  begin
    for I := 0 to High(FSelected) do
      if FSelected[I] then
      begin
        FPlacements[I].X := FDragStartPlacements[I].X +
          (X - FDragStartMouse.X) / Scale;
        FPlacements[I].Y := FDragStartPlacements[I].Y +
          (Y - FDragStartMouse.Y) / Scale;
      end;
  end
  else if FDragMode in [cldmSpacingLeft, cldmSpacingRight] then
  begin
    BackgroundPaintBox.Cursor := crSizeWE;
    if FSelectionMode = clsmCharacterSpacing then
    begin
      SetLength(CharacterCounts, Length(FUnits));
      for I := 0 to High(CharacterCounts) do
        CharacterCounts[I] := Length(DisplayUnitBaseText(I));
      ApplyCharacterLayoutSpacingDrag(FPlacements, FSelected,
        CharacterCounts, FDragStartPlacements, FDragMode,
        X - FDragStartMouse.X, Scale);
    end
    else
      ApplyCharacterLayoutRubySpacingDrag(FPlacements, FSelected,
        FDragStartPlacements, FDragMode,
        X - FDragStartMouse.X, Scale);
  end
  else if FDragMode = cldmRubyMove then
  begin
    BackgroundPaintBox.Cursor := crSizeAll;
    ApplyCharacterLayoutRubyMoveDrag(FPlacements, FSelected,
      FDragStartPlacements, X - FDragStartMouse.X,
      Y - FDragStartMouse.Y, Scale);
  end
  else if FDragMode <> cldmSelectionClick then
    ResizeSelectedElement(X, Y);
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.BackgroundPaintBoxMouseUp(
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
    FSelectionMode := clsmTransform;
    UpdateElementListSelection;
    UpdateSelectedSettings;
    BackgroundPaintBox.Invalidate;
    Exit;
  end;
  if Button = mbLeft then
  begin
    if FClickCandidateModeToggle and not FDragChanged then
      FSelectionMode := NextCharacterLayoutSelectionMode(
        FSelectionMode, SelectionSupportsRubyMode);
    FDragMode := cldmNone;
    FClickCandidateModeToggle := False;
    FDragChanged := False;
    BackgroundPaintBox.Cursor := crDefault;
    UpdateSelectedSettings;
    BackgroundPaintBox.Invalidate;
  end;
end;

procedure TFormLyricsCharacterLayoutSettings.BackgroundPaintBoxMouseWheel(
  Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint; var Handled: Boolean);
const
  MAX_ZOOM = 8.0;
  MIN_ZOOM = 0.25;
  ZOOM_STEP = 1.2;
var
  ClientPoint: TPoint;
  ImageX: Double;
  ImageY: Double;
  NewDestination: TRect;
  NewScale: Double;
  NewZoom: Double;
  OldDestination: TRect;
  OldScale: Double;
begin
  Handled := False;
  ClientPoint := BackgroundPaintBox.ScreenToClient(MousePos);
  if not PtInRect(BackgroundPaintBox.ClientRect, ClientPoint) then
    Exit;
  Handled := True;
  if (FBackground.Width <= 0) or (FBackground.Height <= 0) then
    Exit;
  OldDestination := BackgroundDestinationRect;
  OldScale := BackgroundScale;
  if OldScale <= 0 then
    Exit;
  ImageX := (ClientPoint.X - OldDestination.Left) / OldScale;
  ImageY := (ClientPoint.Y - OldDestination.Top) / OldScale;
  if WheelDelta > 0 then
    NewZoom := FViewZoom * ZOOM_STEP
  else
    NewZoom := FViewZoom / ZOOM_STEP;
  NewZoom := EnsureRange(NewZoom, MIN_ZOOM, MAX_ZOOM);
  if SameValue(NewZoom, FViewZoom) then
    Exit;
  FViewZoom := NewZoom;
  FViewPan := TPointF.Zero;
  NewDestination := BackgroundDestinationRect;
  NewScale := BackgroundScale;
  FViewPan.X := ClientPoint.X - ImageX * NewScale -
    NewDestination.Left;
  FViewPan.Y := ClientPoint.Y - ImageY * NewScale -
    NewDestination.Top;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.ResizeSelectedElement(
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

  if FDragMode in [cldmResizeLeft, cldmResizeTopLeft,
    cldmResizeBottomLeft] then
  begin
    NewLeft := Min(OriginalLeft + DeltaX,
      OriginalRight - Natural.Width * MIN_SCALE);
    NewScale := EnsureRange((OriginalRight - NewLeft) /
      Natural.Width, MIN_SCALE, MAX_SCALE);
    FPlacements[FSelectedIndex].ScaleX := NewScale;
    FPlacements[FSelectedIndex].X := OriginalRight -
      Natural.Right * NewScale;
  end
  else if FDragMode in [cldmResizeRight, cldmResizeTopRight,
    cldmResizeBottomRight] then
  begin
    NewRight := Max(OriginalRight + DeltaX,
      OriginalLeft + Natural.Width * MIN_SCALE);
    NewScale := EnsureRange((NewRight - OriginalLeft) /
      Natural.Width, MIN_SCALE, MAX_SCALE);
    FPlacements[FSelectedIndex].ScaleX := NewScale;
    FPlacements[FSelectedIndex].X := OriginalLeft -
      Natural.Left * NewScale;
  end;

  if FDragMode in [cldmResizeTop, cldmResizeTopLeft,
    cldmResizeTopRight] then
  begin
    NewTop := Min(OriginalTop + DeltaY,
      OriginalBottom - Natural.Height * MIN_SCALE);
    NewScale := EnsureRange((OriginalBottom - NewTop) /
      Natural.Height, MIN_SCALE, MAX_SCALE);
    FPlacements[FSelectedIndex].ScaleY := NewScale;
    FPlacements[FSelectedIndex].Y := OriginalBottom -
      Natural.Bottom * NewScale;
  end
  else if FDragMode in [cldmResizeBottom, cldmResizeBottomLeft,
    cldmResizeBottomRight] then
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

procedure TFormLyricsCharacterLayoutSettings.ResizeSelection(
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

  if FDragMode in [cldmResizeLeft, cldmResizeTopLeft,
    cldmResizeBottomLeft] then
  begin
    AnchorX := FDragStartGroupBounds.Right;
    FactorX := (FDragStartGroupBounds.Width - DeltaX) /
      FDragStartGroupBounds.Width;
  end
  else if FDragMode in [cldmResizeRight, cldmResizeTopRight,
    cldmResizeBottomRight] then
  begin
    AnchorX := FDragStartGroupBounds.Left;
    FactorX := (FDragStartGroupBounds.Width + DeltaX) /
      FDragStartGroupBounds.Width;
  end;

  if FDragMode in [cldmResizeTop, cldmResizeTopLeft,
    cldmResizeTopRight] then
  begin
    AnchorY := FDragStartGroupBounds.Bottom;
    FactorY := (FDragStartGroupBounds.Height - DeltaY) /
      FDragStartGroupBounds.Height;
  end
  else if FDragMode in [cldmResizeBottom, cldmResizeBottomLeft,
    cldmResizeBottomRight] then
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
      if FDragMode in [cldmResizeLeft, cldmResizeRight,
        cldmResizeTopLeft, cldmResizeTopRight,
        cldmResizeBottomLeft, cldmResizeBottomRight] then
      begin
        FPlacements[I].X := AnchorX +
          (FDragStartPlacements[I].X - AnchorX) * FactorX;
        FPlacements[I].ScaleX :=
          FDragStartPlacements[I].ScaleX * FactorX;
      end;
      if FDragMode in [cldmResizeTop, cldmResizeBottom,
        cldmResizeTopLeft, cldmResizeTopRight,
        cldmResizeBottomLeft, cldmResizeBottomRight] then
      begin
        FPlacements[I].Y := AnchorY +
          (FDragStartPlacements[I].Y - AnchorY) * FactorY;
        FPlacements[I].ScaleY :=
          FDragStartPlacements[I].ScaleY * FactorY;
      end;
    end;
end;

procedure TFormLyricsCharacterLayoutSettings.BuildDefaultPlacements(
  out Placements: TDisplayPlacementItems);
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
  SetLength(Placements, Length(FUnits));
  SetLength(ItemWidths, Length(FUnits));
  TotalWidth := 0;
  FBackground.Canvas.Font.Style := FontStyleByteToSet(FBaseFontStyle);
  for I := 0 to High(FUnits) do
  begin
    FBackground.Canvas.Font.Name := FBaseFontName;
    FBackground.Canvas.Font.Height := -Max(1, FBaseFontHeight);
    FBackground.Canvas.Font.Style := FontStyleByteToSet(FBaseFontStyle);
    BaseSize := FBackground.Canvas.TextExtent(DisplayUnitBaseText(I));
    RubySize.cx := 0;
    if DisplayUnitRubyText(I) <> '' then
    begin
      FBackground.Canvas.Font.Name := FRubyFontName;
      FBackground.Canvas.Font.Height := -Max(1, FRubyFontHeight);
      FBackground.Canvas.Font.Style := FontStyleByteToSet(FRubyFontStyle);
      RubySize := FBackground.Canvas.TextExtent(DisplayUnitRubyText(I));
    end;
    ItemWidths[I] := Max(BaseSize.cx, RubySize.cx);
    Inc(TotalWidth, ItemWidths[I]);
    if I > 0 then
      Inc(TotalWidth, ITEM_SPACING);
  end;

  CursorX := -TotalWidth * 0.5;
  for I := 0 to High(Placements) do
  begin
    Placements[I].Index := I;
    Placements[I].X := CursorX + ItemWidths[I] * 0.5;
    Placements[I].Y := 0;
    Placements[I].ScaleX := 1;
    Placements[I].ScaleY := 1;
    Placements[I].BaseFontName := '';
    Placements[I].RubyFontName := '';
    Placements[I].HasBeforeColor := False;
    Placements[I].BeforeColor := 0;
    Placements[I].HasAfterColor := False;
    Placements[I].AfterColor := 0;
    Placements[I].HasBaseFontHeight := False;
    Placements[I].BaseFontHeight := 0;
    Placements[I].HasRubyFontHeight := False;
    Placements[I].RubyFontHeight := 0;
    Placements[I].HasBaseFontStyle := False;
    Placements[I].BaseFontStyle := 0;
    Placements[I].HasRubyFontStyle := False;
    Placements[I].RubyFontStyle := 0;
    Placements[I].HasBaseCharacterSpacing := False;
    Placements[I].BaseCharacterSpacing := 0;
    Placements[I].HasRubyCharacterSpacing := False;
    Placements[I].RubyCharacterSpacing := 0;
    Placements[I].HasRubyOffsetX := False;
    Placements[I].RubyOffsetX := 0;
    Placements[I].HasRubyOffsetY := False;
    Placements[I].RubyOffsetY := 0;
    CursorX := CursorX + ItemWidths[I] + ITEM_SPACING;
  end;
end;

procedure TFormLyricsCharacterLayoutSettings.BuildInitialPlacements;
begin
  BuildDefaultPlacements(FPlacements);
end;

procedure TFormLyricsCharacterLayoutSettings.ButtonMoveToCenterClick(
  Sender: TObject);
var
  Bounds: TRectF;
  DeltaX: Single;
  DeltaY: Single;
  I: Integer;
begin
  if SelectionCount = 0 then
    Exit;
  Bounds := GroupSelectionSceneBounds;
  DeltaX := -(Bounds.Left + Bounds.Right) * 0.5;
  DeltaY := -(Bounds.Top + Bounds.Bottom) * 0.5;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      FPlacements[I].X := FPlacements[I].X + DeltaX;
      FPlacements[I].Y := FPlacements[I].Y + DeltaY;
    end;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.ButtonResetSelectedClick(
  Sender: TObject);
var
  Defaults: TDisplayPlacementItems;
  I: Integer;
begin
  if SelectionCount = 0 then
    Exit;
  BuildDefaultPlacements(Defaults);
  for I := 0 to High(FSelected) do
    if FSelected[I] and (I < Length(Defaults)) then
      FPlacements[I] := Defaults[I];
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.ButtonResetAllClick(
  Sender: TObject);
begin
  BuildInitialPlacements;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.ButtonAlignHorizontalClick(
  Sender: TObject);
var
  BottomSum: Double;
  Bounds: TRectF;
  Count: Integer;
  I: Integer;
  Natural: TRectF;
  TargetBottom: Double;
begin
  Count := SelectionCount;
  if Count < 2 then
    Exit;
  BottomSum := 0;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      Bounds := DisplayUnitSceneBounds(I);
      BottomSum := BottomSum + Bounds.Bottom;
    end;
  TargetBottom := BottomSum / Count;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      Natural := DisplayUnitNaturalBounds(I);
      FPlacements[I].Y := TargetBottom -
        Natural.Bottom * FPlacements[I].ScaleY;
    end;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.ButtonDistributeHorizontalClick(
  Sender: TObject);
var
  Bounds: TRectF;
  CursorX: Double;
  Gap: Double;
  I: Integer;
  J: Integer;
  SelectedIndices: TArray<Integer>;
  SelectedWidths: TArray<Double>;
  TempIndex: Integer;
  TotalWidth: Double;
begin
  if SelectionCount < 3 then
    Exit;
  SetLength(SelectedIndices, SelectionCount);
  J := 0;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      SelectedIndices[J] := I;
      Inc(J);
    end;
  for I := 0 to High(SelectedIndices) - 1 do
    for J := I + 1 to High(SelectedIndices) do
      if DisplayUnitSceneBounds(SelectedIndices[J]).Left <
        DisplayUnitSceneBounds(SelectedIndices[I]).Left then
      begin
        TempIndex := SelectedIndices[I];
        SelectedIndices[I] := SelectedIndices[J];
        SelectedIndices[J] := TempIndex;
      end;

  SetLength(SelectedWidths, Length(SelectedIndices));
  TotalWidth := 0;
  for I := 0 to High(SelectedIndices) do
  begin
    Bounds := DisplayUnitSceneBounds(SelectedIndices[I]);
    SelectedWidths[I] := Bounds.Width;
    TotalWidth := TotalWidth + Bounds.Width;
  end;
  CursorX := DisplayUnitSceneBounds(SelectedIndices[0]).Left;
  Bounds := DisplayUnitSceneBounds(
    SelectedIndices[High(SelectedIndices)]);
  Gap := (Bounds.Right - CursorX - TotalWidth) /
    (Length(SelectedIndices) - 1);
  for I := 0 to High(SelectedIndices) do
  begin
    Bounds := DisplayUnitSceneBounds(SelectedIndices[I]);
    FPlacements[SelectedIndices[I]].X :=
      FPlacements[SelectedIndices[I]].X +
      CursorX - Bounds.Left;
    CursorX := CursorX + SelectedWidths[I] + Gap;
  end;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.ButtonFontClick(
  Sender: TObject);
var
  FontForm: TFormLyricsFontSettings;
  I: Integer;
begin
  if SelectionCount = 0 then
    Exit;
  FontForm := TFormLyricsFontSettings.Create(Self);
  try
    FontForm.SelectedBaseFontName :=
      DisplayUnitBaseFontName(FSelectedIndex);
    FontForm.SelectedRubyFontName :=
      DisplayUnitRubyFontName(FSelectedIndex);
    FontForm.SelectedBaseFontStyle := FontStyleByteToSet(
      DisplayUnitBaseFontStyle(FSelectedIndex));
    FontForm.SelectedRubyFontStyle := FontStyleByteToSet(
      DisplayUnitRubyFontStyle(FSelectedIndex));
    if FontForm.ShowModal <> mrOk then
      Exit;
    for I := 0 to High(FSelected) do
      if FSelected[I] then
      begin
        if SameText(FontForm.SelectedBaseFontName,
          FBaseFontName) then
          FPlacements[I].BaseFontName := ''
        else
          FPlacements[I].BaseFontName :=
            FontForm.SelectedBaseFontName;
        if SameText(FontForm.SelectedRubyFontName,
          FRubyFontName) then
          FPlacements[I].RubyFontName := ''
        else
          FPlacements[I].RubyFontName :=
            FontForm.SelectedRubyFontName;
        FPlacements[I].BaseFontStyle := FontStyleSetToByte(
          FontForm.SelectedBaseFontStyle);
        FPlacements[I].HasBaseFontStyle :=
          FPlacements[I].BaseFontStyle <> FBaseFontStyle;
        FPlacements[I].RubyFontStyle := FontStyleSetToByte(
          FontForm.SelectedRubyFontStyle);
        FPlacements[I].HasRubyFontStyle :=
          FPlacements[I].RubyFontStyle <> FRubyFontStyle;
      end;
  finally
    FontForm.Free;
  end;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.ButtonBeforeColorClick(
  Sender: TObject);
var
  Color: TColor;
  I: Integer;
begin
  if SelectionCount = 0 then
    Exit;
  Color := DisplayUnitBeforeColor(FSelectedIndex);
  if not ExecuteColorPicker(Self, Color) then
    Exit;
  Color := ColorToRGB(Color);
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      FPlacements[I].HasBeforeColor :=
        Cardinal(Color) <> Cardinal(ColorToRGB(FBeforeColor));
      FPlacements[I].BeforeColor := Cardinal(Color) and $FFFFFF;
    end;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.ButtonAfterColorClick(
  Sender: TObject);
var
  Color: TColor;
  I: Integer;
begin
  if SelectionCount = 0 then
    Exit;
  Color := DisplayUnitAfterColor(FSelectedIndex);
  if not ExecuteColorPicker(Self, Color) then
    Exit;
  Color := ColorToRGB(Color);
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      FPlacements[I].HasAfterColor :=
        Cardinal(Color) <> Cardinal(ColorToRGB(FAfterColor));
      FPlacements[I].AfterColor := Cardinal(Color) and $FFFFFF;
    end;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.Configure(
  const Lyrics: string; const CommonSettings: TDisplayCommonSettings;
  const SettingsText: string);
var
  DecodedCommon: TDisplayCommonSettings;
  DecodedPlacements: TDisplayPlacementItems;
  PlacementsMatchLyrics: Boolean;
begin
  FLyrics := Lyrics;
  FCommonSettings := CommonSettings;
  FBaseFontName := CommonSettings.BaseFontName;
  FRubyFontName := CommonSettings.RubyFontName;
  FBaseFontHeight := Max(1, CommonSettings.BaseFontHeight);
  FRubyFontHeight := Max(1, CommonSettings.RubyFontHeight);
  FBeforeColor := TColor(CommonSettings.BeforeColor);
  FAfterColor := TColor(CommonSettings.AfterColor);
  FBaseFontStyle := CommonSettings.BaseFontStyle and $0F;
  FRubyFontStyle := CommonSettings.RubyFontStyle and $0F;
  FRubyGap := EnsureRange(4 + CommonSettings.RubyGapAdjustment,
    -1024, 1024);
  ParseLyrics(FLyrics, FPlainText, FRubySpans);
  BuildLyricsDisplayUnits(FPlainText, FRubySpans, FUnits);
  PlacementsMatchLyrics := False;
  if not TryDecodeDisplaySettingsText(SettingsText, FLyrics,
    DecodedCommon, DecodedPlacements, PlacementsMatchLyrics) or
    not PlacementsMatchLyrics or
    (Length(DecodedPlacements) <> Length(FUnits)) then
    BuildInitialPlacements;
  if PlacementsMatchLyrics and
    (Length(DecodedPlacements) = Length(FUnits)) then
    FPlacements := DecodedPlacements;
  SetLength(FSelected, Length(FUnits));
  ClearSelection;
  PopulateElementList;
  UpdateSelectedSettings;
  BackgroundPaintBox.Invalidate;
end;

procedure TFormLyricsCharacterLayoutSettings.ConfigureCandidates(
  const Captions, Lyrics: TArray<string>;
  const CommonSettings: TArray<TDisplayCommonSettings>;
  const SettingsText: TArray<string>; InitialIndex: Integer);
var
  I: Integer;
begin
  FCandidateLyrics := Copy(Lyrics);
  FCandidateSettings := Copy(CommonSettings);
  FCandidateSettingsText := Copy(SettingsText);
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
  if CandidateCombo.Items.Count = 0 then
    Exit;
  CandidateCombo.ItemIndex := EnsureRange(InitialIndex, 0,
    CandidateCombo.Items.Count - 1);
  CandidateComboChange(CandidateCombo);
end;

procedure TFormLyricsCharacterLayoutSettings.ConfigurePlacementMode(
  PlacementMode: Integer);
begin
  PlacementModeCombo.ItemIndex := EnsureRange(PlacementMode, 0, 1);
  if FPlacementModeButton <> nil then
  begin
    FPlacementModeButton.Glyph := tbgLinePlacement;
    FPlacementModeButton.Hint := '1行配置へ切替';
  end;
end;

procedure TFormLyricsCharacterLayoutSettings.SetPlacementModeSwitchVisible(
  Value: Boolean);
begin
  if FPlacementModeButton <> nil then
    FPlacementModeButton.Visible := Value;
end;

procedure TFormLyricsCharacterLayoutSettings.CandidateComboChange(
  Sender: TObject);
var
  Index: Integer;
begin
  Index := CandidateCombo.ItemIndex;
  if (Index < 0) or (Index >= Length(FCandidateLyrics)) or
    (Index >= Length(FCandidateSettings)) or
    (Index >= Length(FCandidateSettingsText)) then
    Exit;
  Configure(FCandidateLyrics[Index], FCandidateSettings[Index],
    FCandidateSettingsText[Index]);
end;

procedure TFormLyricsCharacterLayoutSettings.SetBackgroundRgba(
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

  FBackgroundPixels := Copy(Pixels);
  FBackgroundPixelWidth := Width;
  FBackgroundPixelHeight := Height;
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

procedure TFormLyricsCharacterLayoutSettings.SetCaptureStatus(
  const Value: string);
begin
  DescriptionLabel.Caption := Value;
end;

function TFormLyricsCharacterLayoutSettings.TryBuildSettingsText(
  out SettingsText: string): Boolean;
begin
  Result := TryEncodeDisplaySettingsText(FLyrics, FCommonSettings,
    FPlacements, SettingsText);
end;

function TFormLyricsCharacterLayoutSettings.SelectedCandidateIndex:
  Integer;
begin
  Result := CandidateCombo.ItemIndex;
end;

function TFormLyricsCharacterLayoutSettings.SelectedPlacementMode: Integer;
begin
  Result := EnsureRange(PlacementModeCombo.ItemIndex, 0, 1);
end;

end.
