unit SYNC_Lyrics_AudioPcm;

// FFmpeg音声をPCM16 stereo 48kHzへ順次変換し、呼び出し側へ小分けに渡す。

interface

uses
  System.SysUtils;

type
  TSyncAudioPcmCallback = reference to procedure(const Pcm: TBytes;
    SampleFrameCount: Integer; var ContinueDecoding: Boolean);

function DecodeSyncAudioPcm16Stereo48k(const FileName: string;
  const Callback: TSyncAudioPcmCallback;
  out ErrorMessage: string): Boolean;

implementation

uses
  System.Math,
  FFmpegApi;

const
  OUTPUT_CHANNEL_COUNT = 2;
  OUTPUT_SAMPLE_RATE = 48000;

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
  Pcm := nil;
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
    Pcm := nil;
    SampleFrameCount := 0;
    Exit;
  end;
  SetLength(Pcm, SampleFrameCount * OUTPUT_CHANNEL_COUNT *
    SizeOf(SmallInt));
  Result := True;
end;

function DecodeSyncAudioPcm16Stereo48k(const FileName: string;
  const Callback: TSyncAudioPcmCallback;
  out ErrorMessage: string): Boolean;
var
  AudioCodec: PAVCodec;
  AudioCodecContext: PAVCodecContext;
  CodecParameters: PAVCodecParameters;
  ContinueDecoding: Boolean;
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
  Utf8FileName: UTF8String;

  function ReceiveFrames: Boolean;
  var
    ReceiveResult: Integer;
  begin
    Result := True;
    while ContinueDecoding do
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
          ErrorMessage := 'デコードした音声をPCMへ変換できません。';
          Exit(False);
        end;
        Callback(Pcm, SampleFrameCount, ContinueDecoding);
      finally
        TFFmpegApi.av_frame_unref(Frame);
      end;
    end;
  end;

begin
  Result := False;
  ErrorMessage := '';
  FormatContext := nil;
  AudioCodecContext := nil;
  Frame := nil;
  Packet := nil;
  Resampler := nil;
  CurrentSampleFormat := -1;
  ContinueDecoding := True;
  try
    try
      if not Assigned(Callback) then
      begin
        ErrorMessage := 'PCM受信処理が指定されていません。';
        Exit;
      end;
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
      while ContinueDecoding and
        (TFFmpegApi.av_read_frame(FormatContext, Packet) >= 0) do
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
      if ContinueDecoding then
      begin
        OpenResult := TFFmpegApi.avcodec_send_packet(
          AudioCodecContext, nil);
        if (OpenResult >= 0) and not ReceiveFrames then
          Exit;
      end;
      Result := True;
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
