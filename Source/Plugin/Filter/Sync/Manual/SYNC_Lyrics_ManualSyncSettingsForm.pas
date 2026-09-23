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
  SYNC_Lyrics_ManualSyncEditModel,
  SYNC_Lyrics_ManualSyncWaveform,
  SYNC_Lyrics_SyncFormat;

type
  // 曲全体の各行から手動同期画面へ渡す歌詞本文と保存済み同期位置。
  TManualSyncLineSource = record
    LyricsText: string; // ルビ構文を含む元の歌詞。
    SyncText: string; // SLD1に保存するその行の同期文字列。
  end;
  TManualSyncLineSources = array of TManualSyncLineSource;

  // 波形上で別行が選択されたとき、曲全体のゼロ始まり行番号を通知する。
  TManualSyncLineSelectedEvent = procedure(Sender: TObject; LineIndex: Integer) of object;

  TFormLyricsManualSyncSettings = class(TForm)
    FileValueLabel: TLabel;
    PlaybackPositionLabel: TLabel;
    PlayButton: TButton;
    RateComboBox: TComboBox;
    LoopCheckBox: TCheckBox;
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
    procedure PlaybackTimerTimer(Sender: TObject);
    procedure RateComboBoxChange(Sender: TObject);
    procedure RateComboBoxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
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
    FDraggingSuffixIndex: Integer;
    FLineDragStartX: Integer;
    FLineDragStartSeconds: Double;
    FDraggingPlayback: Boolean;
    FDraggingView: Boolean;
    FViewDragStartSeconds: Double;
    FViewDragStartX: Integer;
    FDisplaySeconds: Double;
    FEditModel: TManualSyncEditModel;
    FDisplayLines: TArray<TManualSyncDisplayLine>;
    FLyricsLabels: TArray<string>;
    FSelectedLineIndex: Integer;
    FPlaybackPositionSeconds: Double;
    FViewStartSeconds: Double;
    FWaveform: TSyncAudioWaveform;
    FWaveformMessage: string;
    FEmbeddedMode: Boolean;
    FLoading: Boolean;
    FOnSyncChanged: TNotifyEvent;
    FOnLineSelected: TManualSyncLineSelectedEvent;
    function SelectedPlaybackRate: Double;
    function ScaleWaveformMetric(Value: Integer): Integer;
    procedure BuildLyricsLabels;
    function HitTestLyricsLine(const Line: TManualSyncDisplayLine;
      X: Integer; out UnitIndex: Integer; out OnEdge: Boolean): Boolean;
    function HitTestSelectedLyrics(X, Y: Integer;
      out OnEdge: Boolean): Integer;
    function HitTestOtherLyrics(X, Y: Integer;
      out OnEdge: Boolean): Integer;
    function IsInLyricsLane(X, Y: Integer): Boolean;
    function PlotRect: TRect;
    function SecondsToX(Value: Double): Integer;
    function XToSeconds(Value: Integer): Double;
    procedure RefreshSyncStatus;
    procedure SetPlaybackPosition(Value: Double);
    procedure KeepPlaybackCursorInView;
    procedure StartPlayback;
    procedure StopPlayback;
    procedure NotifySyncChanged;
    procedure UpdateEmbeddedLayout;
    procedure UpdateWaveformCursor(X, Y: Integer);
  protected
    procedure Resize; override;
  public
    // 埋め込み・単体表示で使うコントロールの色と描画方法を設定する。
    procedure ApplyDarkTheme;
    // 曲全体編集フォーム内へ埋め込み、単体表示用の入力欄と確定ボタンを隠す。
    procedure ConfigureEmbedded;
    // 対象WAVと選択行を読み込む。同じ音声なら再生位置と再生状態を保つ。
    procedure LoadSettings(const FileName: string; const AudioInfo: TSyncAudioFileInfo;
      const Lyrics, SyncText: string);
    // 全行の表示位置を更新する。選択行の境界編集状態は保持する。
    procedure SetSongLines(const Lines: TManualSyncLineSources; SelectedIndex: Integer);
    // 選択行の境界を既定位置へ戻し、変更通知を発火する。
    procedure ResetSync;
    // 現在の入力欄にあるルビ構文付き歌詞を返す。
    function LyricsText: string;
    // 現在の境界を同期文字列へ変換して返す。
    function SyncText: string;
    // 境界が揃った場合だけ同期文字列を返す。
    function TryGetSyncText(out Value: string): Boolean;
    property OnSyncChanged: TNotifyEvent read FOnSyncChanged
      write FOnSyncChanged;
    property OnLineSelected: TManualSyncLineSelectedEvent
      read FOnLineSelected write FOnLineSelected;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  SYNC_Lyrics_DarkTheme,
  SYNC_Lyrics_LyricParser,
  Vcl.Dialogs,
  Winapi.Windows;

{$R *.dfm}

const
  INITIAL_DISPLAY_SECONDS = 10.0;
  MAX_DISPLAY_SECONDS = 60.0;
  MIN_DISPLAY_SECONDS = 1.0;
  WAVEFORM_BASE_DPI = 96;

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
  FDraggingSuffixIndex := -1;
  FSelectedLineIndex := -1;
  FDraggingPlayback := False;
  FDraggingView := False;
  FDisplaySeconds := INITIAL_DISPLAY_SECONDS;
  FViewStartSeconds := 0;
  RateComboBox.ItemIndex := 0;
  ApplyDarkTheme;
end;

procedure TFormLyricsManualSyncSettings.ApplyDarkTheme;
begin
  ApplySyncLyricsDarkForm(Self);
  FileValueLabel.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  PlaybackPositionLabel.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  LyricsCaptionLabel.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  StatusLabel.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  ApplySyncLyricsDarkButton(PlayButton);
  ApplySyncLyricsDarkComboBox(RateComboBox, RateComboBoxDrawItem);
  LoopCheckBox.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  ApplySyncLyricsDarkMemo(LyricsMemo);
  ApplySyncLyricsDarkButton(ApplyButton);
  ApplySyncLyricsDarkButton(CancelButton);
end;

procedure TFormLyricsManualSyncSettings.RateComboBoxDrawItem(
  Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
begin
  DrawSyncLyricsDarkComboBoxItem(RateComboBox, Index, Rect,
    State, CurrentPPI);
end;

procedure TFormLyricsManualSyncSettings.ConfigureEmbedded;
begin
  FEmbeddedMode := True;
  BorderStyle := bsNone;
  LyricsCaptionLabel.Visible := False;
  LyricsMemo.Visible := False;
  ApplyButton.Visible := False;
  CancelButton.Visible := False;
  UpdateEmbeddedLayout;
end;

procedure TFormLyricsManualSyncSettings.UpdateEmbeddedLayout;
var
  ControlLeft: Integer;
  ControlTop: Integer;
  Gap: Integer;
  Margin: Integer;
  StatusHeight: Integer;
  TopPosition: Integer;
begin
  if not FEmbeddedMode then
    Exit;
  Margin := ScaleWaveformMetric(12);
  StatusHeight := ScaleWaveformMetric(24);
  TopPosition := ScaleWaveformMetric(82);
  Gap := ScaleWaveformMetric(4);
  ControlTop := ScaleWaveformMetric(52);
  PlaybackPositionLabel.SetBounds(
    Max(Margin, ClientWidth - Margin - ScaleWaveformMetric(150)),
    ScaleWaveformMetric(10), ScaleWaveformMetric(150),
    ScaleWaveformMetric(20));
  FileValueLabel.SetBounds(Margin, ScaleWaveformMetric(10),
    Max(1, PlaybackPositionLabel.Left - Margin * 2),
    ScaleWaveformMetric(20));
  ControlLeft := Margin;
  PlayButton.SetBounds(ControlLeft, ControlTop,
    ScaleWaveformMetric(60), ScaleWaveformMetric(27));
  Inc(ControlLeft, PlayButton.Width + Gap);
  RateComboBox.SetBounds(ControlLeft, ControlTop + ScaleWaveformMetric(2),
    ScaleWaveformMetric(76), ScaleWaveformMetric(23));
  Inc(ControlLeft, RateComboBox.Width + Gap);
  LoopCheckBox.SetBounds(ControlLeft, ControlTop + ScaleWaveformMetric(4),
    ScaleWaveformMetric(64), ScaleWaveformMetric(20));
  WaveformPaintBox.SetBounds(Margin, TopPosition,
    Max(1, ClientWidth - Margin * 2),
    Max(1, ClientHeight - TopPosition - StatusHeight - Margin));
  StatusLabel.SetBounds(Margin, ClientHeight - StatusHeight,
    Max(1, ClientWidth - Margin * 2), StatusHeight);
end;

procedure TFormLyricsManualSyncSettings.Resize;
begin
  inherited Resize;
  UpdateEmbeddedLayout;
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
  SourceChanged: Boolean;
  ReloadWaveform: Boolean;
  WaveformError: string;
begin
  FLoading := True;
  try
  SourceChanged := not SameText(FAudioFileName, FileName);
  if SourceChanged then
    StopPlayback;
  ReloadWaveform := SourceChanged or
    (Length(FWaveform) = 0);
  FAudioFileName := FileName;
  FAudioDurationSeconds := AudioInfo.DurationSeconds;
  if SourceChanged then
  begin
    FDisplaySeconds := Min(INITIAL_DISPLAY_SECONDS,
      Max(0.001, FAudioDurationSeconds));
    FViewStartSeconds := 0;
    FPlaybackPositionSeconds := 0;
  end;
  FPlaybackPositionSeconds := EnsureRange(FPlaybackPositionSeconds,
    0.0, FAudioDurationSeconds);
  PlaybackPositionLabel.Caption := Format('%.3f / %.3f 秒',
    [FPlaybackPositionSeconds, FAudioDurationSeconds],
    TFormatSettings.Invariant);
  FileValueLabel.Caption := ExtractFileName(FileName);
  FileValueLabel.Hint := FileName;
  LyricsMemo.Text := Lyrics;
  BuildLyricsLabels;
  FEditModel.Initialize(Length(FLyricsLabels),
    FAudioDurationSeconds, SyncText, FDisplaySeconds);
  if SourceChanged and FEditModel.Complete then
    FDisplaySeconds := Min(Min(MAX_DISPLAY_SECONDS,
      Max(0.001, FAudioDurationSeconds)),
      Max(FDisplaySeconds,
        (FEditModel.BoundarySeconds(FEditModel.BoundaryCount - 1) -
         FEditModel.BoundarySeconds(0)) * 1.15));
  if (FEditModel.BoundaryCount > 0) and
    (SourceChanged or not FAudioPlayer.IsPlaying) then
    FViewStartSeconds := EnsureRange(
      FEditModel.BoundarySeconds(0) - FDisplaySeconds * 0.1,
      0.0, Max(0.0, FAudioDurationSeconds - FDisplaySeconds));
  if ReloadWaveform then
  begin
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
  end;
  WaveformPaintBox.Invalidate;
  RefreshSyncStatus;
  finally
    FLoading := False;
  end;
end;

procedure TFormLyricsManualSyncSettings.BuildLyricsLabels;
begin
  FLyricsLabels := BuildLyricsSyncUnitLabels(LyricsMemo.Text);
end;

procedure TFormLyricsManualSyncSettings.SetSongLines(
  const Lines: TManualSyncLineSources; SelectedIndex: Integer);
var
  Data: TSyncTextData;
  I: Integer;
begin
  FSelectedLineIndex := SelectedIndex;
  SetLength(FDisplayLines, 0);
  SetLength(FDisplayLines, Length(Lines));
  for I := 0 to High(Lines) do
  begin
    FDisplayLines[I].Labels :=
      BuildLyricsSyncUnitLabels(Lines[I].LyricsText);
    if TryParseSyncText(Lines[I].SyncText, Data) and
      (Data.Mode = smManual) and
      (Length(Data.ManualBoundaries) =
        Length(FDisplayLines[I].Labels) + 1) then
      FDisplayLines[I].Boundaries := Copy(Data.ManualBoundaries)
    else
      SetLength(FDisplayLines[I].Boundaries, 0);
  end;
  WaveformPaintBox.Invalidate;
end;

function TFormLyricsManualSyncSettings.LyricsText: string;
begin
  Result := LyricsMemo.Text;
end;

function TFormLyricsManualSyncSettings.SyncText: string;
begin
  Result := FEditModel.SerializeSyncText;
end;

function TFormLyricsManualSyncSettings.TryGetSyncText(
  out Value: string): Boolean;
begin
  Result := (FEditModel <> nil) and FEditModel.Complete;
  if Result then
    Value := FEditModel.SerializeSyncText
  else
    Value := '';
end;

procedure TFormLyricsManualSyncSettings.NotifySyncChanged;
begin
  if not FLoading and Assigned(FOnSyncChanged) then
    FOnSyncChanged(Self);
end;

procedure TFormLyricsManualSyncSettings.ResetSync;
begin
  StopPlayback;
  FEditModel.Initialize(Length(FLyricsLabels),
    FAudioDurationSeconds, '', FDisplaySeconds);
  RefreshSyncStatus;
  WaveformPaintBox.Invalidate;
  NotifySyncChanged;
end;

function TFormLyricsManualSyncSettings.PlotRect: TRect;
begin
  Result := WaveformPaintBox.ClientRect;
  InflateRect(Result, -ScaleWaveformMetric(12),
    -ScaleWaveformMetric(18));
  Dec(Result.Bottom, ScaleWaveformMetric(54));
end;

function TFormLyricsManualSyncSettings.ScaleWaveformMetric(
  Value: Integer): Integer;
begin
  Result := MulDiv(Value, Max(1, CurrentPPI), WAVEFORM_BASE_DPI);
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
  KeepPlaybackCursorInView;
  WaveformPaintBox.Invalidate;
end;

procedure TFormLyricsManualSyncSettings.RefreshSyncStatus;
begin
  if Length(FLyricsLabels) = 0 then
    StatusLabel.Caption := '同期する歌詞を入力してください。'
  else
    StatusLabel.Caption := Format('同期線・歌詞枠をドラッグ（%d / %d）',
      [FEditModel.BoundaryCount, Length(FLyricsLabels) + 1]);
end;

function TFormLyricsManualSyncSettings.IsInLyricsLane(
  X, Y: Integer): Boolean;
var
  R: TRect;
begin
  R := PlotRect;
  Result := (Y >= R.Bottom + ScaleWaveformMetric(LYRICS_LANE_TOP_OFFSET)) and
    (Y <= R.Bottom + ScaleWaveformMetric(LYRICS_LANE_BOTTOM_OFFSET)) and
    (X >= R.Left) and (X <= R.Right);
end;

function TFormLyricsManualSyncSettings.HitTestLyricsLine(
  const Line: TManualSyncDisplayLine; X: Integer;
  out UnitIndex: Integer; out OnEdge: Boolean): Boolean;
var
  BoundaryX: Integer;
  Distance: Integer;
  I: Integer;
  NearestDistance: Integer;
  R: TRect;
begin
  Result := False;
  UnitIndex := -1;
  OnEdge := False;
  if (Length(Line.Labels) = 0) or
    (Length(Line.Boundaries) <> Length(Line.Labels) + 1) then
    Exit;
  R := PlotRect;
  if (X < Max(R.Left, SecondsToX(Line.Boundaries[0]))) or
    (X > Min(R.Right, SecondsToX(Line.Boundaries[
      High(Line.Boundaries)]))) then
    Exit;
  // 短い文字枠でも最も近い端を優先する。
  NearestDistance := ScaleWaveformMetric(11) + 1;
  for I := 0 to High(Line.Boundaries) do
  begin
    BoundaryX := SecondsToX(Line.Boundaries[I]);
    if (BoundaryX < R.Left) or (BoundaryX > R.Right) then
      Continue;
    Distance := Abs(X - BoundaryX);
    if Distance < NearestDistance then
    begin
      NearestDistance := Distance;
      UnitIndex := I;
      OnEdge := True;
      Result := True;
    end;
  end;
  if Result then
    Exit;
  for I := 0 to High(Line.Labels) do
    if (X >= Max(R.Left, SecondsToX(Line.Boundaries[I]))) and
      (X < Min(R.Right, SecondsToX(Line.Boundaries[I + 1]))) then
    begin
      UnitIndex := I;
      Exit(True);
    end;
end;

function TFormLyricsManualSyncSettings.HitTestSelectedLyrics(
  X, Y: Integer; out OnEdge: Boolean): Integer;
var
  I: Integer;
  Line: TManualSyncDisplayLine;
begin
  Result := -1;
  OnEdge := False;
  if not IsInLyricsLane(X, Y) or not FEditModel.Complete then
    Exit;
  Line.Labels := FLyricsLabels;
  SetLength(Line.Boundaries, FEditModel.BoundaryCount);
  for I := 0 to FEditModel.BoundaryCount - 1 do
    Line.Boundaries[I] := FEditModel.BoundarySeconds(I);
  HitTestLyricsLine(Line, X, Result, OnEdge);
end;

function TFormLyricsManualSyncSettings.HitTestOtherLyrics(
  X, Y: Integer; out OnEdge: Boolean): Integer;
var
  I: Integer;
  UnitIndex: Integer;
begin
  Result := -1;
  OnEdge := False;
  if not IsInLyricsLane(X, Y) then
    Exit;
  for I := High(FDisplayLines) downto 0 do
    if (I <> FSelectedLineIndex) and
      HitTestLyricsLine(FDisplayLines[I], X, UnitIndex, OnEdge) then
      Exit(I);
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
  NotifySyncChanged;
end;

procedure TFormLyricsManualSyncSettings.KeepPlaybackCursorInView;
var
  EdgeMarginSeconds: Double;
begin
  if (FAudioPlayer <> nil) and FAudioPlayer.IsPlaying then
    Exit;
  EdgeMarginSeconds := FDisplaySeconds * ScaleWaveformMetric(6) /
    Max(1, PlotRect.Width);
  if FPlaybackPositionSeconds < FViewStartSeconds then
    SetPlaybackPosition(Min(FAudioDurationSeconds,
      FViewStartSeconds + EdgeMarginSeconds))
  else if FPlaybackPositionSeconds >
    FViewStartSeconds + FDisplaySeconds then
    SetPlaybackPosition(Max(0.0, Min(FAudioDurationSeconds,
      FViewStartSeconds + FDisplaySeconds - EdgeMarginSeconds)));
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
  end;
end;

procedure TFormLyricsManualSyncSettings.WaveformPaintBoxMouseDown(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
var
  I: Integer;
  OnEdge: Boolean;
  R: TRect;
begin
  if Button <> mbLeft then
    Exit;
  R := PlotRect;
  if (Y >= R.Top) and (Y <= R.Bottom) and
    (Abs(X - SecondsToX(FPlaybackPositionSeconds)) <=
      ScaleWaveformMetric(7)) then
  begin
    StopPlayback;
    FDraggingPlayback := True;
    TCapturePaintBox(WaveformPaintBox).MouseCapture := True;
    SetPlaybackPosition(XToSeconds(X));
    WaveformPaintBox.Cursor := crHSplit;
    Exit;
  end;
  FDraggingBoundary := -1;
  I := HitTestSelectedLyrics(X, Y, OnEdge);
  if I >= 0 then
  begin
    if I = FEditModel.BoundaryCount - 1 then
      FDraggingBoundary := I
    else
    begin
      FDraggingSuffixIndex := I;
      FLineDragStartX := X;
      FLineDragStartSeconds := FEditModel.BoundarySeconds(I);
    end;
    TCapturePaintBox(WaveformPaintBox).MouseCapture := True;
    if OnEdge then
      WaveformPaintBox.Cursor := crHSplit
    else
      WaveformPaintBox.Cursor := crSizeWE;
    Exit;
  end;
  I := HitTestOtherLyrics(X, Y, OnEdge);
  if I >= 0 then
  begin
    if Assigned(FOnLineSelected) then
      FOnLineSelected(Self, I);
    Exit;
  end;
  if (Y >= R.Top) and (Y <= R.Bottom) then
    for I := 0 to FEditModel.BoundaryCount - 1 do
      if Abs(X - SecondsToX(FEditModel.BoundarySeconds(I))) <=
        ScaleWaveformMetric(6) then
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
begin
  if FDraggingSuffixIndex >= 0 then
  begin
    if FEditModel.MoveSuffix(FDraggingSuffixIndex,
      FLineDragStartSeconds +
      (X - FLineDragStartX) / Max(1, PlotRect.Width) *
      FDisplaySeconds) then
      NotifySyncChanged;
    WaveformPaintBox.Cursor := crSizeWE;
    WaveformPaintBox.Invalidate;
    Exit;
  end;
  if FDraggingView then
  begin
    FViewStartSeconds := EnsureRange(FViewDragStartSeconds -
      (X - FViewDragStartX) / Max(1, PlotRect.Width) *
      FDisplaySeconds, 0.0,
      Max(0.0, FAudioDurationSeconds - FDisplaySeconds));
    KeepPlaybackCursorInView;
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
    if FEditModel.MoveBoundary(FDraggingBoundary, XToSeconds(X)) then
      NotifySyncChanged;
    WaveformPaintBox.Cursor := crHSplit;
    WaveformPaintBox.Invalidate;
    Exit;
  end;
  UpdateWaveformCursor(X, Y);
end;

procedure TFormLyricsManualSyncSettings.WaveformPaintBoxMouseUp(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
  FDraggingBoundary := -1;
  FDraggingSuffixIndex := -1;
  FDraggingPlayback := False;
  FDraggingView := False;
  TCapturePaintBox(WaveformPaintBox).MouseCapture := False;
  UpdateWaveformCursor(X, Y);
end;

procedure TFormLyricsManualSyncSettings.UpdateWaveformCursor(
  X, Y: Integer);
var
  I: Integer;
  OnEdge: Boolean;
  R: TRect;
begin
  if (FDraggingSuffixIndex >= 0) or FDraggingView then
  begin
    WaveformPaintBox.Cursor := crSizeWE;
    Exit;
  end;
  if FDraggingPlayback or (FDraggingBoundary >= 0) then
  begin
    WaveformPaintBox.Cursor := crHSplit;
    Exit;
  end;

  WaveformPaintBox.Cursor := crDefault;
  R := PlotRect;
  I := HitTestSelectedLyrics(X, Y, OnEdge);
  if I >= 0 then
  begin
    if OnEdge then
      WaveformPaintBox.Cursor := crHSplit
    else
      WaveformPaintBox.Cursor := crSizeWE;
    Exit;
  end;
  if HitTestOtherLyrics(X, Y, OnEdge) >= 0 then
  begin
    if OnEdge then
      WaveformPaintBox.Cursor := crHSplit
    else
      WaveformPaintBox.Cursor := crSizeWE;
    Exit;
  end;
  if (Y >= R.Top) and (Y <= R.Bottom) and
    (Abs(X - SecondsToX(FPlaybackPositionSeconds)) <=
      ScaleWaveformMetric(7)) then
  begin
    WaveformPaintBox.Cursor := crHSplit;
    Exit;
  end;
  if (Y >= R.Top) and (Y <= R.Bottom) then
    for I := 0 to FEditModel.BoundaryCount - 1 do
      if Abs(X - SecondsToX(FEditModel.BoundarySeconds(I))) <=
        ScaleWaveformMetric(7) then
      begin
        WaveformPaintBox.Cursor := crHSplit;
        Exit;
      end;
end;

function TFormLyricsManualSyncSettings.SelectedPlaybackRate: Double;
begin
  case RateComboBox.ItemIndex of
    1: Result := 0.75;
    2: Result := 0.5;
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

procedure TFormLyricsManualSyncSettings.WaveformPaintBoxPaint(Sender: TObject);
var
  I: Integer;
  View: TManualSyncWaveformView;
begin
  View.ClientRect := WaveformPaintBox.ClientRect;
  View.PlotRect := PlotRect;
  View.PixelsPerInch := CurrentPPI;
  View.AudioDurationSeconds := FAudioDurationSeconds;
  View.ViewStartSeconds := FViewStartSeconds;
  View.DisplaySeconds := FDisplaySeconds;
  View.PlaybackPositionSeconds := FPlaybackPositionSeconds;
  View.Waveform := FWaveform;
  View.WaveformMessage := FWaveformMessage;
  View.DisplayLines := FDisplayLines;
  View.SelectedLineIndex := FSelectedLineIndex;
  if (FSelectedLineIndex >= 0) and
    (FSelectedLineIndex < Length(FDisplayLines)) and
    (Length(FDisplayLines[FSelectedLineIndex].Labels) =
      FEditModel.UnitCount) then
    View.SelectedLine.Labels := FDisplayLines[FSelectedLineIndex].Labels
  else
    View.SelectedLine.Labels := FLyricsLabels;
  SetLength(View.SelectedLine.Boundaries, FEditModel.BoundaryCount);
  for I := 0 to FEditModel.BoundaryCount - 1 do
    View.SelectedLine.Boundaries[I] := FEditModel.BoundarySeconds(I);
  DrawManualSyncWaveform(WaveformPaintBox.Canvas, View);
end;

end.
