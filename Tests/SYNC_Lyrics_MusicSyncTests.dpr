program SYNC_Lyrics_MusicSyncTests;

// SongReader経由の音楽ファイル読込と、区間内ノート消費数を検証する。

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  RTTIPersistent in 'Source\Lib\SongReader\RTTIPersistent.pas',
  RTTIPersistentIni in 'Source\Lib\SongReader\RTTIPersistentIni.pas',
  SectionFileManager in 'Source\Lib\SongReader\SectionFileManager.pas',
  TextEncodingUtils in 'Source\Lib\SongReader\TextEncodingUtils.pas',
  SongAIUEO in 'Source\Lib\SongReader\SongAIUEO.pas',
  SongDataInfo in 'Source\Lib\SongReader\SongDataInfo.pas',
  SongDataNote in 'Source\Lib\SongReader\SongDataNote.pas',
  SongDataTempo in 'Source\Lib\SongReader\SongDataTempo.pas',
  SongDataTrack in 'Source\Lib\SongReader\SongDataTrack.pas',
  SongData in 'Source\Lib\SongReader\SongData.pas',
  SongReader in 'Source\Lib\SongReader\SongReader.pas',
  SongReaderSMF in 'Source\Lib\SongReader\SongReaderSMF.pas',
  SongReaderUST in 'Source\Lib\SongReader\SongReaderUST.pas',
  SongReaderVSQX in 'Source\Lib\SongReader\SongReaderVSQX.pas',
  SongReaderMusicXML in 'Source\Lib\SongReader\SongReaderMusicXML.pas',
  SongReaderMusicMSC in 'Source\Lib\SongReader\SongReaderMusicMSC.pas',
  SongReaderMusicMSCZ in 'Source\Lib\SongReader\SongReaderMusicMSCZ.pas',
  SongReaderManager in 'Source\Lib\SongReader\SongReaderManager.pas',
  SYNC_Lyrics_LyricParser in 'Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_SyncFormat in 'Source\Common\Sync\SYNC_Lyrics_SyncFormat.pas',
  SYNC_Lyrics_MusicSync in 'Source\Common\Sync\SYNC_Lyrics_MusicSync.pas',
  SYNC_Lyrics_MusicSyncEditModel in
    'Source\Plugin\Filter\SYNC_Lyrics_MusicSyncEditModel.pas';

const
  TEST_MIDI: array[0..50] of Byte = (
    $4D, $54, $68, $64, $00, $00, $00, $06, $00, $00, $00, $01, $01, $E0,
    $4D, $54, $72, $6B, $00, $00, $00, $1D,
    $00, $FF, $51, $03, $07, $A1, $20,
    $00, $90, $3C, $64,
    $83, $60, $80, $3C, $00,
    $00, $90, $3E, $64,
    $83, $60, $80, $3E, $00,
    $00, $FF, $2F, $00
  );

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure TestSongReaderAndConsumption;
var
  Bytes: TBytes;
  FileName: string;
  I: Integer;
  Notes: TMusicNoteStarts;
  ProgressUnits: Double;
  SyncData: TSyncTextData;
  SyncParameters: TArray<Integer>;
  SyncText: string;
begin
  FileName := TPath.Combine(TPath.GetTempPath, 'SYNC_Lyrics_MusicSyncTests.mid');
  SetLength(Bytes, Length(TEST_MIDI));
  for I := 0 to High(TEST_MIDI) do
    Bytes[I] := TEST_MIDI[I];
  TFile.WriteAllBytes(FileName, Bytes);
  try
    Check(LoadMusicNoteStarts(FileName, Notes), 'SongReader MIDI load failed');
    Check(Length(Notes) = 2, 'SongReader note count mismatch');
    Check(Abs(Notes[0].Seconds) < 0.000001, 'first note time mismatch');
    Check(Notes[0].Key = 60, 'first note key mismatch');
    Check(Notes[0].Lyric = '', 'unexpected first note lyric');
    Check(Abs(Notes[1].Seconds - 0.5) < 0.000001, 'second note time mismatch');
    Check(Notes[1].Key = 62, 'second note key mismatch');
    Check(Abs(Notes[0].EndSeconds - 0.5) < 0.000001, 'first note end time mismatch');

    InitializeMusicSync;
    try
      Check(CountConsumedMusicNotes(FileName, -1, 0.0, 0.0) = 1,
        'first consumed note count mismatch');
      Check(CountConsumedMusicNotes(FileName, -1, 0.0, 0.5) = 2,
        'second consumed note count mismatch');
      Check(ResolveMusicSyncProgress(FileName, -1, 0.0, 0.25, ProgressUnits),
        'first continuous progress resolve failed');
      Check(Abs(ProgressUnits - 0.5) < 0.000001,
        'first continuous progress mismatch');
      Check(ResolveMusicSyncProgress(FileName, -1, 0.0, 0.75, ProgressUnits),
        'second continuous progress resolve failed');
      Check(Abs(ProgressUnits - 1.5) < 0.000001,
        'second continuous progress mismatch');

      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, -0.25, 2,
        ProgressUnits), 'pre-display state resolve failed');
      Check(Abs(ProgressUnits) < 0.000001,
        'pre-display state did not remain unconsumed');
      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, 0.75, 2,
        ProgressUnits), 'active display state resolve failed');
      Check(Abs(ProgressUnits - 1.5) < 0.000001,
        'active display state progress mismatch');
      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, 10.0, 2,
        ProgressUnits), 'completed display state resolve failed');
      Check(Abs(ProgressUnits - 2.0) < 0.000001,
        'completed lyrics did not remain complete');
      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, 1.01, 1,
        ProgressUnits), 'single-unit display state resolve failed');
      Check(Abs(ProgressUnits - 1.0) < 0.000001,
        'notes after the assigned unit changed progress');
      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, 2.0, 3,
        ProgressUnits), 'insufficient-note display state resolve failed');
      Check(Abs(ProgressUnits - 2.0) < 0.000001,
        'insufficient notes did not preserve the incomplete state');

      SetLength(SyncParameters, 1);
      SyncParameters[0] := 1;
      Check(ResolveAdjustedMusicSyncProgress(FileName, -1, 0.0, 0.25, 1,
        SyncParameters, ProgressUnits), 'multi-note sync resolve failed');
      Check(Abs(ProgressUnits - 0.25) < 0.000001,
        'first of two notes did not advance one display unit proportionally');
      Check(ResolveAdjustedMusicSyncProgress(FileName, -1, 0.0, 0.75, 1,
        SyncParameters, ProgressUnits), 'second multi-note sync resolve failed');
      Check(Abs(ProgressUnits - 0.75) < 0.000001,
        'second of two notes did not continue the same display unit');

      SyncParameters[0] := -1;
      Check(ResolveAdjustedMusicSyncProgress(FileName, -1, 0.0, 0.25, 2,
        SyncParameters, ProgressUnits), 'multi-unit sync resolve failed');
      Check(Abs(ProgressUnits - 1.0) < 0.000001,
        'one note did not advance two display units proportionally');
      Check(ResolveAdjustedMusicSyncProgress(FileName, -1, 0.0, 0.75, 3,
        SyncParameters, ProgressUnits), 'implicit default sync resolve failed');
      Check(Abs(ProgressUnits - 2.5) < 0.000001,
        'implicit default sync after adjusted stage mismatch');

      SyncText := SerializeMusicSyncText([1, -1, 0]);
      Check(TryParseSyncText(SyncText, SyncData),
        'serialized music sync text could not be parsed');
      Check((SyncData.Version = SYNC_TEXT_VERSION) and
        (SyncData.Mode = smMusic), 'music sync header mismatch');
      Check((Length(SyncData.MusicStages) = 3) and
        (SyncData.MusicStages[0] = 1) and
        (SyncData.MusicStages[1] = -1) and
        (SyncData.MusicStages[2] = 0), 'music sync stages mismatch');
      Check(TryParseSyncText(DEFAULT_MUSIC_SYNC_TEXT, SyncData) and
        (Length(SyncData.MusicStages) = 0),
        'empty music sync stages were not accepted');
      Check(not TryParseSyncText(
        'SYNC_LYRICS_SYNC/2;mode=music;stages=0', SyncData),
        'unsupported sync text version was accepted');
      Check(not TryParseSyncText(
        'SYNC_LYRICS_SYNC/1;mode=music;stages=64', SyncData),
        'out-of-range music sync stage was accepted');
    finally
      FinalizeMusicSync;
    end;
  finally
    TFile.Delete(FileName);
  end;
end;

procedure TestExpandedRubyUnitCharacterNotes;
var
  Model: TMusicSyncEditModel;
  NoteIndex: Integer;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('[漢字](かんじ)を読む');
    Check(Length(Model.Units) = 4, 'ruby lyric unit count mismatch');
    Check(not Model.TryGetExpandedCharacterNoteIndex(0, 1, NoteIndex),
      'one-note ruby unit unexpectedly split its characters');

    Model.LoadSyncText(SerializeMusicSyncText([1, 0, 0, 0]));
    Check(Model.TryGetExpandedCharacterNoteIndex(0, 0, NoteIndex) and
      (NoteIndex = 0), 'first ruby character did not remain on first note');
    Check(Model.TryGetExpandedCharacterNoteIndex(0, 1, NoteIndex) and
      (NoteIndex = 1), 'second ruby character did not move to second note');
    Check(Model.UnitNoteIndexes[1] = 2,
      'unit after expanded ruby unit did not move past both notes');
  finally
    Model.Free;
  end;
end;

begin
  TestSongReaderAndConsumption;
  TestExpandedRubyUnitCharacterNotes;
  Writeln('PASS');
end.
