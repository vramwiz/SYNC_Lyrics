unit SYNC_Lyrics_FontSettingsForm;

// 本文とルビに使用するフォントを一覧とプレビューから選択する。

interface

uses
  System.Classes,
  System.SysUtils,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
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
    BaseBoldCheck: TCheckBox;
    BaseItalicCheck: TCheckBox;
    BaseUnderlineCheck: TCheckBox;
    BaseStrikeOutCheck: TCheckBox;
    RubyBoldCheck: TCheckBox;
    RubyItalicCheck: TCheckBox;
    RubyUnderlineCheck: TCheckBox;
    RubyStrikeOutCheck: TCheckBox;
    procedure BaseFontListClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure RubyFontListClick(Sender: TObject);
    procedure FontStyleClick(Sender: TObject);
  private
    FSelectedBaseFontName: string;
    FSelectedRubyFontName: string;
    FSelectedBaseFontStyle: TFontStyles;
    FSelectedRubyFontStyle: TFontStyles;
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
    property SelectedBaseFontStyle: TFontStyles
      read FSelectedBaseFontStyle write FSelectedBaseFontStyle;
    property SelectedRubyFontStyle: TFontStyles
      read FSelectedRubyFontStyle write FSelectedRubyFontStyle;
  end;

implementation

{$R *.dfm}

procedure TFormLyricsFontSettings.BaseFontListClick(Sender: TObject);
begin
  UpdateBaseSelection;
end;

procedure TFormLyricsFontSettings.FormShow(Sender: TObject);
begin
  BaseBoldCheck.Checked := fsBold in FSelectedBaseFontStyle;
  BaseItalicCheck.Checked := fsItalic in FSelectedBaseFontStyle;
  BaseUnderlineCheck.Checked := fsUnderline in FSelectedBaseFontStyle;
  BaseStrikeOutCheck.Checked := fsStrikeOut in FSelectedBaseFontStyle;
  RubyBoldCheck.Checked := fsBold in FSelectedRubyFontStyle;
  RubyItalicCheck.Checked := fsItalic in FSelectedRubyFontStyle;
  RubyUnderlineCheck.Checked := fsUnderline in FSelectedRubyFontStyle;
  RubyStrikeOutCheck.Checked := fsStrikeOut in FSelectedRubyFontStyle;
  FontStyleClick(nil);
  LoadFontNames(BaseFontList, FSelectedBaseFontName);
  LoadFontNames(RubyFontList, FSelectedRubyFontName);
  UpdateBaseSelection;
  UpdateRubySelection;
  if BaseFontList.CanFocus then
    BaseFontList.SetFocus;
end;

procedure TFormLyricsFontSettings.FontStyleClick(Sender: TObject);
begin
  FSelectedBaseFontStyle := [];
  if BaseBoldCheck.Checked then
    Include(FSelectedBaseFontStyle, fsBold);
  if BaseItalicCheck.Checked then
    Include(FSelectedBaseFontStyle, fsItalic);
  if BaseUnderlineCheck.Checked then
    Include(FSelectedBaseFontStyle, fsUnderline);
  if BaseStrikeOutCheck.Checked then
    Include(FSelectedBaseFontStyle, fsStrikeOut);
  FSelectedRubyFontStyle := [];
  if RubyBoldCheck.Checked then
    Include(FSelectedRubyFontStyle, fsBold);
  if RubyItalicCheck.Checked then
    Include(FSelectedRubyFontStyle, fsItalic);
  if RubyUnderlineCheck.Checked then
    Include(FSelectedRubyFontStyle, fsUnderline);
  if RubyStrikeOutCheck.Checked then
    Include(FSelectedRubyFontStyle, fsStrikeOut);
  BasePreviewPanel.Font.Style := FSelectedBaseFontStyle;
  RubyPreviewPanel.Font.Style := FSelectedRubyFontStyle;
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
    BasePreviewPanel.Font.Style := FSelectedBaseFontStyle;
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
    RubyPreviewPanel.Font.Style := FSelectedRubyFontStyle;
    RubyPreviewPanel.Caption :=
      FSelectedRubyFontName + '  ルビ ふりがな';
  end;
  UpdateButtonState;
end;

end.
