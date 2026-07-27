unit SYNC_Lyrics_MusicSync;

// SongReaderで音楽ファイルを読み、歌詞同期用のノート開始時刻を提供する。

interface

type
  TMusicNoteStart = record
    TrackIndex: Integer; // 読込形式を問わずSongReaderが割り当てたトラック番号。
    Seconds   : Double;  // 曲先頭からのノート開始秒。
    EndSeconds: Double;  // 曲先頭からのノート終了秒。
  end;
  TMusicNoteStarts = TArray<TMusicNoteStart>;

// SongReaderの対応形式を読み、全トラックのノート開始時刻を秒位置順で返す。
function LoadMusicNoteStarts(const FileName: string; out Notes: TMusicNoteStarts): Boolean;

// 音楽ファイルを必要時だけ再読込し、指定区間で開始済みのノート数を返す。Track=-1は全トラック。
function CountConsumedMusicNotes(const FileName: string; Track: Integer;
  StartSeconds, CurrentSeconds: Double): Integer;

// 完了した音数と発音中ノートの進捗を合算し、連続する表示単位位置として返す。
function ResolveMusicSyncProgress(const FileName: string; Track: Integer;
  StartSeconds, CurrentSeconds: Double; out ProgressUnits: Double): Boolean;

// 同期開始以降の音を表示単位数だけ割り当て、後続行の音を除外した進捗を返す。
function ResolveMusicSyncProgressForUnits(const FileName: string; Track: Integer;
  SyncStartSeconds, CurrentSeconds: Double; DisplayUnitCount: Integer;
  out ProgressUnits: Double): Boolean;

// 音楽データキャッシュの排他資源をFilter読込時に初期化する。
procedure InitializeMusicSync;

// 音楽データキャッシュと排他資源をFilter解放時に破棄する。
procedure FinalizeMusicSync;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  SongData,
  Winapi.Windows;

const
  MUSIC_TIME_EPSILON = 0.000001;

var
  CacheFileName: string;
  CacheFileTime: TDateTime;
  CacheInitialized: Boolean;
  CacheLock: TRTLCriticalSection;
  CacheNotes: TMusicNoteStarts;
  CacheValid: Boolean;

function CompareNoteStarts(const Left, Right: TMusicNoteStart): Integer;
begin
  if Left.Seconds < Right.Seconds then
    Exit(-1);
  if Left.Seconds > Right.Seconds then
    Exit(1);
  Result := Left.TrackIndex - Right.TrackIndex;
end;

procedure QuickSortNoteStarts(var Notes: TMusicNoteStarts; Left, Right: Integer);
var
  I: Integer;
  J: Integer;
  Pivot: TMusicNoteStart;
  Swap: TMusicNoteStart;
begin
  I := Left;
  J := Right;
  Pivot := Notes[(Left + Right) div 2];
  repeat
    while CompareNoteStarts(Notes[I], Pivot) < 0 do
      Inc(I);
    while CompareNoteStarts(Notes[J], Pivot) > 0 do
      Dec(J);
    if I <= J then
    begin
      Swap := Notes[I];
      Notes[I] := Notes[J];
      Notes[J] := Swap;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if Left < J then
    QuickSortNoteStarts(Notes, Left, J);
  if I < Right then
    QuickSortNoteStarts(Notes, I, Right);
end;

procedure SortNoteStarts(var Notes: TMusicNoteStarts);
begin
  if Length(Notes) > 1 then
    QuickSortNoteStarts(Notes, 0, High(Notes));
end;

function LoadMusicNoteStarts(const FileName: string; out Notes: TMusicNoteStarts): Boolean;
var
  I: Integer;
  Song: TSongData;
begin
  Result := False;
  SetLength(Notes, 0);
  if (Trim(FileName) = '') or not TFile.Exists(FileName) then
    Exit;

  Song := TSongData.Create;
  try
    try
      if not Song.LoadFromMusicFile(FileName) then
        Exit;
      SetLength(Notes, Song.Notes.Count);
      for I := 0 to Song.Notes.Count - 1 do
      begin
        Notes[I].TrackIndex := Song.Notes[I].TrackIndex;
        Notes[I].Seconds := Song.Notes[I].StartSec;
        Notes[I].EndSeconds := Song.Notes[I].EndSec;
      end;
      SortNoteStarts(Notes);
      Result := True;
    except
      SetLength(Notes, 0);
    end;
  finally
    Song.Free;
  end;
end;

function EnsureMusicCache(const FileName: string): Boolean;
var
  FileTime: TDateTime;
begin
  Result := False;
  if (FileName = '') or not TFile.Exists(FileName) then
    Exit;
  FileTime := TFile.GetLastWriteTimeUtc(FileName);
  if CacheValid and SameText(CacheFileName, FileName) and (CacheFileTime = FileTime) then
    Exit(True);

  CacheValid := LoadMusicNoteStarts(FileName, CacheNotes);
  CacheFileName := FileName;
  CacheFileTime := FileTime;
  Result := CacheValid;
end;

function CountConsumedMusicNotes(const FileName: string; Track: Integer;
  StartSeconds, CurrentSeconds: Double): Integer;
var
  I: Integer;
begin
  Result := 0;
  if CurrentSeconds < StartSeconds - MUSIC_TIME_EPSILON then
    Exit;
  EnterCriticalSection(CacheLock);
  try
    if not EnsureMusicCache(FileName) then
      Exit;
    for I := 0 to High(CacheNotes) do
    begin
      if CacheNotes[I].Seconds < StartSeconds - MUSIC_TIME_EPSILON then
        Continue;
      if CacheNotes[I].Seconds > CurrentSeconds + MUSIC_TIME_EPSILON then
        Break;
      if (Track < 0) or (CacheNotes[I].TrackIndex = Track) then
        Inc(Result);
    end;
  finally
    LeaveCriticalSection(CacheLock);
  end;
end;

function ResolveMusicSyncProgress(const FileName: string; Track: Integer;
  StartSeconds, CurrentSeconds: Double; out ProgressUnits: Double): Boolean;
var
  Duration: Double;
  I: Integer;
begin
  Result := False;
  ProgressUnits := 0;
  if CurrentSeconds < StartSeconds - MUSIC_TIME_EPSILON then
    Exit;
  EnterCriticalSection(CacheLock);
  try
    if not EnsureMusicCache(FileName) then
      Exit;
    Result := True;
    for I := 0 to High(CacheNotes) do
    begin
      if CacheNotes[I].Seconds < StartSeconds - MUSIC_TIME_EPSILON then
        Continue;
      if (Track >= 0) and (CacheNotes[I].TrackIndex <> Track) then
        Continue;
      if CurrentSeconds < CacheNotes[I].Seconds then
        Break;

      Duration := CacheNotes[I].EndSeconds - CacheNotes[I].Seconds;
      if (Duration <= MUSIC_TIME_EPSILON) or
        (CurrentSeconds >= CacheNotes[I].EndSeconds) then
      begin
        ProgressUnits := ProgressUnits + 1;
        Continue;
      end;

      ProgressUnits := ProgressUnits +
        (CurrentSeconds - CacheNotes[I].Seconds) / Duration;
      Break;
    end;
  finally
    LeaveCriticalSection(CacheLock);
  end;
end;

function ResolveMusicSyncProgressForUnits(const FileName: string; Track: Integer;
  SyncStartSeconds, CurrentSeconds: Double; DisplayUnitCount: Integer;
  out ProgressUnits: Double): Boolean;
var
  AssignedCount: Integer;
  Duration: Double;
  I: Integer;
  ProgressBlocked: Boolean;
begin
  Result := False;
  ProgressUnits := 0;
  if DisplayUnitCount <= 0 then
    Exit(True);
  if CurrentSeconds < SyncStartSeconds - MUSIC_TIME_EPSILON then
    Exit(True);

  EnterCriticalSection(CacheLock);
  try
    if not EnsureMusicCache(FileName) then
      Exit;

    AssignedCount := 0;
    ProgressBlocked := False;
    for I := 0 to High(CacheNotes) do
    begin
      if CacheNotes[I].Seconds < SyncStartSeconds - MUSIC_TIME_EPSILON then
        Continue;
      if (Track >= 0) and (CacheNotes[I].TrackIndex <> Track) then
        Continue;
      if AssignedCount >= DisplayUnitCount then
        Break;

      Inc(AssignedCount);
      if ProgressBlocked then
        Continue;
      if CurrentSeconds < CacheNotes[I].Seconds then
      begin
        ProgressBlocked := True;
        Continue;
      end;

      Duration := CacheNotes[I].EndSeconds - CacheNotes[I].Seconds;
      if (Duration <= MUSIC_TIME_EPSILON) or
        (CurrentSeconds >= CacheNotes[I].EndSeconds) then
        ProgressUnits := ProgressUnits + 1
      else
      begin
        ProgressUnits := ProgressUnits +
          (CurrentSeconds - CacheNotes[I].Seconds) / Duration;
        ProgressBlocked := True;
      end;
    end;
    Result := True;
  finally
    LeaveCriticalSection(CacheLock);
  end;
end;

procedure InitializeMusicSync;
begin
  if CacheInitialized then
    Exit;
  InitializeCriticalSection(CacheLock);
  CacheInitialized := True;
end;

procedure FinalizeMusicSync;
begin
  if not CacheInitialized then
    Exit;
  EnterCriticalSection(CacheLock);
  try
    SetLength(CacheNotes, 0);
    CacheFileName := '';
    CacheValid := False;
  finally
    LeaveCriticalSection(CacheLock);
  end;
  DeleteCriticalSection(CacheLock);
  CacheInitialized := False;
end;

end.
