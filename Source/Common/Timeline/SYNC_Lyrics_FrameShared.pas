unit SYNC_Lyrics_FrameShared;

// InputとFilterのDLL間で、歌詞同期に使う現在フレームを受け渡す。

interface

type
  PSyncLyricsFrameState = ^TSyncLyricsFrameState;
  TSyncLyricsFrameState = record
    Magic      : Cardinal; // 共有領域が歌詞用レコードであることを識別する。
    Version    : Cardinal; // レコード形式のバージョン。
    Sequence   : Integer;  // 偶数は読取可能、奇数は書込中を表す。
    Frame      : Integer;  // Inputへ要求された絶対フレーム位置。
    Rate       : Integer;  // フレームレートの分子。
    Scale      : Integer;  // フレームレートの分母。
    TimeSeconds: Double;   // Frame * Scale / Rateで求めた秒位置。
    UpdateTick : UInt64;   // Inputが値を公開した時点のシステム時刻。
  end;

procedure InitializeLyricsFrameShared;
procedure FinalizeLyricsFrameShared;
procedure PublishLyricsFrame(Frame, Rate, Scale: Integer);
function TryReadLyricsFrame(out State: TSyncLyricsFrameState): Boolean;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  SharedMemoryBase;

const
  LYRICS_FRAME_MAP_NAME = 'Local\SYNC_Lyrics_Frame_V1';
  LYRICS_FRAME_MAGIC = $534C5246; // SLRF
  LYRICS_FRAME_VERSION = 1;

var
  SharedMemory: TSharedMemoryBase;

function GetMapView: PSyncLyricsFrameState;
begin
  if SharedMemory = nil then
    Exit(nil);
  Result := SharedMemory.View;
end;

procedure InitializeLyricsFrameShared;
begin
  if SharedMemory <> nil then
    Exit;

  try
    SharedMemory := TSharedMemoryBase.Create(LYRICS_FRAME_MAP_NAME,
      SizeOf(TSyncLyricsFrameState));
  except
    FreeAndNil(SharedMemory);
  end;
end;

procedure FinalizeLyricsFrameShared;
begin
  FreeAndNil(SharedMemory);
end;

procedure PublishLyricsFrame(Frame, Rate, Scale: Integer);
var
  MapView: PSyncLyricsFrameState;
  SequenceBefore: Integer;
  WriteSequence: Integer;
  Retry: Integer;
begin
  InitializeLyricsFrameShared;
  MapView := GetMapView;
  if MapView = nil then
    Exit;

  // 偶数から奇数へ変更できたInputだけが書き込む。
  WriteSequence := 0;
  for Retry := 0 to 15 do
  begin
    SequenceBefore := InterlockedCompareExchange(MapView^.Sequence, 0, 0);
    if Odd(SequenceBefore) then
      Continue;
    if InterlockedCompareExchange(MapView^.Sequence, SequenceBefore + 1,
      SequenceBefore) = SequenceBefore then
    begin
      WriteSequence := SequenceBefore + 1;
      Break;
    end;
  end;
  if WriteSequence = 0 then
    Exit;

  MapView^.Magic := LYRICS_FRAME_MAGIC;
  MapView^.Version := LYRICS_FRAME_VERSION;
  MapView^.Frame := Frame;
  MapView^.Rate := Rate;
  MapView^.Scale := Scale;
  if (Rate > 0) and (Scale > 0) then
    MapView^.TimeSeconds := Frame * Scale / Rate
  else
    MapView^.TimeSeconds := 0;
  MapView^.UpdateTick := GetTickCount64;
  InterlockedExchange(MapView^.Sequence, WriteSequence + 1);
end;

function TryReadLyricsFrame(out State: TSyncLyricsFrameState): Boolean;
var
  MapView: PSyncLyricsFrameState;
  SequenceBefore, SequenceAfter: Integer;
  Retry: Integer;
begin
  FillChar(State, SizeOf(State), 0);
  InitializeLyricsFrameShared;
  MapView := GetMapView;
  Result := False;
  if MapView = nil then
    Exit;

  // Inputの更新と重なった場合は短く再試行し、一貫した組だけを返す。
  for Retry := 0 to 2 do
  begin
    SequenceBefore := InterlockedCompareExchange(MapView^.Sequence, 0, 0);
    if Odd(SequenceBefore) then
      Continue;

    State := MapView^;
    SequenceAfter := InterlockedCompareExchange(MapView^.Sequence, 0, 0);
    Result := (SequenceBefore = SequenceAfter) and
      not Odd(SequenceAfter) and
      (State.Magic = LYRICS_FRAME_MAGIC) and
      (State.Version = LYRICS_FRAME_VERSION);
    if Result then
      Exit;
  end;

  FillChar(State, SizeOf(State), 0);
end;

initialization
  SharedMemory := nil;

finalization
  FinalizeLyricsFrameShared;

end.
