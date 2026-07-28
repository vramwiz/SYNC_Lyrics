unit SYNC_Lyrics_AudioProbe;

// FFmpegを必要時だけロードし、手動同期フォームへ渡す音声基本情報を取得する。

interface

type
  TSyncAudioFileInfo = record
    DurationSeconds: Double;
    SampleRate: Integer;
    Channels: Integer;
    StreamIndex: Integer;
  end;

function TryProbeSyncAudioFile(const FileName: string;
  out AudioInfo: TSyncAudioFileInfo; out ErrorMessage: string): Boolean;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  FFmpegApi;

procedure ClearAudioInfo(out AudioInfo: TSyncAudioFileInfo);
begin
  AudioInfo.DurationSeconds := 0;
  AudioInfo.SampleRate := 0;
  AudioInfo.Channels := 0;
  AudioInfo.StreamIndex := -1;
end;

function TryProbeSyncAudioFile(const FileName: string;
  out AudioInfo: TSyncAudioFileInfo; out ErrorMessage: string): Boolean;
var
  CodecParameters: PAVCodecParameters;
  FormatContext: PAVFormatContext;
  OpenResult: Integer;
  Stream: PAVStream;
  StreamIndex: Integer;
  Utf8FileName: UTF8String;
begin
  Result := False;
  ClearAudioInfo(AudioInfo);
  ErrorMessage := '';
  if Trim(FileName) = '' then
  begin
    ErrorMessage := '同期元ファイルが指定されていません。';
    Exit;
  end;
  if not TFile.Exists(FileName) then
  begin
    ErrorMessage := '指定された同期元ファイルが見つかりません。';
    Exit;
  end;

  FormatContext := nil;
  try
    try
      // 楽譜同期だけを使う場合は、ここへ到達しないためFFmpeg DLLを要求しない。
      TFFmpegApi.EnsureLoaded;
      Utf8FileName := UTF8String(FileName);
      OpenResult := TFFmpegApi.avformat_open_input(@FormatContext,
        PAnsiChar(Utf8FileName), nil, nil);
      if OpenResult < 0 then
      begin
        ErrorMessage := 'FFmpegでファイルを開けません: ' +
          TFFmpegApi.ErrorText(OpenResult);
        Exit;
      end;

      OpenResult := TFFmpegApi.avformat_find_stream_info(
        FormatContext, nil);
      if OpenResult < 0 then
      begin
        ErrorMessage := '音声ストリーム情報を読み取れません: ' +
          TFFmpegApi.ErrorText(OpenResult);
        Exit;
      end;

      StreamIndex := TFFmpegApi.av_find_best_stream(
        FormatContext, AVMEDIA_TYPE_AUDIO, -1, -1, nil, 0);
      if StreamIndex < 0 then
      begin
        ErrorMessage := 'このファイルに利用可能な音声ストリームがありません。';
        Exit;
      end;
      Stream := StreamAt(FormatContext, StreamIndex);
      if (Stream = nil) or (Stream^.codecpar = nil) then
      begin
        ErrorMessage := '音声ストリームの形式情報を取得できません。';
        Exit;
      end;

      CodecParameters := Stream^.codecpar;
      AudioInfo.StreamIndex := StreamIndex;
      AudioInfo.SampleRate := CodecParameters^.sample_rate;
      AudioInfo.Channels := CodecParameters^.ch_layout.nb_channels;
      if (Stream^.duration > 0) and
        (Stream^.time_base.num > 0) and (Stream^.time_base.den > 0) then
        AudioInfo.DurationSeconds := Stream^.duration *
          Stream^.time_base.num / Stream^.time_base.den
      else if FormatContext^.duration > 0 then
        AudioInfo.DurationSeconds :=
          FormatContext^.duration / AV_TIME_BASE;
      Result := True;
    except
      on E: Exception do
        ErrorMessage := 'FFmpegを初期化できません: ' + E.Message;
    end;
  finally
    if FormatContext <> nil then
      TFFmpegApi.avformat_close_input(@FormatContext);
  end;
end;

end.
