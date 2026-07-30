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
  System.IOUtils,
  System.Math,
  System.SysUtils,
  System.UITypes,
  SYNC_Lyrics_ContextManager,
  SYNC_Lyrics_DisplayPresetData,
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_CharacterLayoutSettingsForm,
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
  Vcl.Dialogs,
  Vcl.Forms;

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl; forward;
procedure MusicSyncSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
procedure DisplaySettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
procedure PresetSaveButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
procedure PresetLoadButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
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
  PresetList: array[0..10] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'プリセット1'; Value: 0),
    (Name: 'プリセット2'; Value: 1),
    (Name: 'プリセット3'; Value: 2),
    (Name: 'プリセット4'; Value: 3),
    (Name: 'プリセット5'; Value: 4),
    (Name: 'プリセット6'; Value: 5),
    (Name: 'プリセット7'; Value: 6),
    (Name: 'プリセット8'; Value: 7),
    (Name: 'プリセット9'; Value: 8),
    (Name: 'プリセット10'; Value: 9),
    (Name: nil; Value: 0)
  );
  PresetItem: TFILTER_ITEM_SELECT = (
    ItemType: 'select';
    Name: 'プリセット';
    Value: 0;
    List: @PresetList[0]
  );
  PresetSaveButton: TFILTER_ITEM_BUTTON = (
    ItemType: 'button';
    Name: '保存';
    Callback: PresetSaveButtonCallback
  );
  PresetLoadButton: TFILTER_ITEM_BUTTON = (
    ItemType: 'button';
    Name: '読込';
    Callback: PresetLoadButtonCallback
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
  PluginItems: array[0..18] of Pointer;
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

function TryGetObjectItemText(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  const ItemName: string; out Value: string): Boolean;
var
  RawValue: PAnsiChar;
begin
  Value := '';
  Result := (Edit <> nil) and Assigned(Edit^.GetObjectItemValue) and
    (Obj <> nil);
  if not Result then
    Exit;
  RawValue := Edit^.GetObjectItemValue(Obj, FILTER_EFFECT_NAME,
    PWideChar(ItemName));
  Result := RawValue <> nil;
  if Result then
    Value := string(UTF8String(RawValue));
end;

function TryGetObjectItemInteger(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  const ItemName: string; out Value: Integer): Boolean;
var
  TextValue: string;
begin
  Result := TryGetObjectItemText(Edit, Obj, ItemName, TextValue) and
    TryStrToInt(TextValue, Value);
end;

function TryGetObjectItemFloat(Edit: PEDIT_SECTION; Obj: OBJECT_HANDLE;
  const ItemName: string; out Value: Double): Boolean;
var
  TextValue: string;
begin
  Result := TryGetObjectItemText(Edit, Obj, ItemName, TextValue) and
    TryStrToFloat(TextValue, Value, TFormatSettings.Invariant);
end;

procedure DisplaySettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
begin
  if PlacementModeItem.Value = PLACEMENT_MODE_FREE then
    CharacterLayoutSettingsButtonCallback(Edit)
  else
    LineDisplaySettingsButtonCallback(Edit);
end;

procedure PresetSaveButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  Common: TDisplayCommonSettings;
  CurrentLyrics: string;
  CurrentPlacements: TDisplayPlacementItems;
  CurrentSettingsText: string;
  DisplayEffect: Integer;
  EndAnimation: Integer;
  EndAnimationSeconds: Double;
  FileName: string;
  Obj: OBJECT_HANDLE;
  PlacementsMatchLyrics: Boolean;
  Preset: TDisplayPreset;
  PresetIndex: Integer;
  PresetText: string;
  StartAnimation: Integer;
  StartAnimationSeconds: Double;
  SyncAnimation: Integer;
begin
  try
    if (Edit = nil) or not Assigned(Edit^.GetFocusObject) then
      Exit;
    Obj := Edit^.GetFocusObject();
    if (Obj = nil) or
      not TryGetObjectItemText(Edit, Obj, '歌詞', CurrentLyrics) or
      not TryGetObjectItemText(Edit, Obj, '表示設定',
        CurrentSettingsText) or
      not TryGetObjectItemInteger(Edit, Obj, 'プリセット',
        PresetIndex) or
      not TryGetObjectItemInteger(Edit, Obj, '同期演出',
        DisplayEffect) or
      not TryGetObjectItemInteger(Edit, Obj, '同期アニメーション',
        SyncAnimation) or
      not TryGetObjectItemInteger(Edit, Obj, '開始演出',
        StartAnimation) or
      not TryGetObjectItemFloat(Edit, Obj, '開始演出時間 (秒)',
        StartAnimationSeconds) or
      not TryGetObjectItemInteger(Edit, Obj, '終了演出',
        EndAnimation) or
      not TryGetObjectItemFloat(Edit, Obj, '終了演出時間 (秒)',
        EndAnimationSeconds) then
      Exit;
    Common := DefaultDisplayCommonSettings;
    CurrentPlacements := nil;
    PlacementsMatchLyrics := False;
    TryDecodeDisplaySettingsText(CurrentSettingsText, CurrentLyrics,
      Common, CurrentPlacements, PlacementsMatchLyrics);
    BuildDisplayPreset(Common, DisplayEffect, SyncAnimation, StartAnimation,
      StartAnimationSeconds, EndAnimation, EndAnimationSeconds, Preset);
    if not TryEncodeDisplayPreset(Preset, PresetText) then
      Exit;
    FileName := TPath.Combine(
      TPath.Combine(TPath.GetDocumentsPath, 'SYNC_Lyrics'),
      IntToStr(EnsureRange(PresetIndex, 0, 9)) + '.slpreset');
    TDirectory.CreateDirectory(TPath.GetDirectoryName(FileName));
    TFile.WriteAllText(FileName, PresetText, TEncoding.UTF8);
  except
    // Preset operations are deliberately silent.
  end;
end;

procedure PresetLoadButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  Common: TDisplayCommonSettings;
  CurrentLyrics: string;
  CurrentPlacements: TDisplayPlacementItems;
  CurrentSettingsText: string;
  DisplayEffect: Integer;
  EncodedSettingsText: string;
  EndAnimation: Integer;
  EndAnimationSeconds: Double;
  FailedItemName: string;
  FileName: string;
  Obj: OBJECT_HANDLE;
  PlacementsMatchLyrics: Boolean;
  Preset: TDisplayPreset;
  PresetIndex: Integer;
  PresetText: string;
  StartAnimation: Integer;
  StartAnimationSeconds: Double;
  SyncAnimation: Integer;
  Updates: TFilterItemUpdates;
begin
  try
    if (Edit = nil) or not Assigned(Edit^.GetFocusObject) or
      not Assigned(Edit^.GetObjectItemValue) or
      not Assigned(Edit^.SetObjectItemValue) then
      Exit;
    Obj := Edit^.GetFocusObject();
    if (Obj = nil) or
      not TryGetObjectItemInteger(Edit, Obj, 'プリセット',
        PresetIndex) then
      Exit;
    FileName := TPath.Combine(
      TPath.Combine(TPath.GetDocumentsPath, 'SYNC_Lyrics'),
      IntToStr(EnsureRange(PresetIndex, 0, 9)) + '.slpreset');
    if not TFile.Exists(FileName) then
      Exit;
    PresetText := TFile.ReadAllText(FileName, TEncoding.UTF8);
    if not TryDecodeDisplayPreset(PresetText, Preset) then
      Exit;

    if not TryGetObjectItemText(Edit, Obj, '歌詞', CurrentLyrics) or
      not TryGetObjectItemText(Edit, Obj, '表示設定',
        CurrentSettingsText) then
      Exit;
    Common := DefaultDisplayCommonSettings;
    CurrentPlacements := nil;
    PlacementsMatchLyrics := False;
    TryDecodeDisplaySettingsText(CurrentSettingsText, CurrentLyrics,
      Common, CurrentPlacements, PlacementsMatchLyrics);
    if not PlacementsMatchLyrics then
      CurrentPlacements := nil;
    ApplyDisplayPreset(Preset, Common, DisplayEffect, SyncAnimation,
      StartAnimation, StartAnimationSeconds, EndAnimation,
      EndAnimationSeconds);
    if not TryEncodeDisplaySettingsText(CurrentLyrics, Common,
      CurrentPlacements, EncodedSettingsText) then
      Exit;

    AddFilterItemUpdate(Updates, '表示設定', CurrentSettingsText,
      EncodedSettingsText);
    if not TryGetObjectItemText(Edit, Obj, '同期演出',
      PresetText) then
      Exit;
    AddFilterItemUpdate(Updates, '同期演出', PresetText,
      IntToStr(DisplayEffect));
    if not TryGetObjectItemText(Edit, Obj, '同期アニメーション',
      PresetText) then
      Exit;
    AddFilterItemUpdate(Updates, '同期アニメーション', PresetText,
      IntToStr(SyncAnimation));
    if not TryGetObjectItemText(Edit, Obj, '開始演出',
      PresetText) then
      Exit;
    AddFilterItemUpdate(Updates, '開始演出', PresetText,
      IntToStr(StartAnimation));
    if not TryGetObjectItemText(Edit, Obj, '開始演出時間 (秒)',
      PresetText) then
      Exit;
    AddFilterItemUpdate(Updates, '開始演出時間 (秒)', PresetText,
      FormatFloat('0.00', StartAnimationSeconds,
        TFormatSettings.Invariant));
    if not TryGetObjectItemText(Edit, Obj, '終了演出',
      PresetText) then
      Exit;
    AddFilterItemUpdate(Updates, '終了演出', PresetText,
      IntToStr(EndAnimation));
    if not TryGetObjectItemText(Edit, Obj, '終了演出時間 (秒)',
      PresetText) then
      Exit;
    AddFilterItemUpdate(Updates, '終了演出時間 (秒)', PresetText,
      FormatFloat('0.00', EndAnimationSeconds,
        TFormatSettings.Invariant));
    ApplyFilterItemUpdates(Edit, Obj, Updates, FailedItemName);
  except
    // Preset operations are deliberately silent.
  end;
end;

procedure LineDisplaySettingsButtonCallback(
  Edit: PEDIT_SECTION); cdecl;
var
  BackgroundHeight: Integer;
  BackgroundPixels: TBytes;
  BackgroundStatus: string;
  BackgroundWidth: Integer;
  CurrentCommon: TDisplayCommonSettings;
  CurrentLyrics: string;
  CurrentPlacements: TDisplayPlacementItems;
  CurrentSettingsText: string;
  EncodedSettingsText: string;
  FailedItemName: string;
  LineDisplayForm: TFormLyricsLineDisplaySettings;
  Obj: OBJECT_HANDLE;
  PlacementsMatchLyrics: Boolean;
  SelectedCommon: TDisplayCommonSettings;
  SelectedLyrics: string;
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
    CurrentSettingsText := '';
    if Assigned(DisplaySettingsTextItem.Value) then
      CurrentSettingsText := string(DisplaySettingsTextItem.Value);
    CurrentCommon := DefaultDisplayCommonSettings;
    CurrentPlacements := nil;
    PlacementsMatchLyrics := False;
    TryDecodeDisplaySettingsText(CurrentSettingsText, CurrentLyrics,
      CurrentCommon, CurrentPlacements, PlacementsMatchLyrics);
    LineDisplayForm := TFormLyricsLineDisplaySettings.Create(nil);
    try
      if CopyLastFrame(BackgroundPixels, BackgroundWidth,
        BackgroundHeight, BackgroundStatus) then
        LineDisplayForm.SetBackgroundRgba(BackgroundPixels,
          BackgroundWidth, BackgroundHeight);
      LineDisplayForm.Configure(CurrentLyrics, CurrentCommon);
      if LineDisplayForm.ShowModal <> mrOk then
        Exit;
      SelectedLyrics := LineDisplayForm.EnteredLyrics;
      SelectedCommon := LineDisplayForm.SelectedCommonSettings;
    finally
      LineDisplayForm.Free;
    end;

    if (SelectedLyrics <> CurrentLyrics) or not PlacementsMatchLyrics then
      CurrentPlacements := nil;
    if not TryEncodeDisplaySettingsText(SelectedLyrics, SelectedCommon,
      CurrentPlacements, EncodedSettingsText) then
    begin
      ShowFontSettingsError(
        '表示設定を文字列へ変換できませんでした。');
      Exit;
    end;
    AddFilterItemUpdate(Updates, '歌詞', CurrentLyrics, SelectedLyrics);
    AddFilterItemUpdate(Updates, '表示設定', CurrentSettingsText,
      EncodedSettingsText);
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
  CurrentCommon: TDisplayCommonSettings;
  CurrentPlacements: TDisplayPlacementItems;
  CurrentSettingsText: string;
  CurrentLyrics: string;
  CharacterLayoutForm: TFormLyricsCharacterLayoutSettings;
  EncodedSettingsText: string;
  Obj: OBJECT_HANDLE;
  PlacementsMatchLyrics: Boolean;
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
  CurrentCommon := DefaultDisplayCommonSettings;
  CurrentPlacements := nil;
  PlacementsMatchLyrics := False;
  TryDecodeDisplaySettingsText(CurrentSettingsText, CurrentLyrics,
    CurrentCommon, CurrentPlacements, PlacementsMatchLyrics);

  CharacterLayoutForm := TFormLyricsCharacterLayoutSettings.Create(nil);
  try
    if CopyLastFrame(BackgroundPixels, BackgroundWidth,
      BackgroundHeight, BackgroundStatus) then
      CharacterLayoutForm.SetBackgroundRgba(BackgroundPixels,
        BackgroundWidth, BackgroundHeight);
    CharacterLayoutForm.SetCaptureStatus(BackgroundStatus);
    CharacterLayoutForm.Configure(CurrentLyrics, CurrentCommon,
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

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  AnimationOffsetY: Integer;
  AnimationOpacity: Double;
  AnimationSettings: TLyricsAnimationSettings;
  CommonSettings: TDisplayCommonSettings;
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
  PlacementsMatchLyrics: Boolean;
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
    LyricsText := '';
    if Assigned(LyricsItem.Value) then
      LyricsText := string(LyricsItem.Value);
    CommonSettings := DefaultDisplayCommonSettings;
    PlacementItems := nil;
    PlacementsMatchLyrics := False;
    if Assigned(DisplaySettingsTextItem.Value) then
      TryDecodeDisplaySettingsText(string(DisplaySettingsTextItem.Value),
        LyricsText, CommonSettings, PlacementItems,
        PlacementsMatchLyrics);
    RenderSettings.BaseFontName := CommonSettings.BaseFontName;
    RenderSettings.RubyFontName := CommonSettings.RubyFontName;
    RenderSettings.BaseBold := (CommonSettings.BaseFontStyle and 1) <> 0;
    RenderSettings.BaseItalic := (CommonSettings.BaseFontStyle and 2) <> 0;
    RenderSettings.BaseUnderline := (CommonSettings.BaseFontStyle and 4) <> 0;
    RenderSettings.BaseStrikeOut := (CommonSettings.BaseFontStyle and 8) <> 0;
    RenderSettings.RubyBold := (CommonSettings.RubyFontStyle and 1) <> 0;
    RenderSettings.RubyItalic := (CommonSettings.RubyFontStyle and 2) <> 0;
    RenderSettings.RubyUnderline := (CommonSettings.RubyFontStyle and 4) <> 0;
    RenderSettings.RubyStrikeOut := (CommonSettings.RubyFontStyle and 8) <> 0;
    RenderSettings.BaseFontHeight := CommonSettings.BaseFontHeight;
    RenderSettings.RubyFontHeight := CommonSettings.RubyFontHeight;
    RenderSettings.RubyGapAdjustment := CommonSettings.RubyGapAdjustment;
    RenderSettings.BaseCharacterSpacing :=
      CommonSettings.BaseCharacterSpacing;
    RenderSettings.RubyCharacterSpacing :=
      CommonSettings.RubyCharacterSpacing;
    RenderSettings.BeforeColor.R := CommonSettings.BeforeColor and $FF;
    RenderSettings.BeforeColor.G :=
      (CommonSettings.BeforeColor shr 8) and $FF;
    RenderSettings.BeforeColor.B :=
      (CommonSettings.BeforeColor shr 16) and $FF;
    RenderSettings.AfterColor.R := CommonSettings.AfterColor and $FF;
    RenderSettings.AfterColor.G :=
      (CommonSettings.AfterColor shr 8) and $FF;
    RenderSettings.AfterColor.B :=
      (CommonSettings.AfterColor shr 16) and $FF;
    HasFreePlacement := False;
    if SelectedPlacementMode = PLACEMENT_MODE_FREE then
    begin
      ParseLyrics(LyricsText, PlacementPlainText, PlacementRubySpans);
      BuildLyricsDisplayUnits(PlacementPlainText, PlacementRubySpans,
        PlacementUnits);
      HasFreePlacement := PlacementsMatchLyrics and
        (Length(PlacementItems) = Length(PlacementUnits));
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
        RenderSettings, PlacementItems, CommonSettings.PositionX,
        CommonSettings.PositionY + AnimationOffsetY)
    else
      RenderLyrics(Video, PWideChar(LyricsText), SyncProgress,
        RenderSettings, CommonSettings.PositionX,
        CommonSettings.PositionY + AnimationOffsetY);
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
    PluginItems[4] := @PlacementModeItem;
    PluginItems[5] := @DisplayEffectItem;
    PluginItems[6] := @DisplaySettingsButton;
    PluginItems[7] := @PresetItem;
    PluginItems[8] := @PresetSaveButton;
    PluginItems[9] := @PresetLoadButton;
    PluginItems[10] := @SyncAnimationItem;
    PluginItems[11] := @StartAnimationItem;
    PluginItems[12] := @StartAnimationTimeItem;
    PluginItems[13] := @EndAnimationItem;
    PluginItems[14] := @EndAnimationTimeItem;
    PluginItems[15] := @PreDisplayTimeItem;
    PluginItems[16] := @SyncDataItem;
    PluginItems[17] := @DisplaySettingsTextItem;
    PluginItems[18] := nil;
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
