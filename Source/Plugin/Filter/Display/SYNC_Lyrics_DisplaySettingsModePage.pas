unit SYNC_Lyrics_DisplaySettingsModePage;

// Defines the lifecycle shared by editable placement-mode pages in one host form.

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  SYNC_Lyrics_ToolbarButtons;

const
  DISPLAY_SETTINGS_MODE_LINE = 0; // Song-wide line placement.
  DISPLAY_SETTINGS_MODE_FREE = 1; // Per-display-unit free placement.

type
  TFrameDisplaySettingsModePage = class(TFrame)
  public
    constructor Create(AOwner: TComponent); override;
    // Supplies the icon, stable ID, and label used by the host mode toolbar.
    function ModeGlyph: TSyncLyricsToolbarGlyph; virtual; abstract;
    function ModeID: Integer; virtual; abstract;
    function ModeName: string; virtual; abstract;
    // Captures the page's editable state for the form-level restore action.
    procedure CaptureInitialState; virtual;
    // Saves the outgoing candidate and loads Index within this mode.
    procedure CandidateChanged(Index: Integer); virtual;
    // Receives host visibility transitions without discarding candidate state.
    procedure PageActivated; virtual;
    procedure PageDeactivated; virtual;
    // Restores the state saved by CaptureInitialState.
    procedure RestoreInitialState; virtual;
  end;

implementation

uses
  SYNC_Lyrics_DarkTheme;

constructor TFrameDisplaySettingsModePage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  if AOwner is TWinControl then
    Parent := TWinControl(AOwner);
  Align := alClient;
  ApplySyncLyricsDarkFrame(Self);
end;

procedure TFrameDisplaySettingsModePage.CandidateChanged(Index: Integer);
begin
end;

procedure TFrameDisplaySettingsModePage.CaptureInitialState;
begin
end;

procedure TFrameDisplaySettingsModePage.PageActivated;
begin
end;

procedure TFrameDisplaySettingsModePage.PageDeactivated;
begin
end;

procedure TFrameDisplaySettingsModePage.RestoreInitialState;
begin
end;

end.
