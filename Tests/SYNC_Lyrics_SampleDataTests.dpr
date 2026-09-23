program SYNC_Lyrics_SampleDataTests;

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  Vcl.Forms,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_MusicSync,
  SYNC_Lyrics_MusicSyncSettingsForm,
  SYNC_Lyrics_MidiLyricMatcher,
  SYNC_Lyrics_SyncFormat,
  SYNC_Lyrics_SongLyricsModel;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

var
  C: Char;
  Cost: Double;
  I: Integer;
  Model: TLyricsSongModel;
  Notes: TMusicNoteStarts;
  ExpectedStartNotes: array[0..3] of Integer = (0, 7, 13, 19);
  ExpectedNoteCounts: array[0..3] of Integer = (7, 6, 6, 11);
  SyncForm: TFormLyricsMusicSyncSettings;
begin
  Check(ParamCount = 2, 'Pass the sample MIDI and lyrics paths.');
  Check(LoadMusicNoteStarts(ParamStr(1), Notes), 'Sample MIDI load failed.');
  Check(Length(Notes) = 30, 'Sample MIDI must contain 30 lyric notes.');
  for I := 0 to High(Notes) do
  begin
    Check(Notes[I].TrackIndex = 0, 'Sample notes must use track 0.');
    Check(Notes[I].Lyric <> '', 'A sample note has no lyric.');
    for C in Notes[I].Lyric do
      Check(((C >= #$3041) and (C <= #$3096)) or
        ((C >= #$30A1) and (C <= #$30F6)),
        'MIDI lyrics must contain only hiragana and katakana.');
  end;
  Model := TLyricsSongModel.Create;
  try
    Model.SetLyricsText(TFile.ReadAllText(ParamStr(2), TEncoding.UTF8));
    Check(Model.LineCount = 4, 'Sample text must contain four lines.');
    Check(TryAssignMidiLyricSync(Notes, 0.5, Model, Cost),
      'The sample lyrics did not auto-assign.');
    Check(Cost < 0.5, 'The sample lyrics did not align exactly.');
    for I := 0 to Model.LineCount - 1 do
    begin
      Check(Model[I].StartNoteIndex = ExpectedStartNotes[I],
        'A line starts on the wrong sample note.');
      Check(CountMusicSyncRequiredNotes(Model[I].SyncText,
        CountLyricsDisplayUnits(Model[I].SourceText)) =
        ExpectedNoteCounts[I],
        'A line consumed the wrong number of sample notes.');
    end;
  finally
    Model.Free;
  end;
  Application.Initialize;
  SyncForm := TFormLyricsMusicSyncSettings.Create(nil);
  try
    SyncForm.SetAnchor(0, 30, 1);
    SyncForm.SetSequencePreDisplaySeconds(0.5);
    SyncForm.LoadSettings(ParamStr(1), 0, 0.5, '', '');
    Check(SyncForm.AvailableNoteCount = 30,
      'The editor skipped the first MIDI note during pre-display.');
    Check(Abs(SyncForm.LineSyncStartSeconds - 0.5) < 0.000001,
      'The first editor note does not start after pre-display.');
  finally
    SyncForm.Free;
  end;
  Writeln('PASS');
end.
