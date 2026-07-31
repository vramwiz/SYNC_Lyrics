program SYNC_Lyrics_SongLyricsDataTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  SYNC_Lyrics_LyricParser in '..\Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_SyncFormat in '..\Source\Common\Sync\SYNC_Lyrics_SyncFormat.pas',
  SYNC_Lyrics_SongLyricsModel in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsModel.pas',
  SYNC_Lyrics_SongLyricsData in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsData.pas',
  SYNC_Lyrics_SongLyricsRuntime in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsRuntime.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure RunTests;
var
  Decoded: TLyricsSongModel;
  EncodedText: string;
  ErrorText: string;
  HugeModel: TLyricsSongModel;
  Lines: TLyricsSongLines;
  ActiveIndexes: TLyricsSongLineIndexes;
  ProgressUnits: Double;
  RuntimeLines: TLyricsSongLines;
  Model: TLyricsSongModel;
begin
  Model := TLyricsSongModel.Create;
  Decoded := TLyricsSongModel.Create;
  HugeModel := TLyricsSongModel.Create;
  try
    Model.SetLyricsText(
      '['#26143#31354']('#12411#12375#12382#12425')'#12434#35211#19978#12370#12390 +
      sLineBreak + #26410#26469#12408);
    Check(Model.TrySetDisplayLane(1, 3), 'The display lane setup failed.');
    Check(Model.TryConfirmSync(0, 0.75, 'MS1;1,0'),
      'The synchronization setup failed.');
    Lines := Model.CopyLines;
    Lines[0].DisplayStartFrame := 120;
    Lines[0].DisplayEndFrame := 240;
    Lines[0].SyncStartFrame := 135;
    Lines[0].SyncEndFrame := 220;
    Lines[0].TimingMusicOffsetSeconds := 0.5;
    Lines[0].PlacementText := 'PL1';
    Model.ReplaceLines(Lines);

    Check(TryEncodeSongLyrics(Model, EncodedText, ErrorText),
      'Encoding failed: ' + ErrorText);
    Check(TryDecodeSongLyrics(EncodedText, Decoded, ErrorText),
      'Decoding failed: ' + ErrorText);
    Check(Decoded.LineCount = 2, 'The decoded line count is invalid.');
    Check(Decoded[0].LineID = Model[0].LineID,
      'The stable line identity was not preserved.');
    Check(Decoded[1].DisplayLane = 3,
      'The display lane was not preserved.');
    Check(Decoded[0].SyncState = lssConfirmed,
      'The synchronization state was not preserved.');
    Check(Decoded[0].SyncText = 'MS1;1,0',
      'The synchronization text was not preserved.');
    Check(Decoded[0].DisplayStartFrame = 120,
      'The display start frame was not preserved.');
    Check(Decoded[0].SyncEndFrame = 220,
      'The synchronization end frame was not preserved.');
    Check(Abs(Decoded[0].TimingMusicOffsetSeconds - 0.5) < 0.000001,
      'The timing music offset was not preserved.');
    Check(Abs(Decoded[0].HoldSeconds - 0.5) < 0.000001,
      'The temporary hold duration was not preserved.');
    Check(Decoded[1].StartNoteIndex = Model[1].StartNoteIndex,
      'The continuous music note offset was not preserved.');
    Check(Decoded[0].PlacementText = 'PL1',
      'The placement text was not preserved.');

    Check(not TryDecodeSongLyrics('invalid', Decoded, ErrorText),
      'Malformed Filter text must be rejected.');
    Check(Decoded.LineCount = 2,
      'A failed decode must not mutate the current model.');
    Check(TryGetSongLyricsLines(EncodedText, RuntimeLines),
      'The runtime cache did not decode valid Filter text.');
    Check(ResolveSongLyricsLineIndex(RuntimeLines, 150) = 0,
      'The persisted timed line was not resolved.');
    RuntimeLines := ApplyMusicOffsetToSongLyricsLines(
      RuntimeLines, 1.0, 30, 1);
    Check((RuntimeLines[0].DisplayStartFrame = 135) and
      (RuntimeLines[0].SyncStartFrame = 150) and
      (RuntimeLines[0].DisplayEndFrame = 255) and
      (RuntimeLines[0].SyncEndFrame = 235),
      'Changing the music offset did not shift persisted ranges.');
    RuntimeLines[0].DisplayStartFrame := -1;
    RuntimeLines[0].DisplayEndFrame := -1;
    RuntimeLines[1].DisplayStartFrame := -1;
    RuntimeLines[1].DisplayEndFrame := -1;
    Check(ResolveSongLyricsLineIndex(RuntimeLines, 999) = 0,
      'Untimed data must fall back to the first lyric line.');
    Lines := Model.CopyLines;
    Lines[0].DisplayStartFrame := 0;
    Lines[0].DisplayEndFrame := 9;
    Lines[1].DisplayStartFrame := 10;
    Lines[1].DisplayEndFrame := 20;
    Lines[1].DisplayLane := Lines[0].DisplayLane;
    Model.ReplaceLines(Lines);
    Check(TryEncodeSongLyrics(Model, EncodedText, ErrorText),
      'Timed data encoding failed: ' + ErrorText);
    Check(TryGetSongLyricsLines(EncodedText, RuntimeLines),
      'Timed data was not cached.');
    Check(ResolveSongLyricsLineIndex(RuntimeLines, 5) = 0,
      'The first timed line was not resolved.');
    Check(ResolveSongLyricsLineIndex(RuntimeLines, 10) = 1,
      'The second timed line was not resolved.');
    Check(ResolveSongLyricsLineIndex(RuntimeLines, 21) = -1,
      'A frame outside every range must not resolve a lyric line.');
    Lines := Model.CopyLines;
    Lines[0].DisplayLane := 1;
    Lines[0].DisplayStartFrame := 0;
    Lines[0].DisplayEndFrame := 20;
    Lines[1].DisplayLane := 2;
    Lines[1].DisplayStartFrame := 5;
    Lines[1].DisplayEndFrame := 15;
    Model.ReplaceLines(Lines);
    Check(TryEncodeSongLyrics(Model, EncodedText, ErrorText),
      'Overlapping lane data encoding failed: ' + ErrorText);
    Check(TryGetSongLyricsLines(EncodedText, RuntimeLines),
      'Overlapping lane data was not cached.');
    ActiveIndexes := ResolveSongLyricsLineIndexes(RuntimeLines, 10);
    Check((Length(ActiveIndexes) = 2) and
      (ActiveIndexes[0] = 0) and (ActiveIndexes[1] = 1),
      'Overlapping display lanes were not resolved together.');
    Lines := Model.CopyLines;
    Lines[0].DisplayLane := 1;
    Lines[0].DisplayStartFrame := 0;
    Lines[0].DisplayEndFrame := 20;
    Lines[1].DisplayLane := 1;
    Lines[1].DisplayStartFrame := 10;
    Lines[1].DisplayEndFrame := 30;
    Model.ReplaceLines(Lines);
    Check(TryEncodeSongLyrics(Model, EncodedText, ErrorText),
      'Same-lane overlap encoding failed: ' + ErrorText);
    Check(TryGetSongLyricsLines(EncodedText, RuntimeLines),
      'Same-lane overlap data was not cached.');
    ActiveIndexes := ResolveSongLyricsLineIndexes(RuntimeLines, 10);
    Check((Length(ActiveIndexes) = 1) and (ActiveIndexes[0] = 1),
      'The newer line did not replace the older line in the same lane.');

    Lines[0].DisplayStartFrame := 0;
    Lines[0].DisplayEndFrame := 30;
    Lines[0].SyncStartFrame := 5;
    Lines[0].SyncEndFrame := 10;
    Lines[1].DisplayStartFrame := 8;
    Lines[1].DisplayEndFrame := 25;
    Lines[1].SyncStartFrame := 12;
    Lines[1].SyncEndFrame := 18;
    ActiveIndexes := ResolveSongLyricsPlacementCandidateIndexes(
      Lines, 14);
    Check((Length(ActiveIndexes) = 2) and
      (ActiveIndexes[0] = 0) and (ActiveIndexes[1] = 1),
      'Every overlapping placement candidate was not returned.');
    Check(ResolveSongLyricsPlacementInitialCandidate(
      Lines, ActiveIndexes, 14) = 1,
      'The line inside its synchronization range was not preferred.');
    ActiveIndexes := ResolveSongLyricsPlacementCandidateIndexes(
      Lines, 40);
    Check((Length(ActiveIndexes) = 1) and (ActiveIndexes[0] = 1),
      'The nearest synchronized line was not used outside display ranges.');

    Lines[1].SyncStartFrame := 12;
    Lines[1].SyncEndFrame := 18;
    Check(TryResolveSongLyricsLineBoundaryProgress(
      Lines[1], 11, 4, ProgressUnits) and
      (Abs(ProgressUnits) < 0.000001),
      'A frame before synchronization did not remain unconsumed.');
    Check(not TryResolveSongLyricsLineBoundaryProgress(
      Lines[1], 12, 4, ProgressUnits),
      'The synchronization start frame must use the live resolver.');
    Check(not TryResolveSongLyricsLineBoundaryProgress(
      Lines[1], 17, 4, ProgressUnits),
      'A frame inside synchronization must use the live resolver.');
    Check(TryResolveSongLyricsLineBoundaryProgress(
      Lines[1], 18, 4, ProgressUnits) and
      (Abs(ProgressUnits - 4) < 0.000001),
      'The synchronization end frame did not complete the line.');
    HugeModel.SetLyricsText(StringOfChar('x', 25000));
    Check(not TryEncodeSongLyrics(HugeModel, EncodedText, ErrorText),
      'Text exceeding the Filter string limit must be rejected.');
  finally
    HugeModel.Free;
    Decoded.Free;
    Model.Free;
  end;
end;

begin
  try
    RunTests;
    Writeln('PASS');
  except
    on E: Exception do
    begin
      Writeln('FAIL: ' + E.Message);
      Halt(1);
    end;
  end;
end.
