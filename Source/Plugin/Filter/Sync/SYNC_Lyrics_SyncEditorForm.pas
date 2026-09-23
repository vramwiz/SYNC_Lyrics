unit SYNC_Lyrics_SyncEditorForm;

// Hosts the staged whole-song lyrics input and future per-line sync editor pages.

interface

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  SYNC_Lyrics_InitialLyricsFrame,
  SYNC_Lyrics_ListBoxEdit,
  SYNC_Lyrics_MusicSyncEditorFrame,
  SYNC_Lyrics_SongLyricsData,
  SYNC_Lyrics_SongLyricsModel,
  SYNC_Lyrics_ToolbarButtons;

type
  TFormLyricsSyncEditor = class(TForm)
    BottomPanel: TPanel;
    ContentPanel: TPanel;
    CurrentFrameLabel: TLabel;
    FrameCommandPanel: TPanel;
    LineListHostPanel: TPanel;
    LineListPanel: TPanel;
    LineToolbarPanel: TPanel;
    PlaceholderLabel: TLabel;
    PlaceholderPanel: TPanel;
    SyncStateLabel: TLabel;
    procedure AddLineButtonClick(Sender: TObject);
    procedure ConfirmSyncButtonClick(Sender: TObject);
    procedure DeleteLineButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure FinishButtonClick(Sender: TObject);
    procedure LineListBoxClick(Sender: TObject);
    procedure LineListBoxDblClick(Sender: TObject);
    procedure LineListBoxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure LineListBoxKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure NextButtonClick(Sender: TObject);
    procedure RestoreButtonClick(Sender: TObject);
    procedure ResetLineSyncButtonClick(Sender: TObject);
  private
    FConfirmedLyrics: string;
    FCommitComplete: Boolean;
    FCurrentObjectFrame: Integer;
    FCurrentObjectFrameAvailable: Boolean;
    FEditingWholeLyrics: Boolean;
    FInputFrame: TFrameLyricsInitialInput;
    FInitialInputLyrics: string;
    FInitialSongDataText: string;
    FLineListBox: TSyncLyricsListBoxEdit;
    FLyricsToolbar: TSyncLyricsToolbarButtons;
    FLyricsToolbarAdd: TSyncLyricsToolbarButton;
    FLyricsToolbarDelete: TSyncLyricsToolbarButton;
    FLyricsToolbarEdit: TSyncLyricsToolbarButton;
    FManualClearButton: TButton;
    FTopCloseButton: TSyncLyricsToolbarButton;
    FTopConfirmButton: TSyncLyricsToolbarButton;
    FTopLyricsButton: TSyncLyricsToolbarButton;
    FTopNextButton: TSyncLyricsToolbarButton;
    FTopResetButton: TSyncLyricsToolbarButton;
    FTopRestoreButton: TSyncLyricsToolbarButton;
    FTopToolbar: TSyncLyricsToolbarButtons;
    FMusicFileName: string;
    FMusicSyncFrame: TFrameLyricsMusicSyncEditor;
    FMusicTrack: Integer;
    FAnchorAvailable: Boolean;
    FAnchorFrame: Integer;
    FAnchorRate: Integer;
    FAnchorScale: Integer;
    FDefaultMusicOffsetSeconds: Double;
    FManualAudioDurationSeconds: Double;
    FDefaultHoldSeconds: Double;
    FDefaultPreDisplaySeconds: Double;
    FLoadedLineIndex: Integer;
    FNewLineEditIndex: Integer;
    FSongDataText: string;
    FSongModel: TLyricsSongModel;
    procedure CreateLineListBox;
    procedure CreateLyricsToolbar;
    procedure CreateTopToolbar;
    procedure EnsureMusicSyncFrame;
    procedure EditSelectedLine;
    procedure EditWholeLyrics;
    procedure LineListBoxApplyEdit(Sender: TObject; Index: Integer;
      const NewText: string; var Accept: Boolean);
    procedure LineListBoxCancelEdit(Sender: TObject; Index: Integer);
    procedure LineListBoxGetEditText(Sender: TObject; Index: Integer;
      var Text: string);
    procedure LoadSelectedLine;
    procedure LyricsConfirmed(Sender: TObject; const LyricsText: string);
    procedure LyricsToolbarButtonExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure MusicSyncChanged(Sender: TObject);
    procedure ManualLineSelected(Sender: TObject; LineIndex: Integer);
    procedure TopToolbarButtonExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure PersistDefaultMusicSyncData;
    procedure PopulateLineList;
    procedure RecalculateFrameRanges;
    function SaveForClose: Boolean;
    procedure SaveLoadedLine;
    procedure SelectLine(Index: Integer);
    procedure ShowSongEditor;
    procedure ShowInitialInput;
    procedure UpdateFrameControls;
    procedure UpdateMusicSyncReferences;
    procedure UpdateSyncStateControls;
    procedure UpdateSelectedLineSummary;
  public
    // Supplies the shared music source used while individual lines are selected.
    procedure ConfigureMusicSource(const MusicFileName: string; Track: Integer;
      MusicOffsetSeconds, PreDisplaySeconds, HoldSeconds: Double);
    // Supplies the current Filter position used as the synchronization origin.
    procedure SetAnchor(Frame, Rate, Scale: Integer);
    procedure SetAnchorUnavailable;
    procedure SetCurrentObjectFrame(Frame: Integer);
    function ConfirmedLyrics: string;
    function SongDataText: string;
    function TryLoadSongData(const DataText: string;
      out ErrorText: string): Boolean;
    property LineListBox: TSyncLyricsListBoxEdit read FLineListBox;
  end;

implementation

uses
  System.Math,
  System.UITypes,
  Winapi.Windows,
  Vcl.Dialogs,
  SYNC_Lyrics_DarkTheme,
  SYNC_Lyrics_AudioProbe,
  SYNC_Lyrics_ManualSyncSettingsForm,
  SYNC_Lyrics_MidiLyricAutoAssign,
  SYNC_Lyrics_SyncSourceKind,
  SYNC_Lyrics_SyncFormat;

{$R *.dfm}

const
  LYRICS_TOOLBAR_ADD = 1;
  LYRICS_TOOLBAR_DELETE = 2;
  LYRICS_TOOLBAR_EDIT = 3;
  TOP_TOOLBAR_CLOSE = 101;
  TOP_TOOLBAR_RESTORE = 102;
  TOP_TOOLBAR_NEXT = 103;
  TOP_TOOLBAR_CONFIRM = 104;
  TOP_TOOLBAR_RESET = 105;
  TOP_TOOLBAR_LYRICS = 106;
  NEW_LINE_PLACEHOLDER = '新しい歌詞';

function TFormLyricsSyncEditor.ConfirmedLyrics: string;
begin
  Result := FConfirmedLyrics;
end;

procedure TFormLyricsSyncEditor.CreateLineListBox;
begin
  FLineListBox := TSyncLyricsListBoxEdit.Create(Self);
  FLineListBox.Name := 'LineListBox';
  FLineListBox.Parent := LineListHostPanel;
  FLineListBox.SetBounds(0, 0, LineListHostPanel.ClientWidth,
    LineListHostPanel.ClientHeight);
  FLineListBox.Align := alClient;
  FLineListBox.ItemHeight := MulDiv(28, CurrentPPI, 96);
  FLineListBox.Style := lbOwnerDrawFixed;
  FLineListBox.TabOrder := 0;
  FLineListBox.OnClick := LineListBoxClick;
  FLineListBox.OnDblClick := LineListBoxDblClick;
  FLineListBox.OnDrawItem := LineListBoxDrawItem;
  FLineListBox.OnKeyDown := LineListBoxKeyDown;
  FLineListBox.OnApplyEdit := LineListBoxApplyEdit;
  FLineListBox.OnCancelEdit := LineListBoxCancelEdit;
  FLineListBox.OnGetEditText := LineListBoxGetEditText;
end;

procedure TFormLyricsSyncEditor.AddLineButtonClick(Sender: TObject);
var
  InsertIndex: Integer;
begin
  SaveLoadedLine;
  InsertIndex := LineListBox.ItemIndex + 1;
  if InsertIndex <= 0 then
    InsertIndex := FSongModel.LineCount;
  if not FSongModel.TryInsertLine(InsertIndex, NEW_LINE_PLACEHOLDER) then
    Exit;
  RecalculateFrameRanges;
  FConfirmedLyrics := FSongModel.LyricsText;
  FLoadedLineIndex := -1;
  PopulateLineList;
  FNewLineEditIndex := InsertIndex;
  SelectLine(InsertIndex);
  LineListBox.BeginEdit(InsertIndex);
end;

procedure TFormLyricsSyncEditor.ConfirmSyncButtonClick(Sender: TObject);
var
  LineData: TLyricsSongLine;
begin
  if LineListBox.IsEditing then
    Exit;
  if (FMusicSyncFrame = nil) or (FLoadedLineIndex < 0) or
    (FLoadedLineIndex >= FSongModel.LineCount) then
    Exit;
  if FMusicSyncFrame.HasChanges then
    SaveLoadedLine;
  LineData := FSongModel[FLoadedLineIndex];
  if LineData.SyncState = lssConfirmed then
    FSongModel.TrySetSyncState(FLoadedLineIndex, lssProvisional)
  else
  begin
    FSongModel.TryConfirmSync(FLoadedLineIndex,
      FMusicSyncFrame.PreDisplaySeconds, FMusicSyncFrame.SyncText);
    FMusicSyncFrame.AcceptChanges;
  end;
  LineListBox.Invalidate;
  UpdateSyncStateControls;
end;

procedure TFormLyricsSyncEditor.ConfigureMusicSource(
  const MusicFileName: string; Track: Integer; MusicOffsetSeconds,
  PreDisplaySeconds, HoldSeconds: Double);
var
  AudioInfo: TSyncAudioFileInfo;
  ProbeError: string;
begin
  FMusicFileName := MusicFileName;
  FMusicTrack := Track;
  FDefaultMusicOffsetSeconds := EnsureRange(
    MusicOffsetSeconds, -5.0, 5.0);
  FDefaultPreDisplaySeconds := Max(0.0, PreDisplaySeconds);
  FDefaultHoldSeconds := Max(0.0, HoldSeconds);
  FManualAudioDurationSeconds := 0;
  if (Trim(MusicFileName) <> '') and
    not IsMusicScoreFileName(MusicFileName) and
    TryProbeSyncAudioFile(MusicFileName, AudioInfo, ProbeError) then
    FManualAudioDurationSeconds := AudioInfo.DurationSeconds;
end;

procedure TFormLyricsSyncEditor.CreateLyricsToolbar;
var
  ButtonExtent: Integer;
begin
  ButtonExtent := MulDiv(28, CurrentPPI, 96);
  FLyricsToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FLyricsToolbar.Parent := LineToolbarPanel;
  FLyricsToolbar.Align := alLeft;
  FLyricsToolbar.Width := ButtonExtent * 3;
  FLyricsToolbar.ButtonExtent := ButtonExtent;
  FLyricsToolbar.Color := SYNC_LYRICS_DARK_PANEL_COLOR;
  FLyricsToolbar.ParentBackground := False;
  FLyricsToolbar.OnButtonExecute := LyricsToolbarButtonExecute;
  FLyricsToolbarAdd := FLyricsToolbar.AddCommandButton(
    '歌詞行を追加', tbgAdd, LYRICS_TOOLBAR_ADD);
  FLyricsToolbarDelete := FLyricsToolbar.AddCommandButton(
    '選択した歌詞行を削除', tbgDelete, LYRICS_TOOLBAR_DELETE);
  FLyricsToolbarEdit := FLyricsToolbar.AddCommandButton(
    '選択した歌詞行を修正', tbgEdit, LYRICS_TOOLBAR_EDIT);
  FManualClearButton := TButton.Create(Self);
  FManualClearButton.Parent := LineToolbarPanel;
  FManualClearButton.SetBounds(ButtonExtent * 3 + MulDiv(8, CurrentPPI, 96),
    0, MulDiv(88, CurrentPPI, 96), ButtonExtent);
  FManualClearButton.Caption := '同期解除';
  FManualClearButton.Hint := 'この行の同期設定を解除して前の行に追従';
  FManualClearButton.ShowHint := True;
  FManualClearButton.OnClick := ResetLineSyncButtonClick;
  ApplySyncLyricsDarkButton(FManualClearButton);
  FManualClearButton.Visible := False;
end;

procedure TFormLyricsSyncEditor.CreateTopToolbar;
var
  ButtonExtent: Integer;
begin
  ButtonExtent := MulDiv(28, CurrentPPI, 96);
  FTopToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FTopToolbar.Parent := BottomPanel;
  FTopToolbar.SetBounds(MulDiv(12, CurrentPPI, 96),
    MulDiv(12, CurrentPPI, 96), ButtonExtent * 6, ButtonExtent);
  FTopToolbar.ButtonExtent := ButtonExtent;
  FTopToolbar.Color := SYNC_LYRICS_DARK_PANEL_COLOR;
  FTopToolbar.ParentBackground := False;
  FTopToolbar.OnButtonExecute := TopToolbarButtonExecute;
  FTopCloseButton := FTopToolbar.AddCommandButton(
    '閉じる', tbgClose, TOP_TOOLBAR_CLOSE);
  FTopRestoreButton := FTopToolbar.AddCommandButton(
    '編集開始前に戻す', tbgRestore, TOP_TOOLBAR_RESTORE);
  FTopNextButton := FTopToolbar.AddCommandButton(
    '歌詞を確定して次へ', tbgNext, TOP_TOOLBAR_NEXT);
  FTopConfirmButton := FTopToolbar.AddCommandButton(
    '同期を確定', tbgConfirm, TOP_TOOLBAR_CONFIRM);
  FTopResetButton := FTopToolbar.AddCommandButton(
    '同期を初期化', tbgResetAll, TOP_TOOLBAR_RESET);
  FTopLyricsButton := FTopToolbar.AddCommandButton(
    '歌詞全体を編集', tbgLyrics, TOP_TOOLBAR_LYRICS);
end;

procedure TFormLyricsSyncEditor.EditWholeLyrics;
begin
  if LineListBox.IsEditing then
    Exit;
  SaveLoadedLine;
  FLoadedLineIndex := -1;
  FInputFrame.LyricsMemo.Text := FSongModel.LyricsText;
  FInputFrame.StatusLabel.Caption := '';
  FEditingWholeLyrics := True;
  ShowInitialInput;
end;

procedure TFormLyricsSyncEditor.DeleteLineButtonClick(Sender: TObject);
var
  DeleteIndex: Integer;
  NextIndex: Integer;
begin
  DeleteIndex := LineListBox.ItemIndex;
  if (DeleteIndex < 0) or (DeleteIndex >= FSongModel.LineCount) then
    Exit;
  if MessageDlg('選択した歌詞行を削除しますか？', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then
    Exit;
  SaveLoadedLine;
  if not FSongModel.TryDeleteLine(DeleteIndex) then
    Exit;
  RecalculateFrameRanges;
  FConfirmedLyrics := FSongModel.LyricsText;
  FLoadedLineIndex := -1;
  PopulateLineList;
  if FSongModel.LineCount > 0 then
  begin
    NextIndex := Min(DeleteIndex, FSongModel.LineCount - 1);
    SelectLine(NextIndex);
  end
  else
  begin
    FMusicSyncFrame.SetManualSongLines(nil, -1);
    FMusicSyncFrame.LoadLine(FMusicFileName, FMusicTrack,
      FDefaultPreDisplaySeconds, '', '');
    UpdateSelectedLineSummary;
  end;
end;

procedure TFormLyricsSyncEditor.EditSelectedLine;
begin
  if (LineListBox.ItemIndex < 0) or
    (LineListBox.ItemIndex >= FSongModel.LineCount) then
    Exit;
  SaveLoadedLine;
  LineListBox.BeginEdit(LineListBox.ItemIndex);
end;

procedure TFormLyricsSyncEditor.LineListBoxApplyEdit(Sender: TObject;
  Index: Integer; const NewText: string; var Accept: Boolean);
begin
  Accept := (Index >= 0) and (Index < FSongModel.LineCount) and
    (Trim(NewText) <> '');
  if not Accept then
    Exit;
  Accept := FSongModel.TrySetLineText(Index, NewText);
  if not Accept then
    Exit;
  FNewLineEditIndex := -1;
  RecalculateFrameRanges;
  FConfirmedLyrics := FSongModel.LyricsText;
  FLoadedLineIndex := -1;
  LineListBox.Invalidate;
  SelectLine(Index);
end;

procedure TFormLyricsSyncEditor.LineListBoxCancelEdit(Sender: TObject;
  Index: Integer);
var
  NextIndex: Integer;
begin
  if Index <> FNewLineEditIndex then
    Exit;
  FNewLineEditIndex := -1;
  if not FSongModel.TryDeleteLine(Index) then
    Exit;
  RecalculateFrameRanges;
  FConfirmedLyrics := FSongModel.LyricsText;
  FLoadedLineIndex := -1;
  PopulateLineList;
  if FSongModel.LineCount > 0 then
  begin
    NextIndex := Min(Index, FSongModel.LineCount - 1);
    SelectLine(NextIndex);
  end
  else
  begin
    FMusicSyncFrame.SetManualSongLines(nil, -1);
    FMusicSyncFrame.LoadLine(FMusicFileName, FMusicTrack,
      FDefaultPreDisplaySeconds, '', '');
    UpdateSelectedLineSummary;
  end;
end;

procedure TFormLyricsSyncEditor.LineListBoxGetEditText(Sender: TObject;
  Index: Integer; var Text: string);
begin
  if (Index < 0) or (Index >= FSongModel.LineCount) then
    Exit;
  if Index = FNewLineEditIndex then
    Text := ''
  else
    Text := FSongModel[Index].SourceText;
end;

procedure TFormLyricsSyncEditor.EnsureMusicSyncFrame;
begin
  if FMusicSyncFrame <> nil then
    Exit;
  FMusicSyncFrame := TFrameLyricsMusicSyncEditor.Create(Self);
  FMusicSyncFrame.OnSyncChanged := MusicSyncChanged;
  FMusicSyncFrame.OnLineSelected := ManualLineSelected;
  FMusicSyncFrame.Parent := PlaceholderPanel;
  FMusicSyncFrame.Align := alClient;
  FMusicSyncFrame.ApplyDarkTheme;
  FMusicSyncFrame.BringToFront;
  if FAnchorAvailable then
    FMusicSyncFrame.SetAnchor(0, FAnchorRate, FAnchorScale)
  else
    FMusicSyncFrame.SetAnchorUnavailable;
end;

procedure TFormLyricsSyncEditor.FinishButtonClick(Sender: TObject);
begin
  if SaveForClose then
    ModalResult := mrOk;
end;

procedure TFormLyricsSyncEditor.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  if FCommitComplete then
  begin
    CanClose := True;
    Exit;
  end;
  CanClose := SaveForClose;
  if CanClose then
    ModalResult := mrOk;
end;

function TFormLyricsSyncEditor.SaveForClose: Boolean;
var
  ErrorText: string;
begin
  Result := False;
  if LineListBox.IsEditing then
  begin
    LineListBox.EndEdit(True);
    if LineListBox.IsEditing then
      Exit;
  end;
  if (FInputFrame <> nil) and FInputFrame.Visible then
  begin
    if FEditingWholeLyrics then
      FSongModel.UpdateLyricsTextPreservingMatches(
        FInputFrame.LyricsMemo.Text)
    else
      FSongModel.SetLyricsText(FInputFrame.LyricsMemo.Text);
    if FSongModel.LineCount = 0 then
    begin
      MessageDlg('保存する歌詞行がありません。', mtInformation,
        [mbOK], 0);
      Exit;
    end;
    RecalculateFrameRanges;
  end;
  SaveLoadedLine;
  PersistDefaultMusicSyncData;
  if FSongModel.LineCount = 0 then
  begin
    MessageDlg('保存する歌詞行がありません。', mtInformation,
      [mbOK], 0);
    Exit;
  end;
  if not TryEncodeSongLyrics(FSongModel, FSongDataText,
    ErrorText) then
  begin
    MessageDlg('歌詞データを文字列へ変換できませんでした。'#13#10 +
      ErrorText, mtError, [mbOK], 0);
    Exit;
  end;
  FConfirmedLyrics := FSongModel.LyricsText;
  FCommitComplete := True;
  Result := True;
end;

procedure TFormLyricsSyncEditor.FormCreate(Sender: TObject);
begin
  CreateLineListBox;
  ApplySyncLyricsDarkForm(Self);
  ApplySyncLyricsDarkPanel(ContentPanel);
  ApplySyncLyricsDarkPanel(LineListPanel);
  ApplySyncLyricsDarkPanel(LineToolbarPanel);
  ApplySyncLyricsDarkPanel(FrameCommandPanel);
  ApplySyncLyricsDarkPanel(PlaceholderPanel);
  ApplySyncLyricsDarkPanel(BottomPanel);
  ApplySyncLyricsDarkListBox(LineListBox);
  ApplySyncLyricsDarkEdit(LineListBox.EditControl);
  PlaceholderLabel.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  CreateLyricsToolbar;
  CreateTopToolbar;
  FConfirmedLyrics := '';
  FCommitComplete := False;
  FEditingWholeLyrics := False;
  FCurrentObjectFrame := 0;
  FCurrentObjectFrameAvailable := False;
  FMusicFileName := '';
  FMusicTrack := -1;
  FDefaultMusicOffsetSeconds := 0;
  FDefaultHoldSeconds := 0.5;
  FDefaultPreDisplaySeconds := 0;
  FLoadedLineIndex := -1;
  FNewLineEditIndex := -1;
  FInitialSongDataText := '';
  FSongDataText := '';
  FAnchorAvailable := False;
  FSongModel := TLyricsSongModel.Create;
  FInputFrame := TFrameLyricsInitialInput.Create(Self);
  FInputFrame.Parent := ContentPanel;
  FInputFrame.ApplyDarkTheme;
  FInputFrame.Align := alClient;
  FInputFrame.ConfirmButton.Visible := False;
  FInputFrame.LoadDebugLyrics;
  FInitialInputLyrics := FInputFrame.LyricsMemo.Text;
  FInputFrame.OnLyricsConfirmed := LyricsConfirmed;
  ActiveControl := FInputFrame.LyricsMemo;
  LineListPanel.Visible := False;
  PlaceholderPanel.Visible := False;
  FTopCloseButton.Enabled := True;
  FTopRestoreButton.Enabled := True;
  FTopNextButton.Visible := True;
  FTopConfirmButton.Visible := False;
  FTopResetButton.Visible := False;
  FTopLyricsButton.Visible := False;
  FTopToolbar.Relayout;
  SyncStateLabel.Left := MulDiv(12 + 28 * 5 + 12,
    CurrentPPI, 96);
  SyncStateLabel.Visible := False;
  FLyricsToolbarAdd.Enabled := False;
  FLyricsToolbarDelete.Enabled := False;
  FLyricsToolbarEdit.Enabled := False;
end;

procedure TFormLyricsSyncEditor.NextButtonClick(Sender: TObject);
begin
  if (FInputFrame <> nil) and FInputFrame.Visible then
    FInputFrame.ConfirmButton.Click;
end;

procedure TFormLyricsSyncEditor.RestoreButtonClick(Sender: TObject);
var
  ErrorText: string;
begin
  if LineListBox.IsEditing then
    Exit;
  FLoadedLineIndex := -1;
  if FInitialSongDataText = '' then
  begin
    FSongModel.Clear;
    FSongDataText := '';
    FConfirmedLyrics := '';
    FEditingWholeLyrics := False;
    FInputFrame.LyricsMemo.Text := FInitialInputLyrics;
    ShowInitialInput;
    Exit;
  end;
  if not TryDecodeSongLyrics(FInitialSongDataText, FSongModel,
    ErrorText) then
  begin
    MessageDlg('編集開始前の歌詞データへ戻せませんでした。'#13#10 +
      ErrorText, mtError, [mbOK], 0);
    Exit;
  end;
  FSongDataText := FInitialSongDataText;
  ShowSongEditor;
end;

procedure TFormLyricsSyncEditor.ResetLineSyncButtonClick(Sender: TObject);
var
  LineData: TLyricsSongLine;
begin
  if LineListBox.IsEditing then
    Exit;
  if (FMusicSyncFrame = nil) or (FLoadedLineIndex < 0) or
    (FLoadedLineIndex >= FSongModel.LineCount) then
    Exit;
  if (Trim(FMusicFileName) <> '') and
    not IsMusicScoreFileName(FMusicFileName) then
  begin
    if not FSongModel.TryClearManualSync(FLoadedLineIndex) then
      Exit;
    RecalculateFrameRanges;
    LineData := FSongModel[FLoadedLineIndex];
    FMusicSyncFrame.LoadLine(FMusicFileName, FMusicTrack,
      FDefaultPreDisplaySeconds, LineData.SourceText, LineData.SyncText);
    UpdateMusicSyncReferences;
    LineListBox.Invalidate;
    UpdateSelectedLineSummary;
  end
  else
    FMusicSyncFrame.ResetSync;
end;

procedure TFormLyricsSyncEditor.FormDestroy(Sender: TObject);
begin
  FSongModel.Free;
end;

procedure TFormLyricsSyncEditor.LineListBoxClick(Sender: TObject);
begin
  if LineListBox.IsEditing then
    Exit;
  LoadSelectedLine;
end;

procedure TFormLyricsSyncEditor.LineListBoxDblClick(Sender: TObject);
begin
  if LineListBox.IsEditing then
    Exit;
  SaveLoadedLine;
  if not FSongModel.TrySetStartLine(LineListBox.ItemIndex) then
    Exit;
  LineListBox.Invalidate;
  UpdateSelectedLineSummary;
end;

procedure TFormLyricsSyncEditor.LineListBoxDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  IsManual: Boolean;
  LineData: TLyricsSongLine;
  LineText: string;
  StateText: string;
begin
  if odSelected in State then
  begin
    LineListBox.Canvas.Brush.Color := clHighlight;
    LineListBox.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    LineListBox.Canvas.Brush.Color := SYNC_LYRICS_DARK_CONTROL_COLOR;
    LineListBox.Canvas.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  end;
  LineListBox.Canvas.FillRect(Rect);
  if (Index < 0) or (Index >= FSongModel.LineCount) then
    Exit;

  LineData := FSongModel[Index];
  if LineData.LineID = FSongModel.StartLineID then
    LineText := '[先頭] '
  else
    LineText := '       ';
  IsManual := (Trim(FMusicFileName) <> '') and
    not IsMusicScoreFileName(FMusicFileName);
  case LineData.SyncState of
    lssUnset:
      if IsManual then
        StateText := '自'
      else
        StateText := ' ';
    lssProvisional: StateText := '~';
    lssConfirmed: StateText := 'C';
  else
    StateText := '!';
  end;
  if IsManual then
    LineText := LineText + Format('%.2d   L%d [%s]   %s',
      [Index + 1, LineData.DisplayLane, StateText, LineData.PlainText])
  else
    LineText := LineText + Format('%.2d   L%d N%d   [%s]   %s',
      [Index + 1, LineData.DisplayLane, LineData.StartNoteIndex + 1,
      StateText, LineData.PlainText]);
  LineListBox.Canvas.TextRect(Rect, Rect.Left + 8, Rect.Top + 6, LineText);
end;

procedure TFormLyricsSyncEditor.LineListBoxKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  DisplayLane: Integer;
  SelectedIndex: Integer;
begin
  if LineListBox.IsEditing then
    Exit;
  if Key = VK_F2 then
  begin
    EditSelectedLine;
    Key := 0;
    Exit;
  end;
  DisplayLane := 0;
  if (Key >= Ord('1')) and (Key <= Ord('3')) then
    DisplayLane := Key - Ord('0')
  else if (Key >= VK_NUMPAD1) and (Key <= VK_NUMPAD3) then
    DisplayLane := Key - VK_NUMPAD0;
  if DisplayLane = 0 then
    Exit;

  SelectedIndex := LineListBox.ItemIndex;
  if not FSongModel.TrySetDisplayLane(SelectedIndex, DisplayLane) then
    Exit;
  LineListBox.Invalidate;
  UpdateSelectedLineSummary;
  if SelectedIndex + 1 < FSongModel.LineCount then
    SelectLine(SelectedIndex + 1);
  Key := 0;
end;

procedure TFormLyricsSyncEditor.LyricsConfirmed(Sender: TObject;
  const LyricsText: string);
begin
  if FEditingWholeLyrics then
    FSongModel.UpdateLyricsTextPreservingMatches(LyricsText)
  else
    FSongModel.SetLyricsText(LyricsText);
  FEditingWholeLyrics := False;
  AnalyzeMidiLyricAssignment(FMusicFileName, FMusicTrack, FSongModel);
  AutoAssignMidiLyrics(FMusicFileName, FMusicTrack,
    FDefaultPreDisplaySeconds, FSongModel);
  ShowSongEditor;
end;

procedure TFormLyricsSyncEditor.LyricsToolbarButtonExecute(Sender: TObject;
  Button: TSyncLyricsToolbarButton);
begin
  if LineListBox.IsEditing then
    Exit;
  case Button.Tag of
    LYRICS_TOOLBAR_ADD:
      AddLineButtonClick(Button);
    LYRICS_TOOLBAR_DELETE:
      DeleteLineButtonClick(Button);
    LYRICS_TOOLBAR_EDIT:
      EditSelectedLine;
  end;
end;

procedure TFormLyricsSyncEditor.TopToolbarButtonExecute(Sender: TObject;
  Button: TSyncLyricsToolbarButton);
begin
  case Button.Tag of
    TOP_TOOLBAR_CLOSE:
      FinishButtonClick(Button);
    TOP_TOOLBAR_RESTORE:
      RestoreButtonClick(Button);
    TOP_TOOLBAR_NEXT:
      NextButtonClick(Button);
    TOP_TOOLBAR_CONFIRM:
      ConfirmSyncButtonClick(Button);
    TOP_TOOLBAR_RESET:
      ResetLineSyncButtonClick(Button);
    TOP_TOOLBAR_LYRICS:
      EditWholeLyrics;
  end;
end;

procedure TFormLyricsSyncEditor.ShowSongEditor;
begin
  FEditingWholeLyrics := False;
  FConfirmedLyrics := FSongModel.LyricsText;
  RecalculateFrameRanges;
  FInputFrame.Visible := False;
  PopulateLineList;
  EnsureMusicSyncFrame;
  PlaceholderLabel.Visible := False;
  LineListPanel.Visible := True;
  PlaceholderPanel.Visible := True;
  FTopCloseButton.Enabled := True;
  FTopRestoreButton.Enabled := True;
  FTopNextButton.Visible := False;
  FTopConfirmButton.Visible := True;
  FTopResetButton.Visible := True;
  FTopLyricsButton.Visible := True;
  FTopToolbar.Relayout;
  SyncStateLabel.Visible := True;
  FLyricsToolbarAdd.Enabled := True;
  FLyricsToolbarDelete.Enabled := FSongModel.LineCount > 0;
  FLyricsToolbarEdit.Enabled := FSongModel.LineCount > 0;
  if FSongModel.LineCount > 0 then
    SelectLine(0)
  else
    FTopCloseButton.SetFocus;
end;

procedure TFormLyricsSyncEditor.ShowInitialInput;
begin
  FInputFrame.Visible := True;
  FInputFrame.BringToFront;
  FInputFrame.RefreshInputLayout;
  LineListPanel.Visible := False;
  PlaceholderPanel.Visible := False;
  FTopNextButton.Visible := True;
  FTopConfirmButton.Visible := False;
  FTopResetButton.Visible := False;
  FTopLyricsButton.Visible := False;
  FTopToolbar.Relayout;
  SyncStateLabel.Visible := False;
  FLyricsToolbarAdd.Enabled := False;
  FLyricsToolbarDelete.Enabled := False;
  FLyricsToolbarEdit.Enabled := False;
  if FInputFrame.LyricsMemo.CanFocus then
    FInputFrame.LyricsMemo.SetFocus;
end;

function TFormLyricsSyncEditor.SongDataText: string;
begin
  Result := FSongDataText;
end;

function TFormLyricsSyncEditor.TryLoadSongData(const DataText: string;
  out ErrorText: string): Boolean;
begin
  Result := TryDecodeSongLyrics(DataText, FSongModel, ErrorText);
  if not Result then
    Exit;
  FInitialSongDataText := DataText;
  FSongDataText := DataText;
  AnalyzeMidiLyricAssignment(FMusicFileName, FMusicTrack, FSongModel);
  AutoAssignMidiLyrics(FMusicFileName, FMusicTrack,
    FDefaultPreDisplaySeconds, FSongModel);
  ShowSongEditor;
end;

procedure TFormLyricsSyncEditor.LoadSelectedLine;
var
  LineData: TLyricsSongLine;
  SelectedIndex: Integer;
begin
  SelectedIndex := LineListBox.ItemIndex;
  if SelectedIndex = FLoadedLineIndex then
  begin
    UpdateSelectedLineSummary;
    Exit;
  end;
  SaveLoadedLine;
  if (SelectedIndex < 0) or (SelectedIndex >= FSongModel.LineCount) then
  begin
    FLoadedLineIndex := -1;
    if FMusicSyncFrame <> nil then
    begin
      FMusicSyncFrame.SetReferenceLyrics('', '', 0, '', '', 0);
      FMusicSyncFrame.SetManualSongLines(nil, -1);
    end;
    UpdateSelectedLineSummary;
    Exit;
  end;
  EnsureMusicSyncFrame;
  LineData := FSongModel[SelectedIndex];
  FLoadedLineIndex := SelectedIndex;
  if FAnchorAvailable then
    FMusicSyncFrame.SetAnchor(0, FAnchorRate, FAnchorScale);
  FMusicSyncFrame.SetSequencePreDisplaySeconds(
    FDefaultPreDisplaySeconds);
  FMusicSyncFrame.SetMusicOffsetSeconds(
    FDefaultMusicOffsetSeconds);
  FMusicSyncFrame.SetHoldSeconds(FDefaultHoldSeconds);
  FMusicSyncFrame.SetStartNoteIndex(LineData.StartNoteIndex);
  FMusicSyncFrame.LoadLine(FMusicFileName, FMusicTrack,
    FDefaultPreDisplaySeconds, LineData.SourceText, LineData.SyncText);
  UpdateMusicSyncReferences;
  UpdateSelectedLineSummary;
end;

procedure TFormLyricsSyncEditor.MusicSyncChanged(Sender: TObject);
begin
  if (FMusicSyncFrame = nil) or (FLoadedLineIndex < 0) or
    (FLoadedLineIndex >= FSongModel.LineCount) then
    Exit;
  if not FMusicSyncFrame.HasChanges then
    Exit;
  FSongModel.TrySetSync(FLoadedLineIndex,
    FMusicSyncFrame.PreDisplaySeconds, FMusicSyncFrame.SyncText);
  RecalculateFrameRanges;
  FMusicSyncFrame.AcceptChanges;
  UpdateMusicSyncReferences;
  LineListBox.Invalidate;
  UpdateSyncStateControls;
  UpdateFrameControls;
end;

procedure TFormLyricsSyncEditor.PersistDefaultMusicSyncData;
var
  DefaultSyncText: string;
  I: Integer;
  LineData: TLyricsSongLine;
  SyncAdded: Boolean;
begin
  if (Trim(FMusicFileName) <> '') and
    not IsMusicScoreFileName(FMusicFileName) then
    Exit;
  DefaultSyncText := SerializeMusicSyncText([]);
  SyncAdded := False;
  for I := 0 to FSongModel.LineCount - 1 do
  begin
    LineData := FSongModel[I];
    if LineData.SyncText <> '' then
      Continue;
    if FSongModel.TrySetSync(I, LineData.PreDisplaySeconds,
      DefaultSyncText) then
      SyncAdded := True;
  end;
  if SyncAdded then
  begin
    RecalculateFrameRanges;
    UpdateMusicSyncReferences;
    LineListBox.Invalidate;
    UpdateSyncStateControls;
  end;
end;

procedure TFormLyricsSyncEditor.PopulateLineList;
var
  I: Integer;
begin
  LineListBox.Items.BeginUpdate;
  try
    LineListBox.Items.Clear;
    for I := 0 to FSongModel.LineCount - 1 do
      LineListBox.Items.Add('');
  finally
    LineListBox.Items.EndUpdate;
  end;
end;

procedure TFormLyricsSyncEditor.RecalculateFrameRanges;
begin
  if (Trim(FMusicFileName) <> '') and
    not IsMusicScoreFileName(FMusicFileName) then
    FSongModel.RecalculateManualDefaults(FManualAudioDurationSeconds);
  if not FAnchorAvailable then
    Exit;
  if (Trim(FMusicFileName) = '') or
    IsMusicScoreFileName(FMusicFileName) then
    FSongModel.RecalculateMusicFrameRanges(FMusicFileName, FMusicTrack,
      0, FDefaultMusicOffsetSeconds,
      FDefaultPreDisplaySeconds, FDefaultHoldSeconds,
      FAnchorRate, FAnchorScale)
  else
    FSongModel.RecalculateManualFrameRanges(
      FDefaultMusicOffsetSeconds, FDefaultPreDisplaySeconds,
      FDefaultHoldSeconds, FAnchorRate, FAnchorScale);
end;

procedure TFormLyricsSyncEditor.SelectLine(Index: Integer);
begin
  if (Index < 0) or (Index >= LineListBox.Items.Count) then
    Exit;
  LineListBox.ItemIndex := Index;
  LoadSelectedLine;
  if Visible and LineListBox.CanFocus then
    LineListBox.SetFocus;
end;

procedure TFormLyricsSyncEditor.SaveLoadedLine;
begin
  if (FMusicSyncFrame = nil) or (FLoadedLineIndex < 0) then
    Exit;
  if not FMusicSyncFrame.HasChanges then
    Exit;
  FSongModel.TrySetSync(FLoadedLineIndex,
    FMusicSyncFrame.PreDisplaySeconds, FMusicSyncFrame.SyncText);
  RecalculateFrameRanges;
  FMusicSyncFrame.AcceptChanges;
  UpdateMusicSyncReferences;
  LineListBox.Invalidate;
  UpdateSyncStateControls;
end;

procedure TFormLyricsSyncEditor.SetAnchor(Frame, Rate, Scale: Integer);
begin
  FAnchorAvailable := (Rate > 0) and (Scale > 0);
  FAnchorFrame := Frame;
  FAnchorRate := Rate;
  FAnchorScale := Scale;
end;

procedure TFormLyricsSyncEditor.SetAnchorUnavailable;
begin
  FAnchorAvailable := False;
  FCurrentObjectFrameAvailable := False;
  UpdateFrameControls;
end;

procedure TFormLyricsSyncEditor.SetCurrentObjectFrame(Frame: Integer);
begin
  FCurrentObjectFrame := Max(0, Frame);
  FCurrentObjectFrameAvailable := Frame >= 0;
  UpdateFrameControls;
end;

procedure TFormLyricsSyncEditor.UpdateMusicSyncReferences;
var
  I: Integer;
  LineData: TLyricsSongLine;
  Lines: TManualSyncLineSources;
  NextLineData: TLyricsSongLine;
  PreviousLineData: TLyricsSongLine;
begin
  if FMusicSyncFrame = nil then
    Exit;
  PreviousLineData := Default(TLyricsSongLine);
  NextLineData := Default(TLyricsSongLine);
  if FLoadedLineIndex > 0 then
    PreviousLineData := FSongModel[FLoadedLineIndex - 1];
  if (FLoadedLineIndex >= 0) and
    (FLoadedLineIndex + 1 < FSongModel.LineCount) then
    NextLineData := FSongModel[FLoadedLineIndex + 1];
  FMusicSyncFrame.SetReferenceLyrics(PreviousLineData.SourceText,
    PreviousLineData.SyncText, PreviousLineData.StartNoteIndex,
    NextLineData.SourceText, NextLineData.SyncText,
    NextLineData.StartNoteIndex);
  if (Trim(FMusicFileName) <> '') and
    not IsMusicScoreFileName(FMusicFileName) then
  begin
    SetLength(Lines, FSongModel.LineCount);
    for I := 0 to FSongModel.LineCount - 1 do
    begin
      LineData := FSongModel[I];
      Lines[I].LyricsText := LineData.SourceText;
      Lines[I].SyncText := LineData.SyncText;
    end;
    FMusicSyncFrame.SetManualSongLines(Lines, FLoadedLineIndex);
  end;
end;

procedure TFormLyricsSyncEditor.ManualLineSelected(
  Sender: TObject; LineIndex: Integer);
begin
  SelectLine(LineIndex);
end;

procedure TFormLyricsSyncEditor.UpdateSelectedLineSummary;
var
  SelectedIndex: Integer;
begin
  SelectedIndex := LineListBox.ItemIndex;
  if (SelectedIndex < 0) or (SelectedIndex >= FSongModel.LineCount) then
  begin
    FLyricsToolbarDelete.Enabled := False;
    FLyricsToolbarEdit.Enabled := False;
    UpdateSyncStateControls;
    UpdateFrameControls;
    Exit;
  end;
  FLyricsToolbarDelete.Enabled := True;
  FLyricsToolbarEdit.Enabled := True;
  UpdateSyncStateControls;
  UpdateFrameControls;
end;

procedure TFormLyricsSyncEditor.UpdateFrameControls;
var
  EndText: string;
  LineData: TLyricsSongLine;
  StartText: string;
begin
  if not FCurrentObjectFrameAvailable then
  begin
    CurrentFrameLabel.Caption := '現在位置: 取得不可';
    Exit;
  end;
  if (FLoadedLineIndex < 0) or
    (FLoadedLineIndex >= FSongModel.LineCount) then
  begin
    CurrentFrameLabel.Caption := Format('現在: %d',
      [FCurrentObjectFrame]);
    Exit;
  end;
  LineData := FSongModel[FLoadedLineIndex];
  if LineData.DisplayStartFrame < 0 then
    StartText := '-'
  else
    StartText := IntToStr(LineData.DisplayStartFrame);
  if LineData.DisplayEndFrame < 0 then
    EndText := '-'
  else
    EndText := IntToStr(LineData.DisplayEndFrame);
  CurrentFrameLabel.Caption := Format('現在:%d  範囲:%s-%s',
    [FCurrentObjectFrame, StartText, EndText]);
end;

procedure TFormLyricsSyncEditor.UpdateSyncStateControls;
var
  LineData: TLyricsSongLine;
begin
  FManualClearButton.Visible := (Trim(FMusicFileName) <> '') and
    not IsMusicScoreFileName(FMusicFileName) and
    (FLoadedLineIndex >= 0);
  FTopConfirmButton.Enabled := (FLoadedLineIndex >= 0) and
    (FLoadedLineIndex < FSongModel.LineCount);
  FTopResetButton.Enabled := FTopConfirmButton.Enabled;
  FTopConfirmButton.CheckState := tbcsUnchecked;
  if not FTopConfirmButton.Enabled then
  begin
    SyncStateLabel.Caption := '同期: -';
    FTopConfirmButton.Hint := '同期を確定';
    Exit;
  end;

  LineData := FSongModel[FLoadedLineIndex];
  FManualClearButton.Enabled := LineData.SyncState <> lssUnset;
  if FManualClearButton.Visible then
    FTopResetButton.Hint := '同期解除'
  else
    FTopResetButton.Hint := '同期を初期化';
  case LineData.SyncState of
    lssUnset:
      begin
        if FManualClearButton.Visible then
          SyncStateLabel.Caption := '同期: 自動'
        else
          SyncStateLabel.Caption := '同期: 未設定';
        FTopConfirmButton.Hint := '同期を確定';
      end;
    lssProvisional:
      begin
        SyncStateLabel.Caption := '同期: 仮設定';
        FTopConfirmButton.Hint := '同期を確定';
      end;
    lssConfirmed:
      begin
        SyncStateLabel.Caption := '同期: 確定';
        FTopConfirmButton.Hint := '確定を解除';
        FTopConfirmButton.CheckState := tbcsChecked;
      end;
    lssInconsistent:
      begin
        SyncStateLabel.Caption := '同期: 不整合';
        FTopConfirmButton.Hint := '同期を再確定';
      end;
  end;
end;

end.
