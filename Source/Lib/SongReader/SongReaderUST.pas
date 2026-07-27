unit SongReaderUST;

interface

uses
  SysUtils,Classes,SongData,TextEncodingUtils,SongReader;

type
  //========================================================
  // 正規化ノート（共通構造）
  //========================================================
  TNormalizedNote = record
    TrackIndex : Integer;
    TickOn     : Integer;
    TickOff    : Integer;
    Key        : Integer;
    Lyric      : string;
  end;

  //========================================================
  // UST Reader
  //========================================================
  TSongReaderUST = class(TSongReader)
  private
    // ---- main flow ----
    procedure ParseUST(const Lines: TStrings; SongData: TSongData);

    // ---- init ----
    procedure InitDefaults(SongData: TSongData);

    // ---- section handling ----
    function  IsSectionLine(const Line: string; out Section: string): Boolean;
    function  IsNoteSection(const Section: string): Boolean;

    // ---- header ----
    procedure ParseHeaderLine(const Section, Line: string; SongData: TSongData);
    procedure ApplyTempoBPM(BPM: Double; SongData: TSongData);

    // ---- note ----
    procedure BeginNoteSection;
    procedure ParseNoteLine(const Line: string);
    procedure CommitNoteSection(SongData: TSongData);

    // ---- helpers ----
    function  ParseKeyValue(const Line: string; out Key, Value: string): Boolean;
    function  TryParseTempo(const S: string; out BPM: Double): Boolean;

    // ---- normalized register ----
    procedure AddNormalizedNote(const Note: TNormalizedNote; SongData: TSongData);
    function  TickToSec(Tick: Integer; SongData: TSongData): Double;

  private
    // ---- parse state ----
    FCurrentSection : string;
    FCurrentTick    : Integer;

    FHasNoteSection : Boolean;
    FNoteLength     : Integer;
    FNoteLyric      : string;
    FNoteNum        : Integer;
    FHasNoteNum     : Boolean;
  public
    function LoadFromFile(const FileName: string; SongData: TSongData): Boolean;override;
  end;

implementation

{==========================================================
  Load
==========================================================}
function TSongReaderUST.LoadFromFile(const FileName: string; SongData: TSongData) : Boolean;
var
  Lines : TStringList;
  Text  : string;
begin
  Lines := TStringList.Create;
  try
    // エンコード自動判定はユーティリティに完全委譲
    Text := LoadTextAutoEncoding(FileName);

    // 改行分解（CRLF / LF / CR すべて TStringList に任せる）
    Lines.Text := Text;

    ParseUST(Lines, SongData);
    Result := True;
  finally
    Lines.Free;
  end;
end;


{==========================================================
  Defaults
==========================================================}
procedure TSongReaderUST.InitDefaults(SongData: TSongData);
begin
  // 仮想解像度
  SongData.Info.Division := 480;

  // 仮想テンポ（SETTINGで上書きされる）
  ApplyTempoBPM(120.0, SongData);

  // 仮想トラック（USTは1トラック）
  SongData.Tracks.AddTrackName(0, '');
end;

{==========================================================
  Main Parse
==========================================================}
procedure TSongReaderUST.ParseUST(const Lines: TStrings; SongData: TSongData);
var
  i: Integer;
  Line, Section: string;
begin
  InitDefaults(SongData);

  FCurrentTick    := 0;
  FCurrentSection := '';
  FHasNoteSection := False;

  for i := 0 to Lines.Count - 1 do
  begin
    Line := Trim(Lines[i]);
    if Line = '' then Continue;
    if Line[1] = ';' then Continue;

    if IsSectionLine(Line, Section) then
    begin
      CommitNoteSection(SongData);
      FCurrentSection := Section;

      if SameText(Section, '#TRACKEND') then
        Break;

      if IsNoteSection(Section) then
        BeginNoteSection
      else
        FHasNoteSection := False;

      Continue;
    end;

    if SameText(FCurrentSection, '#SETTING') then
    begin
      ParseHeaderLine(FCurrentSection, Line, SongData);
      Continue;
    end;

    if FHasNoteSection then
      ParseNoteLine(Line);
  end;

  CommitNoteSection(SongData);
end;

{==========================================================
  Section helpers
==========================================================}
function TSongReaderUST.IsSectionLine(const Line: string; out Section: string): Boolean;
begin
  Result := False;
  Section := '';

  if (Line.StartsWith('[')) and (Line.EndsWith(']')) then
  begin
    Section := Copy(Line, 2, Length(Line) - 2);
    Result := Section <> '';
  end;
end;

function TSongReaderUST.IsNoteSection(const Section: string): Boolean;
var
  S: string;
  i: Integer;
begin
  Result := False;
  if not Section.StartsWith('#') then Exit;

  S := Copy(Section, 2, MaxInt);
  if S = '' then Exit;

  for i := 1 to Length(S) do
    if not CharInSet(S[i], ['0'..'9']) then
      Exit;

  Result := True;
end;

{==========================================================
  Header
==========================================================}
procedure TSongReaderUST.ParseHeaderLine(
  const Section, Line: string; SongData: TSongData);
var
  Key, Val: string;
  BPM: Double;
begin
  if not ParseKeyValue(Line, Key, Val) then Exit;

  if SameText(Key, 'Tempo') then
    if TryParseTempo(Val, BPM) then
      ApplyTempoBPM(BPM, SongData);
end;

procedure TSongReaderUST.ApplyTempoBPM(BPM: Double; SongData: TSongData);
var
  UsPerQuarter: Double;
begin
  if BPM <= 0 then Exit;
  UsPerQuarter := 60000000.0 / BPM;
  SongData.Tempos.AddTempo(0, UsPerQuarter, SongData.Info.Division);
end;

{==========================================================
  Note section
==========================================================}
procedure TSongReaderUST.BeginNoteSection;
begin
  FHasNoteSection := True;
  FNoteLength := 0;
  FNoteLyric  := '';
  FNoteNum    := 60;
  FHasNoteNum := False;
end;

procedure TSongReaderUST.ParseNoteLine(const Line: string);
var
  Key, Val: string;
begin
  if not ParseKeyValue(Line, Key, Val) then Exit;

  if SameText(Key, 'Length') then
    TryStrToInt(Val, FNoteLength)
  else if SameText(Key, 'Lyric') then
    FNoteLyric := Val
  else if SameText(Key, 'NoteNum') then
    if TryStrToInt(Val, FNoteNum) then
      FHasNoteNum := True;
end;

procedure TSongReaderUST.CommitNoteSection(SongData: TSongData);
var
  Note  : TNormalizedNote;
  IsRest: Boolean;
begin
  if not FHasNoteSection then Exit;

  // 休符判定
  IsRest := (Trim(FNoteLyric) = '') or SameText(Trim(FNoteLyric), 'R');

  // --- ノート生成（発声する場合のみ） ---
  if (FNoteLength > 0) and (not IsRest) then
  begin
    Note.TrackIndex := 0;
    Note.TickOn     := FCurrentTick;
    Note.TickOff    := FCurrentTick + FNoteLength;
    Note.Key        := FNoteNum;
    Note.Lyric      := FNoteLyric;

    AddNormalizedNote(Note, SongData);
  end;

  // --- ★重要：必ず時間を進める ---
  if FNoteLength > 0 then
    Inc(FCurrentTick, FNoteLength);

  // セクション終了
  FHasNoteSection := False;
end;


{==========================================================
  Helpers
==========================================================}
function TSongReaderUST.ParseKeyValue(
  const Line: string; out Key, Value: string): Boolean;
var
  p: Integer;
begin
  Result := False;
  p := Pos('=', Line);
  if p <= 0 then Exit;

  Key   := Trim(Copy(Line, 1, p - 1));
  Value := Copy(Line, p + 1, MaxInt);
  Result := Key <> '';
end;

function TSongReaderUST.TryParseTempo(
  const S: string; out BPM: Double): Boolean;
var
  T: string;
begin
  T := StringReplace(Trim(S), ',', '.', [rfReplaceAll]);
  Result := TryStrToFloat(T, BPM, TFormatSettings.Invariant);
  if not Result then
    Result := TryStrToFloat(T, BPM);
end;

{==========================================================
  Common register
==========================================================}
procedure TSongReaderUST.AddNormalizedNote(
  const Note: TNormalizedNote; SongData: TSongData);
var
  SecOn, SecOff: Double;
begin
  SecOn  := TickToSec(Note.TickOn, SongData);
  SecOff := TickToSec(Note.TickOff, SongData);

  SongData.Notes.AddNoteOn(Note.TrackIndex, Note.Key, 100, SecOn);
  SongData.Notes.AddNoteOff(Note.TrackIndex, Note.Key, SecOff);

  if Trim(Note.Lyric) <> '' then
    SongData.Notes.AddLyric(Note.TrackIndex, SecOn, Note.Lyric);
end;

function TSongReaderUST.TickToSec(Tick: Integer; SongData: TSongData): Double;
begin
  Result := SongData.Tempos.DeltaToSec(Tick, SongData.Info.Division);
end;

end.

