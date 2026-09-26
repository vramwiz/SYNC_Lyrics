unit SYNC_Lyrics_FontHistoryComboBox;

// A font picker with live wheel preview, explicit history commits, and shared per-user recents.

interface

uses
  System.Classes,
  System.Types,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.StdCtrls;

type
  TSyncLyricsFontHistoryComboBox = class(TComboBox)
  private
    FCommittedFont: string;         // Value last saved to the shared recent-font history.
    FRecentCount: Integer;          // Length of the leading recent-font section.
    FSelectionInRecent: Boolean;    // Preserve which duplicate the user browsed.
    FUpdatingItems: Boolean;        // Suppress commits during list reconstruction.
    FCancelCloseUp: Boolean;        // Escape restores the previous committed value.
    FOnFontCommitted: TNotifyEvent;
    FOnFontPreviewChanged: TNotifyEvent;
    class var FHistoryFileName: string;
    class var FHistoryLoaded: Boolean;
    class var FRecentFonts: TStringList;
    class function GetHistoryFileName: string; static;
    class procedure LoadHistory; static;
    class procedure PromoteFont(const FontName: string); static;
    class procedure SaveHistory; static;
    procedure CommitSelectionInternal(ExplicitChoice: Boolean);
    function FindAlphabeticalFontItem(const FontName: string): Integer;
    function FindFontItem(const FontName: string): Integer;
    function GetSelectedFont: string;
    function MoveAlphabetically(Offset: Integer): Boolean;
    procedure RefreshFonts;
  protected
    procedure CNCommand(var Message: TWMCommand); message CN_COMMAND;
    procedure CloseUp; override;
    procedure CreateWnd; override;
    procedure DoExit; override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint): Boolean; override;
    function DoMouseWheelDown(Shift: TShiftState;
      MousePos: TPoint): Boolean; override;
    function DoMouseWheelUp(Shift: TShiftState;
      MousePos: TPoint): Boolean; override;
    procedure DrawItem(Index: Integer; Rect: TRect;
      State: TOwnerDrawState); override;
    procedure DropDown; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure SetParent(AParent: TWinControl); override;
  public
    class constructor Create;
    class destructor Destroy;
    constructor Create(AOwner: TComponent); override;
    // Overrides the shared history path and clears its cache; intended for isolated tests.
    class procedure ConfigureHistoryFile(const FileName: string);
    // Explicitly commits ItemIndex, updates shared history, and notifies the owner.
    procedure CommitSelection;
    // Displays a saved value without changing history or notifying the owner.
    procedure SetSelectedFont(const FontName: string);
    // Returns the visible font, including an uncommitted wheel selection.
    property SelectedFont: string read GetSelectedFont;
    // The last value committed to history, independent of wheel browsing.
    property CommittedFont: string read FCommittedFont;
    // Fires only when a list choice is committed, after history has been saved.
    property OnFontCommitted: TNotifyEvent read FOnFontCommitted
      write FOnFontCommitted;
    // Lets the owner redraw each wheel step without saving that font to history.
    property OnFontPreviewChanged: TNotifyEvent read FOnFontPreviewChanged
      write FOnFontPreviewChanged;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows,
  Winapi.UxTheme,
  Vcl.Forms,
  Vcl.Graphics,
  SYNC_Lyrics_DarkTheme;

const
  MAX_RECENT_FONTS = 10;
  RECENT_ACCENT = TColor($00DDA96A);

class constructor TSyncLyricsFontHistoryComboBox.Create;
begin
  FRecentFonts := TStringList.Create;
  FRecentFonts.CaseSensitive := False;
end;

class destructor TSyncLyricsFontHistoryComboBox.Destroy;
begin
  FRecentFonts.Free;
end;

constructor TSyncLyricsFontHistoryComboBox.Create(AOwner: TComponent);
begin
  inherited;
  Style := csOwnerDrawFixed;
  Color := SYNC_LYRICS_DARK_CONTROL_COLOR;
  Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  StyleElements := StyleElements - [seClient];
  FSelectionInRecent := True;
end;

procedure TSyncLyricsFontHistoryComboBox.SetParent(AParent: TWinControl);
var
  DesiredHeight: Integer;
begin
  inherited;
  if AParent = nil then
    Exit;
  HandleNeeded;
  DesiredHeight := MulDiv(16, CurrentPPI, 96);
  if ItemHeight <> DesiredHeight then
    ItemHeight := DesiredHeight;
end;

class procedure TSyncLyricsFontHistoryComboBox.ConfigureHistoryFile(
  const FileName: string);
begin
  FHistoryFileName := FileName;
  FHistoryLoaded := False;
  FRecentFonts.Clear;
end;

class function TSyncLyricsFontHistoryComboBox.GetHistoryFileName: string;
var
  Root: string;
begin
  if FHistoryFileName <> '' then
    Exit(FHistoryFileName);
  Root := GetEnvironmentVariable('APPDATA');
  if Root = '' then
    Root := TPath.GetHomePath;
  Result := TPath.Combine(TPath.Combine(Root, 'SYNC_Lyrics'),
    'font-history.txt');
end;

class procedure TSyncLyricsFontHistoryComboBox.LoadHistory;
var
  FontIndex: Integer;
  I: Integer;
  Lines: TStringList;
  Name: string;
begin
  if FHistoryLoaded then
    Exit;
  FHistoryLoaded := True;
  FRecentFonts.Clear;
  Lines := TStringList.Create;
  try
    try
      if TFile.Exists(GetHistoryFileName) then
        Lines.LoadFromFile(GetHistoryFileName, TEncoding.UTF8);
    except
      Exit;
    end;
    for I := 0 to Lines.Count - 1 do
    begin
      Name := Trim(Lines[I]);
      FontIndex := Screen.Fonts.IndexOf(Name);
      if (FontIndex >= 0) and
        (FRecentFonts.IndexOf(Screen.Fonts[FontIndex]) < 0) then
        FRecentFonts.Add(Screen.Fonts[FontIndex]);
      if FRecentFonts.Count >= MAX_RECENT_FONTS then
        Break;
    end;
  finally
    Lines.Free;
  end;
end;

class procedure TSyncLyricsFontHistoryComboBox.SaveHistory;
var
  FileName: string;
  TempName: string;
begin
  FileName := GetHistoryFileName;
  TempName := FileName + '.tmp';
  try
    ForceDirectories(ExtractFileDir(FileName));
    FRecentFonts.SaveToFile(TempName, TEncoding.UTF8);
    if not MoveFileEx(PChar(TempName), PChar(FileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
      DeleteFile(PChar(TempName));
  except
    // Preference I/O must not interrupt editing or AviUtl2 callbacks.
  end;
end;

class procedure TSyncLyricsFontHistoryComboBox.PromoteFont(
  const FontName: string);
var
  FontIndex: Integer;
  HistoryIndex: Integer;
begin
  LoadHistory;
  FontIndex := Screen.Fonts.IndexOf(FontName);
  if FontIndex < 0 then
    Exit;
  HistoryIndex := FRecentFonts.IndexOf(Screen.Fonts[FontIndex]);
  if HistoryIndex >= 0 then
    FRecentFonts.Delete(HistoryIndex);
  FRecentFonts.Insert(0, Screen.Fonts[FontIndex]);
  while FRecentFonts.Count > MAX_RECENT_FONTS do
    FRecentFonts.Delete(FRecentFonts.Count - 1);
  SaveHistory;
end;

function TSyncLyricsFontHistoryComboBox.FindAlphabeticalFontItem(
  const FontName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  if FontName = '' then
    Exit;
  for I := FRecentCount to Items.Count - 1 do
    if SameText(Items[I], FontName) then
      Exit(I);
end;

function TSyncLyricsFontHistoryComboBox.FindFontItem(
  const FontName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  if FontName = '' then
    Exit;
  if FSelectionInRecent then
    for I := 0 to FRecentCount - 1 do
      if SameText(Items[I], FontName) then
        Exit(I);
  Result := FindAlphabeticalFontItem(FontName);
  if Result >= 0 then Exit;
  if not FSelectionInRecent then
    for I := 0 to FRecentCount - 1 do
      if SameText(Items[I], FontName) then
        Exit(I);
end;

function TSyncLyricsFontHistoryComboBox.GetSelectedFont: string;
begin
  if (ItemIndex >= 0) and (ItemIndex < Items.Count) then
    Result := Items[ItemIndex]
  else
    Result := FCommittedFont;
end;

function TSyncLyricsFontHistoryComboBox.MoveAlphabetically(
  Offset: Integer): Boolean;
var
  FontIndex: Integer;
  ListIndex: Integer;
  PreviousFont: string;
begin
  Result := True;
  if Screen.Fonts.Count = 0 then Exit;
  PreviousFont := SelectedFont;
  // The leading history copies are display shortcuts, not wheel neighbors.
  FontIndex := Screen.Fonts.IndexOf(Text);
  if FontIndex < 0 then
  begin
    if Offset > 0 then FontIndex := -1
    else FontIndex := Screen.Fonts.Count;
  end;
  Inc(FontIndex, Offset);
  if FontIndex < 0 then FontIndex := 0;
  if FontIndex >= Screen.Fonts.Count then
    FontIndex := Screen.Fonts.Count - 1;
  ListIndex := FindAlphabeticalFontItem(Screen.Fonts[FontIndex]);
  if ListIndex < 0 then Exit;
  ItemIndex := ListIndex;
  Invalidate;
  if not SameText(SelectedFont, PreviousFont) and
    Assigned(FOnFontPreviewChanged) then
    FOnFontPreviewChanged(Self);
end;

procedure TSyncLyricsFontHistoryComboBox.RefreshFonts;
var
  FontName: string;
  I: Integer;
  PendingSelection: Boolean;
  SelectionWasRecent: Boolean;
begin
  if FUpdatingItems then
    Exit;
  LoadHistory;
  FontName := FCommittedFont;
  PendingSelection := (ItemIndex >= 0) and (ItemIndex < Items.Count) and
    not SameText(Items[ItemIndex], FCommittedFont);
  SelectionWasRecent := ItemIndex < FRecentCount;
  if PendingSelection then
    FontName := Items[ItemIndex]
  else if FontName = '' then
    FontName := Text;
  FUpdatingItems := True;
  Items.BeginUpdate;
  try
    Items.Clear;
    for I := 0 to FRecentFonts.Count - 1 do
      Items.Add(FRecentFonts[I]);
    FRecentCount := Items.Count;
    for I := 0 to Screen.Fonts.Count - 1 do
      Items.Add(Screen.Fonts[I]);
    if (FontName <> '') and (Items.IndexOf(FontName) < 0) then
      Items.Add(FontName);
    if PendingSelection then
    begin
      if SelectionWasRecent then
        ItemIndex := Items.IndexOf(FontName)
      else
        ItemIndex := FindAlphabeticalFontItem(FontName);
    end
    else
      ItemIndex := FindFontItem(FontName);
  finally
    Items.EndUpdate;
    FUpdatingItems := False;
  end;
end;

procedure TSyncLyricsFontHistoryComboBox.SetSelectedFont(
  const FontName: string);
begin
  if not SameText(FontName, FCommittedFont) then
    FSelectionInRecent := True;
  FCommittedFont := FontName;
  if (FontName <> '') and (Items.IndexOf(FontName) < 0) then
    Items.Add(FontName);
  ItemIndex := FindFontItem(FontName);
end;

procedure TSyncLyricsFontHistoryComboBox.CommitSelectionInternal(
  ExplicitChoice: Boolean);
var
  FontName: string;
  Changed: Boolean;
begin
  if FUpdatingItems or (ItemIndex < 0) then
    Exit;
  FontName := Items[ItemIndex];
  if Screen.Fonts.IndexOf(FontName) < 0 then
    Exit;
  FSelectionInRecent := ItemIndex < FRecentCount;
  Changed := not SameText(FontName, FCommittedFont);
  if not Changed and not ExplicitChoice then
    Exit;
  FCommittedFont := FontName;
  PromoteFont(FontName);
  Invalidate;
  if Assigned(FOnFontCommitted) then
    FOnFontCommitted(Self);
end;

procedure TSyncLyricsFontHistoryComboBox.CommitSelection;
begin
  CommitSelectionInternal(True);
end;

procedure TSyncLyricsFontHistoryComboBox.CNCommand(
  var Message: TWMCommand);
begin
  inherited;
  if Message.NotifyCode = CBN_SELENDOK then
    CommitSelectionInternal(False);
end;

procedure TSyncLyricsFontHistoryComboBox.CloseUp;
var
  PreviousFont: string;
begin
  inherited;
  if FCancelCloseUp then
  begin
    PreviousFont := SelectedFont;
    SetSelectedFont(FCommittedFont)
  end
  else
    CommitSelectionInternal(False);
  if FCancelCloseUp and not SameText(SelectedFont, PreviousFont) and
    Assigned(FOnFontPreviewChanged) then
    FOnFontPreviewChanged(Self);
  FCancelCloseUp := False;
end;

procedure TSyncLyricsFontHistoryComboBox.DoExit;
begin
  if not FCancelCloseUp then
    CommitSelectionInternal(False);
  inherited;
end;

function TSyncLyricsFontHistoryComboBox.DoMouseWheel(Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := inherited;
  // Suppress native index stepping, including sub-notch deltas accumulated by VCL.
  if not DroppedDown then Result := True;
end;

function TSyncLyricsFontHistoryComboBox.DoMouseWheelDown(
  Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  if DroppedDown then Result := inherited
  else Result := MoveAlphabetically(1);
end;

function TSyncLyricsFontHistoryComboBox.DoMouseWheelUp(
  Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  if DroppedDown then Result := inherited
  else Result := MoveAlphabetically(-1);
end;

procedure TSyncLyricsFontHistoryComboBox.DropDown;
begin
  RefreshFonts;
  FCancelCloseUp := False;
  inherited;
end;

procedure TSyncLyricsFontHistoryComboBox.KeyDown(var Key: Word;
  Shift: TShiftState);
var
  CommitOnEnter: Boolean;
begin
  if (Key = VK_ESCAPE) and DroppedDown then
    FCancelCloseUp := True;
  CommitOnEnter := (Key = VK_RETURN) and not DroppedDown;
  inherited;
  if CommitOnEnter then
    CommitSelectionInternal(False);
end;

procedure TSyncLyricsFontHistoryComboBox.CreateWnd;
begin
  inherited;
  SetWindowTheme(Handle, 'DarkMode_CFD', nil);
  RefreshFonts;
end;

procedure TSyncLyricsFontHistoryComboBox.DrawItem(Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  PreviousBkMode: Integer;
  RowColor: TColor;
  TextRect: TRect;
begin
  if odSelected in State then
  begin
    RowColor := clHighlight;
    Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    RowColor := SYNC_LYRICS_DARK_CONTROL_COLOR;
    Canvas.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  end;
  Canvas.Brush.Color := RowColor;
  Canvas.FillRect(Rect);
  if (Index < 0) or (Index >= Items.Count) then
    Exit;
  TextRect := Rect;
  Inc(TextRect.Left, MulDiv(5, CurrentPPI, 96));
  if (odComboBoxEdit not in State) and (Index < FRecentCount) then
  begin
    Canvas.Brush.Color := RECENT_ACCENT;
    Canvas.FillRect(System.Types.Rect(Rect.Left + 1, Rect.Top + 2,
      Rect.Left + MulDiv(3, CurrentPPI, 96), Rect.Bottom - 2));
  end;
  Canvas.Brush.Color := RowColor;
  PreviousBkMode := SetBkMode(Canvas.Handle, TRANSPARENT);
  try
    DrawText(Canvas.Handle, PChar(Items[Index]), Length(Items[Index]),
      TextRect, DT_LEFT or DT_VCENTER or DT_SINGLELINE or
      DT_END_ELLIPSIS or DT_NOPREFIX);
  finally
    SetBkMode(Canvas.Handle, PreviousBkMode);
  end;
end;

end.
