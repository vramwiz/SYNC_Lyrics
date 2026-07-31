unit SYNC_Lyrics_SyncEditorForm;

// Hosts the staged whole-song lyrics input and future per-line sync editor pages.

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls,
  SYNC_Lyrics_InitialLyricsFrame,
  SYNC_Lyrics_MusicSyncEditorFrame,
  SYNC_Lyrics_SongLyricsData,
  SYNC_Lyrics_SongLyricsModel;

type
  TFormLyricsSyncEditor = class(TForm)
    AddLineButton: TButton;
    BottomPanel: TPanel;
    CancelButton: TButton;
    ConfirmSyncButton: TButton;
    ContentPanel: TPanel;
    CurrentFrameLabel: TLabel;
    DeleteLineButton: TButton;
    EndFrameButton: TButton;
    FinishButton: TButton;
    FrameCommandPanel: TPanel;
    LineHintLabel: TLabel;
    LineListBox: TListBox;
    LineListHeaderLabel: TLabel;
    LineListPanel: TPanel;
    PlaceholderLabel: TLabel;
    PlaceholderPanel: TPanel;
    SummaryLabel: TLabel;
    StartFrameButton: TButton;
    SyncStateLabel: TLabel;
    procedure AddLineButtonClick(Sender: TObject);
    procedure ConfirmSyncButtonClick(Sender: TObject);
    procedure DeleteLineButtonClick(Sender: TObject);
    procedure EndFrameButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FinishButtonClick(Sender: TObject);
    procedure LineListBoxClick(Sender: TObject);
    procedure LineListBoxDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure LineListBoxKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure StartFrameButtonClick(Sender: TObject);
  private
    FConfirmedLyrics: string;
    FCurrentObjectFrame: Integer;
    FCurrentObjectFrameAvailable: Boolean;
    FInputFrame: TFrameLyricsInitialInput;
    FMusicFileName: string;
    FMusicSyncFrame: TFrameLyricsMusicSyncEditor;
    FMusicTrack: Integer;
    FAnchorAvailable: Boolean;
    FAnchorFrame: Integer;
    FAnchorRate: Integer;
    FAnchorScale: Integer;
    FDefaultPreDisplaySeconds: Double;
    FLoadedLineIndex: Integer;
    FSongDataText: string;
    FSongModel: TLyricsSongModel;
    procedure EnsureMusicSyncFrame;
    procedure EditSelectedLine;
    procedure LoadSelectedLine;
    procedure LyricsConfirmed(Sender: TObject; const LyricsText: string);
    procedure MusicSyncChanged(Sender: TObject);
    procedure PopulateLineList;
    procedure RecalculateFrameRanges;
    procedure SaveLoadedLine;
    procedure SelectLine(Index: Integer);
    procedure ShowSongEditor;
    procedure UpdateFrameControls;
    procedure UpdateMusicSyncReferences;
    procedure UpdateSyncStateControls;
    procedure UpdateSelectedLineSummary;
  public
    // Supplies the shared music source used while individual lines are selected.
    procedure ConfigureMusicSource(const MusicFileName: string; Track: Integer;
      PreDisplaySeconds: Double);
    // Supplies the current Filter position used as the synchronization origin.
    procedure SetAnchor(Frame, Rate, Scale: Integer);
    procedure SetAnchorUnavailable;
    procedure SetCurrentObjectFrame(Frame: Integer);
    function ConfirmedLyrics: string;
    function SongDataText: string;
    function TryLoadSongData(const DataText: string;
      out ErrorText: string): Boolean;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  Winapi.Windows,
  Vcl.Dialogs;

{$R *.dfm}

function TFormLyricsSyncEditor.ConfirmedLyrics: string;
begin
  Result := FConfirmedLyrics;
end;

procedure TFormLyricsSyncEditor.AddLineButtonClick(Sender: TObject);
var
  InsertIndex: Integer;
  LineText: string;
begin
  SaveLoadedLine;
  InsertIndex := LineListBox.ItemIndex + 1;
  if InsertIndex <= 0 then
    InsertIndex := FSongModel.LineCount;
  LineText := '';
  if not InputQuery('歌詞行を追加', '歌詞構文:', LineText) then
    Exit;
  if not FSongModel.TryInsertLine(InsertIndex, LineText) then
    Exit;
  RecalculateFrameRanges;
  FConfirmedLyrics := FSongModel.LyricsText;
  FLoadedLineIndex := -1;
  PopulateLineList;
  SelectLine(InsertIndex);
end;

procedure TFormLyricsSyncEditor.ConfirmSyncButtonClick(Sender: TObject);
var
  LineData: TLyricsSongLine;
begin
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
  const MusicFileName: string; Track: Integer; PreDisplaySeconds: Double);
begin
  FMusicFileName := MusicFileName;
  FMusicTrack := Track;
  FDefaultPreDisplaySeconds := PreDisplaySeconds;
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
    FMusicSyncFrame.LoadLine(FMusicFileName, FMusicTrack,
      FDefaultPreDisplaySeconds, '', '');
    UpdateSelectedLineSummary;
  end;
end;

procedure TFormLyricsSyncEditor.EndFrameButtonClick(Sender: TObject);
begin
  if not FCurrentObjectFrameAvailable or (FLoadedLineIndex < 0) then
    Exit;
  SaveLoadedLine;
  if not FSongModel.TrySetEndFrames(FLoadedLineIndex,
    FCurrentObjectFrame, FCurrentObjectFrame) then
  begin
    MessageDlg('終了位置は開始位置以降にしてください。',
      mtInformation, [mbOK], 0);
    Exit;
  end;
  LineListBox.Invalidate;
  UpdateFrameControls;
end;

procedure TFormLyricsSyncEditor.EditSelectedLine;
var
  LineData: TLyricsSongLine;
  LineText: string;
  SelectedIndex: Integer;
begin
  SelectedIndex := LineListBox.ItemIndex;
  if (SelectedIndex < 0) or (SelectedIndex >= FSongModel.LineCount) then
    Exit;
  SaveLoadedLine;
  LineData := FSongModel[SelectedIndex];
  LineText := LineData.SourceText;
  if not InputQuery('歌詞行を編集', '歌詞構文:', LineText) then
    Exit;
  if not FSongModel.TrySetLineText(SelectedIndex, LineText) then
    Exit;
  RecalculateFrameRanges;
  FConfirmedLyrics := FSongModel.LyricsText;
  FLoadedLineIndex := -1;
  LineListBox.Invalidate;
  SelectLine(SelectedIndex);
end;

procedure TFormLyricsSyncEditor.EnsureMusicSyncFrame;
begin
  if FMusicSyncFrame <> nil then
    Exit;
  FMusicSyncFrame := TFrameLyricsMusicSyncEditor.Create(Self);
  FMusicSyncFrame.OnSyncChanged := MusicSyncChanged;
  FMusicSyncFrame.Parent := PlaceholderPanel;
  FMusicSyncFrame.Align := alClient;
  FMusicSyncFrame.BringToFront;
  if FAnchorAvailable then
    FMusicSyncFrame.SetAnchor(0, FAnchorRate, FAnchorScale)
  else
    FMusicSyncFrame.SetAnchorUnavailable;
end;

procedure TFormLyricsSyncEditor.FinishButtonClick(Sender: TObject);
var
  ErrorText: string;
begin
  SaveLoadedLine;
  if FSongModel.LineCount = 0 then
  begin
    MessageDlg('保存する歌詞行がありません。', mtInformation,
      [mbOK], 0);
    Exit;
  end;
  if not TryEncodeSongLyrics(FSongModel, FSongDataText,
    ErrorText) then
  begin
    MessageDlg('曲全体データを文字列へ変換できませんでした。'#13#10 +
      ErrorText, mtError, [mbOK], 0);
    Exit;
  end;
  FConfirmedLyrics := FSongModel.LyricsText;
  ModalResult := mrOk;
end;

procedure TFormLyricsSyncEditor.FormCreate(Sender: TObject);
begin
  FConfirmedLyrics := '';
  FCurrentObjectFrame := 0;
  FCurrentObjectFrameAvailable := False;
  FMusicFileName := '';
  FMusicTrack := -1;
  FDefaultPreDisplaySeconds := 0;
  FLoadedLineIndex := -1;
  FSongDataText := '';
  FAnchorAvailable := False;
  FSongModel := TLyricsSongModel.Create;
  FInputFrame := TFrameLyricsInitialInput.Create(Self);
  FInputFrame.Parent := ContentPanel;
  FInputFrame.Align := alClient;
  FInputFrame.LoadDebugLyrics;
  FInputFrame.OnLyricsConfirmed := LyricsConfirmed;
  ActiveControl := FInputFrame.LyricsMemo;
  LineListPanel.Visible := False;
  PlaceholderPanel.Visible := False;
  FinishButton.Enabled := False;
  ConfirmSyncButton.Visible := False;
  SyncStateLabel.Visible := False;
  AddLineButton.Enabled := False;
  DeleteLineButton.Enabled := False;
  StartFrameButton.Enabled := False;
  EndFrameButton.Enabled := False;
end;

procedure TFormLyricsSyncEditor.FormDestroy(Sender: TObject);
begin
  FSongModel.Free;
end;

procedure TFormLyricsSyncEditor.LineListBoxClick(Sender: TObject);
begin
  LoadSelectedLine;
end;

procedure TFormLyricsSyncEditor.LineListBoxDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  LineData: TLyricsSongLine;
  LineText: string;
begin
  LineListBox.Canvas.FillRect(Rect);
  if (Index < 0) or (Index >= FSongModel.LineCount) then
    Exit;

  LineData := FSongModel[Index];
  case LineData.SyncState of
    lssUnset:
      LineText := Format('%.2d   L%d N%d   [ ]   %s',
        [Index + 1, LineData.DisplayLane, LineData.StartNoteIndex + 1,
        LineData.PlainText]);
    lssProvisional:
      LineText := Format('%.2d   L%d N%d   [~]   %s',
        [Index + 1, LineData.DisplayLane, LineData.StartNoteIndex + 1,
        LineData.PlainText]);
    lssConfirmed:
      LineText := Format('%.2d   L%d N%d   [C]   %s',
        [Index + 1, LineData.DisplayLane, LineData.StartNoteIndex + 1,
        LineData.PlainText]);
  else
    LineText := Format('%.2d   L%d N%d   [!]   %s',
      [Index + 1, LineData.DisplayLane, LineData.StartNoteIndex + 1,
      LineData.PlainText]);
  end;
  LineListBox.Canvas.TextRect(Rect, Rect.Left + 8, Rect.Top + 6, LineText);
end;

procedure TFormLyricsSyncEditor.LineListBoxKeyDown(Sender: TObject;
  var Key: Word; Shift: TShiftState);
var
  DisplayLane: Integer;
  SelectedIndex: Integer;
begin
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
  FSongModel.SetLyricsText(LyricsText);
  ShowSongEditor;
end;

procedure TFormLyricsSyncEditor.ShowSongEditor;
begin
  FConfirmedLyrics := FSongModel.LyricsText;
  RecalculateFrameRanges;
  FInputFrame.Visible := False;
  PopulateLineList;
  EnsureMusicSyncFrame;
  PlaceholderLabel.Visible := False;
  SummaryLabel.Visible := False;
  LineListPanel.Visible := True;
  PlaceholderPanel.Visible := True;
  FinishButton.Enabled := True;
  ConfirmSyncButton.Visible := True;
  SyncStateLabel.Visible := True;
  AddLineButton.Enabled := True;
  DeleteLineButton.Enabled := FSongModel.LineCount > 0;
  if FSongModel.LineCount > 0 then
    SelectLine(0)
  else
    FinishButton.SetFocus;
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
  FSongDataText := DataText;
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
      FMusicSyncFrame.SetReferenceLyrics('', '', 0, '', '', 0);
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
  FMusicSyncFrame.SetHoldSeconds(LineData.HoldSeconds);
  FMusicSyncFrame.SetStartNoteIndex(LineData.StartNoteIndex);
  UpdateMusicSyncReferences;
  FMusicSyncFrame.LoadLine(FMusicFileName, FMusicTrack,
    IfThen(LineData.PreDisplaySeconds >= 0, LineData.PreDisplaySeconds,
      FDefaultPreDisplaySeconds), LineData.SourceText, LineData.SyncText);
  UpdateSelectedLineSummary;
end;

procedure TFormLyricsSyncEditor.MusicSyncChanged(Sender: TObject);
begin
  if (FMusicSyncFrame = nil) or (FLoadedLineIndex < 0) or
    (FLoadedLineIndex >= FSongModel.LineCount) then
    Exit;
  FSongModel.TrySetSync(FLoadedLineIndex,
    FMusicSyncFrame.PreDisplaySeconds, FMusicSyncFrame.SyncText);
  RecalculateFrameRanges;
  FMusicSyncFrame.AcceptChanges;
  UpdateMusicSyncReferences;
  LineListBox.Invalidate;
  UpdateSyncStateControls;
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
  if not FAnchorAvailable then
    Exit;
  FSongModel.RecalculateMusicFrameRanges(FMusicFileName, FMusicTrack,
    FDefaultPreDisplaySeconds, FDefaultPreDisplaySeconds,
    FAnchorRate, FAnchorScale);
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
end;

procedure TFormLyricsSyncEditor.StartFrameButtonClick(Sender: TObject);
var
  PreDisplaySeconds: Double;
  SyncStartFrame: Int64;
begin
  if not FCurrentObjectFrameAvailable or (FLoadedLineIndex < 0) or
    (FAnchorRate <= 0) or (FAnchorScale <= 0) then
    Exit;
  SaveLoadedLine;
  PreDisplaySeconds := FDefaultPreDisplaySeconds;
  if FMusicSyncFrame <> nil then
    PreDisplaySeconds := FMusicSyncFrame.PreDisplaySeconds;
  SyncStartFrame := FCurrentObjectFrame +
    Round(Max(0, PreDisplaySeconds) * FAnchorRate / FAnchorScale);
  if not FSongModel.TrySetStartFrames(FLoadedLineIndex,
    FCurrentObjectFrame, SyncStartFrame) then
    Exit;
  FLoadedLineIndex := -1;
  SelectLine(LineListBox.ItemIndex);
  LineListBox.Invalidate;
  UpdateSyncStateControls;
  UpdateFrameControls;
end;

procedure TFormLyricsSyncEditor.UpdateSelectedLineSummary;
var
  LineData: TLyricsSongLine;
  SelectedIndex: Integer;
begin
  SelectedIndex := LineListBox.ItemIndex;
  if (SelectedIndex < 0) or (SelectedIndex >= FSongModel.LineCount) then
  begin
    SummaryLabel.Caption := '-';
    DeleteLineButton.Enabled := False;
    UpdateSyncStateControls;
    UpdateFrameControls;
    Exit;
  end;
  DeleteLineButton.Enabled := True;
  LineData := FSongModel[SelectedIndex];
  SummaryLabel.Caption := Format(
    'Line %d / Lane %d / ID %d'#13#10'%s',
    [SelectedIndex + 1, LineData.DisplayLane, LineData.LineID,
     LineData.SourceText]);
  UpdateSyncStateControls;
  UpdateFrameControls;
end;

procedure TFormLyricsSyncEditor.UpdateFrameControls;
var
  EndText: string;
  LineData: TLyricsSongLine;
  StartText: string;
begin
  StartFrameButton.Enabled := FCurrentObjectFrameAvailable and
    (FLoadedLineIndex >= 0) and
    (FLoadedLineIndex < FSongModel.LineCount);
  EndFrameButton.Enabled := StartFrameButton.Enabled;
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
  ConfirmSyncButton.Enabled := (FLoadedLineIndex >= 0) and
    (FLoadedLineIndex < FSongModel.LineCount);
  if not ConfirmSyncButton.Enabled then
  begin
    SyncStateLabel.Caption := '同期: -';
    ConfirmSyncButton.Caption := '同期を確定';
    ConfirmSyncButton.Tag := -1;
    Exit;
  end;

  LineData := FSongModel[FLoadedLineIndex];
  ConfirmSyncButton.Tag := Ord(LineData.SyncState);
  case LineData.SyncState of
    lssUnset:
      begin
        SyncStateLabel.Caption := '同期: 未設定';
        ConfirmSyncButton.Caption := '同期を確定';
      end;
    lssProvisional:
      begin
        SyncStateLabel.Caption := '同期: 仮設定';
        ConfirmSyncButton.Caption := '同期を確定';
      end;
    lssConfirmed:
      begin
        SyncStateLabel.Caption := '同期: 確定';
        ConfirmSyncButton.Caption := '確定を解除';
      end;
    lssInconsistent:
      begin
        SyncStateLabel.Caption := '同期: 不整合';
        ConfirmSyncButton.Caption := '同期を再確定';
      end;
  end;
end;

end.
