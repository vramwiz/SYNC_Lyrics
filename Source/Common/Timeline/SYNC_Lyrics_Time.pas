unit SYNC_Lyrics_Time;

// 単体Filterのオブジェクト内フレームから歌詞同期位置を取得する。

interface

uses
  AviUtl2FilterTypes;

type
  TSyncLyricsFrameState = record
    Frame: Integer;
    Rate: Integer;
    Scale: Integer;
    TimeSeconds: Double;
  end;

function TryGetLyricsFrameState(Video: PFILTER_PROC_VIDEO;
  out EffectiveState: TSyncLyricsFrameState): Boolean;

implementation

function TryGetLyricsFrameState(Video: PFILTER_PROC_VIDEO;
  out EffectiveState: TSyncLyricsFrameState): Boolean;
begin
  FillChar(EffectiveState, SizeOf(EffectiveState), 0);
  Result := (Video <> nil) and (Video^.Object_ <> nil) and
    (Video^.Scene <> nil) and (Video^.Scene^.Rate > 0) and
    (Video^.Scene^.Scale > 0);
  if not Result then
    Exit;
  EffectiveState.Frame := Video^.Object_^.Frame;
  EffectiveState.Rate := Video^.Scene^.Rate;
  EffectiveState.Scale := Video^.Scene^.Scale;
  EffectiveState.TimeSeconds := EffectiveState.Frame *
    EffectiveState.Scale / EffectiveState.Rate;
end;

end.
