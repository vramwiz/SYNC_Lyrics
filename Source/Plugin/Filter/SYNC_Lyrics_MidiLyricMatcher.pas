unit SYNC_Lyrics_MidiLyricMatcher;

// ルビの読みとMIDI歌詞を全曲で照合し、曲同期の段階値を作る。

interface

uses
  SYNC_Lyrics_MusicSync,
  SYNC_Lyrics_SongLyricsModel;

function TryAssignMidiLyricSync(const Notes: TMusicNoteStarts;
  PreDisplaySeconds: Double; const SongModel: TLyricsSongModel;
  out MatchCost: Double): Boolean;

implementation

uses
  System.Math,
  System.SysUtils,
  SYNC_Lyrics_MusicSyncEditModel,
  SYNC_Lyrics_SyncFormat;

type
  TMatchUnit = record
    LineIndex: Integer;
    Reading: string;
  end;
  TMatchUnits = TArray<TMatchUnit>;
  TDoubleRow = TArray<Double>;
  TDoubleMatrix = TArray<TDoubleRow>;
  TIntRow = TArray<Integer>;
  TIntMatrix = TArray<TIntRow>;
  TMatchStep = record
    UnitCount: Integer;
    NoteCount: Integer;
  end;
  TMatchSteps = TArray<TMatchStep>;

function NormalizeReading(const Text: string): string;
var
  C: Char;
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(Text) do
  begin
    C := Text[I];
    if (C >= #$30A1) and (C <= #$30F6) then
      C := Char(Ord(C) - $60);
    if ((C >= #$3041) and (C <= #$3096)) or
      ((C >= 'a') and (C <= 'z')) or
      ((C >= 'A') and (C <= 'Z')) or
      ((C >= '0') and (C <= '9')) or (C = 'ー') then
      Result := Result + C;
  end;
end;

function EditDistance(const LeftText, RightText: string): Integer;
var
  Current: TIntRow;
  I: Integer;
  J: Integer;
  Previous: TIntRow;
begin
  SetLength(Previous, Length(RightText) + 1);
  SetLength(Current, Length(RightText) + 1);
  for J := 0 to High(Previous) do
    Previous[J] := J;
  for I := 1 to Length(LeftText) do
  begin
    Current[0] := I;
    for J := 1 to Length(RightText) do
      Current[J] := Min(Min(Previous[J] + 1, Current[J - 1] + 1),
        Previous[J - 1] + Ord(LeftText[I] <> RightText[J]));
    Previous := Copy(Current);
  end;
  Result := Previous[Length(RightText)];
end;

function BuildUnits(const SongModel: TLyricsSongModel): TMatchUnits;
var
  I: Integer;
  J: Integer;
  Model: TMusicSyncEditModel;
begin
  SetLength(Result, 0);
  Model := TMusicSyncEditModel.Create;
  try
    for I := 0 to SongModel.LineCount - 1 do
    begin
      Model.SetLyrics(SongModel[I].SourceText);
      for J := 0 to High(Model.Units) do
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)].LineIndex := I;
        if ((Model.Units[J].Text = #$FF15) or
            (Model.Units[J].Text = '5')) and
          (J < High(Model.Units)) and
          (Model.Units[J + 1].Text = #$3064) then
          Result[High(Result)].Reading := Char($3044) + Char($3064)
        else if Model.Units[J].RubyText <> '' then
          Result[High(Result)].Reading := NormalizeReading(
            Model.Units[J].RubyText)
        else
          Result[High(Result)].Reading := NormalizeReading(
            Model.Units[J].Text);
      end;
    end;
  finally
    Model.Free;
  end;
end;

function Align(const Units: TMatchUnits; const Notes: TMusicNoteStarts;
  out Steps: TMatchSteps; out MatchCost: Double): Boolean;
const
  MAX_NOTES_PER_UNIT = 8;
  MAX_UNITS_PER_NOTE = 4;
var
  Candidate: Double;
  Costs: TDoubleMatrix;
  I: Integer;
  J: Integer;
  K: Integer;
  NoteReading: string;
  PrevNotes: TIntMatrix;
  PrevUnits: TIntMatrix;
  Step: TMatchStep;
  UnitReading: string;
begin
  Result := False;
  SetLength(Steps, 0);
  MatchCost := 0;
  if (Length(Units) = 0) or (Length(Notes) = 0) then
    Exit;
  SetLength(Costs, Length(Units) + 1);
  SetLength(PrevUnits, Length(Units) + 1);
  SetLength(PrevNotes, Length(Units) + 1);
  for I := 0 to High(Costs) do
  begin
    SetLength(Costs[I], Length(Notes) + 1);
    SetLength(PrevUnits[I], Length(Notes) + 1);
    SetLength(PrevNotes[I], Length(Notes) + 1);
    for J := 0 to High(Costs[I]) do
      Costs[I][J] := 1.0e30;
  end;
  Costs[0][0] := 0;
  for I := 0 to High(Units) do
    for J := 0 to High(Notes) do
    begin
      if Costs[I][J] >= 1.0e29 then
        Continue;
      UnitReading := Units[I].Reading;
      NoteReading := '';
      for K := 1 to Min(MAX_NOTES_PER_UNIT, Length(Notes) - J) do
      begin
        NoteReading := NoteReading + NormalizeReading(Notes[J + K - 1].Lyric);
        Candidate := Costs[I][J] + EditDistance(UnitReading,
          NoteReading) + (K - 1) * 0.05;
        if Candidate < Costs[I + 1][J + K] then
        begin
          Costs[I + 1][J + K] := Candidate;
          PrevUnits[I + 1][J + K] := 1;
          PrevNotes[I + 1][J + K] := K;
        end;
      end;
      UnitReading := Units[I].Reading;
      NoteReading := NormalizeReading(Notes[J].Lyric);
      for K := 2 to Min(MAX_UNITS_PER_NOTE, Length(Units) - I) do
      begin
        if Units[I + K - 1].LineIndex <> Units[I].LineIndex then
          Break;
        UnitReading := UnitReading + Units[I + K - 1].Reading;
        Candidate := Costs[I][J] + EditDistance(UnitReading,
          NoteReading) + (K - 1) * 0.05;
        if Candidate < Costs[I + K][J + 1] then
        begin
          Costs[I + K][J + 1] := Candidate;
          PrevUnits[I + K][J + 1] := K;
          PrevNotes[I + K][J + 1] := 1;
        end;
      end;
    end;
  MatchCost := Costs[Length(Units)][Length(Notes)];
  if MatchCost >= 1.0e29 then
    Exit;
  I := Length(Units);
  J := Length(Notes);
  while (I > 0) and (J > 0) do
  begin
    Step.UnitCount := PrevUnits[I][J];
    Step.NoteCount := PrevNotes[I][J];
    if (Step.UnitCount < 1) or (Step.NoteCount < 1) then
      Exit;
    SetLength(Steps, Length(Steps) + 1);
    Steps[High(Steps)] := Step;
    Dec(I, Step.UnitCount);
    Dec(J, Step.NoteCount);
  end;
  if (I <> 0) or (J <> 0) then
    Exit;
  for I := 0 to Length(Steps) div 2 - 1 do
  begin
    Step := Steps[I];
    Steps[I] := Steps[High(Steps) - I];
    Steps[High(Steps) - I] := Step;
  end;
  Result := True;
end;

function TryAssignMidiLyricSync(const Notes: TMusicNoteStarts;
  PreDisplaySeconds: Double; const SongModel: TLyricsSongModel;
  out MatchCost: Double): Boolean;
var
  I: Integer;
  LineIndex: Integer;
  Stages: TSyncIntegerArray;
  Step: TMatchStep;
  Steps: TMatchSteps;
  UnitIndex: Integer;
  Units: TMatchUnits;
begin
  Result := False;
  MatchCost := 0;
  if SongModel = nil then
    Exit;
  for I := 0 to SongModel.LineCount - 1 do
    if SongModel[I].SyncState in [lssConfirmed, lssInconsistent] then
      Exit;
  for I := 0 to High(Notes) do
    if NormalizeReading(Notes[I].Lyric) = '' then
      Exit;
  Units := BuildUnits(SongModel);
  if not Align(Units, Notes, Steps, MatchCost) or
    (MatchCost > Length(Units) * 0.8) then
    Exit;
  UnitIndex := 0;
  LineIndex := 0;
  SetLength(Stages, 0);
  for I := 0 to High(Steps) do
  begin
    Step := Steps[I];
    if (UnitIndex < Length(Units)) and
      (Units[UnitIndex].LineIndex <> LineIndex) then
    begin
      SongModel.TrySetSync(LineIndex, PreDisplaySeconds,
        SerializeMusicSyncText(Stages));
      Inc(LineIndex);
      SetLength(Stages, 0);
    end;
    SetLength(Stages, Length(Stages) + 1);
    if Step.UnitCount > 1 then
      Stages[High(Stages)] := 1 - Step.UnitCount
    else
      Stages[High(Stages)] := Step.NoteCount - 1;
    Inc(UnitIndex, Step.UnitCount);
  end;
  if Length(Stages) > 0 then
    SongModel.TrySetSync(LineIndex, PreDisplaySeconds,
      SerializeMusicSyncText(Stages));
  Result := True;
end;

end.
