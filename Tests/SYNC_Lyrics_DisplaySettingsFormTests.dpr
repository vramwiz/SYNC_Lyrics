program SYNC_Lyrics_DisplaySettingsFormTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.Math,
  System.SysUtils,
  System.Types,
  Winapi.Messages,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  TextRendererSkia in '..\Source\Lib\TextRenderer\TextRendererSkia.pas',
  TextRendererSkiaRuntime in '..\Source\Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  SYNC_Lyrics_ToolbarButtons in '..\Source\Lib\SYNC_Lyrics_ToolbarButtons.pas',
  SYNC_Lyrics_DarkTheme in '..\Source\Lib\SYNC_Lyrics_DarkTheme.pas',
  SYNC_Lyrics_FontHistoryComboBox in '..\Source\Lib\SYNC_Lyrics_FontHistoryComboBox.pas',
  SYNC_Lyrics_ContrastGuides in '..\Source\Lib\SYNC_Lyrics_ContrastGuides.pas',
  SYNC_Lyrics_LyricParser in '..\Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_DisplaySettingsData in '..\Source\Common\Render\SYNC_Lyrics_DisplaySettingsData.pas',
  ColorPickerColorMath in '..\Source\Lib\ColorPicker\ColorPickerColorMath.pas',
  ColorPickerHueBar in '..\Source\Lib\ColorPicker\ColorPickerHueBar.pas',
  ColorPickerSVArea in '..\Source\Lib\ColorPicker\ColorPickerSVArea.pas',
  SYNC_Lyrics_DisplaySettingsModePage in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplaySettingsModePage.pas',
  SYNC_Lyrics_DisplaySettingsColorPanel in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplaySettingsColorPanel.pas',
  SYNC_Lyrics_DisplayPreviewBackground in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplayPreviewBackground.pas',
  SYNC_Lyrics_DisplayDecorationControls in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplayDecorationControls.pas',
  SYNC_Lyrics_DisplayPreviewText in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplayPreviewText.pas',
  SYNC_Lyrics_LineDisplayPreviewText in '..\Source\Plugin\Filter\Display\Line\SYNC_Lyrics_LineDisplayPreviewText.pas',
  SYNC_Lyrics_CharacterDecorationOverlay in '..\Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterDecorationOverlay.pas',
  SYNC_Lyrics_CharacterPreviewGeometry in '..\Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterPreviewGeometry.pas',
  SYNC_Lyrics_CharacterLayoutInteraction in '..\Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterLayoutInteraction.pas',
  SYNC_Lyrics_LineDisplaySettingsPage in '..\Source\Plugin\Filter\Display\Line\SYNC_Lyrics_LineDisplaySettingsPage.pas',
  SYNC_Lyrics_CharacterDisplaySettingsPage in '..\Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterDisplaySettingsPage.pas',
  SYNC_Lyrics_DisplaySettingsForm in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplaySettingsForm.pas';

var
  Bitmap: TBitmap;
  BaseStyleBefore: Byte;
  BackgroundPixels: TBytes;
  BaseBoundsBeforeRubyResize: TRect;
  Bounds: TRect;
  CornerIndex: Integer;
  CornerPoint: TPoint;
  DragPoint: TPoint;
  ExpectedCursor: TCursor;
  EditedCandidateCommon: TArray<TDisplayCommonSettings>;
  CommonSettings: TArray<TDisplayCommonSettings>;
  CharacterCommonSettings: TArray<TDisplayCommonSettings>;
  CharacterLyrics: TArray<string>;
  InitialCharacterPlacement: TDisplayPlacementItem;
  CharacterPlacementBefore: TDisplayPlacementItem;
  CharacterPlacement1Before: TDisplayPlacementItem;
  CharacterSettingsTexts: TArray<string>;
  InitialCharacterSettingsTexts: TArray<string>;
  DecodedCharacterCommon: TDisplayCommonSettings;
  DecodedCharacterPlacements: TDisplayPlacementItems;
  Form: TFormLyricsDisplaySettings;
  HistoryFileName: string;
  CharacterPage: TFrameLyricsCharacterDisplaySettingsPage;
  LinePage: TFrameLyricsLineDisplaySettingsPage;
  RubyBounds0: TRect;
  RubyBounds1: TRect;
  SettingsBeforeDrag: TDisplayCommonSettings;
  SnapshotPath: string;
  ViewPanBefore: TPointF;
  WheelFontName: string;
  ZoomBefore: Double;
  PlacementsMatchLyrics: Boolean;
  DecorationMode: TCharacterLayoutDragMode;
  DecorationBefore: TDisplayPlacementItem;
  PreviewRenderer: TSkiaTextRenderer;
  PreviewSettings: TDisplayCommonSettings;
  PreviewSignatureBefore: UInt64;
  PreviewSignatureAfter: UInt64;

type
  TTestExceptionHandler = class
  public
    Failed: Boolean;
    procedure HandleException(Sender: TObject; E: Exception);
  end;

procedure TTestExceptionHandler.HandleException(Sender: TObject;
  E: Exception);
begin
  Failed := True;
  Writeln(E.ClassName + ': ' + E.Message);
  Writeln('EXCEPT_OFFSET=' + IntToHex(
    NativeUInt(ExceptAddr) - NativeUInt(GetModuleHandle(nil)), 8));
end;

function BitmapSignature(const Value: TBitmap): UInt64;
var
  X, Y: Integer;
begin
  Result := 2166136261;
  for Y := 0 to Value.Height - 1 do
    for X := 0 to Value.Width - 1 do
      Result := (Result xor Cardinal(ColorToRGB(
        Value.Canvas.Pixels[X, Y]))) * 16777619;
end;

function DecoratedPreviewSignature(Renderer: TSkiaTextRenderer;
  const Settings: TDisplayCommonSettings): UInt64;
var
  PreviewBitmap: TBitmap;
begin
  PreviewBitmap := TBitmap.Create;
  try
    PreviewBitmap.SetSize(240, 120);
    PreviewBitmap.Canvas.Brush.Color := clWhite;
    PreviewBitmap.Canvas.FillRect(Rect(0, 0, 240, 120));
    if not DrawDisplayPreviewText(PreviewBitmap.Canvas, Renderer,
      'A', 'Arial', 48, 0, [], Settings, 120, 60, 1, 1) then
      raise Exception.Create('Skia free preview draw failed');
    Result := BitmapSignature(PreviewBitmap);
  finally
    PreviewBitmap.Free;
  end;
end;

function PreviewAfterHalfOutlinePixels(Renderer: TSkiaTextRenderer): Integer;
var
  Color: Cardinal;
  PreviewBitmap: TBitmap;
  Settings: TDisplayCommonSettings;
  X, Y: Integer;
begin
  Settings := DefaultDisplayCommonSettings;
  Settings.BeforeColor := $00FFFFFF;
  Settings.AfterColor := $00FFFF00;
  Settings.OutlineEnabled := True;
  Settings.OutlineWidth := 8;
  Settings.AfterOutlineOpacity := 0;
  PreviewBitmap := TBitmap.Create;
  try
    PreviewBitmap.SetSize(240, 120);
    PreviewBitmap.Canvas.Brush.Color := clWhite;
    PreviewBitmap.Canvas.FillRect(Rect(0, 0, 240, 120));
    if not DrawDisplayPreviewText(PreviewBitmap.Canvas, Renderer,
      'A', 'Arial', 64, 0, [], Settings, 120, 60, 1, 1) then
      raise Exception.Create('after-color outline preview draw failed');
    Result := 0;
    for Y := 0 to PreviewBitmap.Height - 1 do
      for X := 0 to 119 do
      begin
        Color := Cardinal(ColorToRGB(PreviewBitmap.Canvas.Pixels[X, Y]));
        if ((Color and $FF) < 80) and
          (((Color shr 8) and $FF) < 80) and
          (((Color shr 16) and $FF) < 80) then
          Inc(Result);
      end;
  finally
    PreviewBitmap.Free;
  end;
end;

var
  ExceptionHandler: TTestExceptionHandler;

begin
  ExceptionHandler := nil;
  Form := nil;
  HistoryFileName := TPath.Combine(TPath.GetTempPath,
    'SYNC_Lyrics_FontHistory_FormTest_' +
    IntToStr(GetCurrentProcessId) + '.txt');
  DeleteFile(PChar(HistoryFileName));
  TSyncLyricsFontHistoryComboBox.ConfigureHistoryFile(HistoryFileName);
  try
    try
      Application.Initialize;
      if (DisplayDecorationDragValue(8, 10, 1,
        ddkOutlineWidth) >= 10) or
        (DisplayDecorationDragValue(8, 10000, 1,
        ddkOutlineWidth) <> 24) or
        (DisplayDecorationDragValue(10, 10000, 1,
        ddkShadowOffset) <> 96) or
        (DisplayDecorationDragValue(4, -10000, 1,
        ddkShadowBlur) <> 32) then
        raise Exception.Create('decoration drag sensitivity or limit mismatch');
      Bitmap := TBitmap.Create;
      try
        Bitmap.SetSize(64, 24);
        Bitmap.Canvas.Brush.Color := clWhite;
        Bitmap.Canvas.FillRect(Rect(0, 0, 64, 24));
        DrawContrastDashedLine(Bitmap.Canvas, Point(4, 8), Point(60, 8));
        if ColorToRGB(Bitmap.Canvas.Pixels[5, 7]) <> clBlack then
          raise Exception.Create('contrast guide is invisible on white');
        Bitmap.Canvas.Brush.Color := clBlack;
        Bitmap.Canvas.FillRect(Rect(0, 0, 64, 24));
        DrawContrastDashedLine(Bitmap.Canvas, Point(4, 8), Point(60, 8));
        if ColorToRGB(Bitmap.Canvas.Pixels[5, 8]) <> clWhite then
          raise Exception.Create('contrast guide is invisible on black');
      finally
        Bitmap.Free;
      end;
      TTextRendererSkiaRuntime.Acquire(
        ExtractFilePath(ParamStr(0)) + 'sk4d.dll');
      PreviewRenderer := TSkiaTextRenderer.Create;
      try
        PreviewSettings := DefaultDisplayCommonSettings;
        PreviewSettings.BeforeColor := $00000000;
        PreviewSettings.AfterColor := $00000000;
        PreviewSettings.OutlineEnabled := True;
        PreviewSettings.OutlineWidth := 4;
        if PreviewAfterHalfOutlinePixels(PreviewRenderer) = 0 then
          raise Exception.Create('after-color preview lost the underlying outline');
        PreviewSignatureBefore := DecoratedPreviewSignature(
          PreviewRenderer, PreviewSettings);
        PreviewSettings.OutlineBlur := 8;
        PreviewSignatureAfter := DecoratedPreviewSignature(
          PreviewRenderer, PreviewSettings);
        if PreviewSignatureAfter = PreviewSignatureBefore then
          raise Exception.Create('free preview outline blur has no effect');
        PreviewSettings.OutlineEnabled := False;
        PreviewSettings.ShadowEnabled := True;
        PreviewSignatureBefore := DecoratedPreviewSignature(
          PreviewRenderer, PreviewSettings);
        PreviewSettings.ShadowBlur := 12;
        PreviewSignatureAfter := DecoratedPreviewSignature(
          PreviewRenderer, PreviewSettings);
        if PreviewSignatureAfter = PreviewSignatureBefore then
          raise Exception.Create('free preview shadow blur has no effect');
        PreviewSignatureBefore := PreviewSignatureAfter;
        PreviewSettings.ShadowSpread := 8;
        PreviewSignatureAfter := DecoratedPreviewSignature(
          PreviewRenderer, PreviewSettings);
        if PreviewSignatureAfter = PreviewSignatureBefore then
          raise Exception.Create('free preview shadow spread has no effect');
        PreviewSettings.ShadowEnabled := False;
        PreviewSettings.BeforeOpacity := 255;
        PreviewSettings.AfterOpacity := 255;
        PreviewSignatureBefore := DecoratedPreviewSignature(
          PreviewRenderer, PreviewSettings);
        PreviewSettings.BeforeOpacity := 0;
        PreviewSettings.AfterOpacity := 0;
        PreviewSignatureAfter := DecoratedPreviewSignature(
          PreviewRenderer, PreviewSettings);
        if PreviewSignatureAfter = PreviewSignatureBefore then
          raise Exception.Create('free preview opacity has no effect');
      finally
        PreviewRenderer.Free;
      end;
      ExceptionHandler := TTestExceptionHandler.Create;
      Application.OnException := ExceptionHandler.HandleException;
      Form := TFormLyricsDisplaySettings.Create(nil);
      try
        if (DefaultDisplayCommonSettings.BaseFontHeight <> 64) or
          (DefaultDisplayCommonSettings.RubyFontHeight <> 28) then
          raise Exception.Create('default font sizes were not reduced');
        if Form.Font.Height <> -MulDiv(12, Form.CurrentPPI, 96) then
          raise Exception.Create('form font DPI scaling mismatch');
        if Form.ClientWidth <> MulDiv(990, Form.CurrentPPI, 96) then
          raise Exception.Create('form width DPI scaling mismatch');
        if Form.ClientHeight <> MulDiv(548, Form.CurrentPPI, 96) then
          raise Exception.Create('form height DPI scaling mismatch');
        if Form.Position <> poScreenCenter then
          raise Exception.Create('form initial position mismatch');
        if Form.CandidateCombo.ItemHeight <>
          MulDiv(16, Form.CandidateCombo.CurrentPPI, 96) then
          raise Exception.Create('candidate combo item height DPI mismatch');
        if Form.ModePageCount <> 2 then
          raise Exception.Create('mode page count mismatch');
        Form.ConfigureModeCandidates(DISPLAY_SETTINGS_MODE_LINE,
          ['lane 1', 'lane 2', 'lane 3'], 1);
        SetLength(CommonSettings, 3);
        CommonSettings[0] := DefaultDisplayCommonSettings;
        CommonSettings[1] := DefaultDisplayCommonSettings;
        CommonSettings[1].BaseFontName := 'Arial';
        CommonSettings[1].PositionY := 120;
        CommonSettings[2] := DefaultDisplayCommonSettings;
        CommonSettings[2].PositionX := 45;
        CommonSettings[2].PositionY := 240;
        LinePage := TFrameLyricsLineDisplaySettingsPage(
          Form.PageForMode(DISPLAY_SETTINGS_MODE_LINE));
        if not LinePage.HasSkiaPreviewRenderer then
          raise Exception.Create('line Skia preview renderer was not created');
        CharacterPage := TFrameLyricsCharacterDisplaySettingsPage(
          Form.PageForMode(DISPLAY_SETTINGS_MODE_FREE));
        if not CharacterPage.HasSkiaPreviewRenderer then
          raise Exception.Create('free Skia preview renderer was not created');
        CharacterPage.ColorPanel.BeforeOpacityTrack.Position := 0;
        CharacterPage.ColorPanel.BeforeOpacityTrack.Perform(WM_LBUTTONDOWN,
          MK_LBUTTON, (12 shl 16) or 8);
        CharacterPage.ColorPanel.BeforeOpacityTrack.Perform(WM_MOUSEMOVE,
          MK_LBUTTON, (12 shl 16) or
          (CharacterPage.ColorPanel.BeforeOpacityTrack.ClientWidth div 2));
        CharacterPage.ColorPanel.BeforeOpacityTrack.Perform(WM_LBUTTONUP,
          0, (12 shl 16) or
          (CharacterPage.ColorPanel.BeforeOpacityTrack.ClientWidth div 2));
        if (CharacterPage.ColorPanel.BeforeOpacityTrack.Position < 100) or
          (CharacterPage.ColorPanel.BeforeOpacityTrack.Position > 155) then
          raise Exception.Create('opacity track drag did not follow pointer');
        CharacterPage.ColorPanel.BeforeOpacityTrack.Position := 49;
        if CharacterPage.ColorPanel.BeforeOpacityTrack.Position <> 51 then
          raise Exception.Create('opacity track 10 percent snap failed');
        CharacterPage.ColorPanel.BeforeOpacityTrack.Position := 255;
        if (LinePage.BaseFontCombo.ItemHeight <>
          MulDiv(16, LinePage.BaseFontCombo.CurrentPPI, 96)) or
          (LinePage.RubyFontCombo.ItemHeight <>
          MulDiv(16, LinePage.RubyFontCombo.CurrentPPI, 96)) or
          (CharacterPage.BaseFontCombo.ItemHeight <>
          MulDiv(16, CharacterPage.BaseFontCombo.CurrentPPI, 96)) or
          (CharacterPage.RubyFontCombo.ItemHeight <>
          MulDiv(16, CharacterPage.RubyFontCombo.CurrentPPI, 96)) or
          (CharacterPage.ElementCombo.ItemHeight <>
          MulDiv(16, CharacterPage.ElementCombo.CurrentPPI, 96)) then
          raise Exception.Create('font combo item height DPI mismatch');
        SetLength(BackgroundPixels, 640 * 360 * 4);
        FillChar(BackgroundPixels[0], Length(BackgroundPixels), $40);
        LinePage.SetBackgroundRgba(BackgroundPixels, 640, 360);
        CharacterPage.SetBackgroundRgba(BackgroundPixels, 640, 360);
        if not LinePage.HasBackgroundImage or
          not CharacterPage.HasBackgroundImage then
          raise Exception.Create('preview background was not loaded');
        Form.SetMode(DISPLAY_SETTINGS_MODE_FREE);
        if (Abs(LinePage.Preview.ClientWidth /
          LinePage.Preview.ClientHeight - 16 / 9) > 0.1) or
          (Abs(CharacterPage.Preview.ClientWidth /
          CharacterPage.Preview.ClientHeight - 16 / 9) > 0.1) then
          raise Exception.CreateFmt(
            'preview aspect ratio leaves excess margins: line=%dx%d free=%dx%d',
            [LinePage.Preview.ClientWidth, LinePage.Preview.ClientHeight,
             CharacterPage.Preview.ClientWidth,
             CharacterPage.Preview.ClientHeight]);
        Form.SetMode(DISPLAY_SETTINGS_MODE_LINE);
        LinePage.ConfigureCandidates(['first', '[second](ruby)', 'third'],
          CommonSettings, 1);
        if (LinePage.SelectedLyrics <> '[second](ruby)') or
          (LinePage.SelectedCommonSettings.BaseFontName <> 'Arial') then
          raise Exception.Create('line candidate settings were not loaded');
        LinePage.CandidateChanged(2);
        if (LinePage.SelectedCommonSettings.BaseFontName <> 'Arial') or
          (LinePage.SelectedCommonSettings.PositionX <> 45) or
          (LinePage.SelectedCommonSettings.PositionY <> 240) then
          raise Exception.Create('line shared style or lane position mismatch');
        LinePage.CandidateChanged(1);
        if (Screen.Fonts.IndexOf('Arial') < 0) or
          (Screen.Fonts.IndexOf('Arial') >= Screen.Fonts.Count - 1) then
          raise Exception.Create('wheel preview test requires Arial neighbor');
        WheelFontName := Screen.Fonts[Screen.Fonts.IndexOf('Arial') + 1];
        LinePage.BaseFontCombo.Perform(WM_MOUSEWHEEL,
          MakeWParam(0, Word(SmallInt(-WHEEL_DELTA))), 0);
        if LinePage.SelectedCommonSettings.BaseFontName <> WheelFontName then
          raise Exception.Create('line wheel font was not previewed');
        LinePage.BaseFontCombo.ItemIndex :=
          LinePage.BaseFontCombo.Items.IndexOf('Arial');
        LinePage.BaseFontCombo.CommitSelection;
        Form.ConfigureModeCandidates(DISPLAY_SETTINGS_MODE_FREE,
          ['character 1', 'character 2'], 0);
        SetLength(CharacterCommonSettings, 2);
        CharacterCommonSettings[0] := DefaultDisplayCommonSettings;
        CharacterCommonSettings[1] := DefaultDisplayCommonSettings;
        CharacterCommonSettings[1].BaseFontName := 'Arial';
        SetLength(CharacterLyrics, 2);
        CharacterLyrics[0] := #27468#91#27468#35422#93#40#12358#12383#41;
        CharacterLyrics[1] := #26143#31354;
        SetLength(CharacterSettingsTexts, 2);
        if not TryEncodeDisplaySettingsText(
          CharacterLyrics[0], CharacterCommonSettings[0], nil,
          CharacterSettingsTexts[0]) or
          not TryEncodeDisplaySettingsText(
          CharacterLyrics[1], CharacterCommonSettings[1], nil,
          CharacterSettingsTexts[1]) then
          raise Exception.Create('character test settings encode failed');
        CharacterPage.ConfigureCandidates(CharacterLyrics,
          CharacterCommonSettings, CharacterSettingsTexts, 0);
        if not CharacterPage.TryBuildCandidateSettingsTexts(
          InitialCharacterSettingsTexts) then
          raise Exception.Create('initial character settings build failed');
        InitialCharacterPlacement := CharacterPage.ElementPlacement(0);
        Form.CaptureInitialState;
        if (Form.ModeToolbar.ItemCount <> 5) or
          (Form.ModeToolbar.Items[0].Glyph <> tbgClose) or
          (Form.ModeToolbar.Items[1].Glyph <> tbgRestore) then
          raise Exception.Create('close and restore toolbar mismatch');
        if (CharacterPage.SelectedLyrics <> CharacterLyrics[0]) or
          (CharacterPage.ElementCount <> 2) or
          (CharacterPage.ElementCombo.Items[1] <>
            #50#58#32#91#27468#35422#93#40#12358#12383#41) then
          raise Exception.Create('character display units were not loaded');
        CharacterPage.ElementCombo.ItemIndex := 1;
        CharacterPage.ElementCombo.OnChange(CharacterPage.ElementCombo);
        CharacterPage.CandidateChanged(1);
        if (CharacterPage.SelectedLyrics <> CharacterLyrics[1]) or
          (CharacterPage.ElementCount <> 2) then
          raise Exception.Create('character candidate was not loaded');
        CharacterPage.CandidateChanged(0);
        if CharacterPage.SelectedElementIndex <> 1 then
          raise Exception.Create('character selection was not retained');
        if not CharacterPage.TryBuildCandidateSettingsTexts(
          CharacterSettingsTexts) or
          (Length(CharacterSettingsTexts) <>
          Length(InitialCharacterSettingsTexts)) then
          raise Exception.Create('unchanged character candidates were lost');
        for CornerIndex := 0 to High(CharacterSettingsTexts) do
          if CharacterSettingsTexts[CornerIndex] <>
            InitialCharacterSettingsTexts[CornerIndex] then
            raise Exception.Create('visiting a line changed its placement');
        Form.SetMode(DISPLAY_SETTINGS_MODE_FREE);
        CharacterPage.Preview.OnPaint(CharacterPage.Preview);
        if (ParamCount > 1) and
          SameText(ParamStr(1), '--snapshot-ruby') then
        begin
          CharacterPage.ElementCombo.ItemIndex := 1;
          CharacterPage.ElementCombo.OnChange(CharacterPage.ElementCombo);
          Bounds := CharacterPage.PreviewElementBounds(1);
          for CornerIndex := 1 to 2 do
          begin
            CharacterPage.Preview.OnMouseDown(CharacterPage.Preview,
              mbLeft, [], Bounds.CenterPoint.X, Bounds.Bottom - 10);
            CharacterPage.Preview.OnMouseUp(CharacterPage.Preview,
              mbLeft, [], Bounds.CenterPoint.X, Bounds.Bottom - 10);
          end;
          if CharacterPage.SelectedMode <> clsmRuby then
            raise Exception.Create('ruby snapshot could not select mode');
          Form.Show;
          Application.ProcessMessages;
          Bitmap := Form.GetFormImage;
          try
            Bitmap.SaveToFile(ParamStr(2));
          finally
            Bitmap.Free;
          end;
          Form.Hide;
          CharacterPage.ElementCombo.OnChange(CharacterPage.ElementCombo);
        end;
        Bounds := CharacterPage.PreviewElementBounds(0);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          Bounds.Left + 1,
          (Bounds.Top + Bounds.Bottom) div 2);
        if CharacterPage.Preview.Cursor <> crSizeAll then
          raise Exception.Create('character move hover cursor mismatch');
        CharacterPlacementBefore := CharacterPage.ElementPlacement(0);
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], Bounds.Left + 1,
          (Bounds.Top + Bounds.Bottom) div 2);
        if (CharacterPage.SelectedElementIndex <> 0) or
          (CharacterPage.ElementCombo.ItemIndex <> 0) then
          raise Exception.CreateFmt(
            'character preview selection mismatch: selected=%d, bounds=%d,%d,%d,%d',
            [CharacterPage.SelectedElementIndex, Bounds.Left, Bounds.Top,
             Bounds.Right, Bounds.Bottom]);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          Bounds.Left + 21,
          (Bounds.Top + Bounds.Bottom) div 2 + 12);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], Bounds.Left + 21,
          (Bounds.Top + Bounds.Bottom) div 2 + 12);
        if (CharacterPage.ElementPlacement(0).X =
          CharacterPlacementBefore.X) or
          (CharacterPage.ElementPlacement(0).Y =
          CharacterPlacementBefore.Y) then
          raise Exception.Create('character move drag was not retained');
        CharacterPage.Preview.OnPaint(CharacterPage.Preview);
        Bounds := CharacterPage.PreviewElementBounds(0);
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], Bounds.CenterPoint.X, Bounds.CenterPoint.Y);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          CharacterPage.Preview.ClientWidth div 2 + 4,
          CharacterPage.Preview.ClientHeight div 2 + 4);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], 0, 0);
        CharacterPage.Preview.OnPaint(CharacterPage.Preview);
        Bounds := CharacterPage.PreviewElementBounds(0);
        if (Abs(Bounds.CenterPoint.X -
          CharacterPage.Preview.ClientWidth div 2) > 2) or
          (Abs(Bounds.CenterPoint.Y -
          CharacterPage.Preview.ClientHeight div 2) > 2) then
          raise Exception.Create('character center snap failed');
        Bounds := CharacterPage.PreviewElementBounds(1);
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [ssShift], Bounds.Right - 1,
          (Bounds.Top + Bounds.Bottom) div 2);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [ssShift], Bounds.Right - 1,
          (Bounds.Top + Bounds.Bottom) div 2);
        if (CharacterPage.SelectedElementCount <> 2) or
          (CharacterPage.ElementCombo.ItemIndex <> 1) then
          raise Exception.Create('character multi-selection mismatch');
        CharacterPlacementBefore := CharacterPage.ElementPlacement(0);
        CharacterPlacement1Before := CharacterPage.ElementPlacement(1);
        Bounds := CharacterPage.PreviewElementBounds(0);
        UnionRect(Bounds, Bounds,
          CharacterPage.PreviewElementBounds(1));
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          Bounds.Right, Bounds.Bottom);
        if CharacterPage.Preview.Cursor <> crSizeNWSE then
          raise Exception.Create('character resize hover cursor mismatch');
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], Bounds.Right, Bounds.Bottom);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          Bounds.Right + 20, Bounds.Bottom + 12);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], Bounds.Right + 20, Bounds.Bottom + 12);
        if (CharacterPage.ElementPlacement(0).ScaleX =
          CharacterPlacementBefore.ScaleX) or
          (CharacterPage.ElementPlacement(0).ScaleY =
          CharacterPlacementBefore.ScaleY) or
          (CharacterPage.ElementPlacement(1).ScaleX =
          CharacterPlacement1Before.ScaleX) or
          (CharacterPage.ElementPlacement(1).ScaleY =
          CharacterPlacement1Before.ScaleY) then
          raise Exception.Create('character group resize was not retained');
        Bounds := CharacterPage.PreviewElementBounds(0);
        UnionRect(Bounds, Bounds,
          CharacterPage.PreviewElementBounds(1));
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], Bounds.Left - 4, Bounds.Top - 4);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          Bounds.Right + 4, Bounds.Bottom + 4);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], Bounds.Right + 4, Bounds.Bottom + 4);
        if CharacterPage.SelectedElementCount <> 2 then
          raise Exception.Create('character rectangle selection mismatch');
        CharacterPage.ElementCombo.ItemIndex := 1;
        CharacterPage.ElementCombo.OnChange(CharacterPage.ElementCombo);
        if (CharacterPage.SelectedElementCount <> 1) or
          (CharacterPage.ElementCombo.ItemIndex <> 1) then
          raise Exception.Create('character combo selection sync mismatch');
        Bounds := CharacterPage.PreviewElementBounds(1);
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        if CharacterPage.SelectedMode <> clsmCharacterSpacing then
          raise Exception.Create('character spacing mode mismatch');
        CharacterPlacementBefore := CharacterPage.ElementPlacement(1);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          Bounds.Left, (Bounds.Top + Bounds.Bottom) div 2);
        if CharacterPage.Preview.Cursor <> crSizeWE then
          raise Exception.Create('character spacing cursor mismatch');
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], Bounds.Left, (Bounds.Top + Bounds.Bottom) div 2);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          Bounds.Left - 16, (Bounds.Top + Bounds.Bottom) div 2);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], Bounds.Left - 16, (Bounds.Top + Bounds.Bottom) div 2);
        if CharacterPage.ElementPlacement(1).BaseCharacterSpacing =
          CharacterPlacementBefore.BaseCharacterSpacing then
          raise Exception.Create('character spacing drag mismatch');
        Bounds := CharacterPage.PreviewElementBounds(1);
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        if CharacterPage.SelectedMode <> clsmRuby then
          raise Exception.Create('character ruby mode mismatch');
        RubyBounds1 := CharacterPage.PreviewRubyBounds(1);
        if IsRectEmpty(RubyBounds1) then
          raise Exception.Create('character ruby bounds missing');
        for CornerIndex := 0 to 7 do
        begin
          case CornerIndex of
            0: CornerPoint := RubyBounds1.TopLeft;
            1: CornerPoint := Point(RubyBounds1.CenterPoint.X,
              RubyBounds1.Top);
            2: CornerPoint := Point(RubyBounds1.Right, RubyBounds1.Top);
            3: CornerPoint := Point(RubyBounds1.Left,
              RubyBounds1.CenterPoint.Y);
            4: CornerPoint := Point(RubyBounds1.Right,
              RubyBounds1.CenterPoint.Y);
            5: CornerPoint := Point(RubyBounds1.Left, RubyBounds1.Bottom);
            6: CornerPoint := Point(RubyBounds1.CenterPoint.X,
              RubyBounds1.Bottom);
          else
            CornerPoint := RubyBounds1.BottomRight;
          end;
          if CornerIndex in [0, 7] then
            ExpectedCursor := crSizeNWSE
          else if CornerIndex in [2, 5] then
            ExpectedCursor := crSizeNESW
          else if CornerIndex in [1, 6] then
            ExpectedCursor := crSizeNS
          else
            ExpectedCursor := crSizeWE;
          CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
            CornerPoint.X, CornerPoint.Y);
          if CharacterPage.Preview.Cursor <> ExpectedCursor then
            raise Exception.CreateFmt(
              'ruby handle %d cursor mismatch', [CornerIndex]);
        end;
        CharacterPlacementBefore := CharacterPage.ElementPlacement(1);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          RubyBounds1.Right, RubyBounds1.Bottom);
        if CharacterPage.Preview.Cursor <> crSizeNWSE then
          raise Exception.Create('character ruby resize cursor mismatch');
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], RubyBounds1.Right, RubyBounds1.Bottom);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          RubyBounds1.Right + 16, RubyBounds1.Bottom + 12);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], RubyBounds1.Right + 16, RubyBounds1.Bottom + 12);
        if (CharacterPage.ElementPlacement(1).RubyScaleX <= 1) or
          (CharacterPage.ElementPlacement(1).RubyScaleY <= 1) or
          (CharacterPage.ElementPlacement(1).ScaleX <>
            CharacterPlacementBefore.ScaleX) or
          (CharacterPage.ElementPlacement(1).ScaleY <>
            CharacterPlacementBefore.ScaleY) then
          raise Exception.Create('character ruby resize changed base scale');
        RubyBounds1 := CharacterPage.PreviewRubyBounds(1);
        CharacterPlacementBefore := CharacterPage.ElementPlacement(1);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          RubyBounds1.Left, RubyBounds1.CenterPoint.Y);
        if CharacterPage.Preview.Cursor <> crSizeWE then
          raise Exception.CreateFmt(
            'character ruby spacing cursor mismatch: %d, bounds=%d,%d,%d,%d, mode=%d',
            [Integer(CharacterPage.Preview.Cursor), RubyBounds1.Left,
             RubyBounds1.Top, RubyBounds1.Right, RubyBounds1.Bottom,
             Ord(CharacterPage.SelectedMode)]);
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], RubyBounds1.Left, RubyBounds1.CenterPoint.Y);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          RubyBounds1.Left - 14, RubyBounds1.CenterPoint.Y);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], RubyBounds1.Left - 14, RubyBounds1.CenterPoint.Y);
        if CharacterPage.ElementPlacement(1).RubyCharacterSpacing =
          CharacterPlacementBefore.RubyCharacterSpacing then
          raise Exception.Create('character ruby spacing drag mismatch');
        RubyBounds1 := CharacterPage.PreviewRubyBounds(1);
        CharacterPlacementBefore := CharacterPage.ElementPlacement(1);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          RubyBounds1.CenterPoint.X, RubyBounds1.CenterPoint.Y);
        if CharacterPage.Preview.Cursor <> crSizeAll then
          raise Exception.Create('character ruby body cursor mismatch');
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], RubyBounds1.CenterPoint.X, RubyBounds1.CenterPoint.Y);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          RubyBounds1.CenterPoint.X + 8, RubyBounds1.CenterPoint.Y + 6);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], RubyBounds1.CenterPoint.X + 8,
          RubyBounds1.CenterPoint.Y + 6);
        if (CharacterPage.ElementPlacement(1).RubyOffsetX =
          CharacterPlacementBefore.RubyOffsetX) or
          (CharacterPage.ElementPlacement(1).RubyOffsetY =
          CharacterPlacementBefore.RubyOffsetY) or
          (CharacterPage.ElementPlacement(1).X <>
            CharacterPlacementBefore.X) or
          (CharacterPage.ElementPlacement(1).Y <>
            CharacterPlacementBefore.Y) then
          raise Exception.Create('character ruby move mismatch');
        ZoomBefore := CharacterPage.ViewZoom;
        CharacterPage.AdjustPreviewZoom(120,
          Point(CharacterPage.Preview.ClientWidth div 2,
            CharacterPage.Preview.ClientHeight div 2));
        if CharacterPage.ViewZoom <= ZoomBefore then
          raise Exception.Create('character preview zoom mismatch');
        ViewPanBefore := CharacterPage.ViewPan;
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbMiddle,
          [], 2, 2);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          18, 12);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbMiddle,
          [], 18, 12);
        if (CharacterPage.ViewPan.X = ViewPanBefore.X) and
          (CharacterPage.ViewPan.Y = ViewPanBefore.Y) then
          raise Exception.Create('character preview pan mismatch');
        CharacterPage.ElementCombo.ItemIndex := 1;
        CharacterPage.ElementCombo.OnChange(CharacterPage.ElementCombo);
        CharacterPlacementBefore := CharacterPage.ElementPlacement(1);
        CharacterPage.ActionToolbar.Items[1].Execute;
        if (CharacterPage.ElementPlacement(1).ScaleX =
          CharacterPlacementBefore.ScaleX) and
          (CharacterPage.ElementPlacement(1).RubyOffsetX =
          CharacterPlacementBefore.RubyOffsetX) then
          raise Exception.Create('character reset selected mismatch');
        CharacterPage.BaseFontCombo.ItemIndex :=
          CharacterPage.BaseFontCombo.Items.IndexOf('Arial');
        if CharacterPage.ElementPlacement(1).BaseFontName = 'Arial' then
          raise Exception.Create('font applied before explicit commit');
        CharacterPage.BaseFontCombo.Perform(CN_COMMAND,
          MakeWParam(0, CBN_SELCHANGE), 0);
        CharacterPage.BaseFontCombo.Perform(CN_COMMAND,
          MakeWParam(0, CBN_CLOSEUP), 0);
        if CharacterPage.ElementPlacement(1).BaseFontName <> 'Arial' then
          raise Exception.Create('free font list selection was not applied');
        CharacterPage.BaseFontCombo.Perform(WM_MOUSEWHEEL,
          MakeWParam(0, Word(SmallInt(-WHEEL_DELTA))), 0);
        if CharacterPage.ElementPlacement(1).BaseFontName <> WheelFontName then
          raise Exception.Create('free wheel font was not previewed');
        CharacterPage.BaseFontCombo.ItemIndex :=
          CharacterPage.BaseFontCombo.Items.IndexOf('Arial');
        CharacterPage.BaseFontCombo.CommitSelection;
        CharacterPage.FormattingToolbar.Items[0].Execute;
        if (CharacterPage.ActionToolbar.ItemCount <> 5) or
          (CharacterPage.ActionToolbar.Items[0].Glyph <> tbgMoveToCenter) then
          raise Exception.Create('obsolete decoration action remains');
        CharacterPage.FormattingToolbar.Items[4].Execute;
        CharacterPage.FormattingToolbar.Items[5].Execute;
        if not CharacterPage.ElementPlacement(1).OutlineEnabled or
          not CharacterPage.ElementPlacement(1).ShadowEnabled then
          raise Exception.Create('character decoration toggle mismatch');
        CharacterPage.FormattingToolbar.Items[4].Execute;
        CharacterPage.FormattingToolbar.Items[5].Execute;
        if CharacterPage.ElementPlacement(1).OutlineEnabled or
          CharacterPage.ElementPlacement(1).ShadowEnabled then
          raise Exception.Create('character decoration toggle off mismatch');
        CharacterPage.FormattingToolbar.Items[4].Execute;
        CharacterPage.FormattingToolbar.Items[5].Execute;
        for DecorationMode := cldmOutlineBlur to cldmShadowSpread do
        begin
          CharacterPage.Preview.OnPaint(CharacterPage.Preview);
          Bounds := CharacterPage.DecorationHandleRect(DecorationMode);
          if IsRectEmpty(Bounds) then
            raise Exception.Create('free decoration handle missing');
          DragPoint := Bounds.CenterPoint;
          if DecorationMode = cldmShadowOffset then
            ExpectedCursor := crSizeAll
          else
            ExpectedCursor := crSizeWE;
          CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
            DragPoint.X, DragPoint.Y);
          if CharacterPage.Preview.Cursor <> ExpectedCursor then
            raise Exception.CreateFmt('free decoration hover cursor mismatch: %d actual %d',
              [Ord(DecorationMode), Integer(CharacterPage.Preview.Cursor)]);
          DecorationBefore := CharacterPage.ElementPlacement(1);
          CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
            [], DragPoint.X, DragPoint.Y);
          if DecorationMode in [cldmOutlineBlur, cldmShadowBlur] then
            Dec(DragPoint.X, 12)
          else
            Inc(DragPoint.X, 12);
          if DecorationMode = cldmShadowOffset then
            Inc(DragPoint.Y, 8);
          CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
            DragPoint.X, DragPoint.Y);
          CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
            [], DragPoint.X, DragPoint.Y);
          case DecorationMode of
            cldmOutlineBlur:
              if not CharacterPage.ElementPlacement(1).HasOutlineBlur or
                (CharacterPage.ElementPlacement(1).OutlineBlur =
                DecorationBefore.OutlineBlur) then
                raise Exception.Create('free outline blur drag failed');
            cldmOutlineWidth:
              if not CharacterPage.ElementPlacement(1).HasOutlineWidth or
                (CharacterPage.ElementPlacement(1).OutlineWidth =
                DecorationBefore.OutlineWidth) then
                raise Exception.Create('free outline width drag failed');
            cldmShadowBlur:
              if not CharacterPage.ElementPlacement(1).HasShadowBlur or
                (CharacterPage.ElementPlacement(1).ShadowBlur =
                DecorationBefore.ShadowBlur) then
                raise Exception.Create('free shadow blur drag failed');
            cldmShadowOffset:
              if not CharacterPage.ElementPlacement(1).HasShadowOffsetX or
                not CharacterPage.ElementPlacement(1).HasShadowOffsetY then
                raise Exception.Create('free shadow offset drag failed');
            cldmShadowSpread:
              if not CharacterPage.ElementPlacement(1).HasShadowSpread or
                (CharacterPage.ElementPlacement(1).ShadowSpread =
                DecorationBefore.ShadowSpread) then
                raise Exception.Create('free shadow spread drag failed');
          end;
        end;
        CharacterPage.ElementCombo.ItemIndex := 0;
        CharacterPage.ElementCombo.OnChange(CharacterPage.ElementCombo);
        Bounds := CharacterPage.PreviewElementBounds(1);
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [ssShift], Bounds.Right - 1, Bounds.CenterPoint.Y);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [ssShift], Bounds.Right - 1, Bounds.CenterPoint.Y);
        if CharacterPage.SelectedElementCount <> 2 then
          raise Exception.Create('free decoration multi-selection failed');
        CharacterPlacementBefore := CharacterPage.ElementPlacement(0);
        CharacterPlacement1Before := CharacterPage.ElementPlacement(1);
        Bounds := CharacterPage.DecorationHandleRect(cldmOutlineWidth);
        DragPoint := Bounds.CenterPoint;
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], DragPoint.X, DragPoint.Y);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          DragPoint.X + 12, DragPoint.Y);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], DragPoint.X + 12, DragPoint.Y);
        if (CharacterPage.ElementPlacement(0).OutlineWidth =
          CharacterPlacementBefore.OutlineWidth) or
          (CharacterPage.ElementPlacement(1).OutlineWidth =
          CharacterPlacement1Before.OutlineWidth) then
          raise Exception.Create('free decoration multi-drag failed');
        CharacterPage.ElementCombo.ItemIndex := 1;
        CharacterPage.ElementCombo.OnChange(CharacterPage.ElementCombo);
        CharacterPage.ColorPanel.BeforePicker.Color := clRed;
        CharacterPage.ColorPanel.BeforeOpacityTrack.Position := 111;
        CharacterPage.ColorPanel.OnChange(CharacterPage.ColorPanel);
        if not CharacterPage.TryBuildCandidateSettingsTexts(
          CharacterSettingsTexts) or
          (Length(CharacterSettingsTexts) <> 2) then
          raise Exception.Create('character candidate settings build failed');
        PlacementsMatchLyrics := False;
        if not TryDecodeDisplaySettingsText(CharacterSettingsTexts[0],
          CharacterLyrics[0], DecodedCharacterCommon,
          DecodedCharacterPlacements, PlacementsMatchLyrics) or
          not PlacementsMatchLyrics or
          (Length(DecodedCharacterPlacements) <> 2) then
          raise Exception.Create('character candidate settings decode failed');
        if (DecodedCharacterPlacements[1].BaseFontName <> 'Arial') or
          not DecodedCharacterPlacements[1].HasBaseFontStyle or
          (DecodedCharacterPlacements[1].BaseFontStyle =
            DecodedCharacterCommon.BaseFontStyle) or
          not DecodedCharacterPlacements[1].HasBeforeColor or
          (DecodedCharacterPlacements[1].BeforeColor <>
            Cardinal(ColorToRGB(clRed))) or
          not DecodedCharacterPlacements[1].HasBeforeOpacity or
          (DecodedCharacterPlacements[1].BeforeOpacity <> 111) or
          not DecodedCharacterPlacements[1].HasOutlineEnabled or
          not DecodedCharacterPlacements[1].OutlineEnabled or
          not DecodedCharacterPlacements[1].HasShadowEnabled or
          not DecodedCharacterPlacements[1].ShadowEnabled or
          not DecodedCharacterPlacements[1].HasOutlineWidth or
          not DecodedCharacterPlacements[1].HasOutlineBlur or
          not DecodedCharacterPlacements[1].HasShadowOffsetX or
          not DecodedCharacterPlacements[1].HasShadowOffsetY or
          not DecodedCharacterPlacements[1].HasShadowBlur or
          not DecodedCharacterPlacements[1].HasShadowSpread or
          (DecodedCharacterPlacements[1].RubyScaleX <= 1) or
          (DecodedCharacterPlacements[1].RubyScaleY <= 1) or
          not DecodedCharacterPlacements[1].HasRubyOffsetX or
          not DecodedCharacterPlacements[1].HasRubyOffsetY or
          not DecodedCharacterPlacements[1].HasRubyCharacterSpacing then
          raise Exception.Create('character style settings were not retained');
        Form.SetMode(DISPLAY_SETTINGS_MODE_LINE);
        if (Form.CandidateCombo.Items.Count <> 3) or
          (Form.SelectedCandidateIndex <> 1) then
          raise Exception.Create('line candidates were not configured');
        LinePage.OutlineButton.Execute;
        if not LinePage.SelectedCommonSettings.OutlineEnabled then
          raise Exception.Create('line outline edit was not retained');
        LinePage.ColorPanel.TargetToolbar.FindByTag(1).Execute;
        LinePage.ColorPanel.BeforePicker.Color := clRed;
        LinePage.ColorPanel.BeforeOpacityTrack.Position := 123;
        LinePage.ColorPanel.OnChange(LinePage.ColorPanel);
        if (LinePage.SelectedCommonSettings.BeforeOutlineColor <>
          Cardinal(ColorToRGB(clRed))) or
          (LinePage.SelectedCommonSettings.BeforeOutlineOpacity <> 123) then
          raise Exception.Create('line outline color edit was not retained');
        BaseStyleBefore := LinePage.SelectedCommonSettings.BaseFontStyle;
        LinePage.FormattingToolbar.Items[0].Execute;
        if ((LinePage.SelectedCommonSettings.BaseFontStyle xor
          BaseStyleBefore) and 1) = 0 then
          raise Exception.Create('line font style edit was not retained');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.BasePreviewBounds;
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2 + 12,
          (Bounds.Top + Bounds.Bottom) div 2 + 8);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if (LinePage.SelectedCommonSettings.PositionX =
          SettingsBeforeDrag.PositionX) and
          (LinePage.SelectedCommonSettings.PositionY =
          SettingsBeforeDrag.PositionY) then
          raise Exception.Create('line position drag was not retained');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.BasePreviewBounds;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          Bounds.CenterPoint.X, Bounds.CenterPoint.Y);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          LinePage.Preview.ClientWidth div 2 + 4,
          LinePage.Preview.ClientHeight div 2 + 4);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if (LinePage.SelectedCommonSettings.PositionX <> 0) or
          (LinePage.SelectedCommonSettings.PositionY <> 0) then
          raise Exception.Create('line center snap failed');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.BasePreviewBounds;
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          Bounds.Right, Bounds.Bottom);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          Bounds.Right, Bounds.Bottom + 8);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if LinePage.SelectedCommonSettings.BaseFontHeight =
          SettingsBeforeDrag.BaseFontHeight then
          raise Exception.Create('line size drag was not retained');
        for CornerIndex := 0 to 3 do
        begin
          LinePage.Preview.OnPaint(LinePage.Preview);
          Bounds := LinePage.BasePreviewBounds;
          case CornerIndex of
            0: begin
              CornerPoint := Point(Bounds.Left, Bounds.Top);
              DragPoint := Point(Bounds.Left - 12, Bounds.Top - 12);
              ExpectedCursor := crSizeNWSE;
            end;
            1: begin
              CornerPoint := Point(Bounds.Right, Bounds.Top);
              DragPoint := Point(Bounds.Right + 12, Bounds.Top - 12);
              ExpectedCursor := crSizeNESW;
            end;
            2: begin
              CornerPoint := Point(Bounds.Left, Bounds.Bottom);
              DragPoint := Point(Bounds.Left - 12, Bounds.Bottom + 12);
              ExpectedCursor := crSizeNESW;
            end;
          else
            CornerPoint := Point(Bounds.Right, Bounds.Bottom);
            DragPoint := Point(Bounds.Right + 12, Bounds.Bottom + 12);
            ExpectedCursor := crSizeNWSE;
          end;
          LinePage.Preview.OnMouseMove(LinePage.Preview, [],
            CornerPoint.X, CornerPoint.Y);
          if LinePage.Preview.Cursor <> ExpectedCursor then
            raise Exception.Create('line corner resize cursor mismatch');
          SettingsBeforeDrag := LinePage.SelectedCommonSettings;
          LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
            CornerPoint.X, CornerPoint.Y);
          LinePage.Preview.OnMouseMove(LinePage.Preview, [],
            DragPoint.X, DragPoint.Y);
          LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [],
            DragPoint.X, DragPoint.Y);
          if LinePage.SelectedCommonSettings.BaseFontHeight <=
            SettingsBeforeDrag.BaseFontHeight then
            raise Exception.Create('line corner resize did not enlarge text');
        end;
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.BasePreviewBounds;
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          Bounds.Left, (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          Bounds.Left - 20, (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if LinePage.SelectedCommonSettings.BaseCharacterSpacing =
          SettingsBeforeDrag.BaseCharacterSpacing then
          raise Exception.Create('line base spacing drag was not retained');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.RubyPreviewBounds;
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2 - 8);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if LinePage.SelectedCommonSettings.RubyGapAdjustment =
          SettingsBeforeDrag.RubyGapAdjustment then
          raise Exception.Create('line ruby gap drag was not retained');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.RubyPreviewBounds;
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          Bounds.Left, (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          Bounds.Left - 20, (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if LinePage.SelectedCommonSettings.RubyCharacterSpacing =
          SettingsBeforeDrag.RubyCharacterSpacing then
          raise Exception.Create('line ruby spacing drag was not retained');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.RubyPreviewBounds;
        LinePage.Preview.OnMouseMove(LinePage.Preview, [], Bounds.Left,
          (Bounds.Top + Bounds.Bottom) div 2);
        if LinePage.Preview.Cursor <> crSizeWE then
          raise Exception.Create('ruby spacing hover cursor mismatch');
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        if LinePage.Preview.Cursor <> crSizeNS then
          raise Exception.Create('ruby gap hover cursor mismatch');
        LinePage.Preview.OnMouseMove(LinePage.Preview, [], Bounds.Right,
          Bounds.Bottom);
        if LinePage.Preview.Cursor <> crSizeNWSE then
          raise Exception.Create('ruby resize hover cursor mismatch');
        BaseBoundsBeforeRubyResize := LinePage.BasePreviewBounds;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          Bounds.Right, Bounds.Bottom);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [], Bounds.Right,
          Bounds.Bottom + 10);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        LinePage.Preview.OnPaint(LinePage.Preview);
        if LinePage.BasePreviewBounds.Top <>
          BaseBoundsBeforeRubyResize.Top then
          raise Exception.Create('ruby size moved the base lyrics');
        Bounds := LinePage.RubyPreviewBounds;
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          Bounds.Left, Bounds.Top);
        if LinePage.Preview.Cursor <> crSizeNWSE then
          raise Exception.Create('ruby top-left resize cursor mismatch');
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          Bounds.Left, Bounds.Top);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          Bounds.Left - 12, Bounds.Top - 12);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [],
          Bounds.Left - 12, Bounds.Top - 12);
        if LinePage.SelectedCommonSettings.RubyFontHeight <=
          SettingsBeforeDrag.RubyFontHeight then
          raise Exception.Create('ruby top-left resize did not enlarge text');
        LinePage.Preview.OnPaint(LinePage.Preview);
        if LinePage.BasePreviewBounds.Top <>
          BaseBoundsBeforeRubyResize.Top then
          raise Exception.Create('ruby top-left resize moved the base lyrics');
        Bounds := LinePage.BasePreviewBounds;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        if LinePage.Preview.Cursor <> crSizeAll then
          raise Exception.Create('line move hover cursor mismatch');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.DecorationHandleRect(ldpdOutlineWidth);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        if LinePage.Preview.Cursor <> crSizeWE then
          raise Exception.Create('outline width hover cursor mismatch');
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2 + 10,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if LinePage.SelectedCommonSettings.OutlineWidth =
          SettingsBeforeDrag.OutlineWidth then
          raise Exception.Create('outline width drag was not retained');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.DecorationHandleRect(ldpdOutlineBlur);
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2 - 10,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if LinePage.SelectedCommonSettings.OutlineBlur =
          SettingsBeforeDrag.OutlineBlur then
          raise Exception.Create('outline blur drag was not retained');
        LinePage.ShadowButton.Execute;
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.DecorationHandleRect(ldpdShadowOffset);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        if LinePage.Preview.Cursor <> crSizeAll then
          raise Exception.Create('shadow offset hover cursor mismatch');
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2 + 10,
          (Bounds.Top + Bounds.Bottom) div 2 + 5);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if (LinePage.SelectedCommonSettings.ShadowOffsetX =
          SettingsBeforeDrag.ShadowOffsetX) or
          (LinePage.SelectedCommonSettings.ShadowOffsetY =
          SettingsBeforeDrag.ShadowOffsetY) then
          raise Exception.Create('shadow offset drag was not retained');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.DecorationHandleRect(ldpdShadowBlur);
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2 - 10,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if LinePage.SelectedCommonSettings.ShadowBlur =
          SettingsBeforeDrag.ShadowBlur then
          raise Exception.Create('shadow blur drag was not retained');
        LinePage.Preview.OnPaint(LinePage.Preview);
        Bounds := LinePage.DecorationHandleRect(ldpdShadowSpread);
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          (Bounds.Left + Bounds.Right) div 2,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2 + 10,
          (Bounds.Top + Bounds.Bottom) div 2);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if LinePage.SelectedCommonSettings.ShadowSpread =
          SettingsBeforeDrag.ShadowSpread then
          raise Exception.Create('shadow spread drag was not retained');
        CommonSettings[1] := LinePage.SelectedCommonSettings;
        LinePage.ConfigureCandidates(
          ['[first](one) middle [last](two)'],
          [CommonSettings[1]], 0);
        LinePage.Preview.OnPaint(LinePage.Preview);
        if LinePage.RubyPreviewRectCount <> 2 then
          raise Exception.Create('ruby spans were not laid out separately');
        RubyBounds0 := LinePage.RubyPreviewRect(0);
        RubyBounds1 := LinePage.RubyPreviewRect(1);
        if ((RubyBounds0.Left + RubyBounds0.Right) div 2) >=
          ((RubyBounds1.Left + RubyBounds1.Right) div 2) then
          raise Exception.Create('ruby spans did not follow base ranges');
        ZoomBefore := LinePage.ViewZoom;
        LinePage.AdjustPreviewZoom(120,
          Point(LinePage.Preview.ClientWidth div 3,
          LinePage.Preview.ClientHeight div 3));
        if LinePage.ViewZoom <= ZoomBefore then
          raise Exception.Create('preview wheel zoom was not retained');
        ViewPanBefore := LinePage.ViewPan;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbMiddle, [], 5, 5);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [], 20, 15);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbMiddle, [], 20, 15);
        if SameValue(LinePage.ViewPan.X, ViewPanBefore.X) or
          SameValue(LinePage.ViewPan.Y, ViewPanBefore.Y) then
          raise Exception.Create('preview drag pan was not retained');
        LinePage.ConfigureCandidates(['first', '[second](ruby)', 'third'],
          CommonSettings, 1);
        EditedCandidateCommon := LinePage.CandidateCommonSettings;
        if (Length(EditedCandidateCommon) <> 3) or
          (EditedCandidateCommon[1].OutlineWidth <>
          EditedCandidateCommon[0].OutlineWidth) or
          (EditedCandidateCommon[1].OutlineWidth <>
          EditedCandidateCommon[2].OutlineWidth) or
          (EditedCandidateCommon[0].PositionY =
          EditedCandidateCommon[2].PositionY) then
          raise Exception.Create('shared line style or independent positions mismatch');
        Form.SetMode(DISPLAY_SETTINGS_MODE_FREE);
        if Form.CurrentMode <> DISPLAY_SETTINGS_MODE_FREE then
          raise Exception.Create('free mode switch failed');
        if (Form.CandidateCombo.Items.Count <> 2) or
          (Form.SelectedCandidateIndex <> 0) then
          raise Exception.Create('free candidates were not configured');
        Form.CandidateCombo.ItemIndex := 1;
        Form.CandidateCombo.OnChange(Form.CandidateCombo);
        Form.SetMode(DISPLAY_SETTINGS_MODE_LINE);
        if Form.CurrentMode <> DISPLAY_SETTINGS_MODE_LINE then
          raise Exception.Create('line mode switch failed');
        Form.SetMode(DISPLAY_SETTINGS_MODE_FREE);
        if Form.SelectedCandidateIndex <> 1 then
          raise Exception.Create('free candidate selection was not retained');
        Form.RestoreInitialState;
        if (Form.CurrentMode <> DISPLAY_SETTINGS_MODE_LINE) or
          (Form.SelectedCandidateIndex <> 1) or
          (LinePage.SelectedCommonSettings.BaseFontName <> 'Arial') then
          raise Exception.Create('line initial state was not restored');
        Form.SetMode(DISPLAY_SETTINGS_MODE_FREE);
        if (Form.SelectedCandidateIndex <> 0) or
          (CharacterPage.ElementPlacement(0).X <>
          InitialCharacterPlacement.X) or
          (CharacterPage.ElementPlacement(0).Y <>
          InitialCharacterPlacement.Y) or
          (CharacterPage.ElementPlacement(0).ScaleX <>
          InitialCharacterPlacement.ScaleX) or
          (CharacterPage.ElementPlacement(0).ScaleY <>
          InitialCharacterPlacement.ScaleY) then
          raise Exception.Create('free initial state was not restored');
        Form.SetMode(DISPLAY_SETTINGS_MODE_LINE);
        Form.ModeToolbar.Items[0].Execute;
        if Form.ModalResult <> mrOk then
          raise Exception.Create('close toolbar did not accept edits');
        Form.ModalResult := mrNone;
        Application.ProcessMessages;
        if ExceptionHandler.Failed then
          raise Exception.Create('form construction raised an exception');
        if (ParamCount > 0) and
          SameText(ParamStr(1), '--show') then
        begin
          Form.Show;
          Application.ProcessMessages;
          if ExceptionHandler.Failed then
            raise Exception.Create('display raised an exception');
          Form.SetMode(DISPLAY_SETTINGS_MODE_FREE);
          Application.ProcessMessages;
          if ExceptionHandler.Failed then
            raise Exception.Create('free page display raised an exception');
          Form.SetMode(DISPLAY_SETTINGS_MODE_LINE);
          Application.ProcessMessages;
          if ExceptionHandler.Failed then
            raise Exception.Create('line page redisplay raised an exception');
          Form.Hide;
          Application.ProcessMessages;
        end;
        if (ParamCount > 1) and
          SameText(ParamStr(1), '--snapshot') then
        begin
          SnapshotPath := ParamStr(2);
          if (ParamCount > 2) and SameText(ParamStr(3), 'free') then
            Form.SetMode(DISPLAY_SETTINGS_MODE_FREE);
          Form.Show;
          Application.ProcessMessages;
          if ExceptionHandler.Failed then
            raise Exception.Create('display raised an exception');
          Bitmap := Form.GetFormImage;
          try
            Bitmap.SaveToFile(SnapshotPath);
          finally
            Bitmap.Free;
          end;
          Form.Hide;
          Application.ProcessMessages;
        end;
      finally
        FreeAndNil(Form);
      end;
      Writeln('DISPLAY_FORM_OK');
    except
      on E: Exception do
      begin
        Writeln(E.ClassName + ': ' + E.Message);
        ExitCode := 1;
      end;
    end;
  finally
    Application.OnException := nil;
    ExceptionHandler.Free;
    DeleteFile(PChar(HistoryFileName));
  end;
end.
