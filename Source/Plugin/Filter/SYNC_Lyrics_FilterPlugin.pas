unit SYNC_Lyrics_FilterPlugin;

// 歌詞テロップFilterの最小登録とパススルー処理を担当する。

interface

uses
  AviUtl2FilterTypes;

function GetLyricsFilterTable: PFILTER_PLUGIN_TABLE;
procedure InitializeLyricsFilter;
procedure FinalizeLyricsFilter;

implementation

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
begin
  // 最小プロジェクトでは入力画像を変更しない。
  Result := 1;
end;

var
  PluginItems: array[0..0] of Pointer;
  Plugin: TFILTER_PLUGIN_TABLE = (
    Flag: FILTER_FLAG_VIDEO;
    Name: 'SYNC_歌詞テロップ_Filter';
    Label_: 'SYNC';
    Information: '音楽データに同期する歌詞テロップフィルター';
    Items: nil;
    Func_Proc_Video: LyricsProcVideo;
    Func_Proc_Audio: nil
  );

function GetLyricsFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if Plugin.Items = nil then
  begin
    // AviUtl2はnil終端された項目ポインター配列を参照する。
    PluginItems[0] := nil;
    Plugin.Items := @PluginItems[0];
  end;
  Result := @Plugin;
end;

procedure InitializeLyricsFilter;
begin
end;

procedure FinalizeLyricsFilter;
begin
end;

end.
