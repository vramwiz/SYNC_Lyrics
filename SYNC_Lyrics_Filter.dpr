library SYNC_Lyrics_Filter;

// 歌詞テロップフィルターのAviUtl2 DLL境界。

{$ALIGN 8}

uses
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
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
