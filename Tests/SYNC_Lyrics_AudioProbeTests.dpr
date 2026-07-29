program SYNC_Lyrics_AudioProbeTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  FFmpegApi in 'Source\Lib\FFmpeg\FFmpegApi.pas',
  FFmpegAudioTempo in 'Source\Lib\FFmpeg\FFmpegAudioTempo.pas',
  SYNC_Lyrics_AudioProbe in
    'Source\Common\Sync\SYNC_Lyrics_AudioProbe.pas',
  SYNC_Lyrics_AudioPcm in
    'Source\Common\Sync\SYNC_Lyrics_AudioPcm.pas',
  SYNC_Lyrics_AudioWaveform in
    'Source\Common\Sync\SYNC_Lyrics_AudioWaveform.pas';

var
  AudioInfo: TSyncAudioFileInfo;
  DecodedFrameCount: Int64;
  ErrorMessage: string;
  InputPcm: TBytes;
  OutputPcm: TBytes;
  OutputSampleCount: Integer;
  Waveform: TSyncAudioWaveform;
begin
  try
    if ParamCount < 1 then
      raise Exception.Create('音声ファイルを指定してください。');
    if not TryProbeSyncAudioFile(ParamStr(1), AudioInfo, ErrorMessage) then
      raise Exception.Create(ErrorMessage);
    if (AudioInfo.DurationSeconds <= 0) or
      (AudioInfo.SampleRate <= 0) or (AudioInfo.Channels <= 0) then
      raise Exception.Create('音声基本情報が不正です。');
    if not LoadSyncAudioWaveform(ParamStr(1), 256,
      Waveform, ErrorMessage) then
      raise Exception.Create(ErrorMessage);
    if Length(Waveform) = 0 then
      raise Exception.Create('波形データが空です。');
    DecodedFrameCount := 0;
    if not DecodeSyncAudioPcm16Stereo48k(ParamStr(1),
      procedure(const Pcm: TBytes; SampleFrameCount: Integer;
        var ContinueDecoding: Boolean)
      begin
        Inc(DecodedFrameCount, SampleFrameCount);
      end, ErrorMessage) then
      raise Exception.Create(ErrorMessage);
    if DecodedFrameCount <= 0 then
      raise Exception.Create('PCMデコード結果が空です。');
    SetLength(InputPcm, 48000 * 2 * SizeOf(SmallInt));
    if not TempoPcm16Stereo48k(InputPcm, 0.75, OutputPcm,
      OutputSampleCount, ErrorMessage) then
      raise Exception.Create(ErrorMessage);
    if OutputSampleCount < 60000 then
      raise Exception.CreateFmt(
        '0.75倍速の出力サンプル数が不足しています: %d',
        [OutputSampleCount]);
    SetLength(InputPcm, 24000 * 2 * SizeOf(SmallInt));
    if not TempoPcm16Stereo48k(InputPcm, 0.75, OutputPcm,
      OutputSampleCount, ErrorMessage) then
      raise Exception.Create(ErrorMessage);
    if OutputSampleCount <= 0 then
      raise Exception.Create(
        '0.75倍速の再生チャンク変換で音声が出力されません。');
    Writeln(Format(
      'PASS duration=%.3f sample_rate=%d channels=%d stream=%d points=%d pcm=%d tempo075=%d',
      [AudioInfo.DurationSeconds, AudioInfo.SampleRate,
      AudioInfo.Channels, AudioInfo.StreamIndex, Length(Waveform),
      DecodedFrameCount, OutputSampleCount],
      TFormatSettings.Invariant));
  except
    on E: Exception do
    begin
      Writeln('FAIL: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
