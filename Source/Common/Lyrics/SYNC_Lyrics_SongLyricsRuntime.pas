unit SYNC_Lyrics_SongLyricsRuntime;

// Caches decoded whole-song text and resolves the line active at an object-local frame.

interface

uses
  SYNC_Lyrics_SongLyricsModel;

type
  TLyricsSongLineIndexes = TArray<Integer>;

procedure InitializeSongLyricsRuntime;
procedure FinalizeSongLyricsRuntime;
function TryGetSongLyricsLines(const DataText: string;
  out Lines: TLyricsSongLines): Boolean;
function ResolveSongLyricsLineIndex(const Lines: TLyricsSongLines;
  LocalFrame: Int64): Integer;
function ResolveSongLyricsLineIndexes(const Lines: TLyricsSongLines;
  LocalFrame: Int64): TLyricsSongLineIndexes;
// Returns a copy whose saved ranges follow the currently selected music offset.
function ApplyMusicOffsetToSongLyricsLines(const Lines: TLyricsSongLines;
  MusicOffsetSeconds: Double; Rate, Scale: Integer): TLyricsSongLines;
// Returns every line whose raw display range contains the frame. If none
// contains it, the single line nearest to its synchronization range is used.
function ResolveSongLyricsPlacementCandidateIndexes(
  const Lines: TLyricsSongLines; LocalFrame: Int64): TLyricsSongLineIndexes;
// Returns the position in Candidates whose synchronization range is nearest.
function ResolveSongLyricsPlacementInitialCandidate(
  const Lines: TLyricsSongLines; const Candidates: TLyricsSongLineIndexes;
  LocalFrame: Int64): Integer;
// Returns a fixed unconsumed or completed progress outside the stored sync
// interval. False means the caller must resolve progress inside the interval.
function TryResolveSongLyricsLineBoundaryProgress(
  const LineData: TLyricsSongLine; LocalFrame: Int64;
  DisplayUnitCount: Integer; out ProgressUnits: Double): Boolean;

implementation

uses
  System.Generics.Collections,
  System.Math,
  System.SyncObjs,
  System.SysUtils,
  SYNC_Lyrics_SongLyricsData;

const
  MAX_CACHE_ITEMS = 16;

function ShiftFrame(Value, DeltaFrames: Int64): Int64;
begin
  if Value < 0 then
    Exit(Value);
  Result := Max(0, Value + DeltaFrames);
end;

function ApplyMusicOffsetToSongLyricsLines(const Lines: TLyricsSongLines;
  MusicOffsetSeconds: Double; Rate, Scale: Integer): TLyricsSongLines;
var
  DeltaFrames: Int64;
  I: Integer;
begin
  Result := Copy(Lines);
  if (Rate <= 0) or (Scale <= 0) then
    Exit;
  for I := 0 to High(Result) do
  begin
    DeltaFrames := Round((MusicOffsetSeconds -
      Result[I].TimingMusicOffsetSeconds) * Rate / Scale);
    if DeltaFrames = 0 then
      Continue;
    Result[I].DisplayStartFrame := ShiftFrame(
      Result[I].DisplayStartFrame, DeltaFrames);
    Result[I].DisplayEndFrame := ShiftFrame(
      Result[I].DisplayEndFrame, DeltaFrames);
    Result[I].SyncStartFrame := ShiftFrame(
      Result[I].SyncStartFrame, DeltaFrames);
    Result[I].SyncEndFrame := ShiftFrame(
      Result[I].SyncEndFrame, DeltaFrames);
    Result[I].TimingMusicOffsetSeconds := MusicOffsetSeconds;
  end;
end;

function FrameDistanceToRange(LocalFrame, StartFrame,
  EndFrame: Int64): Int64;
begin
  if StartFrame < 0 then
    StartFrame := 0;
  if EndFrame < StartFrame then
    EndFrame := StartFrame;
  if LocalFrame < StartFrame then
    Exit(StartFrame - LocalFrame);
  if LocalFrame > EndFrame then
    Exit(LocalFrame - EndFrame);
  Result := 0;
end;

function ResolveSongLyricsPlacementInitialCandidate(
  const Lines: TLyricsSongLines; const Candidates: TLyricsSongLineIndexes;
  LocalFrame: Int64): Integer;
var
  BestDistance: Int64;
  CandidateIndex: Integer;
  Distance: Int64;
  I: Integer;
begin
  Result := -1;
  BestDistance := High(Int64);
  for I := 0 to High(Candidates) do
  begin
    CandidateIndex := Candidates[I];
    if (CandidateIndex < 0) or (CandidateIndex >= Length(Lines)) then
      Continue;
    Distance := FrameDistanceToRange(LocalFrame,
      Lines[CandidateIndex].SyncStartFrame,
      Lines[CandidateIndex].SyncEndFrame);
    if (Result < 0) or (Distance < BestDistance) or
      ((Distance = BestDistance) and
       (Lines[CandidateIndex].SyncStartFrame >
        Lines[Candidates[Result]].SyncStartFrame)) then
    begin
      Result := I;
      BestDistance := Distance;
    end;
  end;
end;

function ResolveSongLyricsPlacementCandidateIndexes(
  const Lines: TLyricsSongLines; LocalFrame: Int64): TLyricsSongLineIndexes;
var
  BestCandidate: Integer;
  BestDistance: Int64;
  Distance: Int64;
  EffectiveEnd: Int64;
  EffectiveStart: Int64;
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(Lines) do
  begin
    if (Lines[I].DisplayStartFrame < 0) and
      (Lines[I].DisplayEndFrame < 0) then
      Continue;
    EffectiveStart := Max(0, Lines[I].DisplayStartFrame);
    EffectiveEnd := Lines[I].DisplayEndFrame;
    if EffectiveEnd < EffectiveStart then
      EffectiveEnd := EffectiveStart;
    if (LocalFrame >= EffectiveStart) and (LocalFrame <= EffectiveEnd) then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := I;
    end;
  end;
  if Length(Result) > 0 then
    Exit;

  BestCandidate := -1;
  BestDistance := High(Int64);
  for I := 0 to High(Lines) do
  begin
    if (Lines[I].SyncStartFrame < 0) and
      (Lines[I].SyncEndFrame < 0) then
      Continue;
    Distance := FrameDistanceToRange(LocalFrame,
      Lines[I].SyncStartFrame, Lines[I].SyncEndFrame);
    if (BestCandidate < 0) or (Distance < BestDistance) then
    begin
      BestCandidate := I;
      BestDistance := Distance;
    end;
  end;
  if (BestCandidate < 0) and (Length(Lines) > 0) then
    BestCandidate := 0;
  if BestCandidate >= 0 then
  begin
    SetLength(Result, 1);
    Result[0] := BestCandidate;
  end;
end;

type
  TSongLyricsCacheItem = class
  public
    DataText: string;
    Lines: TLyricsSongLines;
    LastUse: UInt64;
  end;

var
  CacheItems: TObjectList<TSongLyricsCacheItem>;
  CacheLock: TCriticalSection;
  CacheUseCounter: UInt64;

procedure FinalizeSongLyricsRuntime;
begin
  FreeAndNil(CacheItems);
  FreeAndNil(CacheLock);
  CacheUseCounter := 0;
end;

procedure InitializeSongLyricsRuntime;
begin
  if CacheLock <> nil then
    Exit;
  CacheLock := TCriticalSection.Create;
  CacheItems := TObjectList<TSongLyricsCacheItem>.Create(True);
end;

function ResolveSongLyricsLineIndex(const Lines: TLyricsSongLines;
  LocalFrame: Int64): Integer;
var
  BestStart: Int64;
  EffectiveEnd: Int64;
  EffectiveStart: Int64;
  HasTimedLine: Boolean;
  I: Integer;
  J: Integer;
begin
  Result := -1;
  BestStart := Low(Int64);
  HasTimedLine := False;
  for I := 0 to High(Lines) do
  begin
    if (Lines[I].DisplayStartFrame < 0) and
      (Lines[I].DisplayEndFrame < 0) then
      Continue;
    HasTimedLine := True;
    EffectiveStart := Lines[I].DisplayStartFrame;
    if EffectiveStart < 0 then
      EffectiveStart := 0;
    EffectiveEnd := Lines[I].DisplayEndFrame;
    if EffectiveEnd < 0 then
      for J := I + 1 to High(Lines) do
        if (Lines[J].DisplayLane = Lines[I].DisplayLane) and
          (Lines[J].DisplayStartFrame >= 0) then
        begin
          EffectiveEnd := Lines[J].DisplayStartFrame - 1;
          Break;
        end;
    if EffectiveEnd < 0 then
      EffectiveEnd := High(Int64);
    if (LocalFrame >= EffectiveStart) and
      (LocalFrame <= EffectiveEnd) and (EffectiveStart >= BestStart) then
    begin
      Result := I;
      BestStart := EffectiveStart;
    end;
  end;
  if not HasTimedLine and (Length(Lines) > 0) then
    Result := 0;
end;

function ResolveSongLyricsLineIndexes(const Lines: TLyricsSongLines;
  LocalFrame: Int64): TLyricsSongLineIndexes;
var
  BestIndexes: array[1..3] of Integer;
  BestStarts: array[1..3] of Int64;
  EffectiveEnd: Int64;
  EffectiveStart: Int64;
  HasTimedLine: Boolean;
  I: Integer;
  J: Integer;
  Lane: Integer;
begin
  SetLength(Result, 0);
  for Lane := 1 to 3 do
  begin
    BestIndexes[Lane] := -1;
    BestStarts[Lane] := Low(Int64);
  end;
  HasTimedLine := False;
  for I := 0 to High(Lines) do
  begin
    if (Lines[I].DisplayStartFrame < 0) and
      (Lines[I].DisplayEndFrame < 0) then
      Continue;
    HasTimedLine := True;
    Lane := EnsureRange(Lines[I].DisplayLane, 1, 3);
    EffectiveStart := Max(0, Lines[I].DisplayStartFrame);
    EffectiveEnd := Lines[I].DisplayEndFrame;
    if EffectiveEnd < 0 then
      for J := I + 1 to High(Lines) do
        if (Lines[J].DisplayLane = Lines[I].DisplayLane) and
          (Lines[J].DisplayStartFrame >= 0) then
        begin
          EffectiveEnd := Lines[J].DisplayStartFrame - 1;
          Break;
        end;
    if EffectiveEnd < 0 then
      EffectiveEnd := High(Int64);
    if (LocalFrame >= EffectiveStart) and
      (LocalFrame <= EffectiveEnd) and
      (EffectiveStart >= BestStarts[Lane]) then
    begin
      BestIndexes[Lane] := I;
      BestStarts[Lane] := EffectiveStart;
    end;
  end;
  if not HasTimedLine and (Length(Lines) > 0) then
  begin
    SetLength(Result, 1);
    Result[0] := 0;
    Exit;
  end;
  for Lane := 1 to 3 do
    if BestIndexes[Lane] >= 0 then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := BestIndexes[Lane];
    end;
end;

function TryResolveSongLyricsLineBoundaryProgress(
  const LineData: TLyricsSongLine; LocalFrame: Int64;
  DisplayUnitCount: Integer; out ProgressUnits: Double): Boolean;
begin
  Result := False;
  ProgressUnits := 0;
  if DisplayUnitCount <= 0 then
    Exit(True);
  if (LineData.SyncStartFrame >= 0) and
    (LocalFrame < LineData.SyncStartFrame) then
    Exit(True);
  if (LineData.SyncEndFrame >= 0) and
    (LocalFrame >= LineData.SyncEndFrame) then
  begin
    ProgressUnits := DisplayUnitCount;
    Exit(True);
  end;
end;

function TryGetSongLyricsLines(const DataText: string;
  out Lines: TLyricsSongLines): Boolean;
var
  CacheItem: TSongLyricsCacheItem;
  ErrorText: string;
  I: Integer;
  LeastUsedIndex: Integer;
  Model: TLyricsSongModel;
begin
  Lines := nil;
  Result := False;
  if DataText = '' then
    Exit;
  InitializeSongLyricsRuntime;
  CacheLock.Acquire;
  try
    for CacheItem in CacheItems do
      if CacheItem.DataText = DataText then
      begin
        Inc(CacheUseCounter);
        CacheItem.LastUse := CacheUseCounter;
        Lines := Copy(CacheItem.Lines);
        Exit(True);
      end;
  finally
    CacheLock.Release;
  end;

  Model := TLyricsSongModel.Create;
  try
    if not TryDecodeSongLyrics(DataText, Model, ErrorText) then
      Exit;
    Lines := Model.CopyLines;
  finally
    Model.Free;
  end;

  CacheLock.Acquire;
  try
    Inc(CacheUseCounter);
    CacheItem := TSongLyricsCacheItem.Create;
    CacheItem.DataText := DataText;
    CacheItem.Lines := Copy(Lines);
    CacheItem.LastUse := CacheUseCounter;
    CacheItems.Add(CacheItem);
    if CacheItems.Count > MAX_CACHE_ITEMS then
    begin
      LeastUsedIndex := 0;
      for I := 1 to CacheItems.Count - 1 do
        if CacheItems[I].LastUse < CacheItems[LeastUsedIndex].LastUse then
          LeastUsedIndex := I;
      CacheItems.Delete(LeastUsedIndex);
    end;
  finally
    CacheLock.Release;
  end;
  Result := True;
end;

initialization
  CacheItems := nil;
  CacheLock := nil;
  CacheUseCounter := 0;

finalization
  FinalizeSongLyricsRuntime;

end.
