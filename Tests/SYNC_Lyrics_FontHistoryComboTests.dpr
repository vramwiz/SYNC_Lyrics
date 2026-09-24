program SYNC_Lyrics_FontHistoryComboTests;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  Winapi.Messages,
  Winapi.Windows,
  Vcl.Controls,
  Vcl.Forms,
  SYNC_Lyrics_DarkTheme in '..\Source\Lib\SYNC_Lyrics_DarkTheme.pas',
  SYNC_Lyrics_FontHistoryComboBox in '..\Source\Lib\SYNC_Lyrics_FontHistoryComboBox.pas';

type
  TTestFontCombo = class(TSyncLyricsFontHistoryComboBox)
  public
    procedure SimulateCloseUp;
    procedure SimulateDropDown;
    procedure SimulateFocusLoss;
    procedure SimulateNativePick(Index: Integer);
  end;

  TCommitCounter = class
    Count: Integer;
    procedure FontCommitted(Sender: TObject);
  end;

procedure TTestFontCombo.SimulateCloseUp;
begin
  CloseUp;
end;

procedure TTestFontCombo.SimulateDropDown;
begin
  DropDown;
end;

procedure TTestFontCombo.SimulateFocusLoss;
begin
  DoExit;
end;

procedure TTestFontCombo.SimulateNativePick(Index: Integer);
begin
  Perform(CB_SETCURSEL, Index, 0);
  Perform(CN_COMMAND, MakeWParam(0, CBN_SELCHANGE), 0);
  Perform(CN_COMMAND, MakeWParam(0, CBN_SELENDOK), 0);
  Perform(CN_COMMAND, MakeWParam(0, CBN_CLOSEUP), 0);
end;

procedure TCommitCounter.FontCommitted(Sender: TObject);
begin
  Inc(Count);
end;

var
  BaseCombo: TTestFontCombo;
  FontA: string;
  FontB: string;
  Form: TForm;
  HistoryFile: string;
  HistoryLines: TStringList;
  LoadedCombo: TTestFontCombo;
  NativeCombo: TTestFontCombo;
  Counter: TCommitCounter;
  RubyCombo: TTestFontCombo;
begin
  HistoryFile := TPath.Combine(TPath.GetTempPath,
    'SYNC_Lyrics_FontHistory_Test_' +
    IntToStr(GetCurrentProcessId) + '.txt');
  if TFile.Exists(HistoryFile) then
    TFile.Delete(HistoryFile);
  try
    Application.Initialize;
    if Screen.Fonts.Count < 3 then
      raise Exception.Create('test requires three installed fonts');
    FontA := Screen.Fonts[Screen.Fonts.Count - 1];
    FontB := Screen.Fonts[Screen.Fonts.Count div 2];
    TSyncLyricsFontHistoryComboBox.ConfigureHistoryFile(HistoryFile);
    Form := TForm.Create(nil);
    Counter := TCommitCounter.Create;
    try
      BaseCombo := TTestFontCombo.Create(Form);
      BaseCombo.Parent := Form;
      BaseCombo.OnFontCommitted := Counter.FontCommitted;
      RubyCombo := TTestFontCombo.Create(Form);
      RubyCombo.Parent := Form;
      RubyCombo.OnFontCommitted := Counter.FontCommitted;
      if (BaseCombo.ItemHeight <>
        MulDiv(16, BaseCombo.CurrentPPI, 96)) or
        (RubyCombo.ItemHeight <>
        MulDiv(16, RubyCombo.CurrentPPI, 96)) then
        raise Exception.Create('font combo height was not set after parenting');
      BaseCombo.SetSelectedFont(FontA);
      RubyCombo.SetSelectedFont(FontB);
      BaseCombo.SimulateCloseUp;
      if TFile.Exists(HistoryFile) or (Counter.Count <> 0) then
        raise Exception.Create('unchanged font changed history');
      BaseCombo.ItemIndex := BaseCombo.Items.IndexOf(FontB);
      BaseCombo.SimulateFocusLoss;
      if (Counter.Count <> 1) or not TFile.Exists(HistoryFile) then
        raise Exception.Create('focus loss did not commit font');
      if (BaseCombo.ItemIndex <> Screen.Fonts.IndexOf(FontB)) or
        (BaseCombo.Items[BaseCombo.ItemIndex - 1] <>
          Screen.Fonts[Screen.Fonts.IndexOf(FontB) - 1]) then
        raise Exception.Create('committing a font shifted its list position');
      RubyCombo.ItemIndex := RubyCombo.Items.IndexOf(FontA);
      RubyCombo.SimulateCloseUp;
      if Counter.Count <> 2 then
        raise Exception.Create('dropdown close did not commit font');
      if (BaseCombo.Text <> FontB) or (RubyCombo.Text <> FontA) then
        raise Exception.Create('base and ruby selections were not independent');
      NativeCombo := TTestFontCombo.Create(Form);
      NativeCombo.Parent := Form;
      NativeCombo.OnFontCommitted := Counter.FontCommitted;
      NativeCombo.SetSelectedFont(FontA);
      NativeCombo.SimulateNativePick(NativeCombo.Items.IndexOf(FontB));
      if (Counter.Count <> 3) or
        (NativeCombo.CommittedFont <> FontB) then
        raise Exception.Create('native list selection did not commit font');
      TSyncLyricsFontHistoryComboBox.ConfigureHistoryFile(HistoryFile);
      LoadedCombo := TTestFontCombo.Create(Form);
      LoadedCombo.Parent := Form;
      if (LoadedCombo.Items[0] <> FontB) or
        (LoadedCombo.Items[1] <> FontA) or
        (LoadedCombo.Items[2] <> Screen.Fonts[0]) or
        (LoadedCombo.Items[2 + Screen.Fonts.IndexOf(FontA)] <> FontA) or
        (LoadedCombo.Items[2 + Screen.Fonts.IndexOf(FontB)] <> FontB) then
        raise Exception.Create('recent fonts are not above the alphabetic list');
      HistoryLines := TStringList.Create;
      try
        HistoryLines.LoadFromFile(HistoryFile, TEncoding.UTF8);
        if (HistoryLines.Count < 2) or
          (HistoryLines[0] <> FontB) or (HistoryLines[1] <> FontA) then
          raise Exception.Create('shared font history was not restored');
      finally
        HistoryLines.Free;
      end;
      LoadedCombo.SetSelectedFont(FontB);
      if LoadedCombo.ItemIndex <> 0 then
        raise Exception.Create('recent selection did not use the top section');
      LoadedCombo.SimulateNativePick(
        2 + Screen.Fonts.IndexOf(FontA));
      LoadedCombo.SimulateDropDown;
      if (LoadedCombo.ItemIndex <> 2 + Screen.Fonts.IndexOf(FontA)) or
        (LoadedCombo.Items[LoadedCombo.ItemIndex] <> FontA) then
        raise Exception.Create('alphabetic selection jumped to recent fonts');
      Writeln('FONT_HISTORY_OK');
    finally
      Counter.Free;
      Form.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
  if TFile.Exists(HistoryFile) then
    TFile.Delete(HistoryFile);
end.
