unit SYNC_Lyrics_DarkTheme;

interface

uses
  System.Types,
  System.UITypes,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.StdCtrls;

const
  SYNC_LYRICS_DARK_BACKGROUND_COLOR = TColor($00202020);
  SYNC_LYRICS_DARK_PANEL_COLOR = TColor($00262626);
  SYNC_LYRICS_DARK_CONTROL_COLOR = TColor($00303030);
  SYNC_LYRICS_DARK_TEXT_COLOR = TColor($00E6E6E6);

procedure ApplySyncLyricsDarkForm(Form: TForm);
procedure ApplySyncLyricsDarkFrame(Frame: TFrame);
procedure ApplySyncLyricsDarkPanel(Panel: TPanel);
procedure ApplySyncLyricsDarkComboBox(ComboBox: TComboBox;
  DrawItemEvent: TDrawItemEvent);
procedure ApplySyncLyricsDarkEdit(Edit: TEdit);
procedure ApplySyncLyricsDarkMemo(Memo: TMemo);
procedure ApplySyncLyricsDarkListBox(ListBox: TListBox);
procedure ApplySyncLyricsDarkListView(ListView: TListView);
procedure ApplySyncLyricsDarkButton(Button: TButton);
procedure DrawSyncLyricsDarkComboBoxItem(ComboBox: TComboBox;
  Index: Integer; const ItemRect: TRect; State: TOwnerDrawState;
  PPI: Integer);

implementation

uses
  Winapi.Dwmapi,
  Winapi.Windows,
  Winapi.UxTheme;

const
  DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 = 19;
  DWMWA_USE_IMMERSIVE_DARK_MODE = 20;

procedure EnableDarkTitleBar(Form: TForm);
var
  Enabled: BOOL;
begin
  Form.HandleNeeded;
  Enabled := True;
  if DwmSetWindowAttribute(Form.Handle, DWMWA_USE_IMMERSIVE_DARK_MODE,
    @Enabled, SizeOf(Enabled)) <> S_OK then
    DwmSetWindowAttribute(Form.Handle,
      DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1, @Enabled,
      SizeOf(Enabled));
end;

procedure ApplySyncLyricsDarkForm(Form: TForm);
begin
  Form.Color := SYNC_LYRICS_DARK_BACKGROUND_COLOR;
  Form.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  EnableDarkTitleBar(Form);
end;

procedure ApplySyncLyricsDarkFrame(Frame: TFrame);
begin
  Frame.ParentBackground := False;
  Frame.ParentColor := False;
  Frame.ParentFont := False;
  Frame.Color := SYNC_LYRICS_DARK_BACKGROUND_COLOR;
  Frame.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
end;

procedure ApplySyncLyricsDarkPanel(Panel: TPanel);
begin
  Panel.ParentBackground := False;
  Panel.Color := SYNC_LYRICS_DARK_PANEL_COLOR;
  Panel.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
end;

procedure ApplySyncLyricsDarkComboBox(ComboBox: TComboBox;
  DrawItemEvent: TDrawItemEvent);
begin
  ComboBox.Style := csOwnerDrawFixed;
  ComboBox.ItemHeight := MulDiv(16, ComboBox.CurrentPPI, 96);
  ComboBox.Color := SYNC_LYRICS_DARK_CONTROL_COLOR;
  ComboBox.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  ComboBox.StyleElements := ComboBox.StyleElements - [seClient];
  ComboBox.OnDrawItem := DrawItemEvent;
  ComboBox.HandleNeeded;
  SetWindowTheme(ComboBox.Handle, 'DarkMode_CFD', nil);
end;

procedure ApplySyncLyricsDarkEdit(Edit: TEdit);
begin
  Edit.Color := SYNC_LYRICS_DARK_CONTROL_COLOR;
  Edit.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  Edit.StyleElements := Edit.StyleElements - [seClient];
end;

procedure ApplySyncLyricsDarkMemo(Memo: TMemo);
begin
  Memo.Color := SYNC_LYRICS_DARK_CONTROL_COLOR;
  Memo.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  Memo.StyleElements := Memo.StyleElements - [seClient];
end;

procedure ApplySyncLyricsDarkListBox(ListBox: TListBox);
begin
  ListBox.Color := SYNC_LYRICS_DARK_CONTROL_COLOR;
  ListBox.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  ListBox.StyleElements := ListBox.StyleElements - [seClient];
  ListBox.HandleNeeded;
  SetWindowTheme(ListBox.Handle, 'DarkMode_Explorer', nil);
end;

procedure ApplySyncLyricsDarkListView(ListView: TListView);
begin
  ListView.Color := SYNC_LYRICS_DARK_CONTROL_COLOR;
  ListView.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  ListView.StyleElements := ListView.StyleElements - [seClient];
  ListView.HandleNeeded;
  SetWindowTheme(ListView.Handle, 'DarkMode_Explorer', nil);
end;

procedure ApplySyncLyricsDarkButton(Button: TButton);
begin
  Button.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  Button.HandleNeeded;
  SetWindowTheme(Button.Handle, 'DarkMode_Explorer', nil);
end;

procedure DrawSyncLyricsDarkComboBoxItem(ComboBox: TComboBox;
  Index: Integer; const ItemRect: TRect; State: TOwnerDrawState;
  PPI: Integer);
var
  DrawRect: TRect;
  Text: string;
begin
  if odSelected in State then
  begin
    ComboBox.Canvas.Brush.Color := clHighlight;
    ComboBox.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    ComboBox.Canvas.Brush.Color := SYNC_LYRICS_DARK_CONTROL_COLOR;
    ComboBox.Canvas.Font.Color := SYNC_LYRICS_DARK_TEXT_COLOR;
  end;
  ComboBox.Canvas.FillRect(ItemRect);
  if (Index < 0) or (Index >= ComboBox.Items.Count) then
    Exit;

  Text := ComboBox.Items[Index];
  DrawRect := ItemRect;
  Inc(DrawRect.Left, MulDiv(4, PPI, 96));
  DrawText(ComboBox.Canvas.Handle, PChar(Text), Length(Text), DrawRect,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

end.
