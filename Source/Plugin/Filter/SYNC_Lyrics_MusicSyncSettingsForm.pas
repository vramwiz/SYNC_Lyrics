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
    procedure ResetSyncButtonClick(Sender: TObject);
  protected
    procedure ChangeScale(M, D: Integer;
      isDpiChange: Boolean); override;
  private
    FAnchorAvailable: Boolean;
    FAnchorSeconds: Double;
    FDraggingLyric: Boolean;
    FDraggingPreDisplay: Boolean;
    FEditModel: TMusicSyncEditModel;
    FFilterLyricHitRects: TArray<TRect>;
    FFixedLyricHitRects: TArray<TRect>;
    FLoadMessage: string;
    FLyricDragStartX: Integer;
    FLyricDragStep: Integer;
    FNotes: TMusicNoteStarts;
    FPianoRollBuffer: TBitmap;
    FPreDisplaySeconds: Double;
    function GetPreDisplayLinePosition: Integer;
    function HitTestFilterLyric(X, Y: Integer): Integer;
    procedure LoadPianoRoll(const MusicFileName: string; Track: Integer);
    procedure RebuildFilterLyricUnits;
    procedure SetPreDisplayFromMouse(X: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Filterが最後に発火した絶対位置を、この編集画面の基準とする。
    procedure SetAnchor(Frame, Rate, Scale: Integer);
    procedure SetAnchorUnavailable;
    // Filter項目をモデルへ読み込み、ピアノロール表示を準備する。
    procedure LoadSettings(const MusicFileName: string; Track: Integer;
      PreDisplaySeconds: Double; const FilterLyrics, SyncText: string);
    function LyricsText: string;
    function PreDisplaySeconds: Double;
    function SyncText: string;
  end;

implementation

uses
  System.Math,
  Winapi.Windows,
  SYNC_Lyrics_MusicSyncFixedLyrics,
  SYNC_Lyrics_MusicSyncNoteLyrics,
  SYNC_Lyrics_MusicSyncPianoRoll;

{$R *.dfm}

const
  LYRIC_DRAG_STEP_PIXELS_96 = 36;
  PRE_DISPLAY_HIT_MARGIN_96 = 6;

type
  TCapturePaintBox = class(TPaintBox)
  public
    property MouseCapture;
  end;

constructor TFormLyricsMusicSyncSettings.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEditModel := TMusicSyncEditModel.Create;
  FPianoRollBuffer := Vcl.Graphics.TBitmap.Create;
  FPianoRollBuffer.PixelFormat := pf32bit;
end;

destructor TFormLyricsMusicSyncSettings.Destroy;
begin
  FPianoRollBuffer.Free;
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
  TimeWidth: Integer;
begin
  Result := -1;
  TimeWidth := PianoRollPaintBox.ClientWidth -
    MusicSyncKeyboardWidth(CurrentPPI);
  if (TimeWidth <= 0) or
    (FPreDisplaySeconds > MUSIC_SYNC_DISPLAY_SECONDS) then
    Exit;
  Result := MusicSyncKeyboardWidth(CurrentPPI) +
    Round(FPreDisplaySeconds / MUSIC_SYNC_DISPLAY_SECONDS * TimeWidth);
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
  NoteCount: Integer;
begin
  SetLength(FNotes, 0);
  FLoadMessage := '';
  if not FAnchorAvailable then
    FLoadMessage := '基準位置を取得できません。'
  else if MusicFileName = '' then
    FLoadMessage := '音楽ファイルが指定されていません。'
  else if not LoadMusicNoteStarts(MusicFileName, AllNotes) then
    FLoadMessage := '音楽ファイルを読み込めませんでした。'
  else
  begin
    SetLength(FNotes, Length(AllNotes));
    NoteCount := 0;
    for I := 0 to High(AllNotes) do
    begin
      if (Track >= 0) and (AllNotes[I].TrackIndex <> Track) then
        Continue;
      if AllNotes[I].EndSeconds < FAnchorSeconds then
        Continue;
      FNotes[NoteCount] := AllNotes[I];
      Inc(NoteCount);
    end;
    SetLength(FNotes, NoteCount);
  end;
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.LoadSettings(
  const MusicFileName: string; Track: Integer; PreDisplaySeconds: Double;
  const FilterLyrics, SyncText: string);
begin
  FPreDisplaySeconds := Max(0.0, PreDisplaySeconds);
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
  end;
end;

procedure TFormLyricsMusicSyncSettings.PianoRollPaintBoxMouseMove(
  Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  DragStep: Integer;
  DragStepPixels: Integer;
  LinePosition: Integer;
  PreDisplayHitMargin: Integer;
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
      PianoRollPaintBox.Invalidate;
    end;
    PianoRollPaintBox.Cursor := crSizeWE;
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
    PianoRollPaintBox.Cursor := crDefault;
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
      FAnchorSeconds, FPreDisplaySeconds, Dpi, Layout);
    DrawNoteFollowingLyrics(Canvas, FEditModel, Layout, PianoWidth,
      FFilterLyricHitRects);
    DrawFixedLyrics(Canvas, PianoWidth, PianoHeight, FEditModel, Layout,
      FFixedLyricHitRects);
    DrawMusicSyncMarkers(Canvas, PianoHeight, PianoWidth,
      FPreDisplaySeconds, Layout);

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
  FDraggingLyric := False;
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.SetPreDisplayFromMouse(X: Integer);
var
  TimeWidth: Integer;
begin
  TimeWidth := PianoRollPaintBox.ClientWidth -
    MusicSyncKeyboardWidth(CurrentPPI);
  if TimeWidth <= 0 then
    Exit;
  FPreDisplaySeconds := Round(EnsureRange(
    (X - MusicSyncKeyboardWidth(CurrentPPI)) / TimeWidth *
      MUSIC_SYNC_DISPLAY_SECONDS,
    0.0, MUSIC_SYNC_DISPLAY_SECONDS) * 100) / 100;
  PianoRollPaintBox.Invalidate;
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

end.
