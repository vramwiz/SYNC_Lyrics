unit SYNC_Lyrics_InitialLyricsFrame;

// Provides the first-time whole-song lyrics input page for the sync editor.

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TLyricsConfirmedEvent = procedure(Sender: TObject;
    const LyricsText: string) of object;

  TFrameLyricsInitialInput = class(TFrame)
    ConfirmButton: TButton;
    HeaderLabel: TLabel;
    InstructionsLabel: TLabel;
    LyricsMemo: TMemo;
    StatusLabel: TLabel;
    procedure ConfirmButtonClick(Sender: TObject);
  private
    FOnLyricsConfirmed: TLyricsConfirmedEvent;
  public
    procedure LoadDebugLyrics;
    function LyricsText: string;
    property OnLyricsConfirmed: TLyricsConfirmedEvent
      read FOnLyricsConfirmed write FOnLyricsConfirmed;
  end;

implementation

uses
  System.SysUtils;

{$R *.dfm}

procedure TFrameLyricsInitialInput.ConfirmButtonClick(Sender: TObject);
var
  EnteredLyrics: string;
begin
  EnteredLyrics := LyricsMemo.Text;
  if Trim(EnteredLyrics) = '' then
  begin
    StatusLabel.Caption := 'Enter at least one lyric line.';
    LyricsMemo.SetFocus;
    Exit;
  end;

  StatusLabel.Caption := '';
  if Assigned(FOnLyricsConfirmed) then
    FOnLyricsConfirmed(Self, EnteredLyrics);
end;

procedure TFrameLyricsInitialInput.LoadDebugLyrics;
begin
  LyricsMemo.Lines.BeginUpdate;
  try
    LyricsMemo.Lines.Clear;
    LyricsMemo.Lines.Add(
      '['#26143#31354']('#12411#12375#12382#12425')'#12434#35211#19978#12370#12390);
    LyricsMemo.Lines.Add(
      '['#21531']('#12365#12415')'#12398#22768#12434#25506#12375#12390#12427);
    LyricsMemo.Lines.Add(
      '['#26410#26469']('#12415#12425#12356')'#12408#32154#12367#12371#12398#36947#12434);
    LyricsMemo.Lines.Add(
      '['#20809']('#12402#12363#12426')'#12398#20013#12391#27468#12362#12358);
    LyricsMemo.Lines.Add(
      #12414#12383'['#26126#26085']('#12354#12375#12383')'#12371#12371#12391#20250#12362#12358);
  finally
    LyricsMemo.Lines.EndUpdate;
  end;
end;

function TFrameLyricsInitialInput.LyricsText: string;
begin
  Result := LyricsMemo.Text;
end;

end.
