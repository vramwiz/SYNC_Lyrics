program SYNC_Lyrics_MusicSyncTests;

// SongReader経由の音楽ファイル読込と、区間内ノート消費数を検証する。

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  Vcl.Graphics,
  Winapi.Windows,
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
  SYNC_Lyrics_DisplaySettingsData in
    'Source\Common\Render\SYNC_Lyrics_DisplaySettingsData.pas',
  SYNC_Lyrics_SyncFormat in 'Source\Common\Sync\SYNC_Lyrics_SyncFormat.pas',
  SYNC_Lyrics_SyncSourceKind in
    'Source\Common\Sync\SYNC_Lyrics_SyncSourceKind.pas',
  SYNC_Lyrics_ManualSync in
    'Source\Common\Sync\SYNC_Lyrics_ManualSync.pas',
  SYNC_Lyrics_ManualSyncEditModel in
    'Source\Common\Sync\SYNC_Lyrics_ManualSyncEditModel.pas',
  SYNC_Lyrics_MusicSyncAnchor in
    'Source\Common\Sync\SYNC_Lyrics_MusicSyncAnchor.pas',
  SYNC_Lyrics_MusicSync in 'Source\Common\Sync\SYNC_Lyrics_MusicSync.pas',
  SYNC_Lyrics_MusicSyncPianoRoll in
    'Source\Plugin\Filter\SYNC_Lyrics_MusicSyncPianoRoll.pas',
  SYNC_Lyrics_MusicSyncEditModel in
    'Source\Plugin\Filter\SYNC_Lyrics_MusicSyncEditModel.pas',
  SYNC_Lyrics_TimeRuler in
    'Source\Plugin\Filter\SYNC_Lyrics_TimeRuler.pas';

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

procedure TestDisplaySettingsData;
var
  Data: TDisplaySettingsData;
  OversizedText: string;
  TestText: string;
begin
  Check(SizeOf(TDisplaySettingsData) = DISPLAY_SETTINGS_DATA_SIZE,
    'display settings data ABI size mismatch');
  TestText := 'index=0;x=12.5;y=-8.0;label=漢字';
  Check(TryEncodeDisplaySettingsText(TestText, Data),
    'display settings debug text could not be encoded');
  Check(DecodeDisplaySettingsText(Data) = TestText,
    'display settings debug text did not round-trip');

  OversizedText := StringOfChar('x', DISPLAY_SETTINGS_PAYLOAD_SIZE + 1);
  Check(not TryEncodeDisplaySettingsText(OversizedText, Data),
    'oversized display settings debug text was accepted');
end;

procedure TestTimeRuler;
var
  Interval: Double;
begin
  Interval := SelectTimeRulerInterval(10.0);
  Check(Abs(Interval - 1.0) < 0.000001,
    '10 second view did not select one-second ruler ticks');
  Check(FirstTimeRulerTickIndex(2.35, Interval) = 3,
    'ruler did not begin at the next absolute second');
  Check(LastTimeRulerTickIndex(5.35, Interval) = 5,
    'ruler did not end at the last visible absolute second');

  Interval := SelectTimeRulerInterval(1.0);
  Check(Abs(Interval - 0.1) < 0.000001,
    'one-second view did not select 0.1-second ruler ticks');
  Check(FirstTimeRulerTickIndex(0.21, Interval) = 3,
    'fractional ruler did not follow the absolute audio origin');
  Check(TimeRulerDecimalPlaces(Interval) = 1,
    'fractional ruler label precision mismatch');

  Check(Abs(SelectTimeRulerInterval(60.0) - 10.0) < 0.000001,
    'wide view selected an excessive number of ruler ticks');
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
      SyncText := SerializeManualSyncText([0.25, 0.75, 1.5]);
      Check(TryParseSyncText(SyncText, SyncData) and
        (SyncData.Mode = smManual) and
        (Length(SyncData.ManualBoundaries) = 3),
        'serialized manual sync text could not be parsed');
      Check(Abs(SyncData.ManualBoundaries[1] - 0.75) < 0.000001,
        'manual sync boundary mismatch');
      Check(ResolveManualSyncProgress(0.0, 2,
        SyncData.ManualBoundaries, ProgressUnits) and
        (Abs(ProgressUnits) < 0.000001),
        'manual sync pre-roll mismatch');
      Check(ResolveManualSyncProgress(0.5, 2,
        SyncData.ManualBoundaries, ProgressUnits) and
        (Abs(ProgressUnits - 0.5) < 0.000001),
        'manual sync first unit mismatch');
      Check(ResolveManualSyncProgress(1.125, 2,
        SyncData.ManualBoundaries, ProgressUnits) and
        (Abs(ProgressUnits - 1.5) < 0.000001),
        'manual sync second unit mismatch');
      Check(ResolveManualSyncProgress(2.0, 2,
        SyncData.ManualBoundaries, ProgressUnits) and
        (Abs(ProgressUnits - 2.0) < 0.000001),
        'manual sync completion mismatch');
      Check(not ResolveManualSyncProgress(0.5, 3,
        SyncData.ManualBoundaries, ProgressUnits),
        'manual sync accepted a lyric/boundary count mismatch');
      Check(not TryParseSyncText(
        'SYNC_LYRICS_SYNC/1;mode=manual;boundaries=0.5,0.5', SyncData),
        'duplicate manual boundaries were accepted');
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

procedure TestNonSoundingLyricsAreAttached;
var
  Model: TMusicSyncEditModel;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('「歌、 空。」');
    Check(Length(Model.Units) = 2,
      'non-sounding characters created editable sync units');
    Check((Model.Units[0].PrefixText = '「') and
      (Model.Units[0].Text = '歌') and
      (Model.Units[0].SuffixText = '、 '),
      'leading or middle punctuation attachment mismatch');
    Check((Model.Units[1].Text = '空') and
      (Model.Units[1].SuffixText = '。」'),
      'trailing punctuation attachment mismatch');
    Check((Length(Model.Groups) = 2) and
      (Model.UnitNoteIndexes[0] = 0) and
      (Model.UnitNoteIndexes[1] = 1),
      'attached punctuation changed editable note indexes');
  finally
    Model.Free;
  end;
end;

procedure TestDefaultSyncGeneration;
var
  Model: TMusicSyncEditModel;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('「[漢字](かんじ)、 を!');
    Check(Length(Model.Units) = 2,
      'default sync did not use sounding display units');
    Model.LoadSyncText('');
    Check(Model.DefaultSyncGenerated,
      'missing sync text was not recognized as generated defaults');
    Check((Length(Model.Groups) = 2) and
      (Model.Groups[0].UnitCount = 1) and
      (Model.Groups[0].NoteCount = 1) and
      (Model.Groups[1].UnitCount = 1) and
      (Model.Groups[1].NoteCount = 1),
      'missing sync text did not create one-unit one-note defaults');
    Check(Model.SerializeSyncText = DEFAULT_MUSIC_SYNC_TEXT,
      'generated defaults were not serialized in canonical form');

    Model.LoadSyncText(SerializeMusicSyncText([1, 0]));
    Check(not Model.DefaultSyncGenerated,
      'explicit sync stages were mistaken for generated defaults');
  finally
    Model.Free;
  end;
end;

procedure TestSyncPreservedAcrossLyricsEdits;
var
  Model: TMusicSyncEditModel;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('あいう');
    Model.LoadSyncText(SerializeMusicSyncText([0, 1, 0]));
    Model.SelectedUnitIndex := 1;
    Model.SetLyrics('あえいう');
    Check((Length(Model.Groups) = 4) and
      (Model.Groups[0].NoteCount = 1) and
      (Model.Groups[1].NoteCount = 1) and
      (Model.Groups[2].NoteCount = 2) and
      (Model.Groups[3].NoteCount = 1),
      'insertion did not preserve matching multi-note unit');
    Check((Model.UnitNoteIndexes[0] = 0) and
      (Model.UnitNoteIndexes[1] = 1) and
      (Model.UnitNoteIndexes[2] = 2) and
      (Model.UnitNoteIndexes[3] = 4),
      'inserted unit note indexes mismatch');
    Check(Model.SelectedUnitIndex = 2,
      'selection did not follow matching unit after insertion');

    Model.SetLyrics('「あえいう、」');
    Check((Length(Model.Groups) = 4) and
      (Model.Groups[2].NoteCount = 2),
      'punctuation edit changed preserved sync');

    Model.SetLyrics('かきく');
    Model.LoadSyncText(SerializeMusicSyncText([-1, 0]));
    Model.SetLyrics('かきけく');
    Check((Length(Model.Groups) = 3) and
      (Model.Groups[0].UnitCount = 2) and
      (Model.Groups[0].NoteCount = 1) and
      (Model.Groups[1].UnitCount = 1) and
      (Model.Groups[2].UnitCount = 1),
      'insertion after shared group did not preserve the group');

    Model.SetLyrics('かきく');
    Model.LoadSyncText(SerializeMusicSyncText([-1, 0]));
    Model.SetLyrics('かけきく');
    Check((Length(Model.Groups) = 4) and
      (Model.Groups[0].UnitCount = 1) and
      (Model.Groups[1].UnitCount = 1) and
      (Model.Groups[2].UnitCount = 1),
      'edit inside shared group preserved an invalid group');

    Model.SetLyrics('[漢字](かんじ)を');
    Model.LoadSyncText(SerializeMusicSyncText([1, 0]));
    Model.SetLyrics('「[漢字](カンジ)、を」');
    Check((Length(Model.Groups) = 2) and
      (Model.Groups[0].NoteCount = 2),
      'ruby or attached punctuation edit changed base-text sync');
  finally
    Model.Free;
  end;
end;

procedure TestMusicSyncDpiLayout;
var
  Bitmap: Vcl.Graphics.TBitmap;
  BlackKeyY: Integer;
  Layout: TPianoRollLayout;
  Notes: TMusicNoteStarts;
  PixelColor: COLORREF;
begin
  Check(ScaleMusicSyncMetric(76, 96) = 76,
    '96 DPI metric changed its base size');
  Check(ScaleMusicSyncMetric(76, 192) = 152,
    '200 percent DPI metric mismatch');
  Check(MusicSyncKeyboardWidth(192) = 152,
    '200 percent keyboard width mismatch');

  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(1800, 1240);
    SetLength(Notes, 0);
    DrawMusicSyncPianoRoll(Bitmap.Canvas, Bitmap.Width, Bitmap.Height,
      Notes, 0, 0, 0, MUSIC_SYNC_DISPLAY_SECONDS, 192, Layout);
    Check((Layout.Dpi = 192) and
      (Layout.KeyboardWidth = 152) and
      (Layout.RollHeight = 1124) and
      (Layout.TimeWidth = 1648) and
      (Abs(Layout.ViewStartSeconds) < 0.000001) and
      (Abs(Layout.DisplaySeconds -
        MUSIC_SYNC_DISPLAY_SECONDS) < 0.000001),
      '200 percent piano-roll layout mismatch');
    // ノートなしの既定範囲はMIDI 48..71。黒鍵49の中心付近で、
    // 黒鍵幅62%より右側が白鍵ベースとして残ることを確認する。
    BlackKeyY := Round(Layout.RollHeight * 0.5 -
      (49 - 59.5) * (Layout.RollHeight / 24));
    PixelColor := GetPixel(Bitmap.Canvas.Handle, 40, BlackKeyY);
    Check((GetRValue(PixelColor) < 80) and
      (GetGValue(PixelColor) < 80) and
      (GetBValue(PixelColor) < 80),
      'black key itself was not painted dark');
    PixelColor := GetPixel(Bitmap.Canvas.Handle, 120, BlackKeyY);
    Check((GetRValue(PixelColor) > 100) and
      (GetGValue(PixelColor) > 100) and
      (GetBValue(PixelColor) > 100),
      'black key remainder was not painted with the white-key base');
  finally
    Bitmap.Free;
  end;
end;

procedure TestSyncSourceKind;
begin
  Check(IsMusicScoreFileName('song.mid'), 'MIDI was not classified as score');
  Check(IsMusicScoreFileName('SONG.MUSICXML'),
    'MusicXML classification was case-sensitive');
  Check(IsMusicScoreFileName('archive.mscz'),
    'MSCZ was not classified as score');
  Check(not IsMusicScoreFileName('voice.wav'),
    'WAV was unexpectedly classified as score');
  Check(not IsMusicScoreFileName('voice.flac'),
    'FLAC was unexpectedly classified as score');
  Check(not IsMusicScoreFileName('unknown.bin'),
    'unknown file was unexpectedly classified as score');
end;

procedure TestUnassignedLyrics;
var
  Model: TMusicSyncEditModel;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('あいう');
    Check(Model.FirstUnassignedUnitIndex(3) = -1,
      'fully assigned lyrics were reported as unassigned');
    Check(Model.FirstUnassignedUnitIndex(2) = 2,
      'remaining lyric unit index mismatch');
    Model.LoadSyncText(SerializeMusicSyncText([1, 0, 0]));
    Check(Model.FirstUnassignedUnitIndex(1) = 0,
      'partially supplied multi-note unit was not reported');
    Check(Model.FirstUnassignedUnitIndex(2) = 1,
      'unit after completed multi-note unit mismatch');
  finally
    Model.Free;
  end;
end;

procedure TestMusicSyncAnchorPerObject;
var
  Anchor: TMusicSyncAnchor;
begin
  InitializeMusicSyncAnchor;
  try
    RecordMusicSyncAnchor(101, 1001, 1, 0, 99, 300, 30, 1);
    RecordMusicSyncAnchor(102, 1002, 1, 100, 199, 600, 30, 1);
    Check(TryGetMusicSyncAnchor(1, 0, 99, Anchor) and
      (Anchor.ObjectID = 101) and (Anchor.Frame = 300),
      'first object music-sync anchor mismatch');
    Check(TryGetMusicSyncAnchor(1, 100, 199, Anchor) and
      (Anchor.ObjectID = 102) and (Anchor.Frame = 600),
      'second object music-sync anchor mismatch');
    Check(not TryGetMusicSyncAnchor(1, 200, 299, Anchor),
      'unexpected anchor found for unknown object');

    RecordMusicSyncAnchor(102, 1002, 2, 200, 299, 900, 30, 1);
    Check(not TryGetMusicSyncAnchor(1, 100, 199, Anchor),
      'moved object retained its stale anchor');
    Check(TryGetMusicSyncAnchor(2, 200, 299, Anchor) and
      (Anchor.ObjectID = 102) and (Anchor.Frame = 900),
      'moved object music-sync anchor mismatch');
  finally
    FinalizeMusicSyncAnchor;
  end;
end;

procedure TestManualSyncEditModel;
var
  Model: TManualSyncEditModel;
begin
  Model := TManualSyncEditModel.Create;
  try
    Model.Initialize(3, 30.0, '', 10.0);
    Check(Abs(Model.BoundarySeconds(3) - 10.0) < 0.0001,
      'manual sync defaults were placed outside the initial view');
    Model.Initialize(3, 12.0, '');
    Check(Model.Complete and (Model.BoundaryCount = 4),
      'manual sync default boundaries were not generated');
    Check(Abs(Model.BoundarySeconds(1) - 4.0) < 0.0001,
      'manual sync default interval mismatch');
    Check(Model.AddTimingBoundary(1.25) and
      Model.TimingInputStarted and (Model.BoundaryCount = 1),
      'first timing key did not clear defaults and record the first point');
    Check(Model.AddTimingBoundary(2.5) and
      (Model.BoundaryCount = 2),
      'second timing point was not appended');
    Model.RearmTimingInput;
    Check(Model.BoundaryCount = 2,
      'rearming timing input unexpectedly deleted data');
    Check(Model.AddTimingBoundary(3.0) and
      (Model.BoundaryCount = 1) and
      (Abs(Model.BoundarySeconds(0) - 3.0) < 0.0001),
      'first timing key after rearm did not restart input');
    Check(Model.AddTimingBoundary(5.0) and
      Model.AddTimingBoundary(7.0) and
      Model.AddTimingBoundary(9.0) and Model.Complete,
      'manual timing input did not complete');
    Check(Model.MoveBoundary(1, 6.0) and
      (Model.BoundarySeconds(1) < Model.BoundarySeconds(2)),
      'manual boundary drag did not preserve ordering');
    Check(Pos('mode=manual', Model.SerializeSyncText) > 0,
      'manual sync serialization failed');
  finally
    Model.Free;
  end;
end;

begin
  TestDisplaySettingsData;
  TestTimeRuler;
  TestSyncSourceKind;
  TestSongReaderAndConsumption;
  TestExpandedRubyUnitCharacterNotes;
  TestNonSoundingLyricsAreAttached;
  TestDefaultSyncGeneration;
  TestSyncPreservedAcrossLyricsEdits;
  TestMusicSyncDpiLayout;
  TestUnassignedLyrics;
  TestMusicSyncAnchorPerObject;
  TestManualSyncEditModel;
  Writeln('PASS');
end.
