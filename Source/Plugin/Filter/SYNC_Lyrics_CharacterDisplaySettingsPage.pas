unit SYNC_Lyrics_CharacterDisplaySettingsPage;

// Display-only first migration page for per-character free placement.

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  SYNC_Lyrics_DisplaySettingsColorPanel,
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_CharacterLayoutInteraction,
  SYNC_Lyrics_DisplayPreviewBackground,
  SYNC_Lyrics_DisplaySettingsModePage,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_ToolbarButtons;

type
  TDisplayPlacementItemArray = TArray<TDisplayPlacementItems>;
  TBooleanArray = TArray<Boolean>;
  TBooleanArrayArray = TArray<TBooleanArray>;

  TFrameLyricsCharacterDisplaySettingsPage = class(
    TFrameDisplaySettingsModePage)
  private
    FActionToolbar: TSyncLyricsToolbarButtons;
    FBackground: TDisplayPreviewBackground;
    FBackgroundPixels: TBytes;
    FBackgroundPixelWidth: Integer;
    FBackgroundPixelHeight: Integer;
    FBaseFontCombo: TComboBox;
    FBaseFontLabel: TLabel;
    FColorPanel: TDisplaySettingsColorPanel;
    FElementCombo: TComboBox;
    FElementLabel: TLabel;
    FFormattingToolbar: TSyncLyricsToolbarButtons;
    FCandidateCommon: TArray<TDisplayCommonSettings>;
    FCandidateLyrics: TArray<string>;
    FCandidatePlacements: TDisplayPlacementItemArray;
    FCandidateSelected: TBooleanArrayArray;
    FCandidateSelections: TArray<Integer>;
    FInitialCandidate: Integer;
    FInitialCandidateCommon: TArray<TDisplayCommonSettings>;
    FInitialCandidateLyrics: TArray<string>;
    FInitialCandidatePlacements: TDisplayPlacementItemArray;
    FInitialCandidateSelected: TBooleanArrayArray;
    FInitialCandidateSelections: TArray<Integer>;
    FCurrentCandidate: Integer;
    FCurrentCommon: TDisplayCommonSettings;
    FCurrentLyrics: string;
    FCurrentPlacements: TDisplayPlacementItems;
    FDragMode: TCharacterLayoutDragMode;
    FClickCandidateModeToggle: Boolean;
    FDragChanged: Boolean;
    FDragStartMouse: TPoint;
    FDragStartElementBounds: TArray<TRect>;
    FDragStartPlacements: TDisplayPlacementItems;
    FDragStartGroupBounds: TRect;
    FDragStartViewPan: TPointF;
    FPlainText: string;
    FRubySpans: TLyricsRubySpans;
    FSelected: TBooleanArray;
    FSelectingRectangle: Boolean;
    FSelectionCurrent: TPoint;
    FSelectionMode: TCharacterLayoutSelectionMode;
    FSelectionStart: TPoint;
    FUnits: TLyricsDisplayUnits;
    FUpdatingElementCombo: Boolean;
    FUpdatingControls: Boolean;
    FLayoutReady: Boolean;
    FPreview: TPaintBox;
    FViewPan: TPointF;
    FViewZoom: Double;
    FRubyFontCombo: TComboBox;
    FRubyFontLabel: TLabel;
    procedure ComboDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure FontComboChange(Sender: TObject);
    procedure FormattingToolbarExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure ColorPanelChange(Sender: TObject);
    procedure ColorTargetChange(Sender: TObject);
    procedure ActionToolbarExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure BuildDefaultPlacements;
    procedure EditSelectedDecoration;
    function DisplayUnitBaseText(Index: Integer): string;
    function DisplayUnitRubyText(Index: Integer): string;
    function GroupSelectionBounds: TRect;
    function HitTestModeHandle(X, Y: Integer):
      TCharacterLayoutDragMode;
    function HitTestResizeHandle(X, Y: Integer):
      TCharacterLayoutDragMode;
    procedure ElementComboChange(Sender: TObject);
    procedure LoadCandidate(Index: Integer);
    procedure PopulateElementCombo;
    function PreviewScale: Double;
    function PreviewDestinationRect: TRect;
    procedure PreviewMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PreviewMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure PreviewMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PreviewMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure PreviewPaint(Sender: TObject);
    procedure ResizeSelection(X, Y: Integer);
    procedure SelectElement(Index: Integer; Toggle: Boolean = False);
    function SelectionCount: Integer;
    function SelectionSupportsRubyMode: Boolean;
    procedure StoreCurrentCandidate;
    procedure UpdateSelectedControls;
    procedure UpdateElementComboSelection;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AdjustPreviewZoom(WheelDelta: Integer;
      const ClientPoint: TPoint);
    procedure CaptureInitialState; override;
    procedure CandidateChanged(Index: Integer); override;
    procedure ConfigureCandidates(const Lyrics: TArray<string>;
      const CommonSettings: TArray<TDisplayCommonSettings>;
      const SettingsTexts: TArray<string>; InitialIndex: Integer);
    function ElementCount: Integer;
    function ElementPlacement(Index: Integer): TDisplayPlacementItem;
    function ModeGlyph: TSyncLyricsToolbarGlyph; override;
    function ModeID: Integer; override;
    function ModeName: string; override;
    function HasBackgroundImage: Boolean;
    function PreviewElementBounds(Index: Integer): TRect;
    function SelectedElementCount: Integer;
    function SelectedElementIndex: Integer;
    function SelectedMode: TCharacterLayoutSelectionMode;
    function SelectedDecorationSettings: TDisplayCommonSettings;
    procedure ApplySelectedDecoration(
      const Settings: TDisplayCommonSettings);
    function TryBuildCandidateSettingsTexts(
      out SettingsTexts: TArray<string>): Boolean;
    function ViewPan: TPointF;
    function ViewZoom: Double;
    function SelectedLyrics: string;
    procedure RestoreInitialState; override;
    procedure SetBackgroundRgba(const Pixels: TBytes;
      Width, Height: Integer);
    property ColorPanel: TDisplaySettingsColorPanel read FColorPanel;
    property BaseFontCombo: TComboBox read FBaseFontCombo;
    property RubyFontCombo: TComboBox read FRubyFontCombo;
    property ActionToolbar: TSyncLyricsToolbarButtons read FActionToolbar;
    property ElementCombo: TComboBox read FElementCombo;
    property FormattingToolbar: TSyncLyricsToolbarButtons
      read FFormattingToolbar;
    property Preview: TPaintBox read FPreview;
  end;

implementation

{$R *.dfm}

uses
  System.Math,
  Winapi.Windows,
  Vcl.Graphics,
  SYNC_Lyrics_CharacterLayoutDrawing,
  SYNC_Lyrics_DarkTheme,
  SYNC_Lyrics_LineDisplaySettingsForm;

type
  TCharacterDisplayPageControlAccess = class(TControl);

function CharacterFontStyle(Value: Byte): TFontStyles;
begin
  Result := [];
  if (Value and 1) <> 0 then Include(Result, fsBold);
  if (Value and 2) <> 0 then Include(Result, fsItalic);
  if (Value and 4) <> 0 then Include(Result, fsUnderline);
  if (Value and 8) <> 0 then Include(Result, fsStrikeOut);
end;

constructor TFrameLyricsCharacterDisplaySettingsPage.Create(
  AOwner: TComponent);
var
  FontName: string;
begin
  inherited Create(AOwner);
  Name := 'FrameLyricsCharacterDisplaySettingsPage';
  FBackground := TDisplayPreviewBackground.Create;
  FBaseFontLabel := TLabel.Create(Self);
  FBaseFontLabel.Parent := Self;
  FBaseFontLabel.Caption := #27468#35422#12501#12457#12531#12488;
  FBaseFontLabel.Font.Assign(Font);
  FBaseFontCombo := TComboBox.Create(Self);
  FBaseFontCombo.Parent := Self;
  FBaseFontCombo.OnChange := FontComboChange;
  FBaseFontCombo.Items.Assign(Screen.Fonts);
  FontName := 'Yu Gothic UI';
  FBaseFontCombo.ItemIndex := FBaseFontCombo.Items.IndexOf(FontName);
  FRubyFontLabel := TLabel.Create(Self);
  FRubyFontLabel.Parent := Self;
  FRubyFontLabel.Caption := #12523#12499#12501#12457#12531#12488;
  FRubyFontLabel.Font.Assign(Font);
  FRubyFontCombo := TComboBox.Create(Self);
  FRubyFontCombo.Parent := Self;
  FRubyFontCombo.OnChange := FontComboChange;
  FRubyFontCombo.Items.Assign(Screen.Fonts);
  FRubyFontCombo.ItemIndex := FRubyFontCombo.Items.IndexOf(FontName);
  FFormattingToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FFormattingToolbar.Parent := Self;
  FFormattingToolbar.Color := Color;
  FFormattingToolbar.ParentBackground := False;
  FFormattingToolbar.OnButtonExecute := FormattingToolbarExecute;
  FFormattingToolbar.AddToggleButton(#22826#23383, tbgBold);
  FFormattingToolbar.AddToggleButton(#26012#20307, tbgItalic);
  FFormattingToolbar.AddToggleButton(#19979#32218, tbgUnderline);
  FFormattingToolbar.AddToggleButton(#21462#12426#28040#12375#32218,
    tbgStrikeOut);
  FActionToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FActionToolbar.Parent := Self;
  FActionToolbar.Color := Color;
  FActionToolbar.ParentBackground := False;
  FActionToolbar.OnButtonExecute := ActionToolbarExecute;
  FActionToolbar.AddDialogButton(#34892#20849#36890#35373#23450,
    tbgOutline);
  FActionToolbar.AddCommandButton(#20013#22830#12408,
    tbgMoveToCenter);
  FActionToolbar.AddCommandButton(#36984#25246#12434#21021#26399#21270,
    tbgResetSelected);
  FActionToolbar.AddCommandButton(#12377#12409#12390#21021#26399#21270,
    tbgResetAll);
  FActionToolbar.AddCommandButton(#27178#19968#21015,
    tbgAlignHorizontal);
  FActionToolbar.AddCommandButton(#22343#31561#37197#32622,
    tbgDistributeHorizontal);

  FPreview := TPaintBox.Create(Self);
  FPreview.Parent := Self;
  FPreview.OnPaint := PreviewPaint;
  FPreview.OnMouseDown := PreviewMouseDown;
  FPreview.OnMouseMove := PreviewMouseMove;
  FPreview.OnMouseUp := PreviewMouseUp;
  TCharacterDisplayPageControlAccess(FPreview).OnMouseWheel :=
    PreviewMouseWheel;
  FElementLabel := TLabel.Create(Self);
  FElementLabel.Parent := Self;
  FElementLabel.Caption := #36984#25246#25991#23383;
  FElementLabel.Font.Assign(Font);
  FElementCombo := TComboBox.Create(Self);
  FElementCombo.Parent := Self;
  FElementCombo.OnChange := ElementComboChange;
  FColorPanel := TDisplaySettingsColorPanel.Create(Self);
  FColorPanel.Parent := Self;
  FColorPanel.OnChange := ColorPanelChange;
  FColorPanel.OnTargetChange := ColorTargetChange;
  ApplySyncLyricsDarkComboBox(FBaseFontCombo, ComboDrawItem);
  ApplySyncLyricsDarkComboBox(FRubyFontCombo, ComboDrawItem);
  ApplySyncLyricsDarkComboBox(FElementCombo, ComboDrawItem);
  FCurrentCandidate := -1;
  FSelectionMode := clsmTransform;
  FViewZoom := 1;
  FLayoutReady := True;
  Resize;
end;

destructor TFrameLyricsCharacterDisplaySettingsPage.Destroy;
begin
  FBackground.Free;
  inherited;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.AdjustPreviewZoom(
  WheelDelta: Integer; const ClientPoint: TPoint);
const
  MAX_ZOOM = 8.0;
  MIN_ZOOM = 0.25;
  ZOOM_STEP = 1.2;
var
  ImageX: Double;
  ImageY: Double;
  NewDestination: TRect;
  NewScale: Double;
  NewZoom: Double;
  OldDestination: TRect;
  OldScale: Double;
begin
  if not FBackground.HasImage then
    Exit;
  OldDestination := PreviewDestinationRect;
  OldScale := PreviewScale;
  if OldScale <= 0 then
    Exit;
  ImageX := (ClientPoint.X - OldDestination.Left) / OldScale;
  ImageY := (ClientPoint.Y - OldDestination.Top) / OldScale;
  if WheelDelta > 0 then
    NewZoom := FViewZoom * ZOOM_STEP
  else
    NewZoom := FViewZoom / ZOOM_STEP;
  FViewZoom := EnsureRange(NewZoom, MIN_ZOOM, MAX_ZOOM);
  NewDestination := PreviewDestinationRect;
  NewScale := PreviewScale;
  FViewPan.X := FViewPan.X + ClientPoint.X -
    (NewDestination.Left + ImageX * NewScale);
  FViewPan.Y := FViewPan.Y + ClientPoint.Y -
    (NewDestination.Top + ImageY * NewScale);
  FPreview.Invalidate;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.ActionToolbarExecute(
  Sender: TObject; Button: TSyncLyricsToolbarButton);
var
  Bounds: TRect;
  Defaults: TDisplayPlacementItems;
  DeltaX: Double;
  DeltaY: Double;
  I: Integer;
  Indices: TArray<Integer>;
  J: Integer;
  Saved: TDisplayPlacementItems;
  Scale: Double;
  Temp: Integer;
begin
  if Button = nil then
    Exit;
  case Button.Glyph of
    tbgOutline:
      begin
        EditSelectedDecoration;
        Exit;
      end;
    tbgMoveToCenter:
      if SelectionCount > 0 then
      begin
        Bounds := GroupSelectionBounds;
        Scale := PreviewScale;
        if Scale > 0 then
        begin
          DeltaX := (PreviewDestinationRect.CenterPoint.X -
            (Bounds.Left + Bounds.Right) * 0.5) / Scale;
          DeltaY := (PreviewDestinationRect.CenterPoint.Y -
            (Bounds.Top + Bounds.Bottom) * 0.5) / Scale;
          for I := 0 to High(FSelected) do
            if FSelected[I] then
            begin
              FCurrentPlacements[I].X := FCurrentPlacements[I].X + DeltaX;
              FCurrentPlacements[I].Y := FCurrentPlacements[I].Y + DeltaY;
            end;
        end;
      end;
    tbgResetSelected:
      begin
        Saved := Copy(FCurrentPlacements);
        BuildDefaultPlacements;
        Defaults := Copy(FCurrentPlacements);
        FCurrentPlacements := Saved;
        for I := 0 to Min(High(FSelected), High(FCurrentPlacements)) do
          if FSelected[I] then
            FCurrentPlacements[I] := Defaults[I];
      end;
    tbgResetAll:
      BuildDefaultPlacements;
    tbgAlignHorizontal:
      if SelectedElementIndex >= 0 then
        for I := 0 to Min(High(FSelected), High(FCurrentPlacements)) do
          if FSelected[I] then
            FCurrentPlacements[I].Y :=
              FCurrentPlacements[SelectedElementIndex].Y;
    tbgDistributeHorizontal:
      begin
        SetLength(Indices, SelectionCount);
        J := 0;
        for I := 0 to High(FSelected) do
          if FSelected[I] then
          begin
            Indices[J] := I;
            Inc(J);
          end;
        for I := 0 to High(Indices) - 1 do
          for J := I + 1 to High(Indices) do
            if FCurrentPlacements[Indices[I]].X >
              FCurrentPlacements[Indices[J]].X then
            begin
              Temp := Indices[I];
              Indices[I] := Indices[J];
              Indices[J] := Temp;
            end;
        if Length(Indices) >= 3 then
        begin
          DeltaX := (FCurrentPlacements[Indices[High(Indices)]].X -
            FCurrentPlacements[Indices[0]].X) / High(Indices);
          for I := 1 to High(Indices) - 1 do
            FCurrentPlacements[Indices[I]].X :=
              FCurrentPlacements[Indices[0]].X + DeltaX * I;
        end;
      end;
  else
    Exit;
  end;
  StoreCurrentCandidate;
  FPreview.Invalidate;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.EditSelectedDecoration;
var
  DecorationForm: TFormLyricsLineDisplaySettings;
  Settings: TDisplayCommonSettings;
begin
  if SelectionCount = 0 then
    Exit;
  Settings := SelectedDecorationSettings;
  DecorationForm := TFormLyricsLineDisplaySettings.Create(Self);
  try
    DecorationForm.Caption := #36984#25246#35201#32032#12398#35013#39166;
    if (Length(FBackgroundPixels) > 0) and
      (FBackgroundPixelWidth > 0) and
      (FBackgroundPixelHeight > 0) then
      DecorationForm.SetBackgroundRgba(FBackgroundPixels,
        FBackgroundPixelWidth, FBackgroundPixelHeight);
    DecorationForm.Configure(DisplayUnitBaseText(SelectedElementIndex),
      Settings);
    DecorationForm.ConfigurePlacementMode(1);
    DecorationForm.SetPlacementModeSwitchVisible(False);
    if DecorationForm.ShowModal = mrOk then
      ApplySelectedDecoration(DecorationForm.SelectedCommonSettings);
  finally
    DecorationForm.Free;
  end;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.ComboDrawItem(
  Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
begin
  DrawSyncLyricsDarkComboBoxItem(Control as TComboBox, Index, Rect,
    State, CurrentPPI);
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.FontComboChange(
  Sender: TObject);
var
  I: Integer;
  Value: string;
begin
  if FUpdatingControls or (SelectionCount = 0) then
    Exit;
  Value := (Sender as TComboBox).Text;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
      if Sender = FBaseFontCombo then
      begin
        if SameText(Value, FCurrentCommon.BaseFontName) then
          FCurrentPlacements[I].BaseFontName := ''
        else
          FCurrentPlacements[I].BaseFontName := Value;
      end
      else
      begin
        if SameText(Value, FCurrentCommon.RubyFontName) then
          FCurrentPlacements[I].RubyFontName := ''
        else
          FCurrentPlacements[I].RubyFontName := Value;
      end;
  StoreCurrentCandidate;
  FPreview.Invalidate;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.FormattingToolbarExecute(
  Sender: TObject; Button: TSyncLyricsToolbarButton);
var
  BitValue: Byte;
  I: Integer;
  StyleValue: Byte;
  TurnOn: Boolean;
begin
  if (Button = nil) or (SelectionCount = 0) then
    Exit;
  case Button.Glyph of
    tbgBold: BitValue := 1;
    tbgItalic: BitValue := 2;
    tbgUnderline: BitValue := 4;
    tbgStrikeOut: BitValue := 8;
  else
    Exit;
  end;
  TurnOn := Button.CheckState = tbcsChecked;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      StyleValue := FCurrentCommon.BaseFontStyle;
      if FCurrentPlacements[I].HasBaseFontStyle then
        StyleValue := FCurrentPlacements[I].BaseFontStyle;
      if TurnOn then StyleValue := StyleValue or BitValue
      else StyleValue := StyleValue and not BitValue;
      FCurrentPlacements[I].BaseFontStyle := StyleValue and $0F;
      FCurrentPlacements[I].HasBaseFontStyle :=
        FCurrentPlacements[I].BaseFontStyle <>
          FCurrentCommon.BaseFontStyle;
      if DisplayUnitRubyText(I) <> '' then
      begin
        StyleValue := FCurrentCommon.RubyFontStyle;
        if FCurrentPlacements[I].HasRubyFontStyle then
          StyleValue := FCurrentPlacements[I].RubyFontStyle;
        if TurnOn then StyleValue := StyleValue or BitValue
        else StyleValue := StyleValue and not BitValue;
        FCurrentPlacements[I].RubyFontStyle := StyleValue and $0F;
        FCurrentPlacements[I].HasRubyFontStyle :=
          FCurrentPlacements[I].RubyFontStyle <>
            FCurrentCommon.RubyFontStyle;
      end;
    end;
  StoreCurrentCandidate;
  UpdateSelectedControls;
  FPreview.Invalidate;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.ColorPanelChange(
  Sender: TObject);
var
  AfterColor: Cardinal;
  BeforeColor: Cardinal;
  I: Integer;
begin
  if FUpdatingControls or (SelectionCount = 0) then
    Exit;
  BeforeColor := Cardinal(ColorToRGB(FColorPanel.BeforePicker.Color)) and
    $FFFFFF;
  AfterColor := Cardinal(ColorToRGB(FColorPanel.AfterPicker.Color)) and
    $FFFFFF;
  for I := 0 to High(FSelected) do
    if FSelected[I] then
      case FColorPanel.TargetIndex of
        0:
          begin
            FCurrentPlacements[I].BeforeColor := BeforeColor;
            FCurrentPlacements[I].AfterColor := AfterColor;
            FCurrentPlacements[I].BeforeOpacity :=
              FColorPanel.BeforeOpacity;
            FCurrentPlacements[I].AfterOpacity := FColorPanel.AfterOpacity;
            FCurrentPlacements[I].HasBeforeColor :=
              BeforeColor <> FCurrentCommon.BeforeColor;
            FCurrentPlacements[I].HasAfterColor :=
              AfterColor <> FCurrentCommon.AfterColor;
            FCurrentPlacements[I].HasBeforeOpacity :=
              FColorPanel.BeforeOpacity <> FCurrentCommon.BeforeOpacity;
            FCurrentPlacements[I].HasAfterOpacity :=
              FColorPanel.AfterOpacity <> FCurrentCommon.AfterOpacity;
          end;
        1:
          begin
            FCurrentPlacements[I].BeforeOutlineColor := BeforeColor;
            FCurrentPlacements[I].AfterOutlineColor := AfterColor;
            FCurrentPlacements[I].BeforeOutlineOpacity :=
              FColorPanel.BeforeOpacity;
            FCurrentPlacements[I].AfterOutlineOpacity :=
              FColorPanel.AfterOpacity;
            FCurrentPlacements[I].HasBeforeOutlineColor :=
              BeforeColor <> FCurrentCommon.BeforeOutlineColor;
            FCurrentPlacements[I].HasAfterOutlineColor :=
              AfterColor <> FCurrentCommon.AfterOutlineColor;
            FCurrentPlacements[I].HasBeforeOutlineOpacity :=
              FColorPanel.BeforeOpacity <>
                FCurrentCommon.BeforeOutlineOpacity;
            FCurrentPlacements[I].HasAfterOutlineOpacity :=
              FColorPanel.AfterOpacity <>
                FCurrentCommon.AfterOutlineOpacity;
          end;
        2:
          begin
            FCurrentPlacements[I].BeforeShadowColor := BeforeColor;
            FCurrentPlacements[I].AfterShadowColor := AfterColor;
            FCurrentPlacements[I].BeforeShadowOpacity :=
              FColorPanel.BeforeOpacity;
            FCurrentPlacements[I].AfterShadowOpacity :=
              FColorPanel.AfterOpacity;
            FCurrentPlacements[I].HasBeforeShadowColor :=
              BeforeColor <> FCurrentCommon.BeforeShadowColor;
            FCurrentPlacements[I].HasAfterShadowColor :=
              AfterColor <> FCurrentCommon.AfterShadowColor;
            FCurrentPlacements[I].HasBeforeShadowOpacity :=
              FColorPanel.BeforeOpacity <>
                FCurrentCommon.BeforeShadowOpacity;
            FCurrentPlacements[I].HasAfterShadowOpacity :=
              FColorPanel.AfterOpacity <>
                FCurrentCommon.AfterShadowOpacity;
          end;
        3:
          begin
            FCurrentPlacements[I].BeforeBlurColor := BeforeColor;
            FCurrentPlacements[I].AfterBlurColor := AfterColor;
            FCurrentPlacements[I].BeforeBlurOpacity :=
              FColorPanel.BeforeOpacity;
            FCurrentPlacements[I].AfterBlurOpacity :=
              FColorPanel.AfterOpacity;
            FCurrentPlacements[I].HasBeforeBlurColor :=
              BeforeColor <> FCurrentCommon.BeforeBlurColor;
            FCurrentPlacements[I].HasAfterBlurColor :=
              AfterColor <> FCurrentCommon.AfterBlurColor;
            FCurrentPlacements[I].HasBeforeBlurOpacity :=
              FColorPanel.BeforeOpacity <>
                FCurrentCommon.BeforeBlurOpacity;
            FCurrentPlacements[I].HasAfterBlurOpacity :=
              FColorPanel.AfterOpacity <>
                FCurrentCommon.AfterBlurOpacity;
          end;
      end;
  StoreCurrentCandidate;
  FPreview.Invalidate;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.ColorTargetChange(
  Sender: TObject);
begin
  UpdateSelectedControls;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.BuildDefaultPlacements;
const
  ITEM_SPACING = 12;
var
  BaseSize: TSize;
  CursorX: Single;
  I: Integer;
  ItemWidths: TArray<Integer>;
  RubySize: TSize;
  TotalWidth: Integer;
begin
  SetLength(FCurrentPlacements, Length(FUnits));
  SetLength(ItemWidths, Length(FUnits));
  TotalWidth := 0;
  for I := 0 to High(FUnits) do
  begin
    FPreview.Canvas.Font.Name := FCurrentCommon.BaseFontName;
    FPreview.Canvas.Font.Height := -Max(1,
      FCurrentCommon.BaseFontHeight);
    BaseSize := FPreview.Canvas.TextExtent(DisplayUnitBaseText(I));
    RubySize.cx := 0;
    if DisplayUnitRubyText(I) <> '' then
    begin
      FPreview.Canvas.Font.Name := FCurrentCommon.RubyFontName;
      FPreview.Canvas.Font.Height := -Max(1,
        FCurrentCommon.RubyFontHeight);
      RubySize := FPreview.Canvas.TextExtent(DisplayUnitRubyText(I));
    end;
    ItemWidths[I] := Max(BaseSize.cx, RubySize.cx);
    Inc(TotalWidth, ItemWidths[I]);
    if I > 0 then
      Inc(TotalWidth, ITEM_SPACING);
  end;
  CursorX := -TotalWidth * 0.5;
  for I := 0 to High(FCurrentPlacements) do
  begin
    FCurrentPlacements[I].Index := I;
    FCurrentPlacements[I].X := CursorX + ItemWidths[I] * 0.5;
    FCurrentPlacements[I].Y := 0;
    FCurrentPlacements[I].ScaleX := 1;
    FCurrentPlacements[I].ScaleY := 1;
    CursorX := CursorX + ItemWidths[I] + ITEM_SPACING;
  end;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.CandidateChanged(
  Index: Integer);
begin
  LoadCandidate(Index);
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.CaptureInitialState;
var
  I: Integer;
begin
  StoreCurrentCandidate;
  FInitialCandidate := FCurrentCandidate;
  FInitialCandidateLyrics := Copy(FCandidateLyrics);
  FInitialCandidateCommon := Copy(FCandidateCommon);
  FInitialCandidateSelections := Copy(FCandidateSelections);
  SetLength(FInitialCandidatePlacements, Length(FCandidatePlacements));
  for I := 0 to High(FCandidatePlacements) do
    FInitialCandidatePlacements[I] := Copy(FCandidatePlacements[I]);
  SetLength(FInitialCandidateSelected, Length(FCandidateSelected));
  for I := 0 to High(FCandidateSelected) do
    FInitialCandidateSelected[I] := Copy(FCandidateSelected[I]);
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.ConfigureCandidates(
  const Lyrics: TArray<string>;
  const CommonSettings: TArray<TDisplayCommonSettings>;
  const SettingsTexts: TArray<string>; InitialIndex: Integer);
var
  DecodedCommon: TDisplayCommonSettings;
  I: Integer;
  MatchesLyrics: Boolean;
begin
  FCandidateLyrics := Copy(Lyrics);
  FCandidateCommon := Copy(CommonSettings);
  SetLength(FCandidatePlacements, Length(Lyrics));
  SetLength(FCandidateSelected, Length(Lyrics));
  SetLength(FCandidateSelections, Length(Lyrics));
  for I := 0 to High(FCandidateSelections) do
  begin
    FCandidateSelections[I] := -1;
    FCandidateSelected[I] := nil;
    MatchesLyrics := False;
    if (I < Length(SettingsTexts)) and
      TryDecodeDisplaySettingsText(SettingsTexts[I], Lyrics[I],
        DecodedCommon, FCandidatePlacements[I], MatchesLyrics) and
      MatchesLyrics then
    begin
      if I >= Length(FCandidateCommon) then
        Continue;
      FCandidateCommon[I] := DecodedCommon;
    end
    else
      FCandidatePlacements[I] := nil;
  end;
  FCurrentCandidate := -1;
  if Length(FCandidateLyrics) > 0 then
    LoadCandidate(EnsureRange(InitialIndex, 0,
      High(FCandidateLyrics)))
  else
    LoadCandidate(-1);
end;

function TFrameLyricsCharacterDisplaySettingsPage.DisplayUnitBaseText(
  Index: Integer): string;
begin
  Result := Copy(FPlainText, FUnits[Index].BaseStart,
    FUnits[Index].BaseLength);
end;

function TFrameLyricsCharacterDisplaySettingsPage.DisplayUnitRubyText(
  Index: Integer): string;
var
  RubyIndex: Integer;
begin
  Result := '';
  RubyIndex := FUnits[Index].RubyIndex;
  if (RubyIndex >= 0) and (RubyIndex < Length(FRubySpans)) then
    Result := FRubySpans[RubyIndex].RubyText;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.ElementComboChange(
  Sender: TObject);
begin
  if FUpdatingElementCombo then
    Exit;
  if (FCurrentCandidate < 0) or
    (FCurrentCandidate >= Length(FCandidateSelections)) then
    Exit;
  FSelectionMode := clsmTransform;
  SelectElement(FElementCombo.ItemIndex);
end;

function TFrameLyricsCharacterDisplaySettingsPage.ElementCount: Integer;
begin
  Result := Length(FUnits);
end;

function TFrameLyricsCharacterDisplaySettingsPage.ElementPlacement(
  Index: Integer): TDisplayPlacementItem;
begin
  Result := Default(TDisplayPlacementItem);
  if (Index >= 0) and (Index < Length(FCurrentPlacements)) then
    Result := FCurrentPlacements[Index];
end;

function TFrameLyricsCharacterDisplaySettingsPage.GroupSelectionBounds:
  TRect;
var
  Bounds: TRect;
  I: Integer;
  Initialized: Boolean;
begin
  Result := Rect(0, 0, 0, 0);
  Initialized := False;
  for I := 0 to Min(High(FSelected), High(FCurrentPlacements)) do
    if FSelected[I] then
    begin
      Bounds := PreviewElementBounds(I);
      if not Initialized then
      begin
        Result := Bounds;
        Initialized := True;
      end
      else
        UnionRect(Result, Result, Bounds);
    end;
end;

function TFrameLyricsCharacterDisplaySettingsPage.HitTestResizeHandle(
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
    (SelectionCount = 0) then
    Exit;
  Bounds := GroupSelectionBounds;
  CenterX := (Bounds.Left + Bounds.Right) div 2;
  CenterY := (Bounds.Top + Bounds.Bottom) div 2;
  if NearPoint(Bounds.Left, Bounds.Top) then Exit(cldmResizeTopLeft);
  if NearPoint(Bounds.Right, Bounds.Top) then Exit(cldmResizeTopRight);
  if NearPoint(Bounds.Left, Bounds.Bottom) then Exit(cldmResizeBottomLeft);
  if NearPoint(Bounds.Right, Bounds.Bottom) then Exit(cldmResizeBottomRight);
  if NearPoint(CenterX, Bounds.Top) then Exit(cldmResizeTop);
  if NearPoint(CenterX, Bounds.Bottom) then Exit(cldmResizeBottom);
  if NearPoint(Bounds.Left, CenterY) then Exit(cldmResizeLeft);
  if NearPoint(Bounds.Right, CenterY) then Exit(cldmResizeRight);
end;

function TFrameLyricsCharacterDisplaySettingsPage.HitTestModeHandle(
  X, Y: Integer): TCharacterLayoutDragMode;
begin
  Result := cldmNone;
  if (FSelectionMode = clsmTransform) or
    (SelectionCount = 0) then
    Exit;
  Result := HitTestCharacterLayoutModeHandle(GroupSelectionBounds,
    FSelectionMode, X, Y);
end;

function TFrameLyricsCharacterDisplaySettingsPage.ModeID: Integer;
begin
  Result := DISPLAY_SETTINGS_MODE_FREE;
end;

function TFrameLyricsCharacterDisplaySettingsPage.HasBackgroundImage:
  Boolean;
begin
  Result := (FBackground <> nil) and FBackground.HasImage;
end;

function TFrameLyricsCharacterDisplaySettingsPage.ModeGlyph:
  TSyncLyricsToolbarGlyph;
begin
  Result := tbgFreePlacement;
end;

function TFrameLyricsCharacterDisplaySettingsPage.ModeName: string;
begin
  Result := #25991#23383#33258#30001#37197#32622;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.LoadCandidate(
  Index: Integer);
var
  DesiredSelection: Integer;
  I: Integer;
begin
  StoreCurrentCandidate;
  FCurrentCandidate := Index;
  FCurrentLyrics := '';
  FCurrentCommon := DefaultDisplayCommonSettings;
  FCurrentPlacements := nil;
  if (Index >= 0) and (Index < Length(FCandidateLyrics)) then
  begin
    FCurrentLyrics := FCandidateLyrics[Index];
    if Index < Length(FCandidateCommon) then
      FCurrentCommon := FCandidateCommon[Index];
    if Index < Length(FCandidatePlacements) then
      FCurrentPlacements := Copy(FCandidatePlacements[Index]);
  end;
  ParseLyrics(FCurrentLyrics, FPlainText, FRubySpans);
  BuildLyricsDisplayUnits(FPlainText, FRubySpans, FUnits);
  SetLength(FSelected, Length(FUnits));
  for I := 0 to High(FSelected) do
    FSelected[I] := False;
  if (Index >= 0) and (Index < Length(FCandidateSelected)) and
    (Length(FCandidateSelected[Index]) = Length(FUnits)) then
    FSelected := Copy(FCandidateSelected[Index]);
  if Length(FCurrentPlacements) <> Length(FUnits) then
    BuildDefaultPlacements;
  if FBaseFontCombo.Items.IndexOf(FCurrentCommon.BaseFontName) >= 0 then
    FBaseFontCombo.ItemIndex :=
      FBaseFontCombo.Items.IndexOf(FCurrentCommon.BaseFontName);
  if FRubyFontCombo.Items.IndexOf(FCurrentCommon.RubyFontName) >= 0 then
    FRubyFontCombo.ItemIndex :=
      FRubyFontCombo.Items.IndexOf(FCurrentCommon.RubyFontName);
  DesiredSelection := -1;
  if (Index >= 0) and (Index < Length(FCandidateSelections)) then
    DesiredSelection := FCandidateSelections[Index];
  PopulateElementCombo;
  if (DesiredSelection >= 0) and
    (DesiredSelection < FElementCombo.Items.Count) then
  begin
    FUpdatingElementCombo := True;
    try
      FElementCombo.ItemIndex := DesiredSelection;
    finally
      FUpdatingElementCombo := False;
    end;
  end;
  UpdateSelectedControls;
  FPreview.Invalidate;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.PopulateElementCombo;
var
  BaseText: string;
  I: Integer;
  RubyText: string;
begin
  FUpdatingElementCombo := True;
  FElementCombo.Items.BeginUpdate;
  try
    FElementCombo.Items.Clear;
    for I := 0 to High(FUnits) do
    begin
      BaseText := DisplayUnitBaseText(I);
      RubyText := DisplayUnitRubyText(I);
      if RubyText <> '' then
        FElementCombo.Items.Add(Format('%d: [%s](%s)',
          [I + 1, BaseText, RubyText]))
      else
        FElementCombo.Items.Add(Format('%d: %s', [I + 1, BaseText]));
    end;
    FElementCombo.ItemIndex := -1;
  finally
    FElementCombo.Items.EndUpdate;
    FUpdatingElementCombo := False;
  end;
end;

function TFrameLyricsCharacterDisplaySettingsPage.PreviewElementBounds(
  Index: Integer): TRect;
var
  BaseHeight: Integer;
  BaseSpacing: Integer;
  BaseStyle: Byte;
  BaseRect: TRectF;
  BaseSize: TSize;
  Center: TPoint;
  Destination: TRect;
  Item: TDisplayPlacementItem;
  RubyHeight: Integer;
  RubySpacing: Integer;
  RubyStyle: Byte;
  RubyRect: TRectF;
  RubySize: TSize;
  RubyText: string;
  Scale: Double;
begin
  Result := Rect(0, 0, 0, 0);
  if (Index < 0) or (Index >= Length(FUnits)) or
    (Index >= Length(FCurrentPlacements)) then
    Exit;
  Destination := PreviewDestinationRect;
  Scale := PreviewScale;
  Item := FCurrentPlacements[Index];
  Center.X := Destination.Left + Destination.Width div 2 +
    Round(Item.X * Scale);
  Center.Y := Destination.Top + Destination.Height div 2 +
    Round(Item.Y * Scale);
  FPreview.Canvas.Font.Name := FCurrentCommon.BaseFontName;
  if Item.BaseFontName <> '' then
    FPreview.Canvas.Font.Name := Item.BaseFontName;
  BaseHeight := FCurrentCommon.BaseFontHeight;
  if Item.HasBaseFontHeight then
    BaseHeight := Item.BaseFontHeight;
  FPreview.Canvas.Font.Height := -Max(1, BaseHeight);
  BaseStyle := FCurrentCommon.BaseFontStyle;
  if Item.HasBaseFontStyle then BaseStyle := Item.BaseFontStyle;
  FPreview.Canvas.Font.Style := CharacterFontStyle(BaseStyle);
  BaseSpacing := 0;
  if Item.HasBaseCharacterSpacing then
    BaseSpacing := Item.BaseCharacterSpacing;
  SetTextCharacterExtra(FPreview.Canvas.Handle, BaseSpacing);
  BaseSize := FPreview.Canvas.TextExtent(DisplayUnitBaseText(Index));
  BaseRect := RectF(-BaseSize.cx * 0.5, -BaseSize.cy * 0.5,
    BaseSize.cx * 0.5, BaseSize.cy * 0.5);
  Result := Rect(Center.X + Round(BaseRect.Left * Scale * Item.ScaleX),
    Center.Y + Round(BaseRect.Top * Scale * Item.ScaleY),
    Center.X + Round(BaseRect.Right * Scale * Item.ScaleX),
    Center.Y + Round(BaseRect.Bottom * Scale * Item.ScaleY));
  RubyText := DisplayUnitRubyText(Index);
  if RubyText <> '' then
  begin
    FPreview.Canvas.Font.Name := FCurrentCommon.RubyFontName;
    if Item.RubyFontName <> '' then
      FPreview.Canvas.Font.Name := Item.RubyFontName;
    RubyHeight := FCurrentCommon.RubyFontHeight;
    if Item.HasRubyFontHeight then
      RubyHeight := Item.RubyFontHeight;
    FPreview.Canvas.Font.Height := -Max(1, RubyHeight);
    RubyStyle := FCurrentCommon.RubyFontStyle;
    if Item.HasRubyFontStyle then RubyStyle := Item.RubyFontStyle;
    FPreview.Canvas.Font.Style := CharacterFontStyle(RubyStyle);
    RubySpacing := 0;
    if Item.HasRubyCharacterSpacing then
      RubySpacing := Item.RubyCharacterSpacing;
    SetTextCharacterExtra(FPreview.Canvas.Handle, RubySpacing);
    RubySize := FPreview.Canvas.TextExtent(RubyText);
    RubyRect.Left := -RubySize.cx * 0.5;
    RubyRect.Top := -BaseSize.cy * 0.5 - RubySize.cy -
      (4 + FCurrentCommon.RubyGapAdjustment);
    if Item.HasRubyOffsetX then
      RubyRect.Left := RubyRect.Left + Item.RubyOffsetX;
    if Item.HasRubyOffsetY then
      RubyRect.Top := RubyRect.Top + Item.RubyOffsetY;
    RubyRect.Right := RubyRect.Left + RubySize.cx;
    RubyRect.Bottom := RubyRect.Top + RubySize.cy;
    UnionRect(Result, Result, Rect(
      Center.X + Round(RubyRect.Left * Scale * Item.ScaleX),
      Center.Y + Round(RubyRect.Top * Scale * Item.ScaleY),
      Center.X + Round(RubyRect.Right * Scale * Item.ScaleX),
      Center.Y + Round(RubyRect.Bottom * Scale * Item.ScaleY)));
  end;
  SetTextCharacterExtra(FPreview.Canvas.Handle, 0);
  InflateRect(Result, MulDiv(4, CurrentPPI, 96),
    MulDiv(4, CurrentPPI, 96));
end;

function TFrameLyricsCharacterDisplaySettingsPage.PreviewDestinationRect:
  TRect;
var
  Base: TRect;
  DrawHeight: Integer;
  DrawWidth: Integer;
begin
  Base := FBackground.DestinationRect(FPreview.ClientRect);
  if not FBackground.HasImage then
    Exit(Base);
  DrawWidth := Max(1, Round(Base.Width * FViewZoom));
  DrawHeight := Max(1, Round(Base.Height * FViewZoom));
  Result.Left := (FPreview.ClientWidth - DrawWidth) div 2 +
    Round(FViewPan.X);
  Result.Top := (FPreview.ClientHeight - DrawHeight) div 2 +
    Round(FViewPan.Y);
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

function TFrameLyricsCharacterDisplaySettingsPage.PreviewScale: Double;
begin
  Result := 1;
  if FBackground.HasImage and (FBackground.ImageWidth > 0) then
    Result := PreviewDestinationRect.Width / FBackground.ImageWidth;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.PreviewMouseDown(
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
    FPreview.Invalidate;
    Exit;
  end;
  if Button <> mbLeft then
    Exit;
  FDragMode := HitTestModeHandle(X, Y);
  if FDragMode = cldmNone then
    FDragMode := HitTestResizeHandle(X, Y);
  if FDragMode = cldmNone then
  begin
    HitIndex := High(FCurrentPlacements);
    while (HitIndex >= 0) and
      not PtInRect(PreviewElementBounds(HitIndex), Point(X, Y)) do
      Dec(HitIndex);
    if ssShift in Shift then
    begin
      FSelectionMode := clsmTransform;
      SelectElement(HitIndex, True)
    end
    else if HitIndex < 0 then
    begin
      FSelectionMode := clsmTransform;
      SelectElement(-1);
      FDragMode := cldmPan;
      FDragStartViewPan := FViewPan;
    end
    else if (HitIndex >= Length(FSelected)) or
      not FSelected[HitIndex] then
    begin
      FSelectionMode := clsmTransform;
      SelectElement(HitIndex)
    end
    else
    begin
      FCandidateSelections[FCurrentCandidate] := HitIndex;
      FClickCandidateModeToggle := True;
      FPreview.Invalidate;
    end;
    if (HitIndex >= 0) and (HitIndex < Length(FSelected)) and
      FSelected[HitIndex] then
      if FSelectionMode in [clsmCharacterSpacing, clsmRuby] then
        FDragMode := cldmSelectionClick
      else
        FDragMode := cldmMove;
  end;
  if FDragMode <> cldmNone then
  begin
    FDragStartMouse := Point(X, Y);
    FDragStartPlacements := Copy(FCurrentPlacements);
    FDragStartGroupBounds := GroupSelectionBounds;
    SetLength(FDragStartElementBounds, Length(FCurrentPlacements));
    for I := 0 to High(FDragStartElementBounds) do
      FDragStartElementBounds[I] := PreviewElementBounds(I);
  end;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.PreviewMouseMove(
  Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  CharacterCounts: TArray<Integer>;
  HitIndex: Integer;
  I: Integer;
  HoverMode: TCharacterLayoutDragMode;
  Scale: Double;
begin
  if FSelectingRectangle then
  begin
    FSelectionCurrent := Point(X, Y);
    FPreview.Invalidate;
    Exit;
  end;
  if FDragMode <> cldmNone then
  begin
    Scale := PreviewScale;
    if Scale <= 0 then
      Exit;
    if not FDragChanged then
    begin
      FDragChanged := (Abs(X - FDragStartMouse.X) > 3) or
        (Abs(Y - FDragStartMouse.Y) > 3);
      if not FDragChanged then
        Exit;
    end;
    if FDragMode = cldmPan then
    begin
      FViewPan.X := FDragStartViewPan.X + X - FDragStartMouse.X;
      FViewPan.Y := FDragStartViewPan.Y + Y - FDragStartMouse.Y;
      FPreview.Cursor := crSizeAll;
      FPreview.Invalidate;
      Exit;
    end;
    if FDragMode = cldmMove then
    begin
      for I := 0 to Min(High(FSelected),
        High(FCurrentPlacements)) do
        if FSelected[I] then
        begin
          FCurrentPlacements[I].X := FDragStartPlacements[I].X +
            (X - FDragStartMouse.X) / Scale;
          FCurrentPlacements[I].Y := FDragStartPlacements[I].Y +
            (Y - FDragStartMouse.Y) / Scale;
        end;
      FPreview.Cursor := crSizeAll;
    end
    else if FDragMode in [cldmResizeLeft, cldmResizeRight,
      cldmResizeTop, cldmResizeBottom, cldmResizeTopLeft,
      cldmResizeTopRight, cldmResizeBottomLeft,
      cldmResizeBottomRight] then
      ResizeSelection(X, Y);
    if FDragMode in [cldmSpacingLeft, cldmSpacingRight] then
      if FSelectionMode = clsmCharacterSpacing then
      begin
        SetLength(CharacterCounts, Length(FUnits));
        for I := 0 to High(CharacterCounts) do
          CharacterCounts[I] := Length(DisplayUnitBaseText(I));
        ApplyCharacterLayoutSpacingDrag(FCurrentPlacements,
          FSelected, CharacterCounts, FDragStartPlacements,
          FDragMode, X - FDragStartMouse.X, Scale);
      end
      else
        ApplyCharacterLayoutRubySpacingDrag(FCurrentPlacements,
          FSelected, FDragStartPlacements, FDragMode,
          X - FDragStartMouse.X, Scale)
    else if FDragMode = cldmRubyMove then
      ApplyCharacterLayoutRubyMoveDrag(FCurrentPlacements,
        FSelected, FDragStartPlacements,
        X - FDragStartMouse.X, Y - FDragStartMouse.Y, Scale);
    FPreview.Invalidate;
    Exit;
  end;
  HoverMode := HitTestModeHandle(X, Y);
  case HoverMode of
    cldmSpacingLeft, cldmSpacingRight:
      FPreview.Cursor := crSizeWE;
    cldmRubyMove:
      FPreview.Cursor := crSizeAll;
  end;
  if HoverMode <> cldmNone then
    Exit;
  HoverMode := HitTestResizeHandle(X, Y);
  case HoverMode of
    cldmResizeLeft, cldmResizeRight:
      FPreview.Cursor := crSizeWE;
    cldmResizeTop, cldmResizeBottom:
      FPreview.Cursor := crSizeNS;
    cldmResizeTopLeft, cldmResizeBottomRight:
      FPreview.Cursor := crSizeNWSE;
    cldmResizeTopRight, cldmResizeBottomLeft:
      FPreview.Cursor := crSizeNESW;
  else
    HoverMode := cldmNone;
  end;
  if HoverMode <> cldmNone then
    Exit;
  HitIndex := High(FCurrentPlacements);
  while (HitIndex >= 0) and
    not PtInRect(PreviewElementBounds(HitIndex), Point(X, Y)) do
    Dec(HitIndex);
  if HitIndex >= 0 then
    FPreview.Cursor := crSizeAll
  else
    FPreview.Cursor := crDefault;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.PreviewMouseUp(
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
    Bounds := Rect(Min(FSelectionStart.X, FSelectionCurrent.X),
      Min(FSelectionStart.Y, FSelectionCurrent.Y),
      Max(FSelectionStart.X, FSelectionCurrent.X),
      Max(FSelectionStart.Y, FSelectionCurrent.Y));
    if not (ssShift in Shift) then
      for I := 0 to High(FSelected) do
        FSelected[I] := False;
    FCandidateSelections[FCurrentCandidate] := -1;
    for I := 0 to Min(High(FSelected), High(FCurrentPlacements)) do
      if IntersectRect(Intersection, Bounds,
        PreviewElementBounds(I)) then
      begin
        FSelected[I] := True;
        FCandidateSelections[FCurrentCandidate] := I;
      end;
    FSelectingRectangle := False;
    FSelectionMode := clsmTransform;
    FCandidateSelected[FCurrentCandidate] := Copy(FSelected);
    UpdateElementComboSelection;
    UpdateSelectedControls;
    FPreview.Invalidate;
    Exit;
  end;
  if Button <> mbLeft then
    Exit;
  if FClickCandidateModeToggle and not FDragChanged then
    FSelectionMode := NextCharacterLayoutSelectionMode(
      FSelectionMode, SelectionSupportsRubyMode);
  if (FDragMode <> cldmNone) and FDragChanged then
    StoreCurrentCandidate;
  FDragMode := cldmNone;
  FClickCandidateModeToggle := False;
  FDragChanged := False;
  PreviewMouseMove(Sender, Shift, X, Y);
  FPreview.Invalidate;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.PreviewMouseWheel(
  Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint; var Handled: Boolean);
var
  ClientPoint: TPoint;
begin
  Handled := False;
  ClientPoint := FPreview.ScreenToClient(MousePos);
  if not PtInRect(FPreview.ClientRect, ClientPoint) then
    Exit;
  Handled := True;
  AdjustPreviewZoom(WheelDelta, ClientPoint);
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.ResizeSelection(
  X, Y: Integer);
const
  MIN_SCALE = 0.05;
  MAX_SCALE = 10.0;
  MIN_SIZE = 8;
var
  FactorX: Double;
  FactorY: Double;
  I: Integer;
  NewBounds: TRect;
  NewCenterX: Double;
  NewCenterY: Double;
  OldCenterX: Double;
  OldCenterY: Double;
  Scale: Double;
begin
  NewBounds := FDragStartGroupBounds;
  case FDragMode of
    cldmResizeLeft, cldmResizeTopLeft, cldmResizeBottomLeft:
      NewBounds.Left := Min(X, NewBounds.Right - MIN_SIZE);
    cldmResizeRight, cldmResizeTopRight, cldmResizeBottomRight:
      NewBounds.Right := Max(X, NewBounds.Left + MIN_SIZE);
  end;
  case FDragMode of
    cldmResizeTop, cldmResizeTopLeft, cldmResizeTopRight:
      NewBounds.Top := Min(Y, NewBounds.Bottom - MIN_SIZE);
    cldmResizeBottom, cldmResizeBottomLeft, cldmResizeBottomRight:
      NewBounds.Bottom := Max(Y, NewBounds.Top + MIN_SIZE);
  end;
  FactorX := NewBounds.Width / Max(1, FDragStartGroupBounds.Width);
  FactorY := NewBounds.Height / Max(1, FDragStartGroupBounds.Height);
  Scale := PreviewScale;
  if Scale <= 0 then
    Exit;
  for I := 0 to Min(High(FSelected), High(FCurrentPlacements)) do
    if FSelected[I] then
    begin
      OldCenterX := (FDragStartElementBounds[I].Left +
        FDragStartElementBounds[I].Right) * 0.5;
      OldCenterY := (FDragStartElementBounds[I].Top +
        FDragStartElementBounds[I].Bottom) * 0.5;
      NewCenterX := NewBounds.Left +
        (OldCenterX - FDragStartGroupBounds.Left) * FactorX;
      NewCenterY := NewBounds.Top +
        (OldCenterY - FDragStartGroupBounds.Top) * FactorY;
      FCurrentPlacements[I].X := FDragStartPlacements[I].X +
        (NewCenterX - OldCenterX) / Scale;
      FCurrentPlacements[I].Y := FDragStartPlacements[I].Y +
        (NewCenterY - OldCenterY) / Scale;
      if FDragMode in [cldmResizeLeft, cldmResizeRight,
        cldmResizeTopLeft, cldmResizeTopRight,
        cldmResizeBottomLeft, cldmResizeBottomRight] then
        FCurrentPlacements[I].ScaleX := EnsureRange(
          FDragStartPlacements[I].ScaleX * FactorX,
          MIN_SCALE, MAX_SCALE);
      if FDragMode in [cldmResizeTop, cldmResizeBottom,
        cldmResizeTopLeft, cldmResizeTopRight,
        cldmResizeBottomLeft, cldmResizeBottomRight] then
        FCurrentPlacements[I].ScaleY := EnsureRange(
          FDragStartPlacements[I].ScaleY * FactorY,
          MIN_SCALE, MAX_SCALE);
    end;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.RestoreInitialState;
var
  I: Integer;
begin
  FCandidateLyrics := Copy(FInitialCandidateLyrics);
  FCandidateCommon := Copy(FInitialCandidateCommon);
  FCandidateSelections := Copy(FInitialCandidateSelections);
  SetLength(FCandidatePlacements, Length(FInitialCandidatePlacements));
  for I := 0 to High(FInitialCandidatePlacements) do
    FCandidatePlacements[I] := Copy(FInitialCandidatePlacements[I]);
  SetLength(FCandidateSelected, Length(FInitialCandidateSelected));
  for I := 0 to High(FInitialCandidateSelected) do
    FCandidateSelected[I] := Copy(FInitialCandidateSelected[I]);
  FCurrentCandidate := -1;
  if (FInitialCandidate >= 0) and
    (FInitialCandidate < Length(FCandidateLyrics)) then
    LoadCandidate(FInitialCandidate)
  else
    LoadCandidate(-1);
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.SelectElement(
  Index: Integer; Toggle: Boolean);
var
  I: Integer;
begin
  if (Index < 0) or (Index >= Length(FUnits)) then
    Index := -1;
  if Length(FSelected) <> Length(FUnits) then
    SetLength(FSelected, Length(FUnits));
  if Toggle then
  begin
    if Index >= 0 then
      FSelected[Index] := not FSelected[Index];
  end
  else
  begin
    for I := 0 to High(FSelected) do
      FSelected[I] := I = Index;
  end;
  if (Index >= 0) and not FSelected[Index] then
    Index := -1;
  if Index < 0 then
    for I := High(FSelected) downto 0 do
      if FSelected[I] then
      begin
        Index := I;
        Break;
      end;
  if (FCurrentCandidate >= 0) and
    (FCurrentCandidate < Length(FCandidateSelections)) then
  begin
    FCandidateSelections[FCurrentCandidate] := Index;
    FCandidateSelected[FCurrentCandidate] := Copy(FSelected);
  end;
  FUpdatingElementCombo := True;
  try
    FElementCombo.ItemIndex := Index;
  finally
    FUpdatingElementCombo := False;
  end;
  UpdateSelectedControls;
  FPreview.Invalidate;
end;

function TFrameLyricsCharacterDisplaySettingsPage.SelectionCount: Integer;
var
  Selected: Boolean;
begin
  Result := 0;
  for Selected in FSelected do
    if Selected then
      Inc(Result);
end;

function TFrameLyricsCharacterDisplaySettingsPage.SelectionSupportsRubyMode:
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

procedure TFrameLyricsCharacterDisplaySettingsPage.StoreCurrentCandidate;
begin
  if (FCurrentCandidate >= 0) and
    (FCurrentCandidate < Length(FCandidatePlacements)) then
  begin
    FCandidatePlacements[FCurrentCandidate] :=
      Copy(FCurrentPlacements);
    FCandidateSelected[FCurrentCandidate] := Copy(FSelected);
  end;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.UpdateElementComboSelection;
begin
  FUpdatingElementCombo := True;
  try
    FElementCombo.ItemIndex := SelectedElementIndex;
  finally
    FUpdatingElementCombo := False;
  end;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.UpdateSelectedControls;
var
  AfterColor: Cardinal;
  AfterOpacity: Byte;
  BeforeColor: Cardinal;
  BeforeOpacity: Byte;
  Button: TSyncLyricsToolbarButton;
  I: Integer;
  Index: Integer;
  Item: TDisplayPlacementItem;
  StyleValue: Byte;
begin
  if FUpdatingControls then
    Exit;
  FUpdatingControls := True;
  try
    Index := SelectedElementIndex;
    FBaseFontCombo.Enabled := Index >= 0;
    FRubyFontCombo.Enabled := Index >= 0;
    FFormattingToolbar.Enabled := Index >= 0;
    FColorPanel.Enabled := Index >= 0;
    if Index < 0 then
      Exit;
    Item := FCurrentPlacements[Index];
    if Item.BaseFontName <> '' then
      FBaseFontCombo.ItemIndex :=
        FBaseFontCombo.Items.IndexOf(Item.BaseFontName)
    else
      FBaseFontCombo.ItemIndex :=
        FBaseFontCombo.Items.IndexOf(FCurrentCommon.BaseFontName);
    if Item.RubyFontName <> '' then
      FRubyFontCombo.ItemIndex :=
        FRubyFontCombo.Items.IndexOf(Item.RubyFontName)
    else
      FRubyFontCombo.ItemIndex :=
        FRubyFontCombo.Items.IndexOf(FCurrentCommon.RubyFontName);
    StyleValue := FCurrentCommon.BaseFontStyle;
    if Item.HasBaseFontStyle then
      StyleValue := Item.BaseFontStyle;
    for I := 0 to Min(3, FFormattingToolbar.ItemCount - 1) do
    begin
      Button := FFormattingToolbar.Items[I];
      Button.CheckState := TSyncLyricsToolbarCheckState(
        Ord((StyleValue and (1 shl I)) <> 0));
    end;
    case FColorPanel.TargetIndex of
      0:
        begin
          BeforeColor := FCurrentCommon.BeforeColor;
          AfterColor := FCurrentCommon.AfterColor;
          BeforeOpacity := FCurrentCommon.BeforeOpacity;
          AfterOpacity := FCurrentCommon.AfterOpacity;
          if Item.HasBeforeColor then BeforeColor := Item.BeforeColor;
          if Item.HasAfterColor then AfterColor := Item.AfterColor;
          if Item.HasBeforeOpacity then BeforeOpacity := Item.BeforeOpacity;
          if Item.HasAfterOpacity then AfterOpacity := Item.AfterOpacity;
        end;
      1:
        begin
          BeforeColor := FCurrentCommon.BeforeOutlineColor;
          AfterColor := FCurrentCommon.AfterOutlineColor;
          BeforeOpacity := FCurrentCommon.BeforeOutlineOpacity;
          AfterOpacity := FCurrentCommon.AfterOutlineOpacity;
          if Item.HasBeforeOutlineColor then
            BeforeColor := Item.BeforeOutlineColor;
          if Item.HasAfterOutlineColor then
            AfterColor := Item.AfterOutlineColor;
          if Item.HasBeforeOutlineOpacity then
            BeforeOpacity := Item.BeforeOutlineOpacity;
          if Item.HasAfterOutlineOpacity then
            AfterOpacity := Item.AfterOutlineOpacity;
        end;
      2:
        begin
          BeforeColor := FCurrentCommon.BeforeShadowColor;
          AfterColor := FCurrentCommon.AfterShadowColor;
          BeforeOpacity := FCurrentCommon.BeforeShadowOpacity;
          AfterOpacity := FCurrentCommon.AfterShadowOpacity;
          if Item.HasBeforeShadowColor then
            BeforeColor := Item.BeforeShadowColor;
          if Item.HasAfterShadowColor then
            AfterColor := Item.AfterShadowColor;
          if Item.HasBeforeShadowOpacity then
            BeforeOpacity := Item.BeforeShadowOpacity;
          if Item.HasAfterShadowOpacity then
            AfterOpacity := Item.AfterShadowOpacity;
        end;
    else
      begin
        BeforeColor := FCurrentCommon.BeforeBlurColor;
        AfterColor := FCurrentCommon.AfterBlurColor;
        BeforeOpacity := FCurrentCommon.BeforeBlurOpacity;
        AfterOpacity := FCurrentCommon.AfterBlurOpacity;
        if Item.HasBeforeBlurColor then BeforeColor := Item.BeforeBlurColor;
        if Item.HasAfterBlurColor then AfterColor := Item.AfterBlurColor;
        if Item.HasBeforeBlurOpacity then
          BeforeOpacity := Item.BeforeBlurOpacity;
        if Item.HasAfterBlurOpacity then
          AfterOpacity := Item.AfterBlurOpacity;
      end;
    end;
    FColorPanel.Configure(FColorPanel.TargetIndex,
      TColor(BeforeColor), TColor(AfterColor), BeforeOpacity, AfterOpacity);
  finally
    FUpdatingControls := False;
  end;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.PreviewPaint(
  Sender: TObject);
var
  BaseHeight: Integer;
  BaseSpacing: Integer;
  BaseStyle: Byte;
  BaseSize: TSize;
  BaseText: string;
  Center: TPoint;
  Destination: TRect;
  I: Integer;
  IdentityTransform: TXForm;
  Item: TDisplayPlacementItem;
  R: TRect;
  RubyHeight: Integer;
  RubySpacing: Integer;
  RubyStyle: Byte;
  RubySize: TSize;
  RubyText: string;
  Scale: Double;
  WorldTransform: TXForm;
begin
  Destination := PreviewDestinationRect;
  FBackground.DrawAt(FPreview.Canvas, FPreview.ClientRect, Destination);
  Scale := PreviewScale;
  for I := 0 to Min(High(FUnits), High(FCurrentPlacements)) do
  begin
    Item := FCurrentPlacements[I];
    Center.X := Destination.Left + Destination.Width div 2 +
      Round(Item.X * Scale);
    Center.Y := Destination.Top + Destination.Height div 2 +
      Round(Item.Y * Scale);
    BaseText := DisplayUnitBaseText(I);
    FPreview.Canvas.Font.Name := FCurrentCommon.BaseFontName;
    if Item.BaseFontName <> '' then
      FPreview.Canvas.Font.Name := Item.BaseFontName;
    BaseHeight := FCurrentCommon.BaseFontHeight;
    if Item.HasBaseFontHeight then
      BaseHeight := Item.BaseFontHeight;
    FPreview.Canvas.Font.Height := -Max(1, BaseHeight);
    BaseStyle := FCurrentCommon.BaseFontStyle;
    if Item.HasBaseFontStyle then BaseStyle := Item.BaseFontStyle;
    FPreview.Canvas.Font.Style := CharacterFontStyle(BaseStyle);
    BaseSpacing := 0;
    if Item.HasBaseCharacterSpacing then
      BaseSpacing := Item.BaseCharacterSpacing;
    SetTextCharacterExtra(FPreview.Canvas.Handle, BaseSpacing);
    FPreview.Canvas.Font.Color := TColor(FCurrentCommon.BeforeColor);
    if Item.HasBeforeColor then
      FPreview.Canvas.Font.Color := TColor(Item.BeforeColor);
    BaseSize := FPreview.Canvas.TextExtent(BaseText);
    RubyText := DisplayUnitRubyText(I);
    RubySize.cx := 0;
    RubySize.cy := 0;
    RubyHeight := FCurrentCommon.RubyFontHeight;
    RubySpacing := 0;
    RubyStyle := FCurrentCommon.RubyFontStyle;
    if RubyText <> '' then
    begin
      FPreview.Canvas.Font.Name := FCurrentCommon.RubyFontName;
      if Item.RubyFontName <> '' then
        FPreview.Canvas.Font.Name := Item.RubyFontName;
      if Item.HasRubyFontHeight then
        RubyHeight := Item.RubyFontHeight;
      FPreview.Canvas.Font.Height := -Max(1, RubyHeight);
      if Item.HasRubyFontStyle then RubyStyle := Item.RubyFontStyle;
      FPreview.Canvas.Font.Style := CharacterFontStyle(RubyStyle);
      if Item.HasRubyCharacterSpacing then
        RubySpacing := Item.RubyCharacterSpacing;
      SetTextCharacterExtra(FPreview.Canvas.Handle, RubySpacing);
      RubySize := FPreview.Canvas.TextExtent(RubyText);
    end;
    SetGraphicsMode(FPreview.Canvas.Handle, GM_ADVANCED);
    FillChar(WorldTransform, SizeOf(WorldTransform), 0);
    WorldTransform.eM11 := Scale * Item.ScaleX;
    WorldTransform.eM22 := Scale * Item.ScaleY;
    WorldTransform.eDx := Center.X;
    WorldTransform.eDy := Center.Y;
    if SetWorldTransform(FPreview.Canvas.Handle, WorldTransform) then
    try
      FPreview.Canvas.Brush.Style := bsClear;
      if RubyText <> '' then
      begin
        FPreview.Canvas.Font.Name := FCurrentCommon.RubyFontName;
        if Item.RubyFontName <> '' then
          FPreview.Canvas.Font.Name := Item.RubyFontName;
        FPreview.Canvas.Font.Height := -Max(1, RubyHeight);
        FPreview.Canvas.Font.Style := CharacterFontStyle(RubyStyle);
        SetTextCharacterExtra(FPreview.Canvas.Handle, RubySpacing);
        FPreview.Canvas.TextOut(-RubySize.cx div 2 +
          IfThen(Item.HasRubyOffsetX, Item.RubyOffsetX, 0),
          -BaseSize.cy div 2 - RubySize.cy -
            (4 + FCurrentCommon.RubyGapAdjustment) +
            IfThen(Item.HasRubyOffsetY, Item.RubyOffsetY, 0),
          RubyText);
      end;
      FPreview.Canvas.Font.Name := FCurrentCommon.BaseFontName;
      if Item.BaseFontName <> '' then
        FPreview.Canvas.Font.Name := Item.BaseFontName;
      FPreview.Canvas.Font.Height := -Max(1, BaseHeight);
      FPreview.Canvas.Font.Style := CharacterFontStyle(BaseStyle);
      SetTextCharacterExtra(FPreview.Canvas.Handle, BaseSpacing);
      FPreview.Canvas.TextOut(-BaseSize.cx div 2,
        -BaseSize.cy div 2, BaseText);
    finally
      FillChar(IdentityTransform, SizeOf(IdentityTransform), 0);
      IdentityTransform.eM11 := 1;
      IdentityTransform.eM22 := 1;
      SetWorldTransform(FPreview.Canvas.Handle, IdentityTransform);
      SetTextCharacterExtra(FPreview.Canvas.Handle, 0);
    end;
    R := PreviewElementBounds(I);
    FPreview.Canvas.Brush.Style := bsClear;
    if (I < Length(FSelected)) and FSelected[I] then
      FPreview.Canvas.Pen.Color :=
        CharacterLayoutSelectionColor(FSelectionMode)
    else
      FPreview.Canvas.Pen.Color := RGB(90, 90, 90);
    FPreview.Canvas.Rectangle(R);
  end;
  if SelectionCount > 0 then
  begin
    R := GroupSelectionBounds;
    FPreview.Canvas.Brush.Style := bsClear;
    FPreview.Canvas.Pen.Color :=
      CharacterLayoutSelectionColor(FSelectionMode);
    FPreview.Canvas.Pen.Width := 1;
    if SelectionCount > 1 then
      FPreview.Canvas.Pen.Style := psDash;
    FPreview.Canvas.Rectangle(R);
    FPreview.Canvas.Pen.Style := psSolid;
    if FSelectionMode in [clsmCharacterSpacing, clsmRuby] then
      DrawCharacterLayoutSpacingHandles(FPreview.Canvas, R,
        FSelectionMode = clsmRuby)
    else
      DrawCharacterLayoutResizeHandles(FPreview.Canvas, R);
  end;
  if FSelectingRectangle then
  begin
    R := Rect(Min(FSelectionStart.X, FSelectionCurrent.X),
      Min(FSelectionStart.Y, FSelectionCurrent.Y),
      Max(FSelectionStart.X, FSelectionCurrent.X),
      Max(FSelectionStart.Y, FSelectionCurrent.Y));
    FPreview.Canvas.Brush.Style := bsClear;
    FPreview.Canvas.Pen.Color := clWhite;
    FPreview.Canvas.Pen.Style := psDot;
    FPreview.Canvas.Rectangle(R);
    FPreview.Canvas.Pen.Style := psSolid;
  end;
end;

function TFrameLyricsCharacterDisplaySettingsPage.SelectedElementIndex:
  Integer;
begin
  Result := -1;
  if (FCurrentCandidate >= 0) and
    (FCurrentCandidate < Length(FCandidateSelections)) then
    Result := FCandidateSelections[FCurrentCandidate];
end;

function TFrameLyricsCharacterDisplaySettingsPage.SelectedElementCount:
  Integer;
begin
  Result := SelectionCount;
end;

function TFrameLyricsCharacterDisplaySettingsPage.SelectedMode:
  TCharacterLayoutSelectionMode;
begin
  Result := FSelectionMode;
end;

function TFrameLyricsCharacterDisplaySettingsPage.ViewPan: TPointF;
begin
  Result := FViewPan;
end;

function TFrameLyricsCharacterDisplaySettingsPage.ViewZoom: Double;
begin
  Result := FViewZoom;
end;

function TFrameLyricsCharacterDisplaySettingsPage.TryBuildCandidateSettingsTexts(
  out SettingsTexts: TArray<string>): Boolean;
var
  I: Integer;
begin
  StoreCurrentCandidate;
  SetLength(SettingsTexts, Length(FCandidateLyrics));
  for I := 0 to High(SettingsTexts) do
  begin
    if (I >= Length(FCandidateCommon)) or
      (I >= Length(FCandidatePlacements)) or
      not TryEncodeDisplaySettingsText(FCandidateLyrics[I],
        FCandidateCommon[I], FCandidatePlacements[I],
        SettingsTexts[I]) then
      Exit(False);
  end;
  Result := True;
end;

function TFrameLyricsCharacterDisplaySettingsPage.SelectedLyrics: string;
begin
  Result := FCurrentLyrics;
end;

function TFrameLyricsCharacterDisplaySettingsPage.SelectedDecorationSettings:
  TDisplayCommonSettings;
var
  Index: Integer;
  Item: TDisplayPlacementItem;
begin
  Result := FCurrentCommon;
  Index := SelectedElementIndex;
  if (Index < 0) or (Index >= Length(FCurrentPlacements)) then
    Exit;
  Item := FCurrentPlacements[Index];
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
  if Item.HasShadowEnabled then
    Result.ShadowEnabled := Item.ShadowEnabled;
  if Item.HasShadowOffsetX then Result.ShadowOffsetX := Item.ShadowOffsetX;
  if Item.HasShadowOffsetY then Result.ShadowOffsetY := Item.ShadowOffsetY;
  if Item.HasShadowBlur then Result.ShadowBlur := Item.ShadowBlur;
  if Item.HasShadowSpread then Result.ShadowSpread := Item.ShadowSpread;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.ApplySelectedDecoration(
  const Settings: TDisplayCommonSettings);
var
  I: Integer;
  Item: TDisplayPlacementItem;
begin
  for I := 0 to High(FSelected) do
    if FSelected[I] then
    begin
      Item := FCurrentPlacements[I];
      Item.BeforeColor := Settings.BeforeColor;
      Item.HasBeforeColor := Settings.BeforeColor <> FCurrentCommon.BeforeColor;
      Item.AfterColor := Settings.AfterColor;
      Item.HasAfterColor := Settings.AfterColor <> FCurrentCommon.AfterColor;
      Item.BeforeOpacity := Settings.BeforeOpacity;
      Item.HasBeforeOpacity := Settings.BeforeOpacity <>
        FCurrentCommon.BeforeOpacity;
      Item.AfterOpacity := Settings.AfterOpacity;
      Item.HasAfterOpacity := Settings.AfterOpacity <>
        FCurrentCommon.AfterOpacity;
      Item.BeforeOutlineColor := Settings.BeforeOutlineColor;
      Item.HasBeforeOutlineColor := Settings.BeforeOutlineColor <>
        FCurrentCommon.BeforeOutlineColor;
      Item.AfterOutlineColor := Settings.AfterOutlineColor;
      Item.HasAfterOutlineColor := Settings.AfterOutlineColor <>
        FCurrentCommon.AfterOutlineColor;
      Item.BeforeOutlineOpacity := Settings.BeforeOutlineOpacity;
      Item.HasBeforeOutlineOpacity := Settings.BeforeOutlineOpacity <>
        FCurrentCommon.BeforeOutlineOpacity;
      Item.AfterOutlineOpacity := Settings.AfterOutlineOpacity;
      Item.HasAfterOutlineOpacity := Settings.AfterOutlineOpacity <>
        FCurrentCommon.AfterOutlineOpacity;
      Item.BeforeShadowColor := Settings.BeforeShadowColor;
      Item.HasBeforeShadowColor := Settings.BeforeShadowColor <>
        FCurrentCommon.BeforeShadowColor;
      Item.AfterShadowColor := Settings.AfterShadowColor;
      Item.HasAfterShadowColor := Settings.AfterShadowColor <>
        FCurrentCommon.AfterShadowColor;
      Item.BeforeShadowOpacity := Settings.BeforeShadowOpacity;
      Item.HasBeforeShadowOpacity := Settings.BeforeShadowOpacity <>
        FCurrentCommon.BeforeShadowOpacity;
      Item.AfterShadowOpacity := Settings.AfterShadowOpacity;
      Item.HasAfterShadowOpacity := Settings.AfterShadowOpacity <>
        FCurrentCommon.AfterShadowOpacity;
      Item.BeforeBlurColor := Settings.BeforeBlurColor;
      Item.HasBeforeBlurColor := Settings.BeforeBlurColor <>
        FCurrentCommon.BeforeBlurColor;
      Item.AfterBlurColor := Settings.AfterBlurColor;
      Item.HasAfterBlurColor := Settings.AfterBlurColor <>
        FCurrentCommon.AfterBlurColor;
      Item.BeforeBlurOpacity := Settings.BeforeBlurOpacity;
      Item.HasBeforeBlurOpacity := Settings.BeforeBlurOpacity <>
        FCurrentCommon.BeforeBlurOpacity;
      Item.AfterBlurOpacity := Settings.AfterBlurOpacity;
      Item.HasAfterBlurOpacity := Settings.AfterBlurOpacity <>
        FCurrentCommon.AfterBlurOpacity;
      Item.OutlineEnabled := Settings.OutlineEnabled;
      Item.HasOutlineEnabled := Settings.OutlineEnabled <>
        FCurrentCommon.OutlineEnabled;
      Item.OutlineWidth := Settings.OutlineWidth;
      Item.HasOutlineWidth := Abs(Settings.OutlineWidth -
        FCurrentCommon.OutlineWidth) > 0.0001;
      Item.OutlineBlur := Settings.OutlineBlur;
      Item.HasOutlineBlur := Abs(Settings.OutlineBlur -
        FCurrentCommon.OutlineBlur) > 0.0001;
      Item.ShadowEnabled := Settings.ShadowEnabled;
      Item.HasShadowEnabled := Settings.ShadowEnabled <>
        FCurrentCommon.ShadowEnabled;
      Item.ShadowOffsetX := Settings.ShadowOffsetX;
      Item.HasShadowOffsetX := Abs(Settings.ShadowOffsetX -
        FCurrentCommon.ShadowOffsetX) > 0.0001;
      Item.ShadowOffsetY := Settings.ShadowOffsetY;
      Item.HasShadowOffsetY := Abs(Settings.ShadowOffsetY -
        FCurrentCommon.ShadowOffsetY) > 0.0001;
      Item.ShadowBlur := Settings.ShadowBlur;
      Item.HasShadowBlur := Abs(Settings.ShadowBlur -
        FCurrentCommon.ShadowBlur) > 0.0001;
      Item.ShadowSpread := Settings.ShadowSpread;
      Item.HasShadowSpread := Abs(Settings.ShadowSpread -
        FCurrentCommon.ShadowSpread) > 0.0001;
      FCurrentPlacements[I] := Item;
    end;
  StoreCurrentCandidate;
  UpdateSelectedControls;
  FPreview.Invalidate;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.SetBackgroundRgba(
  const Pixels: TBytes; Width, Height: Integer);
begin
  FBackgroundPixels := Copy(Pixels);
  FBackgroundPixelWidth := Width;
  FBackgroundPixelHeight := Height;
  FBackground.SetRgba(Pixels, Width, Height);
  FPreview.Invalidate;
end;

procedure TFrameLyricsCharacterDisplaySettingsPage.Resize;
var
  Extent: Integer;
  Gap: Integer;
  Margin: Integer;
  TopValue: Integer;
begin
  inherited;
  if not FLayoutReady then
    Exit;
  Margin := MulDiv(12, CurrentPPI, 96);
  Gap := MulDiv(12, CurrentPPI, 96);
  Extent := MulDiv(28, CurrentPPI, 96);
  FBaseFontLabel.SetBounds(Margin, MulDiv(9, CurrentPPI, 96),
    MulDiv(76, CurrentPPI, 96), MulDiv(20, CurrentPPI, 96));
  FBaseFontCombo.SetBounds(Margin + MulDiv(80, CurrentPPI, 96),
    MulDiv(4, CurrentPPI, 96), MulDiv(150, CurrentPPI, 96),
    MulDiv(24, CurrentPPI, 96));
  FRubyFontLabel.SetBounds(FBaseFontCombo.Left + FBaseFontCombo.Width +
    MulDiv(18, CurrentPPI, 96), FBaseFontLabel.Top,
    MulDiv(76, CurrentPPI, 96), FBaseFontLabel.Height);
  FRubyFontCombo.SetBounds(FRubyFontLabel.Left + MulDiv(80, CurrentPPI, 96),
    FBaseFontCombo.Top, MulDiv(150, CurrentPPI, 96),
    FBaseFontCombo.Height);
  FFormattingToolbar.ButtonExtent := Extent;
  FFormattingToolbar.SetBounds(FRubyFontCombo.Left + FRubyFontCombo.Width +
    MulDiv(16, CurrentPPI, 96), MulDiv(2, CurrentPPI, 96),
    Max(1, ClientWidth - FRubyFontCombo.Left - FRubyFontCombo.Width -
      Margin - MulDiv(16, CurrentPPI, 96)), Extent);
  FElementLabel.SetBounds(Margin, Extent + MulDiv(11, CurrentPPI, 96),
    MulDiv(64, CurrentPPI, 96), MulDiv(20, CurrentPPI, 96));
  FElementCombo.SetBounds(FElementLabel.Left + FElementLabel.Width,
    Extent + MulDiv(6, CurrentPPI, 96), MulDiv(180, CurrentPPI, 96),
    MulDiv(24, CurrentPPI, 96));
  FActionToolbar.ButtonExtent := Extent;
  FActionToolbar.SetBounds(FElementCombo.Left + FElementCombo.Width + Gap,
    Extent + MulDiv(4, CurrentPPI, 96),
    Max(1, ClientWidth - FElementCombo.Left - FElementCombo.Width -
      Gap - Margin), Extent);
  TopValue := Extent * 2 + MulDiv(14, CurrentPPI, 96);
  FColorPanel.SetBounds(ClientWidth - Margin - MulDiv(188, CurrentPPI, 96),
    TopValue, MulDiv(188, CurrentPPI, 96),
    Max(1, ClientHeight - TopValue - Margin));
  FPreview.SetBounds(Margin, TopValue,
    Max(1, FColorPanel.Left - Gap - Margin), FColorPanel.Height);
end;

end.
