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
  SYNC_Lyrics_MusicSync in 'Source\Common\Sync\SYNC_Lyrics_MusicSync.pas';

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
    Check(Abs(Notes[1].Seconds - 0.5) < 0.000001, 'second note time mismatch');
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
    finally
      FinalizeMusicSync;
    end;
  finally
    TFile.Delete(FileName);
  end;
end;

begin
  TestSongReaderAndConsumption;
  Writeln('PASS');
end.
