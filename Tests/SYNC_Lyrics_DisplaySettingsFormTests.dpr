program SYNC_Lyrics_DisplaySettingsFormTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  System.Types,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  TextRendererSkiaRuntime in '..\Source\Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  SYNC_Lyrics_ToolbarButtons in '..\Source\Lib\SYNC_Lyrics_ToolbarButtons.pas',
  SYNC_Lyrics_DarkTheme in '..\Source\Lib\SYNC_Lyrics_DarkTheme.pas',
  SYNC_Lyrics_LyricParser in '..\Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_DisplaySettingsData in '..\Source\Common\Render\SYNC_Lyrics_DisplaySettingsData.pas',
  ColorPickerColorMath in '..\Source\Lib\ColorPicker\ColorPickerColorMath.pas',
  ColorPickerHueBar in '..\Source\Lib\ColorPicker\ColorPickerHueBar.pas',
  ColorPickerSVArea in '..\Source\Lib\ColorPicker\ColorPickerSVArea.pas',
  SYNC_Lyrics_DisplaySettingsModePage in '..\Source\Plugin\Filter\SYNC_Lyrics_DisplaySettingsModePage.pas',
  SYNC_Lyrics_DisplaySettingsColorPanel in '..\Source\Plugin\Filter\SYNC_Lyrics_DisplaySettingsColorPanel.pas',
  SYNC_Lyrics_DisplayPreviewBackground in '..\Source\Plugin\Filter\SYNC_Lyrics_DisplayPreviewBackground.pas',
  SYNC_Lyrics_CharacterLayoutInteraction in '..\Source\Plugin\Filter\SYNC_Lyrics_CharacterLayoutInteraction.pas',
  SYNC_Lyrics_LineDisplaySettingsPage in '..\Source\Plugin\Filter\SYNC_Lyrics_LineDisplaySettingsPage.pas',
  SYNC_Lyrics_CharacterDisplaySettingsPage in '..\Source\Plugin\Filter\SYNC_Lyrics_CharacterDisplaySettingsPage.pas',
  SYNC_Lyrics_DisplaySettingsForm in '..\Source\Plugin\Filter\SYNC_Lyrics_DisplaySettingsForm.pas';

var
  Bitmap: TBitmap;
  BaseStyleBefore: Byte;
  BackgroundPixels: TBytes;
  BaseBoundsBeforeRubyResize: TRect;
  Bounds: TRect;
  EditedCandidateCommon: TArray<TDisplayCommonSettings>;
  CommonSettings: TArray<TDisplayCommonSettings>;
  CharacterCommonSettings: TArray<TDisplayCommonSettings>;
  CharacterLyrics: TArray<string>;
  InitialCharacterPlacement: TDisplayPlacementItem;
  CharacterPlacementBefore: TDisplayPlacementItem;
  CharacterPlacement1Before: TDisplayPlacementItem;
  CharacterSettingsTexts: TArray<string>;
  DecodedCharacterCommon: TDisplayCommonSettings;
  DecodedCharacterPlacements: TDisplayPlacementItems;
  Form: TFormLyricsDisplaySettings;
  CharacterPage: TFrameLyricsCharacterDisplaySettingsPage;
  LinePage: TFrameLyricsLineDisplaySettingsPage;
  RubyBounds0: TRect;
  RubyBounds1: TRect;
  SettingsBeforeDrag: TDisplayCommonSettings;
  SnapshotPath: string;
  ViewPanBefore: TPointF;
  ZoomBefore: Double;
  PlacementsMatchLyrics: Boolean;

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

var
  ExceptionHandler: TTestExceptionHandler;

begin
  ExceptionHandler := nil;
  Form := nil;
  try
    try
      Application.Initialize;
      TTextRendererSkiaRuntime.Acquire(
        ExtractFilePath(ParamStr(0)) + 'sk4d.dll');
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
        if Form.ClientHeight <> MulDiv(650, Form.CurrentPPI, 96) then
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
        CommonSettings[2] := DefaultDisplayCommonSettings;
        LinePage := TFrameLyricsLineDisplaySettingsPage(
          Form.PageForMode(DISPLAY_SETTINGS_MODE_LINE));
        if not LinePage.HasSkiaPreviewRenderer then
          raise Exception.Create('line Skia preview renderer was not created');
        CharacterPage := TFrameLyricsCharacterDisplaySettingsPage(
          Form.PageForMode(DISPLAY_SETTINGS_MODE_FREE));
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
        LinePage.ConfigureCandidates(['first', '[second](ruby)', 'third'],
          CommonSettings, 1);
        if (LinePage.SelectedLyrics <> '[second](ruby)') or
          (LinePage.SelectedCommonSettings.BaseFontName <> 'Arial') then
          raise Exception.Create('line candidate settings were not loaded');
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
        Form.SetMode(DISPLAY_SETTINGS_MODE_FREE);
        CharacterPage.Preview.OnPaint(CharacterPage.Preview);
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
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbRight,
          [], Bounds.Left - 4, Bounds.Top - 4);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          Bounds.Right + 4, Bounds.Bottom + 4);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbRight,
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
        CharacterPlacementBefore := CharacterPage.ElementPlacement(1);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2, Bounds.Top);
        if CharacterPage.Preview.Cursor <> crSizeAll then
          raise Exception.Create('character ruby cursor mismatch');
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], (Bounds.Left + Bounds.Right) div 2, Bounds.Top);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          (Bounds.Left + Bounds.Right) div 2 + 8, Bounds.Top + 6);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], (Bounds.Left + Bounds.Right) div 2 + 8, Bounds.Top + 6);
        if (CharacterPage.ElementPlacement(1).RubyOffsetX =
          CharacterPlacementBefore.RubyOffsetX) or
          (CharacterPage.ElementPlacement(1).RubyOffsetY =
          CharacterPlacementBefore.RubyOffsetY) then
          raise Exception.Create('character ruby move mismatch');
        ZoomBefore := CharacterPage.ViewZoom;
        CharacterPage.AdjustPreviewZoom(120,
          Point(CharacterPage.Preview.ClientWidth div 2,
            CharacterPage.Preview.ClientHeight div 2));
        if CharacterPage.ViewZoom <= ZoomBefore then
          raise Exception.Create('character preview zoom mismatch');
        ViewPanBefore := CharacterPage.ViewPan;
        CharacterPage.Preview.OnMouseDown(CharacterPage.Preview, mbLeft,
          [], 2, 2);
        CharacterPage.Preview.OnMouseMove(CharacterPage.Preview, [],
          18, 12);
        CharacterPage.Preview.OnMouseUp(CharacterPage.Preview, mbLeft,
          [], 18, 12);
        if (CharacterPage.ViewPan.X = ViewPanBefore.X) and
          (CharacterPage.ViewPan.Y = ViewPanBefore.Y) then
          raise Exception.Create('character preview pan mismatch');
        CharacterPage.ElementCombo.ItemIndex := 1;
        CharacterPage.ElementCombo.OnChange(CharacterPage.ElementCombo);
        CharacterPlacementBefore := CharacterPage.ElementPlacement(1);
        CharacterPage.ActionToolbar.Items[2].Execute;
        if (CharacterPage.ElementPlacement(1).ScaleX =
          CharacterPlacementBefore.ScaleX) and
          (CharacterPage.ElementPlacement(1).RubyOffsetX =
          CharacterPlacementBefore.RubyOffsetX) then
          raise Exception.Create('character reset selected mismatch');
        CharacterPage.BaseFontCombo.ItemIndex :=
          CharacterPage.BaseFontCombo.Items.IndexOf('Arial');
        CharacterPage.BaseFontCombo.OnChange(
          CharacterPage.BaseFontCombo);
        CharacterPage.FormattingToolbar.Items[0].Execute;
        CharacterPage.ColorPanel.BeforePicker.Color := clRed;
        CharacterPage.ColorPanel.BeforeOpacityTrack.Position := 111;
        CharacterPage.ColorPanel.OnChange(CharacterPage.ColorPanel);
        SettingsBeforeDrag := CharacterPage.SelectedDecorationSettings;
        SettingsBeforeDrag.OutlineEnabled := True;
        SettingsBeforeDrag.OutlineWidth := 7.25;
        SettingsBeforeDrag.OutlineBlur := 2.5;
        SettingsBeforeDrag.ShadowEnabled := True;
        SettingsBeforeDrag.ShadowOffsetX := 11;
        SettingsBeforeDrag.ShadowOffsetY := -6;
        SettingsBeforeDrag.ShadowBlur := 3;
        SettingsBeforeDrag.ShadowSpread := 4;
        SettingsBeforeDrag.BeforeOutlineColor := ColorToRGB(clBlue);
        SettingsBeforeDrag.BeforeOutlineOpacity := 77;
        CharacterPage.ApplySelectedDecoration(SettingsBeforeDrag);
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
          not DecodedCharacterPlacements[1].HasOutlineWidth or
          (Abs(DecodedCharacterPlacements[1].OutlineWidth - 7.25) > 0.001) or
          not DecodedCharacterPlacements[1].HasOutlineBlur or
          (Abs(DecodedCharacterPlacements[1].OutlineBlur - 2.5) > 0.001) or
          not DecodedCharacterPlacements[1].HasShadowEnabled or
          not DecodedCharacterPlacements[1].ShadowEnabled or
          not DecodedCharacterPlacements[1].HasShadowOffsetX or
          (Abs(DecodedCharacterPlacements[1].ShadowOffsetX - 11) > 0.001) or
          not DecodedCharacterPlacements[1].HasShadowOffsetY or
          (Abs(DecodedCharacterPlacements[1].ShadowOffsetY + 6) > 0.001) or
          not DecodedCharacterPlacements[1].HasShadowBlur or
          (Abs(DecodedCharacterPlacements[1].ShadowBlur - 3) > 0.001) or
          not DecodedCharacterPlacements[1].HasShadowSpread or
          (Abs(DecodedCharacterPlacements[1].ShadowSpread - 4) > 0.001) or
          not DecodedCharacterPlacements[1].HasBeforeOutlineColor or
          (DecodedCharacterPlacements[1].BeforeOutlineColor <>
            Cardinal(ColorToRGB(clBlue))) or
          not DecodedCharacterPlacements[1].HasBeforeOutlineOpacity or
          (DecodedCharacterPlacements[1].BeforeOutlineOpacity <> 77) then
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
        SettingsBeforeDrag := LinePage.SelectedCommonSettings;
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [],
          Bounds.Right, Bounds.Bottom);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [],
          Bounds.Right, Bounds.Bottom + 8);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 0, 0);
        if LinePage.SelectedCommonSettings.BaseFontHeight =
          SettingsBeforeDrag.BaseFontHeight then
          raise Exception.Create('line size drag was not retained');
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
        LinePage.Preview.OnMouseDown(LinePage.Preview, mbLeft, [], 5, 5);
        LinePage.Preview.OnMouseMove(LinePage.Preview, [], 20, 15);
        LinePage.Preview.OnMouseUp(LinePage.Preview, mbLeft, [], 20, 15);
        if SameValue(LinePage.ViewPan.X, ViewPanBefore.X) or
          SameValue(LinePage.ViewPan.Y, ViewPanBefore.Y) then
          raise Exception.Create('preview drag pan was not retained');
        LinePage.ConfigureCandidates(['first', '[second](ruby)', 'third'],
          CommonSettings, 1);
        EditedCandidateCommon := LinePage.CandidateCommonSettings;
        if (Length(EditedCandidateCommon) <> 3) or
          (EditedCandidateCommon[1].OutlineWidth =
          EditedCandidateCommon[0].OutlineWidth) then
          raise Exception.Create('all line candidate edits were not exposed');
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
  end;
end.
