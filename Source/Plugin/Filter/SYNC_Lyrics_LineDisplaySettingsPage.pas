unit SYNC_Lyrics_LineDisplaySettingsPage;

// Display-only first migration page for line placement settings.

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
  TextRendererSkia,
  TextRendererTypes,
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_DisplayPreviewBackground,
  SYNC_Lyrics_DisplaySettingsColorPanel,
  SYNC_Lyrics_DisplaySettingsModePage,
  SYNC_Lyrics_ToolbarButtons;

type
  TLineDisplayPageSelection = (ldpsBase, ldpsRuby);
  TLineDisplayPageDragMode = (ldpdNone, ldpdPan, ldpdMove, ldpdResize,
    ldpdSpacingLeft, ldpdSpacingRight, ldpdRubyGap, ldpdOutlineBlur,
    ldpdOutlineWidth, ldpdShadowBlur, ldpdShadowOffset,
    ldpdShadowSpread);

  TFrameLyricsLineDisplaySettingsPage = class(TFrameDisplaySettingsModePage)
  private
    FFormattingButtons: array[0..3] of TSyncLyricsToolbarButton;
    FBaseFontCombo: TComboBox;
    FBaseFontLabel: TLabel;
    FBasePreviewBounds: TRect;
    FBackground: TDisplayPreviewBackground;
    FCandidateCommon: TArray<TDisplayCommonSettings>;
    FCandidateLyrics: TArray<string>;
    FColorTarget: Integer;
    FCurrentCandidate: Integer;
    FCurrentCommon: TDisplayCommonSettings;
    FCurrentLyrics: string;
    FDragMode: TLineDisplayPageDragMode;
    FDragStartBaseCharacterSpacing: Integer;
    FDragStartFontHeight: Integer;
    FDragStartOutlineBlur: Single;
    FDragStartOutlineWidth: Single;
    FDragStartPoint: TPoint;
    FDragStartPositionX: Integer;
    FDragStartPositionY: Integer;
    FDragStartRubyCharacterSpacing: Integer;
    FDragStartRubyGapAdjustment: Integer;
    FDragStartShadowBlur: Single;
    FDragStartShadowOffsetX: Single;
    FDragStartShadowOffsetY: Single;
    FDragStartShadowSpread: Single;
    FDragStartViewPan: TPointF;
    FActionToolbar: TSyncLyricsToolbarButtons;
    FColorPanel: TDisplaySettingsColorPanel;
    FFormattingToolbar: TSyncLyricsToolbarButtons;
    FInitialCandidate: Integer;
    FInitialCandidateCommon: TArray<TDisplayCommonSettings>;
    FInitialCandidateLyrics: TArray<string>;
    FLayoutReady: Boolean;
    FOutlineButton: TSyncLyricsToolbarButton;
    FPreview: TPaintBox;
    FPreviewRenderer: TSkiaTextRenderer;
    FRubyFontCombo: TComboBox;
    FRubyFontLabel: TLabel;
    FRubyPreviewBounds: TRect;
    FRubyPreviewRects: TArray<TRect>;
    FSelection: TLineDisplayPageSelection;
    FShadowButton: TSyncLyricsToolbarButton;
    FUpdatingControls: Boolean;
    FViewPan: TPointF;
    FViewZoom: Double;
    procedure ActionToolbarExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure FontComboChange(Sender: TObject);
    procedure ColorPanelChange(Sender: TObject);
    procedure ColorTargetChange(Sender: TObject);
    procedure FormattingToolbarExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    function SelectedFontStyle: Byte;
    procedure SetSelectedFontStyle(Value: Byte);
    procedure StoreCurrentCandidate;
    procedure UpdateColorPanel;
    procedure UpdateControls;
    procedure ComboDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure PreviewPaint(Sender: TObject);
    procedure PreviewMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PreviewMouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer);
    procedure PreviewMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PreviewMouseLeave(Sender: TObject);
    procedure PreviewMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    function PreviewBackgroundScale: Double;
    function PreviewDestinationRect: TRect;
    function BaseSpacingIntervalCount: Integer;
    function CreatePreviewBitmap(Image: TTextRenderImage):
      Vcl.Graphics.TBitmap;
    procedure DrawDecorationHandles(Canvas: TCanvas);
    procedure DrawHalfSyncedText(Canvas: TCanvas; X, Y: Integer;
      const Text: string; TransitionX, CharacterSpacing: Integer);
    procedure DrawPreviewImage(Canvas: TCanvas; Image,
      AnchorImage: TTextRenderImage; X, Y, TransitionX: Integer;
      AfterPhase: Boolean);
    function HitTestDragMode(const PointValue: TPoint):
      TLineDisplayPageDragMode;
    function ResizeHandleRect(const Bounds: TRect): TRect;
    function RenderPreviewTextImage(Canvas: TCanvas; const Text: string;
      CharacterSpacing: Integer; AfterPhase,
      IncludeDecoration: Boolean): TTextRenderImage;
    function RubySpacingIntervalCount: Integer;
    function SpacingHandleRect(const Bounds: TRect;
      LeftSide: Boolean): TRect;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AdjustPreviewZoom(WheelDelta: Integer;
      const ClientPoint: TPoint);
    procedure CaptureInitialState; override;
    procedure CandidateChanged(Index: Integer); override;
    function CandidateCommonSettings: TArray<TDisplayCommonSettings>;
    function CandidateLyrics: TArray<string>;
    procedure ConfigureCandidates(const Lyrics: TArray<string>;
      const CommonSettings: TArray<TDisplayCommonSettings>;
      InitialIndex: Integer);
    function DecorationHandleRect(Mode: TLineDisplayPageDragMode): TRect;
    function ModeGlyph: TSyncLyricsToolbarGlyph; override;
    function ModeID: Integer; override;
    function ModeName: string; override;
    function SelectedCommonSettings: TDisplayCommonSettings;
    function SelectedLyrics: string;
    function HasBackgroundImage: Boolean;
    function HasSkiaPreviewRenderer: Boolean;
    function RubyPreviewRect(Index: Integer): TRect;
    function RubyPreviewRectCount: Integer;
    procedure RestoreInitialState; override;
    procedure SetBackgroundRgba(const Pixels: TBytes;
      Width, Height: Integer);
    property BaseFontCombo: TComboBox read FBaseFontCombo;
    property RubyFontCombo: TComboBox read FRubyFontCombo;
    property BasePreviewBounds: TRect read FBasePreviewBounds;
    property ColorPanel: TDisplaySettingsColorPanel read FColorPanel;
    property ActionToolbar: TSyncLyricsToolbarButtons read FActionToolbar;
    property FormattingToolbar: TSyncLyricsToolbarButtons
      read FFormattingToolbar;
    property OutlineButton: TSyncLyricsToolbarButton read FOutlineButton;
    property Preview: TPaintBox read FPreview;
    property RubyPreviewBounds: TRect read FRubyPreviewBounds;
    property ShadowButton: TSyncLyricsToolbarButton read FShadowButton;
    property ViewPan: TPointF read FViewPan;
    property ViewZoom: Double read FViewZoom;
  end;

implementation

{$R *.dfm}

uses
  System.Math,
  Winapi.Windows,
  TextRendererSkiaRuntime,
  SYNC_Lyrics_DarkTheme,
  SYNC_Lyrics_LyricParser;

type
  TDisplayPageControlAccess = class(TControl);

constructor TFrameLyricsLineDisplaySettingsPage.Create(AOwner: TComponent);
var
  FontName: string;
begin
  inherited Create(AOwner);
  Name := 'FrameLyricsLineDisplaySettingsPage';
  FBackground := TDisplayPreviewBackground.Create;
  FPreviewRenderer := nil;
  if TTextRendererSkiaRuntime.IsAcquired then
    try
      FPreviewRenderer := TSkiaTextRenderer.Create;
    except
      FPreviewRenderer := nil;
    end;
  FBaseFontLabel := TLabel.Create(Self);
  FBaseFontLabel.Parent := Self;
  FBaseFontLabel.Caption := #27468#35422#12501#12457#12531#12488;
  FBaseFontLabel.Font.Assign(Font);
  FBaseFontCombo := TComboBox.Create(Self);
  FBaseFontCombo.Parent := Self;
  FBaseFontCombo.Items.Assign(Screen.Fonts);
  FontName := 'Yu Gothic UI';
  FBaseFontCombo.ItemIndex := FBaseFontCombo.Items.IndexOf(FontName);
  FBaseFontCombo.OnChange := FontComboChange;
  FRubyFontLabel := TLabel.Create(Self);
  FRubyFontLabel.Parent := Self;
  FRubyFontLabel.Caption := #12523#12499#12501#12457#12531#12488;
  FRubyFontLabel.Font.Assign(Font);
  FRubyFontCombo := TComboBox.Create(Self);
  FRubyFontCombo.Parent := Self;
  FRubyFontCombo.Items.Assign(Screen.Fonts);
  FRubyFontCombo.ItemIndex := FRubyFontCombo.Items.IndexOf(FontName);
  FRubyFontCombo.OnChange := FontComboChange;

  FFormattingToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FFormattingToolbar.Parent := Self;
  FFormattingToolbar.Color := Color;
  FFormattingToolbar.ParentBackground := False;
  FFormattingToolbar.OnButtonExecute := FormattingToolbarExecute;
  FFormattingButtons[0] := FFormattingToolbar.AddToggleButton(
    #22826#23383, tbgBold, 1);
  FFormattingButtons[1] := FFormattingToolbar.AddToggleButton(
    #26012#20307, tbgItalic, 2);
  FFormattingButtons[2] := FFormattingToolbar.AddToggleButton(
    #19979#32218, tbgUnderline, 4);
  FFormattingButtons[3] := FFormattingToolbar.AddToggleButton(
    #21462#12426#28040#12375#32218, tbgStrikeOut, 8);
  FActionToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FActionToolbar.Parent := Self;
  FActionToolbar.Color := Color;
  FActionToolbar.ParentBackground := False;
  FActionToolbar.OnButtonExecute := ActionToolbarExecute;
  FOutlineButton := FActionToolbar.AddToggleButton(
    #32257#21462#12426, tbgOutline, 100);
  FShadowButton := FActionToolbar.AddToggleButton(
    #24433, tbgShadow, 101);

  FPreview := TPaintBox.Create(Self);
  FPreview.Parent := Self;
  FPreview.OnPaint := PreviewPaint;
  FPreview.OnMouseDown := PreviewMouseDown;
  FPreview.OnMouseLeave := PreviewMouseLeave;
  FPreview.OnMouseMove := PreviewMouseMove;
  FPreview.OnMouseUp := PreviewMouseUp;
  TDisplayPageControlAccess(FPreview).OnMouseWheel := PreviewMouseWheel;
  FColorPanel := TDisplaySettingsColorPanel.Create(Self);
  FColorPanel.Parent := Self;
  FColorPanel.OnChange := ColorPanelChange;
  FColorPanel.OnTargetChange := ColorTargetChange;
  ApplySyncLyricsDarkComboBox(FBaseFontCombo, ComboDrawItem);
  ApplySyncLyricsDarkComboBox(FRubyFontCombo, ComboDrawItem);
  FSelection := ldpsBase;
  FColorTarget := 0;
  FCurrentCandidate := -1;
  FDragMode := ldpdNone;
  FViewPan := TPointF.Zero;
  FViewZoom := 1;
  FCurrentCommon := DefaultDisplayCommonSettings;
  FLayoutReady := True;
  Resize;
end;

destructor TFrameLyricsLineDisplaySettingsPage.Destroy;
begin
  FPreviewRenderer.Free;
  FBackground.Free;
  inherited;
end;

procedure TFrameLyricsLineDisplaySettingsPage.ActionToolbarExecute(
  Sender: TObject; Button: TSyncLyricsToolbarButton);
begin
  if FUpdatingControls then
    Exit;
  case Button.Tag of
    100: FCurrentCommon.OutlineEnabled :=
      Button.CheckState = tbcsChecked;
    101: FCurrentCommon.ShadowEnabled :=
      Button.CheckState = tbcsChecked;
  end;
  FPreview.Invalidate;
end;

procedure TFrameLyricsLineDisplaySettingsPage.CandidateChanged(
  Index: Integer);
begin
  if Index = FCurrentCandidate then
    Exit;
  StoreCurrentCandidate;
  if (Index < 0) or (Index >= Length(FCandidateCommon)) or
    (Index >= Length(FCandidateLyrics)) then
  begin
    FCurrentCandidate := -1;
    Exit;
  end;
  FCurrentCandidate := Index;
  FCurrentCommon := FCandidateCommon[Index];
  FCurrentLyrics := FCandidateLyrics[Index];
  UpdateControls;
end;

procedure TFrameLyricsLineDisplaySettingsPage.CaptureInitialState;
begin
  StoreCurrentCandidate;
  FInitialCandidate := FCurrentCandidate;
  FInitialCandidateLyrics := Copy(FCandidateLyrics);
  FInitialCandidateCommon := Copy(FCandidateCommon);
end;

function TFrameLyricsLineDisplaySettingsPage.CandidateCommonSettings:
  TArray<TDisplayCommonSettings>;
begin
  StoreCurrentCandidate;
  Result := Copy(FCandidateCommon);
end;

function TFrameLyricsLineDisplaySettingsPage.CandidateLyrics:
  TArray<string>;
begin
  Result := Copy(FCandidateLyrics);
end;

procedure TFrameLyricsLineDisplaySettingsPage.ConfigureCandidates(
  const Lyrics: TArray<string>;
  const CommonSettings: TArray<TDisplayCommonSettings>;
  InitialIndex: Integer);
begin
  FCandidateLyrics := Copy(Lyrics);
  FCandidateCommon := Copy(CommonSettings);
  FCurrentCandidate := -1;
  if (Length(FCandidateLyrics) = 0) or
    (Length(FCandidateCommon) = 0) then
    Exit;
  CandidateChanged(EnsureRange(InitialIndex, 0,
    Min(High(FCandidateLyrics), High(FCandidateCommon))));
end;

procedure TFrameLyricsLineDisplaySettingsPage.RestoreInitialState;
begin
  FCandidateLyrics := Copy(FInitialCandidateLyrics);
  FCandidateCommon := Copy(FInitialCandidateCommon);
  FCurrentCandidate := -1;
  if (FInitialCandidate >= 0) and
    (FInitialCandidate < Length(FCandidateLyrics)) and
    (FInitialCandidate < Length(FCandidateCommon)) then
    CandidateChanged(FInitialCandidate)
  else
  begin
    FCurrentLyrics := '';
    FCurrentCommon := DefaultDisplayCommonSettings;
    UpdateControls;
  end;
end;

procedure TFrameLyricsLineDisplaySettingsPage.ComboDrawItem(
  Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
begin
  DrawSyncLyricsDarkComboBoxItem(Control as TComboBox, Index, Rect,
    State, CurrentPPI);
end;

procedure TFrameLyricsLineDisplaySettingsPage.ColorPanelChange(
  Sender: TObject);
var
  AfterColor: Cardinal;
  BeforeColor: Cardinal;
begin
  if FUpdatingControls or (FCurrentCandidate < 0) then
    Exit;
  BeforeColor := Cardinal(ColorToRGB(FColorPanel.BeforePicker.Color));
  AfterColor := Cardinal(ColorToRGB(FColorPanel.AfterPicker.Color));
  case FColorTarget of
    0:
      begin
        FCurrentCommon.BeforeColor := BeforeColor;
        FCurrentCommon.AfterColor := AfterColor;
        FCurrentCommon.BeforeOpacity := FColorPanel.BeforeOpacity;
        FCurrentCommon.AfterOpacity := FColorPanel.AfterOpacity;
      end;
    1:
      begin
        FCurrentCommon.BeforeOutlineColor := BeforeColor;
        FCurrentCommon.AfterOutlineColor := AfterColor;
        FCurrentCommon.BeforeOutlineOpacity := FColorPanel.BeforeOpacity;
        FCurrentCommon.AfterOutlineOpacity := FColorPanel.AfterOpacity;
      end;
    2:
      begin
        FCurrentCommon.BeforeShadowColor := BeforeColor;
        FCurrentCommon.AfterShadowColor := AfterColor;
        FCurrentCommon.BeforeShadowOpacity := FColorPanel.BeforeOpacity;
        FCurrentCommon.AfterShadowOpacity := FColorPanel.AfterOpacity;
      end;
    3:
      begin
        FCurrentCommon.BeforeBlurColor := BeforeColor;
        FCurrentCommon.AfterBlurColor := AfterColor;
        FCurrentCommon.BeforeBlurOpacity := FColorPanel.BeforeOpacity;
        FCurrentCommon.AfterBlurOpacity := FColorPanel.AfterOpacity;
      end;
  end;
  FPreview.Invalidate;
end;

procedure TFrameLyricsLineDisplaySettingsPage.ColorTargetChange(
  Sender: TObject);
begin
  FColorTarget := FColorPanel.TargetIndex;
  UpdateColorPanel;
end;

procedure TFrameLyricsLineDisplaySettingsPage.FontComboChange(
  Sender: TObject);
begin
  if FUpdatingControls or (FCurrentCandidate < 0) then
    Exit;
  if (Sender = FBaseFontCombo) and (FBaseFontCombo.ItemIndex >= 0) then
    FCurrentCommon.BaseFontName := FBaseFontCombo.Text
  else if (Sender = FRubyFontCombo) and (FRubyFontCombo.ItemIndex >= 0) then
    FCurrentCommon.RubyFontName := FRubyFontCombo.Text;
  FPreview.Invalidate;
end;

procedure TFrameLyricsLineDisplaySettingsPage.FormattingToolbarExecute(
  Sender: TObject; Button: TSyncLyricsToolbarButton);
var
  StyleValue: Byte;
begin
  if FUpdatingControls or (FCurrentCandidate < 0) then
    Exit;
  StyleValue := SelectedFontStyle;
  if Button.CheckState = tbcsChecked then
    StyleValue := StyleValue or Byte(Button.Tag)
  else
    StyleValue := StyleValue and not Byte(Button.Tag);
  SetSelectedFontStyle(StyleValue);
  FPreview.Invalidate;
end;

function TFrameLyricsLineDisplaySettingsPage.ModeID: Integer;
begin
  Result := DISPLAY_SETTINGS_MODE_LINE;
end;

function TFrameLyricsLineDisplaySettingsPage.HasBackgroundImage: Boolean;
begin
  Result := (FBackground <> nil) and FBackground.HasImage;
end;

function TFrameLyricsLineDisplaySettingsPage.HasSkiaPreviewRenderer: Boolean;
begin
  Result := FPreviewRenderer <> nil;
end;

function TFrameLyricsLineDisplaySettingsPage.PreviewDestinationRect: TRect;
var
  BaseDestination: TRect;
  DrawHeight: Integer;
  DrawWidth: Integer;
begin
  Result := FPreview.ClientRect;
  if not FBackground.HasImage then
    Exit;
  BaseDestination := FBackground.DestinationRect(FPreview.ClientRect);
  DrawWidth := Max(1, Round(BaseDestination.Width * FViewZoom));
  DrawHeight := Max(1, Round(BaseDestination.Height * FViewZoom));
  Result.Left := FPreview.ClientRect.Left +
    (FPreview.ClientWidth - DrawWidth) div 2 + Round(FViewPan.X);
  Result.Top := FPreview.ClientRect.Top +
    (FPreview.ClientHeight - DrawHeight) div 2 + Round(FViewPan.Y);
  Result.Right := Result.Left + DrawWidth;
  Result.Bottom := Result.Top + DrawHeight;
end;

function TFrameLyricsLineDisplaySettingsPage.PreviewBackgroundScale: Double;
var
  Destination: TRect;
begin
  Result := 1;
  if not FBackground.HasImage or (FBackground.ImageWidth <= 0) then
    Exit;
  Destination := PreviewDestinationRect;
  Result := Destination.Width / FBackground.ImageWidth;
end;

function TFrameLyricsLineDisplaySettingsPage.RubyPreviewRect(
  Index: Integer): TRect;
begin
  if (Index < 0) or (Index >= Length(FRubyPreviewRects)) then
    Exit(TRect.Empty);
  Result := FRubyPreviewRects[Index];
end;

function TFrameLyricsLineDisplaySettingsPage.RubyPreviewRectCount: Integer;
begin
  Result := Length(FRubyPreviewRects);
end;

function TFrameLyricsLineDisplaySettingsPage.ModeGlyph:
  TSyncLyricsToolbarGlyph;
begin
  Result := tbgLinePlacement;
end;

function TFrameLyricsLineDisplaySettingsPage.ModeName: string;
begin
  Result := #49#34892#37197#32622;
end;

function TFrameLyricsLineDisplaySettingsPage.CreatePreviewBitmap(
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

procedure TFrameLyricsLineDisplaySettingsPage.DrawHalfSyncedText(
  Canvas: TCanvas; X, Y: Integer; const Text: string; TransitionX,
  CharacterSpacing: Integer);
var
  AfterImage: TTextRenderImage;
  AnchorImage: TTextRenderImage;
  BeforeImage: TTextRenderImage;
  RenderedWithSkia: Boolean;
  SavedDC: Integer;
begin
  BeforeImage := nil;
  AfterImage := nil;
  AnchorImage := nil;
  RenderedWithSkia := False;
  if FPreviewRenderer <> nil then
    try
      AnchorImage := RenderPreviewTextImage(Canvas, Text, CharacterSpacing,
        False, False);
      BeforeImage := RenderPreviewTextImage(Canvas, Text, CharacterSpacing,
        False, True);
      AfterImage := RenderPreviewTextImage(Canvas, Text, CharacterSpacing,
        True, True);
      if (AnchorImage <> nil) and (BeforeImage <> nil) and
        (AfterImage <> nil) then
      begin
        DrawPreviewImage(Canvas, BeforeImage, AnchorImage, X, Y,
          TransitionX, False);
        DrawPreviewImage(Canvas, AfterImage, AnchorImage, X, Y,
          TransitionX, True);
        RenderedWithSkia := True;
      end;
    except
      { Retain the transparent GDI preview if Skia cannot render a font. }
    end;
  BeforeImage.Free;
  AfterImage.Free;
  AnchorImage.Free;
  if RenderedWithSkia then
    Exit;

  Canvas.Font.Color := TColor(FCurrentCommon.BeforeColor);
  Canvas.TextOut(X, Y, Text);
  SavedDC := SaveDC(Canvas.Handle);
  try
    IntersectClipRect(Canvas.Handle, 0, 0, TransitionX,
      FPreview.ClientHeight);
    Canvas.Font.Color := TColor(FCurrentCommon.AfterColor);
    Canvas.TextOut(X, Y, Text);
  finally
    RestoreDC(Canvas.Handle, SavedDC);
  end;
end;

procedure TFrameLyricsLineDisplaySettingsPage.DrawPreviewImage(
  Canvas: TCanvas; Image, AnchorImage: TTextRenderImage; X, Y,
  TransitionX: Integer; AfterPhase: Boolean);
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
    if (Length(AnchorImage.TextUnitOrigins) > 0) and
      (Length(Image.TextUnitOrigins) > 0) then
    begin
      ImageLeft := X + Round(AnchorImage.TextUnitOrigins[0].X +
        AnchorImage.Bounds.Left - AnchorImage.LayoutBounds.Left -
        Image.TextUnitOrigins[0].X);
      ImageTop := Y + Round(AnchorImage.TextUnitOrigins[0].Y +
        AnchorImage.Bounds.Top - AnchorImage.LayoutBounds.Top -
        Image.TextUnitOrigins[0].Y);
    end
    else
    begin
      ImageLeft := X + Image.Bounds.Left - Image.LayoutBounds.Left;
      ImageTop := Y + Image.Bounds.Top - Image.LayoutBounds.Top;
    end;
    SavedDC := SaveDC(Canvas.Handle);
    try
      if AfterPhase then
        IntersectClipRect(Canvas.Handle, 0, 0, TransitionX,
          FPreview.ClientHeight)
      else
        IntersectClipRect(Canvas.Handle, TransitionX, 0,
          FPreview.ClientWidth, FPreview.ClientHeight);
      Blend.BlendOp := AC_SRC_OVER;
      Blend.BlendFlags := 0;
      Blend.SourceConstantAlpha := 255;
      Blend.AlphaFormat := AC_SRC_ALPHA;
      AlphaBlend(Canvas.Handle, ImageLeft, ImageTop, Bitmap.Width,
        Bitmap.Height, Bitmap.Canvas.Handle, 0, 0, Bitmap.Width,
        Bitmap.Height, Blend);
    finally
      RestoreDC(Canvas.Handle, SavedDC);
    end;
  finally
    Bitmap.Free;
  end;
end;

function TFrameLyricsLineDisplaySettingsPage.RenderPreviewTextImage(
  Canvas: TCanvas; const Text: string; CharacterSpacing: Integer;
  AfterPhase, IncludeDecoration: Boolean): TTextRenderImage;
var
  BlurColor: TColor;
  BlurOpacity: Byte;
  FillColor: TColor;
  FillOpacity: Byte;
  Metrics: TTextRenderMetrics;
  OutlineColor: TColor;
  OutlineOpacity: Byte;
  PreviewScale: Double;
  Request: TTextRenderRequest;
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
    FillColor := TColor(FCurrentCommon.AfterColor);
    FillOpacity := FCurrentCommon.AfterOpacity;
    OutlineColor := TColor(FCurrentCommon.AfterOutlineColor);
    OutlineOpacity := FCurrentCommon.AfterOutlineOpacity;
    ShadowColor := TColor(FCurrentCommon.AfterShadowColor);
    ShadowOpacity := FCurrentCommon.AfterShadowOpacity;
    BlurColor := TColor(FCurrentCommon.AfterBlurColor);
    BlurOpacity := FCurrentCommon.AfterBlurOpacity;
  end
  else
  begin
    FillColor := TColor(FCurrentCommon.BeforeColor);
    FillOpacity := FCurrentCommon.BeforeOpacity;
    OutlineColor := TColor(FCurrentCommon.BeforeOutlineColor);
    OutlineOpacity := FCurrentCommon.BeforeOutlineOpacity;
    ShadowColor := TColor(FCurrentCommon.BeforeShadowColor);
    ShadowOpacity := FCurrentCommon.BeforeShadowOpacity;
    BlurColor := TColor(FCurrentCommon.BeforeBlurColor);
    BlurOpacity := FCurrentCommon.BeforeBlurOpacity;
  end;
  PreviewScale := PreviewBackgroundScale;
  if PreviewScale <= 0 then
    PreviewScale := 1;
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
  Request.CaptureTextUnits := True;
  Request.Outlines := [];
  if IncludeDecoration and FCurrentCommon.OutlineEnabled and
    (FCurrentCommon.OutlineWidth > 0) then
  begin
    if FCurrentCommon.OutlineBlur <= 0 then
      Request.Outlines := [TTextRenderOutline.Create(
        FCurrentCommon.OutlineWidth * PreviewScale,
        AlphaColor(OutlineColor, OutlineOpacity))]
    else if (ColorToRGB(BlurColor) = ColorToRGB(OutlineColor)) and
      (BlurOpacity = OutlineOpacity) then
      Request.Outlines := [TTextRenderOutline.Create(
        FCurrentCommon.OutlineWidth * PreviewScale,
        FCurrentCommon.OutlineBlur * PreviewScale,
        AlphaColor(OutlineColor, OutlineOpacity))]
    else
      Request.Outlines := [
        TTextRenderOutline.Create(FCurrentCommon.OutlineWidth * PreviewScale,
          FCurrentCommon.OutlineBlur * PreviewScale,
          AlphaColor(BlurColor, BlurOpacity)),
        TTextRenderOutline.Create(FCurrentCommon.OutlineWidth * PreviewScale,
          AlphaColor(OutlineColor, OutlineOpacity))];
  end;
  Request.Shadows := [];
  if IncludeDecoration and FCurrentCommon.ShadowEnabled then
  begin
    Shadow := System.Default(TTextRenderShadow);
    Shadow.Offset := PointF(FCurrentCommon.ShadowOffsetX * PreviewScale,
      FCurrentCommon.ShadowOffsetY * PreviewScale);
    Shadow.BlurRadius := FCurrentCommon.ShadowBlur * PreviewScale;
    Shadow.SpreadRadius := FCurrentCommon.ShadowSpread * PreviewScale;
    Shadow.Color := AlphaColor(ShadowColor, ShadowOpacity);
    Request.Shadows := [Shadow];
  end;
  Result := FPreviewRenderer.Render(Request, Metrics);
end;

procedure TFrameLyricsLineDisplaySettingsPage.PreviewPaint(Sender: TObject);
var
  BaseRect: TRect;
  BaseHeight: Integer;
  BaseSpacing: Integer;
  BaseStyle: TFontStyles;
  BaseWidth: Integer;
  BaseX: Integer;
  BaseY: Integer;
  CenterX: Integer;
  Destination: TRect;
  Handle: TRect;
  LeftHandle: TRect;
  OldCharacterSpacing: Integer;
  PlainText: string;
  PrefixText: string;
  PrefixWidth: Integer;
  RubyGap: Integer;
  RubyHeight: Integer;
  RubyIndex: Integer;
  RubySpacing: Integer;
  RubySpans: TLyricsRubySpans;
  RubyRect: TRect;
  RubyWidth: Integer;
  RubyX: Integer;
  RubyY: Integer;
  RightHandle: TRect;
  RubyStyle: TFontStyles;
  PreviewScale: Double;
  SpanText: string;
  SpanWidth: Integer;
  SelectedBounds: TRect;
  SelectionColor: TColor;
begin
  FBackground.DrawAt(FPreview.Canvas, FPreview.ClientRect,
    PreviewDestinationRect);
  PreviewScale := PreviewBackgroundScale;
  FPreview.Canvas.Brush.Style := bsClear;
  ParseLyrics(FCurrentLyrics, PlainText, RubySpans);
  BaseStyle := [];
  if (FCurrentCommon.BaseFontStyle and 1) <> 0 then
    Include(BaseStyle, fsBold);
  if (FCurrentCommon.BaseFontStyle and 2) <> 0 then
    Include(BaseStyle, fsItalic);
  if (FCurrentCommon.BaseFontStyle and 4) <> 0 then
    Include(BaseStyle, fsUnderline);
  if (FCurrentCommon.BaseFontStyle and 8) <> 0 then
    Include(BaseStyle, fsStrikeOut);
  RubyStyle := [];
  if (FCurrentCommon.RubyFontStyle and 1) <> 0 then
    Include(RubyStyle, fsBold);
  if (FCurrentCommon.RubyFontStyle and 2) <> 0 then
    Include(RubyStyle, fsItalic);
  if (FCurrentCommon.RubyFontStyle and 4) <> 0 then
    Include(RubyStyle, fsUnderline);
  if (FCurrentCommon.RubyFontStyle and 8) <> 0 then
    Include(RubyStyle, fsStrikeOut);
  FPreview.Canvas.Font.Name := FCurrentCommon.BaseFontName;
  FPreview.Canvas.Font.Color := TColor(FCurrentCommon.BeforeColor);
  FPreview.Canvas.Font.Height := -Max(1,
    Round(FCurrentCommon.BaseFontHeight * PreviewScale));
  FPreview.Canvas.Font.Style := BaseStyle;
  OldCharacterSpacing := GetTextCharacterExtra(FPreview.Canvas.Handle);
  SetTextCharacterExtra(FPreview.Canvas.Handle, 0);
  Destination := PreviewDestinationRect;
  BaseSpacing := Round(FCurrentCommon.BaseCharacterSpacing * PreviewScale);
  RubySpacing := Round(FCurrentCommon.RubyCharacterSpacing * PreviewScale);
  BaseWidth := FPreview.Canvas.TextWidth(PlainText) + BaseSpacing *
    Max(0, Length(PlainText) - 1);
  BaseWidth := Max(1, BaseWidth);
  BaseHeight := FPreview.Canvas.TextHeight(PlainText);
  RubyHeight := 0;
  if Length(RubySpans) > 0 then
  begin
    FPreview.Canvas.Font.Name := FCurrentCommon.RubyFontName;
    FPreview.Canvas.Font.Height := -Max(1,
      Round(FCurrentCommon.RubyFontHeight * PreviewScale));
    FPreview.Canvas.Font.Style := RubyStyle;
    RubyHeight := FPreview.Canvas.TextHeight('Ag');
  end;
  RubyGap := Round((4 + FCurrentCommon.RubyGapAdjustment) * PreviewScale);
  BaseX := Destination.Left + (Destination.Width - BaseWidth) div 2 +
    Round(FCurrentCommon.PositionX * PreviewScale);
  BaseY := Destination.Top + (Destination.Height - BaseHeight) div 2 +
    Round(FCurrentCommon.PositionY * PreviewScale);
  CenterX := BaseX + BaseWidth div 2;
  BaseRect := Rect(BaseX, BaseY, BaseX + BaseWidth, BaseY + BaseHeight);
  FBasePreviewBounds := BaseRect;
  FPreview.Canvas.Font.Name := FCurrentCommon.BaseFontName;
  FPreview.Canvas.Font.Height := -Max(1,
    Round(FCurrentCommon.BaseFontHeight * PreviewScale));
  FPreview.Canvas.Font.Style := BaseStyle;
  SetTextCharacterExtra(FPreview.Canvas.Handle, BaseSpacing);
  DrawHalfSyncedText(FPreview.Canvas, BaseRect.Left, BaseRect.Top,
    PlainText, CenterX, BaseSpacing);
  SetRectEmpty(FRubyPreviewBounds);
  SetLength(FRubyPreviewRects, Length(RubySpans));
  if Length(RubySpans) > 0 then
  begin
    RubyY := BaseY - RubyGap - RubyHeight;
    for RubyIndex := 0 to High(RubySpans) do
    begin
      FPreview.Canvas.Font.Name := FCurrentCommon.BaseFontName;
      FPreview.Canvas.Font.Height := -Max(1,
        Round(FCurrentCommon.BaseFontHeight * PreviewScale));
      FPreview.Canvas.Font.Style := BaseStyle;
      SetTextCharacterExtra(FPreview.Canvas.Handle, 0);
      PrefixText := Copy(PlainText, 1,
        RubySpans[RubyIndex].BaseStart - 1);
      SpanText := Copy(PlainText, RubySpans[RubyIndex].BaseStart,
        RubySpans[RubyIndex].BaseLength);
      PrefixWidth := FPreview.Canvas.TextWidth(PrefixText) + BaseSpacing *
        Max(0, Length(PrefixText) - 1);
      if PrefixText <> '' then
        Inc(PrefixWidth, BaseSpacing);
      SpanWidth := FPreview.Canvas.TextWidth(SpanText) + BaseSpacing *
        Max(0, Length(SpanText) - 1);

      FPreview.Canvas.Font.Name := FCurrentCommon.RubyFontName;
      FPreview.Canvas.Font.Height := -Max(1,
        Round(FCurrentCommon.RubyFontHeight * PreviewScale));
      FPreview.Canvas.Font.Style := RubyStyle;
      SetTextCharacterExtra(FPreview.Canvas.Handle, 0);
      RubyWidth := FPreview.Canvas.TextWidth(RubySpans[RubyIndex].RubyText) +
        RubySpacing * Max(0,
        Length(RubySpans[RubyIndex].RubyText) - 1);
      RubyWidth := Max(1, RubyWidth);
      RubyX := BaseX + PrefixWidth + (SpanWidth - RubyWidth) div 2;
      RubyRect := Rect(RubyX, RubyY, RubyX + RubyWidth,
        RubyY + RubyHeight);
      FRubyPreviewRects[RubyIndex] := RubyRect;
      if RubyIndex = 0 then
        FRubyPreviewBounds := RubyRect
      else
      begin
        FRubyPreviewBounds.Left := Min(FRubyPreviewBounds.Left,
          RubyRect.Left);
        FRubyPreviewBounds.Top := Min(FRubyPreviewBounds.Top, RubyRect.Top);
        FRubyPreviewBounds.Right := Max(FRubyPreviewBounds.Right,
          RubyRect.Right);
        FRubyPreviewBounds.Bottom := Max(FRubyPreviewBounds.Bottom,
          RubyRect.Bottom);
      end;
      SetTextCharacterExtra(FPreview.Canvas.Handle, RubySpacing);
      DrawHalfSyncedText(FPreview.Canvas, RubyRect.Left, RubyRect.Top,
        RubySpans[RubyIndex].RubyText, CenterX, RubySpacing);
    end;
  end
  else if FSelection = ldpsRuby then
    FSelection := ldpsBase;
  SetTextCharacterExtra(FPreview.Canvas.Handle, OldCharacterSpacing);
  FPreview.Canvas.Brush.Style := bsClear;
  if FSelection = ldpsBase then
  begin
    SelectionColor := RGB(255, 210, 40);
    SelectedBounds := FBasePreviewBounds;
  end
  else
  begin
    SelectionColor := RGB(175, 110, 255);
    SelectedBounds := FRubyPreviewBounds;
  end;
  FPreview.Canvas.Pen.Color := SelectionColor;
  FPreview.Canvas.Rectangle(SelectedBounds);
  Handle := ResizeHandleRect(SelectedBounds);
  LeftHandle := SpacingHandleRect(SelectedBounds, True);
  RightHandle := SpacingHandleRect(SelectedBounds, False);
  FPreview.Canvas.Brush.Style := bsSolid;
  FPreview.Canvas.Brush.Color := SelectionColor;
  FPreview.Canvas.FillRect(Handle);
  if ((FSelection = ldpsBase) and (Length(PlainText) > 1)) or
    ((FSelection = ldpsRuby) and (RubySpacingIntervalCount > 0)) then
  begin
    FPreview.Canvas.FillRect(LeftHandle);
    FPreview.Canvas.FillRect(RightHandle);
  end;
  DrawDecorationHandles(FPreview.Canvas);
end;

procedure TFrameLyricsLineDisplaySettingsPage.SetBackgroundRgba(
  const Pixels: TBytes; Width, Height: Integer);
begin
  FBackground.SetRgba(Pixels, Width, Height);
  FPreview.Invalidate;
end;

function TFrameLyricsLineDisplaySettingsPage.DecorationHandleRect(
  Mode: TLineDisplayPageDragMode): TRect;
var
  Bounds: TRect;
  Center: TPoint;
  Extent: Integer;
  Gap: Integer;
  PreviewScale: Double;
begin
  Result := TRect.Empty;
  if FSelection = ldpsRuby then
    Bounds := FRubyPreviewBounds
  else
    Bounds := FBasePreviewBounds;
  if IsRectEmpty(Bounds) then
    Exit;
  Extent := MulDiv(24, CurrentPPI, 96);
  Gap := MulDiv(10, CurrentPPI, 96);
  PreviewScale := PreviewBackgroundScale;
  if PreviewScale <= 0 then
    PreviewScale := 1;
  case Mode of
    ldpdOutlineBlur:
      Center := Point(Bounds.Left - Gap - Extent div 2,
        Bounds.Top - Gap - Extent div 2);
    ldpdOutlineWidth:
      Center := Point(Bounds.Right + Gap + Extent div 2,
        Bounds.Top - Gap - Extent div 2);
    ldpdShadowBlur:
      Center := Point(Bounds.Left - Gap - Extent div 2,
        Bounds.Bottom + Gap + Extent div 2);
    ldpdShadowOffset:
      Center := Point(Bounds.Right + Gap + Extent div 2 +
        Round(FCurrentCommon.ShadowOffsetX * PreviewScale),
        Bounds.Bottom + Gap + Extent div 2 +
        Round(FCurrentCommon.ShadowOffsetY * PreviewScale));
    ldpdShadowSpread:
      begin
        Result := DecorationHandleRect(ldpdShadowOffset);
        Center := Point(Result.Right + Gap + Extent div 2,
          (Result.Top + Result.Bottom) div 2);
      end;
  else
    Exit;
  end;
  case Mode of
    ldpdOutlineBlur:
      Dec(Center.X, Round(FCurrentCommon.OutlineBlur * PreviewScale));
    ldpdOutlineWidth:
      Inc(Center.X, Round(FCurrentCommon.OutlineWidth * PreviewScale));
    ldpdShadowBlur:
      Dec(Center.X, Round(FCurrentCommon.ShadowBlur * PreviewScale));
    ldpdShadowSpread:
      Inc(Center.X, Round(FCurrentCommon.ShadowSpread * PreviewScale));
  end;
  Center.X := EnsureRange(Center.X, Extent div 2,
    Max(Extent div 2, FPreview.ClientWidth - Extent div 2));
  Center.Y := EnsureRange(Center.Y, Extent div 2,
    Max(Extent div 2, FPreview.ClientHeight - Extent div 2));
  Result := Rect(Center.X - Extent div 2, Center.Y - Extent div 2,
    Center.X + Extent div 2, Center.Y + Extent div 2);
end;

procedure TFrameLyricsLineDisplaySettingsPage.DrawDecorationHandles(
  Canvas: TCanvas);
const
  MODES: array[0..4] of TLineDisplayPageDragMode =
    (ldpdOutlineBlur, ldpdOutlineWidth, ldpdShadowBlur,
     ldpdShadowOffset, ldpdShadowSpread);
  LABELS: array[0..4] of string = (#26580, #32257, #24433, 'XY', #24195);
var
  Anchor: TPoint;
  Bounds: TRect;
  Handle: TRect;
  I: Integer;
  Mode: TLineDisplayPageDragMode;
  TextRect: TRect;
  ValueRect: TRect;
  ValueText: string;

  function DecorationValue(AMode: TLineDisplayPageDragMode): string;
  begin
    case AMode of
      ldpdOutlineBlur:
        Result := FormatFloat('0.0', FCurrentCommon.OutlineBlur);
      ldpdOutlineWidth:
        Result := FormatFloat('0.0', FCurrentCommon.OutlineWidth);
      ldpdShadowBlur:
        Result := FormatFloat('0.0', FCurrentCommon.ShadowBlur);
      ldpdShadowOffset:
        Result := 'X ' + FormatFloat('0.0', FCurrentCommon.ShadowOffsetX) +
          '  Y ' + FormatFloat('0.0', FCurrentCommon.ShadowOffsetY);
      ldpdShadowSpread:
        Result := FormatFloat('0.0', FCurrentCommon.ShadowSpread);
    else
      Result := '';
    end;
  end;
begin
  if FSelection = ldpsRuby then
    Bounds := FRubyPreviewBounds
  else
    Bounds := FBasePreviewBounds;
  if IsRectEmpty(Bounds) then
    Exit;
  for I := Low(MODES) to High(MODES) do
  begin
    Mode := MODES[I];
    if (Mode in [ldpdOutlineBlur, ldpdOutlineWidth]) and
      not FCurrentCommon.OutlineEnabled then
      Continue;
    if (Mode in [ldpdShadowBlur, ldpdShadowOffset, ldpdShadowSpread]) and
      not FCurrentCommon.ShadowEnabled then
      Continue;
    Handle := DecorationHandleRect(Mode);
    if Mode in [ldpdOutlineBlur, ldpdShadowBlur] then
      Anchor.X := Bounds.Left
    else
      Anchor.X := Bounds.Right;
    if Mode in [ldpdOutlineBlur, ldpdOutlineWidth] then
      Anchor.Y := Bounds.Top
    else
      Anchor.Y := Bounds.Bottom;
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Color := RGB(144, 144, 144);
    Canvas.MoveTo(Anchor.X, Anchor.Y);
    Canvas.LineTo((Handle.Left + Handle.Right) div 2,
      (Handle.Top + Handle.Bottom) div 2);
    Canvas.Pen.Style := psSolid;
    if FDragMode = Mode then
      Canvas.Pen.Color := clAqua
    else
      Canvas.Pen.Color := RGB(210, 210, 210);
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
      ValueRect := Handle;
      InflateRect(ValueRect, MulDiv(20, CurrentPPI, 96), 0);
      OffsetRect(ValueRect, 0, Handle.Height + MulDiv(4, CurrentPPI, 96));
      if ValueRect.Bottom > FPreview.ClientHeight then
        OffsetRect(ValueRect, 0, -Handle.Height * 2 -
          MulDiv(8, CurrentPPI, 96));
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := RGB(35, 35, 35);
      Canvas.Pen.Color := clAqua;
      Canvas.RoundRect(ValueRect.Left, ValueRect.Top, ValueRect.Right,
        ValueRect.Bottom, MulDiv(5, CurrentPPI, 96),
        MulDiv(5, CurrentPPI, 96));
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Style := [];
      Canvas.Font.Color := RGB(235, 235, 235);
      DrawText(Canvas.Handle, PChar(ValueText), Length(ValueText), ValueRect,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    end;
  end;
end;

function TFrameLyricsLineDisplaySettingsPage.HitTestDragMode(
  const PointValue: TPoint): TLineDisplayPageDragMode;
var
  IntervalCount: Integer;
  SelectedBounds: TRect;
begin
  Result := ldpdNone;
  if FCurrentCommon.OutlineEnabled then
  begin
    if PtInRect(DecorationHandleRect(ldpdOutlineBlur), PointValue) then
      Exit(ldpdOutlineBlur);
    if PtInRect(DecorationHandleRect(ldpdOutlineWidth), PointValue) then
      Exit(ldpdOutlineWidth);
  end;
  if FCurrentCommon.ShadowEnabled then
  begin
    if PtInRect(DecorationHandleRect(ldpdShadowBlur), PointValue) then
      Exit(ldpdShadowBlur);
    if PtInRect(DecorationHandleRect(ldpdShadowOffset), PointValue) then
      Exit(ldpdShadowOffset);
    if PtInRect(DecorationHandleRect(ldpdShadowSpread), PointValue) then
      Exit(ldpdShadowSpread);
  end;
  if FSelection = ldpsRuby then
  begin
    SelectedBounds := FRubyPreviewBounds;
    IntervalCount := RubySpacingIntervalCount;
  end
  else
  begin
    SelectedBounds := FBasePreviewBounds;
    IntervalCount := BaseSpacingIntervalCount;
  end;
  if not IsRectEmpty(SelectedBounds) then
  begin
    if (IntervalCount > 0) and
      PtInRect(SpacingHandleRect(SelectedBounds, True), PointValue) then
      Exit(ldpdSpacingLeft);
    if (IntervalCount > 0) and
      PtInRect(SpacingHandleRect(SelectedBounds, False), PointValue) then
      Exit(ldpdSpacingRight);
    if PtInRect(ResizeHandleRect(SelectedBounds), PointValue) then
      Exit(ldpdResize);
    if PtInRect(SelectedBounds, PointValue) then
      if FSelection = ldpsRuby then
        Exit(ldpdRubyGap)
      else
        Exit(ldpdMove);
  end;
  if PtInRect(FRubyPreviewBounds, PointValue) then
    Exit(ldpdRubyGap);
  if PtInRect(FBasePreviewBounds, PointValue) then
    Exit(ldpdMove);
end;

procedure TFrameLyricsLineDisplaySettingsPage.PreviewMouseDown(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  PointValue: TPoint;
  SelectedBounds: TRect;
begin
  if Button <> mbLeft then
    Exit;
  PointValue := Point(X, Y);
  if FSelection = ldpsRuby then
    SelectedBounds := FRubyPreviewBounds
  else
    SelectedBounds := FBasePreviewBounds;
  if not (PtInRect(ResizeHandleRect(SelectedBounds), PointValue) or
    PtInRect(SpacingHandleRect(SelectedBounds, True), PointValue) or
    PtInRect(SpacingHandleRect(SelectedBounds, False), PointValue)) then
  begin
    if PtInRect(FRubyPreviewBounds, PointValue) then
      FSelection := ldpsRuby
    else if PtInRect(FBasePreviewBounds, PointValue) then
      FSelection := ldpsBase;
  end;
  UpdateControls;
  FDragMode := HitTestDragMode(PointValue);
  if FDragMode = ldpdNone then
    FDragMode := ldpdPan;
  if FDragMode <> ldpdNone then
  begin
    FDragStartPoint := PointValue;
    FDragStartPositionX := FCurrentCommon.PositionX;
    FDragStartPositionY := FCurrentCommon.PositionY;
    FDragStartBaseCharacterSpacing :=
      FCurrentCommon.BaseCharacterSpacing;
    FDragStartRubyCharacterSpacing :=
      FCurrentCommon.RubyCharacterSpacing;
    FDragStartRubyGapAdjustment := FCurrentCommon.RubyGapAdjustment;
    FDragStartOutlineWidth := FCurrentCommon.OutlineWidth;
    FDragStartOutlineBlur := FCurrentCommon.OutlineBlur;
    FDragStartShadowOffsetX := FCurrentCommon.ShadowOffsetX;
    FDragStartShadowOffsetY := FCurrentCommon.ShadowOffsetY;
    FDragStartShadowBlur := FCurrentCommon.ShadowBlur;
    FDragStartShadowSpread := FCurrentCommon.ShadowSpread;
    FDragStartViewPan := FViewPan;
    if FSelection = ldpsRuby then
      FDragStartFontHeight := FCurrentCommon.RubyFontHeight
    else
      FDragStartFontHeight := FCurrentCommon.BaseFontHeight;
    TDisplayPageControlAccess(FPreview).MouseCapture := True;
  end;
end;

procedure TFrameLyricsLineDisplaySettingsPage.PreviewMouseMove(
  Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  DeltaX: Integer;
  DeltaY: Integer;
  IntervalCount: Integer;
  Mode: TLineDisplayPageDragMode;
  PreviewScale: Double;
begin
  if FDragMode = ldpdNone then
  begin
    Mode := HitTestDragMode(Point(X, Y));
    case Mode of
      ldpdMove, ldpdShadowOffset:
        FPreview.Cursor := crSizeAll;
      ldpdResize:
        FPreview.Cursor := crSizeNWSE;
      ldpdSpacingLeft, ldpdSpacingRight, ldpdOutlineBlur,
        ldpdOutlineWidth, ldpdShadowBlur, ldpdShadowSpread:
        FPreview.Cursor := crSizeWE;
      ldpdRubyGap:
        FPreview.Cursor := crSizeNS;
    else
      FPreview.Cursor := crDefault;
    end;
    Exit;
  end;
  PreviewScale := PreviewBackgroundScale;
  if PreviewScale <= 0 then
    PreviewScale := 1;
  DeltaX := Round((X - FDragStartPoint.X) / PreviewScale);
  DeltaY := Round((Y - FDragStartPoint.Y) / PreviewScale);
  case FDragMode of
    ldpdPan:
      begin
        FViewPan.X := FDragStartViewPan.X + X - FDragStartPoint.X;
        FViewPan.Y := FDragStartViewPan.Y + Y - FDragStartPoint.Y;
        FPreview.Cursor := crSizeAll;
      end;
    ldpdMove:
      begin
        FCurrentCommon.PositionX := EnsureRange(
          FDragStartPositionX + DeltaX, -10000, 10000);
        FCurrentCommon.PositionY := EnsureRange(
          FDragStartPositionY + DeltaY, -10000, 10000);
      end;
    ldpdResize:
      begin
        if FSelection = ldpsRuby then
          FCurrentCommon.RubyFontHeight := EnsureRange(
            FDragStartFontHeight + DeltaY, 1, 1024)
        else
          FCurrentCommon.BaseFontHeight := EnsureRange(
            FDragStartFontHeight + DeltaY, 1, 1024);
      end;
    ldpdSpacingLeft, ldpdSpacingRight:
      begin
        if FDragMode = ldpdSpacingLeft then
          DeltaX := -DeltaX;
        if FSelection = ldpsRuby then
          IntervalCount := RubySpacingIntervalCount
        else
          IntervalCount := BaseSpacingIntervalCount;
        if IntervalCount > 0 then
          if FSelection = ldpsRuby then
            FCurrentCommon.RubyCharacterSpacing := EnsureRange(
              FDragStartRubyCharacterSpacing +
              Round(DeltaX / IntervalCount), -100, 100)
          else
            FCurrentCommon.BaseCharacterSpacing := EnsureRange(
              FDragStartBaseCharacterSpacing +
              Round(DeltaX / IntervalCount), -100, 100);
      end;
    ldpdRubyGap:
      FCurrentCommon.RubyGapAdjustment := EnsureRange(
        FDragStartRubyGapAdjustment - DeltaY, -200, 500);
    ldpdOutlineWidth:
      FCurrentCommon.OutlineWidth := EnsureRange(
        FDragStartOutlineWidth + DeltaX, 0.0, 500.0);
    ldpdOutlineBlur:
      FCurrentCommon.OutlineBlur := EnsureRange(
        FDragStartOutlineBlur - DeltaX, 0.0, 500.0);
    ldpdShadowOffset:
      begin
        FCurrentCommon.ShadowOffsetX := EnsureRange(
          FDragStartShadowOffsetX + DeltaX, -2000.0, 2000.0);
        FCurrentCommon.ShadowOffsetY := EnsureRange(
          FDragStartShadowOffsetY + DeltaY, -2000.0, 2000.0);
      end;
    ldpdShadowBlur:
      FCurrentCommon.ShadowBlur := EnsureRange(
        FDragStartShadowBlur - DeltaX, 0.0, 500.0);
    ldpdShadowSpread:
      FCurrentCommon.ShadowSpread := EnsureRange(
        FDragStartShadowSpread + DeltaX, 0.0, 500.0);
  end;
  FPreview.Invalidate;
end;

procedure TFrameLyricsLineDisplaySettingsPage.PreviewMouseLeave(
  Sender: TObject);
begin
  if FDragMode = ldpdNone then
    FPreview.Cursor := crDefault;
end;

procedure TFrameLyricsLineDisplaySettingsPage.AdjustPreviewZoom(
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
  if not PtInRect(FPreview.ClientRect, ClientPoint) then
    Exit;
  if not FBackground.HasImage then
    Exit;
  OldDestination := PreviewDestinationRect;
  OldScale := PreviewBackgroundScale;
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
  NewDestination := PreviewDestinationRect;
  NewScale := PreviewBackgroundScale;
  FViewPan.X := ClientPoint.X - ImageX * NewScale - NewDestination.Left;
  FViewPan.Y := ClientPoint.Y - ImageY * NewScale - NewDestination.Top;
  FPreview.Invalidate;
end;

procedure TFrameLyricsLineDisplaySettingsPage.PreviewMouseWheel(
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

procedure TFrameLyricsLineDisplaySettingsPage.PreviewMouseUp(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button <> mbLeft then
    Exit;
  FDragMode := ldpdNone;
  TDisplayPageControlAccess(FPreview).MouseCapture := False;
  PreviewMouseMove(Sender, Shift, X, Y);
end;

function TFrameLyricsLineDisplaySettingsPage.BaseSpacingIntervalCount:
  Integer;
var
  PlainText: string;
  RubySpans: TLyricsRubySpans;
begin
  ParseLyrics(FCurrentLyrics, PlainText, RubySpans);
  Result := Max(0, Length(PlainText) - 1);
end;

function TFrameLyricsLineDisplaySettingsPage.ResizeHandleRect(
  const Bounds: TRect): TRect;
var
  Size: Integer;
begin
  Size := MulDiv(8, CurrentPPI, 96);
  Result := Rect(Bounds.Right - Size div 2,
    Bounds.Bottom - Size div 2, Bounds.Right + Size div 2 + 1,
    Bounds.Bottom + Size div 2 + 1);
end;

function TFrameLyricsLineDisplaySettingsPage.RubySpacingIntervalCount:
  Integer;
var
  I: Integer;
  PlainText: string;
  RubySpans: TLyricsRubySpans;
begin
  ParseLyrics(FCurrentLyrics, PlainText, RubySpans);
  Result := 0;
  for I := 0 to High(RubySpans) do
    Result := Max(Result, Length(RubySpans[I].RubyText) - 1);
end;

function TFrameLyricsLineDisplaySettingsPage.SpacingHandleRect(
  const Bounds: TRect; LeftSide: Boolean): TRect;
var
  CenterX: Integer;
  CenterY: Integer;
  Size: Integer;
begin
  Size := MulDiv(8, CurrentPPI, 96);
  if LeftSide then
    CenterX := Bounds.Left
  else
    CenterX := Bounds.Right;
  CenterY := (Bounds.Top + Bounds.Bottom) div 2;
  Result := Rect(CenterX - Size div 2, CenterY - Size div 2,
    CenterX + Size div 2 + 1, CenterY + Size div 2 + 1);
end;

function TFrameLyricsLineDisplaySettingsPage.SelectedCommonSettings:
  TDisplayCommonSettings;
begin
  StoreCurrentCandidate;
  Result := FCurrentCommon;
end;

function TFrameLyricsLineDisplaySettingsPage.SelectedFontStyle: Byte;
begin
  if FSelection = ldpsRuby then
    Result := FCurrentCommon.RubyFontStyle
  else
    Result := FCurrentCommon.BaseFontStyle;
end;

function TFrameLyricsLineDisplaySettingsPage.SelectedLyrics: string;
begin
  Result := FCurrentLyrics;
end;

procedure TFrameLyricsLineDisplaySettingsPage.SetSelectedFontStyle(
  Value: Byte);
begin
  if FSelection = ldpsRuby then
    FCurrentCommon.RubyFontStyle := Value
  else
    FCurrentCommon.BaseFontStyle := Value;
end;

procedure TFrameLyricsLineDisplaySettingsPage.StoreCurrentCandidate;
begin
  if (FCurrentCandidate >= 0) and
    (FCurrentCandidate < Length(FCandidateCommon)) then
    FCandidateCommon[FCurrentCandidate] := FCurrentCommon;
end;

procedure TFrameLyricsLineDisplaySettingsPage.UpdateControls;
var
  I: Integer;
  StyleValue: Byte;
begin
  FUpdatingControls := True;
  try
    FBaseFontCombo.ItemIndex := FBaseFontCombo.Items.IndexOf(
      FCurrentCommon.BaseFontName);
    FRubyFontCombo.ItemIndex := FRubyFontCombo.Items.IndexOf(
      FCurrentCommon.RubyFontName);
    StyleValue := SelectedFontStyle;
    for I := 0 to High(FFormattingButtons) do
      FFormattingButtons[I].CheckState := TSyncLyricsToolbarCheckState(
        Ord((StyleValue and Byte(FFormattingButtons[I].Tag)) <> 0));
    FOutlineButton.CheckState := TSyncLyricsToolbarCheckState(
      Ord(FCurrentCommon.OutlineEnabled));
    FShadowButton.CheckState := TSyncLyricsToolbarCheckState(
      Ord(FCurrentCommon.ShadowEnabled));
    UpdateColorPanel;
  finally
    FUpdatingControls := False;
  end;
  FPreview.Invalidate;
end;

procedure TFrameLyricsLineDisplaySettingsPage.UpdateColorPanel;
begin
  case FColorTarget of
    0: FColorPanel.Configure(FColorTarget,
      TColor(FCurrentCommon.BeforeColor),
      TColor(FCurrentCommon.AfterColor),
      FCurrentCommon.BeforeOpacity, FCurrentCommon.AfterOpacity);
    1: FColorPanel.Configure(FColorTarget,
      TColor(FCurrentCommon.BeforeOutlineColor),
      TColor(FCurrentCommon.AfterOutlineColor),
      FCurrentCommon.BeforeOutlineOpacity,
      FCurrentCommon.AfterOutlineOpacity);
    2: FColorPanel.Configure(FColorTarget,
      TColor(FCurrentCommon.BeforeShadowColor),
      TColor(FCurrentCommon.AfterShadowColor),
      FCurrentCommon.BeforeShadowOpacity,
      FCurrentCommon.AfterShadowOpacity);
    3: FColorPanel.Configure(FColorTarget,
      TColor(FCurrentCommon.BeforeBlurColor),
      TColor(FCurrentCommon.AfterBlurColor),
      FCurrentCommon.BeforeBlurOpacity,
      FCurrentCommon.AfterBlurOpacity);
  end;
end;

procedure TFrameLyricsLineDisplaySettingsPage.Resize;
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
  Gap := MulDiv(8, CurrentPPI, 96);
  Extent := MulDiv(28, CurrentPPI, 96);
  FBaseFontLabel.SetBounds(Margin, MulDiv(9, CurrentPPI, 96),
    MulDiv(76, CurrentPPI, 96), MulDiv(20, CurrentPPI, 96));
  FBaseFontCombo.SetBounds(Margin + MulDiv(80, CurrentPPI, 96),
    MulDiv(4, CurrentPPI, 96), MulDiv(150, CurrentPPI, 96),
    MulDiv(24, CurrentPPI, 96));
  FRubyFontLabel.SetBounds(FBaseFontCombo.Left + FBaseFontCombo.Width +
    MulDiv(18, CurrentPPI, 96), FBaseFontLabel.Top,
    MulDiv(76, CurrentPPI, 96), FBaseFontLabel.Height);
  FRubyFontCombo.SetBounds(FRubyFontLabel.Left +
    MulDiv(80, CurrentPPI, 96), FBaseFontCombo.Top,
    MulDiv(150, CurrentPPI, 96), FBaseFontCombo.Height);
  FFormattingToolbar.ButtonExtent := Extent;
  FFormattingToolbar.SetBounds(FRubyFontCombo.Left + FRubyFontCombo.Width +
    MulDiv(16, CurrentPPI, 96), MulDiv(2, CurrentPPI, 96),
    Max(1, ClientWidth - FRubyFontCombo.Left - FRubyFontCombo.Width -
      Margin - MulDiv(16, CurrentPPI, 96)), Extent);
  FActionToolbar.ButtonExtent := Extent;
  FActionToolbar.SetBounds(Margin, Extent + MulDiv(6, CurrentPPI, 96),
    Max(1, ClientWidth - Margin * 2), Extent);
  TopValue := Extent * 2 + Gap + MulDiv(6, CurrentPPI, 96);
  FColorPanel.SetBounds(ClientWidth - Margin - MulDiv(188, CurrentPPI, 96),
    TopValue, MulDiv(188, CurrentPPI, 96),
    Max(1, ClientHeight - TopValue - Margin));
  FPreview.SetBounds(Margin, TopValue,
    Max(1, FColorPanel.Left - Margin - Gap), FColorPanel.Height);
end;

end.
