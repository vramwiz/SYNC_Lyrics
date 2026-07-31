unit SYNC_Lyrics_SongLyricsModel;

// Holds the editable whole-song lyrics lines independently from VCL controls.

interface

uses
  SYNC_Lyrics_LyricParser;

type
  TLyricsLineSyncState = (lssUnset, lssProvisional, lssConfirmed,
    lssInconsistent);

  TLyricsSongLine = record
    LineID     : Int64; // Stable identity within one song model.
    SourceText : string; // Editable lyrics text including ruby syntax.
    PlainText  : string; // Parsed text used by lists and drawing.
    RubySpans  : TLyricsRubySpans;
    DisplayLane: Byte; // One-based display lane in the supported range 1..3.
    SyncState  : TLyricsLineSyncState;
    StartNoteIndex: Integer; // Zero-based index in the shared eligible music-note sequence.
    PreDisplaySeconds: Double;
    HoldSeconds: Double;
    SyncText   : string;
    DisplayStartFrame: Int64;
    DisplayEndFrame: Int64;
    SyncStartFrame: Int64;
    SyncEndFrame: Int64;
    TimingMusicOffsetSeconds: Double;
    PlacementText: string;
  end;
  TLyricsSongLines = TArray<TLyricsSongLine>;

  TLyricsSongModel = class
  private
    FLines: TLyricsSongLines;
    FNextLineID: Int64;
    function GetLine(Index: Integer): TLyricsSongLine;
    function GetLineCount: Integer;
    procedure InitializeLine(var LineData: TLyricsSongLine;
      const SourceText: string);
    procedure RecalculateNoteOffsets;
  public
    constructor Create;
    procedure Clear;
    // Replaces the whole working set; blank source lines are omitted.
    procedure SetLyricsText(const LyricsText: string);
    // Rebuilds the editable whole-song text in current display order.
    function LyricsText: string;
    // Persistence uses copies so decoding cannot partially mutate the working model.
    function CopyLines: TLyricsSongLines;
    procedure ReplaceLines(const Lines: TLyricsSongLines);
    // These operations preserve the stable identities of unaffected lines.
    function TryDeleteLine(Index: Integer): Boolean;
    function TryInsertLine(Index: Integer; const SourceText: string): Boolean;
    function TrySetLineText(Index: Integer;
      const SourceText: string): Boolean;
    function TrySetStartFrames(Index: Integer; DisplayStartFrame,
      SyncStartFrame: Int64): Boolean;
    function TrySetEndFrames(Index: Integer; DisplayEndFrame,
      SyncEndFrame: Int64): Boolean;
    function TrySetDisplayLane(Index, DisplayLane: Integer): Boolean;
    function TrySetPlacementText(Index: Integer;
      const PlacementText: string): Boolean;
    function TryConfirmSync(Index: Integer; PreDisplaySeconds: Double;
      const SyncText: string): Boolean;
    function TrySetSync(Index: Integer; PreDisplaySeconds: Double;
      const SyncText: string): Boolean;
    function TrySetSyncState(Index: Integer;
      SyncState: TLyricsLineSyncState): Boolean;
    // Rebuilds object-local display ranges from the shared music-note sequence.
    procedure RecalculateMusicFrameRanges(const MusicFileName: string;
      Track: Integer; SequenceStartSeconds, MusicOffsetSeconds,
      DefaultPreDisplaySeconds: Double; Rate, Scale: Integer);
    property LineCount: Integer read GetLineCount;
    property Lines[Index: Integer]: TLyricsSongLine read GetLine; default;
  end;

implementation

uses
  System.Classes,
  System.Math,
  System.SysUtils,
  SYNC_Lyrics_MusicSync,
  SYNC_Lyrics_SyncFormat;

const
  DEFAULT_LYRICS_HOLD_SECONDS = 0.5;

constructor TLyricsSongModel.Create;
begin
  inherited Create;
  FNextLineID := 1;
end;

procedure TLyricsSongModel.Clear;
begin
  SetLength(FLines, 0);
  FNextLineID := 1;
end;

function TLyricsSongModel.GetLine(Index: Integer): TLyricsSongLine;
begin
  if (Index < 0) or (Index >= Length(FLines)) then
    raise EArgumentOutOfRangeException.Create('Lyrics line index is out of range.');
  Result := FLines[Index];
end;

function TLyricsSongModel.GetLineCount: Integer;
begin
  Result := Length(FLines);
end;

function TLyricsSongModel.CopyLines: TLyricsSongLines;
begin
  Result := Copy(FLines);
end;

procedure TLyricsSongModel.InitializeLine(var LineData: TLyricsSongLine;
  const SourceText: string);
begin
  LineData.LineID := FNextLineID;
  Inc(FNextLineID);
  LineData.SourceText := SourceText;
  ParseLyrics(LineData.SourceText, LineData.PlainText,
    LineData.RubySpans);
  LineData.DisplayLane := 1;
  LineData.SyncState := lssUnset;
  LineData.StartNoteIndex := -1;
  LineData.PreDisplaySeconds := -1;
  LineData.HoldSeconds := DEFAULT_LYRICS_HOLD_SECONDS;
  LineData.SyncText := '';
  LineData.DisplayStartFrame := -1;
  LineData.DisplayEndFrame := -1;
  LineData.SyncStartFrame := -1;
  LineData.SyncEndFrame := -1;
  LineData.TimingMusicOffsetSeconds := 0;
  LineData.PlacementText := '';
end;

procedure TLyricsSongModel.RecalculateMusicFrameRanges(
  const MusicFileName: string; Track: Integer; SequenceStartSeconds,
  MusicOffsetSeconds, DefaultPreDisplaySeconds: Double;
  Rate, Scale: Integer);
var
  DisplayStartSeconds: Double;
  EffectivePreDisplaySeconds: Double;
  I: Integer;
  RequiredNoteCount: Integer;
  SyncEndSeconds: Double;
  SyncStartSeconds: Double;
begin
  if (Rate <= 0) or (Scale <= 0) then
    Exit;
  for I := 0 to High(FLines) do
  begin
    RequiredNoteCount := CountMusicSyncRequiredNotes(
      FLines[I].SyncText,
      CountLyricsDisplayUnits(FLines[I].SourceText));
    if not TryResolveMusicSyncTimeRange(MusicFileName, Track,
      ObjectSecondsToMusicSeconds(SequenceStartSeconds,
        MusicOffsetSeconds), FLines[I].StartNoteIndex,
      RequiredNoteCount, SyncStartSeconds, SyncEndSeconds) then
    begin
      FLines[I].DisplayStartFrame := -1;
      FLines[I].DisplayEndFrame := -1;
      FLines[I].SyncStartFrame := -1;
      FLines[I].SyncEndFrame := -1;
      Continue;
    end;
    SyncStartSeconds := MusicSecondsToObjectSeconds(
      SyncStartSeconds, MusicOffsetSeconds);
    SyncEndSeconds := MusicSecondsToObjectSeconds(
      SyncEndSeconds, MusicOffsetSeconds);
    EffectivePreDisplaySeconds := FLines[I].PreDisplaySeconds;
    if EffectivePreDisplaySeconds < 0 then
      EffectivePreDisplaySeconds := DefaultPreDisplaySeconds;
    DisplayStartSeconds := Max(0,
      SyncStartSeconds - Max(0, EffectivePreDisplaySeconds));
    FLines[I].SyncStartFrame := Floor(
      SyncStartSeconds * Rate / Scale);
    FLines[I].SyncEndFrame := Max(FLines[I].SyncStartFrame,
      Ceil(SyncEndSeconds * Rate / Scale) - 1);
    FLines[I].DisplayStartFrame := Floor(
      DisplayStartSeconds * Rate / Scale);
    FLines[I].DisplayEndFrame := Max(FLines[I].DisplayStartFrame,
      Ceil((SyncEndSeconds + Max(0, FLines[I].HoldSeconds)) *
        Rate / Scale) - 1);
    FLines[I].TimingMusicOffsetSeconds := MusicOffsetSeconds;
  end;
end;

function TLyricsSongModel.LyricsText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FLines) do
  begin
    if I > 0 then
      Result := Result + sLineBreak;
    Result := Result + FLines[I].SourceText;
  end;
end;

procedure TLyricsSongModel.RecalculateNoteOffsets;
var
  ConsumedNoteCount: Integer;
  I: Integer;
  NextNoteIndex: Integer;
begin
  NextNoteIndex := 0;
  for I := 0 to High(FLines) do
  begin
    ConsumedNoteCount := CountMusicSyncRequiredNotes(
      FLines[I].SyncText,
      CountLyricsDisplayUnits(FLines[I].SourceText));
    if (FLines[I].StartNoteIndex < 0) or
      (FLines[I].SyncState = lssUnset) then
      FLines[I].StartNoteIndex := NextNoteIndex;
    NextNoteIndex := FLines[I].StartNoteIndex + ConsumedNoteCount;
  end;
end;

procedure TLyricsSongModel.ReplaceLines(const Lines: TLyricsSongLines);
var
  I: Integer;
begin
  FLines := Copy(Lines);
  FNextLineID := 1;
  for I := 0 to High(FLines) do
  begin
    ParseLyrics(FLines[I].SourceText, FLines[I].PlainText,
      FLines[I].RubySpans);
    if FLines[I].LineID >= FNextLineID then
      FNextLineID := FLines[I].LineID + 1;
  end;
  RecalculateNoteOffsets;
end;

procedure TLyricsSongModel.SetLyricsText(const LyricsText: string);
var
  I: Integer;
  LineIndex: Integer;
  SourceLines: TStringList;
begin
  Clear;
  SourceLines := TStringList.Create;
  try
    SourceLines.Text := LyricsText;
    for I := 0 to SourceLines.Count - 1 do
    begin
      if Trim(SourceLines[I]) = '' then
        Continue;
      LineIndex := Length(FLines);
      SetLength(FLines, LineIndex + 1);
      InitializeLine(FLines[LineIndex], SourceLines[I]);
    end;
  finally
    SourceLines.Free;
  end;
  RecalculateNoteOffsets;
end;

function TLyricsSongModel.TryDeleteLine(Index: Integer): Boolean;
var
  I: Integer;
begin
  Result := (Index >= 0) and (Index < Length(FLines));
  if not Result then
    Exit;
  for I := Index to High(FLines) - 1 do
    FLines[I] := FLines[I + 1];
  SetLength(FLines, Length(FLines) - 1);
  RecalculateNoteOffsets;
end;

function TLyricsSongModel.TryInsertLine(Index: Integer;
  const SourceText: string): Boolean;
var
  I: Integer;
begin
  Result := (Index >= 0) and (Index <= Length(FLines)) and
    (Trim(SourceText) <> '');
  if not Result then
    Exit;
  SetLength(FLines, Length(FLines) + 1);
  for I := High(FLines) downto Index + 1 do
    FLines[I] := FLines[I - 1];
  InitializeLine(FLines[Index], SourceText);
  RecalculateNoteOffsets;
end;

function TLyricsSongModel.TrySetLineText(Index: Integer;
  const SourceText: string): Boolean;
begin
  Result := (Index >= 0) and (Index < Length(FLines)) and
    (Trim(SourceText) <> '');
  if not Result then
    Exit;
  if FLines[Index].SourceText = SourceText then
    Exit;
  FLines[Index].SourceText := SourceText;
  ParseLyrics(FLines[Index].SourceText, FLines[Index].PlainText,
    FLines[Index].RubySpans);
  FLines[Index].PlacementText := '';
  if (FLines[Index].SyncState <> lssUnset) or
    (FLines[Index].SyncText <> '') then
    FLines[Index].SyncState := lssInconsistent;
  RecalculateNoteOffsets;
end;

function TLyricsSongModel.TrySetStartFrames(Index: Integer;
  DisplayStartFrame, SyncStartFrame: Int64): Boolean;
var
  TimingChanged: Boolean;
begin
  Result := (Index >= 0) and (Index < Length(FLines)) and
    (DisplayStartFrame >= 0) and (SyncStartFrame >= DisplayStartFrame);
  if not Result then
    Exit;
  TimingChanged :=
    (FLines[Index].DisplayStartFrame <> DisplayStartFrame) or
    (FLines[Index].SyncStartFrame <> SyncStartFrame);
  FLines[Index].DisplayStartFrame := DisplayStartFrame;
  FLines[Index].SyncStartFrame := SyncStartFrame;
  if TimingChanged and (FLines[Index].SyncState = lssConfirmed) then
    FLines[Index].SyncState := lssInconsistent;
end;

function TLyricsSongModel.TrySetEndFrames(Index: Integer;
  DisplayEndFrame, SyncEndFrame: Int64): Boolean;
begin
  Result := (Index >= 0) and (Index < Length(FLines)) and
    (DisplayEndFrame >= 0) and (SyncEndFrame >= 0) and
    ((FLines[Index].DisplayStartFrame < 0) or
     (DisplayEndFrame >= FLines[Index].DisplayStartFrame)) and
    ((FLines[Index].SyncStartFrame < 0) or
     (SyncEndFrame >= FLines[Index].SyncStartFrame));
  if not Result then
    Exit;
  FLines[Index].DisplayEndFrame := DisplayEndFrame;
  FLines[Index].SyncEndFrame := SyncEndFrame;
end;

function TLyricsSongModel.TrySetDisplayLane(Index,
  DisplayLane: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index < Length(FLines)) and
    (DisplayLane >= 1) and (DisplayLane <= 3);
  if Result then
    FLines[Index].DisplayLane := DisplayLane;
end;

function TLyricsSongModel.TrySetPlacementText(Index: Integer;
  const PlacementText: string): Boolean;
begin
  Result := (Index >= 0) and (Index < Length(FLines)) and
    (Pos(#10, PlacementText) = 0) and (Pos(#13, PlacementText) = 0);
  if Result then
    FLines[Index].PlacementText := PlacementText;
end;

function TLyricsSongModel.TryConfirmSync(Index: Integer;
  PreDisplaySeconds: Double; const SyncText: string): Boolean;
begin
  Result := TrySetSync(Index, PreDisplaySeconds, SyncText);
  if Result then
    FLines[Index].SyncState := lssConfirmed;
end;

function TLyricsSongModel.TrySetSync(Index: Integer;
  PreDisplaySeconds: Double; const SyncText: string): Boolean;
var
  PreviousState: TLyricsLineSyncState;
begin
  Result := (Index >= 0) and (Index < Length(FLines));
  if not Result then
    Exit;
  PreviousState := FLines[Index].SyncState;
  FLines[Index].PreDisplaySeconds := PreDisplaySeconds;
  FLines[Index].SyncText := SyncText;
  if PreviousState = lssConfirmed then
    FLines[Index].SyncState := lssInconsistent
  else if SyncText = '' then
    FLines[Index].SyncState := lssUnset
  else
    FLines[Index].SyncState := lssProvisional;
  RecalculateNoteOffsets;
end;

function TLyricsSongModel.TrySetSyncState(Index: Integer;
  SyncState: TLyricsLineSyncState): Boolean;
begin
  Result := (Index >= 0) and (Index < Length(FLines));
  if Result then
  begin
    FLines[Index].SyncState := SyncState;
    RecalculateNoteOffsets;
  end;
end;

end.
