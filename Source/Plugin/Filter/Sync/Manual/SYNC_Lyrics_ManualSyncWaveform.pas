unit SYNC_Lyrics_ManualSyncWaveform;

// WAV手動同期画面の波形・時間目盛り・全行歌詞・再生位置を描画する。

interface

uses
  System.Types,
  Vcl.Graphics,
  SYNC_Lyrics_AudioWaveform,
  SYNC_Lyrics_SyncFormat;

const
  LYRICS_LANE_TOP_OFFSET = 24;
  LYRICS_LANE_BOTTOM_OFFSET = 50;

type
  // 1行の表示単位と各単位の開始・終了時刻。境界数はラベル数より1多い。
  TManualSyncDisplayLine = record
    Labels: TArray<string>; // ルビをひとまとまりにした表示文字。
    Boundaries: TSyncDoubleArray; // WAV先頭からの秒数。
  end;

  // 描画時点の値だけを束ね、再生や編集の状態変更を描画側へ持ち込まない。
  TManualSyncWaveformView = record
    ClientRect: TRect; // ペイントボックス全体。
    PlotRect: TRect; // 波形を描く時間軸領域。
    PixelsPerInch: Integer; // 画面の現在DPI。
    AudioDurationSeconds: Double; // WAV全体の長さ。
    ViewStartSeconds: Double; // 左端のWAV時刻。
    DisplaySeconds: Double; // 画面の時間幅。
    PlaybackPositionSeconds: Double; // 再生または再生開始の位置。
    Waveform: TSyncAudioWaveform; // 音声のmin/max包絡線。
    WaveformMessage: string; // 波形取得に失敗した場合の理由。
    DisplayLines: TArray<TManualSyncDisplayLine>; // 曲内の全行。
    SelectedLineIndex: Integer; // 明るく描画する行番号。
    SelectedLine: TManualSyncDisplayLine; // 編集途中の境界を反映した行。
  end;

// Viewの時間範囲を画面へ描く。Viewと歌詞・波形配列は変更しない。
procedure DrawManualSyncWaveform(Canvas: TCanvas; const View: TManualSyncWaveformView);

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  Winapi.Windows,
  SYNC_Lyrics_TimeRuler;

const
  RULER_LABEL_TOP_OFFSET = 5;
  SYNC_LINE_BOTTOM_OFFSET = 52;
  WAVEFORM_BASE_DPI = 96;

function ScaleMetric(const View: TManualSyncWaveformView; Value: Integer): Integer;
begin
  Result := MulDiv(Value, Max(1, View.PixelsPerInch), WAVEFORM_BASE_DPI);
end;

function SecondsToX(const View: TManualSyncWaveformView; Value: Double): Integer;
begin
  Result := View.PlotRect.Left + Round((Value - View.ViewStartSeconds) /
    Max(0.001, View.DisplaySeconds) * View.PlotRect.Width);
end;

procedure DrawLyricsLine(Canvas: TCanvas; const View: TManualSyncWaveformView;
  const Line: TManualSyncDisplayLine; Selected: Boolean);
var
  I: Integer;
  LabelRect: TRect;
begin
  if Length(Line.Boundaries) <> Length(Line.Labels) + 1 then
    Exit;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Height := -ScaleMetric(View, 14);
  for I := 0 to High(Line.Labels) do
  begin
    if (Line.Boundaries[I + 1] < View.ViewStartSeconds) or
      (Line.Boundaries[I] > View.ViewStartSeconds + View.DisplaySeconds) then
      Continue;
    LabelRect := Rect(
      Max(View.PlotRect.Left, SecondsToX(View, Line.Boundaries[I])),
      View.PlotRect.Bottom + ScaleMetric(View, LYRICS_LANE_TOP_OFFSET),
      Min(View.PlotRect.Right, SecondsToX(View, Line.Boundaries[I + 1])),
      View.PlotRect.Bottom + ScaleMetric(View, LYRICS_LANE_BOTTOM_OFFSET));
    if LabelRect.Right <= LabelRect.Left then
      Continue;
    if Selected then
    begin
      Canvas.Brush.Color := RGB(42, 92, 118);
      Canvas.Pen.Color := RGB(93, 205, 235);
      Canvas.Font.Color := clWhite;
    end
    else
    begin
      Canvas.Brush.Color := RGB(32, 49, 59);
      Canvas.Pen.Color := RGB(69, 103, 117);
      Canvas.Font.Color := RGB(159, 177, 185);
    end;
    Canvas.Polygon([
      Point(LabelRect.Left, LabelRect.Top),
      Point(Max(LabelRect.Left, LabelRect.Right - ScaleMetric(View, 8)),
        LabelRect.Top),
      Point(LabelRect.Right, (LabelRect.Top + LabelRect.Bottom) div 2),
      Point(Max(LabelRect.Left, LabelRect.Right - ScaleMetric(View, 8)),
        LabelRect.Bottom),
      Point(LabelRect.Left, LabelRect.Bottom)]);
    Canvas.Brush.Style := bsClear;
    InflateRect(LabelRect, -ScaleMetric(View, 4), -ScaleMetric(View, 3));
    Dec(LabelRect.Right, ScaleMetric(View, 6));
    Canvas.TextRect(LabelRect, Line.Labels[I],
      [tfSingleLine, tfVerticalCenter, tfEndEllipsis]);
    Canvas.Brush.Style := bsSolid;
  end;
end;

procedure DrawManualSyncWaveform(Canvas: TCanvas; const View: TManualSyncWaveformView);
var
  CenterY: Integer;
  EndPoint: Integer;
  EndSeconds: Double;
  FirstTickIndex: Int64;
  I: Integer;
  LastTickIndex: Int64;
  MaximumValue: Single;
  MinimumValue: Single;
  Peak: Single;
  PlaybackX: Integer;
  PointIndex: Integer;
  Scale: Double;
  StartPoint: Integer;
  StartSeconds: Double;
  TextValue: string;
  TickDecimalPlaces: Integer;
  TickIndex: Int64;
  TickInterval: Double;
  TickSeconds: Double;
  X: Integer;
  YMaximum: Integer;
  YMinimum: Integer;
begin
  Canvas.Brush.Color := RGB(24, 28, 36);
  Canvas.FillRect(View.ClientRect);
  if (View.PlotRect.Right <= View.PlotRect.Left) or
    (View.PlotRect.Bottom <= View.PlotRect.Top) then
    Exit;

  CenterY := (View.PlotRect.Top + View.PlotRect.Bottom) div 2;
  Canvas.Pen.Width := 1;
  Canvas.Pen.Color := RGB(82, 92, 108);
  Canvas.MoveTo(View.PlotRect.Left, CenterY);
  Canvas.LineTo(View.PlotRect.Right, CenterY);
  TickInterval := SelectTimeRulerInterval(View.DisplaySeconds);
  FirstTickIndex := FirstTimeRulerTickIndex(
    View.ViewStartSeconds, TickInterval);
  LastTickIndex := LastTimeRulerTickIndex(
    View.ViewStartSeconds + View.DisplaySeconds, TickInterval);
  TickDecimalPlaces := TimeRulerDecimalPlaces(TickInterval);
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Height := -ScaleMetric(View, 13);
  Canvas.Font.Color := RGB(205, 212, 226);
  Canvas.Brush.Style := bsClear;
  for TickIndex := FirstTickIndex to LastTickIndex do
  begin
    TickSeconds := TickIndex * TickInterval;
    X := SecondsToX(View, TickSeconds);
    Canvas.Pen.Color := RGB(72, 82, 98);
    Canvas.MoveTo(X, View.PlotRect.Top);
    Canvas.LineTo(X, View.PlotRect.Bottom);
    TextValue := Format('%.*f', [TickDecimalPlaces, TickSeconds],
      TFormatSettings.Invariant);
    Canvas.TextOut(EnsureRange(
      X - Canvas.TextWidth(TextValue) div 2, View.PlotRect.Left,
      View.PlotRect.Right - Canvas.TextWidth(TextValue)),
      View.PlotRect.Bottom + ScaleMetric(View, RULER_LABEL_TOP_OFFSET),
      TextValue);
  end;

  if Length(View.Waveform) = 0 then
  begin
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -ScaleMetric(View, 14);
    Canvas.Font.Color := RGB(210, 215, 224);
    Canvas.Brush.Style := bsClear;
    TextValue := View.WaveformMessage;
    if TextValue = '' then
      TextValue := '波形データがありません。';
    Canvas.TextOut(View.PlotRect.Left +
      (View.PlotRect.Width - Canvas.TextWidth(TextValue)) div 2,
      CenterY - Canvas.TextHeight(TextValue) div 2, TextValue);
    Canvas.Brush.Style := bsSolid;
    Exit;
  end;

  Peak := 0;
  for PointIndex := 0 to High(View.Waveform) do
    Peak := Max(Peak, Max(Abs(View.Waveform[PointIndex].Minimum),
      Abs(View.Waveform[PointIndex].Maximum)));
  if Peak <= 0.000001 then
    Scale := 1
  else
    Scale := 0.9 / Peak;
  Canvas.Pen.Color := RGB(72, 190, 225);
  Canvas.Pen.Width := 1;
  for X := View.PlotRect.Left to View.PlotRect.Right - 1 do
  begin
    StartSeconds := View.ViewStartSeconds +
      (X - View.PlotRect.Left) / Max(1, View.PlotRect.Width) *
      View.DisplaySeconds;
    EndSeconds := View.ViewStartSeconds +
      (X - View.PlotRect.Left + 1) / Max(1, View.PlotRect.Width) *
      View.DisplaySeconds;
    StartPoint := Floor(StartSeconds /
      Max(0.001, View.AudioDurationSeconds) * Length(View.Waveform));
    EndPoint := Ceil(EndSeconds /
      Max(0.001, View.AudioDurationSeconds) * Length(View.Waveform));
    StartPoint := EnsureRange(StartPoint, 0, Length(View.Waveform) - 1);
    if EndPoint <= StartPoint then
      EndPoint := StartPoint + 1;
    EndPoint := Min(Length(View.Waveform), EndPoint);
    MinimumValue := 1;
    MaximumValue := -1;
    for PointIndex := StartPoint to EndPoint - 1 do
    begin
      MinimumValue := Min(MinimumValue, View.Waveform[PointIndex].Minimum);
      MaximumValue := Max(MaximumValue, View.Waveform[PointIndex].Maximum);
    end;
    YMinimum := CenterY - Round(MinimumValue * Scale *
      (View.PlotRect.Height div 2));
    YMaximum := CenterY - Round(MaximumValue * Scale *
      (View.PlotRect.Height div 2));
    Canvas.MoveTo(X, YMaximum);
    Canvas.LineTo(X, YMinimum + 1);
  end;

  for I := 0 to High(View.DisplayLines) do
    if I <> View.SelectedLineIndex then
      DrawLyricsLine(Canvas, View, View.DisplayLines[I], False);
  DrawLyricsLine(Canvas, View, View.SelectedLine, True);

  // 同期線を歌詞枠より手前へ描き、境界のドラッグ位置を見失わないようにする。
  Canvas.Pen.Color := RGB(235, 112, 164);
  Canvas.Pen.Width := 1;
  for I := 0 to High(View.SelectedLine.Boundaries) do
  begin
    if (View.SelectedLine.Boundaries[I] < View.ViewStartSeconds) or
      (View.SelectedLine.Boundaries[I] >
      View.ViewStartSeconds + View.DisplaySeconds) then
      Continue;
    X := SecondsToX(View, View.SelectedLine.Boundaries[I]);
    Canvas.MoveTo(X, View.PlotRect.Top);
    Canvas.LineTo(X, View.PlotRect.Bottom +
      ScaleMetric(View, SYNC_LINE_BOTTOM_OFFSET));
  end;
  if (View.AudioDurationSeconds > 0) and
    (View.PlaybackPositionSeconds >= View.ViewStartSeconds) and
    (View.PlaybackPositionSeconds <=
      View.ViewStartSeconds + View.DisplaySeconds) then
  begin
    PlaybackX := SecondsToX(View, View.PlaybackPositionSeconds);
    Canvas.Pen.Color := RGB(255, 204, 64);
    Canvas.Pen.Width := 2;
    Canvas.MoveTo(PlaybackX, View.PlotRect.Top);
    Canvas.LineTo(PlaybackX, View.PlotRect.Bottom);
    Canvas.Brush.Color := RGB(255, 204, 64);
    Canvas.Polygon([
      Point(PlaybackX - ScaleMetric(View, 5), View.PlotRect.Top),
      Point(PlaybackX + ScaleMetric(View, 5), View.PlotRect.Top),
      Point(PlaybackX, View.PlotRect.Top + ScaleMetric(View, 7))]);
  end;
  Canvas.Brush.Style := bsSolid;
end;

end.
