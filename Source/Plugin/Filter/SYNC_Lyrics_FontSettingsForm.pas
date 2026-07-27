unit SYNC_Lyrics_FontSettingsForm;

// 本文とルビに使用するフォントを一覧とプレビューから選択する。

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TFormLyricsFontSettings = class(TForm)
    BaseFontLabel: TLabel;
    BaseFontList: TListBox;
    BasePreviewPanel: TPanel;
    RubyFontLabel: TLabel;
    RubyFontList: TListBox;
    RubyPreviewPanel: TPanel;
    ButtonPanel: TPanel;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    procedure BaseFontListClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RubyFontListClick(Sender: TObject);
  private
    FSelectedBaseFontName: string;
    FSelectedRubyFontName: string;
    procedure LoadFontNames(FontList: TListBox;
      const SelectedFontName: string);
    procedure UpdateBaseSelection;
    procedure UpdateButtonState;
    procedure UpdateRubySelection;
  public
    property SelectedBaseFontName: string read FSelectedBaseFontName
      write FSelectedBaseFontName;
    property SelectedRubyFontName: string read FSelectedRubyFontName
      write FSelectedRubyFontName;
  end;

implementation

{$R *.dfm}

procedure TFormLyricsFontSettings.BaseFontListClick(Sender: TObject);
begin
  UpdateBaseSelection;
end;

procedure TFormLyricsFontSettings.FormShow(Sender: TObject);
begin
  LoadFontNames(BaseFontList, FSelectedBaseFontName);
  LoadFontNames(RubyFontList, FSelectedRubyFontName);
  UpdateBaseSelection;
  UpdateRubySelection;
  if BaseFontList.CanFocus then
    BaseFontList.SetFocus;
end;

procedure TFormLyricsFontSettings.LoadFontNames(FontList: TListBox;
  const SelectedFontName: string);
var
  AddedIndex: Integer;
  I: Integer;
  SelectedIndex: Integer;
begin
  SelectedIndex := -1;
  FontList.Items.BeginUpdate;
  try
    FontList.Clear;
    for I := 0 to Screen.Fonts.Count - 1 do
    begin
      AddedIndex := FontList.Items.Add(Screen.Fonts[I]);
      if SameText(Screen.Fonts[I], SelectedFontName) then
        SelectedIndex := AddedIndex;
    end;
    FontList.ItemIndex := SelectedIndex;
  finally
    FontList.Items.EndUpdate;
  end;
  if SelectedIndex >= 0 then
    FontList.TopIndex := SelectedIndex;
end;

procedure TFormLyricsFontSettings.RubyFontListClick(Sender: TObject);
begin
  UpdateRubySelection;
end;

procedure TFormLyricsFontSettings.UpdateBaseSelection;
begin
  if BaseFontList.ItemIndex >= 0 then
  begin
    FSelectedBaseFontName := BaseFontList.Items[BaseFontList.ItemIndex];
    BasePreviewPanel.Font.Name := FSelectedBaseFontName;
    BasePreviewPanel.Caption :=
      FSelectedBaseFontName + '  aA1 あいうえお 漢字';
  end;
  UpdateButtonState;
end;

procedure TFormLyricsFontSettings.UpdateButtonState;
begin
  ButtonOK.Enabled := (BaseFontList.ItemIndex >= 0) and
    (RubyFontList.ItemIndex >= 0);
end;

procedure TFormLyricsFontSettings.UpdateRubySelection;
begin
  if RubyFontList.ItemIndex >= 0 then
  begin
    FSelectedRubyFontName := RubyFontList.Items[RubyFontList.ItemIndex];
    RubyPreviewPanel.Font.Name := FSelectedRubyFontName;
    RubyPreviewPanel.Caption :=
      FSelectedRubyFontName + '  ルビ ふりがな';
  end;
  UpdateButtonState;
end;

end.
