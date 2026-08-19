program SYNC_Lyrics_FormSmokeTest;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.SysUtils,
  System.UITypes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  SYNC_Lyrics_DarkTheme in '..\Source\Lib\SYNC_Lyrics_DarkTheme.pas',
  SYNC_Lyrics_ListBoxEdit in '..\Source\Lib\SYNC_Lyrics_ListBoxEdit.pas',
  SYNC_Lyrics_ToolbarButtons in '..\Source\Lib\SYNC_Lyrics_ToolbarButtons.pas',
  SYNC_Lyrics_LyricParser in '..\Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_DisplaySettingsData in '..\Source\Common\Render\SYNC_Lyrics_DisplaySettingsData.pas',
  SYNC_Lyrics_SyncFormat in '..\Source\Common\Sync\SYNC_Lyrics_SyncFormat.pas',
  SYNC_Lyrics_SongLyricsData in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsData.pas',
  SYNC_Lyrics_SongLyricsModel in '..\Source\Common\Lyrics\SYNC_Lyrics_SongLyricsModel.pas',
  SYNC_Lyrics_InitialLyricsFrame in '..\Source\Plugin\Filter\SYNC_Lyrics_InitialLyricsFrame.pas',
  SYNC_Lyrics_MusicSyncSettingsForm in '..\Source\Plugin\Filter\SYNC_Lyrics_MusicSyncSettingsForm.pas',
  SYNC_Lyrics_MusicSyncEditorFrame in '..\Source\Plugin\Filter\SYNC_Lyrics_MusicSyncEditorFrame.pas',
  SYNC_Lyrics_LineDisplaySettingsForm in '..\Source\Plugin\Filter\SYNC_Lyrics_LineDisplaySettingsForm.pas',
  SYNC_Lyrics_CharacterLayoutSettingsForm in '..\Source\Plugin\Filter\SYNC_Lyrics_CharacterLayoutSettingsForm.pas',
  SYNC_Lyrics_SyncEditorForm in '..\Source\Plugin\Filter\SYNC_Lyrics_SyncEditorForm.pas';

var
  CandidateCaptions: TArray<string>;
  CandidateCommon: TArray<TDisplayCommonSettings>;
  CandidateLyrics: TArray<string>;
  CharacterLayoutForm: TFormLyricsCharacterLayoutSettings;
  EditorForm: TFormLyricsSyncEditor;
  InputFrame: TFrameLyricsInitialInput;
  LineDisplayForm: TFormLyricsLineDisplaySettings;
  MusicSyncFrame: TFrameLyricsMusicSyncEditor;
  MusicSyncForm: TFormLyricsMusicSyncSettings;
  LyricsToolbar: TSyncLyricsToolbarButtons;
  TopToolbar: TSyncLyricsToolbarButtons;
  Key: Word;
  ErrorText: string;
  SongDataText: string;
  ReloadedModel: TLyricsSongModel;
  StoredModel: TLyricsSongModel;
  CanClose: Boolean;

function FindOwnedComponentByClass(Owner: TComponent;
  ComponentClass: TComponentClass): TComponent;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Owner.ComponentCount - 1 do
    if Owner.Components[I].InheritsFrom(ComponentClass) then
      Exit(Owner.Components[I]);
end;

function FindChildControlByClass(Parent: TWinControl;
  ControlClass: TControlClass): TControl;
var
  Child: TControl;
  I: Integer;
begin
  Result := nil;
  for I := 0 to Parent.ControlCount - 1 do
  begin
    Child := Parent.Controls[I];
    if Child.InheritsFrom(ControlClass) then
      Exit(Child);
    if Child is TWinControl then
    begin
      Result := FindChildControlByClass(TWinControl(Child), ControlClass);
      if Result <> nil then
        Exit;
    end;
  end;
end;

begin
  try
    Application.Initialize;
    LineDisplayForm := TFormLyricsLineDisplaySettings.Create(nil);
    try
      if LineDisplayForm.Color <> SYNC_LYRICS_DARK_BACKGROUND_COLOR then
        raise Exception.Create('The placement editor did not use the dark background.');
      if (LineDisplayForm.CandidateCombo.Style <> csOwnerDrawFixed) or
        not Assigned(LineDisplayForm.CandidateCombo.OnDrawItem) then
        raise Exception.Create('The placement combo box was not owner-drawn.');
      if LineDisplayForm.LyricsEdit.Color <>
        SYNC_LYRICS_DARK_CONTROL_COLOR then
        raise Exception.Create('The placement edit did not use the dark control color.');
      if (LineDisplayForm.DescriptionLabel.Caption = '') or
        (Ord(LineDisplayForm.DescriptionLabel.Caption[1]) <> $672C) then
        raise Exception.Create(
          'The line display instructions were not compiled as Unicode.');
      CandidateCaptions := ['1: first', '2: second'];
      CandidateLyrics := ['first', 'second'];
      SetLength(CandidateCommon, 2);
      CandidateCommon[0] := DefaultDisplayCommonSettings;
      CandidateCommon[1] := DefaultDisplayCommonSettings;
      LineDisplayForm.ConfigureCandidates(CandidateCaptions,
        CandidateLyrics, CandidateCommon, 1);
      if not LineDisplayForm.CandidateCombo.Visible or
        (LineDisplayForm.SelectedCandidateIndex <> 1) or
        (LineDisplayForm.LyricsEdit.Text <> 'second') then
        raise Exception.Create(
          'The initial placement candidate was not loaded.');
      if not LineDisplayForm.LyricsEdit.ReadOnly then
        raise Exception.Create(
          'The placement candidate lyric remained editable.');
    finally
      LineDisplayForm.Free;
    end;
    CharacterLayoutForm := TFormLyricsCharacterLayoutSettings.Create(nil);
    try
      if CharacterLayoutForm.Color <>
        SYNC_LYRICS_DARK_BACKGROUND_COLOR then
        raise Exception.Create(
          'The character placement editor did not use the dark background.');
      if (CharacterLayoutForm.CandidateCombo.Style <> csOwnerDrawFixed) or
        not Assigned(CharacterLayoutForm.CandidateCombo.OnDrawItem) then
        raise Exception.Create(
          'The character placement combo box was not owner-drawn.');
      if CharacterLayoutForm.ElementListView.Color <>
        SYNC_LYRICS_DARK_CONTROL_COLOR then
        raise Exception.Create(
          'The character placement list did not use the dark control color.');
      if CharacterLayoutForm.ButtonPanel.Color <>
        SYNC_LYRICS_DARK_PANEL_COLOR then
        raise Exception.Create(
          'The character placement button panel was not dark.');
    finally
      CharacterLayoutForm.Free;
    end;
    EditorForm := TFormLyricsSyncEditor.Create(nil);
    try
      if EditorForm.Color <> SYNC_LYRICS_DARK_BACKGROUND_COLOR then
        raise Exception.Create('The song sync editor was not dark.');
      EditorForm.SetAnchor(100, 30, 1);
      EditorForm.SetCurrentObjectFrame(45);
      EditorForm.HandleNeeded;
      EditorForm.Show;
      InputFrame := EditorForm.FindComponent(
        'FrameLyricsInitialInput') as TFrameLyricsInitialInput;
      if InputFrame = nil then
        InputFrame := FindOwnedComponentByClass(EditorForm,
          TFrameLyricsInitialInput) as TFrameLyricsInitialInput;
      if InputFrame = nil then
        InputFrame := FindChildControlByClass(EditorForm,
          TFrameLyricsInitialInput) as TFrameLyricsInitialInput;
      if InputFrame = nil then
        raise Exception.Create('The initial lyrics frame was not created.');
      if (InputFrame.Color <> SYNC_LYRICS_DARK_BACKGROUND_COLOR) or
        (InputFrame.LyricsMemo.Color <>
          SYNC_LYRICS_DARK_CONTROL_COLOR) then
        raise Exception.Create('The initial lyrics input was not dark.');
      TopToolbar := FindChildControlByClass(EditorForm.BottomPanel,
        TSyncLyricsToolbarButtons) as TSyncLyricsToolbarButtons;
      if (TopToolbar = nil) or (TopToolbar.ItemCount <> 5) or
        (TopToolbar.Items[0].Glyph <> tbgClose) or
        (TopToolbar.Items[1].Glyph <> tbgRestore) or
        (TopToolbar.Items[2].Glyph <> tbgNext) or
        (TopToolbar.Items[3].Glyph <> tbgConfirm) or
        (TopToolbar.Items[4].Glyph <> tbgResetAll) then
        raise Exception.Create(
          'The top actions did not use the common icon toolbar.');
      if (EditorForm.SyncStateLabel.Top <> TopToolbar.Top) or
        (EditorForm.SyncStateLabel.Height <> TopToolbar.Height) then
        raise Exception.Create(
          'The synchronization state was not vertically aligned with the icons.');
      if not TopToolbar.Items[0].Enabled then
        raise Exception.Create(
          'The initial lyrics page did not provide the common close action.');
      if not TopToolbar.Items[2].Visible then
        raise Exception.Create(
          'The initial lyrics page did not provide the next action.');
      TopToolbar.Items[2].Execute;
      if EditorForm.LineListBox.Items.Count <> 5 then
        raise Exception.Create('The confirmed lyrics did not create five lines.');
      if (EditorForm.FindComponent('LineListHeaderLabel') <> nil) or
        (EditorForm.FindComponent('LineHintLabel') <> nil) or
        (EditorForm.FindComponent('SummaryLabel') <> nil) or
        (EditorForm.LineListBox.Height <= 418) then
        raise Exception.Create(
          'Removing the lyric labels did not expand the line list vertically.');
      if EditorForm.LineListBox.ItemIndex <> 0 then
        raise Exception.Create('The first lyric line was not selected.');
      if not TopToolbar.Items[1].Enabled then
        raise Exception.Create('The restore action was not available.');
      if TopToolbar.Items[2].Visible then
        raise Exception.Create(
          'The next action remained visible in the synchronization editor.');
      LyricsToolbar := FindChildControlByClass(EditorForm.LineListPanel,
        TSyncLyricsToolbarButtons) as TSyncLyricsToolbarButtons;
      if (LyricsToolbar = nil) or (LyricsToolbar.ItemCount <> 3) then
        raise Exception.Create(
          'The lyric-line toolbar was not created above the line list.');
      if (LyricsToolbar.Items[0].Glyph <> tbgAdd) or
        (LyricsToolbar.Items[1].Glyph <> tbgDelete) or
        (LyricsToolbar.Items[2].Glyph <> tbgEdit) then
        raise Exception.Create(
          'The lyric-line toolbar did not use add, delete, and edit glyphs.');
      if LyricsToolbar.Top >= EditorForm.LineListBox.Top then
        raise Exception.Create(
          'The lyric-line toolbar was not placed above the line list.');
      if not LyricsToolbar.Items[0].Enabled or
        not LyricsToolbar.Items[1].Enabled or
        not LyricsToolbar.Items[2].Enabled then
        raise Exception.Create(
          'The lyric-line toolbar actions were not enabled.');
      LyricsToolbar.Items[0].Execute;
      if (EditorForm.LineListBox.Items.Count <> 6) or
        not EditorForm.LineListBox.IsEditing or
        (EditorForm.LineListBox.EditControl.Text <> '') then
        raise Exception.Create(
          'Adding a lyric line did not begin an empty inline edit.');
      if EditorForm.LineListBox.EditControl.Height <>
        EditorForm.LineListBox.ItemHeight then
        raise Exception.Create(
          'The inline lyric editor height did not match its list row.');
      EditorForm.LineListBox.EndEdit(True);
      if not EditorForm.LineListBox.IsEditing then
        raise Exception.Create(
          'An empty new lyric line was accepted unexpectedly.');
      EditorForm.LineListBox.EndEdit(False);
      if (EditorForm.LineListBox.Items.Count <> 5) or
        EditorForm.LineListBox.IsEditing then
        raise Exception.Create(
          'Canceling a new inline lyric did not remove the pending line.');
      EditorForm.LineListBox.ItemIndex := 0;
      EditorForm.LineListBoxClick(EditorForm.LineListBox);
      LyricsToolbar.Items[2].Execute;
      if not EditorForm.LineListBox.IsEditing or
        (EditorForm.LineListBox.EditControl.Text <>
          '['#26143#31354']('#12411#12375#12382#12425')'#12434#35211#19978#12370#12390) then
        raise Exception.Create(
          'The edit glyph did not begin editing the selected lyric syntax.');
      EditorForm.LineListBox.EndEdit(False);
      MusicSyncFrame := EditorForm.FindComponent(
        'FrameLyricsMusicSyncEditor') as TFrameLyricsMusicSyncEditor;
      if MusicSyncFrame = nil then
        raise Exception.Create('The music synchronization frame was not created.');
      MusicSyncForm := MusicSyncFrame.FindComponent(
        'FormLyricsMusicSyncSettings') as TFormLyricsMusicSyncSettings;
      if MusicSyncForm = nil then
        MusicSyncForm := FindOwnedComponentByClass(MusicSyncFrame,
          TFormLyricsMusicSyncSettings) as TFormLyricsMusicSyncSettings;
      if MusicSyncForm = nil then
        MusicSyncForm := FindChildControlByClass(MusicSyncFrame,
          TFormLyricsMusicSyncSettings) as TFormLyricsMusicSyncSettings;
      if (MusicSyncForm = nil) or
        (MusicSyncForm.Color <> SYNC_LYRICS_DARK_BACKGROUND_COLOR) or
        (MusicSyncForm.LyricsEdit.Color <>
          SYNC_LYRICS_DARK_CONTROL_COLOR) then
        raise Exception.Create('The music synchronization editor was not dark.');
      if MusicSyncForm.ResetSyncButton.ClassType <> TButton then
        raise Exception.Create(
          'The reset synchronization button did not use the standard UI.');
      if MusicSyncForm.BottomPanel.Visible or
        not TopToolbar.Items[4].Visible then
        raise Exception.Create(
          'The embedded synchronization controls were not moved to the top bar.');
      if MusicSyncForm.PianoRollPaintBox.Height <>
        MusicSyncForm.ClientHeight then
        raise Exception.Create(
          'Removing the embedded lyrics row did not expand the editor.');
      MusicSyncForm.PianoRollPaintBoxMouseMove(
        MusicSyncForm.PianoRollPaintBox, [], 4, 4);
      if MusicSyncForm.PianoRollPaintBox.Cursor <> crDefault then
        raise Exception.Create(
          'The empty piano-roll area did not use the default cursor.');
      MusicSyncForm.PianoRollPaintBoxMouseDown(
        MusicSyncForm.PianoRollPaintBox, mbLeft, [], 4, 4);
      if MusicSyncForm.PianoRollPaintBox.Cursor <> crDefault then
        raise Exception.Create(
          'Panning the piano roll did not use the default cursor.');
      MusicSyncForm.PianoRollPaintBoxMouseUp(
        MusicSyncForm.PianoRollPaintBox, mbLeft, [], 4, 4);
      if EditorForm.LineListBox.Color <>
        SYNC_LYRICS_DARK_CONTROL_COLOR then
        raise Exception.Create('The song line list was not dark.');
      if MusicSyncFrame.LyricsText <>
        '['#26143#31354']('#12411#12375#12382#12425')'#12434#35211#19978#12370#12390 then
        raise Exception.Create('The first lyric line was not loaded into the editor.');
      TopToolbar.Items[3].Execute;
      if TopToolbar.Items[3].CheckState <> tbcsChecked then
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
      if TopToolbar.Items[3].CheckState <> tbcsChecked then
        raise Exception.Create('The confirmed state was not retained after switching.');
      TopToolbar.Items[3].Execute;
      if TopToolbar.Items[3].CheckState <> tbcsUnchecked then
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
        CanClose := True;
        EditorForm.FormCloseQuery(EditorForm, CanClose);
        if not CanClose or (EditorForm.ModalResult <> mrOk) then
          raise Exception.Create(
            'Closing the window did not save and complete the editor.');
        SongDataText := EditorForm.SongDataText;
        if not SongDataText.StartsWith('SLD1,') then
          raise Exception.Create('The editor did not save an SLD1 document.');
      finally
        EditorForm.Free;
      end;
      if not TryDecodeSongLyrics(SongDataText, ReloadedModel,
        ErrorText) then
        raise Exception.Create('The editor output could not be decoded: ' + ErrorText);
      if ReloadedModel[0].DisplayLane <> 3 then
        raise Exception.Create('Saving did not persist the edited display lane.');
      if (ReloadedModel[0].SyncText <> DEFAULT_MUSIC_SYNC_TEXT) or
        (ReloadedModel[1].SyncText <> DEFAULT_MUSIC_SYNC_TEXT) then
        raise Exception.Create(
          'Saving did not persist default synchronization for every lyric line.');
      EditorForm := TFormLyricsSyncEditor.Create(nil);
      try
        if not EditorForm.TryLoadSongData(SongDataText, ErrorText) then
          raise Exception.Create(
            'The restore test could not load Filter text: ' + ErrorText);
        TopToolbar := FindChildControlByClass(EditorForm.BottomPanel,
          TSyncLyricsToolbarButtons) as TSyncLyricsToolbarButtons;
        if TopToolbar = nil then
          raise Exception.Create('The restore test could not find the top toolbar.');
        Key := Ord('1');
        EditorForm.LineListBoxKeyDown(EditorForm.LineListBox, Key, []);
        TopToolbar.Items[1].Execute;
        CanClose := True;
        EditorForm.FormCloseQuery(EditorForm, CanClose);
        if not CanClose then
          raise Exception.Create('The restored editor could not close.');
        SongDataText := EditorForm.SongDataText;
      finally
        EditorForm.Free;
      end;
      if not TryDecodeSongLyrics(SongDataText, ReloadedModel,
        ErrorText) or (ReloadedModel[0].DisplayLane <> 3) then
        raise Exception.Create(
          'Restoring did not recover the state from before editing.');
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
