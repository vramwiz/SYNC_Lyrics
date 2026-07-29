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
  SYNC_Lyrics_DisplaySettingsDebugForm,
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
  SYNC_Lyrics_Animation,
  SYNC_Lyrics_Renderer,
  SYNC_Lyrics_SyncSourceKind,
  SYNC_Lyrics_SyncFormat,
  SYNC_Lyrics_Time,
  Vcl.Dialogs,
  Vcl.Forms;

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl; forward;
procedure FontSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
procedure MusicSyncSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
procedure DisplaySettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;

type
  TDisplaySettingsDataItem = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Value: PDisplaySettingsData;
    Size: Integer;
    DefaultValue: TDisplaySettingsData;
  end;

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
  DisplayTypeList: array[0..4] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '通常カラオケ'; Value: 0),
    (Name: '文字単位強調'; Value: 1),
    (Name: '1文字ずつ出現'; Value: 2),
    (Name: '文字自由配置'; Value: 3),
    (Name: nil; Value: 0)
  );
  DisplayTypeItem: TFILTER_ITEM_SELECT = (
    ItemType: 'select';
    Name: 'タイプ';
    Value: 0;
    List: @DisplayTypeList[0]
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
    Name: '同期演出';
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
  DisplaySettingsDataItem: TDisplaySettingsDataItem;
  PluginItems: array[0..33] of Pointer;
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
  DISPLAY_MODE_FREE_PLACEMENT = 3;

procedure ShowFontSettingsError(const MessageText: string);
begin
  MessageDlg(MessageText, mtError, [mbOK], 0);
end;

procedure DisplaySettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  BackgroundHeight: Integer;
  BackgroundPixels: TBytes;
  BackgroundStatus: string;
  BackgroundWidth: Integer;
  CurrentText: string;
  DisplayForm: TFormLyricsDisplaySettingsDebug;
  EncodedData: TDisplaySettingsData;
begin
  if DisplayTypeItem.Value <> DISPLAY_MODE_FREE_PLACEMENT then
  begin
    MessageDlg('表示設定は「文字自由配置」で使用できます。',
      mtInformation, [mbOK], 0);
    Exit;
  end;

  CurrentText := '';
  if (DisplaySettingsDataItem.Value <> nil) and
    (DisplaySettingsDataItem.Size = SizeOf(TDisplaySettingsData)) then
    CurrentText := DecodeDisplaySettingsText(
      DisplaySettingsDataItem.Value^);

  DisplayForm := TFormLyricsDisplaySettingsDebug.Create(nil);
  try
    if CopyLastFrame(BackgroundPixels, BackgroundWidth,
      BackgroundHeight, BackgroundStatus) then
      DisplayForm.SetBackgroundRgba(BackgroundPixels,
        BackgroundWidth, BackgroundHeight);
    DisplayForm.SetCaptureStatus(BackgroundStatus);
    DisplayForm.SetSettingsText(CurrentText);
    if DisplayForm.ShowModal <> mrOk then
      Exit;
    if not TryEncodeDisplaySettingsText(
      DisplayForm.SettingsText, EncodedData) then
    begin
      ShowFontSettingsError(
        '表示設定データが保存可能なサイズを超えています。');
      Exit;
    end;
  finally
    DisplayForm.Free;
  end;

  if (DisplaySettingsDataItem.Value = nil) or
    (DisplaySettingsDataItem.Size <> SizeOf(TDisplaySettingsData)) then
  begin
    ShowFontSettingsError(
      '表示設定データの保存領域を取得できませんでした。');
    Exit;
  end;
  DisplaySettingsDataItem.Value^ := EncodedData;
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
  LyricsText: string;
  MusicFileName: string;
  LocalSeconds: Double;
  ObjectStartFrame: Integer;
  ObjectStartSeconds: Double;
  RenderSettings: TLyricsRenderSettings;
  RemainingSeconds: Double;
  SyncData: TSyncTextData;
  SyncStartSeconds: Double;
  SyncProgress: Double;
  Track: Integer;
  SelectedDisplayMode: Integer;
begin
  try
    CaptureLastFrame(Video);
    AnimationOffsetY := 0;
    AnimationOpacity := 1;
    RenderSettings := DefaultLyricsRenderSettings;
    SelectedDisplayMode := EnsureRange(DisplayTypeItem.Value, 0,
      DISPLAY_MODE_FREE_PLACEMENT);
    if SelectedDisplayMode = DISPLAY_MODE_FREE_PLACEMENT then
      RenderSettings.DisplayType := ldtKaraoke
    else
      RenderSettings.DisplayType := TLyricsDisplayType(
        SelectedDisplayMode);
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
    RenderSettings.BeforeColor.R := BeforeColorItem.R;
    RenderSettings.BeforeColor.G := BeforeColorItem.G;
    RenderSettings.BeforeColor.B := BeforeColorItem.B;
    RenderSettings.AfterColor.R := AfterColorItem.R;
    RenderSettings.AfterColor.G := AfterColorItem.G;
    RenderSettings.AfterColor.B := AfterColorItem.B;
    LyricsText := '';
    if Assigned(LyricsItem.Value) then
      LyricsText := string(LyricsItem.Value);
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
    RenderLyrics(Video, PWideChar(LyricsText), SyncProgress, RenderSettings,
      Round(PositionXItem.Value),
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
    ClearDisplaySettingsData(DisplaySettingsDataItem.DefaultValue);
    DisplaySettingsDataItem.ItemType := 'data';
    DisplaySettingsDataItem.Name := '表示設定データ';
    DisplaySettingsDataItem.Value :=
      @DisplaySettingsDataItem.DefaultValue;
    DisplaySettingsDataItem.Size := SizeOf(TDisplaySettingsData);
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
    PluginItems[19] := @DisplayTypeItem;
    PluginItems[20] := @DisplaySettingsButton;
    PluginItems[21] := @SyncAnimationItem;
    PluginItems[22] := @StartAnimationItem;
    PluginItems[23] := @StartAnimationTimeItem;
    PluginItems[24] := @EndAnimationItem;
    PluginItems[25] := @EndAnimationTimeItem;
    PluginItems[26] := @BaseFontSizeItem;
    PluginItems[27] := @RubyFontSizeItem;
    PluginItems[28] := @RubyGapAdjustmentItem;
    PluginItems[29] := @BaseCharacterSpacingItem;
    PluginItems[30] := @PreDisplayTimeItem;
    PluginItems[31] := @SyncDataItem;
    PluginItems[32] := @DisplaySettingsDataItem;
    PluginItems[33] := nil;
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
