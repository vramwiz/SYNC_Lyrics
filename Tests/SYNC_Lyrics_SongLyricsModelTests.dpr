program SYNC_Lyrics_SongLyricsModelTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  SYNC_Lyrics_LyricParser in '..\Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_SyncFormat in '..\Source\Common\Sync\SYNC_Lyrics_SyncFormat.pas',
  SYNC_Lyrics_SongLyricsModel in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsModel.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure RunTests;
var
  Model: TLyricsSongModel;
begin
  Model := TLyricsSongModel.Create;
  try
    Model.SetLyricsText(
      '['#26143#31354']('#12411#12375#12382#12425')'#12434#35211#19978#12370#12390 +
      sLineBreak + sLineBreak +
      '['#21531']('#12365#12415')'#12398#22768 +
      sLineBreak + #26410#26469#12408);
    Check(Model.LineCount = 3, 'Blank lines must not create lyric records.');
    Check(Model[0].LineID = 1, 'The first line ID must start at one.');
    Check(Model[1].LineID = 2, 'Line IDs must increase in display order.');
    Check(Model[0].PlainText = #26143#31354#12434#35211#19978#12370#12390,
      'Ruby syntax must be removed from list text.');
    Check(Length(Model[0].RubySpans) = 1,
      'Ruby spans must remain available in the line record.');
    Check(Model[0].DisplayLane = 1, 'The default display lane must be one.');
    Check(Model[0].SyncState = lssUnset,
      'New lyric lines must start with unset synchronization.');
    Check(Model[0].StartNoteIndex = 0,
      'The first lyric line must start with the first music note.');
    Check(Model[1].StartNoteIndex =
      CountLyricsDisplayUnits(Model[0].SourceText),
      'The second lyric line must start after the first line notes.');
    Check(Model[0].PreDisplaySeconds < 0,
      'New lyric lines must inherit the editor pre-display time.');
    Check(Abs(Model[0].HoldSeconds - 0.5) < 0.000001,
      'New lyric lines must use the temporary hold duration.');
    Check(Abs(Model[0].TimingMusicOffsetSeconds) < 0.000001,
      'New lyric lines must start with a zero timing music offset.');
    Check(Model.TrySetPlacementText(0, 'SL2 placement'),
      'The placement text setup failed.');
    Check(Model[0].PlacementText = 'SL2 placement',
      'The placement text was not stored.');
    Check(not Model.TrySetPlacementText(0, 'invalid'#13#10'placement'),
      'Multiline placement text must be rejected.');
    Check(Model[0].PlacementText = 'SL2 placement',
      'Rejected placement text changed the current value.');
    Check(Model.TrySetDisplayLane(0, 3),
      'A supported display lane must be accepted.');
    Check(Model[0].DisplayLane = 3,
      'The accepted display lane must be stored.');
    Check(not Model.TrySetDisplayLane(0, 4),
      'An unsupported display lane must be rejected.');
    Check(not Model.TrySetDisplayLane(9, 1),
      'An invalid line index must be rejected.');
    Check(Model.TrySetSync(1, 0.75, 'MS1;1,0'),
      'Synchronization data must be accepted for an existing line.');
    Check(Model[1].PreDisplaySeconds = 0.75,
      'Per-line pre-display time must be stored.');
    Check(Model[1].SyncText = 'MS1;1,0',
      'Per-line synchronization text must be stored.');
    Check(Model[1].SyncState = lssProvisional,
      'Edited synchronization must become provisional.');
    Check(Model.TryConfirmSync(1, 0.75, 'MS1;1,0'),
      'An existing synchronization must be confirmable.');
    Check(Model[1].SyncState = lssConfirmed,
      'Confirmed synchronization must retain its explicit state.');
    Check(Model.TrySetSync(1, 0.5, 'MS1;1,1'),
      'Confirmed synchronization data must remain editable.');
    Check(Model[1].SyncState = lssInconsistent,
      'Editing confirmed synchronization must flag an inconsistency.');
    Check(Model.TrySetSyncState(1, lssProvisional),
      'Synchronization confirmation must be releasable.');
    Check(Model[1].SyncState = lssProvisional,
      'Released synchronization must return to provisional state.');
    Check(not Model.TrySetSync(9, 0.5, ''),
      'Synchronization must reject an invalid line index.');
    Check(Model.TryInsertLine(1,
      '['#26032#12375#12356']('#12354#12383#12425#12375#12356')'#34892),
      'A lyric line must be insertable at the selected position.');
    Check(Model.LineCount = 4, 'Inserting must increase the line count.');
    Check(Model[1].LineID = 4,
      'An inserted line must receive a new stable identity.');
    Check(Model[2].LineID = 2,
      'Inserting must preserve the identity of following lines.');
    Check(Model[1].DisplayLane = 1,
      'An inserted line must use the default display lane.');
    Check(Model.TrySetPlacementText(2, 'line placement'),
      'A following line placement could not be stored.');
    Check(Model.TrySetLineText(2,
      '['#21531']('#12365#12415')'#12398#26032#12375#12356#22768),
      'An existing lyric syntax must be editable.');
    Check(Model[2].LineID = 2,
      'Editing lyric syntax must preserve the line identity.');
    Check(Model[2].PlainText = #21531#12398#26032#12375#12356#22768,
      'Editing lyric syntax must rebuild the parsed list text.');
    Check(Model[2].SyncState = lssInconsistent,
      'Editing a synchronized lyric must flag an inconsistency.');
    Check(Model[2].PlacementText = '',
      'Editing lyric syntax must clear its stale placement override.');
    Check(Model.TryDeleteLine(1),
      'The inserted lyric line must be deletable.');
    Check(Model.LineCount = 3, 'Deleting must reduce the line count.');
    Check(Model[1].LineID = 2,
      'Deleting must preserve the identity of following lines.');
    Check(Pos(#26032#12375#12356#22768,
      Model.LyricsText) > 0,
      'The whole-song text must reflect line syntax edits.');
    Check(not Model.TryInsertLine(9, 'invalid'),
      'Insertion must reject an invalid line index.');
    Check(not Model.TrySetLineText(0, ''),
      'Editing must reject an empty lyric line.');
    Check(not Model.TryDeleteLine(9),
      'Deletion must reject an invalid line index.');
    Check(Model.TryConfirmSync(0, 0.5, 'MS1;1'),
      'The timing test line must be confirmable.');
    Check(Model.TrySetStartFrames(0, 120, 135),
      'Display and synchronization starts must be set together.');
    Check(Model[0].DisplayStartFrame = 120,
      'The display start frame was not stored.');
    Check(Model[0].SyncStartFrame = 135,
      'The synchronization start frame was not stored.');
    Check(Model[0].SyncState = lssInconsistent,
      'Changing confirmed start timing must flag an inconsistency.');
    Check(not Model.TrySetEndFrames(0, 100, 140),
      'An end before the display start must be rejected.');
    Check(Model.TrySetEndFrames(0, 240, 220),
      'Valid display and synchronization ends must be stored.');
    Check(Model[0].DisplayEndFrame = 240,
      'The display end frame was not stored.');

    Model.SetLyricsText('ab' + sLineBreak + 'cd' + sLineBreak + 'ef');
    Check((Model[0].StartNoteIndex = 0) and
      (Model[1].StartNoteIndex = 2) and
      (Model[2].StartNoteIndex = 4),
      'Default one-note groups must form one continuous song sequence.');
    Check(Model.TrySetSync(0, 0,
      SerializeMusicSyncText([1, 0])),
      'The first line adjusted synchronization was not accepted.');
    Check(Model[1].StartNoteIndex = 3,
      'An unconfirmed following line must follow the adjusted note count.');
    Check(Model.TryConfirmSync(1, 0, DEFAULT_MUSIC_SYNC_TEXT),
      'The second line could not be fixed.');
    Check(Model.TrySetSync(0, 0,
      SerializeMusicSyncText([2, 0])),
      'The first line could not be adjusted again.');
    Check(Model[1].StartNoteIndex = 3,
      'A confirmed following line must retain its music note position.');
    Check(Model.TrySetSyncState(1, lssProvisional),
      'The second line confirmation could not be released.');
    Check(Model[1].StartNoteIndex = 3,
      'An edited line must keep its fixed music note position.');
  finally
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
