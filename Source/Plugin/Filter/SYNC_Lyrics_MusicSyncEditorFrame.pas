unit SYNC_Lyrics_MusicSyncEditorFrame;

// Embeds the existing music-score synchronization editor for reuse in whole-song editing.

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  SYNC_Lyrics_MusicSyncSettingsForm;

type
  TFrameLyricsMusicSyncEditor = class(TFrame)
  private
    FEditorForm: TFormLyricsMusicSyncSettings;
    FLoadedPreDisplaySeconds: Double;
    FLoadedSyncText: string;
    FOnSyncChanged: TNotifyEvent;
    procedure EditorSyncChanged(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Supplies the current Filter position used as the piano-roll time origin.
    procedure SetAnchor(Frame, Rate, Scale: Integer);
    procedure SetAnchorUnavailable;
    procedure SetSequencePreDisplaySeconds(Value: Double);
    // Supplies the fixed post-synchronization display duration.
    procedure SetHoldSeconds(Value: Double);
    // Supplies neighboring song lines for read-only piano-roll context.
    procedure SetReferenceLyrics(const PreviousLyrics,
      PreviousSyncText: string; PreviousStartNoteIndex: Integer;
      const NextLyrics, NextSyncText: string;
      NextStartNoteIndex: Integer);
    // Skips notes already assigned to preceding whole-song lyric lines.
    procedure SetStartNoteIndex(Value: Integer);
    // Replaces the editor contents with one song-line record.
    procedure LoadLine(const MusicFileName: string; Track: Integer;
      PreDisplaySeconds: Double; const LyricsText, SyncText: string);
    procedure AcceptChanges;
    // Exposes the current row values without applying them to the Filter.
    function LyricsText: string;
    function HasChanges: Boolean;
    function PreDisplaySeconds: Double;
    function SyncText: string;
    // Fires immediately after a user operation changes synchronization.
    property OnSyncChanged: TNotifyEvent read FOnSyncChanged
      write FOnSyncChanged;
  end;

implementation

uses
  System.Math;

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
  FEditorForm.LyricsEdit.ReadOnly := True;
  FEditorForm.Parent := Self;
  FEditorForm.Align := alClient;
  FEditorForm.Show;
end;

procedure TFrameLyricsMusicSyncEditor.EditorSyncChanged(Sender: TObject);
begin
  if Assigned(FOnSyncChanged) then
    FOnSyncChanged(Self);
end;

procedure TFrameLyricsMusicSyncEditor.AcceptChanges;
begin
  FLoadedPreDisplaySeconds := FEditorForm.PreDisplaySeconds;
  FLoadedSyncText := FEditorForm.SyncText;
end;

destructor TFrameLyricsMusicSyncEditor.Destroy;
begin
  FEditorForm.Free;
  inherited Destroy;
end;

procedure TFrameLyricsMusicSyncEditor.LoadLine(const MusicFileName: string;
  Track: Integer; PreDisplaySeconds: Double; const LyricsText,
  SyncText: string);
begin
  FEditorForm.LoadSettings(MusicFileName, Track, PreDisplaySeconds,
    LyricsText, SyncText);
  AcceptChanges;
end;

function TFrameLyricsMusicSyncEditor.HasChanges: Boolean;
begin
  Result := (Abs(FEditorForm.PreDisplaySeconds -
    FLoadedPreDisplaySeconds) >= 0.005) or
    (FEditorForm.SyncText <> FLoadedSyncText);
end;

function TFrameLyricsMusicSyncEditor.LyricsText: string;
begin
  Result := FEditorForm.LyricsText;
end;

function TFrameLyricsMusicSyncEditor.PreDisplaySeconds: Double;
begin
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
  Result := FEditorForm.SyncText;
end;

end.
