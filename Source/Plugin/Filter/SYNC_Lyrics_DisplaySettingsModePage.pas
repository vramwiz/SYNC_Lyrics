unit SYNC_Lyrics_DisplaySettingsModePage;

// Defines a display-only page contract for placement modes hosted by one form.

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  SYNC_Lyrics_ToolbarButtons;

const
  DISPLAY_SETTINGS_MODE_LINE = 0;
  DISPLAY_SETTINGS_MODE_FREE = 1;

type
  TFrameDisplaySettingsModePage = class(TFrame)
  public
    constructor Create(AOwner: TComponent); override;
    function ModeGlyph: TSyncLyricsToolbarGlyph; virtual; abstract;
    function ModeID: Integer; virtual; abstract;
    function ModeName: string; virtual; abstract;
    procedure CaptureInitialState; virtual;
    procedure CandidateChanged(Index: Integer); virtual;
    procedure PageActivated; virtual;
    procedure PageDeactivated; virtual;
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
