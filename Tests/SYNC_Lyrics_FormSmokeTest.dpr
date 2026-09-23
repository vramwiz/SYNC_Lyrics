program SYNC_Lyrics_FormSmokeTest;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  System.UITypes,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  TextRendererSkiaRuntime in '..\Source\Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  SYNC_Lyrics_DarkTheme in '..\Source\Lib\SYNC_Lyrics_DarkTheme.pas',
  SYNC_Lyrics_ListBoxEdit in '..\Source\Lib\SYNC_Lyrics_ListBoxEdit.pas',
  SYNC_Lyrics_ToolbarButtons in '..\Source\Lib\SYNC_Lyrics_ToolbarButtons.pas',
  SYNC_Lyrics_LyricParser in '..\Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_DisplaySettingsData in '..\Source\Common\Render\SYNC_Lyrics_DisplaySettingsData.pas',
  SYNC_Lyrics_SyncFormat in '..\Source\Common\Sync\SYNC_Lyrics_SyncFormat.pas',
  SYNC_Lyrics_SongLyricsData in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsData.pas',
  SYNC_Lyrics_SongLyricsModel in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsModel.pas',
  SYNC_Lyrics_InitialLyricsFrame in '..\Source\Plugin\Filter\Sync\SYNC_Lyrics_InitialLyricsFrame.pas',
  SYNC_Lyrics_ManualSyncWaveform in '..\Source\Plugin\Filter\Sync\Manual\SYNC_Lyrics_ManualSyncWaveform.pas',
  SYNC_Lyrics_ManualSyncSettingsForm in '..\Source\Plugin\Filter\Sync\Manual\SYNC_Lyrics_ManualSyncSettingsForm.pas',
  SYNC_Lyrics_MusicSyncSettingsForm in '..\Source\Plugin\Filter\Sync\Midi\SYNC_Lyrics_MusicSyncSettingsForm.pas',
  SYNC_Lyrics_MusicSyncEditorFrame in '..\Source\Plugin\Filter\Sync\SYNC_Lyrics_MusicSyncEditorFrame.pas',
  SYNC_Lyrics_LineDisplaySettingsForm in '..\Source\Plugin\Filter\Display\Line\SYNC_Lyrics_LineDisplaySettingsForm.pas',
  SYNC_Lyrics_CharacterLayoutSettingsForm in '..\Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterLayoutSettingsForm.pas',
  SYNC_Lyrics_DisplaySettingsModePage in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplaySettingsModePage.pas',
  SYNC_Lyrics_DisplaySettingsColorPanel in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplaySettingsColorPanel.pas',
  SYNC_Lyrics_DisplayPreviewBackground in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplayPreviewBackground.pas',
  SYNC_Lyrics_LineDisplaySettingsPage in '..\Source\Plugin\Filter\Display\Line\SYNC_Lyrics_LineDisplaySettingsPage.pas',
  SYNC_Lyrics_CharacterDisplaySettingsPage in '..\Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterDisplaySettingsPage.pas',
  SYNC_Lyrics_DisplaySettingsForm in '..\Source\Plugin\Filter\Display\SYNC_Lyrics_DisplaySettingsForm.pas',
  SYNC_Lyrics_SyncEditorForm in '..\Source\Plugin\Filter\Sync\SYNC_Lyrics_SyncEditorForm.pas';

var
  CandidateCaptions: TArray<string>;
  CandidateCommon: TArray<TDisplayCommonSettings>;
  CandidateLyrics: TArray<string>;
  CandidateSettingsTexts: TArray<string>;
  CharacterLayoutForm: TFormLyricsCharacterLayoutSettings;
  CharacterLayoutToolbar: TSyncLyricsToolbarButtons;
  DisplaySettingsForm: TFormLyricsDisplaySettings;
  DisplayCharacterPage: TFrameLyricsCharacterDisplaySettingsPage;
  DisplayLinePage: TFrameLyricsLineDisplaySettingsPage;
  EditorForm: TFormLyricsSyncEditor;
  InputFrame: TFrameLyricsInitialInput;
  LineDisplayForm: TFormLyricsLineDisplaySettings;
  MusicSyncFrame: TFrameLyricsMusicSyncEditor;
  MusicSyncForm: TFormLyricsMusicSyncSettings;
  ManualSyncForm: TFormLyricsManualSyncSettings;
  PreviewPixels: TBytes;
  LyricsToolbar: TSyncLyricsToolbarButtons;
  LegacyDisplayFontHeight: Integer;
  LegacyDisplayFontName: string;
  LineDisplayToolbar: TSyncLyricsToolbarButtons;
  TopToolbar: TSyncLyricsToolbarButtons;
  ToolbarExtent: Integer;
  Key: Word;
  ErrorText: string;
  SongDataText: string;
  ReloadedModel: TLyricsSongModel;
  StoredModel: TLyricsSongModel;
  CanClose: Boolean;

function FindOwnedComponentByClass(Owner: TComponent;
  ComponentClass: TComponentClass): TComponent;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Owner.ComponentCount - 1 do
    if Owner.Components[I].InheritsFrom(ComponentClass) then
      Exit(Owner.Components[I]);
end;

function FindChildControlByClass(Parent: TWinControl;
  ControlClass: TControlClass): TControl;
var
  Child: TControl;
  I: Integer;
begin
  Result := nil;
  for I := 0 to Parent.ControlCount - 1 do
  begin
    Child := Parent.Controls[I];
    if Child.InheritsFrom(ControlClass) then
      Exit(Child);
    if Child is TWinControl then
    begin
      Result := FindChildControlByClass(TWinControl(Child), ControlClass);
      if Result <> nil then
        Exit;
    end;
  end;
end;

begin
  try
    Application.Initialize;
    TTextRendererSkiaRuntime.Acquire(
      ExtractFilePath(ParamStr(0)) + 'sk4d.dll');
    LineDisplayForm := TFormLyricsLineDisplaySettings.Create(nil);
    LegacyDisplayFontHeight := LineDisplayForm.Font.Height;
    LegacyDisplayFontName := LineDisplayForm.Font.Name;
    try
      if LineDisplayForm.Color <> SYNC_LYRICS_DARK_BACKGROUND_COLOR then
        raise Exception.Create('The placement editor did not use the dark background.');
      if (LineDisplayForm.CandidateCombo.Style <> csOwnerDrawFixed) or
        not Assigned(LineDisplayForm.CandidateCombo.OnDrawItem) then
        raise Exception.Create('The placement combo box was not owner-drawn.');
      if (LineDisplayForm.PlacementModeCombo.Style <> csOwnerDrawFixed) or
        not Assigned(LineDisplayForm.PlacementModeCombo.OnDrawItem) then
        raise Exception.Create(
          'The line placement mode combo box was not owner-drawn.');
      LineDisplayForm.ConfigurePlacementMode(1);
      if LineDisplayForm.SelectedPlacementMode <> 1 then
        raise Exception.Create(
          'The line placement mode selection was not retained.');
      if (LineDisplayForm.FindComponent('DescriptionLabel') <> nil) or
        (LineDisplayForm.FindComponent('LyricsEdit') <> nil) or
        (LineDisplayForm.FindComponent('SelectionLabel') <> nil) then
        raise Exception.Create(
          'The removed line-display header rows were still present.');
      CandidateCaptions := ['1: first', '2: second'];
      CandidateLyrics := ['first', 'second'];
      SetLength(CandidateCommon, 2);
      CandidateCommon[0] := DefaultDisplayCommonSettings;
      CandidateCommon[1] := DefaultDisplayCommonSettings;
      CandidateCommon[1].OutlineEnabled := True;
      CandidateCommon[1].OutlineWidth := 9.5;
      CandidateCommon[1].ShadowEnabled := True;
      CandidateCommon[1].ShadowOffsetX := 14;
      CandidateCommon[1].BeforeOutlineColor := $00010203;
      CandidateCommon[1].AfterShadowOpacity := 123;
      LineDisplayForm.ConfigureCandidates(CandidateCaptions,
        CandidateLyrics, CandidateCommon, 1);
      if not LineDisplayForm.CandidateCombo.Visible or
        (LineDisplayForm.SelectedCandidateIndex <> 1) or
        (LineDisplayForm.EnteredLyrics <> 'second') then
        raise Exception.Create(
          'The initial placement candidate was not loaded.');
      CandidateCommon[0] := LineDisplayForm.SelectedCommonSettings;
      if not CandidateCommon[0].OutlineEnabled or
        (Abs(CandidateCommon[0].OutlineWidth - 9.5) > 0.001) or
        not CandidateCommon[0].ShadowEnabled or
        (Abs(CandidateCommon[0].ShadowOffsetX - 14) > 0.001) or
        (CandidateCommon[0].BeforeOutlineColor <> $00010203) or
        (CandidateCommon[0].AfterShadowOpacity <> 123) then
        raise Exception.Create(
          'The line decoration settings did not survive the form round-trip.');
      if (LineDisplayForm.ClientHeight <> 548) or
        (LineDisplayForm.PreviewPaintBox.Top >= 205) or
        (LineDisplayForm.PreviewPaintBox.Height < 400) then
        raise Exception.Create(
          'The compact form height or placement canvas size was incorrect.');
      LineDisplayToolbar := FindOwnedComponentByClass(LineDisplayForm,
        TSyncLyricsToolbarButtons) as TSyncLyricsToolbarButtons;
      if (LineDisplayToolbar = nil) or
        (LineDisplayToolbar.FindByTag(100) = nil) or
        (LineDisplayToolbar.FindByTag(100).Glyph <> tbgFreePlacement) or
        LineDisplayForm.PlacementModeCombo.Visible or
        (LineDisplayForm.BaseFontCombo.Width > 160) or
        (LineDisplayForm.RubyFontCombo.Width > 160) or
        (LineDisplayToolbar.Left <= LineDisplayForm.RubyFontCombo.Left +
          LineDisplayForm.RubyFontCombo.Width) or
        (LineDisplayToolbar.Top >= LineDisplayForm.PreviewPaintBox.Top) then
        raise Exception.Create(
          'The font selectors and formatting icons did not share one row.');
      LineDisplayToolbar.FindByTag(100).Execute;
      if (LineDisplayForm.ModalResult <>
        PLACEMENT_MODE_SWITCH_MODAL_RESULT) or
        (LineDisplayForm.SelectedPlacementMode <> 1) then
        raise Exception.Create(
          'The line editor did not request an immediate free-mode switch.');
    finally
      LineDisplayForm.Free;
    end;
    CharacterLayoutForm := TFormLyricsCharacterLayoutSettings.Create(nil);
    try
      if CharacterLayoutForm.Color <>
        SYNC_LYRICS_DARK_BACKGROUND_COLOR then
        raise Exception.Create(
          'The character placement editor did not use the dark background.');
      if (CharacterLayoutForm.CandidateCombo.Style <> csOwnerDrawFixed) or
        not Assigned(CharacterLayoutForm.CandidateCombo.OnDrawItem) then
        raise Exception.Create(
          'The character placement combo box was not owner-drawn.');
      if (CharacterLayoutForm.PlacementModeCombo.Style <>
        csOwnerDrawFixed) or
        not Assigned(CharacterLayoutForm.PlacementModeCombo.OnDrawItem) then
        raise Exception.Create(
          'The character placement mode combo box was not owner-drawn.');
      CharacterLayoutForm.ConfigurePlacementMode(0);
      if CharacterLayoutForm.SelectedPlacementMode <> 0 then
        raise Exception.Create(
          'The character placement mode selection was not retained.');
      if CharacterLayoutForm.ElementListView.Color <>
        SYNC_LYRICS_DARK_CONTROL_COLOR then
        raise Exception.Create(
          'The character placement list did not use the dark control color.');
      if CharacterLayoutForm.ButtonPanel.Color <>
        SYNC_LYRICS_DARK_PANEL_COLOR then
        raise Exception.Create(
          'The character placement button panel was not dark.');
      CharacterLayoutToolbar := FindOwnedComponentByClass(
        CharacterLayoutForm,
        TSyncLyricsToolbarButtons) as TSyncLyricsToolbarButtons;
      if (CharacterLayoutToolbar = nil) or
        (CharacterLayoutToolbar.FindByTag(0) = nil) or
        (CharacterLayoutToolbar.FindByTag(0).Glyph <> tbgOutline) or
        (CharacterLayoutToolbar.FindByTag(8) = nil) or
        (CharacterLayoutToolbar.FindByTag(9) = nil) or
        (CharacterLayoutToolbar.FindByTag(9).Glyph <> tbgLinePlacement) or
        CharacterLayoutForm.PlacementModeCombo.Visible then
        raise Exception.Create(
          'The character placement editor did not expose decoration settings.');
      if (CharacterLayoutForm.ColorPanel.Width < 180) or
        (CharacterLayoutForm.ColorPanel.Left +
          CharacterLayoutForm.ColorPanel.Width >
          CharacterLayoutForm.ClientWidth) or
        (CharacterLayoutForm.ElementPanel.Width >=
          CharacterLayoutForm.ColorPanel.Width) or
        (CharacterLayoutForm.ElementPanel.Left +
          CharacterLayoutForm.ElementPanel.Width >=
          CharacterLayoutForm.ColorPanel.Left) or
        (CharacterLayoutForm.BackgroundPaintBox.Left +
          CharacterLayoutForm.BackgroundPaintBox.Width >=
          CharacterLayoutForm.ElementPanel.Left) then
        raise Exception.Create(
          'The character list and fixed color picker layout was incorrect.');
      SetLength(PreviewPixels, 64 * 36 * 4);
      CharacterLayoutForm.SetBackgroundRgba(PreviewPixels, 64, 36);
      CharacterLayoutForm.Configure('[test](ruby)',
        DefaultDisplayCommonSettings, '');
      CharacterLayoutForm.HandleNeeded;
      CharacterLayoutForm.BackgroundPaintBoxPaint(
        CharacterLayoutForm.BackgroundPaintBox);
      CharacterLayoutToolbar.FindByTag(9).Execute;
      if (CharacterLayoutForm.ModalResult <>
        PLACEMENT_MODE_SWITCH_MODAL_RESULT) or
        (CharacterLayoutForm.SelectedPlacementMode <> 0) then
        raise Exception.Create(
          'The free editor did not request an immediate line-mode switch.');
    finally
      CharacterLayoutForm.Free;
    end;
    DisplaySettingsForm := TFormLyricsDisplaySettings.Create(nil);
    try
      DisplayLinePage := TFrameLyricsLineDisplaySettingsPage(
        DisplaySettingsForm.PageForMode(DISPLAY_SETTINGS_MODE_LINE));
      DisplayCharacterPage := TFrameLyricsCharacterDisplaySettingsPage(
        DisplaySettingsForm.PageForMode(DISPLAY_SETTINGS_MODE_FREE));
      SetLength(PreviewPixels, 64 * 36 * 4);
      FillChar(PreviewPixels[0], Length(PreviewPixels), $20);
      DisplayLinePage.SetBackgroundRgba(PreviewPixels, 64, 36);
      DisplayCharacterPage.SetBackgroundRgba(PreviewPixels, 64, 36);
      if not DisplayLinePage.HasBackgroundImage or
        not DisplayCharacterPage.HasBackgroundImage then
        raise Exception.Create(
          'The shared display previews did not load the Filter frame.');
      if DisplaySettingsForm.Font.Name <> LegacyDisplayFontName then
        raise Exception.Create(
          'The common display form did not use the legacy form font.');
      if DisplaySettingsForm.Font.Height <> LegacyDisplayFontHeight then
        raise Exception.Create(
          'The common display form did not match the legacy DPI font size.');
      if DisplaySettingsForm.ClientWidth <>
        MulDiv(990, DisplaySettingsForm.CurrentPPI, 96) then
        raise Exception.Create(
          'The common display form did not use the compact DPI width.');
      if (DisplaySettingsForm.ClientHeight <>
        MulDiv(548, DisplaySettingsForm.CurrentPPI, 96)) or
        (DisplaySettingsForm.Position <> poScreenCenter) then
        raise Exception.Create(
          'The common display form size or position was incorrect.');
      if (DisplaySettingsForm.Color <>
        SYNC_LYRICS_DARK_BACKGROUND_COLOR) or
        (DisplaySettingsForm.ModePageCount <> 2) or
        (DisplaySettingsForm.CurrentMode <> DISPLAY_SETTINGS_MODE_LINE) or
        not (DisplaySettingsForm.CurrentPage is
          TFrameLyricsLineDisplaySettingsPage) then
        raise Exception.Create(
          'The shared display settings host did not initialize line mode.');
      DisplaySettingsForm.ConfigureModeCandidates(
        DISPLAY_SETTINGS_MODE_LINE, ['lane 1', 'lane 2', 'lane 3'], 2);
       DisplaySettingsForm.ConfigureModeCandidates(
         DISPLAY_SETTINGS_MODE_FREE, ['line 1', 'line 2'], 1);
       SetLength(CandidateSettingsTexts, Length(CandidateLyrics));
       DisplayCharacterPage.ConfigureCandidates(CandidateLyrics,
         CandidateCommon, CandidateSettingsTexts, 1);
      if (DisplaySettingsForm.CandidateCombo.Items.Count <> 3) or
        (DisplaySettingsForm.SelectedCandidateIndex <> 2) then
        raise Exception.Create(
          'The shared host did not load line-mode candidates.');
      if (DisplaySettingsForm.ModeToolbar.FindByTag(
          DISPLAY_SETTINGS_MODE_LINE) = nil) or
        (DisplaySettingsForm.ModeToolbar.FindByTag(
          DISPLAY_SETTINGS_MODE_FREE) = nil) then
        raise Exception.Create(
          'The shared display settings host did not expose mode icons.');
      DisplaySettingsForm.SetMode(DISPLAY_SETTINGS_MODE_FREE);
      if (DisplaySettingsForm.CurrentMode <> DISPLAY_SETTINGS_MODE_FREE) or
        not (DisplaySettingsForm.CurrentPage is
          TFrameLyricsCharacterDisplaySettingsPage) or
        not DisplaySettingsForm.CurrentPage.Visible then
        raise Exception.Create(
          'The shared display settings host did not switch to free mode.');
      if (DisplaySettingsForm.CandidateCombo.Items.Count <> 2) or
        (DisplaySettingsForm.SelectedCandidateIndex <> 1) then
        raise Exception.Create(
          'The shared host did not switch candidate sets with the mode.');
      DisplaySettingsForm.CaptureInitialState;
      if (DisplaySettingsForm.ModeToolbar.ItemCount <> 5) or
        (DisplaySettingsForm.ModeToolbar.Items[0].Glyph <> tbgClose) or
        (DisplaySettingsForm.ModeToolbar.Items[1].Glyph <> tbgRestore) then
        raise Exception.Create(
          'The shared host did not expose close and restore icons.');
      with TFrameLyricsCharacterDisplaySettingsPage(
        DisplaySettingsForm.CurrentPage) do
        if (ColorPanel.Width < 180) or
          (Preview.Left + Preview.Width >= ColorPanel.Left) or
          (Preview.Width <= ColorPanel.Width * 3) or
          (ElementCombo.Top >= Preview.Top) or
          (ElementCombo.Items.Count = 0) or
          (ElementCombo.Style <> csOwnerDrawFixed) or
          not Assigned(ElementCombo.OnDrawItem) then
          raise Exception.Create(
            'The new free-mode page layout was not constructed.');
      DisplaySettingsForm.SetMode(DISPLAY_SETTINGS_MODE_LINE);
      if not (DisplaySettingsForm.CurrentPage is
        TFrameLyricsLineDisplaySettingsPage) then
        raise Exception.Create(
          'The shared display settings host did not return to line mode.');
    finally
      DisplaySettingsForm.Free;
    end;
    EditorForm := TFormLyricsSyncEditor.Create(nil);
    try
      if EditorForm.Color <> SYNC_LYRICS_DARK_BACKGROUND_COLOR then
        raise Exception.Create('The song sync editor was not dark.');
      EditorForm.SetAnchor(100, 30, 1);
      EditorForm.SetCurrentObjectFrame(45);
      EditorForm.HandleNeeded;
      EditorForm.Show;
      if (EditorForm.LineListBox = nil) or
        (EditorForm.LineListBox.Parent <> EditorForm.LineListHostPanel) then
        raise Exception.Create(
          'The runtime lyric list was not created in its designer-safe host.');
      InputFrame := EditorForm.FindComponent(
        'FrameLyricsInitialInput') as TFrameLyricsInitialInput;
      if InputFrame = nil then
        InputFrame := FindOwnedComponentByClass(EditorForm,
          TFrameLyricsInitialInput) as TFrameLyricsInitialInput;
      if InputFrame = nil then
        InputFrame := FindChildControlByClass(EditorForm,
          TFrameLyricsInitialInput) as TFrameLyricsInitialInput;
      if InputFrame = nil then
        raise Exception.Create('The initial lyrics frame was not created.');
      if (InputFrame.Color <> SYNC_LYRICS_DARK_BACKGROUND_COLOR) or
        (InputFrame.LyricsMemo.Color <>
          SYNC_LYRICS_DARK_CONTROL_COLOR) then
        raise Exception.Create('The initial lyrics input was not dark.');
      TopToolbar := FindChildControlByClass(EditorForm.BottomPanel,
        TSyncLyricsToolbarButtons) as TSyncLyricsToolbarButtons;
      if (TopToolbar = nil) or (TopToolbar.ItemCount <> 6) or
        (TopToolbar.Items[0].Glyph <> tbgClose) or
        (TopToolbar.Items[1].Glyph <> tbgRestore) or
        (TopToolbar.Items[2].Glyph <> tbgNext) or
        (TopToolbar.Items[3].Glyph <> tbgConfirm) or
        (TopToolbar.Items[4].Glyph <> tbgResetAll) or
        (TopToolbar.Items[5].Glyph <> tbgLyrics) then
        raise Exception.Create(
          'The top actions did not use the common icon toolbar.');
      ToolbarExtent := MulDiv(28, EditorForm.CurrentPPI, 96);
      if (TopToolbar.ButtonExtent <> ToolbarExtent) or
        (TopToolbar.Left <> MulDiv(12, EditorForm.CurrentPPI, 96)) or
        (TopToolbar.Top <> MulDiv(12, EditorForm.CurrentPPI, 96)) or
        (TopToolbar.Width <> ToolbarExtent * 6) or
        (TopToolbar.Height <> ToolbarExtent) or
        (TopToolbar.Items[0].Width <> ToolbarExtent) or
        (TopToolbar.Items[0].Height <> ToolbarExtent) then
        raise Exception.Create(
          'The top icon toolbar did not scale for the current DPI.');
      if (EditorForm.SyncStateLabel.Top <> TopToolbar.Top) or
        (EditorForm.SyncStateLabel.Height <> TopToolbar.Height) then
        raise Exception.Create(
          'The synchronization state was not vertically aligned with the icons.');
      if not TopToolbar.Items[0].Enabled then
        raise Exception.Create(
          'The initial lyrics page did not provide the common close action.');
      if not TopToolbar.Items[2].Visible then
        raise Exception.Create(
          'The initial lyrics page did not provide the next action.');
      TopToolbar.Items[2].Execute;
      if EditorForm.LineListBox.Items.Count <> 5 then
        raise Exception.Create('The confirmed lyrics did not create five lines.');
      if (EditorForm.FindComponent('LineListHeaderLabel') <> nil) or
        (EditorForm.FindComponent('LineHintLabel') <> nil) or
        (EditorForm.FindComponent('SummaryLabel') <> nil) or
        (EditorForm.LineListBox.Height <= 0) or
        (EditorForm.LineListBox.Height <>
          EditorForm.LineListHostPanel.ClientHeight) then
        raise Exception.Create(
          'Removing the lyric labels did not expand the line list vertically.');
      if EditorForm.LineListBox.ItemIndex <> 0 then
        raise Exception.Create('The first lyric line was not selected.');
      if not TopToolbar.Items[1].Enabled then
        raise Exception.Create('The restore action was not available.');
      if TopToolbar.Items[2].Visible then
        raise Exception.Create(
          'The next action remained visible in the synchronization editor.');
      LyricsToolbar := FindChildControlByClass(EditorForm.LineListPanel,
        TSyncLyricsToolbarButtons) as TSyncLyricsToolbarButtons;
      if (LyricsToolbar = nil) or (LyricsToolbar.ItemCount <> 3) then
        raise Exception.Create(
          'The lyric-line toolbar was not created above the line list.');
      if (LyricsToolbar.ButtonExtent <> ToolbarExtent) or
        (LyricsToolbar.Width <> ToolbarExtent * 3) or
        (LyricsToolbar.Items[0].Width <> ToolbarExtent) or
        (LyricsToolbar.Items[0].Height <> ToolbarExtent) then
        raise Exception.Create(
          'The lyric-line icon toolbar did not scale for the current DPI.');
      if (LyricsToolbar.Items[0].Glyph <> tbgAdd) or
        (LyricsToolbar.Items[1].Glyph <> tbgDelete) or
        (LyricsToolbar.Items[2].Glyph <> tbgEdit) then
        raise Exception.Create(
          'The lyric-line toolbar did not use add, delete, and edit glyphs.');
      if LyricsToolbar.ClientToScreen(Point(0, 0)).Y >=
        EditorForm.LineListBox.ClientToScreen(Point(0, 0)).Y then
        raise Exception.Create(
          'The lyric-line toolbar was not placed above the line list.');
      if not LyricsToolbar.Items[0].Enabled or
        not LyricsToolbar.Items[1].Enabled or
        not LyricsToolbar.Items[2].Enabled then
        raise Exception.Create(
          'The lyric-line toolbar actions were not enabled.');
      LyricsToolbar.Items[0].Execute;
      if (EditorForm.LineListBox.Items.Count <> 6) or
        not EditorForm.LineListBox.IsEditing or
        (EditorForm.LineListBox.EditControl.Text <> '') then
        raise Exception.Create(
          'Adding a lyric line did not begin an empty inline edit.');
      if EditorForm.LineListBox.EditControl.Height <>
        EditorForm.LineListBox.ItemHeight then
        raise Exception.Create(
          'The inline lyric editor height did not match its list row.');
      EditorForm.LineListBox.EndEdit(True);
      if not EditorForm.LineListBox.IsEditing then
        raise Exception.Create(
          'An empty new lyric line was accepted unexpectedly.');
      EditorForm.LineListBox.EndEdit(False);
      if (EditorForm.LineListBox.Items.Count <> 5) or
        EditorForm.LineListBox.IsEditing then
        raise Exception.Create(
          'Canceling a new inline lyric did not remove the pending line.');
      EditorForm.LineListBox.ItemIndex := 0;
      EditorForm.LineListBoxClick(EditorForm.LineListBox);
      LyricsToolbar.Items[2].Execute;
      if not EditorForm.LineListBox.IsEditing or
        (EditorForm.LineListBox.EditControl.Text <>
          '['#26143#31354']('#12411#12375#12382#12425')'#12434#35211#19978#12370#12390) then
        raise Exception.Create(
          'The edit glyph did not begin editing the selected lyric syntax.');
      EditorForm.LineListBox.EndEdit(False);
      MusicSyncFrame := EditorForm.FindComponent(
        'FrameLyricsMusicSyncEditor') as TFrameLyricsMusicSyncEditor;
      if MusicSyncFrame = nil then
        raise Exception.Create('The music synchronization frame was not created.');
      MusicSyncFrame.LoadLine(ExpandFileName(
        'Tests\Fixtures\sync_test_120bpm_30s.wav'), -1,
        0.5, 'test', SerializeManualSyncText([0.0, 1.0,
        2.0, 3.0, 4.0]));
      ManualSyncForm := FindOwnedComponentByClass(MusicSyncFrame,
        TFormLyricsManualSyncSettings) as TFormLyricsManualSyncSettings;
      if (ManualSyncForm = nil) or not ManualSyncForm.Visible or
        (ManualSyncForm.WaveformPaintBox.Width >= 852) or
        (ManualSyncForm.WaveformPaintBox.Width <= 0) then
        raise Exception.Create(
          'The WAV source did not switch to the embedded waveform editor.');
      MusicSyncFrame.LoadLine(ExpandFileName(
        'Tests\Fixtures\sync_test_120bpm_30s.mid'), -1,
        0.5,
        '['#26143#31354']('#12411#12375#12382#12425')'#12434#35211#19978#12370#12390,
        DEFAULT_MUSIC_SYNC_TEXT);
      MusicSyncForm := MusicSyncFrame.FindComponent(
        'FormLyricsMusicSyncSettings') as TFormLyricsMusicSyncSettings;
      if MusicSyncForm = nil then
        MusicSyncForm := FindOwnedComponentByClass(MusicSyncFrame,
          TFormLyricsMusicSyncSettings) as TFormLyricsMusicSyncSettings;
      if MusicSyncForm = nil then
        MusicSyncForm := FindChildControlByClass(MusicSyncFrame,
          TFormLyricsMusicSyncSettings) as TFormLyricsMusicSyncSettings;
      if (MusicSyncForm = nil) or
        (MusicSyncForm.Color <> SYNC_LYRICS_DARK_BACKGROUND_COLOR) or
        (MusicSyncForm.LyricsEdit.Color <>
          SYNC_LYRICS_DARK_CONTROL_COLOR) then
        raise Exception.Create('The music synchronization editor was not dark.');
      if MusicSyncForm.ResetSyncButton.ClassType <> TButton then
        raise Exception.Create(
          'The reset synchronization button did not use the standard UI.');
      if MusicSyncForm.BottomPanel.Visible or
        not TopToolbar.Items[4].Visible then
        raise Exception.Create(
          'The embedded synchronization controls were not moved to the top bar.');
      if MusicSyncForm.PianoRollPaintBox.Height <>
        MusicSyncForm.ClientHeight then
        raise Exception.Create(
          'Removing the embedded lyrics row did not expand the editor.');
      MusicSyncForm.PianoRollPaintBoxMouseMove(
        MusicSyncForm.PianoRollPaintBox, [], 4, 4);
      if MusicSyncForm.PianoRollPaintBox.Cursor <> crDefault then
        raise Exception.Create(
          'The empty piano-roll area did not use the default cursor.');
      MusicSyncForm.PianoRollPaintBoxMouseDown(
        MusicSyncForm.PianoRollPaintBox, mbLeft, [], 4, 4);
      if MusicSyncForm.PianoRollPaintBox.Cursor <> crDefault then
        raise Exception.Create(
          'Panning the piano roll did not use the default cursor.');
      MusicSyncForm.PianoRollPaintBoxMouseUp(
        MusicSyncForm.PianoRollPaintBox, mbLeft, [], 4, 4);
      if EditorForm.LineListBox.Color <>
        SYNC_LYRICS_DARK_CONTROL_COLOR then
        raise Exception.Create('The song line list was not dark.');
      if MusicSyncFrame.LyricsText <>
        '['#26143#31354']('#12411#12375#12382#12425')'#12434#35211#19978#12370#12390 then
        raise Exception.Create('The first lyric line was not loaded into the editor.');
      TopToolbar.Items[3].Execute;
      if TopToolbar.Items[3].CheckState <> tbcsChecked then
        raise Exception.Create('The selected lyric line was not confirmed.');
      TopToolbar.Items[5].Execute;
      if not InputFrame.Visible or TopToolbar.Items[5].Visible or
        not InputFrame.LyricsMemo.Visible or
        (InputFrame.LyricsMemo.Height <= InputFrame.ClientHeight div 3) or
        (InputFrame.LyricsMemo.Width <= InputFrame.ClientWidth div 2) or
        (InputFrame.LyricsMemo.Text <> EditorForm.ConfirmedLyrics) then
        raise Exception.Create(
          'The whole-lyrics icon did not return to the lyrics input page.');
      TopToolbar.Items[2].Execute;
      if InputFrame.Visible or not TopToolbar.Items[5].Visible or
        (TopToolbar.Items[3].CheckState <> tbcsChecked) then
        raise Exception.Create(
          'Returning from unchanged whole lyrics did not preserve synchronization.');
      Key := Ord('2');
      EditorForm.LineListBoxKeyDown(EditorForm.LineListBox, Key, []);
      if EditorForm.LineListBox.ItemIndex <> 1 then
        raise Exception.Create('The display lane shortcut did not advance.');
      if MusicSyncFrame.LyricsText <>
        '['#21531']('#12365#12415')'#12398#22768#12434#25506#12375#12390#12427 then
        raise Exception.Create('Advancing did not load the next lyric line.');
      EditorForm.LineListBox.ItemIndex := 0;
      EditorForm.LineListBoxClick(EditorForm.LineListBox);
      if TopToolbar.Items[3].CheckState <> tbcsChecked then
        raise Exception.Create('The confirmed state was not retained after switching.');
      TopToolbar.Items[3].Execute;
      if TopToolbar.Items[3].CheckState <> tbcsUnchecked then
        raise Exception.Create('The confirmed state was not released.');
      EditorForm.Hide;
    finally
      EditorForm.Free;
    end;

    StoredModel := TLyricsSongModel.Create;
    ReloadedModel := TLyricsSongModel.Create;
    try
      StoredModel.SetLyricsText('first' + sLineBreak + 'second');
      if not TryEncodeSongLyrics(StoredModel, SongDataText, ErrorText) then
        raise Exception.Create('Could not prepare stored text: ' + ErrorText);
      EditorForm := TFormLyricsSyncEditor.Create(nil);
      try
      if not EditorForm.TryLoadSongData(SongDataText, ErrorText) then
        raise Exception.Create('The editor did not load Filter text: ' + ErrorText);
        if EditorForm.LineListBox.Items.Count <> 2 then
          raise Exception.Create('The loaded song did not create two rows.');
        Key := Ord('3');
        EditorForm.LineListBoxKeyDown(EditorForm.LineListBox, Key, []);
        CanClose := True;
        EditorForm.FormCloseQuery(EditorForm, CanClose);
        if not CanClose or (EditorForm.ModalResult <> mrOk) then
          raise Exception.Create(
            'Closing the window did not save and complete the editor.');
        SongDataText := EditorForm.SongDataText;
        if not SongDataText.StartsWith('SLD1,') then
          raise Exception.Create('The editor did not save an SLD1 document.');
      finally
        EditorForm.Free;
      end;
      if not TryDecodeSongLyrics(SongDataText, ReloadedModel,
        ErrorText) then
        raise Exception.Create('The editor output could not be decoded: ' + ErrorText);
      if ReloadedModel[0].DisplayLane <> 3 then
        raise Exception.Create('Saving did not persist the edited display lane.');
      if (ReloadedModel[0].SyncText <> DEFAULT_MUSIC_SYNC_TEXT) or
        (ReloadedModel[1].SyncText <> DEFAULT_MUSIC_SYNC_TEXT) then
        raise Exception.Create(
          'Saving did not persist default synchronization for every lyric line.');
      EditorForm := TFormLyricsSyncEditor.Create(nil);
      try
        if not EditorForm.TryLoadSongData(SongDataText, ErrorText) then
          raise Exception.Create(
            'The restore test could not load Filter text: ' + ErrorText);
        TopToolbar := FindChildControlByClass(EditorForm.BottomPanel,
          TSyncLyricsToolbarButtons) as TSyncLyricsToolbarButtons;
        if TopToolbar = nil then
          raise Exception.Create('The restore test could not find the top toolbar.');
        Key := Ord('1');
        EditorForm.LineListBoxKeyDown(EditorForm.LineListBox, Key, []);
        TopToolbar.Items[1].Execute;
        CanClose := True;
        EditorForm.FormCloseQuery(EditorForm, CanClose);
        if not CanClose then
          raise Exception.Create('The restored editor could not close.');
        SongDataText := EditorForm.SongDataText;
      finally
        EditorForm.Free;
      end;
      if not TryDecodeSongLyrics(SongDataText, ReloadedModel,
        ErrorText) or (ReloadedModel[0].DisplayLane <> 3) then
        raise Exception.Create(
          'Restoring did not recover the state from before editing.');
    finally
      ReloadedModel.Free;
      StoredModel.Free;
    end;
    Writeln('FORM_OK');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      Halt(1);
    end;
  end;
end.
