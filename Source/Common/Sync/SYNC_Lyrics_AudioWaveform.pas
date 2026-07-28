unit SYNC_Lyrics_AudioWaveform;

// FFmpeg音声をPCM16 stereo 48kHzへ順次変換し、表示用min/max包絡線へ縮約する。

interface

type
  TSyncAudioWavePoint = record
    Minimum: Single;
    Maximum: Single;
  end;
  TSyncAudioWaveform = TArray<TSyncAudioWavePoint>;

function LoadSyncAudioWaveform(const FileName: string; PointCount: Integer;
  out Waveform: TSyncAudioWaveform; out ErrorMessage: string): Boolean;

implementation

uses
  System.Math,
  System.SysUtils,
  FFmpegApi;

const
  PCM_BLOCK_FRAME_COUNT = 1024;
  OUTPUT_CHANNEL_COUNT = 2;
  OUTPUT_SAMPLE_RATE = 48000;

type
  PSmallIntArray = ^TSmallIntArray;
  TSmallIntArray = array[0..MaxInt div SizeOf(SmallInt) - 1] of SmallInt;
  TWaveBlocks = TArray<TSyncAudioWavePoint>;

procedure AppendPcmToBlocks(const Pcm: TBytes; SampleFrameCount: Integer;
  var Blocks: TWaveBlocks; var TotalFrameCount: Int64);
var
  BlockIndex: Integer;
  FrameIndex: Integer;
  LeftValue: Integer;
  MixedValue: Single;
  RightValue: Integer;
  Samples: PSmallIntArray;
begin
  if (Length(Pcm) = 0) or (SampleFrameCount <= 0) then
    Exit;
  Samples := PSmallIntArray(@Pcm[0]);
  for FrameIndex := 0 to SampleFrameCount - 1 do
  begin
    BlockIndex := TotalFrameCount div PCM_BLOCK_FRAME_COUNT;
    if BlockIndex >= Length(Blocks) then
    begin
      SetLength(Blocks, BlockIndex + 1);
      Blocks[BlockIndex].Minimum := 1;
      Blocks[BlockIndex].Maximum := -1;
    end;
    LeftValue := Samples^[FrameIndex * OUTPUT_CHANNEL_COUNT];
    RightValue := Samples^[FrameIndex * OUTPUT_CHANNEL_COUNT + 1];
    MixedValue := (LeftValue + RightValue) / 65536.0;
    if MixedValue < Blocks[BlockIndex].Minimum then
      Blocks[BlockIndex].Minimum := MixedValue;
    if MixedValue > Blocks[BlockIndex].Maximum then
      Blocks[BlockIndex].Maximum := MixedValue;
    Inc(TotalFrameCount);
  end;
end;

function CreateAudioResampler(CodecParameters: PAVCodecParameters;
  SampleFormat: Integer; out Resampler: PSwrContext;
  out ErrorMessage: string): Boolean;
var
  InputLayout: TAVChannelLayout;
  OutputLayout: TAVChannelLayout;
  ReturnCode: Integer;
begin
  Result := False;
  Resampler := nil;
  FillChar(InputLayout, SizeOf(InputLayout), 0);
  FillChar(OutputLayout, SizeOf(OutputLayout), 0);
  if CodecParameters = nil then
  begin
    ErrorMessage := '音声コーデック情報がありません。';
    Exit;
  end;

  if CodecParameters^.ch_layout.nb_channels > 0 then
    ReturnCode := TFFmpegApi.av_channel_layout_copy(
      @InputLayout, @CodecParameters^.ch_layout)
  else
  begin
    TFFmpegApi.av_channel_layout_default(@InputLayout, 1);
    ReturnCode := 0;
  end;
  if ReturnCode < 0 then
  begin
    ErrorMessage := TFFmpegApi.ErrorText(ReturnCode);
    Exit;
  end;

  try
    TFFmpegApi.av_channel_layout_default(
      @OutputLayout, OUTPUT_CHANNEL_COUNT);
    ReturnCode := TFFmpegApi.swr_alloc_set_opts2(@Resampler,
      @OutputLayout, AV_SAMPLE_FMT_S16, OUTPUT_SAMPLE_RATE,
      @InputLayout, SampleFormat, CodecParameters^.sample_rate, 0, nil);
    if (ReturnCode < 0) or (Resampler = nil) then
    begin
      ErrorMessage := '音声変換器を作成できません: ' +
        TFFmpegApi.ErrorText(ReturnCode);
      Exit;
    end;
    ReturnCode := TFFmpegApi.swr_init(Resampler);
    if ReturnCode < 0 then
    begin
      ErrorMessage := '音声変換器を初期化できません: ' +
        TFFmpegApi.ErrorText(ReturnCode);
      TFFmpegApi.swr_free(@Resampler);
      Exit;
    end;
    Result := True;
  finally
    TFFmpegApi.av_channel_layout_uninit(@OutputLayout);
    TFFmpegApi.av_channel_layout_uninit(@InputLayout);
  end;
end;

function ConvertFrame(Frame: PAVFrame; Resampler: PSwrContext;
  SourceSampleRate: Integer; out Pcm: TBytes;
  out SampleFrameCount: Integer): Boolean;
var
  OutputData: array[0..0] of PByte;
  OutputFrameCapacity: Integer;
begin
  Result := False;
  SetLength(Pcm, 0);
  SampleFrameCount := 0;
  if (Frame = nil) or (Resampler = nil) or (Frame^.nb_samples <= 0) then
    Exit;
  if SourceSampleRate <= 0 then
    SourceSampleRate := OUTPUT_SAMPLE_RATE;
  OutputFrameCapacity := Ceil(Frame^.nb_samples *
    OUTPUT_SAMPLE_RATE / SourceSampleRate) + 256;
  SetLength(Pcm, OutputFrameCapacity * OUTPUT_CHANNEL_COUNT *
    SizeOf(SmallInt));
  OutputData[0] := @Pcm[0];
  SampleFrameCount := TFFmpegApi.swr_convert(Resampler,
    @OutputData[0], OutputFrameCapacity, @Frame^.data[0],
    Frame^.nb_samples);
  if SampleFrameCount <= 0 then
  begin
    SetLength(Pcm, 0);
    SampleFrameCount := 0;
    Exit;
  end;
  SetLength(Pcm, SampleFrameCount * OUTPUT_CHANNEL_COUNT *
    SizeOf(SmallInt));
  Result := True;
end;

procedure CondenseBlocks(const Blocks: TWaveBlocks; PointCount: Integer;
  out Waveform: TSyncAudioWaveform);
var
  BlockIndex: Integer;
  EndBlock: Integer;
  PointIndex: Integer;
  StartBlock: Integer;
begin
  SetLength(Waveform, 0);
  PointCount := Min(Max(1, PointCount), Length(Blocks));
  if PointCount <= 0 then
    Exit;
  SetLength(Waveform, PointCount);
  for PointIndex := 0 to PointCount - 1 do
  begin
    StartBlock := PointIndex * Length(Blocks) div PointCount;
    EndBlock := (PointIndex + 1) * Length(Blocks) div PointCount;
    if EndBlock <= StartBlock then
      EndBlock := StartBlock + 1;
    Waveform[PointIndex].Minimum := 1;
    Waveform[PointIndex].Maximum := -1;
    for BlockIndex := StartBlock to EndBlock - 1 do
    begin
      Waveform[PointIndex].Minimum := Min(
        Waveform[PointIndex].Minimum, Blocks[BlockIndex].Minimum);
      Waveform[PointIndex].Maximum := Max(
        Waveform[PointIndex].Maximum, Blocks[BlockIndex].Maximum);
    end;
  end;
end;

function LoadSyncAudioWaveform(const FileName: string; PointCount: Integer;
  out Waveform: TSyncAudioWaveform; out ErrorMessage: string): Boolean;
var
  AudioCodec: PAVCodec;
  AudioCodecContext: PAVCodecContext;
  Blocks: TWaveBlocks;
  CodecParameters: PAVCodecParameters;
  CurrentSampleFormat: Integer;
  FormatContext: PAVFormatContext;
  Frame: PAVFrame;
  OpenResult: Integer;
  Packet: PAVPacket;
  Pcm: TBytes;
  Resampler: PSwrContext;
  SampleFrameCount: Integer;
  Stream: PAVStream;
  StreamIndex: Integer;
  TotalFrameCount: Int64;
  Utf8FileName: UTF8String;

  function ReceiveFrames: Boolean;
  var
    ReceiveResult: Integer;
  begin
    Result := True;
    while True do
    begin
      ReceiveResult := TFFmpegApi.avcodec_receive_frame(
        AudioCodecContext, Frame);
      if (ReceiveResult = AVERROR_EAGAIN) or
        (ReceiveResult = AVERROR_EOF) then
        Exit;
      if ReceiveResult < 0 then
      begin
        ErrorMessage := '音声フレームをデコードできません: ' +
          TFFmpegApi.ErrorText(ReceiveResult);
        Exit(False);
      end;
      try
        if (Resampler = nil) or
          (CurrentSampleFormat <> Frame^.format) then
        begin
          if Resampler <> nil then
            TFFmpegApi.swr_free(@Resampler);
          CurrentSampleFormat := Frame^.format;
          if not CreateAudioResampler(CodecParameters,
            CurrentSampleFormat, Resampler, ErrorMessage) then
            Exit(False);
        end;
        if not ConvertFrame(Frame, Resampler,
          CodecParameters^.sample_rate, Pcm, SampleFrameCount) then
        begin
          ErrorMessage := 'デコードした音声を波形形式へ変換できません。';
          Exit(False);
        end;
        AppendPcmToBlocks(Pcm, SampleFrameCount,
          Blocks, TotalFrameCount);
      finally
        TFFmpegApi.av_frame_unref(Frame);
      end;
    end;
  end;

begin
  Result := False;
  SetLength(Waveform, 0);
  ErrorMessage := '';
  FormatContext := nil;
  AudioCodecContext := nil;
  Frame := nil;
  Packet := nil;
  Resampler := nil;
  CurrentSampleFormat := -1;
  TotalFrameCount := 0;
  SetLength(Blocks, 0);
  try
    try
      TFFmpegApi.EnsureLoaded;
      Utf8FileName := UTF8String(FileName);
      OpenResult := TFFmpegApi.avformat_open_input(
        @FormatContext, PAnsiChar(Utf8FileName), nil, nil);
      if OpenResult < 0 then
      begin
        ErrorMessage := TFFmpegApi.ErrorText(OpenResult);
        Exit;
      end;
      OpenResult := TFFmpegApi.avformat_find_stream_info(
        FormatContext, nil);
      if OpenResult < 0 then
      begin
        ErrorMessage := TFFmpegApi.ErrorText(OpenResult);
        Exit;
      end;
      StreamIndex := TFFmpegApi.av_find_best_stream(
        FormatContext, AVMEDIA_TYPE_AUDIO, -1, -1, nil, 0);
      if StreamIndex < 0 then
      begin
        ErrorMessage := '利用可能な音声ストリームがありません。';
        Exit;
      end;
      Stream := StreamAt(FormatContext, StreamIndex);
      if (Stream = nil) or (Stream^.codecpar = nil) then
      begin
        ErrorMessage := '音声ストリーム情報を取得できません。';
        Exit;
      end;
      CodecParameters := Stream^.codecpar;
      AudioCodec := TFFmpegApi.avcodec_find_decoder(
        CodecParameters^.codec_id);
      if AudioCodec = nil then
      begin
        ErrorMessage := '対応する音声デコーダがありません。';
        Exit;
      end;
      AudioCodecContext := TFFmpegApi.avcodec_alloc_context3(AudioCodec);
      if AudioCodecContext = nil then
      begin
        ErrorMessage := '音声デコーダを作成できません。';
        Exit;
      end;
      OpenResult := TFFmpegApi.avcodec_parameters_to_context(
        AudioCodecContext, CodecParameters);
      if OpenResult < 0 then
      begin
        ErrorMessage := TFFmpegApi.ErrorText(OpenResult);
        Exit;
      end;
      OpenResult := TFFmpegApi.avcodec_open2(
        AudioCodecContext, AudioCodec, nil);
      if OpenResult < 0 then
      begin
        ErrorMessage := TFFmpegApi.ErrorText(OpenResult);
        Exit;
      end;
      Frame := TFFmpegApi.av_frame_alloc();
      Packet := TFFmpegApi.av_packet_alloc();
      if (Frame = nil) or (Packet = nil) then
      begin
        ErrorMessage := '音声デコード用バッファを作成できません。';
        Exit;
      end;

      while TFFmpegApi.av_read_frame(FormatContext, Packet) >= 0 do
      begin
        try
          if Packet^.stream_index <> StreamIndex then
            Continue;
          repeat
            OpenResult := TFFmpegApi.avcodec_send_packet(
              AudioCodecContext, Packet);
            if OpenResult = AVERROR_EAGAIN then
              if not ReceiveFrames then
                Exit;
          until OpenResult <> AVERROR_EAGAIN;
          if OpenResult < 0 then
            Continue;
          if not ReceiveFrames then
            Exit;
        finally
          TFFmpegApi.av_packet_unref(Packet);
        end;
      end;
      OpenResult := TFFmpegApi.avcodec_send_packet(
        AudioCodecContext, nil);
      if (OpenResult >= 0) and not ReceiveFrames then
        Exit;

      if Length(Blocks) = 0 then
      begin
        ErrorMessage := '波形に使用できる音声サンプルがありません。';
        Exit;
      end;
      CondenseBlocks(Blocks, PointCount, Waveform);
      Result := Length(Waveform) > 0;
    except
      on E: Exception do
        ErrorMessage := E.ClassName + ': ' + E.Message;
    end;
  finally
    if Resampler <> nil then
      TFFmpegApi.swr_free(@Resampler);
    if Packet <> nil then
      TFFmpegApi.av_packet_free(@Packet);
    if Frame <> nil then
      TFFmpegApi.av_frame_free(@Frame);
    if AudioCodecContext <> nil then
      TFFmpegApi.avcodec_free_context(@AudioCodecContext);
    if FormatContext <> nil then
      TFFmpegApi.avformat_close_input(@FormatContext);
  end;
end;

end.
