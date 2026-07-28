unit SYNC_Lyrics_MusicSyncSettingsForm;

// 曲同期編集の基準位置と、音楽データの最小ピアノロール表示を提供する。

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  SYNC_Lyrics_MusicSync;

type
  TMusicSyncEditGroup = record
    UnitStart: Integer;
    UnitCount: Integer;
    NoteCount: Integer;
  end;
  TMusicSyncEditGroups = TArray<TMusicSyncEditGroup>;

  TFormLyricsMusicSyncSettings = class(TForm)
    PianoRollPaintBox: TPaintBox;
    BottomPanel: TPanel;
    LyricsLabel: TLabel;
    LyricsEdit: TEdit;
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
  private
    FAnchorAvailable: Boolean;
    FAnchorSeconds: Double;
    FDraggingLyric: Boolean;
    FDraggingPreDisplay: Boolean;
    FFilterLyricHitRects: TArray<TRect>;
    FFilterLyricUnits: TArray<string>;
    FLoadMessage: string;
    FLyricDragGroupEnd: Integer;
    FLyricDragGroupIndex: Integer;
    FLyricDragGroupNoteCount: Integer;
    FLyricDragGroupStart: Integer;
    FLyricDragOriginalGroups: TMusicSyncEditGroups;
    FLyricDragStartX: Integer;
    FLyricDragStep: Integer;
    FNotes: TMusicNoteStarts;
    FPianoRollBuffer: TBitmap;
    FPreDisplaySeconds: Double;
    FSelectedLyricIndex: Integer;
    FSyncEditGroups: TMusicSyncEditGroups;
    FUnitGroupIndexes: TArray<Integer>;
    FUnitNoteIndexes: TArray<Integer>;
    procedure AppendEditGroup(var Groups: TMusicSyncEditGroups;
      UnitCount, NoteCount: Integer);
    procedure AppendPreservedGroups(const Source: TMusicSyncEditGroups;
      FirstUnit, LastUnit: Integer; var Dest: TMusicSyncEditGroups);
    procedure ApplyLyricDragStep(Step: Integer);
    procedure GetKeyAxisBounds(CanvasHeight, MidiKey, LowestKey,
      HighestKey: Integer; KeyThickness: Double;
      out TopPosition, BottomPosition: Integer);
    procedure GetLaneAxisBounds(CanvasHeight, MidiKey, LowestKey,
      HighestKey: Integer; KeyThickness: Double;
      out TopPosition, BottomPosition: Integer);
    procedure GetNoteAxisBounds(CanvasHeight, MidiKey, LowestKey,
      HighestKey: Integer; KeyThickness: Double;
      out TopPosition, BottomPosition: Integer);
    function GetKeyName(MidiKey: Integer): string;
    function GetPianoKeyPitchCenter(MidiKey: Integer): Double;
    function GetPreDisplayLinePosition: Integer;
    function HitTestFilterLyric(X, Y: Integer): Integer;
    function IsBlackKey(Key: Integer): Boolean;
    procedure LoadPianoRoll(const MusicFileName: string; Track: Integer);
    procedure LoadSyncStages(const SyncText: string);
    procedure RebuildFilterLyricUnits;
    procedure RebuildUnitNoteIndexes;
    procedure ResizeEditGroups(UnitCount: Integer);
    procedure ResolvePitchRange(out LowestKey, HighestKey: Integer);
    procedure SetPreDisplayFromMouse(X: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Filterが最後に発火した絶対位置を、この編集画面の基準として表示する。
    procedure SetAnchor(Frame, Rate, Scale: Integer);
    // Filterがまだ発火していないため基準位置を取得できないことを表示する。
    procedure SetAnchorUnavailable;
    // 音楽ファイルとトラックを読み込み、基準位置から未来側のピアノロールを準備する。
    procedure LoadSettings(const MusicFileName: string; Track: Integer;
      PreDisplaySeconds: Double; const FilterLyrics, SyncText: string);
    function LyricsText: string;
    function SyncText: string;
  end;

implementation

uses
  System.Math,
  Winapi.Windows,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_SyncFormat;

{$R *.dfm}

const
  PIANO_ROLL_DISPLAY_SECONDS = 6.0;
  PIANO_ROLL_KEYBOARD_WIDTH = 76;
  PIANO_ROLL_MIN_VISIBLE_KEYS = 24;
  FILTER_LYRIC_NOTE_MARGIN = 5;
  LYRIC_DRAG_STEP_PIXELS = 36;
  PRE_DISPLAY_HIT_MARGIN = 6;

type
  TCapturePaintBox = class(TPaintBox)
  public
    property MouseCapture;
  end;

constructor TFormLyricsMusicSyncSettings.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSelectedLyricIndex := -1;
  FPianoRollBuffer := Vcl.Graphics.TBitmap.Create;
  FPianoRollBuffer.PixelFormat := pf32bit;
end;

destructor TFormLyricsMusicSyncSettings.Destroy;
begin
  FPianoRollBuffer.Free;
  inherited Destroy;
end;

function TFormLyricsMusicSyncSettings.GetPianoKeyPitchCenter(
  MidiKey: Integer): Double;
begin
  // ピアノロールの縦軸は、白鍵・黒鍵に関係なく半音ごとの等間隔とする。
  Result := MidiKey;
end;

function TFormLyricsMusicSyncSettings.GetKeyName(MidiKey: Integer): string;
const
  KEY_NAMES: array[0..11] of string = (
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  );
var
  PitchClass: Integer;
begin
  PitchClass := MidiKey mod 12;
  if PitchClass < 0 then
    Inc(PitchClass, 12);
  Result := KEY_NAMES[PitchClass];
end;

procedure TFormLyricsMusicSyncSettings.GetLaneAxisBounds(CanvasHeight,
  MidiKey, LowestKey, HighestKey: Integer; KeyThickness: Double;
  out TopPosition, BottomPosition: Integer);
var
  AxisCenter: Double;
  RangeCenter: Double;
begin
  RangeCenter := (GetPianoKeyPitchCenter(LowestKey) +
    GetPianoKeyPitchCenter(HighestKey)) * 0.5;
  AxisCenter := CanvasHeight * 0.5 -
    (GetPianoKeyPitchCenter(MidiKey) - RangeCenter) * KeyThickness;
  TopPosition := Round(AxisCenter - KeyThickness * 0.5);
  BottomPosition := Round(AxisCenter + KeyThickness * 0.5);
  if BottomPosition <= TopPosition then
    BottomPosition := TopPosition + 1;
end;

procedure TFormLyricsMusicSyncSettings.GetKeyAxisBounds(CanvasHeight,
  MidiKey, LowestKey, HighestKey: Integer; KeyThickness: Double;
  out TopPosition, BottomPosition: Integer);
var
  AxisCenter: Double;
  KeyCenter: Double;
  RangeCenter: Double;
  VisibleThickness: Double;
begin
  RangeCenter := (GetPianoKeyPitchCenter(LowestKey) +
    GetPianoKeyPitchCenter(HighestKey)) * 0.5;
  KeyCenter := GetPianoKeyPitchCenter(MidiKey);
  AxisCenter := CanvasHeight * 0.5 -
    (KeyCenter - RangeCenter) * KeyThickness;
  if IsBlackKey(MidiKey) then
    VisibleThickness := KeyThickness * 0.62
  else
    VisibleThickness := KeyThickness;
  TopPosition := Round(AxisCenter - VisibleThickness * 0.5);
  BottomPosition := Round(AxisCenter + VisibleThickness * 0.5);
  if BottomPosition <= TopPosition then
    BottomPosition := TopPosition + 1;
end;

procedure TFormLyricsMusicSyncSettings.GetNoteAxisBounds(CanvasHeight,
  MidiKey, LowestKey, HighestKey: Integer; KeyThickness: Double;
  out TopPosition, BottomPosition: Integer);
var
  AxisCenter: Double;
  NoteHeight: Integer;
  RangeCenter: Double;
begin
  RangeCenter := (GetPianoKeyPitchCenter(LowestKey) +
    GetPianoKeyPitchCenter(HighestKey)) * 0.5;
  AxisCenter := CanvasHeight * 0.5 -
    (GetPianoKeyPitchCenter(MidiKey) - RangeCenter) * KeyThickness;
  // 高さを先に整数へ固定し、上下端の個別丸めによる1px差を発生させない。
  NoteHeight := Max(3, Round(KeyThickness * 0.8));
  TopPosition := Round(AxisCenter - NoteHeight * 0.5);
  BottomPosition := TopPosition + NoteHeight;
end;

function TFormLyricsMusicSyncSettings.GetPreDisplayLinePosition: Integer;
var
  TimeWidth: Integer;
begin
  Result := -1;
  TimeWidth := PianoRollPaintBox.ClientWidth - PIANO_ROLL_KEYBOARD_WIDTH;
  if (TimeWidth <= 0) or
    (FPreDisplaySeconds > PIANO_ROLL_DISPLAY_SECONDS) then
    Exit;
  Result := PIANO_ROLL_KEYBOARD_WIDTH +
    Round(FPreDisplaySeconds / PIANO_ROLL_DISPLAY_SECONDS * TimeWidth);
end;

function TFormLyricsMusicSyncSettings.IsBlackKey(Key: Integer): Boolean;
var
  PitchClass: Integer;
begin
  PitchClass := Key mod 12;
  if PitchClass < 0 then
    Inc(PitchClass, 12);
  Result := PitchClass in [1, 3, 6, 8, 10];
end;

function TFormLyricsMusicSyncSettings.HitTestFilterLyric(
  X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FFilterLyricHitRects) do
    if PtInRect(FFilterLyricHitRects[I], Point(X, Y)) then
      Exit(I);
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
  begin
    FLoadMessage := '基準位置を取得できません。';
    PianoRollPaintBox.Invalidate;
    Exit;
  end;
  if MusicFileName = '' then
  begin
    FLoadMessage := '音楽ファイルが指定されていません。';
    PianoRollPaintBox.Invalidate;
    Exit;
  end;
  if not LoadMusicNoteStarts(MusicFileName, AllNotes) then
  begin
    FLoadMessage := '音楽ファイルを読み込めませんでした。';
    PianoRollPaintBox.Invalidate;
    Exit;
  end;

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
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.LoadSyncStages(
  const SyncText: string);
var
  Data: TSyncTextData;
  NoteCount: Integer;
  StageIndex: Integer;
  StageValue: Integer;
  UnitCount: Integer;
  UnitIndex: Integer;
begin
  SetLength(FSyncEditGroups, 0);
  if not TryParseSyncText(SyncText, Data) or
    (Data.Mode <> smMusic) then
    SetLength(Data.MusicStages, 0);

  StageIndex := 0;
  UnitIndex := 0;
  while UnitIndex < Length(FFilterLyricUnits) do
  begin
    if StageIndex < Length(Data.MusicStages) then
      StageValue := Data.MusicStages[StageIndex]
    else
      StageValue := 0;
    if StageValue < 0 then
    begin
      UnitCount := Min(Abs(StageValue) + 1,
        Length(FFilterLyricUnits) - UnitIndex);
      NoteCount := 1;
    end
    else
    begin
      UnitCount := 1;
      NoteCount := StageValue + 1;
    end;
    AppendEditGroup(FSyncEditGroups, UnitCount, NoteCount);
    Inc(UnitIndex, UnitCount);
    Inc(StageIndex);
  end;
  RebuildUnitNoteIndexes;
end;

procedure TFormLyricsMusicSyncSettings.LoadSettings(
  const MusicFileName: string; Track: Integer; PreDisplaySeconds: Double;
  const FilterLyrics, SyncText: string);
begin
  FPreDisplaySeconds := Max(0.0, PreDisplaySeconds);
  LyricsEdit.Text := FilterLyrics;
  RebuildFilterLyricUnits;
  LoadSyncStages(SyncText);
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

function TFormLyricsMusicSyncSettings.SyncText: string;
var
  GroupIndex: Integer;
  LastNonZero: Integer;
  Stages: TArray<Integer>;
begin
  SetLength(Stages, Length(FSyncEditGroups));
  for GroupIndex := 0 to High(FSyncEditGroups) do
  begin
    if FSyncEditGroups[GroupIndex].UnitCount > 1 then
      Stages[GroupIndex] := -(FSyncEditGroups[GroupIndex].UnitCount - 1)
    else
      Stages[GroupIndex] := FSyncEditGroups[GroupIndex].NoteCount - 1;
  end;
  LastNonZero := High(Stages);
  while (LastNonZero >= 0) and (Stages[LastNonZero] = 0) do
    Dec(LastNonZero);
  SetLength(Stages, LastNonZero + 1);
  Result := SerializeMusicSyncText(Stages);
end;

procedure TFormLyricsMusicSyncSettings.AppendEditGroup(
  var Groups: TMusicSyncEditGroups; UnitCount, NoteCount: Integer);
var
  GroupIndex: Integer;
begin
  if UnitCount <= 0 then
    Exit;
  GroupIndex := Length(Groups);
  SetLength(Groups, GroupIndex + 1);
  if GroupIndex = 0 then
    Groups[GroupIndex].UnitStart := 0
  else
    Groups[GroupIndex].UnitStart :=
      Groups[GroupIndex - 1].UnitStart +
      Groups[GroupIndex - 1].UnitCount;
  Groups[GroupIndex].UnitCount := UnitCount;
  Groups[GroupIndex].NoteCount := Max(1, NoteCount);
end;

procedure TFormLyricsMusicSyncSettings.AppendPreservedGroups(
  const Source: TMusicSyncEditGroups; FirstUnit, LastUnit: Integer;
  var Dest: TMusicSyncEditGroups);
var
  GroupEnd: Integer;
  GroupIndex: Integer;
  IntersectionEnd: Integer;
  IntersectionStart: Integer;
  PreservedNoteCount: Integer;
begin
  if FirstUnit > LastUnit then
    Exit;
  for GroupIndex := 0 to High(Source) do
  begin
    GroupEnd := Source[GroupIndex].UnitStart +
      Source[GroupIndex].UnitCount - 1;
    IntersectionStart := Max(FirstUnit,
      Source[GroupIndex].UnitStart);
    IntersectionEnd := Min(LastUnit, GroupEnd);
    if IntersectionStart > IntersectionEnd then
      Continue;
    if Source[GroupIndex].UnitCount = 1 then
      PreservedNoteCount := Source[GroupIndex].NoteCount
    else
      PreservedNoteCount := 1;
    AppendEditGroup(Dest,
      IntersectionEnd - IntersectionStart + 1,
      PreservedNoteCount);
  end;
end;

procedure TFormLyricsMusicSyncSettings.ApplyLyricDragStep(
  Step: Integer);
var
  DesiredGroupIndex: Integer;
  DesiredStart: Integer;
  LeftUnitCount: Integer;
  NewGroups: TMusicSyncEditGroups;
  RightUnitCount: Integer;
  TotalUnitCount: Integer;
begin
  if (FSelectedLyricIndex < 0) or
    (FSelectedLyricIndex >= Length(FFilterLyricUnits)) then
    Exit;
  FSyncEditGroups := Copy(FLyricDragOriginalGroups);
  if Step = 0 then
  begin
    RebuildUnitNoteIndexes;
    PianoRollPaintBox.Invalidate;
    Exit;
  end;

  TotalUnitCount := Length(FFilterLyricUnits);
  SetLength(NewGroups, 0);
  if Step < 0 then
  begin
    // 1文字ずつではなく1グループずつ左へ結合する。直前の歌詞が
    // 既に共有グループ内なら、そのグループ開始位置まで一度に含める。
    DesiredGroupIndex := Max(0, FLyricDragGroupIndex + Step);
    DesiredStart :=
      FLyricDragOriginalGroups[DesiredGroupIndex].UnitStart;
    AppendPreservedGroups(FLyricDragOriginalGroups, 0,
      DesiredStart - 1, NewGroups);
    AppendEditGroup(NewGroups,
      FLyricDragGroupEnd - DesiredStart + 1, 1);
    AppendPreservedGroups(FLyricDragOriginalGroups,
      FLyricDragGroupEnd + 1, TotalUnitCount - 1, NewGroups);
  end;
  if Step > 0 then
  begin
    if FLyricDragGroupEnd > FLyricDragGroupStart then
    begin
      // 共有中は選択文字だけをグループから切り離す。同じドラッグで
      // 自分の音数は増やさず、左右に残る文字はそれぞれ共有を維持する。
      AppendPreservedGroups(FLyricDragOriginalGroups, 0,
        FLyricDragGroupStart - 1, NewGroups);
      LeftUnitCount := FSelectedLyricIndex - FLyricDragGroupStart;
      RightUnitCount := FLyricDragGroupEnd - FSelectedLyricIndex;
      AppendEditGroup(NewGroups, LeftUnitCount, 1);
      AppendEditGroup(NewGroups, 1, 1);
      AppendEditGroup(NewGroups, RightUnitCount, 1);
      AppendPreservedGroups(FLyricDragOriginalGroups,
        FLyricDragGroupEnd + 1, TotalUnitCount - 1, NewGroups);
    end
    else
    begin
      // 共有がなければ、選択歌詞が担当する音数を現在値から増やす。
      AppendPreservedGroups(FLyricDragOriginalGroups, 0,
        FLyricDragGroupStart - 1, NewGroups);
      AppendEditGroup(NewGroups, 1,
        Min(64, FLyricDragGroupNoteCount + Step));
      AppendPreservedGroups(FLyricDragOriginalGroups,
        FLyricDragGroupEnd + 1, TotalUnitCount - 1, NewGroups);
    end;
  end;
  FSyncEditGroups := NewGroups;
  RebuildUnitNoteIndexes;
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.PianoRollPaintBoxMouseDown(
  Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  LinePosition: Integer;
  LyricIndex: Integer;
begin
  if Button <> mbLeft then
    Exit;
  LinePosition := GetPreDisplayLinePosition;
  if (LinePosition >= 0) and
    (Abs(X - LinePosition) <= PRE_DISPLAY_HIT_MARGIN) then
  begin
    FDraggingPreDisplay := True;
    TCapturePaintBox(PianoRollPaintBox).MouseCapture := True;
    PianoRollPaintBox.Cursor := crSizeWE;
    SetPreDisplayFromMouse(X);
    Exit;
  end;

  LyricIndex := HitTestFilterLyric(X, Y);
  if LyricIndex >= 0 then
  begin
    FSelectedLyricIndex := LyricIndex;
    if (LyricIndex >= Length(FUnitGroupIndexes)) or
      (FUnitGroupIndexes[LyricIndex] < 0) then
      Exit;
    FDraggingLyric := True;
    FLyricDragStartX := X;
    FLyricDragStep := 0;
    FLyricDragOriginalGroups := Copy(FSyncEditGroups);
    FLyricDragGroupIndex := FUnitGroupIndexes[LyricIndex];
    with FSyncEditGroups[FLyricDragGroupIndex] do
    begin
      FLyricDragGroupStart := UnitStart;
      FLyricDragGroupEnd := UnitStart + UnitCount - 1;
      FLyricDragGroupNoteCount := NoteCount;
    end;
    TCapturePaintBox(PianoRollPaintBox).MouseCapture := True;
    PianoRollPaintBox.Cursor := crSizeWE;
    PianoRollPaintBox.Invalidate;
  end;
end;

procedure TFormLyricsMusicSyncSettings.PianoRollPaintBoxMouseMove(
  Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  DragStep: Integer;
  LinePosition: Integer;
begin
  if FDraggingPreDisplay then
  begin
    SetPreDisplayFromMouse(X);
    PianoRollPaintBox.Cursor := crSizeWE;
    Exit;
  end;

  if FDraggingLyric then
  begin
    if X >= FLyricDragStartX then
      DragStep := (X - FLyricDragStartX) div LYRIC_DRAG_STEP_PIXELS
    else
      DragStep := -((FLyricDragStartX - X) div LYRIC_DRAG_STEP_PIXELS);
    if DragStep <> FLyricDragStep then
    begin
      FLyricDragStep := DragStep;
      ApplyLyricDragStep(DragStep);
    end;
    PianoRollPaintBox.Cursor := crSizeWE;
    Exit;
  end;

  LinePosition := GetPreDisplayLinePosition;
  if (LinePosition >= 0) and
    (Abs(X - LinePosition) <= PRE_DISPLAY_HIT_MARGIN) then
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
    TCapturePaintBox(PianoRollPaintBox).MouseCapture := False;
  end
  else
    Exit;
  PianoRollPaintBoxMouseMove(Sender, Shift, X, Y);
end;

procedure TFormLyricsMusicSyncSettings.PianoRollPaintBoxPaint(
  Sender: TObject);
var
  BottomPosition: Integer;
  Canvas: TCanvas;
  HighestKey: Integer;
  I: Integer;
  Key: Integer;
  KeyName: string;
  KeyTextWidth: Integer;
  KeyThickness: Double;
  LeftPosition: Integer;
  LowestKey: Integer;
  FilterLyric: string;
  FilterLyricRect: TRect;
  FilterTextX: Integer;
  FilterStartSeconds: Double;
  Note: TMusicNoteStart;
  NoteColor: TColor;
  PianoHeight: Integer;
  PianoWidth: Integer;
  PreDisplayPosition: Integer;
  RightPosition: Integer;
  SecondIndex: Integer;
  SyncNoteIndex: Integer;
  SyncNoteIndexForNote: Integer;
  TimeWidth: Integer;
  TextHeight: Integer;
  TextWidth: Integer;
  TextY: Integer;
  TopPosition: Integer;
  PitchSpan: Double;
  UnitIndex: Integer;
  X: Integer;
begin
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
  Canvas.Brush.Color := RGB(20, 24, 32);
  Canvas.FillRect(Rect(0, 0, PianoWidth, PianoHeight));
  if (PianoWidth <= PIANO_ROLL_KEYBOARD_WIDTH) or (PianoHeight <= 0) then
    Exit;

  ResolvePitchRange(LowestKey, HighestKey);
  PitchSpan := GetPianoKeyPitchCenter(HighestKey) -
    GetPianoKeyPitchCenter(LowestKey) + 1.0;
  KeyThickness := PianoHeight / Max(1.0, PitchSpan);
  TimeWidth := PianoWidth - PIANO_ROLL_KEYBOARD_WIDTH;
  FilterStartSeconds := FAnchorSeconds + FPreDisplaySeconds;
  SyncNoteIndex := 0;
  for I := 0 to High(FFilterLyricHitRects) do
    FFilterLyricHitRects[I] := Rect(0, 0, 0, 0);

  // 背景レーンは白鍵・黒鍵に関係なく、半音ごとに同じ高さで敷く。
  for Key := LowestKey to HighestKey do
    if not IsBlackKey(Key) then
    begin
      GetLaneAxisBounds(PianoHeight, Key, LowestKey, HighestKey,
        KeyThickness, TopPosition, BottomPosition);
      Canvas.Brush.Color := RGB(43, 48, 58);
      Canvas.FillRect(Rect(PIANO_ROLL_KEYBOARD_WIDTH, TopPosition,
        PianoWidth, BottomPosition));
    end;

  for Key := LowestKey to HighestKey do
    if IsBlackKey(Key) then
    begin
      GetLaneAxisBounds(PianoHeight, Key, LowestKey, HighestKey,
        KeyThickness, TopPosition, BottomPosition);
      Canvas.Brush.Color := RGB(27, 31, 40);
      Canvas.FillRect(Rect(PIANO_ROLL_KEYBOARD_WIDTH, TopPosition,
        PianoWidth, BottomPosition));
    end;

  Canvas.Pen.Color := RGB(82, 89, 104);
  for SecondIndex := 1 to Trunc(PIANO_ROLL_DISPLAY_SECONDS) do
  begin
    X := PIANO_ROLL_KEYBOARD_WIDTH +
      Round(SecondIndex / PIANO_ROLL_DISPLAY_SECONDS * TimeWidth);
    Canvas.MoveTo(X, 0);
    Canvas.LineTo(X, PianoHeight);
  end;

  // 連続した白鍵を先に描き、黒鍵を白鍵の境界へ短く重ねる。
  for Key := LowestKey to HighestKey do
    if not IsBlackKey(Key) then
    begin
      GetKeyAxisBounds(PianoHeight, Key, LowestKey, HighestKey,
        KeyThickness, TopPosition, BottomPosition);
      Canvas.Brush.Color := RGB(232, 234, 238);
      Canvas.Pen.Color := RGB(130, 134, 142);
      Canvas.Rectangle(0, TopPosition, PIANO_ROLL_KEYBOARD_WIDTH,
        BottomPosition);
    end;

  for Key := LowestKey to HighestKey do
    if IsBlackKey(Key) then
    begin
      GetKeyAxisBounds(PianoHeight, Key, LowestKey, HighestKey,
        KeyThickness, TopPosition, BottomPosition);
      Canvas.Brush.Color := RGB(25, 27, 32);
      Canvas.Pen.Color := RGB(8, 9, 11);
      Canvas.Rectangle(0, TopPosition,
        Round(PIANO_ROLL_KEYBOARD_WIDTH * 0.62), BottomPosition);
    end;

  for I := 0 to High(FNotes) do
  begin
    Note := FNotes[I];
    SyncNoteIndexForNote := -1;
    if Note.Seconds >= FilterStartSeconds then
    begin
      SyncNoteIndexForNote := SyncNoteIndex;
      Inc(SyncNoteIndex);
    end;
    if (Note.Key < LowestKey) or (Note.Key > HighestKey) or
      (Note.Seconds > FAnchorSeconds + PIANO_ROLL_DISPLAY_SECONDS) then
      Continue;
    LeftPosition := PIANO_ROLL_KEYBOARD_WIDTH +
      Round((Max(Note.Seconds, FAnchorSeconds) - FAnchorSeconds) /
      PIANO_ROLL_DISPLAY_SECONDS * TimeWidth);
    RightPosition := PIANO_ROLL_KEYBOARD_WIDTH +
      Round((Max(Note.EndSeconds, Note.Seconds + 0.05) - FAnchorSeconds) /
      PIANO_ROLL_DISPLAY_SECONDS * TimeWidth);
    RightPosition := Min(PianoWidth, Max(LeftPosition + 2, RightPosition));
    GetNoteAxisBounds(PianoHeight, Note.Key, LowestKey, HighestKey,
      KeyThickness, TopPosition, BottomPosition);

    NoteColor := RGB(45, 180, 225);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := NoteColor;
    Canvas.Pen.Color := RGB(135, 225, 250);
    Canvas.Rectangle(LeftPosition, TopPosition, RightPosition,
      BottomPosition);

    KeyName := GetKeyName(Note.Key);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -12;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := RGB(12, 45, 58);
    KeyTextWidth := Canvas.TextWidth(KeyName);
    Canvas.TextRect(Rect(LeftPosition + 1, TopPosition,
      RightPosition - 1, BottomPosition),
      LeftPosition + 3, TopPosition, KeyName);

    if Trim(Note.Lyric) <> '' then
    begin
      Canvas.Font.Height := -12;
      Canvas.Font.Style := [];
      Canvas.Font.Color := RGB(12, 45, 58);
      Canvas.TextRect(Rect(
        Min(RightPosition - 1, LeftPosition + KeyTextWidth + 7),
        TopPosition, RightPosition - 1, BottomPosition),
        LeftPosition + KeyTextWidth + 7, TopPosition, Note.Lyric);
    end;

    if SyncNoteIndexForNote >= 0 then
    begin
      FilterTextX := LeftPosition;
      for UnitIndex := 0 to High(FFilterLyricUnits) do
        if (UnitIndex < Length(FUnitNoteIndexes)) and
          (FUnitNoteIndexes[UnitIndex] = SyncNoteIndexForNote) then
        begin
          FilterLyric := FFilterLyricUnits[UnitIndex];
          if FilterLyric = '' then
            Continue;
        Canvas.Font.Height := -13;
        Canvas.Font.Style := [];
        Canvas.Font.Color := RGB(238, 242, 248);
        TextHeight := Canvas.TextHeight(FilterLyric);
        TextWidth := Canvas.TextWidth(FilterLyric);
        TextY := BottomPosition + FILTER_LYRIC_NOTE_MARGIN;
        FilterLyricRect := Rect(FilterTextX, TextY,
          Min(PianoWidth, FilterTextX + TextWidth + 2),
          Min(PianoHeight, TextY + TextHeight + 1));
        Canvas.TextRect(FilterLyricRect,
          FilterTextX, TextY, FilterLyric);
        if UnitIndex < Length(FFilterLyricHitRects) then
          FFilterLyricHitRects[UnitIndex] := Rect(
            FilterLyricRect.Left - 3, FilterLyricRect.Top - 2,
            FilterLyricRect.Right + 2,
            Min(PianoHeight, FilterLyricRect.Bottom + 2));

        if UnitIndex = FSelectedLyricIndex then
        begin
          Canvas.Brush.Style := bsClear;
          Canvas.Pen.Width := 2;
          Canvas.Pen.Color := RGB(255, 210, 70);
          Canvas.Rectangle(FFilterLyricHitRects[UnitIndex]);
          Canvas.Pen.Width := 1;
        end;
        Inc(FilterTextX, TextWidth + 2);
      end;
    end;
    Canvas.Brush.Style := bsSolid;
  end;

  Canvas.Pen.Width := 2;
  Canvas.Pen.Color := RGB(255, 210, 70);
  Canvas.MoveTo(PIANO_ROLL_KEYBOARD_WIDTH, 0);
  Canvas.LineTo(PIANO_ROLL_KEYBOARD_WIDTH, PianoHeight);

  if FPreDisplaySeconds <= PIANO_ROLL_DISPLAY_SECONDS then
  begin
    PreDisplayPosition := GetPreDisplayLinePosition;
    Canvas.Pen.Color := RGB(255, 105, 180);
    Canvas.MoveTo(PreDisplayPosition, 0);
    Canvas.LineTo(PreDisplayPosition, PianoHeight);
  end;
  Canvas.Pen.Width := 1;

  if FLoadMessage <> '' then
  begin
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -14;
    Canvas.Font.Style := [];
    Canvas.Font.Color := RGB(210, 215, 224);
    TextWidth := Canvas.TextWidth(FLoadMessage);
    TextHeight := Canvas.TextHeight(FLoadMessage);
    Canvas.TextOut(
      PIANO_ROLL_KEYBOARD_WIDTH + (TimeWidth - TextWidth) div 2,
      (PianoHeight - TextHeight) div 2,
      FLoadMessage);
    Canvas.Brush.Style := bsSolid;
  end;
  finally
    // 完成した1枚だけを転送し、ドラッグ中の背景消去と部分描画を画面へ見せない。
    PianoRollPaintBox.Canvas.Draw(0, 0, FPianoRollBuffer);
  end;
end;

procedure TFormLyricsMusicSyncSettings.RebuildFilterLyricUnits;
var
  I: Integer;
  PlainText: string;
  RubySpans: TLyricsRubySpans;
  Units: TLyricsDisplayUnits;
begin
  ParseLyrics(LyricsEdit.Text, PlainText, RubySpans);
  BuildLyricsDisplayUnits(PlainText, RubySpans, Units);
  SetLength(FFilterLyricUnits, Length(Units));
  SetLength(FFilterLyricHitRects, Length(Units));
  for I := 0 to High(Units) do
    FFilterLyricUnits[I] := Copy(PlainText, Units[I].BaseStart,
      Units[I].BaseLength);
  ResizeEditGroups(Length(Units));
  if Length(FFilterLyricUnits) = 0 then
    FSelectedLyricIndex := -1
  else if FSelectedLyricIndex < 0 then
    FSelectedLyricIndex := 0
  else
    FSelectedLyricIndex := Min(FSelectedLyricIndex,
      High(FFilterLyricUnits));
  RebuildUnitNoteIndexes;
end;

procedure TFormLyricsMusicSyncSettings.RebuildUnitNoteIndexes;
var
  GroupIndex: Integer;
  I: Integer;
  NoteIndex: Integer;
begin
  SetLength(FUnitGroupIndexes, Length(FFilterLyricUnits));
  SetLength(FUnitNoteIndexes, Length(FFilterLyricUnits));
  for I := 0 to High(FUnitGroupIndexes) do
  begin
    FUnitGroupIndexes[I] := -1;
    FUnitNoteIndexes[I] := -1;
  end;
  NoteIndex := 0;
  for GroupIndex := 0 to High(FSyncEditGroups) do
  begin
    for I := FSyncEditGroups[GroupIndex].UnitStart to
      Min(High(FUnitNoteIndexes),
        FSyncEditGroups[GroupIndex].UnitStart +
        FSyncEditGroups[GroupIndex].UnitCount - 1) do
    begin
      FUnitGroupIndexes[I] := GroupIndex;
      FUnitNoteIndexes[I] := NoteIndex;
    end;
    Inc(NoteIndex, FSyncEditGroups[GroupIndex].NoteCount);
  end;
end;

procedure TFormLyricsMusicSyncSettings.ResizeEditGroups(
  UnitCount: Integer);
var
  NewGroups: TMusicSyncEditGroups;
  PreservedCount: Integer;
begin
  SetLength(NewGroups, 0);
  PreservedCount := Min(UnitCount, Length(FUnitGroupIndexes));
  if PreservedCount > 0 then
    AppendPreservedGroups(FSyncEditGroups, 0,
      PreservedCount - 1, NewGroups);
  while PreservedCount < UnitCount do
  begin
    AppendEditGroup(NewGroups, 1, 1);
    Inc(PreservedCount);
  end;
  FSyncEditGroups := NewGroups;
  RebuildUnitNoteIndexes;
end;

procedure TFormLyricsMusicSyncSettings.SetPreDisplayFromMouse(X: Integer);
var
  TimeWidth: Integer;
begin
  TimeWidth := PianoRollPaintBox.ClientWidth - PIANO_ROLL_KEYBOARD_WIDTH;
  if TimeWidth <= 0 then
    Exit;
  FPreDisplaySeconds := EnsureRange(
    (X - PIANO_ROLL_KEYBOARD_WIDTH) / TimeWidth *
    PIANO_ROLL_DISPLAY_SECONDS, 0.0, PIANO_ROLL_DISPLAY_SECONDS);
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.ResolvePitchRange(
  out LowestKey, HighestKey: Integer);
var
  CenterKey: Integer;
  HasVisibleNote: Boolean;
  I: Integer;
begin
  LowestKey := 60;
  HighestKey := 60;
  HasVisibleNote := False;
  for I := 0 to High(FNotes) do
    if FNotes[I].Seconds <=
      FAnchorSeconds + PIANO_ROLL_DISPLAY_SECONDS then
    begin
      if not HasVisibleNote then
      begin
        LowestKey := FNotes[I].Key;
        HighestKey := FNotes[I].Key;
        HasVisibleNote := True;
      end
      else
      begin
        LowestKey := Min(LowestKey, FNotes[I].Key);
        HighestKey := Max(HighestKey, FNotes[I].Key);
      end;
    end;

  CenterKey := (LowestKey + HighestKey) div 2;
  if HighestKey - LowestKey + 1 < PIANO_ROLL_MIN_VISIBLE_KEYS then
  begin
    LowestKey := CenterKey - PIANO_ROLL_MIN_VISIBLE_KEYS div 2;
    HighestKey := LowestKey + PIANO_ROLL_MIN_VISIBLE_KEYS - 1;
  end
  else
  begin
    Dec(LowestKey, 2);
    Inc(HighestKey, 2);
  end;
  LowestKey := EnsureRange(LowestKey, 0, 127);
  HighestKey := EnsureRange(HighestKey, 0, 127);
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
