unit SYNC_Lyrics_MusicSyncSettingsForm;

// 曲同期編集の基準位置と、音楽データの最小ピアノロール表示を提供する。

interface

uses
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  SYNC_Lyrics_MusicSync;

type
  TFormLyricsMusicSyncSettings = class(TForm)
    AnchorDescriptionLabel: TLabel;
    AnchorFrameLabel: TLabel;
    AnchorTimeLabel: TLabel;
    MusicFileLabel: TLabel;
    MusicFileEdit: TEdit;
    TrackLabel: TLabel;
    TrackValueLabel: TLabel;
    PianoRollLabel: TLabel;
    PianoRollPaintBox: TPaintBox;
    PianoRollStatusLabel: TLabel;
    BottomPanel: TPanel;
    CloseButton: TButton;
    procedure PianoRollPaintBoxPaint(Sender: TObject);
  private
    FAnchorAvailable: Boolean;
    FAnchorSeconds: Double;
    FNotes: TMusicNoteStarts;
    function IsBlackKey(Key: Integer): Boolean;
    procedure LoadPianoRoll(const MusicFileName: string; Track: Integer);
    procedure ResolvePitchRange(out LowestKey, HighestKey: Integer);
  public
    // Filterが最後に発火した絶対位置を、この編集画面の基準として表示する。
    procedure SetAnchor(Frame, Rate, Scale: Integer);
    // Filterがまだ発火していないため基準位置を取得できないことを表示する。
    procedure SetAnchorUnavailable;
    // 音楽ファイルとトラックを読み込み、基準位置から未来側のピアノロールを準備する。
    procedure LoadSettings(const MusicFileName: string; Track: Integer);
  end;

implementation

uses
  System.Math,
  System.Types,
  Winapi.Windows;

{$R *.dfm}

const
  PIANO_ROLL_DISPLAY_SECONDS = 6.0;
  PIANO_ROLL_KEYBOARD_WIDTH = 76;
  PIANO_ROLL_MIN_VISIBLE_KEYS = 24;

function TFormLyricsMusicSyncSettings.IsBlackKey(Key: Integer): Boolean;
var
  PitchClass: Integer;
begin
  PitchClass := Key mod 12;
  if PitchClass < 0 then
    Inc(PitchClass, 12);
  Result := PitchClass in [1, 3, 6, 8, 10];
end;

procedure TFormLyricsMusicSyncSettings.LoadPianoRoll(
  const MusicFileName: string; Track: Integer);
var
  AllNotes: TMusicNoteStarts;
  I: Integer;
  NoteCount: Integer;
begin
  SetLength(FNotes, 0);
  if not FAnchorAvailable then
  begin
    PianoRollStatusLabel.Caption :=
      'Filterを一度描画して基準位置を取得してください。';
    PianoRollPaintBox.Invalidate;
    Exit;
  end;
  if MusicFileName = '' then
  begin
    PianoRollStatusLabel.Caption := '音楽ファイルが指定されていません。';
    PianoRollPaintBox.Invalidate;
    Exit;
  end;
  if not LoadMusicNoteStarts(MusicFileName, AllNotes) then
  begin
    PianoRollStatusLabel.Caption := '音楽ファイルを読み込めませんでした。';
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
  PianoRollStatusLabel.Caption := Format(
    '基準から %.1f 秒先までを表示 / 読み込みノート %d個',
    [PIANO_ROLL_DISPLAY_SECONDS, NoteCount]);
  PianoRollPaintBox.Invalidate;
end;

procedure TFormLyricsMusicSyncSettings.LoadSettings(
  const MusicFileName: string; Track: Integer);
begin
  MusicFileEdit.Text := MusicFileName;
  TrackValueLabel.Caption := IntToStr(Track);
  LoadPianoRoll(MusicFileName, Track);
end;

procedure TFormLyricsMusicSyncSettings.PianoRollPaintBoxPaint(
  Sender: TObject);
var
  BottomPosition: Integer;
  Canvas: TCanvas;
  HighestKey: Integer;
  I: Integer;
  Key: Integer;
  LaneHeight: Double;
  LeftPosition: Integer;
  LowestKey: Integer;
  Note: TMusicNoteStart;
  NoteColor: TColor;
  PianoHeight: Integer;
  PianoWidth: Integer;
  RightPosition: Integer;
  SecondIndex: Integer;
  TimeWidth: Integer;
  TopPosition: Integer;
  VisibleKeyCount: Integer;
  X: Integer;
begin
  Canvas := PianoRollPaintBox.Canvas;
  PianoWidth := PianoRollPaintBox.ClientWidth;
  PianoHeight := PianoRollPaintBox.ClientHeight;
  Canvas.Brush.Color := RGB(20, 24, 32);
  Canvas.FillRect(Rect(0, 0, PianoWidth, PianoHeight));
  if (PianoWidth <= PIANO_ROLL_KEYBOARD_WIDTH) or (PianoHeight <= 0) then
    Exit;

  ResolvePitchRange(LowestKey, HighestKey);
  VisibleKeyCount := HighestKey - LowestKey + 1;
  LaneHeight := PianoHeight / Max(1, VisibleKeyCount);
  TimeWidth := PianoWidth - PIANO_ROLL_KEYBOARD_WIDTH;

  for Key := LowestKey to HighestKey do
  begin
    TopPosition := Round((HighestKey - Key) * LaneHeight);
    BottomPosition := Round((HighestKey - Key + 1) * LaneHeight);
    if IsBlackKey(Key) then
      Canvas.Brush.Color := RGB(27, 31, 40)
    else
      Canvas.Brush.Color := RGB(43, 48, 58);
    Canvas.FillRect(Rect(PIANO_ROLL_KEYBOARD_WIDTH, TopPosition,
      PianoWidth, BottomPosition));

    Canvas.Pen.Color := RGB(58, 63, 73);
    Canvas.MoveTo(PIANO_ROLL_KEYBOARD_WIDTH, BottomPosition - 1);
    Canvas.LineTo(PianoWidth, BottomPosition - 1);

    // 黒鍵の右側が暗いレーンと連続して見えないよう、鍵盤領域は白鍵面を下地にする。
    Canvas.Brush.Color := RGB(232, 234, 238);
    Canvas.Pen.Color := RGB(130, 134, 142);
    Canvas.Rectangle(0, TopPosition, PIANO_ROLL_KEYBOARD_WIDTH,
      BottomPosition);
    if IsBlackKey(Key) then
    begin
      Canvas.Brush.Color := RGB(25, 27, 32);
      Canvas.Pen.Color := RGB(8, 9, 11);
      Canvas.Rectangle(0, TopPosition,
        Round(PIANO_ROLL_KEYBOARD_WIDTH * 0.64), BottomPosition);
    end;
  end;

  Canvas.Pen.Color := RGB(82, 89, 104);
  for SecondIndex := 1 to Trunc(PIANO_ROLL_DISPLAY_SECONDS) do
  begin
    X := PIANO_ROLL_KEYBOARD_WIDTH +
      Round(SecondIndex / PIANO_ROLL_DISPLAY_SECONDS * TimeWidth);
    Canvas.MoveTo(X, 0);
    Canvas.LineTo(X, PianoHeight);
  end;

  for I := 0 to High(FNotes) do
  begin
    Note := FNotes[I];
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
    TopPosition := Round((HighestKey - Note.Key) * LaneHeight + 1);
    BottomPosition := Round((HighestKey - Note.Key + 1) * LaneHeight - 1);
    BottomPosition := Max(TopPosition + 1, BottomPosition);

    NoteColor := RGB(45, 180, 225);
    Canvas.Brush.Color := NoteColor;
    Canvas.Pen.Color := RGB(135, 225, 250);
    Canvas.Rectangle(LeftPosition, TopPosition, RightPosition,
      BottomPosition);
  end;

  Canvas.Pen.Width := 2;
  Canvas.Pen.Color := RGB(255, 210, 70);
  Canvas.MoveTo(PIANO_ROLL_KEYBOARD_WIDTH, 0);
  Canvas.LineTo(PIANO_ROLL_KEYBOARD_WIDTH, PianoHeight);
  Canvas.Pen.Width := 1;
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
  AnchorFrameLabel.Caption := Format('基準絶対フレーム: %d', [Frame]);
  if FAnchorAvailable then
  begin
    FAnchorSeconds := Frame * Scale / Rate;
    AnchorTimeLabel.Caption := Format('基準時刻: %.3f 秒  (%d/%d fps)',
      [FAnchorSeconds, Rate, Scale]);
  end
  else
    AnchorTimeLabel.Caption := '基準時刻: 取得できません';
end;

procedure TFormLyricsMusicSyncSettings.SetAnchorUnavailable;
begin
  FAnchorAvailable := False;
  FAnchorSeconds := 0;
  AnchorFrameLabel.Caption := '基準絶対フレーム: 未取得';
  AnchorTimeLabel.Caption :=
    '基準時刻: Filterを一度描画してから開いてください';
end;

end.
