unit SYNC_Lyrics_MusicSyncPianoRoll;

// 曲同期GUIの鍵盤、音程レーン、時間線、音楽ノートを描画する。
// 歌詞描画層へ、同期開始後の各ノート矩形と固定レーン境界を提供する。

interface

uses
  System.Types,
  Vcl.Graphics,
  SYNC_Lyrics_MusicSync;

const
  MUSIC_SYNC_DISPLAY_SECONDS = 6.0;
  MUSIC_SYNC_KEYBOARD_WIDTH = 76;
  MUSIC_SYNC_FIXED_LYRIC_HEIGHT = 58;

type
  TPianoRollLayout = record
    RollHeight: Integer;
    TimeWidth: Integer;
    SyncNoteRects: TArray<TRect>;
  end;

// ピアノロール本体を描画し、歌詞層が使用する時間・ノート座標を返す。
procedure DrawMusicSyncPianoRoll(Canvas: TCanvas; PianoWidth,
  PianoHeight: Integer; const Notes: TMusicNoteStarts;
  AnchorSeconds, PreDisplaySeconds: Double; out Layout: TPianoRollLayout);

// 歌詞層の後から基準線と事前表示線を重ねる。
procedure DrawMusicSyncMarkers(Canvas: TCanvas; PianoHeight,
  PianoWidth: Integer; PreDisplaySeconds: Double);

implementation

uses
  System.Math,
  System.SysUtils,
  Winapi.Windows;

const
  MIN_VISIBLE_KEYS = 24;

function IsBlackKey(Key: Integer): Boolean;
var
  PitchClass: Integer;
begin
  PitchClass := Key mod 12;
  if PitchClass < 0 then
    Inc(PitchClass, 12);
  Result := PitchClass in [1, 3, 6, 8, 10];
end;

function KeyName(MidiKey: Integer): string;
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

procedure ResolvePitchRange(const Notes: TMusicNoteStarts;
  AnchorSeconds: Double; out LowestKey, HighestKey: Integer);
var
  CenterKey: Integer;
  HasVisibleNote: Boolean;
  I: Integer;
begin
  LowestKey := 60;
  HighestKey := 60;
  HasVisibleNote := False;
  for I := 0 to High(Notes) do
    if Notes[I].Seconds <= AnchorSeconds + MUSIC_SYNC_DISPLAY_SECONDS then
    begin
      if not HasVisibleNote then
      begin
        LowestKey := Notes[I].Key;
        HighestKey := Notes[I].Key;
        HasVisibleNote := True;
      end
      else
      begin
        LowestKey := Min(LowestKey, Notes[I].Key);
        HighestKey := Max(HighestKey, Notes[I].Key);
      end;
    end;
  CenterKey := (LowestKey + HighestKey) div 2;
  if HighestKey - LowestKey + 1 < MIN_VISIBLE_KEYS then
  begin
    LowestKey := CenterKey - MIN_VISIBLE_KEYS div 2;
    HighestKey := LowestKey + MIN_VISIBLE_KEYS - 1;
  end
  else
  begin
    Dec(LowestKey, 2);
    Inc(HighestKey, 2);
  end;
  LowestKey := EnsureRange(LowestKey, 0, 127);
  HighestKey := EnsureRange(HighestKey, 0, 127);
end;

function PitchCenter(CanvasHeight, MidiKey, LowestKey, HighestKey: Integer;
  KeyThickness: Double): Double;
var
  RangeCenter: Double;
begin
  RangeCenter := (LowestKey + HighestKey) * 0.5;
  Result := CanvasHeight * 0.5 -
    (MidiKey - RangeCenter) * KeyThickness;
end;

procedure LaneBounds(CanvasHeight, MidiKey, LowestKey, HighestKey: Integer;
  KeyThickness: Double; out TopPosition, BottomPosition: Integer);
var
  Center: Double;
begin
  Center := PitchCenter(CanvasHeight, MidiKey, LowestKey, HighestKey,
    KeyThickness);
  TopPosition := Round(Center - KeyThickness * 0.5);
  BottomPosition := Round(Center + KeyThickness * 0.5);
  if BottomPosition <= TopPosition then
    BottomPosition := TopPosition + 1;
end;

procedure KeyBounds(CanvasHeight, MidiKey, LowestKey, HighestKey: Integer;
  KeyThickness: Double; out TopPosition, BottomPosition: Integer);
var
  Center: Double;
  VisibleThickness: Double;
begin
  Center := PitchCenter(CanvasHeight, MidiKey, LowestKey, HighestKey,
    KeyThickness);
  if IsBlackKey(MidiKey) then
    VisibleThickness := KeyThickness * 0.62
  else
    VisibleThickness := KeyThickness;
  TopPosition := Round(Center - VisibleThickness * 0.5);
  BottomPosition := Round(Center + VisibleThickness * 0.5);
  if BottomPosition <= TopPosition then
    BottomPosition := TopPosition + 1;
end;

procedure NoteBounds(CanvasHeight, MidiKey, LowestKey, HighestKey: Integer;
  KeyThickness: Double; out TopPosition, BottomPosition: Integer);
var
  Center: Double;
  NoteHeight: Integer;
begin
  Center := PitchCenter(CanvasHeight, MidiKey, LowestKey, HighestKey,
    KeyThickness);
  NoteHeight := Max(3, Round(KeyThickness * 0.8));
  TopPosition := Round(Center - NoteHeight * 0.5);
  BottomPosition := TopPosition + NoteHeight;
end;

procedure DrawMusicSyncPianoRoll(Canvas: TCanvas; PianoWidth,
  PianoHeight: Integer; const Notes: TMusicNoteStarts;
  AnchorSeconds, PreDisplaySeconds: Double; out Layout: TPianoRollLayout);
var
  BottomPosition: Integer;
  HighestKey: Integer;
  I: Integer;
  Key: Integer;
  KeyText: string;
  KeyTextWidth: Integer;
  KeyThickness: Double;
  LeftPosition: Integer;
  LowestKey: Integer;
  Note: TMusicNoteStart;
  RightPosition: Integer;
  SecondIndex: Integer;
  SyncNoteIndex: Integer;
  SyncNoteIndexForNote: Integer;
  TopPosition: Integer;
  X: Integer;
begin
  Layout.RollHeight := Max(1, PianoHeight - MUSIC_SYNC_FIXED_LYRIC_HEIGHT);
  Layout.TimeWidth := Max(0, PianoWidth - MUSIC_SYNC_KEYBOARD_WIDTH);
  SetLength(Layout.SyncNoteRects, Length(Notes));
  for I := 0 to High(Layout.SyncNoteRects) do
    Layout.SyncNoteRects[I] := Rect(0, 0, 0, 0);

  Canvas.Brush.Color := RGB(20, 24, 32);
  Canvas.FillRect(Rect(0, 0, PianoWidth, PianoHeight));
  if (Layout.TimeWidth <= 0) or (Layout.RollHeight <= 0) then
    Exit;
  ResolvePitchRange(Notes, AnchorSeconds, LowestKey, HighestKey);
  KeyThickness := Layout.RollHeight /
    Max(1, HighestKey - LowestKey + 1);

  for Key := LowestKey to HighestKey do
  begin
    LaneBounds(Layout.RollHeight, Key, LowestKey, HighestKey,
      KeyThickness, TopPosition, BottomPosition);
    if IsBlackKey(Key) then
      Canvas.Brush.Color := RGB(27, 31, 40)
    else
      Canvas.Brush.Color := RGB(43, 48, 58);
    Canvas.FillRect(Rect(MUSIC_SYNC_KEYBOARD_WIDTH, TopPosition,
      PianoWidth, BottomPosition));
  end;

  Canvas.Pen.Color := RGB(82, 89, 104);
  for SecondIndex := 1 to Trunc(MUSIC_SYNC_DISPLAY_SECONDS) do
  begin
    X := MUSIC_SYNC_KEYBOARD_WIDTH +
      Round(SecondIndex / MUSIC_SYNC_DISPLAY_SECONDS * Layout.TimeWidth);
    Canvas.MoveTo(X, 0);
    Canvas.LineTo(X, Layout.RollHeight);
  end;

  for Key := LowestKey to HighestKey do
    if not IsBlackKey(Key) then
    begin
      KeyBounds(Layout.RollHeight, Key, LowestKey, HighestKey,
        KeyThickness, TopPosition, BottomPosition);
      Canvas.Brush.Color := RGB(232, 234, 238);
      Canvas.Pen.Color := RGB(130, 134, 142);
      Canvas.Rectangle(0, TopPosition, MUSIC_SYNC_KEYBOARD_WIDTH,
        BottomPosition);
    end;
  for Key := LowestKey to HighestKey do
    if IsBlackKey(Key) then
    begin
      KeyBounds(Layout.RollHeight, Key, LowestKey, HighestKey,
        KeyThickness, TopPosition, BottomPosition);
      Canvas.Brush.Color := RGB(25, 27, 32);
      Canvas.Pen.Color := RGB(8, 9, 11);
      Canvas.Rectangle(0, TopPosition,
        Round(MUSIC_SYNC_KEYBOARD_WIDTH * 0.62), BottomPosition);
    end;

  SyncNoteIndex := 0;
  for I := 0 to High(Notes) do
  begin
    Note := Notes[I];
    SyncNoteIndexForNote := -1;
    if Note.Seconds >= AnchorSeconds + PreDisplaySeconds then
    begin
      SyncNoteIndexForNote := SyncNoteIndex;
      Inc(SyncNoteIndex);
    end;
    if Note.Seconds > AnchorSeconds + MUSIC_SYNC_DISPLAY_SECONDS then
      Continue;
    LeftPosition := MUSIC_SYNC_KEYBOARD_WIDTH +
      Round((Max(Note.Seconds, AnchorSeconds) - AnchorSeconds) /
        MUSIC_SYNC_DISPLAY_SECONDS * Layout.TimeWidth);
    RightPosition := MUSIC_SYNC_KEYBOARD_WIDTH +
      Round((Max(Note.EndSeconds, Note.Seconds + 0.05) - AnchorSeconds) /
        MUSIC_SYNC_DISPLAY_SECONDS * Layout.TimeWidth);
    RightPosition := Min(PianoWidth, Max(LeftPosition + 2, RightPosition));
    if SyncNoteIndexForNote >= 0 then
      Layout.SyncNoteRects[SyncNoteIndexForNote] :=
        Rect(LeftPosition, 0, RightPosition, 0);
    if (Note.Key < LowestKey) or (Note.Key > HighestKey) then
      Continue;

    NoteBounds(Layout.RollHeight, Note.Key, LowestKey, HighestKey,
      KeyThickness, TopPosition, BottomPosition);
    if SyncNoteIndexForNote >= 0 then
      Layout.SyncNoteRects[SyncNoteIndexForNote] :=
        Rect(LeftPosition, TopPosition, RightPosition, BottomPosition);
    Canvas.Brush.Style := bsSolid;
    Canvas.Brush.Color := RGB(45, 180, 225);
    Canvas.Pen.Color := RGB(135, 225, 250);
    Canvas.Rectangle(LeftPosition, TopPosition, RightPosition,
      BottomPosition);

    KeyText := KeyName(Note.Key);
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -12;
    Canvas.Font.Style := [fsBold];
    Canvas.Font.Color := RGB(12, 45, 58);
    KeyTextWidth := Canvas.TextWidth(KeyText);
    Canvas.TextRect(Rect(LeftPosition + 1, TopPosition,
      RightPosition - 1, BottomPosition),
      LeftPosition + 3, TopPosition, KeyText);
    if Trim(Note.Lyric) <> '' then
    begin
      Canvas.Font.Style := [];
      Canvas.TextRect(Rect(
        Min(RightPosition - 1, LeftPosition + KeyTextWidth + 7),
        TopPosition, RightPosition - 1, BottomPosition),
        LeftPosition + KeyTextWidth + 7, TopPosition, Note.Lyric);
    end;
    Canvas.Brush.Style := bsSolid;
  end;
end;

procedure DrawMusicSyncMarkers(Canvas: TCanvas; PianoHeight,
  PianoWidth: Integer; PreDisplaySeconds: Double);
var
  PreDisplayPosition: Integer;
  TimeWidth: Integer;
begin
  TimeWidth := PianoWidth - MUSIC_SYNC_KEYBOARD_WIDTH;
  Canvas.Pen.Width := 2;
  Canvas.Pen.Color := RGB(255, 210, 70);
  Canvas.MoveTo(MUSIC_SYNC_KEYBOARD_WIDTH, 0);
  Canvas.LineTo(MUSIC_SYNC_KEYBOARD_WIDTH, PianoHeight);
  if (TimeWidth > 0) and
    (PreDisplaySeconds <= MUSIC_SYNC_DISPLAY_SECONDS) then
  begin
    PreDisplayPosition := MUSIC_SYNC_KEYBOARD_WIDTH +
      Round(PreDisplaySeconds / MUSIC_SYNC_DISPLAY_SECONDS * TimeWidth);
    Canvas.Pen.Color := RGB(255, 105, 180);
    Canvas.MoveTo(PreDisplayPosition, 0);
    Canvas.LineTo(PreDisplayPosition, PianoHeight);
  end;
  Canvas.Pen.Width := 1;
end;

end.
