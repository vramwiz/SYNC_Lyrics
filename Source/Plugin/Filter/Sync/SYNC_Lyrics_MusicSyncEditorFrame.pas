unit SYNC_Lyrics_MusicSyncEditorFrame;

// Embeds the existing music-score synchronization editor for reuse in whole-song editing.

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  SYNC_Lyrics_ManualSyncSettingsForm,
  SYNC_Lyrics_MusicSyncSettingsForm;

type
  TFrameLyricsMusicSyncEditor = class(TFrame)
  private
    FEditorForm: TFormLyricsMusicSyncSettings;
    FManualEditorForm: TFormLyricsManualSyncSettings;
    FLoadedPreDisplaySeconds: Double;
    FLoadedSyncText: string;
    FOnSyncChanged: TNotifyEvent;
    FOnLineSelected: TManualSyncLineSelectedEvent;
    FPreDisplaySeconds: Double;
    FUseManualEditor: Boolean;
    procedure EditorSyncChanged(Sender: TObject);
    procedure ManualLineSelected(Sender: TObject; LineIndex: Integer);
    function CurrentSyncText: string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyDarkTheme;
    // Supplies the current Filter position used as the piano-roll time origin.
    procedure SetAnchor(Frame, Rate, Scale: Integer);
    procedure SetAnchorUnavailable;
    procedure SetMusicOffsetSeconds(Value: Double);
    procedure SetSequencePreDisplaySeconds(Value: Double);
    // Supplies the fixed post-synchronization display duration.
    procedure SetHoldSeconds(Value: Double);
    // Supplies neighboring song lines for read-only piano-roll context.
    procedure SetReferenceLyrics(const PreviousLyrics,
      PreviousSyncText: string; PreviousStartNoteIndex: Integer;
      const NextLyrics, NextSyncText: string;
      NextStartNoteIndex: Integer);
    // WAV波形へ曲全体の歌詞位置を渡す。選択行の編集中データは置き換えない。
    procedure SetManualSongLines(const Lines: TManualSyncLineSources;
      SelectedIndex: Integer);
    // Skips notes already assigned to preceding whole-song lyric lines.
    procedure SetStartNoteIndex(Value: Integer);
    // Replaces the editor contents with one song-line record.
    procedure LoadLine(const MusicFileName: string; Track: Integer;
      PreDisplaySeconds: Double; const LyricsText, SyncText: string);
    procedure ResetSync;
    procedure AcceptChanges;
    // Exposes the current row values without applying them to the Filter.
    function LyricsText: string;
    function HasChanges: Boolean;
    function PreDisplaySeconds: Double;
    function SyncText: string;
    // Fires immediately after a user operation changes synchronization.
    property OnSyncChanged: TNotifyEvent read FOnSyncChanged
      write FOnSyncChanged;
    property OnLineSelected: TManualSyncLineSelectedEvent
      read FOnLineSelected write FOnLineSelected;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  SYNC_Lyrics_AudioProbe,
  SYNC_Lyrics_SyncSourceKind;

{$R *.dfm}

constructor TFrameLyricsMusicSyncEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Name := 'FrameLyricsMusicSyncEditor';
  FEditorForm := TFormLyricsMusicSyncSettings.Create(Self);
  FEditorForm.OnSyncChanged := EditorSyncChanged;
  FEditorForm.BorderStyle := bsNone;
  FEditorForm.ApplyButton.Visible := False;
  FEditorForm.CloseButton.Visible := False;
  FEditorForm.BottomPanel.Visible := False;
  FEditorForm.LyricsEdit.ReadOnly := True;
  FEditorForm.Parent := Self;
  FEditorForm.Align := alClient;
  FEditorForm.Show;
  FManualEditorForm := TFormLyricsManualSyncSettings.Create(Self);
  FManualEditorForm.OnSyncChanged := EditorSyncChanged;
  FManualEditorForm.OnLineSelected := ManualLineSelected;
  FManualEditorForm.ConfigureEmbedded;
  FManualEditorForm.Parent := Self;
  FManualEditorForm.Align := alClient;
  FManualEditorForm.Hide;
end;

procedure TFrameLyricsMusicSyncEditor.ResetSync;
begin
  if FUseManualEditor then
    FManualEditorForm.ResetSync
  else
    FEditorForm.ResetSyncButton.Click;
end;

procedure TFrameLyricsMusicSyncEditor.ApplyDarkTheme;
begin
  FEditorForm.ApplyDarkTheme;
  FManualEditorForm.ApplyDarkTheme;
end;

procedure TFrameLyricsMusicSyncEditor.EditorSyncChanged(Sender: TObject);
begin
  if Assigned(FOnSyncChanged) then
    FOnSyncChanged(Self);
end;

procedure TFrameLyricsMusicSyncEditor.ManualLineSelected(
  Sender: TObject; LineIndex: Integer);
begin
  if Assigned(FOnLineSelected) then
    FOnLineSelected(Self, LineIndex);
end;

procedure TFrameLyricsMusicSyncEditor.AcceptChanges;
begin
  FLoadedPreDisplaySeconds := PreDisplaySeconds;
  FLoadedSyncText := CurrentSyncText;
end;

destructor TFrameLyricsMusicSyncEditor.Destroy;
begin
  FManualEditorForm.Free;
  FEditorForm.Free;
  inherited Destroy;
end;

procedure TFrameLyricsMusicSyncEditor.LoadLine(const MusicFileName: string;
  Track: Integer; PreDisplaySeconds: Double; const LyricsText,
  SyncText: string);
var
  AudioInfo: TSyncAudioFileInfo;
  ErrorMessage: string;
begin
  FPreDisplaySeconds := Max(0.0, PreDisplaySeconds);
  FUseManualEditor := (Trim(MusicFileName) <> '') and
    not IsMusicScoreFileName(MusicFileName);
  if FUseManualEditor then
  begin
    FEditorForm.Hide;
    FManualEditorForm.Show;
    FManualEditorForm.BringToFront;
    if not TryProbeSyncAudioFile(MusicFileName, AudioInfo,
      ErrorMessage) then
    begin
      AudioInfo := Default(TSyncAudioFileInfo);
      AudioInfo.DurationSeconds := 0.001;
      AudioInfo.StreamIndex := -1;
    end;
    FManualEditorForm.LoadSettings(MusicFileName, AudioInfo,
      LyricsText, SyncText);
  end
  else
  begin
    FManualEditorForm.Hide;
    FEditorForm.Show;
    FEditorForm.BringToFront;
    FEditorForm.LoadSettings(MusicFileName, Track, PreDisplaySeconds,
      LyricsText, SyncText);
  end;
  FLoadedPreDisplaySeconds := FPreDisplaySeconds;
  FLoadedSyncText := SyncText;
end;

function TFrameLyricsMusicSyncEditor.HasChanges: Boolean;
begin
  Result := (Abs(PreDisplaySeconds -
    FLoadedPreDisplaySeconds) >= 0.005) or
    (CurrentSyncText <> FLoadedSyncText);
end;

function TFrameLyricsMusicSyncEditor.LyricsText: string;
begin
  if FUseManualEditor then
    Result := FManualEditorForm.LyricsText
  else
    Result := FEditorForm.LyricsText;
end;

function TFrameLyricsMusicSyncEditor.PreDisplaySeconds: Double;
begin
  if FUseManualEditor then
    Result := FPreDisplaySeconds
  else
    Result := FEditorForm.PreDisplaySeconds;
end;

procedure TFrameLyricsMusicSyncEditor.SetAnchor(Frame, Rate, Scale: Integer);
begin
  FEditorForm.SetAnchor(Frame, Rate, Scale);
end;

procedure TFrameLyricsMusicSyncEditor.SetAnchorUnavailable;
begin
  FEditorForm.SetAnchorUnavailable;
end;

procedure TFrameLyricsMusicSyncEditor.SetHoldSeconds(Value: Double);
begin
  FEditorForm.SetHoldSeconds(Value);
end;

procedure TFrameLyricsMusicSyncEditor.SetMusicOffsetSeconds(Value: Double);
begin
  FEditorForm.SetMusicOffsetSeconds(Value);
end;

procedure TFrameLyricsMusicSyncEditor.SetStartNoteIndex(Value: Integer);
begin
  FEditorForm.SetStartNoteIndex(Value);
end;

procedure TFrameLyricsMusicSyncEditor.SetSequencePreDisplaySeconds(
  Value: Double);
begin
  FEditorForm.SetSequencePreDisplaySeconds(Value);
end;

procedure TFrameLyricsMusicSyncEditor.SetReferenceLyrics(
  const PreviousLyrics, PreviousSyncText: string;
  PreviousStartNoteIndex: Integer; const NextLyrics,
  NextSyncText: string; NextStartNoteIndex: Integer);
begin
  FEditorForm.SetReferenceLyrics(PreviousLyrics, PreviousSyncText,
    PreviousStartNoteIndex, NextLyrics, NextSyncText,
    NextStartNoteIndex);
end;

function TFrameLyricsMusicSyncEditor.SyncText: string;
begin
  Result := CurrentSyncText;
end;

procedure TFrameLyricsMusicSyncEditor.SetManualSongLines(
  const Lines: TManualSyncLineSources; SelectedIndex: Integer);
begin
  FManualEditorForm.SetSongLines(Lines, SelectedIndex);
end;

function TFrameLyricsMusicSyncEditor.CurrentSyncText: string;
begin
  if FUseManualEditor then
  begin
    if not FManualEditorForm.TryGetSyncText(Result) then
      Result := FLoadedSyncText;
  end
  else
    Result := FEditorForm.SyncText;
end;

end.
