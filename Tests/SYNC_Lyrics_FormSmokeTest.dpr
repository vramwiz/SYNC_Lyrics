program SYNC_Lyrics_FormSmokeTest;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.UITypes,
  Vcl.Forms,
  SYNC_Lyrics_LyricParser in '..\Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_SyncFormat in '..\Source\Common\Sync\SYNC_Lyrics_SyncFormat.pas',
  SYNC_Lyrics_SongLyricsData in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsData.pas',
  SYNC_Lyrics_SongLyricsModel in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsModel.pas',
  SYNC_Lyrics_InitialLyricsFrame in '..\Source\Plugin\Filter\SYNC_Lyrics_InitialLyricsFrame.pas',
  SYNC_Lyrics_MusicSyncEditorFrame in '..\Source\Plugin\Filter\SYNC_Lyrics_MusicSyncEditorFrame.pas',
  SYNC_Lyrics_SyncEditorForm in '..\Source\Plugin\Filter\SYNC_Lyrics_SyncEditorForm.pas';

var
  EditorForm: TFormLyricsSyncEditor;
  InputFrame: TFrameLyricsInitialInput;
  MusicSyncFrame: TFrameLyricsMusicSyncEditor;
  Key: Word;
  ErrorText: string;
  SongDataText: string;
  ReloadedModel: TLyricsSongModel;
  StoredModel: TLyricsSongModel;

begin
  try
    Application.Initialize;
    EditorForm := TFormLyricsSyncEditor.Create(nil);
    try
      EditorForm.SetAnchor(100, 30, 1);
      EditorForm.SetCurrentObjectFrame(45);
      EditorForm.HandleNeeded;
      EditorForm.Show;
      InputFrame := EditorForm.FindComponent(
        'FrameLyricsInitialInput') as TFrameLyricsInitialInput;
      if InputFrame = nil then
        raise Exception.Create('The initial lyrics frame was not created.');
      InputFrame.ConfirmButton.Click;
      if EditorForm.LineListBox.Items.Count <> 5 then
        raise Exception.Create('The confirmed lyrics did not create five lines.');
      if EditorForm.LineListBox.ItemIndex <> 0 then
        raise Exception.Create('The first lyric line was not selected.');
      MusicSyncFrame := EditorForm.FindComponent(
        'FrameLyricsMusicSyncEditor') as TFrameLyricsMusicSyncEditor;
      if MusicSyncFrame = nil then
        raise Exception.Create('The music synchronization frame was not created.');
      if MusicSyncFrame.LyricsText <>
        '['#26143#31354']('#12411#12375#12382#12425')'#12434#35211#19978#12370#12390 then
        raise Exception.Create('The first lyric line was not loaded into the editor.');
      EditorForm.StartFrameButton.Click;
      if Pos('45-', EditorForm.CurrentFrameLabel.Caption) = 0 then
        raise Exception.Create('The current frame was not assigned as the start.');
      EditorForm.ConfirmSyncButton.Click;
      if EditorForm.ConfirmSyncButton.Tag <> Ord(lssConfirmed) then
        raise Exception.Create('The selected lyric line was not confirmed.');
      Key := Ord('2');
      EditorForm.LineListBoxKeyDown(EditorForm.LineListBox, Key, []);
      if EditorForm.LineListBox.ItemIndex <> 1 then
        raise Exception.Create('The display lane shortcut did not advance.');
      if MusicSyncFrame.LyricsText <>
        '['#21531']('#12365#12415')'#12398#22768#12434#25506#12375#12390#12427 then
        raise Exception.Create('Advancing did not load the next lyric line.');
      EditorForm.LineListBox.ItemIndex := 0;
      EditorForm.LineListBoxClick(EditorForm.LineListBox);
      if EditorForm.ConfirmSyncButton.Tag <> Ord(lssConfirmed) then
        raise Exception.Create('The confirmed state was not retained after switching.');
      EditorForm.ConfirmSyncButton.Click;
      if EditorForm.ConfirmSyncButton.Tag <> Ord(lssProvisional) then
        raise Exception.Create('The confirmed state was not released.');
      EditorForm.Hide;
    finally
      EditorForm.Free;
    end;

    StoredModel := TLyricsSongModel.Create;
    ReloadedModel := TLyricsSongModel.Create;
    try
      StoredModel.SetLyricsText('first' + sLineBreak + 'second');
      if not TryEncodeSongLyrics(StoredModel, SongDataText, ErrorText) then
        raise Exception.Create('Could not prepare stored text: ' + ErrorText);
      EditorForm := TFormLyricsSyncEditor.Create(nil);
      try
        if not EditorForm.TryLoadSongData(SongDataText, ErrorText) then
          raise Exception.Create('The editor did not load Filter text: ' + ErrorText);
        if EditorForm.LineListBox.Items.Count <> 2 then
          raise Exception.Create('The loaded song did not create two rows.');
        Key := Ord('3');
        EditorForm.LineListBoxKeyDown(EditorForm.LineListBox, Key, []);
        EditorForm.FinishButton.Click;
        if EditorForm.ModalResult <> mrOk then
          raise Exception.Create('Saving did not complete the editor.');
        SongDataText := EditorForm.SongDataText;
      finally
        EditorForm.Free;
      end;
      if not TryDecodeSongLyrics(SongDataText, ReloadedModel,
        ErrorText) then
        raise Exception.Create('The editor output could not be decoded: ' + ErrorText);
      if ReloadedModel[0].DisplayLane <> 3 then
        raise Exception.Create('Saving did not persist the edited display lane.');
    finally
      ReloadedModel.Free;
      StoredModel.Free;
    end;
    Writeln('FORM_OK');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      Halt(1);
    end;
  end;
end.
