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
  Vcl.StdCtrls,
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_ToolbarButtons;

type
  TLineDisplaySelection = (ldsBase, ldsRuby);
  TLineDisplayDragMode = (lddNone, lddMoveGroup, lddRubyGap,
    lddResizeTopLeft, lddResizeTopRight, lddResizeBottomLeft,
    lddResizeBottomRight, lddSpacingLeft, lddSpacingRight);

  TFormLyricsLineDisplaySettings = class(TForm)
    CandidateLabel: TLabel;
    CandidateCombo: TComboBox;
    DescriptionLabel: TLabel;
    LyricsLabel: TLabel;
    LyricsEdit: TEdit;
    SelectionLabel: TLabel;
    BaseFontLabel: TLabel;
    BaseFontCombo: TComboBox;
    RubyFontLabel: TLabel;
    RubyFontCombo: TComboBox;
    PreviewPaintBox: TPaintBox;
    ButtonPanel: TPanel;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure CandidateComboChange(Sender: TObject);
    procedure BaseFontComboChange(Sender: TObject);
    procedure RubyFontComboChange(Sender: TObject);
    procedure LyricsEditChange(Sender: TObject);
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
    FToolbar: TSyncLyricsToolbarButtons;
    FToolbarAfterColor: TSyncLyricsToolbarButton;
    FToolbarBeforeColor: TSyncLyricsToolbarButton;
    FToolbarBold: TSyncLyricsToolbarButton;
    FToolbarItalic: TSyncLyricsToolbarButton;
    FToolbarStrikeOut: TSyncLyricsToolbarButton;
    FToolbarUnderline: TSyncLyricsToolbarButton;
    FUpdatingControls: Boolean;
    FCandidateLyrics: TArray<string>;
    FCandidateSettings: TArray<TDisplayCommonSettings>;
    function BackgroundDestinationRect: TRect;
    function BackgroundScale: Double;
    procedure CalculateLayout(Canvas: TCanvas; DrawText: Boolean);
    procedure CreateFormattingToolbar;
    procedure DrawSelection(Canvas: TCanvas);
    function HitTestDragMode(const Point: TPoint): TLineDisplayDragMode;
    function RubySpacingIntervalCount: Integer;
    procedure StartDrag(Mode: TLineDisplayDragMode; const Point: TPoint);
    procedure UpdateDrag(const Point: TPoint);
    procedure ParseCurrentLyrics;
    procedure ToolbarButtonExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure UpdateFontCombos;
    procedure UpdateFormattingControls;
    procedure UpdateSelectionLabel;
  public
    procedure Configure(const Lyrics: string;
      const CommonSettings: TDisplayCommonSettings);
    procedure ConfigureCandidates(const Captions, Lyrics: TArray<string>;
      const CommonSettings: TArray<TDisplayCommonSettings>;
      InitialIndex: Integer);
    function EnteredLyrics: string;
    function SelectedCandidateIndex: Integer;
    function SelectedCommonSettings: TDisplayCommonSettings;
    procedure SetLyricsEditingEnabled(Value: Boolean);
    procedure SetBackgroundRgba(const Pixels: TBytes;
      Width, Height: Integer);
  end;

implementation

uses
  ColorPickerDialog,
  System.Math,
  Winapi.Windows;

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
  TOOLBAR_BOLD = 2;
  TOOLBAR_ITALIC = 3;
  TOOLBAR_UNDERLINE = 4;
  TOOLBAR_STRIKE_OUT = 5;
  TOOLBAR_BEFORE_COLOR = 6;
  TOOLBAR_AFTER_COLOR = 7;

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
  FBaseFontStyle := CommonSettings.BaseFontStyle;
  FRubyFontStyle := CommonSettings.RubyFontStyle;
  LyricsEdit.Text := Lyrics;
  ParseCurrentLyrics;
  LyricsEdit.SelectAll;
  UpdateFontCombos;
  UpdateFormattingControls;
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
  SetLyricsEditingEnabled(False);
end;

procedure TFormLyricsLineDisplaySettings.CreateFormattingToolbar;
var
  Extent: Integer;
begin
  Extent := MulDiv(28, CurrentPPI, 96);
  FToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FToolbar.Parent := Self;
  FToolbar.SetBounds(DescriptionLabel.Left,
    BaseFontCombo.Top + BaseFontCombo.Height + MulDiv(6, CurrentPPI, 96),
    ClientWidth - DescriptionLabel.Left * 2, Extent);
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
  FToolbarBeforeColor := FToolbar.AddDialogButton(
    #34892#20849#36890#12398#21516#26399#21069#33394,
    tbgBeforeColor, TOOLBAR_BEFORE_COLOR);
  FToolbarAfterColor := FToolbar.AddDialogButton(
    #34892#20849#36890#12398#21516#26399#24460#33394,
    tbgAfterColor, TOOLBAR_AFTER_COLOR);
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

function TFormLyricsLineDisplaySettings.EnteredLyrics: string;
begin
  Result := LyricsEdit.Text;
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
  Result.RubyGapAdjustment := FRubyGapAdjustment;
  Result.BaseCharacterSpacing := FBaseCharacterSpacing;
  Result.RubyCharacterSpacing := FRubyCharacterSpacing;
end;

procedure TFormLyricsLineDisplaySettings.SetLyricsEditingEnabled(
  Value: Boolean);
begin
  LyricsEdit.ReadOnly := not Value;
  LyricsEdit.TabStop := Value;
end;

procedure TFormLyricsLineDisplaySettings.FormCreate(Sender: TObject);
begin
  DescriptionLabel.Caption :=
    UnicodeString(
      '本文内ドラッグ: 移動 / ルビ内: 間隔 / 四隅: サイズ / 左右点: 字間');
  FBackground := Vcl.Graphics.TBitmap.Create;
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
  FBeforeColor := clWhite;
  FAfterColor := RGB(0, 255, 255);
  FSelection := ldsBase;
  FUpdatingControls := False;
  DoubleBuffered := True;
  BaseFontCombo.Items.Assign(Screen.Fonts);
  RubyFontCombo.Items.Assign(Screen.Fonts);
  CreateFormattingToolbar;
  ParseCurrentLyrics;
  UpdateSelectionLabel;
  UpdateFormattingControls;
end;

procedure TFormLyricsLineDisplaySettings.FormDestroy(Sender: TObject);
begin
  FBackground.Free;
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

procedure TFormLyricsLineDisplaySettings.LyricsEditChange(Sender: TObject);
begin
  ParseCurrentLyrics;
  PreviewPaintBox.Invalidate;
end;

procedure TFormLyricsLineDisplaySettings.ParseCurrentLyrics;
begin
  FLyrics := LyricsEdit.Text;
  ParseLyrics(FLyrics, FPlainText, FRubySpans);
  if (FSelection = ldsRuby) and (Length(FRubySpans) = 0) then
    FSelection := ldsBase;
  UpdateSelectionLabel;
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
      UpdateSelectionLabel;
      UpdateFormattingControls;
      PreviewPaintBox.Invalidate;
      StartDrag(lddRubyGap, Point);
      Exit;
    end;
  if FBaseBounds.Contains(Point) then
  begin
    FSelection := ldsBase;
    UpdateSelectionLabel;
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
    lddMoveGroup:
      PreviewPaintBox.Cursor := crSizeAll;
    lddRubyGap:
      PreviewPaintBox.Cursor := crSizeNS;
    lddSpacingLeft, lddSpacingRight:
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
  ColorValue: TColor;
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
    TOOLBAR_BEFORE_COLOR:
      begin
        ColorValue := FBeforeColor;
        if not ExecuteColorPicker(Self, ColorValue) then
          Exit;
        FBeforeColor := ColorToRGB(ColorValue);
      end;
    TOOLBAR_AFTER_COLOR:
      begin
        ColorValue := FAfterColor;
        if not ExecuteColorPicker(Self, ColorValue) then
          Exit;
        FAfterColor := ColorToRGB(ColorValue);
      end;
  end;
  UpdateFormattingControls;
  PreviewPaintBox.Invalidate;
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
    FToolbarBeforeColor.AccentColor := FBeforeColor;
    FToolbarBeforeColor.HasAccentColor := True;
    FToolbarAfterColor.AccentColor := FAfterColor;
    FToolbarAfterColor.HasAccentColor := True;
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
  UpdateSelectionLabel;
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

  Canvas.Font.Name := FBaseFontName;
  Canvas.Font.Height := -Max(1, Round(FBaseFontHeight * Scale));
  Canvas.Font.Style := FontStylesFromByte(FBaseFontStyle);
  Canvas.Font.Color := FBeforeColor;
  SetTextCharacterExtra(Canvas.Handle,
    Round(FBaseCharacterSpacing * Scale));
  if DrawText then
    Canvas.TextOut(BaseX, BaseY, FPlainText);
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
        Canvas.TextOut(RubyX, RubyY, FRubySpans[I].RubyText);
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

procedure TFormLyricsLineDisplaySettings.UpdateSelectionLabel;
begin
  if FSelection = ldsRuby then
    SelectionLabel.Caption := Format(UnicodeString(
      '選択中: ルビ全体  サイズ %d  字間 %d  間隔補正 %d'),
      [FRubyFontHeight, FRubyCharacterSpacing, FRubyGapAdjustment])
  else
    SelectionLabel.Caption := Format(UnicodeString(
      '選択中: 本文全体  サイズ %d  字間 %d  位置 (%d, %d)'),
      [FBaseFontHeight, FBaseCharacterSpacing, FPositionX, FPositionY]);
end;

end.
