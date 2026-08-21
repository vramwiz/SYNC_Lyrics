unit SYNC_Lyrics_DisplaySettingsForm;

// Hosts display-setting mode pages without closing the window on mode changes.

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  SYNC_Lyrics_DisplaySettingsModePage,
  SYNC_Lyrics_ToolbarButtons;

type
  TDisplaySettingsModePageEntry = record
    CandidateCaptions: TArray<string>;
    CandidateIndex: Integer;
    InitialCandidateIndex: Integer;
    ModeID: Integer;
    Page: TFrameDisplaySettingsModePage;
  end;

  TFormLyricsDisplaySettings = class(TForm)
  private
    FCandidateCombo: TComboBox;
    FCandidateLabel: TLabel;
    FCurrentMode: Integer;
    FInitialMode: Integer;
    FModePages: TArray<TDisplaySettingsModePageEntry>;
    FModeToolbar: TSyncLyricsToolbarButtons;
    FPageHost: TPanel;
    FTopPanel: TPanel;
    FUpdatingCandidate: Boolean;
    procedure CandidateComboChange(Sender: TObject);
    procedure ComboDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    function FindModePage(ModeID: Integer): TFrameDisplaySettingsModePage;
    function FindModePageIndex(ModeID: Integer): Integer;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ModeButtonExecute(Sender: TObject;
      Button: TSyncLyricsToolbarButton);
    procedure UpdateModeButtons;
    procedure UpdateCandidateCombo;
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure CaptureInitialState;
    procedure ConfigureModeCandidates(ModeID: Integer;
      const Captions: TArray<string>; InitialIndex: Integer);
    procedure RegisterModePage(Page: TFrameDisplaySettingsModePage);
    procedure RestoreInitialState;
    procedure SetMode(ModeID: Integer);
    function CurrentPage: TFrameDisplaySettingsModePage;
    function PageForMode(ModeID: Integer): TFrameDisplaySettingsModePage;
    function ModePageCount: Integer;
    function SelectedCandidateIndex: Integer;
    property CandidateCombo: TComboBox read FCandidateCombo;
    property CurrentMode: Integer read FCurrentMode;
    property ModeToolbar: TSyncLyricsToolbarButtons read FModeToolbar;
    property PageHost: TPanel read FPageHost;
  end;

implementation

uses
  System.Math,
  Winapi.Windows,
  SYNC_Lyrics_CharacterDisplaySettingsPage,
  SYNC_Lyrics_DarkTheme,
  SYNC_Lyrics_LineDisplaySettingsPage;

const
  DISPLAY_SETTINGS_COMMAND_CLOSE = -1;
  DISPLAY_SETTINGS_COMMAND_RESTORE = -2;

constructor TFormLyricsDisplaySettings.Create(AOwner: TComponent);
var
  CharacterPage: TFrameLyricsCharacterDisplaySettingsPage;
  LinePage: TFrameLyricsLineDisplaySettingsPage;
begin
  inherited CreateNew(AOwner);
  Name := 'FormLyricsDisplaySettings';
  Caption := #27468#35422#34920#31034#35373#23450;
  BorderStyle := bsSizeable;
  Position := poScreenCenter;
  OnCloseQuery := FormCloseQuery;
  Font.Name := 'Segoe UI';
  Font.PixelsPerInch := CurrentPPI;
  Font.Height := -MulDiv(12, CurrentPPI, 96);
  ClientWidth := MulDiv(990, CurrentPPI, 96);
  ClientHeight := MulDiv(650, CurrentPPI, 96);
  Constraints.MinWidth := MulDiv(760, CurrentPPI, 96);
  Constraints.MinHeight := MulDiv(560, CurrentPPI, 96);
  DoubleBuffered := True;
  ApplySyncLyricsDarkForm(Self);

  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := Self;
  FTopPanel.BevelOuter := bvNone;
  FTopPanel.Caption := '';
  ApplySyncLyricsDarkPanel(FTopPanel);
  FModeToolbar := TSyncLyricsToolbarButtons.Create(Self);
  FModeToolbar.Parent := FTopPanel;
  FModeToolbar.Color := FTopPanel.Color;
  FModeToolbar.ParentBackground := False;
  FModeToolbar.SeparatorExtent := MulDiv(4, CurrentPPI, 96);
  FModeToolbar.OnButtonExecute := ModeButtonExecute;
  FModeToolbar.AddCommandButton(#38281#12376#12427, tbgClose,
    DISPLAY_SETTINGS_COMMAND_CLOSE);
  FModeToolbar.AddCommandButton(#38283#12356#12383#26178#28857#12408#25147#12377,
    tbgRestore, DISPLAY_SETTINGS_COMMAND_RESTORE);
  FModeToolbar.AddSeparator;
  FCandidateLabel := TLabel.Create(Self);
  FCandidateLabel.Parent := FTopPanel;
  FCandidateLabel.Caption := #32232#38598#23550#35937;
  FCandidateLabel.Font.Assign(Font);
  FCandidateCombo := TComboBox.Create(Self);
  FCandidateCombo.Parent := FTopPanel;
  FCandidateCombo.OnChange := CandidateComboChange;
  ApplySyncLyricsDarkComboBox(FCandidateCombo, ComboDrawItem);

  FPageHost := TPanel.Create(Self);
  FPageHost.Parent := Self;
  FPageHost.BevelOuter := bvNone;
  FPageHost.Caption := '';
  ApplySyncLyricsDarkPanel(FPageHost);

  LinePage := TFrameLyricsLineDisplaySettingsPage.Create(FPageHost);
  RegisterModePage(LinePage);
  CharacterPage := TFrameLyricsCharacterDisplaySettingsPage.Create(FPageHost);
  RegisterModePage(CharacterPage);
  ConfigureModeCandidates(DISPLAY_SETTINGS_MODE_LINE,
    [#37197#32622#49#65288#34920#31034#27573#49#65289,
     #37197#32622#50#65288#34920#31034#27573#50#65289,
     #37197#32622#51#65288#34920#31034#27573#51#65289], 0);
  ConfigureModeCandidates(DISPLAY_SETTINGS_MODE_FREE,
    [#29694#22312#12398#27468#35422], 0);
  FCurrentMode := -1;
  SetMode(DISPLAY_SETTINGS_MODE_LINE);
  Resize;
end;

procedure TFormLyricsDisplaySettings.CandidateComboChange(Sender: TObject);
var
  Index: Integer;
begin
  if FUpdatingCandidate then
    Exit;
  Index := FindModePageIndex(FCurrentMode);
  if Index < 0 then
    Exit;
  FModePages[Index].CandidateIndex := FCandidateCombo.ItemIndex;
  FModePages[Index].Page.CandidateChanged(FCandidateCombo.ItemIndex);
end;

procedure TFormLyricsDisplaySettings.CaptureInitialState;
var
  I: Integer;
begin
  FInitialMode := FCurrentMode;
  for I := 0 to High(FModePages) do
  begin
    FModePages[I].InitialCandidateIndex :=
      FModePages[I].CandidateIndex;
    FModePages[I].Page.CaptureInitialState;
  end;
end;

procedure TFormLyricsDisplaySettings.ComboDrawItem(Control: TWinControl;
  Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  DrawSyncLyricsDarkComboBoxItem(Control as TComboBox, Index, Rect,
    State, CurrentPPI);
end;

procedure TFormLyricsDisplaySettings.ConfigureModeCandidates(
  ModeID: Integer; const Captions: TArray<string>; InitialIndex: Integer);
var
  Index: Integer;
begin
  Index := FindModePageIndex(ModeID);
  if Index < 0 then
    Exit;
  FModePages[Index].CandidateCaptions := Copy(Captions);
  if Length(Captions) = 0 then
    FModePages[Index].CandidateIndex := -1
  else
    FModePages[Index].CandidateIndex := EnsureRange(InitialIndex, 0,
      High(Captions));
  if FCurrentMode = ModeID then
    UpdateCandidateCombo;
end;

function TFormLyricsDisplaySettings.CurrentPage:
  TFrameDisplaySettingsModePage;
begin
  Result := FindModePage(FCurrentMode);
end;

function TFormLyricsDisplaySettings.PageForMode(
  ModeID: Integer): TFrameDisplaySettingsModePage;
begin
  Result := FindModePage(ModeID);
end;

function TFormLyricsDisplaySettings.FindModePage(
  ModeID: Integer): TFrameDisplaySettingsModePage;
var
  Entry: TDisplaySettingsModePageEntry;
begin
  Result := nil;
  for Entry in FModePages do
    if Entry.ModeID = ModeID then
      Exit(Entry.Page);
end;

function TFormLyricsDisplaySettings.FindModePageIndex(
  ModeID: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FModePages) do
    if FModePages[I].ModeID = ModeID then
      Exit(I);
end;

procedure TFormLyricsDisplaySettings.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  ModalResult := mrOk;
  CanClose := True;
end;

procedure TFormLyricsDisplaySettings.ModeButtonExecute(Sender: TObject;
  Button: TSyncLyricsToolbarButton);
begin
  case Button.Tag of
    DISPLAY_SETTINGS_COMMAND_CLOSE:
      ModalResult := mrOk;
    DISPLAY_SETTINGS_COMMAND_RESTORE:
      RestoreInitialState;
  else
    SetMode(Button.Tag);
  end;
end;

function TFormLyricsDisplaySettings.ModePageCount: Integer;
begin
  Result := Length(FModePages);
end;

function TFormLyricsDisplaySettings.SelectedCandidateIndex: Integer;
var
  Index: Integer;
begin
  Index := FindModePageIndex(FCurrentMode);
  if Index < 0 then
    Exit(-1);
  Result := FModePages[Index].CandidateIndex;
end;

procedure TFormLyricsDisplaySettings.RegisterModePage(
  Page: TFrameDisplaySettingsModePage);
var
  Index: Integer;
begin
  if (Page = nil) or (FindModePage(Page.ModeID) <> nil) then
    Exit;
  Index := Length(FModePages);
  SetLength(FModePages, Index + 1);
  FModePages[Index].ModeID := Page.ModeID;
  FModePages[Index].Page := Page;
  FModePages[Index].CandidateIndex := -1;
  FModePages[Index].InitialCandidateIndex := -1;
  FModeToolbar.AddToggleButton(Page.ModeName, Page.ModeGlyph, Page.ModeID);
  Page.Parent := FPageHost;
  Page.Align := alClient;
  Page.Visible := False;
end;

procedure TFormLyricsDisplaySettings.RestoreInitialState;
var
  I: Integer;
begin
  for I := 0 to High(FModePages) do
  begin
    FModePages[I].CandidateIndex :=
      FModePages[I].InitialCandidateIndex;
    FModePages[I].Page.RestoreInitialState;
  end;
  if FCurrentMode <> FInitialMode then
    SetMode(FInitialMode)
  else
  begin
    UpdateCandidateCombo;
    UpdateModeButtons;
  end;
end;

procedure TFormLyricsDisplaySettings.Resize;
var
  Margin: Integer;
  TopHeight: Integer;
begin
  inherited;
  if FTopPanel = nil then
    Exit;
  Margin := MulDiv(12, CurrentPPI, 96);
  TopHeight := MulDiv(48, CurrentPPI, 96);
  FTopPanel.SetBounds(0, 0, ClientWidth, TopHeight);
  FPageHost.SetBounds(0, TopHeight, ClientWidth,
    Max(1, ClientHeight - TopHeight));
  FModeToolbar.ButtonExtent := MulDiv(30, CurrentPPI, 96);
  FModeToolbar.SetBounds(Margin, MulDiv(8, CurrentPPI, 96),
    Max(MulDiv(30, CurrentPPI, 96),
      FModeToolbar.ItemCount * MulDiv(34, CurrentPPI, 96)),
    MulDiv(30, CurrentPPI, 96));
  FCandidateLabel.SetBounds(FModeToolbar.Left + FModeToolbar.Width +
    MulDiv(16, CurrentPPI, 96), MulDiv(16, CurrentPPI, 96),
    MulDiv(56, CurrentPPI, 96), MulDiv(18, CurrentPPI, 96));
  FCandidateCombo.SetBounds(FCandidateLabel.Left +
    MulDiv(64, CurrentPPI, 96), MulDiv(11, CurrentPPI, 96),
    Max(MulDiv(220, CurrentPPI, 96), ClientWidth -
      FCandidateLabel.Left - MulDiv(76, CurrentPPI, 96)),
    MulDiv(24, CurrentPPI, 96));
end;

procedure TFormLyricsDisplaySettings.SetMode(ModeID: Integer);
var
  NewPage: TFrameDisplaySettingsModePage;
  OldPage: TFrameDisplaySettingsModePage;
begin
  NewPage := FindModePage(ModeID);
  if NewPage = nil then
  begin
    UpdateModeButtons;
    Exit;
  end;
  if FCurrentMode = ModeID then
  begin
    UpdateModeButtons;
    Exit;
  end;
  OldPage := FindModePage(FCurrentMode);
  if OldPage <> nil then
  begin
    OldPage.PageDeactivated;
    OldPage.Visible := False;
  end;
  FCurrentMode := ModeID;
  NewPage.Visible := True;
  NewPage.BringToFront;
  UpdateCandidateCombo;
  NewPage.PageActivated;
  UpdateModeButtons;
end;

procedure TFormLyricsDisplaySettings.UpdateCandidateCombo;
var
  CaptionText: string;
  Index: Integer;
begin
  Index := FindModePageIndex(FCurrentMode);
  FUpdatingCandidate := True;
  try
    FCandidateCombo.Items.BeginUpdate;
    try
      FCandidateCombo.Items.Clear;
      if Index >= 0 then
        for CaptionText in FModePages[Index].CandidateCaptions do
          FCandidateCombo.Items.Add(CaptionText);
      if Index >= 0 then
        FCandidateCombo.ItemIndex := FModePages[Index].CandidateIndex
      else
        FCandidateCombo.ItemIndex := -1;
    finally
      FCandidateCombo.Items.EndUpdate;
    end;
  finally
    FUpdatingCandidate := False;
  end;
  if Index >= 0 then
    FModePages[Index].Page.CandidateChanged(
      FModePages[Index].CandidateIndex);
end;

procedure TFormLyricsDisplaySettings.UpdateModeButtons;
var
  Button: TSyncLyricsToolbarButton;
  Entry: TDisplaySettingsModePageEntry;
begin
  if FModeToolbar = nil then
    Exit;
  for Entry in FModePages do
  begin
    Button := FModeToolbar.FindByTag(Entry.ModeID);
    if Button <> nil then
      Button.CheckState := TSyncLyricsToolbarCheckState(
        Ord(Entry.ModeID = FCurrentMode));
  end;
end;

end.
