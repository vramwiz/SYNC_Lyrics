unit SYNC_Lyrics_FilterPlugin;

// 歌詞テロップFilterの最小登録とパススルー処理を担当する。

interface

uses
  AviUtl2FilterTypes;

// AviUtl2へ登録するFilterテーブルを返し、設定項目配列を初回取得時に確定する。
function GetLyricsFilterTable: PFILTER_PLUGIN_TABLE;

// 共有フレーム、補間コンテキスト、描画資源をFilter読込時に初期化する。
procedure InitializeLyricsFilter;

// Filter解放時に描画資源、補間コンテキスト、共有フレームを逆順で解放する。
procedure FinalizeLyricsFilter;

implementation

uses
  System.Math,
  System.SysUtils,
  System.UITypes,
  SYNC_Lyrics_ContextManager,
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_CharacterLayoutSettingsForm,
  SYNC_Lyrics_FontSettingsForm,
  SYNC_Lyrics_FrameShared,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_LastFrameCapture,
  SYNC_Lyrics_ManualSync,
  SYNC_Lyrics_ManualSyncSettingsForm,
  SYNC_Lyrics_AudioProbe,
  SYNC_Lyrics_MusicSync,
  SYNC_Lyrics_MusicSyncAnchor,
  SYNC_Lyrics_MusicSyncSettingsForm,
  SYNC_Lyrics_LineDisplaySettingsForm,
  SYNC_Lyrics_Animation,
  SYNC_Lyrics_Renderer,
  SYNC_Lyrics_SyncSourceKind,
  SYNC_Lyrics_SyncFormat,
  SYNC_Lyrics_Time,
  Winapi.Windows,
  Vcl.Dialogs,
  Vcl.Forms,
  Vcl.Graphics;

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl; forward;
procedure FontSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
procedure MusicSyncSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
procedure DisplaySettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
procedure CharacterLayoutSettingsButtonCallback(
  Edit: PEDIT_SECTION); cdecl; forward;
procedure LineDisplaySettingsButtonCallback(
  Edit: PEDIT_SECTION); cdecl; forward;

var
  LyricsItem: TFILTER_ITEM_STRING = (
    ItemType: 'string';
    Name: '歌詞';
    Value: ''
  );
  MusicFileItem: TFILTER_ITEM_FILE = (
    ItemType: 'file';
    Name: '音楽ファイル';
    Value: '';
    FileFilter:
      '同期ファイル (*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz;*.wav;*.mp3;*.flac;*.m4a;*.aac;*.ogg;*.opus;*.wma)'#0 +
      '*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz;*.wav;*.mp3;*.flac;*.m4a;*.aac;*.ogg;*.opus;*.wma'#0 +
      '楽譜ファイル (*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz)'#0 +
      '*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz'#0 +
      '音声ファイル (*.wav;*.mp3;*.flac;*.m4a;*.aac;*.ogg;*.opus;*.wma)'#0 +
      '*.wav;*.mp3;*.flac;*.m4a;*.aac;*.ogg;*.opus;*.wma'#0 +
      'すべてのファイル (*.*)'#0'*.*'#0#0
  );
  TrackItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: 'トラック (-1=全て)';
    Value: -1;
    S: -1;
    E: 255;
    Step: 1
  );
  PositionXItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: 'X';
    Value: 0;
    S: -10000;
    E: 10000;
    Step: 1
  );
  PositionYItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: 'Y';
    Value: 0;
    S: -10000;
    E: 10000;
    Step: 1
  );
  FontSettingsButton: TFILTER_ITEM_BUTTON = (
    ItemType: 'button';
    Name: 'フォント設定';
    Callback: FontSettingsButtonCallback
  );
  BaseFontItem: TFILTER_ITEM_STRING = (
    ItemType: 'string';
    Name: 'フォント名';
    Value: 'Yu Gothic UI'
  );
  BaseBoldItem: TFILTER_ITEM_CHECK = (
    ItemType: 'check';
    Name: '太字';
    Value: 1
  );
  BaseItalicItem: TFILTER_ITEM_CHECK = (
    ItemType: 'check';
    Name: '斜体';
    Value: 0
  );
  BaseUnderlineItem: TFILTER_ITEM_CHECK = (
    ItemType: 'check';
    Name: '下線';
    Value: 0
  );
  BaseStrikeOutItem: TFILTER_ITEM_CHECK = (
    ItemType: 'check';
    Name: '取り消し線';
    Value: 0
  );
  RubyFontItem: TFILTER_ITEM_STRING = (
    ItemType: 'string';
    Name: 'フォント名（ルビ）';
    Value: 'Yu Gothic UI'
  );
  RubyBoldItem: TFILTER_ITEM_CHECK = (
    ItemType: 'check';
    Name: '太字（ルビ）';
    Value: 1
  );
  RubyItalicItem: TFILTER_ITEM_CHECK = (
    ItemType: 'check';
    Name: '斜体（ルビ）';
    Value: 0
  );
  RubyUnderlineItem: TFILTER_ITEM_CHECK = (
    ItemType: 'check';
    Name: '下線（ルビ）';
    Value: 0
  );
  RubyStrikeOutItem: TFILTER_ITEM_CHECK = (
    ItemType: 'check';
    Name: '取り消し線（ルビ）';
    Value: 0
  );
  BeforeColorItem: TFILTER_ITEM_COLOR = (
    ItemType: 'color';
    Name: '変化前色';
    B: 255;
    G: 255;
    R: 255;
    X: 0
  );
  AfterColorItem: TFILTER_ITEM_COLOR = (
    ItemType: 'color';
    Name: '変化後色';
    B: 255;
    G: 255;
    R: 0;
    X: 0
  );
  PlacementModeList: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '1行配置'; Value: 0),
    (Name: '文字自由配置'; Value: 1),
    (Name: nil; Value: 0)
  );
  PlacementModeItem: TFILTER_ITEM_SELECT = (
    ItemType: 'select';
    Name: '配置モード';
    Value: 0;
    List: @PlacementModeList[0]
  );
  DisplayEffectList: array[0..3] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '通常カラオケ'; Value: 0),
    (Name: '文字単位強調'; Value: 1),
    (Name: '1文字ずつ出現'; Value: 2),
    (Name: nil; Value: 0)
  );
  DisplayEffectItem: TFILTER_ITEM_SELECT = (
    ItemType: 'select';
    Name: '同期演出';
    Value: 0;
    List: @DisplayEffectList[0]
  );
  DisplaySettingsButton: TFILTER_ITEM_BUTTON = (
    ItemType: 'button';
    Name: '表示設定';
    Callback: DisplaySettingsButtonCallback
  );
  SyncAnimationList: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: 0),
    (Name: 'バウンド'; Value: 1),
    (Name: nil; Value: 0)
  );
  SyncAnimationItem: TFILTER_ITEM_SELECT = (
    ItemType: 'select';
    Name: '同期アニメーション';
    Value: 0;
    List: @SyncAnimationList[0]
  );
  EdgeAnimationList: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: 0),
    (Name: 'フェード'; Value: 1),
    (Name: nil; Value: 0)
  );
  StartAnimationItem: TFILTER_ITEM_SELECT = (
    ItemType: 'select';
    Name: '開始演出';
    Value: 0;
    List: @EdgeAnimationList[0]
  );
  StartAnimationTimeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: '開始演出時間 (秒)';
    Value: 0.3;
    S: 0.01;
    E: 10;
    Step: 0.01
  );
  EndAnimationItem: TFILTER_ITEM_SELECT = (
    ItemType: 'select';
    Name: '終了演出';
    Value: 0;
    List: @EdgeAnimationList[0]
  );
  EndAnimationTimeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: '終了演出時間 (秒)';
    Value: 0.3;
    S: 0.01;
    E: 10;
    Step: 0.01
  );
  BaseFontSizeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: '歌詞サイズ';
    Value: 96;
    S: 1;
    E: 1024;
    Step: 1
  );
  RubyFontSizeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: 'ルビサイズ';
    Value: 42;
    S: 1;
    E: 1024;
    Step: 1
  );
  RubyGapAdjustmentItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: 'ルビ間隔補正';
    Value: 0;
    S: -200;
    E: 500;
    Step: 1
  );
  BaseCharacterSpacingItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: '字間';
    Value: 0;
    S: -100;
    E: 100;
    Step: 1
  );
  RubyCharacterSpacingItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: '字間（ルビ）';
    Value: 0;
    S: -100;
    E: 100;
    Step: 1
  );
  PreDisplayTimeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: '事前表示 (秒)';
    Value: 0.5;
    S: 0;
    E: 60;
    Step: 0.01
  );
  MusicSyncSettingsButton: TFILTER_ITEM_BUTTON = (
    ItemType: 'button';
    Name: '曲同期設定';
    Callback: MusicSyncSettingsButtonCallback
  );
  SyncDataItem: TFILTER_ITEM_STRING = (
    ItemType: 'string';
    Name: '同期データ';
    Value: DEFAULT_MUSIC_SYNC_TEXT
  );
  DisplaySettingsTextItem: TFILTER_ITEM_STRING = (
    ItemType: 'string';
    Name: '表示設定';
    Value: ''
  );
  PluginItems: array[0..35] of Pointer;
  Plugin: TFILTER_PLUGIN_TABLE = (
    Flag: FILTER_FLAG_VIDEO;
    Name: 'SYNC_歌詞テロップ_Filter';
    Label_: 'SYNC';
    Information: '音楽データに同期する歌詞テロップフィルター';
    Items: nil;
    Func_Proc_Video: LyricsProcVideo;
    Func_Proc_Audio: nil
  );

const
  FILTER_EFFECT_NAME = 'SYNC_歌詞テロップ_Filter';
  BASE_FONT_ITEM_NAME = 'フォント名';
  RUBY_FONT_ITEM_NAME = 'フォント名（ルビ）';
  PLACEMENT_MODE_LINE = 0;
  PLACEMENT_MODE_FREE = 1;

type
  TFilterItemUpdate = record
    Name: string;
    OldValue: string;
    NewValue: string;
  end;
  TFilterItemUpdates = TArray<TFilterItemUpdate>;

procedure ShowFontSettingsError(const MessageText: string);
begin
  MessageDlg(MessageText, mtError, [mbOK], 0);
end;

procedure AddFilterItemUpdate(var Updates: TFilterItemUpdates;
  const Name, OldValue, NewValue: string);
var
  Index: Integer;
begin
  if OldValue = NewValue then
    Exit;
  Index := Length(Updates);
  SetLength(Updates, Index + 1);
  Updates[Index].Name := Name;
  Updates[Index].OldValue := OldValue;
  Updates[Index].NewValue := NewValue;
end;

function ApplyFilterItemUpdates(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  const Updates: TFilterItemUpdates; out FailedItemName: string): Boolean;
var
  I: Integer;
  RollbackIndex: Integer;
  Utf8Value: UTF8String;
begin
  Result := False;
  FailedItemName := '';
  for I := 0 to High(Updates) do
  begin
    Utf8Value := UTF8String(Updates[I].NewValue);
    if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
      PWideChar(Updates[I].Name), PAnsiChar(Utf8Value)) then
    begin
      FailedItemName := Updates[I].Name;
      for RollbackIndex := I - 1 downto 0 do
      begin
        Utf8Value := UTF8String(Updates[RollbackIndex].OldValue);
        Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
          PWideChar(Updates[RollbackIndex].Name), PAnsiChar(Utf8Value));
      end;
      Exit;
    end;
  end;
  Result := True;
end;

function FilterColorText(Color: TColor): string;
var
  RgbColor: COLORREF;
begin
  RgbColor := ColorToRGB(Color);
  Result := LowerCase(Format('%.2x%.2x%.2x', [
    GetRValue(RgbColor), GetGValue(RgbColor), GetBValue(RgbColor)]));
end;

function StyleFlagText(Style: Byte; Mask: Byte): string;
begin
  if (Style and Mask) <> 0 then
    Result := '1'
  else
    Result := '0';
end;

procedure DisplaySettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
begin
  if PlacementModeItem.Value = PLACEMENT_MODE_FREE then
    CharacterLayoutSettingsButtonCallback(Edit)
  else
    LineDisplaySettingsButtonCallback(Edit);
end;

procedure LineDisplaySettingsButtonCallback(
  Edit: PEDIT_SECTION); cdecl;
var
  BackgroundHeight: Integer;
  BackgroundPixels: TBytes;
  BackgroundStatus: string;
  BackgroundWidth: Integer;
  CurrentBaseFontName: string;
  CurrentBaseFontStyle: Byte;
  CurrentLyrics: string;
  CurrentRubyFontName: string;
  CurrentRubyFontStyle: Byte;
  FailedItemName: string;
  LineDisplayForm: TFormLyricsLineDisplaySettings;
  Obj: OBJECT_HANDLE;
  SelectedAfterColor: TColor;
  SelectedBaseFontHeight: Integer;
  SelectedBaseCharacterSpacing: Integer;
  SelectedBaseFontName: string;
  SelectedBaseFontStyle: Byte;
  SelectedBeforeColor: TColor;
  SelectedPositionX: Integer;
  SelectedPositionY: Integer;
  SelectedRubyCharacterSpacing: Integer;
  SelectedLyrics: string;
  SelectedRubyFontHeight: Integer;
  SelectedRubyFontName: string;
  SelectedRubyFontStyle: Byte;
  SelectedRubyGapAdjustment: Integer;
  Updates: TFilterItemUpdates;
begin
  try
    Obj := nil;
    if (Edit <> nil) and Assigned(Edit^.GetFocusObject) then
      Obj := Edit^.GetFocusObject();
    if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
      not Assigned(Edit^.SetObjectName) or (Obj = nil) then
    begin
      ShowFontSettingsError(
        '1行表示設定を反映する対象オブジェクトを取得できませんでした。');
      Exit;
    end;

    CurrentLyrics := '';
    if Assigned(LyricsItem.Value) then
      CurrentLyrics := string(LyricsItem.Value);
    CurrentBaseFontName := 'Yu Gothic UI';
    if Assigned(BaseFontItem.Value) then
      CurrentBaseFontName := string(BaseFontItem.Value);
    CurrentRubyFontName := CurrentBaseFontName;
    if Assigned(RubyFontItem.Value) then
      CurrentRubyFontName := string(RubyFontItem.Value);
    CurrentBaseFontStyle := Byte(Ord(BaseBoldItem.Value <> 0) or
      (Ord(BaseItalicItem.Value <> 0) shl 1) or
      (Ord(BaseUnderlineItem.Value <> 0) shl 2) or
      (Ord(BaseStrikeOutItem.Value <> 0) shl 3));
    CurrentRubyFontStyle := Byte(Ord(RubyBoldItem.Value <> 0) or
      (Ord(RubyItalicItem.Value <> 0) shl 1) or
      (Ord(RubyUnderlineItem.Value <> 0) shl 2) or
      (Ord(RubyStrikeOutItem.Value <> 0) shl 3));
    LineDisplayForm := TFormLyricsLineDisplaySettings.Create(nil);
    try
      if CopyLastFrame(BackgroundPixels, BackgroundWidth,
        BackgroundHeight, BackgroundStatus) then
        LineDisplayForm.SetBackgroundRgba(BackgroundPixels,
          BackgroundWidth, BackgroundHeight);
      LineDisplayForm.Configure(CurrentLyrics, CurrentBaseFontName,
        CurrentRubyFontName, Round(BaseFontSizeItem.Value),
        Round(RubyFontSizeItem.Value), Round(RubyGapAdjustmentItem.Value),
        Round(BaseCharacterSpacingItem.Value),
        Round(RubyCharacterSpacingItem.Value), Round(PositionXItem.Value),
        Round(PositionYItem.Value),
        RGB(BeforeColorItem.R, BeforeColorItem.G, BeforeColorItem.B),
        RGB(AfterColorItem.R, AfterColorItem.G, AfterColorItem.B),
        CurrentBaseFontStyle, CurrentRubyFontStyle);
      if LineDisplayForm.ShowModal <> mrOk then
        Exit;
      SelectedLyrics := LineDisplayForm.EnteredLyrics;
      SelectedBaseFontName := LineDisplayForm.SelectedBaseFontName;
      SelectedRubyFontName := LineDisplayForm.SelectedRubyFontName;
      SelectedBaseFontStyle := LineDisplayForm.SelectedBaseFontStyle;
      SelectedRubyFontStyle := LineDisplayForm.SelectedRubyFontStyle;
      SelectedBaseFontHeight := LineDisplayForm.SelectedBaseFontHeight;
      SelectedBaseCharacterSpacing :=
        LineDisplayForm.SelectedBaseCharacterSpacing;
      SelectedRubyFontHeight := LineDisplayForm.SelectedRubyFontHeight;
      SelectedRubyCharacterSpacing :=
        LineDisplayForm.SelectedRubyCharacterSpacing;
      SelectedRubyGapAdjustment :=
        LineDisplayForm.SelectedRubyGapAdjustment;
      SelectedPositionX := LineDisplayForm.SelectedPositionX;
      SelectedPositionY := LineDisplayForm.SelectedPositionY;
      SelectedBeforeColor := LineDisplayForm.SelectedBeforeColor;
      SelectedAfterColor := LineDisplayForm.SelectedAfterColor;
    finally
      LineDisplayForm.Free;
    end;

    AddFilterItemUpdate(Updates, '歌詞', CurrentLyrics, SelectedLyrics);
    AddFilterItemUpdate(Updates, BASE_FONT_ITEM_NAME, CurrentBaseFontName,
      SelectedBaseFontName);
    AddFilterItemUpdate(Updates, RUBY_FONT_ITEM_NAME, CurrentRubyFontName,
      SelectedRubyFontName);
    AddFilterItemUpdate(Updates, '太字',
      StyleFlagText(CurrentBaseFontStyle, 1),
      StyleFlagText(SelectedBaseFontStyle, 1));
    AddFilterItemUpdate(Updates, '斜体',
      StyleFlagText(CurrentBaseFontStyle, 2),
      StyleFlagText(SelectedBaseFontStyle, 2));
    AddFilterItemUpdate(Updates, '下線',
      StyleFlagText(CurrentBaseFontStyle, 4),
      StyleFlagText(SelectedBaseFontStyle, 4));
    AddFilterItemUpdate(Updates, '取り消し線',
      StyleFlagText(CurrentBaseFontStyle, 8),
      StyleFlagText(SelectedBaseFontStyle, 8));
    AddFilterItemUpdate(Updates, '太字（ルビ）',
      StyleFlagText(CurrentRubyFontStyle, 1),
      StyleFlagText(SelectedRubyFontStyle, 1));
    AddFilterItemUpdate(Updates, '斜体（ルビ）',
      StyleFlagText(CurrentRubyFontStyle, 2),
      StyleFlagText(SelectedRubyFontStyle, 2));
    AddFilterItemUpdate(Updates, '下線（ルビ）',
      StyleFlagText(CurrentRubyFontStyle, 4),
      StyleFlagText(SelectedRubyFontStyle, 4));
    AddFilterItemUpdate(Updates, '取り消し線（ルビ）',
      StyleFlagText(CurrentRubyFontStyle, 8),
      StyleFlagText(SelectedRubyFontStyle, 8));
    AddFilterItemUpdate(Updates, '歌詞サイズ',
      IntToStr(Round(BaseFontSizeItem.Value)),
      IntToStr(SelectedBaseFontHeight));
    AddFilterItemUpdate(Updates, 'ルビサイズ',
      IntToStr(Round(RubyFontSizeItem.Value)),
      IntToStr(SelectedRubyFontHeight));
    AddFilterItemUpdate(Updates, 'ルビ間隔補正',
      IntToStr(Round(RubyGapAdjustmentItem.Value)),
      IntToStr(SelectedRubyGapAdjustment));
    AddFilterItemUpdate(Updates, '字間',
      IntToStr(Round(BaseCharacterSpacingItem.Value)),
      IntToStr(SelectedBaseCharacterSpacing));
    AddFilterItemUpdate(Updates, '字間（ルビ）',
      IntToStr(Round(RubyCharacterSpacingItem.Value)),
      IntToStr(SelectedRubyCharacterSpacing));
    AddFilterItemUpdate(Updates, 'X', IntToStr(Round(PositionXItem.Value)),
      IntToStr(SelectedPositionX));
    AddFilterItemUpdate(Updates, 'Y', IntToStr(Round(PositionYItem.Value)),
      IntToStr(SelectedPositionY));
    AddFilterItemUpdate(Updates, '変化前色',
      FilterColorText(RGB(BeforeColorItem.R, BeforeColorItem.G,
        BeforeColorItem.B)), FilterColorText(SelectedBeforeColor));
    AddFilterItemUpdate(Updates, '変化後色',
      FilterColorText(RGB(AfterColorItem.R, AfterColorItem.G,
        AfterColorItem.B)), FilterColorText(SelectedAfterColor));
    if not ApplyFilterItemUpdates(Edit, Obj, Updates, FailedItemName) then
    begin
      ShowFontSettingsError('「' + FailedItemName +
        '」を歌詞テロップへ反映できませんでした。');
      Exit;
    end;
    Edit^.SetObjectName(Obj, PWideChar(SelectedLyrics));
  except
    on E: Exception do
      ShowFontSettingsError(
        '1行表示設定の反映中にエラーが発生しました: ' + E.Message);
  end;
end;

procedure CharacterLayoutSettingsButtonCallback(
  Edit: PEDIT_SECTION); cdecl;
var
  BackgroundHeight: Integer;
  BackgroundPixels: TBytes;
  BackgroundStatus: string;
  BackgroundWidth: Integer;
  CurrentBaseFontName: string;
  CurrentSettingsText: string;
  CurrentLyrics: string;
  CurrentRubyFontName: string;
  CharacterLayoutForm: TFormLyricsCharacterLayoutSettings;
  EncodedSettingsText: string;
  Obj: OBJECT_HANDLE;
  Utf8SettingsText: UTF8String;
begin
  if PlacementModeItem.Value <> PLACEMENT_MODE_FREE then
  begin
    MessageDlg('表示設定は「文字自由配置」で使用できます。',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  CurrentSettingsText := '';
  if Assigned(DisplaySettingsTextItem.Value) then
    CurrentSettingsText := string(DisplaySettingsTextItem.Value);
  CurrentLyrics := '';
  if Assigned(LyricsItem.Value) then
    CurrentLyrics := string(LyricsItem.Value);
  CurrentBaseFontName := 'Yu Gothic UI';
  if Assigned(BaseFontItem.Value) then
    CurrentBaseFontName := string(BaseFontItem.Value);
  CurrentRubyFontName := CurrentBaseFontName;
  if Assigned(RubyFontItem.Value) then
    CurrentRubyFontName := string(RubyFontItem.Value);

  CharacterLayoutForm := TFormLyricsCharacterLayoutSettings.Create(nil);
  try
    if CopyLastFrame(BackgroundPixels, BackgroundWidth,
      BackgroundHeight, BackgroundStatus) then
      CharacterLayoutForm.SetBackgroundRgba(BackgroundPixels,
        BackgroundWidth, BackgroundHeight);
    CharacterLayoutForm.SetCaptureStatus(BackgroundStatus);
    CharacterLayoutForm.Configure(CurrentLyrics, CurrentBaseFontName,
      CurrentRubyFontName, Round(BaseFontSizeItem.Value),
      Round(RubyFontSizeItem.Value), Round(RubyGapAdjustmentItem.Value),
      BeforeColorItem.R or (Cardinal(BeforeColorItem.G) shl 8) or
        (Cardinal(BeforeColorItem.B) shl 16),
      AfterColorItem.R or (Cardinal(AfterColorItem.G) shl 8) or
        (Cardinal(AfterColorItem.B) shl 16),
      Byte(Ord(BaseBoldItem.Value <> 0) or
        (Ord(BaseItalicItem.Value <> 0) shl 1) or
        (Ord(BaseUnderlineItem.Value <> 0) shl 2) or
        (Ord(BaseStrikeOutItem.Value <> 0) shl 3)),
      Byte(Ord(RubyBoldItem.Value <> 0) or
        (Ord(RubyItalicItem.Value <> 0) shl 1) or
        (Ord(RubyUnderlineItem.Value <> 0) shl 2) or
        (Ord(RubyStrikeOutItem.Value <> 0) shl 3)),
      CurrentSettingsText);
    if CharacterLayoutForm.ShowModal <> mrOk then
      Exit;
    if not CharacterLayoutForm.TryBuildSettingsText(EncodedSettingsText) then
    begin
      ShowFontSettingsError(
        '表示設定を文字列へ変換できませんでした。');
      Exit;
    end;
  finally
    CharacterLayoutForm.Free;
  end;

  Obj := nil;
  if (Edit <> nil) and Assigned(Edit^.GetFocusObject) then
    Obj := Edit^.GetFocusObject();
  if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
    (Obj = nil) then
  begin
    ShowFontSettingsError(
      '表示設定を反映する対象オブジェクトを取得できませんでした。');
    Exit;
  end;
  Utf8SettingsText := UTF8String(EncodedSettingsText);
  if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
    '表示設定', PAnsiChar(Utf8SettingsText)) then
    ShowFontSettingsError('表示設定を歌詞テロップへ反映できませんでした。');
end;

procedure MusicSyncSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  Anchor: TMusicSyncAnchor;
  AudioInfo: TSyncAudioFileInfo;
  AudioProbeError: string;
  CurrentLyrics: string;
  CurrentMusicFileName: string;
  CurrentPreDisplaySeconds: Double;
  CurrentSyncText: string;
  LyricsChanged: Boolean;
  ManualSyncForm: TFormLyricsManualSyncSettings;
  Obj: OBJECT_HANDLE;
  ObjectLayerFrame: TOBJECT_LAYER_FRAME;
  SelectedLyrics: string;
  SelectedPreDisplaySeconds: Double;
  SelectedSyncText: string;
  PreDisplayChanged: Boolean;
  SyncChanged: Boolean;
  SyncForm: TFormLyricsMusicSyncSettings;
  Utf8Lyrics: UTF8String;
  Utf8OriginalLyrics: UTF8String;
  Utf8OriginalPreDisplay: UTF8String;
  Utf8OriginalSyncText: UTF8String;
  Utf8PreDisplay: UTF8String;
  Utf8SyncText: UTF8String;
begin
  Obj := nil;
  if (Edit <> nil) and Assigned(Edit^.GetFocusObject) then
    Obj := Edit^.GetFocusObject();

  CurrentLyrics := '';
  if Assigned(LyricsItem.Value) then
    CurrentLyrics := string(LyricsItem.Value);
  CurrentMusicFileName := '';
  if Assigned(MusicFileItem.Value) then
    CurrentMusicFileName := string(MusicFileItem.Value);
  CurrentSyncText := DEFAULT_MUSIC_SYNC_TEXT;
  if Assigned(SyncDataItem.Value) then
    CurrentSyncText := string(SyncDataItem.Value);
  if not IsMusicScoreFileName(CurrentMusicFileName) then
  begin
    if not TryProbeSyncAudioFile(CurrentMusicFileName,
      AudioInfo, AudioProbeError) then
    begin
      ShowFontSettingsError(AudioProbeError);
      Exit;
    end;
    ManualSyncForm := TFormLyricsManualSyncSettings.Create(nil);
    try
      ManualSyncForm.LoadSettings(CurrentMusicFileName, AudioInfo,
        CurrentLyrics, CurrentSyncText);
      if ManualSyncForm.ShowModal <> mrOk then
        Exit;
      SelectedLyrics := ManualSyncForm.LyricsText;
      SelectedSyncText := ManualSyncForm.SyncText;
    finally
      ManualSyncForm.Free;
    end;
    LyricsChanged := SelectedLyrics <> CurrentLyrics;
    SyncChanged := SelectedSyncText <> CurrentSyncText;
    if not LyricsChanged and not SyncChanged then
      Exit;
    if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
      (Obj = nil) then
    begin
      ShowFontSettingsError(
        '手動同期設定を反映する対象オブジェクトを取得できませんでした。');
      Exit;
    end;
    if LyricsChanged then
    begin
      Utf8Lyrics := UTF8String(SelectedLyrics);
      if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
        '歌詞', PAnsiChar(Utf8Lyrics)) then
      begin
        ShowFontSettingsError(
          '歌詞を歌詞テロップへ反映できませんでした。');
        Exit;
      end;
    end;
    if SyncChanged then
    begin
      Utf8SyncText := UTF8String(SelectedSyncText);
      if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
        '同期データ', PAnsiChar(Utf8SyncText)) then
      begin
        if LyricsChanged then
        begin
          Utf8OriginalLyrics := UTF8String(CurrentLyrics);
          Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
            '歌詞', PAnsiChar(Utf8OriginalLyrics));
        end;
        ShowFontSettingsError(
          '手動同期データを歌詞テロップへ反映できませんでした。');
      end;
    end;
    Exit;
  end;
  CurrentPreDisplaySeconds := Max(0.0, PreDisplayTimeItem.Value);

  SyncForm := TFormLyricsMusicSyncSettings.Create(nil);
  try
    if (Obj <> nil) and Assigned(Edit^.GetObjectLayerFrame) then
    begin
      ObjectLayerFrame := Edit^.GetObjectLayerFrame(Obj);
      if TryGetMusicSyncAnchor(ObjectLayerFrame.Layer,
        ObjectLayerFrame.StartFrame, ObjectLayerFrame.EndFrame, Anchor) then
        SyncForm.SetAnchor(Anchor.Frame, Anchor.Rate, Anchor.Scale)
      else
        SyncForm.SetAnchorUnavailable;
    end
    else
      SyncForm.SetAnchorUnavailable;
    SyncForm.LoadSettings(CurrentMusicFileName, Round(TrackItem.Value),
      Max(0.0, PreDisplayTimeItem.Value), CurrentLyrics, CurrentSyncText);
    if SyncForm.ShowModal <> mrOk then
      Exit;
    SelectedLyrics := SyncForm.LyricsText;
    SelectedPreDisplaySeconds := SyncForm.PreDisplaySeconds;
    SelectedSyncText := SyncForm.SyncText;
  finally
    SyncForm.Free;
  end;

  LyricsChanged := SelectedLyrics <> CurrentLyrics;
  PreDisplayChanged :=
    Abs(SelectedPreDisplaySeconds - CurrentPreDisplaySeconds) >= 0.005;
  SyncChanged := SelectedSyncText <> CurrentSyncText;
  if not LyricsChanged and not SyncChanged and not PreDisplayChanged then
    Exit;
  if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or
    not Assigned(Edit^.SetObjectItemValue) then
  begin
    ShowFontSettingsError('歌詞を反映するための編集情報を取得できませんでした。');
    Exit;
  end;
  if Obj = nil then
  begin
    ShowFontSettingsError('対象の歌詞テロップオブジェクトを取得できませんでした。');
    Exit;
  end;
  if LyricsChanged then
  begin
    Utf8Lyrics := UTF8String(SelectedLyrics);
    if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
      '歌詞', PAnsiChar(Utf8Lyrics)) then
    begin
      ShowFontSettingsError('歌詞を歌詞テロップへ反映できませんでした。');
      Exit;
    end;
  end;
  if SyncChanged then
  begin
    Utf8SyncText := UTF8String(SelectedSyncText);
    if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
      '同期データ', PAnsiChar(Utf8SyncText)) then
    begin
      if LyricsChanged then
      begin
        Utf8OriginalLyrics := UTF8String(CurrentLyrics);
        Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
          '歌詞', PAnsiChar(Utf8OriginalLyrics));
      end;
      ShowFontSettingsError('同期データを歌詞テロップへ反映できませんでした。');
      Exit;
    end;
  end;
  if PreDisplayChanged then
  begin
    Utf8PreDisplay := UTF8String(FormatFloat('0.00',
      SelectedPreDisplaySeconds, TFormatSettings.Invariant));
    if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
      '事前表示 (秒)', PAnsiChar(Utf8PreDisplay)) then
    begin
      if SyncChanged then
      begin
        Utf8OriginalSyncText := UTF8String(CurrentSyncText);
        Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
          '同期データ', PAnsiChar(Utf8OriginalSyncText));
      end;
      if LyricsChanged then
      begin
        Utf8OriginalLyrics := UTF8String(CurrentLyrics);
        Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
          '歌詞', PAnsiChar(Utf8OriginalLyrics));
      end;
      Utf8OriginalPreDisplay := UTF8String(FormatFloat('0.00',
        CurrentPreDisplaySeconds, TFormatSettings.Invariant));
      Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
        '事前表示 (秒)', PAnsiChar(Utf8OriginalPreDisplay));
      ShowFontSettingsError('事前表示時間を歌詞テロップへ反映できませんでした。');
    end;
  end;
end;

procedure FontSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  BaseChanged: Boolean;
  CurrentBaseFontName: string;
  CurrentRubyFontName: string;
  EffectCount: Integer;
  FontForm: TFormLyricsFontSettings;
  Obj: OBJECT_HANDLE;
  RubyChanged: Boolean;
  SelectedBaseFontName: string;
  SelectedRubyFontName: string;
  Utf8BaseFontName: UTF8String;
  Utf8CurrentBaseFontName: UTF8String;
  Utf8RubyFontName: UTF8String;
begin
  if Edit = nil then
    Exit;
  if not Assigned(Edit^.GetFocusObject) or
    not Assigned(Edit^.SetObjectItemValue) then
  begin
    ShowFontSettingsError('AviUtl2の編集情報を取得できませんでした。');
    Exit;
  end;

  Obj := Edit^.GetFocusObject();
  if Obj = nil then
  begin
    ShowFontSettingsError('対象の歌詞テロップオブジェクトを取得できませんでした。');
    Exit;
  end;

  if Assigned(Edit^.CountObjectEffect) then
  begin
    EffectCount := Edit^.CountObjectEffect(Obj, FILTER_EFFECT_NAME);
    if EffectCount <> 1 then
    begin
      ShowFontSettingsError(
        '同じオブジェクト内の歌詞テロップFilterを一意に特定できませんでした。');
      Exit;
    end;
  end;

  if Assigned(BaseFontItem.Value) then
    CurrentBaseFontName := string(BaseFontItem.Value)
  else
    CurrentBaseFontName := '';
  if Assigned(RubyFontItem.Value) then
    CurrentRubyFontName := string(RubyFontItem.Value)
  else
    CurrentRubyFontName := '';

  FontForm := TFormLyricsFontSettings.Create(nil);
  try
    FontForm.SelectedBaseFontName := CurrentBaseFontName;
    FontForm.SelectedRubyFontName := CurrentRubyFontName;
    if FontForm.ShowModal <> mrOk then
      Exit;
    SelectedBaseFontName := FontForm.SelectedBaseFontName;
    SelectedRubyFontName := FontForm.SelectedRubyFontName;
  finally
    FontForm.Free;
  end;

  if (SelectedBaseFontName = '') or (SelectedRubyFontName = '') then
    Exit;
  BaseChanged := not SameText(CurrentBaseFontName, SelectedBaseFontName);
  RubyChanged := not SameText(CurrentRubyFontName, SelectedRubyFontName);
  if not BaseChanged and not RubyChanged then
    Exit;

  if BaseChanged then
  begin
    Utf8BaseFontName := UTF8String(SelectedBaseFontName);
    if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
      BASE_FONT_ITEM_NAME, PAnsiChar(Utf8BaseFontName)) then
    begin
      ShowFontSettingsError('本文用フォントを歌詞テロップへ反映できませんでした。');
      Exit;
    end;
  end;

  if RubyChanged then
  begin
    Utf8RubyFontName := UTF8String(SelectedRubyFontName);
    if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
      RUBY_FONT_ITEM_NAME, PAnsiChar(Utf8RubyFontName)) then
    begin
      if BaseChanged then
      begin
        Utf8CurrentBaseFontName := UTF8String(CurrentBaseFontName);
        Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
          BASE_FONT_ITEM_NAME, PAnsiChar(Utf8CurrentBaseFontName));
      end;
      ShowFontSettingsError('ルビ用フォントを歌詞テロップへ反映できませんでした。');
    end;
  end;
end;

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  AnimationOffsetY: Integer;
  AnimationOpacity: Double;
  AnimationSettings: TLyricsAnimationSettings;
  DisplayUnitCount: Integer;
  FrameState: TSyncLyricsFrameState;
  HasFreePlacement: Boolean;
  LyricsText: string;
  MusicFileName: string;
  LocalSeconds: Double;
  ObjectStartFrame: Integer;
  ObjectStartSeconds: Double;
  RenderSettings: TLyricsRenderSettings;
  RemainingSeconds: Double;
  PlacementItems: TDisplayPlacementItems;
  PlacementPlainText: string;
  PlacementRubySpans: TLyricsRubySpans;
  PlacementUnits: TLyricsDisplayUnits;
  SyncData: TSyncTextData;
  SyncStartSeconds: Double;
  SyncProgress: Double;
  Track: Integer;
  SelectedPlacementMode: Integer;
begin
  try
    CaptureLastFrame(Video);
    AnimationOffsetY := 0;
    AnimationOpacity := 1;
    RenderSettings := DefaultLyricsRenderSettings;
    SelectedPlacementMode := EnsureRange(PlacementModeItem.Value,
      PLACEMENT_MODE_LINE, PLACEMENT_MODE_FREE);
    RenderSettings.DisplayType := TLyricsDisplayType(
      EnsureRange(DisplayEffectItem.Value,
        Ord(Low(TLyricsDisplayType)), Ord(High(TLyricsDisplayType))));
    if Assigned(BaseFontItem.Value) then
      RenderSettings.BaseFontName := string(BaseFontItem.Value);
    if Assigned(RubyFontItem.Value) then
      RenderSettings.RubyFontName := string(RubyFontItem.Value);
    RenderSettings.BaseBold := BaseBoldItem.Value <> 0;
    RenderSettings.BaseItalic := BaseItalicItem.Value <> 0;
    RenderSettings.BaseUnderline := BaseUnderlineItem.Value <> 0;
    RenderSettings.BaseStrikeOut := BaseStrikeOutItem.Value <> 0;
    RenderSettings.RubyBold := RubyBoldItem.Value <> 0;
    RenderSettings.RubyItalic := RubyItalicItem.Value <> 0;
    RenderSettings.RubyUnderline := RubyUnderlineItem.Value <> 0;
    RenderSettings.RubyStrikeOut := RubyStrikeOutItem.Value <> 0;
    RenderSettings.BaseFontHeight := Round(BaseFontSizeItem.Value);
    RenderSettings.RubyFontHeight := Round(RubyFontSizeItem.Value);
    RenderSettings.RubyGapAdjustment := Round(RubyGapAdjustmentItem.Value);
    RenderSettings.BaseCharacterSpacing := Round(BaseCharacterSpacingItem.Value);
    RenderSettings.RubyCharacterSpacing :=
      Round(RubyCharacterSpacingItem.Value);
    RenderSettings.BeforeColor.R := BeforeColorItem.R;
    RenderSettings.BeforeColor.G := BeforeColorItem.G;
    RenderSettings.BeforeColor.B := BeforeColorItem.B;
    RenderSettings.AfterColor.R := AfterColorItem.R;
    RenderSettings.AfterColor.G := AfterColorItem.G;
    RenderSettings.AfterColor.B := AfterColorItem.B;
    LyricsText := '';
    if Assigned(LyricsItem.Value) then
      LyricsText := string(LyricsItem.Value);
    HasFreePlacement := False;
    if SelectedPlacementMode = PLACEMENT_MODE_FREE then
    begin
      ParseLyrics(LyricsText, PlacementPlainText, PlacementRubySpans);
      BuildLyricsDisplayUnits(PlacementPlainText, PlacementRubySpans,
        PlacementUnits);
      if Assigned(DisplaySettingsTextItem.Value) then
        HasFreePlacement := TryDecodeDisplayPlacementsText(
          string(DisplaySettingsTextItem.Value), LyricsText,
          Length(PlacementUnits), PlacementItems);
    end;
    DisplayUnitCount := CountLyricsDisplayUnits(LyricsText);
    SyncProgress := 0;
    if TryGetLyricsFrameState(Video, FrameState) then
    begin
      MusicFileName := '';
      if Assigned(MusicFileItem.Value) then
        MusicFileName := string(MusicFileItem.Value);
      Track := Round(TrackItem.Value);
      ObjectStartSeconds := FrameState.TimeSeconds;
      if (Video <> nil) and (Video^.Object_ <> nil) and (FrameState.Rate > 0) then
      begin
        ObjectStartFrame := FrameState.Frame - Video^.Object_^.Frame;
        ObjectStartSeconds := ObjectStartSeconds -
          Video^.Object_^.Frame * FrameState.Scale / FrameState.Rate;
        RecordMusicSyncAnchor(Video^.Object_^.ID, Video^.Object_^.EffectID,
          Video^.Object_^.Layer, Video^.Object_^.FrameS,
          Video^.Object_^.FrameE, ObjectStartFrame, FrameState.Rate,
          FrameState.Scale);
      end;
      SyncStartSeconds := ObjectStartSeconds +
        Max(0.0, PreDisplayTimeItem.Value);
      if Assigned(SyncDataItem.Value) and
        TryParseSyncText(string(SyncDataItem.Value), SyncData) then
        case SyncData.Mode of
          smMusic:
            ResolveAdjustedMusicSyncProgress(MusicFileName, Track,
              SyncStartSeconds, FrameState.TimeSeconds, DisplayUnitCount,
              SyncData.MusicStages, SyncProgress);
          smManual:
            ResolveManualSyncProgress(FrameState.TimeSeconds,
              DisplayUnitCount, SyncData.ManualBoundaries, SyncProgress);
        end;
      if (Video <> nil) and (Video^.Object_ <> nil) and
        (FrameState.Rate > 0) then
      begin
        LocalSeconds := Video^.Object_^.Frame *
          FrameState.Scale / FrameState.Rate;
        RemainingSeconds := Max(0,
          Video^.Object_^.FrameTotal - 1 - Video^.Object_^.Frame) *
          FrameState.Scale / FrameState.Rate;
        AnimationSettings.SyncAnimation := TLyricsSyncAnimation(
          EnsureRange(SyncAnimationItem.Value,
            Ord(Low(TLyricsSyncAnimation)),
            Ord(High(TLyricsSyncAnimation))));
        AnimationSettings.StartAnimation := TLyricsEdgeAnimation(
          EnsureRange(StartAnimationItem.Value,
            Ord(Low(TLyricsEdgeAnimation)),
            Ord(High(TLyricsEdgeAnimation))));
        AnimationSettings.EndAnimation := TLyricsEdgeAnimation(
          EnsureRange(EndAnimationItem.Value,
            Ord(Low(TLyricsEdgeAnimation)),
            Ord(High(TLyricsEdgeAnimation))));
        AnimationSettings.StartDurationSeconds :=
          Max(0.01, StartAnimationTimeItem.Value);
        AnimationSettings.EndDurationSeconds :=
          Max(0.01, EndAnimationTimeItem.Value);
        AnimationSettings.BaseFontHeight :=
          RenderSettings.BaseFontHeight;
        ResolveLyricsAnimation(AnimationSettings, LocalSeconds,
          RemainingSeconds, SyncProgress, AnimationOpacity,
          AnimationOffsetY);
      end;
    end;
    RenderSettings.Opacity := AnimationOpacity;
    if HasFreePlacement then
      RenderFreePlacementLyrics(Video, PWideChar(LyricsText), SyncProgress,
        RenderSettings, PlacementItems, Round(PositionXItem.Value),
        Round(PositionYItem.Value) + AnimationOffsetY)
    else
      RenderLyrics(Video, PWideChar(LyricsText), SyncProgress,
        RenderSettings, Round(PositionXItem.Value),
        Round(PositionYItem.Value) + AnimationOffsetY);
  except
    // Delphi例外をAviUtl2のコールバック境界より外へ漏らさない。
  end;
  Result := 1;
end;

function GetLyricsFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if Plugin.Items = nil then
  begin
    // AviUtl2はnil終端された項目ポインター配列を参照する。
    PluginItems[0] := @MusicSyncSettingsButton;
    PluginItems[1] := @LyricsItem;
    PluginItems[2] := @MusicFileItem;
    PluginItems[3] := @TrackItem;
    PluginItems[4] := @PositionXItem;
    PluginItems[5] := @PositionYItem;
    PluginItems[6] := @FontSettingsButton;
    PluginItems[7] := @BaseFontItem;
    PluginItems[8] := @BaseBoldItem;
    PluginItems[9] := @BaseItalicItem;
    PluginItems[10] := @BaseUnderlineItem;
    PluginItems[11] := @BaseStrikeOutItem;
    PluginItems[12] := @RubyFontItem;
    PluginItems[13] := @RubyBoldItem;
    PluginItems[14] := @RubyItalicItem;
    PluginItems[15] := @RubyUnderlineItem;
    PluginItems[16] := @RubyStrikeOutItem;
    PluginItems[17] := @BeforeColorItem;
    PluginItems[18] := @AfterColorItem;
    PluginItems[19] := @PlacementModeItem;
    PluginItems[20] := @DisplayEffectItem;
    PluginItems[21] := @DisplaySettingsButton;
    PluginItems[22] := @SyncAnimationItem;
    PluginItems[23] := @StartAnimationItem;
    PluginItems[24] := @StartAnimationTimeItem;
    PluginItems[25] := @EndAnimationItem;
    PluginItems[26] := @EndAnimationTimeItem;
    PluginItems[27] := @BaseFontSizeItem;
    PluginItems[28] := @RubyFontSizeItem;
    PluginItems[29] := @RubyGapAdjustmentItem;
    PluginItems[30] := @BaseCharacterSpacingItem;
    PluginItems[31] := @RubyCharacterSpacingItem;
    PluginItems[32] := @PreDisplayTimeItem;
    PluginItems[33] := @SyncDataItem;
    PluginItems[34] := @DisplaySettingsTextItem;
    PluginItems[35] := nil;
    Plugin.Items := @PluginItems[0];
  end;
  Result := @Plugin;
end;

procedure InitializeLyricsFilter;
begin
  InitializeLastFrameCapture;
  InitializeLyricsFrameShared;
  InitializeLyricsContexts;
  InitializeMusicSyncAnchor;
  InitializeMusicSync;
  InitializeLyricsRenderer;
end;

procedure FinalizeLyricsFilter;
begin
  FinalizeLyricsRenderer;
  FinalizeMusicSync;
  FinalizeMusicSyncAnchor;
  FinalizeLyricsContexts;
  FinalizeLyricsFrameShared;
  FinalizeLastFrameCapture;
end;

end.
