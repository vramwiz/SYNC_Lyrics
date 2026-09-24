library SYNC_Lyrics_Filter;

// 歌詞テロップフィルターのAviUtl2 DLL境界。

{$ALIGN 8}

uses
  System.Skia in 'Win64\SkiaOverride\System.Skia.pas',
  TextRendererSkiaBootstrap in 'Source\Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererTypes in 'Source\Lib\TextRenderer\TextRendererTypes.pas',
  TextRenderer in 'Source\Lib\TextRenderer\TextRenderer.pas',
  TextRendererSkiaRuntime in 'Source\Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  TextRendererSkia in 'Source\Lib\TextRenderer\TextRendererSkia.pas',
  PluginFilterSerifDrawSyncHighlight in 'Source\Lib\SerifSyncAnimation\PluginFilterSerifDrawSyncHighlight.pas',
  PluginFilterTable in 'Source\Lib\FilterTable\PluginFilterTable.pas',
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SYNC_Lyrics_ListBoxEdit in 'Source\Lib\SYNC_Lyrics_ListBoxEdit.pas',
  SYNC_Lyrics_ToolbarButtons in 'Source\Lib\SYNC_Lyrics_ToolbarButtons.pas',
  SYNC_Lyrics_DarkTheme in 'Source\Lib\SYNC_Lyrics_DarkTheme.pas',
  SYNC_Lyrics_FontHistoryComboBox in 'Source\Lib\SYNC_Lyrics_FontHistoryComboBox.pas',
  ColorPickerColorMath in 'Source\Lib\ColorPicker\ColorPickerColorMath.pas',
  ColorPickerRGBEditFrame in 'Source\Lib\ColorPicker\ColorPickerRGBEditFrame.pas' {FrameColorPickerRGBEdit: TFrame},
  ColorPickerHueBar in 'Source\Lib\ColorPicker\ColorPickerHueBar.pas',
  ColorPickerSVArea in 'Source\Lib\ColorPicker\ColorPickerSVArea.pas',
  ColorPickerPick in 'Source\Lib\ColorPicker\ColorPickerPick.pas',
  ColorPickerDialogFrame in 'Source\Lib\ColorPicker\ColorPickerDialogFrame.pas' {FrameColorPickerDialog: TFrame},
  ColorPickerDialog in 'Source\Lib\ColorPicker\ColorPickerDialog.pas' {FormColorPickerDialog},
  SYNC_Lyrics_Time in 'Source\Common\Timeline\SYNC_Lyrics_Time.pas',
  SYNC_Lyrics_LyricParser in 'Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_SongLyricsModel in 'Source\Common\Lyrics\SYNC_Lyrics_SongLyricsModel.pas',
  SYNC_Lyrics_SongLyricsData in 'Source\Common\Lyrics\SYNC_Lyrics_SongLyricsData.pas',
  SYNC_Lyrics_SongLyricsRuntime in 'Source\Common\Lyrics\SYNC_Lyrics_SongLyricsRuntime.pas',
  RTTIPersistent in 'Source\Lib\SongReader\Persistence\RTTIPersistent.pas',
  RTTIPersistentIni in 'Source\Lib\SongReader\Persistence\RTTIPersistentIni.pas',
  SectionFileManager in 'Source\Lib\SongReader\Persistence\SectionFileManager.pas',
  TextEncodingUtils in 'Source\Lib\SongReader\Persistence\TextEncodingUtils.pas',
  SongAIUEO in 'Source\Lib\SongReader\Core\SongAIUEO.pas',
  SongDataInfo in 'Source\Lib\SongReader\Core\SongDataInfo.pas',
  SongDataNote in 'Source\Lib\SongReader\Core\SongDataNote.pas',
  SongDataTempo in 'Source\Lib\SongReader\Core\SongDataTempo.pas',
  SongDataTrack in 'Source\Lib\SongReader\Core\SongDataTrack.pas',
  SongData in 'Source\Lib\SongReader\Core\SongData.pas',
  SongReader in 'Source\Lib\SongReader\Core\SongReader.pas',
  SongReaderSMF in 'Source\Lib\SongReader\Formats\SongReaderSMF.pas',
  SongReaderUST in 'Source\Lib\SongReader\Formats\SongReaderUST.pas',
  SongReaderVSQX in 'Source\Lib\SongReader\Formats\SongReaderVSQX.pas',
  SongReaderMusicXML in 'Source\Lib\SongReader\Formats\SongReaderMusicXML.pas',
  SongReaderMusicMSC in 'Source\Lib\SongReader\Formats\SongReaderMusicMSC.pas',
  SongReaderMusicMSCZ in 'Source\Lib\SongReader\Formats\SongReaderMusicMSCZ.pas',
  SongReaderManager in 'Source\Lib\SongReader\Core\SongReaderManager.pas',
  SYNC_Lyrics_SyncFormat in 'Source\Common\Sync\SYNC_Lyrics_SyncFormat.pas',
  FFmpegApi in 'Source\Lib\FFmpeg\FFmpegApi.pas',
  FFmpegAudioTempo in 'Source\Lib\FFmpeg\FFmpegAudioTempo.pas',
  SYNC_Lyrics_SyncSourceKind in 'Source\Common\Sync\SYNC_Lyrics_SyncSourceKind.pas',
  SYNC_Lyrics_AudioProbe in 'Source\Common\Sync\SYNC_Lyrics_AudioProbe.pas',
  SYNC_Lyrics_AudioWaveform in 'Source\Common\Sync\SYNC_Lyrics_AudioWaveform.pas',
  SYNC_Lyrics_AudioPcm in 'Source\Common\Sync\SYNC_Lyrics_AudioPcm.pas',
  SYNC_Lyrics_AudioPlayer in 'Source\Common\Sync\SYNC_Lyrics_AudioPlayer.pas',
  SYNC_Lyrics_ManualSyncEditModel in 'Source\Common\Sync\SYNC_Lyrics_ManualSyncEditModel.pas',
  SYNC_Lyrics_ManualSync in 'Source\Common\Sync\SYNC_Lyrics_ManualSync.pas',
  SYNC_Lyrics_MusicSyncAnchor in 'Source\Common\Sync\SYNC_Lyrics_MusicSyncAnchor.pas',
  SYNC_Lyrics_MusicSync in 'Source\Common\Sync\SYNC_Lyrics_MusicSync.pas',
  SYNC_Lyrics_DisplaySettingsData in 'Source\Common\Render\SYNC_Lyrics_DisplaySettingsData.pas',
  SYNC_Lyrics_ResolvedDisplayUnits in 'Source\Common\Render\SYNC_Lyrics_ResolvedDisplayUnits.pas',
  SYNC_Lyrics_LastFrameCapture in 'Source\Common\Render\SYNC_Lyrics_LastFrameCapture.pas',
  MVAnimationTypes in 'Source\Lib\EdgeAnimation\Core\MVAnimationTypes.pas',
  MVTransitionTiming in 'Source\Lib\EdgeAnimation\Core\MVTransitionTiming.pas',
  MVAnimationCatalog in 'Source\Lib\EdgeAnimation\Core\MVAnimationCatalog.pas',
  MVTransitionParts in 'Source\Lib\EdgeAnimation\Core\MVTransitionParts.pas',
  MVTransitionComposition in 'Source\Lib\EdgeAnimation\Core\MVTransitionComposition.pas',
  MVTransitionBasic in 'Source\Lib\EdgeAnimation\Transition\MVTransitionBasic.pas',
  MVTransitionExtended in 'Source\Lib\EdgeAnimation\Transition\MVTransitionExtended.pas',
  MVTransitionMovement in 'Source\Lib\EdgeAnimation\Transition\MVTransitionMovement.pas',
  MVTransitionScale in 'Source\Lib\EdgeAnimation\Transition\MVTransitionScale.pas',
  MVTransitionMasks in 'Source\Lib\EdgeAnimation\Transition\MVTransitionMasks.pas',
  MVTransitionScatter in 'Source\Lib\EdgeAnimation\Transition\MVTransitionScatter.pas',
  MVTransitionKinetic in 'Source\Lib\EdgeAnimation\Transition\MVTransitionKinetic.pas',
  MVTransitionPattern in 'Source\Lib\EdgeAnimation\Transition\MVTransitionPattern.pas',
  MVTransitionPath in 'Source\Lib\EdgeAnimation\Transition\MVTransitionPath.pas',
  MVHoldBasic in 'Source\Lib\EdgeAnimation\Hold\MVHoldBasic.pas',
  MVHoldExtended in 'Source\Lib\EdgeAnimation\Hold\MVHoldExtended.pas',
  MVHoldKinetic in 'Source\Lib\EdgeAnimation\Hold\MVHoldKinetic.pas',
  MVHoldAccent in 'Source\Lib\EdgeAnimation\Hold\MVHoldAccent.pas',
  SYNC_Lyrics_Animation in 'Source\Common\Render\SYNC_Lyrics_Animation.pas',
  SYNC_Lyrics_Renderer in 'Source\Common\Render\SYNC_Lyrics_Renderer.pas',
  SYNC_Lyrics_CharacterLayoutInteraction in 'Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterLayoutInteraction.pas',
  SYNC_Lyrics_CharacterLayoutDrawing in 'Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterLayoutDrawing.pas',
  SYNC_Lyrics_DisplaySettingsModePage in 'Source\Plugin\Filter\Display\SYNC_Lyrics_DisplaySettingsModePage.pas',
  SYNC_Lyrics_DisplaySettingsColorPanel in 'Source\Plugin\Filter\Display\SYNC_Lyrics_DisplaySettingsColorPanel.pas',
  SYNC_Lyrics_DisplayPreviewBackground in 'Source\Plugin\Filter\Display\SYNC_Lyrics_DisplayPreviewBackground.pas',
  SYNC_Lyrics_DisplayDecorationControls in 'Source\Plugin\Filter\Display\SYNC_Lyrics_DisplayDecorationControls.pas',
  SYNC_Lyrics_DisplayPreviewText in 'Source\Plugin\Filter\Display\SYNC_Lyrics_DisplayPreviewText.pas',
  SYNC_Lyrics_LineDisplayPreviewText in 'Source\Plugin\Filter\Display\Line\SYNC_Lyrics_LineDisplayPreviewText.pas',
  SYNC_Lyrics_CharacterDecorationOverlay in 'Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterDecorationOverlay.pas',
  SYNC_Lyrics_CharacterPreviewGeometry in 'Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterPreviewGeometry.pas',
  SYNC_Lyrics_ContrastGuides in 'Source\Lib\SYNC_Lyrics_ContrastGuides.pas',
  SYNC_Lyrics_LineDisplaySettingsPage in 'Source\Plugin\Filter\Display\Line\SYNC_Lyrics_LineDisplaySettingsPage.pas',
  SYNC_Lyrics_CharacterDisplaySettingsPage in 'Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterDisplaySettingsPage.pas',
  SYNC_Lyrics_DisplaySettingsForm in 'Source\Plugin\Filter\Display\SYNC_Lyrics_DisplaySettingsForm.pas',
  SYNC_Lyrics_CharacterLayoutSettingsForm in 'Source\Plugin\Filter\Display\Character\SYNC_Lyrics_CharacterLayoutSettingsForm.pas' {FormLyricsCharacterLayoutSettings},
  SYNC_Lyrics_LineDisplaySettingsForm in 'Source\Plugin\Filter\Display\Line\SYNC_Lyrics_LineDisplaySettingsForm.pas' {FormLyricsLineDisplaySettings},
  SYNC_Lyrics_MusicSyncEditModel in 'Source\Plugin\Filter\Sync\Midi\SYNC_Lyrics_MusicSyncEditModel.pas',
  SYNC_Lyrics_MidiLyricMatcher in 'Source\Plugin\Filter\Sync\Midi\SYNC_Lyrics_MidiLyricMatcher.pas',
  SYNC_Lyrics_MidiLyricAutoAssign in 'Source\Plugin\Filter\Sync\Midi\SYNC_Lyrics_MidiLyricAutoAssign.pas',
  SYNC_Lyrics_MusicSyncPianoRoll in 'Source\Plugin\Filter\Sync\Midi\SYNC_Lyrics_MusicSyncPianoRoll.pas',
  SYNC_Lyrics_MusicSyncNoteLyrics in 'Source\Plugin\Filter\Sync\Midi\SYNC_Lyrics_MusicSyncNoteLyrics.pas',
  SYNC_Lyrics_MusicSyncFixedLyrics in 'Source\Plugin\Filter\Sync\Midi\SYNC_Lyrics_MusicSyncFixedLyrics.pas',
  SYNC_Lyrics_MusicSyncSettingsForm in 'Source\Plugin\Filter\Sync\Midi\SYNC_Lyrics_MusicSyncSettingsForm.pas' {FormLyricsMusicSyncSettings},
  SYNC_Lyrics_MusicSyncEditorFrame in 'Source\Plugin\Filter\Sync\SYNC_Lyrics_MusicSyncEditorFrame.pas',
  SYNC_Lyrics_TimeRuler in 'Source\Plugin\Filter\Sync\SYNC_Lyrics_TimeRuler.pas',
  SYNC_Lyrics_ManualSyncWaveform in 'Source\Plugin\Filter\Sync\Manual\SYNC_Lyrics_ManualSyncWaveform.pas',
  SYNC_Lyrics_ManualSyncSettingsForm in 'Source\Plugin\Filter\Sync\Manual\SYNC_Lyrics_ManualSyncSettingsForm.pas' {FormLyricsManualSyncSettings},
  SYNC_Lyrics_InitialLyricsFrame in 'Source\Plugin\Filter\Sync\SYNC_Lyrics_InitialLyricsFrame.pas' {FrameLyricsInitialInput: TFrame},
  SYNC_Lyrics_SyncEditorForm in 'Source\Plugin\Filter\Sync\SYNC_Lyrics_SyncEditorForm.pas' {FormLyricsSyncEditor},
  SYNC_Lyrics_SerifAnimationItems in 'Source\Plugin\Filter\Animation\SYNC_Lyrics_SerifAnimationItems.pas',
  SYNC_Lyrics_FilterPlugin in 'Source\Plugin\Filter\SYNC_Lyrics_FilterPlugin.pas';

function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  Result := 0;
  try
    InitializeLyricsFilter;
    Result := 1;
  except
    // Exceptions must not cross AviUtl2's C callback boundary.
  end;
end;

procedure UninitializePlugin; cdecl;
begin
  try
    FinalizeLyricsFilter;
  except
    // DLL unload must continue even if Skia cleanup fails.
  end;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := nil;
  try
    Result := GetLyricsFilterTable;
  except
    // The host treats a missing table as plugin initialization failure.
  end;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
