unit SYNC_Lyrics_FilterPlugin;

// 歌詞テロップFilterの最小登録とパススルー処理を担当する。

interface

uses
  AviUtl2FilterTypes;

// AviUtl2へ登録するFilterテーブルを返し、設定項目配列を初回取得時に確定する。
function GetLyricsFilterTable: PFILTER_PLUGIN_TABLE;

// 共有フレーム、補間コンテキスト、描画資源をFilter読込時に初期化する。
procedure InitializeLyricsFilter;

// Filter解放時に描画資源、補間コンテキスト、共有フレームを逆順で解放する。
procedure FinalizeLyricsFilter;

implementation

uses
  SYNC_Lyrics_ContextManager,
  SYNC_Lyrics_FrameShared,
  SYNC_Lyrics_MusicSync,
  SYNC_Lyrics_Renderer,
  SYNC_Lyrics_Time;

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl; forward;

var
  LyricsItem: TFILTER_ITEM_STRING = (
    ItemType: 'string';
    Name: '歌詞';
    Value: ''
  );
  MusicFileItem: TFILTER_ITEM_FILE = (
    ItemType: 'file';
    Name: '音楽ファイル';
    Value: '';
    FileFilter:
      '音楽ファイル (*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz)'#0 +
      '*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz'#0#0
  );
  TrackItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: 'トラック (-1=全て)';
    Value: -1;
    S: -1;
    E: 255;
    Step: 1
  );
  PositionXItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: 'X';
    Value: 0;
    S: -10000;
    E: 10000;
    Step: 1
  );
  PositionYItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: 'Y';
    Value: 0;
    S: -10000;
    E: 10000;
    Step: 1
  );
  PluginItems: array[0..5] of Pointer;
  Plugin: TFILTER_PLUGIN_TABLE = (
    Flag: FILTER_FLAG_VIDEO;
    Name: 'SYNC_歌詞テロップ_Filter';
    Label_: 'SYNC';
    Information: '音楽データに同期する歌詞テロップフィルター';
    Items: nil;
    Func_Proc_Video: LyricsProcVideo;
    Func_Proc_Audio: nil
  );

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  FrameState: TSyncLyricsFrameState;
  MusicFileName: string;
  StartSeconds: Double;
  SyncProgress: Double;
  Track: Integer;
begin
  try
    SyncProgress := 0;
    if TryGetLyricsFrameState(Video, FrameState) then
    begin
      MusicFileName := '';
      if Assigned(MusicFileItem.Value) then
        MusicFileName := string(MusicFileItem.Value);
      Track := Round(TrackItem.Value);
      StartSeconds := FrameState.TimeSeconds;
      if (Video <> nil) and (Video^.Object_ <> nil) and (FrameState.Rate > 0) then
        StartSeconds := StartSeconds -
          Video^.Object_^.Frame * FrameState.Scale / FrameState.Rate;
      ResolveMusicSyncProgress(MusicFileName, Track, StartSeconds,
        FrameState.TimeSeconds, SyncProgress);
    end;
    RenderLyrics(Video, LyricsItem.Value, SyncProgress,
      Round(PositionXItem.Value), Round(PositionYItem.Value));
  except
    // Delphi例外をAviUtl2のコールバック境界より外へ漏らさない。
  end;
  Result := 1;
end;

function GetLyricsFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if Plugin.Items = nil then
  begin
    // AviUtl2はnil終端された項目ポインター配列を参照する。
    PluginItems[0] := @LyricsItem;
    PluginItems[1] := @MusicFileItem;
    PluginItems[2] := @TrackItem;
    PluginItems[3] := @PositionXItem;
    PluginItems[4] := @PositionYItem;
    PluginItems[5] := nil;
    Plugin.Items := @PluginItems[0];
  end;
  Result := @Plugin;
end;

procedure InitializeLyricsFilter;
begin
  InitializeLyricsFrameShared;
  InitializeLyricsContexts;
  InitializeMusicSync;
  InitializeLyricsRenderer;
end;

procedure FinalizeLyricsFilter;
begin
  FinalizeLyricsRenderer;
  FinalizeMusicSync;
  FinalizeLyricsContexts;
  FinalizeLyricsFrameShared;
end;

end.
