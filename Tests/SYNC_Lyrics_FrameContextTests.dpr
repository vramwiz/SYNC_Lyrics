program SYNC_Lyrics_FrameContextTests;

// Input読込と、キャッシュ時のFilter相対フレーム補間を一連で検証する。

{$APPTYPE CONSOLE}

uses
  Winapi.Windows,
  System.Math,
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  AviUtl2InputTypes in 'Source\Lib\AviUtl2InputTypes.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemoryBase.pas',
  SYNC_Lyrics_FrameShared in 'Source\Common\Timeline\SYNC_Lyrics_FrameShared.pas',
  SYNC_Lyrics_ContextManager in 'Source\Common\Timeline\SYNC_Lyrics_ContextManager.pas',
  SYNC_Lyrics_Time in 'Source\Common\Timeline\SYNC_Lyrics_Time.pas',
  SYNC_Lyrics_InputPlugin in 'Source\Plugin\Input\SYNC_Lyrics_InputPlugin.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckResolved(var Video: TFILTER_PROC_VIDEO; ExpectedFrame: Integer;
  const MessageText: string);
var
  State: TSyncLyricsFrameState;
begin
  Check(TryGetLyricsFrameState(@Video, State),
    MessageText + ': resolve failed');
  Check(State.Frame = ExpectedFrame,
    Format('%s: expected frame %d, actual %d',
      [MessageText, ExpectedFrame, State.Frame]));
  Check(SameValue(State.TimeSeconds,
    ExpectedFrame * State.Scale / State.Rate),
    MessageText + ': time mismatch');
end;

procedure TestInputAndCachedInterpolation;
var
  Buffer    : array[0..15] of Byte;
  Context   : INPUT_HANDLE;
  ObjectInfo: TOBJECT_INFO;
  Video     : TFILTER_PROC_VIDEO;
begin
  Context := LyricsInputOpen('2_2_3600_30_1.synclyrics');
  Check(Context <> nil, 'input open failed');
  try
    FillChar(Buffer, SizeOf(Buffer), $FF);
    Check(LyricsInputReadVideo(Context, 150, @Buffer[0]) =
      SizeOf(Buffer), 'input read failed');

    FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
    FillChar(Video, SizeOf(Video), 0);
    ObjectInfo.ID := 1;
    ObjectInfo.EffectID := 10;
    ObjectInfo.Frame := 10;
    Video.Object_ := @ObjectInfo;
    CheckResolved(Video, 150, 'initial input anchor');

    // Inputを再度呼ばず、AviUtl2の入力キャッシュが効いた状態を再現する。
    ObjectInfo.Frame := 11;
    CheckResolved(Video, 151, 'cached next frame');
    ObjectInfo.Frame := 40;
    CheckResolved(Video, 180, 'cached relative interpolation');

    // Inputが再発火した場合は、現在の相対フレームで新しい絶対位置へ基準化する。
    Check(LyricsInputReadVideo(Context, 300, @Buffer[0]) =
      SizeOf(Buffer), 'input re-read failed');
    CheckResolved(Video, 300, 'input re-anchor');
    ObjectInfo.Frame := 41;
    CheckResolved(Video, 301, 'after re-anchor');
  finally
    LyricsInputClose(Context);
  end;
end;

procedure TestRejectsStaleInitialAnchor;
var
  EffectiveState: TSyncLyricsFrameState;
  ObjectInfo: TOBJECT_INFO;
  SharedState: TSyncLyricsFrameState;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(SharedState, SizeOf(SharedState), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.ID := 2;
  ObjectInfo.EffectID := 20;
  Video.Object_ := @ObjectInfo;
  SharedState.Sequence := 2;
  SharedState.Frame := 81;
  SharedState.Rate := 30;
  SharedState.Scale := 1;
  SharedState.UpdateTick := GetTickCount64 - 1001;

  Check(not ResolveLyricsFrameState(@Video, SharedState, EffectiveState),
    'stale shared state was accepted as a new object anchor');
end;

begin
  InitializeLyricsFrameShared;
  InitializeLyricsContexts;
  try
    TestInputAndCachedInterpolation;
    TestRejectsStaleInitialAnchor;
    Writeln('PASS');
  finally
    FinalizeLyricsContexts;
    FinalizeLyricsFrameShared;
  end;
end.
