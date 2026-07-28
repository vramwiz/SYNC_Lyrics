unit SYNC_Lyrics_ManualSyncSettingsForm;

// FFmpeg音声を使う手動同期設定画面。波形と速度変更再生を提供する。

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  SYNC_Lyrics_AudioProbe,
  SYNC_Lyrics_AudioPlayer,
  SYNC_Lyrics_AudioWaveform,
  SYNC_Lyrics_ManualSyncEditModel;

type
  TFormLyricsManualSyncSettings = class(TForm)
    TitleLabel: TLabel;
    FileCaptionLabel: TLabel;
    FileValueLabel: TLabel;
    DurationCaptionLabel: TLabel;
    DurationValueLabel: TLabel;
    SampleRateCaptionLabel: TLabel;
    SampleRateValueLabel: TLabel;
    ChannelsCaptionLabel: TLabel;
    ChannelsValueLabel: TLabel;
    PlaybackCaptionLabel: TLabel;
    PlaybackPositionLabel: TLabel;
    StopButton: TButton;
    PlayButton: TButton;
    RateComboBox: TComboBox;
    LoopCheckBox: TCheckBox;
    AdjustModeButton: TButton;
    TimingModeButton: TButton;
    RearmButton: TButton;
    WaveformPaintBox: TPaintBox;
    LyricsCaptionLabel: TLabel;
    LyricsMemo: TMemo;
    StatusLabel: TLabel;
    ApplyButton: TButton;
    CancelButton: TButton;
    PlaybackTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PlayButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure PlaybackTimerTimer(Sender: TObject);
    procedure RateComboBoxChange(Sender: TObject);
    procedure AdjustModeButtonClick(Sender: TObject);
    procedure TimingModeButtonClick(Sender: TObject);
    procedure RearmButtonClick(Sender: TObject);
    procedure LyricsMemoChange(Sender: TObject);
    procedure ApplyButtonClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure WaveformPaintBoxMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure WaveformPaintBoxMouseMove(Sender: TObject;
      Shift: TShiftState; X, Y: Integer);
    procedure WaveformPaintBoxMouseUp(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure WaveformPaintBoxPaint(Sender: TObject);
  private
    FAudioFileName: string;
    FAudioDurationSeconds: Double;
    FAudioPlayer: TSyncAudioPlayer;
    FDraggingBoundary: Integer;
    FDraggingPlayback: Boolean;
    FDraggingView: Boolean;
    FViewDragStartSeconds: Double;
    FViewDragStartX: Integer;
    FDisplaySeconds: Double;
    FEditModel: TManualSyncEditModel;
    FInputMode: Integer;
    FLyricsLabels: TArray<string>;
    FPlaybackPositionSeconds: Double;
    FViewStartSeconds: Double;
    FWaveform: TSyncAudioWaveform;
    FWaveformMessage: string;
    function SelectedPlaybackRate: Double;
    procedure BuildLyricsLabels;
    function PlotRect: TRect;
    function SecondsToX(Value: Double): Integer;
    function XToSeconds(Value: Integer): Double;
    procedure RefreshModeDisplay;
    procedure RefreshSyncStatus;
    procedure SetPlaybackPosition(Value: Double);
    procedure StartPlayback;
    procedure StopPlayback;
  public
    procedure LoadSettings(const FileName: string;
      const AudioInfo: TSyncAudioFileInfo; const Lyrics, SyncText: string);
    function LyricsText: string;
    function SyncText: string;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  SYNC_Lyrics_LyricParser,
  Vcl.Dialogs,
  Winapi.Windows;

{$R *.dfm}

const
  INITIAL_DISPLAY_SECONDS = 10.0;
  MAX_DISPLAY_SECONDS = 60.0;
  MIN_DISPLAY_SECONDS = 1.0;

type
  TCapturePaintBox = class(TPaintBox)
  public
    property MouseCapture;
  end;

procedure TFormLyricsManualSyncSettings.FormCreate(Sender: TObject);
begin
  FAudioPlayer := TSyncAudioPlayer.Create;
  FEditModel := TManualSyncEditModel.Create;
  FDraggingBoundary := -1;
  FDraggingPlayback := False;
  FDraggingView := False;
  FDisplaySeconds := INITIAL_DISPLAY_SECONDS;
  FInputMode := 0;
  FViewStartSeconds := 0;
  RateComboBox.ItemIndex := 0;
  RefreshModeDisplay;
end;

procedure TFormLyricsManualSyncSettings.FormDestroy(Sender: TObject);
begin
  PlaybackTimer.Enabled := False;
  FreeAndNil(FAudioPlayer);
  FreeAndNil(FEditModel);
end;

procedure TFormLyricsManualSyncSettings.LoadSettings(
  const FileName: string; const AudioInfo: TSyncAudioFileInfo;
  const Lyrics, SyncText: string);
var
  WaveformError: string;
begin
  StopPlayback;
  FAudioFileName := FileName;
  FAudioDurationSeconds := AudioInfo.DurationSeconds;
  FDisplaySeconds := Min(INITIAL_DISPLAY_SECONDS,
    Max(0.001, FAudioDurationSeconds));
  FViewStartSeconds := 0;
  FPlaybackPositionSeconds := 0;
  PlaybackPositionLabel.Caption := Format('0.000 / %.3f 秒',
    [FAudioDurationSeconds], TFormatSettings.Invariant);
  FileValueLabel.Caption := FileName;
  DurationValueLabel.Caption := Format('%.3f 秒',
    [AudioInfo.DurationSeconds], TFormatSettings.Invariant);
  SampleRateValueLabel.Caption := Format('%d Hz',
    [AudioInfo.SampleRate]);
  ChannelsValueLabel.Caption := IntToStr(AudioInfo.Channels);
  LyricsMemo.Text := Lyrics;
  BuildLyricsLabels;
  FEditModel.Initialize(Length(FLyricsLabels),
    FAudioDurationSeconds, SyncText, FDisplaySeconds);
  FWaveformMessage := '';
  Screen.Cursor := crHourGlass;
  try
    if LoadSyncAudioWaveform(FileName, 4096,
      FWaveform, WaveformError) then
      StatusLabel.Caption :=
        '波形を読み込みました。速度を選び、再生で音声を確認できます。'
    else
    begin
      SetLength(FWaveform, 0);
      FWaveformMessage := '波形を読み込めません: ' + WaveformError;
      StatusLabel.Caption := FWaveformMessage;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  WaveformPaintBox.Invalidate;
  RefreshSyncStatus;
end;

procedure TFormLyricsManualSyncSettings.BuildLyricsLabels;
var
  I: Integer;
  PlainText: string;
  RubySpans: TLyricsRubySpans;
  Units: TLyricsDisplayUnits;
begin
  ParseLyrics(LyricsMemo.Text, PlainText, RubySpans);
  BuildLyricsDisplayUnits(PlainText, RubySpans, Units);
  // 同じ要素数でSetLengthしても既存のstring要素は消えないため、
  // 編集・初期読込のたびに必ず空配列からラベルを再構築する。
  SetLength(FLyricsLabels, 0);
  SetLength(FLyricsLabels, CountLyricsDisplayUnits(LyricsMemo.Text));
  for I := 0 to High(Units) do
    if Units[I].SyncUnitIndex >= 0 then
      FLyricsLabels[Units[I].SyncUnitIndex] :=
        FLyricsLabels[Units[I].SyncUnitIndex] +
        Copy(PlainText, Units[I].BaseStart, Units[I].BaseLength);
end;

function TFormLyricsManualSyncSettings.LyricsText: string;
begin
  Result := LyricsMemo.Text;
end;

function TFormLyricsManualSyncSettings.SyncText: string;
begin
  Result := FEditModel.SerializeSyncText;
end;

function TFormLyricsManualSyncSettings.PlotRect: TRect;
begin
  Result := WaveformPaintBox.ClientRect;
  InflateRect(Result, -12, -18);
  Dec(Result.Bottom, 54);
end;

function TFormLyricsManualSyncSettings.SecondsToX(Value: Double): Integer;
var
  R: TRect;
begin
  R := PlotRect;
  Result := R.Left + Round((Value - FViewStartSeconds) /
    Max(0.001, FDisplaySeconds) * R.Width);
end;

function TFormLyricsManualSyncSettings.XToSeconds(Value: Integer): Double;
var
  R: TRect;
begin
  R := PlotRect;
  Result := EnsureRange(FViewStartSeconds +
    EnsureRange((Value - R.Left) / Max(1, R.Width), 0.0, 1.0) *
    FDisplaySeconds, 0.0, FAudioDurationSeconds);
end;

procedure TFormLyricsManualSyncSettings.FormMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
var
  ClientPoint: TPoint;
  CursorRatio: Double;
  CursorSeconds: Double;
  MaximumDisplaySeconds: Double;
  MaxViewStart: Double;
  MinimumDisplaySeconds: Double;
  NewDisplaySeconds: Double;
  R: TRect;
  WheelSteps: Double;
begin
  ClientPoint := WaveformPaintBox.ScreenToClient(MousePos);
  if not PtInRect(WaveformPaintBox.ClientRect, ClientPoint) then
    Exit;
  R := PlotRect;
  if R.Width <= 0 then
    Exit;
  WheelSteps := WheelDelta / 120;
  MaximumDisplaySeconds := Min(MAX_DISPLAY_SECONDS,
    Max(0.001, FAudioDurationSeconds));
  MinimumDisplaySeconds := Min(MIN_DISPLAY_SECONDS,
    MaximumDisplaySeconds);
  if ssShift in Shift then
  begin
    MaxViewStart := Max(0.0,
      FAudioDurationSeconds - FDisplaySeconds);
    FViewStartSeconds := EnsureRange(FViewStartSeconds -
      WheelSteps * FDisplaySeconds * 0.25, 0.0, MaxViewStart);
  end
  else
  begin
    CursorRatio := EnsureRange((ClientPoint.X - R.Left) /
      Max(1, R.Width), 0.0, 1.0);
    CursorSeconds := FViewStartSeconds +
      CursorRatio * FDisplaySeconds;
    if WheelDelta > 0 then
      NewDisplaySeconds := FDisplaySeconds * 0.8
    else
      NewDisplaySeconds := FDisplaySeconds * 1.25;
    NewDisplaySeconds := EnsureRange(NewDisplaySeconds,
      MinimumDisplaySeconds, MaximumDisplaySeconds);
    MaxViewStart := Max(0.0,
      FAudioDurationSeconds - NewDisplaySeconds);
    FViewStartSeconds := EnsureRange(
      CursorSeconds - CursorRatio * NewDisplaySeconds,
      0.0, MaxViewStart);
    FDisplaySeconds := NewDisplaySeconds;
  end;
  Handled := True;
  WaveformPaintBox.Invalidate;
end;

procedure TFormLyricsManualSyncSettings.RefreshModeDisplay;
begin
  AdjustModeButton.Enabled := FInputMode <> 0;
  TimingModeButton.Enabled := FInputMode <> 1;
  RearmButton.Enabled := FInputMode = 1;
end;

procedure TFormLyricsManualSyncSettings.RefreshSyncStatus;
begin
  if Length(FLyricsLabels) = 0 then
    StatusLabel.Caption := '同期する歌詞を入力してください。'
  else if FInputMode = 0 then
    StatusLabel.Caption := Format('調整モード：同期線をドラッグ（%d / %d）',
      [FEditModel.BoundaryCount, Length(FLyricsLabels) + 1])
  else if not FEditModel.TimingInputStarted then
    StatusLabel.Caption :=
      'タイミング入力：再生中の最初のSpaceで既存位置をクリアします。'
  else
    StatusLabel.Caption := Format(
      'タイミング入力：%d / %d位置を入力済み',
      [FEditModel.BoundaryCount, Length(FLyricsLabels) + 1]);
end;

procedure TFormLyricsManualSyncSettings.SetPlaybackPosition(Value: Double);
begin
  FPlaybackPositionSeconds := EnsureRange(Value, 0.0,
    FAudioDurationSeconds);
  PlaybackPositionLabel.Caption := Format('%.3f / %.3f 秒',
    [FPlaybackPositionSeconds, FAudioDurationSeconds],
    TFormatSettings.Invariant);
  WaveformPaintBox.Invalidate;
end;

procedure TFormLyricsManualSyncSettings.AdjustModeButtonClick(
  Sender: TObject);
begin
  FInputMode := 0;
  RefreshModeDisplay;
  RefreshSyncStatus;
end;

procedure TFormLyricsManualSyncSettings.TimingModeButtonClick(
  Sender: TObject);
begin
  FInputMode := 1;
  RefreshModeDisplay;
  RefreshSyncStatus;
end;

procedure TFormLyricsManualSyncSettings.RearmButtonClick(Sender: TObject);
begin
  FEditModel.RearmTimingInput;
  RefreshSyncStatus;
end;

procedure TFormLyricsManualSyncSettings.LyricsMemoChange(Sender: TObject);
var
  PreviousCount: Integer;
begin
  PreviousCount := Length(FLyricsLabels);
  BuildLyricsLabels;
  if (FEditModel <> nil) and
    (PreviousCount <> Length(FLyricsLabels)) then
    FEditModel.Initialize(Length(FLyricsLabels),
      FAudioDurationSeconds, '', FDisplaySeconds);
  WaveformPaintBox.Invalidate;
  if FEditModel <> nil then
    RefreshSyncStatus;
end;

procedure TFormLyricsManualSyncSettings.ApplyButtonClick(Sender: TObject);
begin
  if Length(FLyricsLabels) = 0 then
  begin
    MessageDlg('同期する歌詞を入力してください。',
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if not FEditModel.Complete then
  begin
    MessageDlg(Format('同期位置が不足しています（%d / %d）。',
      [FEditModel.BoundaryCount, Length(FLyricsLabels) + 1]),
      mtWarning, [mbOK], 0);
    Exit;
  end;
  ModalResult := mrOk;
end;

procedure TFormLyricsManualSyncSettings.FormKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
begin
  if ActiveControl = LyricsMemo then
    Exit;
  if (Key = Ord('P')) and (Shift = []) then
  begin
    PlayButtonClick(PlayButton);
    Key := 0;
  end
  else if (Key = Ord('S')) and (Shift = []) then
  begin
    RateComboBox.ItemIndex :=
      (RateComboBox.ItemIndex + 1) mod RateComboBox.Items.Count;
    RateComboBoxChange(RateComboBox);
    Key := 0;
  end
  else if (Key = VK_SPACE) and (Shift = []) and
    (FInputMode = 1) and (FAudioPlayer <> nil) and
    FAudioPlayer.IsPlaying then
  begin
    if FEditModel.AddTimingBoundary(FPlaybackPositionSeconds) then
    begin
      RefreshSyncStatus;
      WaveformPaintBox.Invalidate;
    end
    else
      MessageBeep(MB_ICONWARNING);
    Key := 0;
  end;
end;

procedure TFormLyricsManualSyncSettings.WaveformPaintBoxMouseDown(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var
  I: Integer;
  R: TRect;
begin
  if Button <> mbLeft then
    Exit;
  R := PlotRect;
  if (Y >= R.Top) and (Y <= R.Bottom) and
    (Abs(X - SecondsToX(FPlaybackPositionSeconds)) <= 7) then
  begin
    StopPlayback;
    FDraggingPlayback := True;
    TCapturePaintBox(WaveformPaintBox).MouseCapture := True;
    SetPlaybackPosition(XToSeconds(X));
    WaveformPaintBox.Cursor := crHSplit;
    Exit;
  end;
  FDraggingBoundary := -1;
  if FInputMode = 0 then
    for I := 0 to FEditModel.BoundaryCount - 1 do
      if Abs(X - SecondsToX(FEditModel.BoundarySeconds(I))) <= 6 then
      begin
        FDraggingBoundary := I;
        TCapturePaintBox(WaveformPaintBox).MouseCapture := True;
        WaveformPaintBox.Cursor := crHSplit;
        Exit;
      end;
  // 既存のドラッグ対象がない場所では時間軸そのものをつかむ。
  StopPlayback;
  FDraggingView := True;
  FViewDragStartX := X;
  FViewDragStartSeconds := FViewStartSeconds;
  TCapturePaintBox(WaveformPaintBox).MouseCapture := True;
  WaveformPaintBox.Cursor := crSizeWE;
end;

procedure TFormLyricsManualSyncSettings.WaveformPaintBoxMouseMove(
  Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  if FDraggingView then
  begin
    FViewStartSeconds := EnsureRange(FViewDragStartSeconds -
      (X - FViewDragStartX) / Max(1, PlotRect.Width) *
      FDisplaySeconds, 0.0,
      Max(0.0, FAudioDurationSeconds - FDisplaySeconds));
    WaveformPaintBox.Cursor := crSizeWE;
    WaveformPaintBox.Invalidate;
    Exit;
  end;
  if FDraggingPlayback then
  begin
    SetPlaybackPosition(XToSeconds(X));
    WaveformPaintBox.Cursor := crHSplit;
    Exit;
  end;
  if FDraggingBoundary >= 0 then
  begin
    FEditModel.MoveBoundary(FDraggingBoundary, XToSeconds(X));
    WaveformPaintBox.Invalidate;
    Exit;
  end;
  WaveformPaintBox.Cursor := crDefault;
  if FInputMode = 0 then
    for I := 0 to FEditModel.BoundaryCount - 1 do
      if Abs(X - SecondsToX(FEditModel.BoundarySeconds(I))) <= 6 then
      begin
        WaveformPaintBox.Cursor := crHSplit;
        Break;
      end;
  if WaveformPaintBox.Cursor = crDefault then
    WaveformPaintBox.Cursor := crSizeWE;
end;

procedure TFormLyricsManualSyncSettings.WaveformPaintBoxMouseUp(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  FDraggingBoundary := -1;
  FDraggingPlayback := False;
  FDraggingView := False;
  TCapturePaintBox(WaveformPaintBox).MouseCapture := False;
end;

function TFormLyricsManualSyncSettings.SelectedPlaybackRate: Double;
begin
  case RateComboBox.ItemIndex of
    1: Result := 0.5;
    2: Result := 0.25;
  else
    Result := 1.0;
  end;
end;

procedure TFormLyricsManualSyncSettings.StartPlayback;
var
  ErrorMessage: string;
begin
  if (FAudioPlayer = nil) or (FAudioFileName = '') then
    Exit;
  if FPlaybackPositionSeconds >= FAudioDurationSeconds - 0.001 then
    FPlaybackPositionSeconds := 0;
  if not FAudioPlayer.Start(FAudioFileName, SelectedPlaybackRate,
    FPlaybackPositionSeconds, ErrorMessage) then
  begin
    StatusLabel.Caption := '再生を開始できません: ' + ErrorMessage;
    MessageDlg(StatusLabel.Caption, mtError, [mbOK], 0);
    Exit;
  end;
  PlayButton.Caption := '一時停止';
  PlaybackTimer.Enabled := True;
  StatusLabel.Caption := Format('再生中（%.2f 倍速）',
    [SelectedPlaybackRate], TFormatSettings.Invariant);
  WaveformPaintBox.Invalidate;
end;

procedure TFormLyricsManualSyncSettings.StopPlayback;
begin
  PlaybackTimer.Enabled := False;
  if FAudioPlayer <> nil then
  begin
    if FAudioPlayer.IsPlaying then
      FPlaybackPositionSeconds := Min(FAudioDurationSeconds,
        FAudioPlayer.PositionSeconds);
    FAudioPlayer.Stop;
  end;
  PlayButton.Caption := '再生';
  WaveformPaintBox.Invalidate;
end;

procedure TFormLyricsManualSyncSettings.PlayButtonClick(Sender: TObject);
begin
  if (FAudioPlayer <> nil) and FAudioPlayer.IsPlaying then
  begin
    StopPlayback;
    StatusLabel.Caption := '一時停止しました。';
  end
  else
    StartPlayback;
end;

procedure TFormLyricsManualSyncSettings.StopButtonClick(Sender: TObject);
begin
  StopPlayback;
  FViewStartSeconds := 0;
  SetPlaybackPosition(0);
  StatusLabel.Caption := '停止して先頭へ戻しました。';
end;

procedure TFormLyricsManualSyncSettings.RateComboBoxChange(Sender: TObject);
begin
  if (FAudioPlayer <> nil) and FAudioPlayer.IsPlaying then
  begin
    StopPlayback;
    StartPlayback;
  end;
end;

procedure TFormLyricsManualSyncSettings.PlaybackTimerTimer(Sender: TObject);
var
  PlaybackError: string;
begin
  if FAudioPlayer = nil then
    Exit;
  FPlaybackPositionSeconds := Min(FAudioDurationSeconds,
    FAudioPlayer.PositionSeconds);
  if FPlaybackPositionSeconds < FViewStartSeconds then
    FViewStartSeconds := Max(0.0, FPlaybackPositionSeconds)
  else if FPlaybackPositionSeconds >
    FViewStartSeconds + FDisplaySeconds then
    FViewStartSeconds := EnsureRange(
      FPlaybackPositionSeconds - FDisplaySeconds * 0.1,
      0.0, Max(0.0, FAudioDurationSeconds - FDisplaySeconds));
  PlaybackPositionLabel.Caption := Format('%.3f / %.3f 秒',
    [FPlaybackPositionSeconds, FAudioDurationSeconds],
    TFormatSettings.Invariant);
  WaveformPaintBox.Invalidate;
  if not FAudioPlayer.IsPlaying then
  begin
    PlaybackTimer.Enabled := False;
    PlayButton.Caption := '再生';
    PlaybackError := FAudioPlayer.ErrorMessage;
    if PlaybackError <> '' then
      StatusLabel.Caption := '再生エラー: ' + PlaybackError
    else if LoopCheckBox.Checked then
    begin
      FPlaybackPositionSeconds := 0;
      FViewStartSeconds := 0;
      StartPlayback;
      Exit;
    end
    else
    begin
      FPlaybackPositionSeconds := FAudioDurationSeconds;
      PlaybackPositionLabel.Caption := Format('%.3f / %.3f 秒',
        [FAudioDurationSeconds, FAudioDurationSeconds],
        TFormatSettings.Invariant);
      WaveformPaintBox.Invalidate;
      StatusLabel.Caption := '再生が終了しました。';
    end;
  end;
end;

procedure TFormLyricsManualSyncSettings.WaveformPaintBoxPaint(
  Sender: TObject);
var
  Canvas: TCanvas;
  CenterY: Integer;
  EndPoint: Integer;
  EndSeconds: Double;
  I: Integer;
  LabelRect: TRect;
  MaximumValue: Single;
  MinimumValue: Single;
  Peak: Single;
  PlotRect: TRect;
  PointIndex: Integer;
  Scale: Double;
  StartPoint: Integer;
  StartSeconds: Double;
  TextValue: string;
  X: Integer;
  YMaximum: Integer;
  YMinimum: Integer;
  PlaybackX: Integer;
begin
  Canvas := WaveformPaintBox.Canvas;
  Canvas.Brush.Color := RGB(24, 28, 36);
  Canvas.FillRect(WaveformPaintBox.ClientRect);
  PlotRect := Self.PlotRect;
  if (PlotRect.Right <= PlotRect.Left) or
    (PlotRect.Bottom <= PlotRect.Top) then
    Exit;

  CenterY := (PlotRect.Top + PlotRect.Bottom) div 2;
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := RGB(66, 74, 88);
  Canvas.MoveTo(PlotRect.Left, CenterY);
  Canvas.LineTo(PlotRect.Right, CenterY);
  for I := 0 to 4 do
  begin
    X := PlotRect.Left + MulDiv(I,
      PlotRect.Right - PlotRect.Left, 4);
    Canvas.Pen.Color := RGB(48, 54, 66);
    Canvas.MoveTo(X, PlotRect.Top);
    Canvas.LineTo(X, PlotRect.Bottom);
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -12;
    Canvas.Font.Color := RGB(150, 160, 178);
    Canvas.Brush.Style := bsClear;
    TextValue := Format('%.2f',
      [FViewStartSeconds + FDisplaySeconds * I / 4],
      TFormatSettings.Invariant);
    Canvas.TextOut(X - Canvas.TextWidth(TextValue) div 2,
      PlotRect.Bottom + 5, TextValue);
  end;

  if Length(FWaveform) = 0 then
  begin
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -14;
    Canvas.Font.Color := RGB(210, 215, 224);
    Canvas.Brush.Style := bsClear;
    if FWaveformMessage = '' then
      FWaveformMessage := '波形データがありません。';
    Canvas.TextOut(PlotRect.Left +
      (PlotRect.Width - Canvas.TextWidth(FWaveformMessage)) div 2,
      CenterY - Canvas.TextHeight(FWaveformMessage) div 2,
      FWaveformMessage);
    Canvas.Brush.Style := bsSolid;
    Exit;
  end;

  Peak := 0;
  for PointIndex := 0 to High(FWaveform) do
    Peak := Max(Peak, Max(Abs(FWaveform[PointIndex].Minimum),
      Abs(FWaveform[PointIndex].Maximum)));
  if Peak <= 0.000001 then
    Scale := 1
  else
    Scale := 0.9 / Peak;
  Canvas.Pen.Color := RGB(72, 190, 225);
  Canvas.Pen.Width := 1;
  for X := PlotRect.Left to PlotRect.Right - 1 do
  begin
    StartSeconds := FViewStartSeconds +
      (X - PlotRect.Left) / Max(1, PlotRect.Width) * FDisplaySeconds;
    EndSeconds := FViewStartSeconds +
      (X - PlotRect.Left + 1) / Max(1, PlotRect.Width) *
      FDisplaySeconds;
    StartPoint := Floor(StartSeconds /
      Max(0.001, FAudioDurationSeconds) * Length(FWaveform));
    EndPoint := Ceil(EndSeconds /
      Max(0.001, FAudioDurationSeconds) * Length(FWaveform));
    StartPoint := EnsureRange(StartPoint, 0, Length(FWaveform) - 1);
    if EndPoint <= StartPoint then
      EndPoint := StartPoint + 1;
    EndPoint := Min(Length(FWaveform), EndPoint);
    MinimumValue := 1;
    MaximumValue := -1;
    for PointIndex := StartPoint to EndPoint - 1 do
    begin
      MinimumValue := Min(MinimumValue,
        FWaveform[PointIndex].Minimum);
      MaximumValue := Max(MaximumValue,
        FWaveform[PointIndex].Maximum);
    end;
    YMinimum := CenterY - Round(MinimumValue * Scale *
      (PlotRect.Height div 2));
    YMaximum := CenterY - Round(MaximumValue * Scale *
      (PlotRect.Height div 2));
    Canvas.MoveTo(X, YMaximum);
    Canvas.LineTo(X, YMinimum + 1);
  end;

  // 完了した各区間だけを、右端が矢印になった歌詞枠で表示する。
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Height := -14;
  for I := 0 to Min(High(FLyricsLabels),
    FEditModel.BoundaryCount - 2) do
  begin
    if (FEditModel.BoundarySeconds(I + 1) < FViewStartSeconds) or
      (FEditModel.BoundarySeconds(I) >
      FViewStartSeconds + FDisplaySeconds) then
      Continue;
    LabelRect := Rect(
      Max(PlotRect.Left,
        SecondsToX(FEditModel.BoundarySeconds(I))),
      PlotRect.Bottom + 12,
      Min(PlotRect.Right,
        SecondsToX(FEditModel.BoundarySeconds(I + 1))),
      PlotRect.Bottom + 38);
    Canvas.Brush.Color := RGB(42, 92, 118);
    Canvas.Pen.Color := RGB(93, 205, 235);
    Canvas.Polygon([
      Point(LabelRect.Left, LabelRect.Top),
      Point(Max(LabelRect.Left, LabelRect.Right - 8), LabelRect.Top),
      Point(LabelRect.Right, (LabelRect.Top + LabelRect.Bottom) div 2),
      Point(Max(LabelRect.Left, LabelRect.Right - 8), LabelRect.Bottom),
      Point(LabelRect.Left, LabelRect.Bottom)]);
    Canvas.Font.Color := clWhite;
    Canvas.Brush.Style := bsClear;
    InflateRect(LabelRect, -4, -3);
    Dec(LabelRect.Right, 6);
    Canvas.TextRect(LabelRect, FLyricsLabels[I],
      [tfSingleLine, tfVerticalCenter, tfEndEllipsis]);
    Canvas.Brush.Style := bsSolid;
  end;

  // 同期境界は歌詞枠より手前へ描き、ドラッグ対象を明確にする。
  Canvas.Pen.Color := RGB(235, 112, 164);
  Canvas.Pen.Width := 1;
  for I := 0 to FEditModel.BoundaryCount - 1 do
  begin
    if (FEditModel.BoundarySeconds(I) < FViewStartSeconds) or
      (FEditModel.BoundarySeconds(I) >
      FViewStartSeconds + FDisplaySeconds) then
      Continue;
    X := SecondsToX(FEditModel.BoundarySeconds(I));
    Canvas.MoveTo(X, PlotRect.Top);
    Canvas.LineTo(X, PlotRect.Bottom + 42);
  end;
  if (FAudioDurationSeconds > 0) and
    (FPlaybackPositionSeconds >= FViewStartSeconds) and
    (FPlaybackPositionSeconds <=
      FViewStartSeconds + FDisplaySeconds) then
  begin
    PlaybackX := SecondsToX(FPlaybackPositionSeconds);
    Canvas.Pen.Color := RGB(255, 204, 64);
    Canvas.Pen.Width := 2;
    Canvas.MoveTo(PlaybackX, PlotRect.Top);
    Canvas.LineTo(PlaybackX, PlotRect.Bottom);
    Canvas.Brush.Color := RGB(255, 204, 64);
    Canvas.Polygon([
      Point(PlaybackX - 5, PlotRect.Top),
      Point(PlaybackX + 5, PlotRect.Top),
      Point(PlaybackX, PlotRect.Top + 7)]);
  end;
  Canvas.Brush.Style := bsSolid;
end;

end.
