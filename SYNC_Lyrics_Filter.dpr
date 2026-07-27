library SYNC_Lyrics_Filter;

// 歌詞テロップフィルターのAviUtl2 DLL境界。

{$ALIGN 8}

uses
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemoryBase.pas',
  SYNC_Lyrics_FrameShared in 'Source\Common\Timeline\SYNC_Lyrics_FrameShared.pas',
  SYNC_Lyrics_ContextManager in 'Source\Common\Timeline\SYNC_Lyrics_ContextManager.pas',
  SYNC_Lyrics_Time in 'Source\Common\Timeline\SYNC_Lyrics_Time.pas',
  SYNC_Lyrics_LyricParser in 'Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  RTTIPersistent in 'Source\Lib\SongReader\RTTIPersistent.pas',
  RTTIPersistentIni in 'Source\Lib\SongReader\RTTIPersistentIni.pas',
  SectionFileManager in 'Source\Lib\SongReader\SectionFileManager.pas',
  TextEncodingUtils in 'Source\Lib\SongReader\TextEncodingUtils.pas',
  SongAIUEO in 'Source\Lib\SongReader\SongAIUEO.pas',
  SongDataInfo in 'Source\Lib\SongReader\SongDataInfo.pas',
  SongDataNote in 'Source\Lib\SongReader\SongDataNote.pas',
  SongDataTempo in 'Source\Lib\SongReader\SongDataTempo.pas',
  SongDataTrack in 'Source\Lib\SongReader\SongDataTrack.pas',
  SongData in 'Source\Lib\SongReader\SongData.pas',
  SongReader in 'Source\Lib\SongReader\SongReader.pas',
  SongReaderSMF in 'Source\Lib\SongReader\SongReaderSMF.pas',
  SongReaderUST in 'Source\Lib\SongReader\SongReaderUST.pas',
  SongReaderVSQX in 'Source\Lib\SongReader\SongReaderVSQX.pas',
  SongReaderMusicXML in 'Source\Lib\SongReader\SongReaderMusicXML.pas',
  SongReaderMusicMSC in 'Source\Lib\SongReader\SongReaderMusicMSC.pas',
  SongReaderMusicMSCZ in 'Source\Lib\SongReader\SongReaderMusicMSCZ.pas',
  SongReaderManager in 'Source\Lib\SongReader\SongReaderManager.pas',
  SYNC_Lyrics_MusicSync in 'Source\Common\Sync\SYNC_Lyrics_MusicSync.pas',
  SYNC_Lyrics_Renderer in 'Source\Common\Render\SYNC_Lyrics_Renderer.pas',
  SYNC_Lyrics_FontSettingsForm in 'Source\Plugin\Filter\SYNC_Lyrics_FontSettingsForm.pas' {FormLyricsFontSettings},
  SYNC_Lyrics_FilterPlugin in 'Source\Plugin\Filter\SYNC_Lyrics_FilterPlugin.pas';

function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  InitializeLyricsFilter;
  Result := 1;
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizeLyricsFilter;
end;

function GetFilterPluginTable: PFILTER_PLUGIN_TABLE; cdecl;
begin
  Result := GetLyricsFilterTable;
end;

exports
  InitializePlugin name 'InitializePlugin',
  UninitializePlugin name 'UninitializePlugin',
  GetFilterPluginTable name 'GetFilterPluginTable';

begin
end.
