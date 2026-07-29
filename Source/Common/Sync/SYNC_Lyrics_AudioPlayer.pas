unit SYNC_Lyrics_AudioPlayer;

// 手動同期フォーム用のFFmpegデコード＋waveOutストリーミング再生。

interface

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils;

type
  TSyncAudioPlayer = class;

  TSyncAudioPlaybackThread = class(TThread)
  private
    FFileName: string;
    FOwner: TSyncAudioPlayer;
    FRate: Double;
    FStartPositionSeconds: Double;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TSyncAudioPlayer; const AFileName: string;
      ARate, AStartPositionSeconds: Double);
  end;

  TSyncAudioPlayer = class
  private
    FErrorLock: TCriticalSection;
    FErrorMessage: string;
    FPlaying: Integer;
    FPositionMs: Integer;
    FThread: TSyncAudioPlaybackThread;
    procedure SetError(const Value: string);
    procedure SetPlaying(Value: Boolean);
    procedure SetPositionMs(Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    function ErrorMessage: string;
    function IsPlaying: Boolean;
    function PositionSeconds: Double;
    function Start(const FileName: string; Rate, StartPositionSeconds: Double;
      out ErrorMessage: string): Boolean;
    procedure Stop;
  end;

implementation

uses
  System.Generics.Collections,
  System.Math,
  Winapi.MMSystem,
  Winapi.Windows,
  FFmpegAudioTempo,
  SYNC_Lyrics_AudioPcm;

const
  OUTPUT_CHANNEL_COUNT = 2;
  OUTPUT_SAMPLE_RATE = 48000;
  TARGET_QUEUE_SAMPLES = OUTPUT_SAMPLE_RATE;

type
  PPlaybackBuffer = ^TPlaybackBuffer;
  TPlaybackBuffer = record
    Header: TWaveHdr;
    Data: Pointer;
  end;

procedure ReleaseDoneBuffers(WaveOut: HWAVEOUT;
  Buffers: TList<PPlaybackBuffer>; ForceAll: Boolean);
var
  Buffer: PPlaybackBuffer;
  I: Integer;
begin
  for I := Buffers.Count - 1 downto 0 do
  begin
    Buffer := Buffers[I];
    if ForceAll or ((Buffer^.Header.dwFlags and WHDR_DONE) <> 0) then
    begin
      waveOutUnprepareHeader(WaveOut, @Buffer^.Header,
        SizeOf(Buffer^.Header));
      FreeMem(Buffer^.Data);
      Dispose(Buffer);
      Buffers.Delete(I);
    end;
  end;
end;

function QueuePcm(WaveOut: HWAVEOUT; Buffers: TList<PPlaybackBuffer>;
  const Pcm: TBytes; out ErrorMessage: string): Boolean;
var
  Buffer: PPlaybackBuffer;
  ReturnCode: MMRESULT;
begin
  Result := False;
  ErrorMessage := '';
  if Length(Pcm) = 0 then
    Exit(True);
  New(Buffer);
  FillChar(Buffer^, SizeOf(Buffer^), 0);
  GetMem(Buffer^.Data, Length(Pcm));
  Move(Pcm[0], Buffer^.Data^, Length(Pcm));
  Buffer^.Header.lpData := Buffer^.Data;
  Buffer^.Header.dwBufferLength := Length(Pcm);
  ReturnCode := waveOutPrepareHeader(WaveOut, @Buffer^.Header,
    SizeOf(Buffer^.Header));
  if ReturnCode <> MMSYSERR_NOERROR then
  begin
    ErrorMessage := Format('waveOutPrepareHeader failed: %d', [ReturnCode]);
    FreeMem(Buffer^.Data);
    Dispose(Buffer);
    Exit;
  end;
  ReturnCode := waveOutWrite(WaveOut, @Buffer^.Header,
    SizeOf(Buffer^.Header));
  if ReturnCode <> MMSYSERR_NOERROR then
  begin
    waveOutUnprepareHeader(WaveOut, @Buffer^.Header,
      SizeOf(Buffer^.Header));
    ErrorMessage := Format('waveOutWrite failed: %d', [ReturnCode]);
    FreeMem(Buffer^.Data);
    Dispose(Buffer);
    Exit;
  end;
  Buffers.Add(Buffer);
  Result := True;
end;

function PlayedSamples(WaveOut: HWAVEOUT): Int64;
var
  Time: TMMTime;
begin
  Result := 0;
  FillChar(Time, SizeOf(Time), 0);
  Time.wType := TIME_SAMPLES;
  if waveOutGetPosition(WaveOut, @Time, SizeOf(Time)) =
    MMSYSERR_NOERROR then
    if Time.wType = TIME_SAMPLES then
      Result := Time.sample
    else if Time.wType = TIME_BYTES then
      Result := Time.cb div (OUTPUT_CHANNEL_COUNT * SizeOf(SmallInt));
end;

constructor TSyncAudioPlaybackThread.Create(AOwner: TSyncAudioPlayer;
  const AFileName: string; ARate, AStartPositionSeconds: Double);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FFileName := AFileName;
  FRate := ARate;
  FStartPositionSeconds := Max(0.0, AStartPositionSeconds);
end;

procedure TSyncAudioPlaybackThread.Execute;
var
  Buffers: TList<PPlaybackBuffer>;
  DecodeError: string;
  FramesToSkip: Int64;
  FlushPendingPcm: TFunc<Boolean>;
  InputByteOffset: Integer;
  OldPcmLength: Integer;
  OutputPcm: TBytes;
  OutputSampleCount: Integer;
  PendingPcm: TBytes;
  PendingSampleCount: Integer;
  QueueError: string;
  QueuedSamples: Int64;
  RemainingFrameCount: Integer;
  SkipFrameCount: Integer;
  StartPositionMs: Integer;
  WaveFormat: TWaveFormatEx;
  WaveOut: HWAVEOUT;
  WaveResult: MMRESULT;
begin
  WaveOut := 0;
  QueuedSamples := 0;
  StartPositionMs := Round(FStartPositionSeconds * 1000);
  FramesToSkip := Round(FStartPositionSeconds * OUTPUT_SAMPLE_RATE);
  PendingSampleCount := 0;
  PendingPcm := nil;
  Buffers := TList<PPlaybackBuffer>.Create;
  try
    FlushPendingPcm :=
      function: Boolean
      var
        Played: Int64;
      begin
        Result := False;
        while not Terminated do
        begin
          Played := PlayedSamples(WaveOut);
          FOwner.SetPositionMs(StartPositionMs +
            Round(Played * FRate * 1000 / OUTPUT_SAMPLE_RATE));
          ReleaseDoneBuffers(WaveOut, Buffers, False);
          if QueuedSamples - Played < TARGET_QUEUE_SAMPLES then
            Break;
          Sleep(10);
        end;
        if Terminated then
          Exit;
        if not TempoPcm16Stereo48k(PendingPcm, FRate, OutputPcm,
          OutputSampleCount, QueueError) then
        begin
          FOwner.SetError(QueueError);
          Exit;
        end;
        PendingPcm := nil;
        PendingSampleCount := 0;
        if not QueuePcm(WaveOut, Buffers, OutputPcm,
          QueueError) then
        begin
          FOwner.SetError(QueueError);
          Exit;
        end;
        Inc(QueuedSamples, OutputSampleCount);
        Result := True;
      end;
    FillChar(WaveFormat, SizeOf(WaveFormat), 0);
    WaveFormat.wFormatTag := WAVE_FORMAT_PCM;
    WaveFormat.nChannels := OUTPUT_CHANNEL_COUNT;
    WaveFormat.nSamplesPerSec := OUTPUT_SAMPLE_RATE;
    WaveFormat.wBitsPerSample := 16;
    WaveFormat.nBlockAlign := OUTPUT_CHANNEL_COUNT * SizeOf(SmallInt);
    WaveFormat.nAvgBytesPerSec :=
      OUTPUT_SAMPLE_RATE * WaveFormat.nBlockAlign;
    WaveResult := waveOutOpen(@WaveOut, WAVE_MAPPER, @WaveFormat,
      0, 0, CALLBACK_NULL);
    if WaveResult <> MMSYSERR_NOERROR then
    begin
      FOwner.SetError(Format('waveOutOpen failed: %d', [WaveResult]));
      Exit;
    end;

    if not DecodeSyncAudioPcm16Stereo48k(FFileName,
      procedure(const Pcm: TBytes; SampleFrameCount: Integer;
        var ContinueDecoding: Boolean)
      begin
        if Terminated then
        begin
          ContinueDecoding := False;
          Exit;
        end;
        SkipFrameCount := Min(Int64(SampleFrameCount), FramesToSkip);
        Dec(FramesToSkip, SkipFrameCount);
        RemainingFrameCount := SampleFrameCount - SkipFrameCount;
        if RemainingFrameCount <= 0 then
          Exit;
        InputByteOffset := SkipFrameCount * OUTPUT_CHANNEL_COUNT *
          SizeOf(SmallInt);
        OldPcmLength := Length(PendingPcm);
        SetLength(PendingPcm, OldPcmLength +
          RemainingFrameCount * OUTPUT_CHANNEL_COUNT * SizeOf(SmallInt));
        Move(Pcm[InputByteOffset], PendingPcm[OldPcmLength],
          RemainingFrameCount * OUTPUT_CHANNEL_COUNT * SizeOf(SmallInt));
        Inc(PendingSampleCount, RemainingFrameCount);
        // atempoは短すぎる入力では出力しないため、2秒単位にまとめる。
        if (PendingSampleCount >= OUTPUT_SAMPLE_RATE * 2) and
          (not FlushPendingPcm()) then
        begin
          ContinueDecoding := False;
          Terminate;
        end;
      end, DecodeError) and (not Terminated) then
      FOwner.SetError(DecodeError);

    if (not Terminated) and (PendingSampleCount > 0) and
      (not FlushPendingPcm()) then
      Terminate;

    while (not Terminated) and
      (PlayedSamples(WaveOut) < QueuedSamples) do
    begin
      FOwner.SetPositionMs(StartPositionMs +
        Round(PlayedSamples(WaveOut) * FRate * 1000 /
        OUTPUT_SAMPLE_RATE));
      ReleaseDoneBuffers(WaveOut, Buffers, False);
      Sleep(10);
    end;
    if not Terminated then
      FOwner.SetPositionMs(StartPositionMs +
        Round(QueuedSamples * FRate * 1000 / OUTPUT_SAMPLE_RATE));
  finally
    if WaveOut <> 0 then
    begin
      waveOutReset(WaveOut);
      ReleaseDoneBuffers(WaveOut, Buffers, True);
      waveOutClose(WaveOut);
    end;
    Buffers.Free;
    FlushPendingPcm := nil;
    FOwner.SetPlaying(False);
  end;
end;

constructor TSyncAudioPlayer.Create;
begin
  inherited;
  FErrorLock := TCriticalSection.Create;
end;

destructor TSyncAudioPlayer.Destroy;
begin
  Stop;
  FErrorLock.Free;
  inherited;
end;

function TSyncAudioPlayer.ErrorMessage: string;
begin
  FErrorLock.Acquire;
  try
    Result := FErrorMessage;
  finally
    FErrorLock.Release;
  end;
end;

function TSyncAudioPlayer.IsPlaying: Boolean;
begin
  Result := TInterlocked.CompareExchange(FPlaying, 0, 0) <> 0;
end;

function TSyncAudioPlayer.PositionSeconds: Double;
begin
  Result := TInterlocked.CompareExchange(FPositionMs, 0, 0) / 1000;
end;

procedure TSyncAudioPlayer.SetError(const Value: string);
begin
  FErrorLock.Acquire;
  try
    FErrorMessage := Value;
  finally
    FErrorLock.Release;
  end;
end;

procedure TSyncAudioPlayer.SetPlaying(Value: Boolean);
begin
  if Value then
    TInterlocked.Exchange(FPlaying, 1)
  else
    TInterlocked.Exchange(FPlaying, 0);
end;

procedure TSyncAudioPlayer.SetPositionMs(Value: Integer);
begin
  TInterlocked.Exchange(FPositionMs, Max(0, Value));
end;

function TSyncAudioPlayer.Start(const FileName: string; Rate,
  StartPositionSeconds: Double; out ErrorMessage: string): Boolean;
begin
  Stop;
  SetError('');
  StartPositionSeconds := Max(0.0, StartPositionSeconds);
  SetPositionMs(Round(StartPositionSeconds * 1000));
  if not FileExists(FileName) then
  begin
    ErrorMessage := '音声ファイルが見つかりません。';
    Exit(False);
  end;
  if not (SameValue(Rate, 1.0) or SameValue(Rate, 0.75) or
    SameValue(Rate, 0.5)) then
  begin
    ErrorMessage := '対応していない再生速度です。';
    Exit(False);
  end;
  FThread := TSyncAudioPlaybackThread.Create(Self, FileName, Rate,
    StartPositionSeconds);
  SetPlaying(True);
  FThread.Start;
  ErrorMessage := '';
  Result := True;
end;

procedure TSyncAudioPlayer.Stop;
begin
  if FThread <> nil then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  SetPlaying(False);
end;

end.
