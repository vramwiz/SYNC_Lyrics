unit SYNC_Lyrics_MusicSyncSettingsForm;

// 曲同期GUIのVCLイベントと、編集モデル・各描画層の受け渡しを調整する。
// 同期規則と個別描画は専用ユニットへ委譲し、フォーム固有処理だけを保持する。

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  SYNC_Lyrics_MusicSync,
  SYNC_Lyrics_MusicSyncEditModel;

type
  TFormLyricsMusicSyncSettings = class(TForm)
    PianoRollPaintBox: TPaintBox;
    BottomPanel: TPanel;
    LyricsLabel: TLabel;
    LyricsEdit: TEdit;
    ResetSyncButton: TButton;
    ApplyButton: TButton;
    CloseButton: TButton;
    procedure LyricsEditChange(Sender: TObject);
    procedure PianoRollPaintBoxMouseDown(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PianoRollPaintBoxMouseMove(Sender: TObject;
      Shift: TShiftState; X, Y: Integer);
    procedure PianoRollPaintBoxMouseUp(Sender: TObject;
      Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure PianoRollPaintBoxPaint(Sender: TObject);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure ResetSyncButtonClick(Sender: TObject);
  protected
    procedure ChangeScale(M, D: Integer;
      isDpiChange: Boolean); override;
  private
    FAnchorAvailable: Boolean;
    FAnchorSeconds: Double;
    FAvailableNoteCount: Integer;
    FDraggingLyric: Boolean;
    FDraggingPreDisplay: Boolean;
    FDraggingView: Boolean;
    FDisplaySeconds: Double;
    FEditModel: TMusicSyncEditModel;
    FFilterLyricHitRects: TArray<TRect>;
    FFixedLyricHitRects: TArray<TRect>;
    FHasTrackNotes: Boolean;
    FHoldSeconds: Double;
    FLastTrackNoteEndSeconds: Double;
    FLineSyncEndSeconds: Double;
    FLineSyncStartSeconds: Double;
    FLoadMessage: string;
    FLyricDragStartX: Integer;
    FLyricDragStep: Integer;
    FNotes: TMusicNoteStarts;
    FPianoRollBuffer: TBitmap;
    FMusicOffsetSeconds: Double;
    FPreDisplaySeconds: Double;
    FSequencePreDisplaySeconds: Double;
    FStartNoteIndex: Integer;
    FMusicLoaded: Boolean;
    FNextLyricsModel: TMusicSyncEditModel;
    FNextStartNoteIndex: Integer;
    FOnSyncChanged: TNotifyEvent;
    FPreviousLyricsModel: TMusicSyncEditModel;
    FPreviousStartNoteIndex: Integer;
    FViewStartOffsetSeconds: Double;
    FViewDragStartOffsetSeconds: Double;
    FViewDragStartX: Integer;
    function GetPreDisplayLinePosition: Integer;
    function HitTestFilterLyric(X, Y: Integer): Integer;
    procedure LoadPianoRoll(const MusicFileName: string; Track: Integer);
    procedure RebuildFilterLyricUnits;
    procedure SetPreDisplayFromMouse(X: Integer);
    procedure UpdateLineSyncTimeRange;
    procedure UpdateNoteAvailabilityMessage;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Filterが最後に発火した絶対位置を、この編集画面の基準とする。
    procedure SetAnchor(Frame, Rate, Scale: Integer);
    procedure SetAnchorUnavailable;
    // Places source music later for positive values and earlier for negative.
    procedure SetMusicOffsetSeconds(Value: Double);
    // Supplies the common first-line synchronization offset from the object start.
    procedure SetSequencePreDisplaySeconds(Value: Double);
    // Supplies the fixed post-synchronization display duration.
    procedure SetHoldSeconds(Value: Double);
    // Supplies neighboring song lines for read-only piano-roll context.
    procedure SetReferenceLyrics(const PreviousLyrics,
      PreviousSyncText: string; PreviousStartNoteIndex: Integer;
      const NextLyrics, NextSyncText: string;
      NextStartNoteIndex: Integer);
    // Skips notes already assigned to preceding whole-song lyric lines.
    procedure SetStartNoteIndex(Value: Integer);
    // Filter項目をモデルへ読み込み、ピアノロール表示を準備する。
    procedure LoadSettings(const MusicFileName: string; Track: Integer;
      PreDisplaySeconds: Double; const FilterLyrics, SyncText: string);
    function LyricsText: string;
    function PreDisplaySeconds: Double;
    function SyncText: string;
    // Notifies an embedding editor after each user synchronization change.
    property OnSyncChanged: TNotifyEvent read FOnSyncChanged
      write FOnSyncChanged;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows,
  SYNC_Lyrics_MusicSyncFixedLyrics,
  SYNC_Lyrics_MusicSyncNoteLyrics,
  SYNC_Lyrics_MusicSyncPianoRoll,
  SYNC_Lyrics_SyncFormat;

{$R *.dfm}

const
  LYRIC_DRAG_STEP_PIXELS_96 = 36;
  MAX_DISPLAY_SECONDS = 60.0;
  MIN_DISPLAY_SECONDS = 1.0;
  PRE_DISPLAY_HIT_MARGIN_96 = 6;

type
  TCapturePaintBox = class(TPaintBox)
  public
    property MouseCapture;
  end;

constructor TFormLyricsMusicSyncSettings.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDisplaySeconds := MUSIC_SYNC_DISPLAY_SECONDS;
  FLineSyncStartSeconds := 0;
  FLineSyncEndSeconds := 0;
  FHoldSeconds := 0.5;
  FMusicOffsetSeconds := 0;
  FSequencePreDisplaySeconds := 0;
  FStartNoteIndex := 0;
  FEditModel := TMusicSyncEditModel.Create;
  FPreviousLyricsModel := TMusicSyncEditModel.Create;
  FNextLyricsModel := TMusicSyncEditModel.Create;
  FPianoRollBuffer := Vcl.Graphics.TBitmap.Create;
  FPianoRollBuffer.PixelFormat := pf32bit;
end;

destructor TFormLyricsMusicSyncSettings.Destroy;
begin
  FPianoRollBuffer.Free;
  FNextLyricsModel.Free;
  FPreviousLyricsModel.Free;
  FEditModel.Free;
  inherited Destroy;
end;

procedure TFormLyricsMusicSyncSettings.ChangeScale(M, D: Integer;
  isDpiChange: Boolean);
begin
  inherited ChangeScale(M, D, isDpiChange);
  if FPianoRollBuffer <> nil then
    FPianoRollBuffer.SetSize(0, 0);
  if PianoRollPaintBox <> nil then
    PianoRollPaintBox.Invalidate;
end;

function TFormLyricsMusicSyncSettings.GetPreDisplayLinePosition: Integer;
var
  RelativeSeconds: Double;
  TimeWidth: Integer;
begin
  Result := -1;
  TimeWidth := PianoRollPaintBox.ClientWidth -
    MusicSyncKeyboardWidth(CurrentPPI);
  RelativeSeconds := FLineSyncStartSeconds - FPreDisplaySeconds -
    FAnchorSeconds;
  if (TimeWidth <= 0) or
    (RelativeSeconds < FViewStartOffsetSeconds) or
    (RelativeSeconds >
      FViewStartOffsetSeconds + FDisplaySeconds) then
    Exit;
  RelativeSeconds := RelativeSeconds - FViewStartOffsetSeconds;
  Result := MusicSyncKeyboardWidth(CurrentPPI) +
    Round(RelativeSeconds / FDisplaySeconds * TimeWidth);
end;

procedure TFormLyricsMusicSyncSettings.FormMouseWheel(Sender: TObject;
  Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint;
  var Handled: Boolean);
var
  ClientPoint: TPoint;
  CursorRatio: Double;
  CursorSeconds: Double;
  MaxViewOffset: Double;
  NewDisplaySeconds: Double;
  TimeWidth: Integer;
  WheelSteps: Double;
begin
  ClientPoint := PianoRollPaintBox.ScreenToClient(MousePos);
  if not PtInRect(PianoRollPaintBox.ClientRect, ClientPoint) then
    Exit;
  TimeWidth := PianoRollPaintBox.ClientWidth -
    MusicSyncKeyboardWidth(CurrentPPI);
  if TimeWidth <= 0 then
    Exit;

  WheelSteps := WheelDelta / 120;
  MaxViewOffset := Max(0.0, FLastTrackNoteEndSeconds -
    FAnchorSeconds - FDisplaySeconds);
  if ssShift in Shift then
    FViewStartOffsetSeconds := EnsureRange(
      FViewStartOffsetSeconds - WheelSteps *
        FDisplaySeconds * 0.25, 0.0, MaxViewOffset)
  else
  begin
    CursorRatio := EnsureRange(
      (ClientPoint.X - MusicSyncKeyboardWidth(CurrentPPI)) /
        TimeWidth, 0.0, 1.0);
    CursorSeconds := FViewStartOffsetSeconds +
      CursorRatio * FDisplaySeconds;
    if WheelDelta > 0 then
      NewDisplaySeconds := FDisplaySeconds * 0.8
    else
      NewDisplaySeconds := FDisplaySeconds * 1.25;
    NewDisplaySeconds := EnsureRange(NewDisplaySeconds,
      MIN_DISPLAY_SECONDS, MAX_DISPLAY_SECONDS);
    MaxViewOffset := Max(0.0, FLastTrackNoteEndSeconds -
      FAnchorSeconds - NewDisplaySeconds);
    FViewStartOffsetSeconds := EnsureRange(
      CursorSeconds - CursorRatio * NewDisplaySeconds,
      0.0, MaxViewOffset);
    FDisplaySeconds := NewDisplaySeconds;
  end;
  Handled := True;
  PianoRollPaintBox.Invalidate;
end;

function TFormLyricsMusicSyncSettings.HitTestFilterLyric(
  X, Y: Integer): Integer;
begin
  Result := HitTestNoteFollowingLyrics(FFilterLyricHitRects, X, Y);
  if Result < 0 then
    Result := HitTestFixedLyrics(FFixedLyricHitRects, X, Y);
end;

procedure TFormLyricsMusicSyncSettings.LoadPianoRoll(
  const MusicFileName: string; Track: Integer);
var
  AllNotes: TMusicNoteStarts;
  I: Integer;
  LastTrackNoteEndSeconds: Double;
  NoteCount: Integer;
  ShiftedNote: TMusicNoteStart;
  TargetOffsetSeconds: Double;
begin
  SetLength(FNotes, 0);
  FMusicLoaded := False;
  FHasTrackNotes := False;
  FAvailableNoteCount := 0;
  FLastTrackNoteEndSeconds := 0;
  FLoadMessage := '';
  FLineSyncStartSeconds := FAnchorSeconds +
    FSequencePreDisplaySeconds;
  if not FAnchorAvailable then
    FLoadMessage := '基準位置を取得できません。'
  else if MusicFileName = '' then
    FLoadMessage := '音楽ファイルが指定されていません。'
  else if not LoadMusicNoteStarts(MusicFileName, AllNotes) then
    FLoadMessage := '音楽ファイルを読み込めませんでした。'
  else
  begin
    FMusicLoaded := True;
    SetLength(FNotes, Length(AllNotes));
    NoteCount := 0;
    LastTrackNoteEndSeconds := 0;
    for I := 0 to High(AllNotes) do
    begin
      if (Track >= 0) and (AllNotes[I].TrackIndex <> Track) then
        Continue;
      FHasTrackNotes := True;
      ShiftedNote := AllNotes[I];
      ShiftedNote.Seconds := MusicSecondsToObjectSeconds(
        ShiftedNote.Seconds, FMusicOffsetSeconds);
      ShiftedNote.EndSeconds := MusicSecondsToObjectSeconds(
        ShiftedNote.EndSeconds, FMusicOffsetSeconds);
      LastTrackNoteEndSeconds := Max(LastTrackNoteEndSeconds,
        ShiftedNote.EndSeconds);
      if ShiftedNote.EndSeconds < FAnchorSeconds then
        Continue;
      FNotes[NoteCount] := ShiftedNote;
      Inc(NoteCount);
    end;
    SetLength(FNotes, NoteCount);
    FLastTrackNoteEndSeconds := LastTrackNoteEndSeconds;
    UpdateLineSyncTimeRange;
    TargetOffsetSeconds := FLineSyncStartSeconds -
      FPreDisplaySeconds - FAnchorSeconds;
    FViewStartOffsetSeconds := Max(0, TargetOffsetSeconds);
    UpdateNoteAvailabilityMessage;
  end;
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.LoadSettings(
  const MusicFileName: string; Track: Integer; PreDisplaySeconds: Double;
  const FilterLyrics, SyncText: string);
begin
  FPreDisplaySeconds := Max(0.0, PreDisplaySeconds);
  FDisplaySeconds := MUSIC_SYNC_DISPLAY_SECONDS;
  FViewStartOffsetSeconds := 0;
  LyricsEdit.Text := FilterLyrics;
  RebuildFilterLyricUnits;
  FEditModel.LoadSyncText(SyncText);
  LoadPianoRoll(MusicFileName, Track);
end;

procedure TFormLyricsMusicSyncSettings.LyricsEditChange(Sender: TObject);
begin
  RebuildFilterLyricUnits;
  PianoRollPaintBox.Invalidate;
end;

function TFormLyricsMusicSyncSettings.LyricsText: string;
begin
  Result := LyricsEdit.Text;
end;

function TFormLyricsMusicSyncSettings.PreDisplaySeconds: Double;
begin
  Result := FPreDisplaySeconds;
end;

function TFormLyricsMusicSyncSettings.SyncText: string;
begin
  Result := FEditModel.SerializeSyncText;
end;

procedure TFormLyricsMusicSyncSettings.PianoRollPaintBoxMouseDown(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  LinePosition: Integer;
  LyricIndex: Integer;
  PreDisplayHitMargin: Integer;
begin
  if Button <> mbLeft then
    Exit;
  LinePosition := GetPreDisplayLinePosition;
  PreDisplayHitMargin := ScaleMusicSyncMetric(
    PRE_DISPLAY_HIT_MARGIN_96, CurrentPPI);
  if (LinePosition >= 0) and
    (Abs(X - LinePosition) <= PreDisplayHitMargin) then
  begin
    FDraggingPreDisplay := True;
    TCapturePaintBox(PianoRollPaintBox).MouseCapture := True;
    PianoRollPaintBox.Cursor := crSizeWE;
    SetPreDisplayFromMouse(X);
    Exit;
  end;

  LyricIndex := HitTestFilterLyric(X, Y);
  if FEditModel.BeginDrag(LyricIndex) then
  begin
    FDraggingLyric := True;
    FLyricDragStartX := X;
    FLyricDragStep := 0;
    TCapturePaintBox(PianoRollPaintBox).MouseCapture := True;
    PianoRollPaintBox.Cursor := crSizeWE;
    PianoRollPaintBox.Invalidate;
    Exit;
  end;

  FDraggingView := True;
  FViewDragStartX := X;
  FViewDragStartOffsetSeconds := FViewStartOffsetSeconds;
  TCapturePaintBox(PianoRollPaintBox).MouseCapture := True;
  PianoRollPaintBox.Cursor := crSizeWE;
end;

procedure TFormLyricsMusicSyncSettings.PianoRollPaintBoxMouseMove(
  Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  DragStep: Integer;
  DragStepPixels: Integer;
  LinePosition: Integer;
  PreDisplayHitMargin: Integer;
  TimeWidth: Integer;
begin
  if FDraggingPreDisplay then
  begin
    SetPreDisplayFromMouse(X);
    PianoRollPaintBox.Cursor := crSizeWE;
    Exit;
  end;
  if FDraggingLyric then
  begin
    DragStepPixels := Max(1, ScaleMusicSyncMetric(
      LYRIC_DRAG_STEP_PIXELS_96, CurrentPPI));
    if X >= FLyricDragStartX then
      DragStep := (X - FLyricDragStartX) div DragStepPixels
    else
      DragStep := -((FLyricDragStartX - X) div
        DragStepPixels);
    if DragStep <> FLyricDragStep then
    begin
      FLyricDragStep := DragStep;
      FEditModel.ApplyDragStep(DragStep);
      UpdateLineSyncTimeRange;
      if Assigned(FOnSyncChanged) then
        FOnSyncChanged(Self);
      PianoRollPaintBox.Invalidate;
    end;
    PianoRollPaintBox.Cursor := crSizeWE;
    Exit;
  end;
  if FDraggingView then
  begin
    TimeWidth := Max(1, PianoRollPaintBox.ClientWidth -
      MusicSyncKeyboardWidth(CurrentPPI));
    FViewStartOffsetSeconds := EnsureRange(
      FViewDragStartOffsetSeconds -
      (X - FViewDragStartX) / TimeWidth * FDisplaySeconds,
      0.0, Max(0.0, FLastTrackNoteEndSeconds -
      FAnchorSeconds - FDisplaySeconds));
    PianoRollPaintBox.Cursor := crSizeWE;
    PianoRollPaintBox.Invalidate;
    Exit;
  end;

  LinePosition := GetPreDisplayLinePosition;
  PreDisplayHitMargin := ScaleMusicSyncMetric(
    PRE_DISPLAY_HIT_MARGIN_96, CurrentPPI);
  if (LinePosition >= 0) and
    (Abs(X - LinePosition) <= PreDisplayHitMargin) then
    PianoRollPaintBox.Cursor := crSizeWE
  else if HitTestFilterLyric(X, Y) >= 0 then
    PianoRollPaintBox.Cursor := crSizeWE
  else
    PianoRollPaintBox.Cursor := crSizeWE;
end;

procedure TFormLyricsMusicSyncSettings.PianoRollPaintBoxMouseUp(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if Button <> mbLeft then
    Exit;
  if FDraggingPreDisplay then
  begin
    SetPreDisplayFromMouse(X);
    FDraggingPreDisplay := False;
    TCapturePaintBox(PianoRollPaintBox).MouseCapture := False;
  end
  else if FDraggingLyric then
  begin
    FDraggingLyric := False;
    FEditModel.EndDrag;
    TCapturePaintBox(PianoRollPaintBox).MouseCapture := False;
  end
  else if FDraggingView then
  begin
    FDraggingView := False;
    TCapturePaintBox(PianoRollPaintBox).MouseCapture := False;
  end
  else
    Exit;
  PianoRollPaintBoxMouseMove(Sender, Shift, X, Y);
end;

procedure TFormLyricsMusicSyncSettings.PianoRollPaintBoxPaint(
  Sender: TObject);
var
  Canvas: TCanvas;
  Dpi: Integer;
  Layout: TPianoRollLayout;
  PianoHeight: Integer;
  PianoWidth: Integer;
  TextHeight: Integer;
  TextWidth: Integer;
begin
  Dpi := CurrentPPI;
  PianoWidth := PianoRollPaintBox.ClientWidth;
  PianoHeight := PianoRollPaintBox.ClientHeight;
  if (PianoWidth <= 0) or (PianoHeight <= 0) or
    (FPianoRollBuffer = nil) then
    Exit;
  if (FPianoRollBuffer.Width <> PianoWidth) or
    (FPianoRollBuffer.Height <> PianoHeight) then
    FPianoRollBuffer.SetSize(PianoWidth, PianoHeight);
  Canvas := FPianoRollBuffer.Canvas;
  try
    DrawMusicSyncPianoRoll(Canvas, PianoWidth, PianoHeight, FNotes,
      FAnchorSeconds, FSequencePreDisplaySeconds, FStartNoteIndex,
      FAnchorSeconds + FViewStartOffsetSeconds,
      FDisplaySeconds, Dpi, Layout);
    DrawReferenceNoteLyrics(Canvas, FPreviousLyricsModel,
      FPreviousStartNoteIndex, Layout, PianoWidth);
    DrawReferenceNoteLyrics(Canvas, FNextLyricsModel,
      FNextStartNoteIndex, Layout, PianoWidth);
    DrawNoteFollowingLyrics(Canvas, FEditModel, Layout, PianoWidth,
      FFilterLyricHitRects);
    DrawFixedLyrics(Canvas, PianoWidth, PianoHeight, FEditModel, Layout,
      FFixedLyricHitRects);
    DrawUnassignedLyrics(Canvas, PianoWidth, FEditModel, Layout,
      FAvailableNoteCount);
    DrawMusicSyncMarkers(Canvas, PianoHeight, PianoWidth,
      FLineSyncStartSeconds, FPreDisplaySeconds,
      FLineSyncEndSeconds + FHoldSeconds, Layout);

    if FLoadMessage <> '' then
    begin
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Name := 'Segoe UI';
      Canvas.Font.Height := -ScaleMusicSyncMetric(14, Dpi);
      Canvas.Font.Style := [];
      Canvas.Font.Color := RGB(210, 215, 224);
      TextWidth := Canvas.TextWidth(FLoadMessage);
      TextHeight := Canvas.TextHeight(FLoadMessage);
      Canvas.TextOut(Layout.KeyboardWidth +
        (Layout.TimeWidth - TextWidth) div 2,
        (Layout.RollHeight - TextHeight) div 2, FLoadMessage);
      Canvas.Brush.Style := bsSolid;
    end;
  finally
    // 全描画層を合成した1枚だけを画面へ転送する。
    PianoRollPaintBox.Canvas.Draw(0, 0, FPianoRollBuffer);
  end;
end;

procedure TFormLyricsMusicSyncSettings.RebuildFilterLyricUnits;
begin
  FEditModel.SetLyrics(LyricsEdit.Text);
  SetLength(FFilterLyricHitRects, Length(FEditModel.Units));
  SetLength(FFixedLyricHitRects, Length(FEditModel.Units));
end;

procedure TFormLyricsMusicSyncSettings.ResetSyncButtonClick(
  Sender: TObject);
begin
  FEditModel.Reset;
  UpdateLineSyncTimeRange;
  FDraggingLyric := False;
  if Assigned(FOnSyncChanged) then
    FOnSyncChanged(Self);
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.SetPreDisplayFromMouse(X: Integer);
var
  MouseSeconds: Double;
  PreviousPreDisplaySeconds: Double;
  TimeWidth: Integer;
begin
  TimeWidth := PianoRollPaintBox.ClientWidth -
    MusicSyncKeyboardWidth(CurrentPPI);
  if TimeWidth <= 0 then
    Exit;
  MouseSeconds := FAnchorSeconds + FViewStartOffsetSeconds +
    (X - MusicSyncKeyboardWidth(CurrentPPI)) / TimeWidth *
      FDisplaySeconds;
  PreviousPreDisplaySeconds := FPreDisplaySeconds;
  FPreDisplaySeconds := Round(EnsureRange(
    FLineSyncStartSeconds - MouseSeconds,
    0.0, MAX_DISPLAY_SECONDS) * 100) / 100;
  if (Abs(FPreDisplaySeconds - PreviousPreDisplaySeconds) >= 0.005) and
    Assigned(FOnSyncChanged) then
    FOnSyncChanged(Self);
  UpdateNoteAvailabilityMessage;
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.UpdateNoteAvailabilityMessage;
const
  TIME_EPSILON = 0.000000001;
var
  I: Integer;
  SyncStartSeconds: Double;
begin
  if not FMusicLoaded then
    Exit;
  FLoadMessage := '';
  if not FHasTrackNotes then
  begin
    FLoadMessage := '指定トラックにノートがありません。';
    Exit;
  end;

  SyncStartSeconds := FAnchorSeconds + FSequencePreDisplaySeconds;
  FAvailableNoteCount := 0;
  for I := 0 to High(FNotes) do
    if FNotes[I].Seconds >= SyncStartSeconds - TIME_EPSILON then
      Inc(FAvailableNoteCount);
  FAvailableNoteCount := Max(0,
    FAvailableNoteCount - FStartNoteIndex);
  if FAvailableNoteCount = 0 then
    FLoadMessage := Format(
      '同期開始 %.3f 秒以降に対象ノートがありません（曲データ最終 %.3f 秒）。',
      [SyncStartSeconds, FLastTrackNoteEndSeconds],
      TFormatSettings.Invariant);
end;

procedure TFormLyricsMusicSyncSettings.UpdateLineSyncTimeRange;
var
  EligibleNoteIndex: Integer;
  I: Integer;
  LastNoteIndex: Integer;
  RequiredNoteCount: Integer;
begin
  FLineSyncStartSeconds := FAnchorSeconds +
    FSequencePreDisplaySeconds;
  FLineSyncEndSeconds := FLineSyncStartSeconds;
  RequiredNoteCount := CountMusicSyncRequiredNotes(
    FEditModel.SerializeSyncText, Length(FEditModel.Units));
  if RequiredNoteCount <= 0 then
    Exit;
  EligibleNoteIndex := 0;
  LastNoteIndex := FStartNoteIndex + RequiredNoteCount - 1;
  for I := 0 to High(FNotes) do
    if FNotes[I].Seconds >=
      FAnchorSeconds + FSequencePreDisplaySeconds then
    begin
      if EligibleNoteIndex = FStartNoteIndex then
        FLineSyncStartSeconds := FNotes[I].Seconds;
      if EligibleNoteIndex = LastNoteIndex then
      begin
        FLineSyncEndSeconds := Max(FNotes[I].EndSeconds,
          FNotes[I].Seconds);
        Exit;
      end;
      Inc(EligibleNoteIndex);
    end;
end;

procedure TFormLyricsMusicSyncSettings.SetAnchor(Frame, Rate,
  Scale: Integer);
begin
  FAnchorAvailable := (Rate > 0) and (Scale > 0);
  FAnchorSeconds := 0;
  if FAnchorAvailable then
    FAnchorSeconds := Frame * Scale / Rate;
end;

procedure TFormLyricsMusicSyncSettings.SetAnchorUnavailable;
begin
  FAnchorAvailable := False;
  FAnchorSeconds := 0;
end;

procedure TFormLyricsMusicSyncSettings.SetHoldSeconds(Value: Double);
begin
  FHoldSeconds := Max(0.0, Value);
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.SetStartNoteIndex(Value: Integer);
begin
  FStartNoteIndex := Max(0, Value);
  UpdateNoteAvailabilityMessage;
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.SetMusicOffsetSeconds(Value: Double);
begin
  FMusicOffsetSeconds := EnsureRange(Value, -5.0, 5.0);
end;

procedure TFormLyricsMusicSyncSettings.SetSequencePreDisplaySeconds(
  Value: Double);
begin
  FSequencePreDisplaySeconds := Max(0.0, Value);
end;

procedure TFormLyricsMusicSyncSettings.SetReferenceLyrics(
  const PreviousLyrics, PreviousSyncText: string;
  PreviousStartNoteIndex: Integer; const NextLyrics,
  NextSyncText: string; NextStartNoteIndex: Integer);
begin
  FPreviousLyricsModel.SetLyrics(PreviousLyrics);
  FPreviousLyricsModel.LoadSyncText(PreviousSyncText);
  FPreviousStartNoteIndex := Max(0, PreviousStartNoteIndex);
  FNextLyricsModel.SetLyrics(NextLyrics);
  FNextLyricsModel.LoadSyncText(NextSyncText);
  FNextStartNoteIndex := Max(0, NextStartNoteIndex);
  PianoRollPaintBox.Invalidate;
end;

end.
