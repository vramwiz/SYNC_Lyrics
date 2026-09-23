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
    procedure UpdateInputLayout;
  protected
    procedure Resize; override;
  public
    procedure ApplyDarkTheme;
    procedure LoadDebugLyrics;
    procedure RefreshInputLayout;
    function LyricsText: string;
    property OnLyricsConfirmed: TLyricsConfirmedEvent
      read FOnLyricsConfirmed write FOnLyricsConfirmed;
  end;

implementation

uses
  System.Math,
  System.SysUtils,
  SYNC_Lyrics_DarkTheme,
  Winapi.Windows;

{$R *.dfm}

procedure TFrameLyricsInitialInput.UpdateInputLayout;
var
  BottomMargin: Integer;
  ButtonHeight: Integer;
  ButtonWidth: Integer;
  Margin: Integer;
  MemoTop: Integer;
  StatusHeight: Integer;
begin
  if (HeaderLabel = nil) or (InstructionsLabel = nil) or
    (LyricsMemo = nil) or (StatusLabel = nil) or
    (ConfirmButton = nil) then
    Exit;
  Margin := MulDiv(24, Max(1, CurrentPPI), 96);
  MemoTop := MulDiv(108, Max(1, CurrentPPI), 96);
  StatusHeight := MulDiv(18, Max(1, CurrentPPI), 96);
  BottomMargin := MulDiv(18, Max(1, CurrentPPI), 96);
  ButtonWidth := MulDiv(104, Max(1, CurrentPPI), 96);
  ButtonHeight := MulDiv(30, Max(1, CurrentPPI), 96);
  HeaderLabel.SetBounds(Margin, Margin,
    Max(1, ClientWidth - Margin * 2),
    MulDiv(25, Max(1, CurrentPPI), 96));
  InstructionsLabel.SetBounds(Margin,
    MulDiv(59, Max(1, CurrentPPI), 96),
    Max(1, ClientWidth - Margin * 2),
    MulDiv(38, Max(1, CurrentPPI), 96));
  ConfirmButton.SetBounds(ClientWidth - Margin - ButtonWidth,
    ClientHeight - BottomMargin - ButtonHeight,
    ButtonWidth, ButtonHeight);
  StatusLabel.SetBounds(Margin,
    ClientHeight - BottomMargin - StatusHeight,
    Max(1, ConfirmButton.Left - Margin * 2), StatusHeight);
  LyricsMemo.SetBounds(Margin, MemoTop,
    Max(1, ClientWidth - Margin * 2),
    Max(1, ConfirmButton.Top - MulDiv(12,
      Max(1, CurrentPPI), 96) - MemoTop));
end;

procedure TFrameLyricsInitialInput.Resize;
begin
  inherited Resize;
  UpdateInputLayout;
end;

procedure TFrameLyricsInitialInput.RefreshInputLayout;
begin
  UpdateInputLayout;
  LyricsMemo.Visible := True;
  LyricsMemo.BringToFront;
end;

procedure TFrameLyricsInitialInput.ApplyDarkTheme;
begin
  ApplySyncLyricsDarkFrame(Self);
  ApplySyncLyricsDarkMemo(LyricsMemo);
  ApplySyncLyricsDarkButton(ConfirmButton);
  HeaderLabel.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  InstructionsLabel.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  RefreshInputLayout;
end;

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
