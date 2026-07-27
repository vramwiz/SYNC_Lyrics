unit SYNC_Lyrics_Time;

// Inputの絶対フレームとFilterの相対フレームから歌詞同期位置を取得する。

interface

uses
  AviUtl2FilterTypes,
  SYNC_Lyrics_FrameShared;

function TryGetLyricsFrameState(Video: PFILTER_PROC_VIDEO;
  out EffectiveState: TSyncLyricsFrameState): Boolean;

implementation

uses
  SYNC_Lyrics_ContextManager;

function TryGetLyricsFrameState(Video: PFILTER_PROC_VIDEO;
  out EffectiveState: TSyncLyricsFrameState): Boolean;
var
  SharedState: TSyncLyricsFrameState;
begin
  FillChar(EffectiveState, SizeOf(EffectiveState), 0);
  Result := TryReadLyricsFrame(SharedState) and
    ResolveLyricsFrameState(Video, SharedState, EffectiveState);
end;

end.
