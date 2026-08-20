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
  SYNC_Lyrics_DisplaySettingsData,
  SYNC_Lyrics_DisplaySettingsForm,
  SYNC_Lyrics_CharacterLayoutSettingsForm,
  SYNC_Lyrics_CharacterDisplaySettingsPage,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_SongLyricsData,
  SYNC_Lyrics_SongLyricsModel,
  SYNC_Lyrics_SongLyricsRuntime,
  SYNC_Lyrics_LastFrameCapture,
  SYNC_Lyrics_ManualSync,
  SYNC_Lyrics_ManualSyncSettingsForm,
  SYNC_Lyrics_AudioProbe,
  SYNC_Lyrics_MusicSync,
  SYNC_Lyrics_MusicSyncAnchor,
  SYNC_Lyrics_MusicSyncSettingsForm,
  SYNC_Lyrics_SyncEditorForm,
  SYNC_Lyrics_SerifAnimationItems,
  SYNC_Lyrics_LineDisplaySettingsForm,
  SYNC_Lyrics_LineDisplaySettingsPage,
  SYNC_Lyrics_Animation,
  SYNC_Lyrics_Renderer,
  SYNC_Lyrics_SyncSourceKind,
  SYNC_Lyrics_SyncFormat,
  SYNC_Lyrics_Time,
  Vcl.Dialogs,
  Vcl.Forms;

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl; forward;
function LyricsProcVideoMulti(Video: PFILTER_PROC_VIDEO): Byte; cdecl; forward;
procedure MusicSyncSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
procedure DisplaySettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;
function CharacterLayoutSettingsButtonCallback(
  Edit: PEDIT_SECTION): Integer; forward;
function LineDisplaySettingsButtonCallback(
  Edit: PEDIT_SECTION): Integer; forward;

var
  LyricsItem: TFILTER_ITEM_STRING = (
    ItemType: 'string';
    Name: '歌詞';
    Value: ''
  );
  SongDocumentItem: TFILTER_ITEM_STRING = (
    ItemType: 'string';
    Name: '歌詞データ';
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
  MusicOffsetItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: '音楽オフセット (秒)';
    Value: 0;
    S: -5;
    E: 5;
    Step: 0.01
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
  PreDisplayTimeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: '事前表示';
    Value: 0.5;
    S: 0;
    E: 60;
    Step: 0.01
  );
  HoldTimeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track';
    Name: '表示維持';
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
  PluginItems: array[0..32] of Pointer;
  Plugin: TFILTER_PLUGIN_TABLE = (
    Flag: FILTER_FLAG_VIDEO or FILTER_FLAG_FILTER;
    Name: 'SYNC_歌詞テロップ_Filter';
    Label_: 'SYNC';
    Information: '音楽データに同期する歌詞テロップフィルター';
    Items: nil;
    Func_Proc_Video: LyricsProcVideoMulti;
    Func_Proc_Audio: nil
  );

const
  FILTER_EFFECT_NAME = 'SYNC_歌詞テロップ_Filter';
  PLACEMENT_MODE_LINE = Ord(lpmLine);
  PLACEMENT_MODE_FREE = Ord(lpmFree);

type
  TFilterItemUpdate = record
    Name: string;
    OldValue: string;
    NewValue: string;
  end;
  TFilterItemUpdates = TArray<TFilterItemUpdate>;
  TDisplayCommonSettingsArray = TArray<TDisplayCommonSettings>;
  TPlacementCandidateContext = record
    DataText: string;
    Lines: TLyricsSongLines;
    LanePlacementTexts: TLyricsLanePlacementTexts;
    PlacementMode: TLyricsPlacementMode;
    StartLineID: Int64;
    CandidateIndexes: TLyricsSongLineIndexes;
    InitialCandidate: Integer;
    InitialLane: Integer;
  end;

procedure SetLyricsRenderColor(var Target: TLyricsRenderColor;
  Color: Cardinal; Opacity: Byte);
begin
  Target.A := Opacity;
  Target.R := Color and $FF;
  Target.G := (Color shr 8) and $FF;
  Target.B := (Color shr 16) and $FF;
end;

procedure ApplyDisplayDecoration(const Common: TDisplayCommonSettings;
  var Settings: TLyricsRenderSettings);
begin
  SetLyricsRenderColor(Settings.BeforeColor, Common.BeforeColor,
    Common.BeforeOpacity);
  SetLyricsRenderColor(Settings.AfterColor, Common.AfterColor,
    Common.AfterOpacity);
  SetLyricsRenderColor(Settings.BeforeOutlineColor,
    Common.BeforeOutlineColor, Common.BeforeOutlineOpacity);
  SetLyricsRenderColor(Settings.AfterOutlineColor,
    Common.AfterOutlineColor, Common.AfterOutlineOpacity);
  SetLyricsRenderColor(Settings.BeforeShadowColor,
    Common.BeforeShadowColor, Common.BeforeShadowOpacity);
  SetLyricsRenderColor(Settings.AfterShadowColor,
    Common.AfterShadowColor, Common.AfterShadowOpacity);
  SetLyricsRenderColor(Settings.BeforeBlurColor, Common.BeforeBlurColor,
    Common.BeforeBlurOpacity);
  SetLyricsRenderColor(Settings.AfterBlurColor, Common.AfterBlurColor,
    Common.AfterBlurOpacity);
  Settings.OutlineEnabled := Common.OutlineEnabled;
  Settings.OutlineWidth := Common.OutlineWidth;
  Settings.OutlineBlur := Common.OutlineBlur;
  Settings.ShadowEnabled := Common.ShadowEnabled;
  Settings.ShadowOffsetX := Common.ShadowOffsetX;
  Settings.ShadowOffsetY := Common.ShadowOffsetY;
  Settings.ShadowBlur := Common.ShadowBlur;
  Settings.ShadowSpread := Common.ShadowSpread;
end;

procedure ApplySerifSyncStyle(var Settings: TLyricsRenderSettings);
begin
  Settings.SyncKind := TLyricsSyncKind(EnsureRange(
    SerifSyncTypeItem.Value, Ord(Low(TLyricsSyncKind)),
    Ord(High(TLyricsSyncKind))));
  Settings.SyncShape := EnsureRange(SerifSyncShapeItem.Value,
    SERIF_SYNC_SHAPE_AUTO, SERIF_SYNC_SHAPE_TRIANGLE);
  Settings.ColorFillMode := TLyricsColorFillMode(EnsureRange(
    SerifSyncFillItem.Value, Ord(Low(TLyricsColorFillMode)),
    Ord(High(TLyricsColorFillMode))));
  Settings.ColorAfterMode := TLyricsColorAfterMode(EnsureRange(
    SerifSyncAfterItem.Value, Ord(Low(TLyricsColorAfterMode)),
    Ord(High(TLyricsColorAfterMode))));
  Settings.ColorBandSizePercent := EnsureRange(
    SerifSyncSizeItem.Value, 1.0, 1000.0);
  Settings.SyncOffsetX := EnsureRange(SerifSyncOffsetXItem.Value,
    -100.0, 100.0);
  Settings.SyncOffsetY := EnsureRange(SerifSyncOffsetYItem.Value,
    -100.0, 100.0);
  Settings.SyncColor.R := SerifSyncColorItem.R;
  Settings.SyncColor.G := SerifSyncColorItem.G;
  Settings.SyncColor.B := SerifSyncColorItem.B;
  Settings.SyncColor.A := 255;
  if SerifSyncTypeItem.Value <> SERIF_SYNC_COLOR then
  begin
    Settings.AfterColor := Settings.BeforeColor;
    Settings.AfterOutlineColor := Settings.BeforeOutlineColor;
    Settings.AfterShadowColor := Settings.BeforeShadowColor;
    Settings.AfterBlurColor := Settings.BeforeBlurColor;
  end;
end;

function CurrentSerifSyncAnimation: TLyricsSyncAnimation;
begin
  // 同期変形は文字・ルビ単位のRendererへ移し、行全体は動かさない。
  Result := lsaNone;
end;

function CurrentSerifStartAnimation: TLyricsEdgeAnimation;
begin
  case SerifBeforeTypeItem.Value of
    1: Result := leaFade;
    2: Result := leaSlide;
    3: Result := leaZoom;
    4: Result := leaPop;
    5: Result := leaWipe;
    6: Result := leaBlur;
    10: Result := leaRotate;
    11: Result := leaBounce;
  else
    Result := leaNone;
  end;
end;

function CurrentSerifStartAnimationDuration: Double;
begin
  Result := EnsureRange(SerifBeforeTimeItem.Value, 0.01, 3.00);
end;

function CurrentSerifEndAnimation: TLyricsEdgeAnimation;
begin
  case SerifAfterTypeItem.Value of
    1: Result := leaFade;
    2: Result := leaSlide;
    3: Result := leaZoom;
    4: Result := leaWipe;
    5: Result := leaBlur;
    6: Result := leaRotate;
  else
    Result := leaNone;
  end;
end;

function CurrentSerifEndAnimationDuration: Double;
begin
  Result := Min(EnsureRange(SerifAfterTimeItem.Value, 0.01, 3.00),
    Max(0.01, HoldTimeItem.Value));
end;

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

function TryBuildPlacementCandidateContext(Edit: PEDIT_SECTION;
  Obj: OBJECT_HANDLE; out Context: TPlacementCandidateContext): Boolean;
var
  AdjustedLines: TLyricsSongLines;
  Anchor: TMusicSyncAnchor;
  CurrentFrame: Int64;
  ObjectLayerFrame: TOBJECT_LAYER_FRAME;
  SongStartFrame: Int64;
  StartLineID: Int64;
begin
  Context.DataText := '';
  Context.Lines := nil;
  Context.LanePlacementTexts := Default(TLyricsLanePlacementTexts);
  Context.PlacementMode := lpmLine;
  Context.StartLineID := 0;
  Context.CandidateIndexes := nil;
  Context.InitialCandidate := -1;
  Context.InitialLane := 0;
  if not TryGetObjectItemText(Edit, Obj, '歌詞データ',
    Context.DataText) then
    Context.DataText := '';
  Result := (Context.DataText <> '') and
    TryGetSongLyricsDocument(Context.DataText, Context.Lines,
      StartLineID, Context.LanePlacementTexts,
      Context.PlacementMode) and
    (Length(Context.Lines) > 0);
  if not Result then
    Exit;

  AdjustedLines := Copy(Context.Lines);
  CurrentFrame := 0;
  if (Edit <> nil) and Assigned(Edit^.GetObjectLayerFrame) and
    (Obj <> nil) then
  begin
    ObjectLayerFrame := Edit^.GetObjectLayerFrame(Obj);
    if TryGetMusicSyncAnchor(ObjectLayerFrame.Layer,
      ObjectLayerFrame.StartFrame, ObjectLayerFrame.EndFrame, Anchor) then
    begin
      CurrentFrame := Anchor.CurrentFrame;
      AdjustedLines := ApplyMusicOffsetToSongLyricsLines(AdjustedLines,
        EnsureRange(MusicOffsetItem.Value, -5.0, 5.0),
        Anchor.Rate, Anchor.Scale);
      AdjustedLines := ApplyDisplayDurationsToSongLyricsLines(
        AdjustedLines, Max(0.0, PreDisplayTimeItem.Value),
        Max(0.0, HoldTimeItem.Value), Anchor.Rate, Anchor.Scale);
    end;
  end;
  AdjustedLines := AlignSongLyricsLinesToStartLine(AdjustedLines,
    StartLineID, SongStartFrame);
  Context.CandidateIndexes :=
    ResolveSongLyricsPlacementCandidateIndexes(AdjustedLines, CurrentFrame);
  Context.InitialCandidate := ResolveSongLyricsPlacementInitialCandidate(
    AdjustedLines, Context.CandidateIndexes, CurrentFrame);
  Context.StartLineID := StartLineID;
  if (Context.InitialCandidate >= 0) and
    (Context.InitialCandidate < Length(Context.CandidateIndexes)) then
    Context.InitialLane := EnsureRange(
      Context.Lines[Context.CandidateIndexes[
        Context.InitialCandidate]].DisplayLane, 1, 3) - 1;
  Result := Length(Context.CandidateIndexes) > 0;
end;

function FindLaneRepresentativeIndex(
  const Context: TPlacementCandidateContext; DisplayLane: Integer): Integer;
var
  CandidateIndex: Integer;
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(Context.CandidateIndexes) do
  begin
    CandidateIndex := Context.CandidateIndexes[I];
    if (CandidateIndex >= 0) and (CandidateIndex < Length(Context.Lines)) and
      (Context.Lines[CandidateIndex].DisplayLane = DisplayLane) then
      Exit(CandidateIndex);
  end;
  for I := 0 to High(Context.Lines) do
    if Context.Lines[I].DisplayLane = DisplayLane then
      Exit(I);
  if Length(Context.CandidateIndexes) > 0 then
    Result := Context.CandidateIndexes[0]
  else if Length(Context.Lines) > 0 then
    Result := 0;
end;

procedure BuildLanePlacementValues(
  const Context: TPlacementCandidateContext;
  const GlobalSettingsText: string; out Captions, Lyrics,
  SettingsTexts: TArray<string>;
  out CommonSettings: TDisplayCommonSettingsArray);
var
  Common: TDisplayCommonSettings;
  DisplayLane: Integer;
  Items: TDisplayPlacementItems;
  LaneCommon: TDisplayCommonSettings;
  MatchesLyrics: Boolean;
  RepresentativeIndex: Integer;
begin
  SetLength(Captions, 3);
  SetLength(Lyrics, 3);
  SetLength(SettingsTexts, 3);
  SetLength(CommonSettings, 3);
  for DisplayLane := 1 to 3 do
  begin
    RepresentativeIndex := FindLaneRepresentativeIndex(Context,
      DisplayLane);
    if RepresentativeIndex >= 0 then
      Lyrics[DisplayLane - 1] :=
        Context.Lines[RepresentativeIndex].SourceText
    else
      Lyrics[DisplayLane - 1] := '';
    Captions[DisplayLane - 1] := Format('配置%d（表示段%d）',
      [DisplayLane, DisplayLane]);
    Common := DefaultDisplayCommonSettings;
    Items := nil;
    MatchesLyrics := False;
    TryDecodeDisplaySettingsText(GlobalSettingsText,
      Lyrics[DisplayLane - 1], Common, Items, MatchesLyrics);
    Inc(Common.PositionY, (DisplayLane - 2) *
      (Common.BaseFontHeight + Common.RubyFontHeight + 16));
    SettingsTexts[DisplayLane - 1] :=
      Context.LanePlacementTexts[DisplayLane];
    if Context.LanePlacementTexts[DisplayLane] <> '' then
    begin
      LaneCommon := Common;
      if TryDecodeDisplaySettingsText(
        Context.LanePlacementTexts[DisplayLane],
        Lyrics[DisplayLane - 1], LaneCommon, Items, MatchesLyrics) then
        Common := LaneCommon;
    end;
    CommonSettings[DisplayLane - 1] := Common;
  end;
end;

procedure BuildPlacementCandidateValues(
  const Context: TPlacementCandidateContext;
  const GlobalSettingsText: string; out Captions, Lyrics,
  SettingsTexts: TArray<string>;
  out CommonSettings: TDisplayCommonSettingsArray);
var
  CandidateIndex: Integer;
  Common: TDisplayCommonSettings;
  I: Integer;
  Items: TDisplayPlacementItems;
  LineCommon: TDisplayCommonSettings;
  MatchesLyrics: Boolean;
begin
  SetLength(Captions, Length(Context.CandidateIndexes));
  SetLength(Lyrics, Length(Context.CandidateIndexes));
  SetLength(SettingsTexts, Length(Context.CandidateIndexes));
  SetLength(CommonSettings, Length(Context.CandidateIndexes));
  for I := 0 to High(Context.CandidateIndexes) do
  begin
    CandidateIndex := Context.CandidateIndexes[I];
    Lyrics[I] := Context.Lines[CandidateIndex].SourceText;
    Captions[I] := Format('%d: %s', [CandidateIndex + 1,
      Context.Lines[CandidateIndex].PlainText]);
    Common := DefaultDisplayCommonSettings;
    Items := nil;
    MatchesLyrics := False;
    TryDecodeDisplaySettingsText(GlobalSettingsText, Lyrics[I],
      Common, Items, MatchesLyrics);
    SettingsTexts[I] := GlobalSettingsText;
    if (Context.Lines[CandidateIndex].PlacementText <> '') and
      TryDecodeDisplaySettingsText(
        Context.Lines[CandidateIndex].PlacementText, Lyrics[I],
        LineCommon, Items, MatchesLyrics) and MatchesLyrics then
    begin
      Common := LineCommon;
      SettingsTexts[I] := Context.Lines[CandidateIndex].PlacementText;
    end;
    CommonSettings[I] := Common;
  end;
end;

function TryStoreSongLinePlacement(Edit: PEDIT_SECTION;
  Obj: OBJECT_HANDLE; const Context: TPlacementCandidateContext;
  CandidatePosition, PlacementMode: Integer; const SettingsText: string;
  out ErrorText: string): Boolean;
var
  CandidateIndex: Integer;
  EncodedSongText: string;
  Model: TLyricsSongModel;
  Utf8SongText: UTF8String;
begin
  Result := False;
  ErrorText := '';
  if (CandidatePosition < 0) or
    (CandidatePosition >= Length(Context.CandidateIndexes)) then
  begin
    ErrorText := '編集対象の歌詞行を取得できませんでした。';
    Exit;
  end;
  CandidateIndex := Context.CandidateIndexes[CandidatePosition];
  Model := TLyricsSongModel.Create;
  try
    Model.ReplaceLines(Context.Lines);
    Model.ReplaceLanePlacementTexts(Context.LanePlacementTexts);
    if Context.StartLineID > 0 then
      Model.TrySetStartLineID(Context.StartLineID);
    Model.PlacementMode := TLyricsPlacementMode(EnsureRange(
      PlacementMode, PLACEMENT_MODE_LINE, PLACEMENT_MODE_FREE));
    if not Model.TrySetPlacementText(CandidateIndex, SettingsText) or
      not TryEncodeSongLyrics(Model, EncodedSongText, ErrorText) then
      Exit;
  finally
    Model.Free;
  end;
  if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
    (Obj = nil) then
  begin
    ErrorText := '配置を反映する対象オブジェクトを取得できませんでした。';
    Exit;
  end;
  Utf8SongText := UTF8String(EncodedSongText);
  Result := Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
    '歌詞データ', PAnsiChar(Utf8SongText));
  if not Result then
    ErrorText := '歌詞データを歌詞テロップへ反映できませんでした。';
end;

function TryStoreSongLanePlacement(Edit: PEDIT_SECTION;
  Obj: OBJECT_HANDLE; const Context: TPlacementCandidateContext;
  LanePosition, PlacementMode: Integer; const SettingsText: string;
  out ErrorText: string): Boolean;
var
  EncodedSongText: string;
  Model: TLyricsSongModel;
  Utf8SongText: UTF8String;
begin
  Result := False;
  ErrorText := '';
  if (LanePosition < 0) or (LanePosition >= 3) then
  begin
    ErrorText := '編集対象の共通配置を取得できませんでした。';
    Exit;
  end;
  Model := TLyricsSongModel.Create;
  try
    Model.ReplaceLines(Context.Lines);
    Model.ReplaceLanePlacementTexts(Context.LanePlacementTexts);
    if Context.StartLineID > 0 then
      Model.TrySetStartLineID(Context.StartLineID);
    Model.PlacementMode := TLyricsPlacementMode(EnsureRange(
      PlacementMode, PLACEMENT_MODE_LINE, PLACEMENT_MODE_FREE));
    if not Model.TrySetLanePlacementText(LanePosition + 1,
      SettingsText) or
      not TryEncodeSongLyrics(Model, EncodedSongText, ErrorText) then
      Exit;
  finally
    Model.Free;
  end;
  if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
    (Obj = nil) then
  begin
    ErrorText := '配置を反映する対象オブジェクトを取得できませんでした。';
    Exit;
  end;
  Utf8SongText := UTF8String(EncodedSongText);
  Result := Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
    '歌詞データ', PAnsiChar(Utf8SongText));
  if not Result then
    ErrorText := '歌詞データを歌詞テロップへ反映できませんでした。';
end;

function TryStoreSongLinePlacements(Edit: PEDIT_SECTION;
  Obj: OBJECT_HANDLE; const Context: TPlacementCandidateContext;
  PlacementMode: Integer; const SettingsTexts: TArray<string>;
  out ErrorText: string): Boolean;
var
  CandidatePosition: Integer;
  EncodedSongText: string;
  Model: TLyricsSongModel;
  Utf8SongText: UTF8String;
begin
  Result := False;
  ErrorText := '';
  if Length(SettingsTexts) <> Length(Context.CandidateIndexes) then
  begin
    ErrorText := '自由配置の編集内容を取得できませんでした。';
    Exit;
  end;
  Model := TLyricsSongModel.Create;
  try
    Model.ReplaceLines(Context.Lines);
    Model.ReplaceLanePlacementTexts(Context.LanePlacementTexts);
    if Context.StartLineID > 0 then
      Model.TrySetStartLineID(Context.StartLineID);
    Model.PlacementMode := TLyricsPlacementMode(EnsureRange(
      PlacementMode, PLACEMENT_MODE_LINE, PLACEMENT_MODE_FREE));
    for CandidatePosition := 0 to High(SettingsTexts) do
      if not Model.TrySetPlacementText(
        Context.CandidateIndexes[CandidatePosition],
        SettingsTexts[CandidatePosition]) then
      begin
        ErrorText := '自由配置設定を歌詞データへ反映できませんでした。';
        Exit;
      end;
    if not TryEncodeSongLyrics(Model, EncodedSongText, ErrorText) then
      Exit;
  finally
    Model.Free;
  end;
  if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
    (Obj = nil) then
  begin
    ErrorText := '配置を反映する対象オブジェクトを取得できませんでした。';
    Exit;
  end;
  Utf8SongText := UTF8String(EncodedSongText);
  Result := Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
    '歌詞データ', PAnsiChar(Utf8SongText));
  if not Result then
    ErrorText := '歌詞データを歌詞テロップへ反映できませんでした。';
end;

function TryStoreSongLanePlacements(Edit: PEDIT_SECTION;
  Obj: OBJECT_HANDLE; const Context: TPlacementCandidateContext;
  PlacementMode: Integer; const SettingsTexts: TArray<string>;
  out ErrorText: string): Boolean;
var
  EncodedSongText: string;
  LanePosition: Integer;
  Model: TLyricsSongModel;
  Utf8SongText: UTF8String;
begin
  Result := False;
  ErrorText := '';
  if Length(SettingsTexts) <> 3 then
  begin
    ErrorText := '共通配置1～3の設定を取得できませんでした。';
    Exit;
  end;
  Model := TLyricsSongModel.Create;
  try
    Model.ReplaceLines(Context.Lines);
    Model.ReplaceLanePlacementTexts(Context.LanePlacementTexts);
    if Context.StartLineID > 0 then
      Model.TrySetStartLineID(Context.StartLineID);
    Model.PlacementMode := TLyricsPlacementMode(EnsureRange(
      PlacementMode, PLACEMENT_MODE_LINE, PLACEMENT_MODE_FREE));
    for LanePosition := 0 to 2 do
      if not Model.TrySetLanePlacementText(LanePosition + 1,
        SettingsTexts[LanePosition]) then
      begin
        ErrorText := '共通配置設定を歌詞データへ反映できませんでした。';
        Exit;
      end;
    if not TryEncodeSongLyrics(Model, EncodedSongText, ErrorText) then
      Exit;
  finally
    Model.Free;
  end;
  if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
    (Obj = nil) then
  begin
    ErrorText := '配置を反映する対象オブジェクトを取得できませんでした。';
    Exit;
  end;
  Utf8SongText := UTF8String(EncodedSongText);
  Result := Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
    '歌詞データ', PAnsiChar(Utf8SongText));
  if not Result then
    ErrorText := '歌詞データを歌詞テロップへ反映できませんでした。';
end;

procedure DisplaySettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  BackgroundHeight: Integer;
  BackgroundPixels: TBytes;
  BackgroundStatus: string;
  BackgroundWidth: Integer;
  CandidateCaptions: TArray<string>;
  CandidateCommon: TDisplayCommonSettingsArray;
  CandidateLyrics: TArray<string>;
  CandidateSettingsTexts: TArray<string>;
  CharacterPage: TFrameLyricsCharacterDisplaySettingsPage;
  CurrentSettingsText: string;
  DisplaySettingsForm: TFormLyricsDisplaySettings;
  ErrorText: string;
  FormResult: Integer;
  I: Integer;
  LinePage: TFrameLyricsLineDisplaySettingsPage;
  Obj: OBJECT_HANDLE;
  PlacementContext: TPlacementCandidateContext;
  PlacementMode: TLyricsPlacementMode;
  WholeSongMode: Boolean;
begin
  try
    PlacementMode := lpmLine;
    Obj := nil;
    if (Edit <> nil) and Assigned(Edit^.GetFocusObject) then
      Obj := Edit^.GetFocusObject();
    CurrentSettingsText := '';
    if Assigned(DisplaySettingsTextItem.Value) then
      CurrentSettingsText := string(DisplaySettingsTextItem.Value);
    WholeSongMode := TryBuildPlacementCandidateContext(
      Edit, Obj, PlacementContext);
    if WholeSongMode then
    begin
      PlacementMode := PlacementContext.PlacementMode;
    end;
    DisplaySettingsForm := TFormLyricsDisplaySettings.Create(nil);
    try
      LinePage := TFrameLyricsLineDisplaySettingsPage(
        DisplaySettingsForm.PageForMode(Ord(lpmLine)));
      CharacterPage := TFrameLyricsCharacterDisplaySettingsPage(
        DisplaySettingsForm.PageForMode(Ord(lpmFree)));
      if CopyLastFrame(BackgroundPixels, BackgroundWidth,
        BackgroundHeight, BackgroundStatus) then
      begin
        LinePage.SetBackgroundRgba(BackgroundPixels,
          BackgroundWidth, BackgroundHeight);
        CharacterPage.SetBackgroundRgba(BackgroundPixels,
          BackgroundWidth, BackgroundHeight);
      end;
      if WholeSongMode then
      begin
        BuildLanePlacementValues(PlacementContext, CurrentSettingsText,
          CandidateCaptions, CandidateLyrics, CandidateSettingsTexts,
          CandidateCommon);
        DisplaySettingsForm.ConfigureModeCandidates(
          Ord(lpmLine), CandidateCaptions,
          PlacementContext.InitialLane);
        LinePage.ConfigureCandidates(CandidateLyrics, CandidateCommon,
          PlacementContext.InitialLane);
        BuildPlacementCandidateValues(PlacementContext,
          CurrentSettingsText, CandidateCaptions, CandidateLyrics,
          CandidateSettingsTexts, CandidateCommon);
        DisplaySettingsForm.ConfigureModeCandidates(
          Ord(lpmFree), CandidateCaptions,
          PlacementContext.InitialCandidate);
        CharacterPage.ConfigureCandidates(CandidateLyrics,
          CandidateCommon, CandidateSettingsTexts,
          PlacementContext.InitialCandidate);
      end;
      DisplaySettingsForm.SetMode(Ord(PlacementMode));
      FormResult := DisplaySettingsForm.ShowModal;
      if WholeSongMode and (FormResult = mrOk) and
        (DisplaySettingsForm.CurrentMode = Ord(lpmLine)) then
      begin
        CandidateLyrics := LinePage.CandidateLyrics;
        CandidateCommon := LinePage.CandidateCommonSettings;
        if (Length(CandidateLyrics) <> 3) or
          (Length(CandidateCommon) <> 3) then
        begin
          ShowFontSettingsError(
            '共通配置1～3の編集内容を取得できませんでした。');
          Exit;
        end;
        SetLength(CandidateSettingsTexts, 3);
        for I := 0 to 2 do
          if not TryEncodeDisplaySettingsText(CandidateLyrics[I],
            CandidateCommon[I], nil, CandidateSettingsTexts[I]) then
          begin
            ShowFontSettingsError(
              '共通配置設定を文字列へ変換できませんでした。');
            Exit;
          end;
        if not TryStoreSongLanePlacements(Edit, Obj, PlacementContext,
          Ord(lpmLine), CandidateSettingsTexts, ErrorText) then
          ShowFontSettingsError(ErrorText);
      end;
      if WholeSongMode and (FormResult = mrOk) and
        (DisplaySettingsForm.CurrentMode = Ord(lpmFree)) then
      begin
        if not CharacterPage.TryBuildCandidateSettingsTexts(
          CandidateSettingsTexts) then
        begin
          ShowFontSettingsError(
            '自由配置設定を文字列へ変換できませんでした。');
          Exit;
        end;
        if not TryStoreSongLinePlacements(Edit, Obj, PlacementContext,
          Ord(lpmFree), CandidateSettingsTexts, ErrorText) then
          ShowFontSettingsError(ErrorText);
      end;
    finally
      DisplaySettingsForm.Free;
    end;
  except
    on E: Exception do
      ShowFontSettingsError(
        '表示設定画面を開けませんでした: ' + E.Message);
  end;
end;

function LineDisplaySettingsButtonCallback(
  Edit: PEDIT_SECTION): Integer;
var
  BackgroundHeight: Integer;
  BackgroundPixels: TBytes;
  BackgroundStatus: string;
  BackgroundWidth: Integer;
  CandidateCaptions: TArray<string>;
  CandidateCommon: TDisplayCommonSettingsArray;
  CandidateLyrics: TArray<string>;
  CandidatePosition: Integer;
  CandidateSettingsTexts: TArray<string>;
  CurrentCommon: TDisplayCommonSettings;
  CurrentLyrics: string;
  CurrentPlacements: TDisplayPlacementItems;
  CurrentSettingsText: string;
  EncodedSettingsText: string;
  ErrorText: string;
  FailedItemName: string;
  FormResult: Integer;
  LineDisplayForm: TFormLyricsLineDisplaySettings;
  Obj: OBJECT_HANDLE;
  PlacementContext: TPlacementCandidateContext;
  PlacementsMatchLyrics: Boolean;
  SelectedCommon: TDisplayCommonSettings;
  SelectedLyrics: string;
  SelectedPlacementMode: Integer;
  Updates: TFilterItemUpdates;
  WholeSongMode: Boolean;
begin
  Result := -1;
  try
    Obj := nil;
    if (Edit <> nil) and Assigned(Edit^.GetFocusObject) then
      Obj := Edit^.GetFocusObject();
    if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
      (Obj = nil) then
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
    WholeSongMode := TryBuildPlacementCandidateContext(
      Edit, Obj, PlacementContext);
    if WholeSongMode then
    begin
      BuildLanePlacementValues(PlacementContext,
        CurrentSettingsText, CandidateCaptions, CandidateLyrics,
        CandidateSettingsTexts, CandidateCommon);
      LineDisplayForm := TFormLyricsLineDisplaySettings.Create(nil);
      try
        if CopyLastFrame(BackgroundPixels, BackgroundWidth,
          BackgroundHeight, BackgroundStatus) then
          LineDisplayForm.SetBackgroundRgba(BackgroundPixels,
            BackgroundWidth, BackgroundHeight);
        LineDisplayForm.ConfigureCandidates(CandidateCaptions,
          CandidateLyrics, CandidateCommon,
          PlacementContext.InitialLane);
        LineDisplayForm.ConfigurePlacementMode(
          Ord(PlacementContext.PlacementMode));
        FormResult := LineDisplayForm.ShowModal;
        if (FormResult <> mrOk) and
          (FormResult <> PLACEMENT_MODE_SWITCH_MODAL_RESULT) then
          Exit;
        CandidatePosition := LineDisplayForm.SelectedCandidateIndex;
        SelectedLyrics := LineDisplayForm.EnteredLyrics;
        SelectedCommon := LineDisplayForm.SelectedCommonSettings;
        SelectedPlacementMode :=
          LineDisplayForm.SelectedPlacementMode;
      finally
        LineDisplayForm.Free;
      end;
      if (CandidatePosition < 0) or
        (CandidatePosition >= Length(CandidateSettingsTexts)) then
        Exit;
      if not TryEncodeDisplaySettingsText(SelectedLyrics,
        SelectedCommon, nil, EncodedSettingsText) then
      begin
        ShowFontSettingsError(
          '共通配置設定を文字列へ変換できませんでした。');
        Exit;
      end;
      if not TryStoreSongLanePlacement(Edit, Obj, PlacementContext,
        CandidatePosition, SelectedPlacementMode,
        EncodedSettingsText, ErrorText) then
        ShowFontSettingsError(ErrorText);
      if (ErrorText = '') and
        (FormResult = PLACEMENT_MODE_SWITCH_MODAL_RESULT) then
        Result := SelectedPlacementMode;
      Exit;
    end;

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
      LineDisplayForm.ConfigurePlacementMode(PLACEMENT_MODE_LINE);
      FormResult := LineDisplayForm.ShowModal;
      if (FormResult <> mrOk) and
        (FormResult <> PLACEMENT_MODE_SWITCH_MODAL_RESULT) then
        Exit;
      SelectedLyrics := LineDisplayForm.EnteredLyrics;
      SelectedCommon := LineDisplayForm.SelectedCommonSettings;
      SelectedPlacementMode := LineDisplayForm.SelectedPlacementMode;
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
    if Assigned(Edit^.SetObjectName) then
      Edit^.SetObjectName(Obj, PWideChar(SelectedLyrics));
    if FormResult = PLACEMENT_MODE_SWITCH_MODAL_RESULT then
      Result := SelectedPlacementMode;
  except
    on E: Exception do
      ShowFontSettingsError(
        '1行表示設定の反映中にエラーが発生しました: ' + E.Message);
  end;
end;

function CharacterLayoutSettingsButtonCallback(
  Edit: PEDIT_SECTION): Integer;
var
  BackgroundHeight: Integer;
  BackgroundPixels: TBytes;
  BackgroundStatus: string;
  BackgroundWidth: Integer;
  CandidateCaptions: TArray<string>;
  CandidateCommon: TDisplayCommonSettingsArray;
  CandidateLyrics: TArray<string>;
  CandidatePosition: Integer;
  CandidateSettingsTexts: TArray<string>;
  CurrentCommon: TDisplayCommonSettings;
  CurrentPlacements: TDisplayPlacementItems;
  CurrentSettingsText: string;
  CurrentLyrics: string;
  CharacterLayoutForm: TFormLyricsCharacterLayoutSettings;
  EncodedSettingsText: string;
  ErrorText: string;
  FormResult: Integer;
  Obj: OBJECT_HANDLE;
  PlacementContext: TPlacementCandidateContext;
  PlacementsMatchLyrics: Boolean;
  SelectedPlacementMode: Integer;
  Utf8SettingsText: UTF8String;
begin
  Result := -1;
  CurrentSettingsText := '';
  if Assigned(DisplaySettingsTextItem.Value) then
    CurrentSettingsText := string(DisplaySettingsTextItem.Value);
  CurrentLyrics := '';
  if Assigned(LyricsItem.Value) then
    CurrentLyrics := string(LyricsItem.Value);
  Obj := nil;
  if (Edit <> nil) and Assigned(Edit^.GetFocusObject) then
    Obj := Edit^.GetFocusObject();
  if TryBuildPlacementCandidateContext(Edit, Obj, PlacementContext) then
  begin
    BuildPlacementCandidateValues(PlacementContext,
      CurrentSettingsText, CandidateCaptions, CandidateLyrics,
      CandidateSettingsTexts, CandidateCommon);
    CharacterLayoutForm :=
      TFormLyricsCharacterLayoutSettings.Create(nil);
    try
      if CopyLastFrame(BackgroundPixels, BackgroundWidth,
        BackgroundHeight, BackgroundStatus) then
        CharacterLayoutForm.SetBackgroundRgba(BackgroundPixels,
          BackgroundWidth, BackgroundHeight);
      CharacterLayoutForm.SetCaptureStatus(BackgroundStatus);
      CharacterLayoutForm.ConfigureCandidates(CandidateCaptions,
        CandidateLyrics, CandidateCommon, CandidateSettingsTexts,
        PlacementContext.InitialCandidate);
      CharacterLayoutForm.ConfigurePlacementMode(
        Ord(PlacementContext.PlacementMode));
      FormResult := CharacterLayoutForm.ShowModal;
      if (FormResult <> mrOk) and
        (FormResult <> PLACEMENT_MODE_SWITCH_MODAL_RESULT) then
        Exit;
      CandidatePosition :=
        CharacterLayoutForm.SelectedCandidateIndex;
      SelectedPlacementMode :=
        CharacterLayoutForm.SelectedPlacementMode;
      if not CharacterLayoutForm.TryBuildSettingsText(
        EncodedSettingsText) then
      begin
        ShowFontSettingsError(
          '行別表示設定を文字列へ変換できませんでした。');
        Exit;
      end;
    finally
      CharacterLayoutForm.Free;
    end;
    if not TryStoreSongLinePlacement(Edit, Obj, PlacementContext,
      CandidatePosition, SelectedPlacementMode,
      EncodedSettingsText, ErrorText) then
      ShowFontSettingsError(ErrorText);
    if (ErrorText = '') and
      (FormResult = PLACEMENT_MODE_SWITCH_MODAL_RESULT) then
      Result := SelectedPlacementMode;
    Exit;
  end;

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
    CharacterLayoutForm.ConfigurePlacementMode(PLACEMENT_MODE_FREE);
    FormResult := CharacterLayoutForm.ShowModal;
    if (FormResult <> mrOk) and
      (FormResult <> PLACEMENT_MODE_SWITCH_MODAL_RESULT) then
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
    ShowFontSettingsError('表示設定を歌詞テロップへ反映できませんでした。')
  else if FormResult = PLACEMENT_MODE_SWITCH_MODAL_RESULT then
    Result := PLACEMENT_MODE_LINE;
end;

procedure MusicSyncSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl;
var
  Anchor: TMusicSyncAnchor;
  AudioInfo: TSyncAudioFileInfo;
  AudioProbeError: string;
  CurrentHoldSeconds: Double;
  CurrentLyrics: string;
  CurrentMusicFileName: string;
  CurrentMusicOffsetSeconds: Double;
  CurrentPreDisplaySeconds: Double;
  CurrentSongDataText: string;
  CurrentSyncText: string;
  CurrentTrack: Integer;
  LyricsChanged: Boolean;
  ManualSyncForm: TFormLyricsManualSyncSettings;
  Obj: OBJECT_HANDLE;
  ObjectLayerFrame: TOBJECT_LAYER_FRAME;
  SelectedLyrics: string;
  SelectedPreDisplaySeconds: Double;
  SelectedSongDataText: string;
  SelectedSyncText: string;
  PreDisplayChanged: Boolean;
  SyncChanged: Boolean;
  SyncEditorForm: TFormLyricsSyncEditor;
  SyncForm: TFormLyricsMusicSyncSettings;
  StoredSongDataText: string;
  Utf8Lyrics: UTF8String;
  Utf8OriginalLyrics: UTF8String;
  Utf8OriginalPreDisplay: UTF8String;
  Utf8OriginalSyncText: UTF8String;
  Utf8PreDisplay: UTF8String;
  Utf8SongDataText: UTF8String;
  Utf8SyncText: UTF8String;
begin
  Obj := nil;
  if (Edit <> nil) and Assigned(Edit^.GetFocusObject) then
    Obj := Edit^.GetFocusObject();

  CurrentLyrics := '';
  if not TryGetObjectItemText(Edit, Obj, '音楽ファイル',
    CurrentMusicFileName) then
    CurrentMusicFileName := '';
  CurrentSyncText := DEFAULT_MUSIC_SYNC_TEXT;
  if not TryGetObjectItemText(Edit, Obj, '歌詞データ',
    CurrentSongDataText) then
    CurrentSongDataText := '';
  if not TryGetObjectItemInteger(Edit, Obj, 'トラック (-1=全て)',
    CurrentTrack) then
    CurrentTrack := -1;
  if not TryGetObjectItemFloat(Edit, Obj, '音楽オフセット (秒)',
    CurrentMusicOffsetSeconds) then
    CurrentMusicOffsetSeconds := 0;
  CurrentMusicOffsetSeconds := EnsureRange(CurrentMusicOffsetSeconds,
    -5.0, 5.0);
  if not TryGetObjectItemFloat(Edit, Obj, '事前表示',
    CurrentPreDisplaySeconds) then
    CurrentPreDisplaySeconds := 0.5;
  CurrentPreDisplaySeconds := Max(0.0, CurrentPreDisplaySeconds);
  if not TryGetObjectItemFloat(Edit, Obj, '表示維持',
    CurrentHoldSeconds) then
    CurrentHoldSeconds := 0.5;
  CurrentHoldSeconds := Max(0.0, CurrentHoldSeconds);
  if Trim(CurrentLyrics) = '' then
  begin
    SyncEditorForm := TFormLyricsSyncEditor.Create(nil);
    try
      SyncEditorForm.ConfigureMusicSource(CurrentMusicFileName,
        CurrentTrack, CurrentMusicOffsetSeconds,
        CurrentPreDisplaySeconds, CurrentHoldSeconds);
      if (Obj <> nil) and (Edit <> nil) and
        Assigned(Edit^.GetObjectLayerFrame) then
      begin
        ObjectLayerFrame := Edit^.GetObjectLayerFrame(Obj);
        if TryGetMusicSyncAnchor(ObjectLayerFrame.Layer,
          ObjectLayerFrame.StartFrame, ObjectLayerFrame.EndFrame,
          Anchor) then
        begin
          SyncEditorForm.SetAnchor(Anchor.Frame, Anchor.Rate, Anchor.Scale);
          SyncEditorForm.SetCurrentObjectFrame(Anchor.CurrentFrame);
        end
        else
          SyncEditorForm.SetAnchorUnavailable;
      end
      else
        SyncEditorForm.SetAnchorUnavailable;
      if (CurrentSongDataText <> '') and
        not SyncEditorForm.TryLoadSongData(CurrentSongDataText,
          AudioProbeError) then
        MessageDlg('歌詞データを解析できませんでした。'#13#10 +
          AudioProbeError, mtError, [mbOK], 0);
      if SyncEditorForm.ShowModal <> mrOk then
        Exit;
      SelectedSongDataText := SyncEditorForm.SongDataText;
    finally
      SyncEditorForm.Free;
    end;
    if SelectedSongDataText = CurrentSongDataText then
      Exit;
    if (Edit = nil) or not Assigned(Edit^.SetObjectItemValue) or
      (Obj = nil) then
    begin
      ShowFontSettingsError(
        '歌詞データを反映する対象オブジェクトを取得できませんでした。');
      Exit;
    end;
    Utf8SongDataText := UTF8String(SelectedSongDataText);
    if not Edit^.SetObjectItemValue(Obj, FILTER_EFFECT_NAME,
      '歌詞データ', PAnsiChar(Utf8SongDataText)) or
      not TryGetObjectItemText(Edit, Obj, '歌詞データ',
        StoredSongDataText) or
      (StoredSongDataText <> SelectedSongDataText) then
      ShowFontSettingsError(
        '歌詞データを歌詞テロップへ保存できませんでした。');
    Exit;
  end;
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
    SyncForm.SetMusicOffsetSeconds(CurrentMusicOffsetSeconds);
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
      '事前表示', PAnsiChar(Utf8PreDisplay)) then
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
        '事前表示', PAnsiChar(Utf8OriginalPreDisplay));
      ShowFontSettingsError('事前表示時間を歌詞テロップへ反映できませんでした。');
    end;
  end;
end;

procedure RenderLyricsLine(Video: PFILTER_PROC_VIDEO;
  const FrameState: TSyncLyricsFrameState; HasFrameState: Boolean;
  ObjectStartSeconds, SongStartSeconds: Double;
  const MusicFileName: string; Track,
  SelectedPlacementMode: Integer; const LyricsText: string;
  HasSongLine: Boolean; const SongLine: TLyricsSongLine;
  const LanePlacementText: string;
  Buffer: PPIXEL_RGBA; RenderWidth, RenderHeight: Integer);
var
  AnimationOffsetY: Integer;
  AnimationOpacity: Double;
  AnimationSettings: TLyricsAnimationSettings;
  AnimationTransform: TLyricsAnimationTransform;
  CommonSettings: TDisplayCommonSettings;
  CurrentSyncSeconds: Double;
  DisplayUnitCount: Integer;
  EffectiveRestoreDuration: Double;
  EffectivePreDisplaySeconds: Double;
  EffectiveSyncText: string;
  HasBoundaryProgress: Boolean;
  HasFreePlacement: Boolean;
  HasLanePlacement: Boolean;
  HasSyncData: Boolean;
  HoldDurationSeconds: Double;
  LastStageDuration: Double;
  LineCommonSettings: TDisplayCommonSettings;
  LinePlacementItems: TDisplayPlacementItems;
  LinePlacementsMatchLyrics: Boolean;
  LocalSeconds: Double;
  MusicOffsetSeconds: Double;
  PlacementItems: TDisplayPlacementItems;
  PlacementPlainText: string;
  PlacementRubySpans: TLyricsRubySpans;
  PlacementsMatchLyrics: Boolean;
  PlacementUnits: TLyricsDisplayUnits;
  RemainingSeconds: Double;
  RenderSettings: TLyricsRenderSettings;
  RestoreElapsedSeconds: Double;
  SyncData: TSyncTextData;
  SyncProgress: Double;
  SyncStartSeconds: Double;
begin
  AnimationOffsetY := 0;
  AnimationOpacity := 1;
  CommonSettings := DefaultDisplayCommonSettings;
  PlacementItems := nil;
  PlacementsMatchLyrics := False;
  HasLanePlacement := False;
  if Assigned(DisplaySettingsTextItem.Value) then
    TryDecodeDisplaySettingsText(string(DisplaySettingsTextItem.Value),
      LyricsText, CommonSettings, PlacementItems,
      PlacementsMatchLyrics);
  if HasSongLine and (SelectedPlacementMode = PLACEMENT_MODE_LINE) and
    (LanePlacementText <> '') and
    TryDecodeDisplaySettingsText(LanePlacementText, LyricsText,
      LineCommonSettings, LinePlacementItems,
      LinePlacementsMatchLyrics) then
  begin
    CommonSettings := LineCommonSettings;
    PlacementItems := nil;
    PlacementsMatchLyrics := False;
    HasLanePlacement := True;
  end
  else if HasSongLine and
    (SelectedPlacementMode = PLACEMENT_MODE_FREE) and
    (SongLine.PlacementText <> '') and
    TryDecodeDisplaySettingsText(SongLine.PlacementText, LyricsText,
      LineCommonSettings, LinePlacementItems,
      LinePlacementsMatchLyrics) and LinePlacementsMatchLyrics then
  begin
    CommonSettings := LineCommonSettings;
    PlacementItems := LinePlacementItems;
    PlacementsMatchLyrics := LinePlacementsMatchLyrics;
  end;
  if HasSongLine and not HasLanePlacement then
    // 3段分を中央基準で予約し、段1・2・3を上・中央・下へ固定する。
    Inc(CommonSettings.PositionY, (SongLine.DisplayLane - 2) *
      (CommonSettings.BaseFontHeight +
       CommonSettings.RubyFontHeight + 16));

  RenderSettings := DefaultLyricsRenderSettings;
  RenderSettings.DisplayType := TLyricsDisplayType(
    EnsureRange(DisplayEffectItem.Value,
      Ord(Low(TLyricsDisplayType)), Ord(High(TLyricsDisplayType))));
  RenderSettings.BaseFontName := CommonSettings.BaseFontName;
  RenderSettings.RubyFontName := CommonSettings.RubyFontName;
  RenderSettings.BaseBold := (CommonSettings.BaseFontStyle and 1) <> 0;
  RenderSettings.BaseItalic := (CommonSettings.BaseFontStyle and 2) <> 0;
  RenderSettings.BaseUnderline :=
    (CommonSettings.BaseFontStyle and 4) <> 0;
  RenderSettings.BaseStrikeOut :=
    (CommonSettings.BaseFontStyle and 8) <> 0;
  RenderSettings.RubyBold := (CommonSettings.RubyFontStyle and 1) <> 0;
  RenderSettings.RubyItalic :=
    (CommonSettings.RubyFontStyle and 2) <> 0;
  RenderSettings.RubyUnderline :=
    (CommonSettings.RubyFontStyle and 4) <> 0;
  RenderSettings.RubyStrikeOut :=
    (CommonSettings.RubyFontStyle and 8) <> 0;
  RenderSettings.BaseFontHeight := CommonSettings.BaseFontHeight;
  RenderSettings.RubyFontHeight := CommonSettings.RubyFontHeight;
  RenderSettings.RubyGapAdjustment :=
    CommonSettings.RubyGapAdjustment;
  RenderSettings.BaseCharacterSpacing :=
    CommonSettings.BaseCharacterSpacing;
  RenderSettings.RubyCharacterSpacing :=
    CommonSettings.RubyCharacterSpacing;
  ApplyDisplayDecoration(CommonSettings, RenderSettings);
  ApplySerifSyncStyle(RenderSettings);

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
  HasBoundaryProgress := False;
  if HasSongLine and (Video <> nil) and (Video^.Object_ <> nil) then
    HasBoundaryProgress := TryResolveSongLyricsLineBoundaryProgress(
      SongLine, Video^.Object_^.Frame, DisplayUnitCount, SyncProgress);
  EffectivePreDisplaySeconds := Max(0.0, PreDisplayTimeItem.Value);
  MusicOffsetSeconds := EnsureRange(MusicOffsetItem.Value, -5.0, 5.0);
  EffectiveSyncText := '';
  if Assigned(SyncDataItem.Value) then
    EffectiveSyncText := string(SyncDataItem.Value);
  if HasSongLine then
    EffectiveSyncText := SongLine.SyncText;
  if HasFrameState then
  begin
    CurrentSyncSeconds := ObjectSecondsToMusicSeconds(
      FrameState.TimeSeconds, MusicOffsetSeconds);
    SyncStartSeconds := ObjectSecondsToMusicSeconds(
      ObjectStartSeconds + EffectivePreDisplaySeconds,
      MusicOffsetSeconds);
    if HasSongLine and (Video <> nil) and
      (Video^.Object_ <> nil) and (FrameState.Rate > 0) then
    begin
      CurrentSyncSeconds := ObjectSecondsToMusicSeconds(
        SongStartSeconds + Video^.Object_^.Frame *
        FrameState.Scale / FrameState.Rate,
        MusicOffsetSeconds);
      SyncStartSeconds := ObjectSecondsToMusicSeconds(
        0, MusicOffsetSeconds);
    end;
    HasSyncData := TryParseSyncText(EffectiveSyncText, SyncData);
    if not HasBoundaryProgress and HasSyncData then
      case SyncData.Mode of
        smMusic:
          if HasSongLine then
            ResolveAdjustedMusicSyncProgressWithOffset(MusicFileName,
              Track, SyncStartSeconds, CurrentSyncSeconds,
              SongLine.StartNoteIndex, DisplayUnitCount,
              SyncData.MusicStages, SyncProgress)
          else
            ResolveAdjustedMusicSyncProgress(MusicFileName, Track,
              SyncStartSeconds, CurrentSyncSeconds, DisplayUnitCount,
              SyncData.MusicStages, SyncProgress);
        smManual:
          ResolveManualSyncProgress(CurrentSyncSeconds,
            DisplayUnitCount, SyncData.ManualBoundaries, SyncProgress);
      end;
    if HasSongLine and (Video <> nil) and (Video^.Object_ <> nil) and
      (FrameState.Rate > 0) and (FrameState.Scale > 0) and
      (SongLine.SyncEndFrame >= 0) and
      (SongLine.DisplayEndFrame > SongLine.SyncEndFrame) and
      (Video^.Object_^.Frame >= SongLine.SyncEndFrame) then
    begin
      LastStageDuration := 0.3;
      if HasSyncData then
        case SyncData.Mode of
          smMusic:
            if not TryResolveMusicSyncLastStageDuration(MusicFileName,
              Track, SyncStartSeconds, SongLine.StartNoteIndex,
              DisplayUnitCount, SyncData.MusicStages,
              LastStageDuration) then
              LastStageDuration := 0.3;
          smManual:
            if Length(SyncData.ManualBoundaries) >= 2 then
              LastStageDuration :=
                SyncData.ManualBoundaries[High(SyncData.ManualBoundaries)] -
                SyncData.ManualBoundaries[High(SyncData.ManualBoundaries) - 1];
        end;
      HoldDurationSeconds :=
        (SongLine.DisplayEndFrame - SongLine.SyncEndFrame) *
        FrameState.Scale / FrameState.Rate;
      EffectiveRestoreDuration := Min(HoldDurationSeconds,
        EnsureRange(LastStageDuration, 0.15, 0.60));
      RestoreElapsedSeconds :=
        (Video^.Object_^.Frame - SongLine.SyncEndFrame) *
        FrameState.Scale / FrameState.Rate;
      if EffectiveRestoreDuration <= 0.000001 then
        RenderSettings.CompletionRestoreProgress := 1
      else
        RenderSettings.CompletionRestoreProgress := EnsureRange(
          RestoreElapsedSeconds / EffectiveRestoreDuration, 0.0, 1.0);
    end;
    if (Video <> nil) and (Video^.Object_ <> nil) and
      (FrameState.Rate > 0) then
    begin
      LocalSeconds := Video^.Object_^.Frame *
        FrameState.Scale / FrameState.Rate;
      RemainingSeconds := Max(0,
        Video^.Object_^.FrameTotal - 1 - Video^.Object_^.Frame) *
        FrameState.Scale / FrameState.Rate;
      if HasSongLine and (SongLine.DisplayStartFrame >= 0) then
        LocalSeconds := Max(0,
          Video^.Object_^.Frame - SongLine.DisplayStartFrame) *
          FrameState.Scale / FrameState.Rate;
      if HasSongLine and (SongLine.DisplayEndFrame >= 0) then
        RemainingSeconds := Max(0,
          SongLine.DisplayEndFrame - Video^.Object_^.Frame) *
          FrameState.Scale / FrameState.Rate;
      AnimationSettings.SyncAnimation := CurrentSerifSyncAnimation;
      AnimationSettings.StartAnimation := CurrentSerifStartAnimation;
      AnimationSettings.EndAnimation := CurrentSerifEndAnimation;
      AnimationSettings.StartDurationSeconds :=
        CurrentSerifStartAnimationDuration;
      AnimationSettings.EndDurationSeconds :=
        CurrentSerifEndAnimationDuration;
      AnimationSettings.BaseFontHeight :=
        RenderSettings.BaseFontHeight;
      AnimationSettings.StartDirection := SerifBeforeDirectionItem.Value;
      AnimationSettings.StartZoomOrigin :=
        SerifBeforeZoomOriginItem.Value;
      AnimationSettings.EndDirection := SerifAfterDirectionItem.Value;
      AnimationSettings.EndZoomDestination :=
        SerifAfterZoomDestinationItem.Value;
      ResolveLyricsAnimationTransform(AnimationSettings, LocalSeconds,
        RemainingSeconds, SyncProgress, AnimationTransform);
      AnimationOpacity := AnimationTransform.Opacity;
      AnimationOffsetY := 0;
      RenderSettings.LayerOffsetX := AnimationTransform.OffsetX;
      RenderSettings.LayerOffsetY := AnimationTransform.OffsetY;
      RenderSettings.LayerScaleX := AnimationTransform.ScaleX;
      RenderSettings.LayerScaleY := AnimationTransform.ScaleY;
      RenderSettings.LayerRotationDegrees :=
        AnimationTransform.RotationDegrees;
      RenderSettings.LayerBlurRadius := AnimationTransform.BlurRadius;
      RenderSettings.LayerWipeDirection := AnimationTransform.WipeDirection;
      RenderSettings.LayerWipeProgress := AnimationTransform.WipeProgress;
    end;
  end;
  RenderSettings.Opacity := AnimationOpacity;
  if HasFreePlacement then
    DrawFreePlacementLyricsLayer(Buffer, RenderWidth, RenderHeight,
      PWideChar(LyricsText), SyncProgress, RenderSettings, PlacementItems,
      CommonSettings.PositionX,
      CommonSettings.PositionY + AnimationOffsetY)
  else
    DrawLyricsLayer(Buffer, RenderWidth, RenderHeight,
      PWideChar(LyricsText), SyncProgress, RenderSettings,
      CommonSettings.PositionX,
      CommonSettings.PositionY + AnimationOffsetY);
end;

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  ActiveSongLine: TLyricsSongLine;
  ActiveSongLineIndex: Integer;
  AnimationOffsetY: Integer;
  AnimationOpacity: Double;
  AnimationSettings: TLyricsAnimationSettings;
  AnimationTransform: TLyricsAnimationTransform;
  CommonSettings: TDisplayCommonSettings;
  DisplayUnitCount: Integer;
  EffectivePreDisplaySeconds: Double;
  EffectiveSyncText: string;
  FrameState: TSyncLyricsFrameState;
  HasFreePlacement: Boolean;
  HasSongData: Boolean;
  HasSongLine: Boolean;
  LyricsText: string;
  MusicFileName: string;
  MusicOffsetSeconds: Double;
  LocalSeconds: Double;
  ObjectStartFrame: Integer;
  ObjectStartSeconds: Double;
  RenderSettings: TLyricsRenderSettings;
  RemainingSeconds: Double;
  SongLines: TLyricsSongLines;
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
    SelectedPlacementMode := PLACEMENT_MODE_LINE;
    RenderSettings.DisplayType := TLyricsDisplayType(
      EnsureRange(DisplayEffectItem.Value,
        Ord(Low(TLyricsDisplayType)), Ord(High(TLyricsDisplayType))));
    LyricsText := '';
    if Assigned(LyricsItem.Value) then
      LyricsText := string(LyricsItem.Value);
    HasSongData := False;
    HasSongLine := False;
    SongLines := nil;
    if Assigned(SongDocumentItem.Value) then
      HasSongData := TryGetSongLyricsLines(
        string(SongDocumentItem.Value), SongLines);
    if HasSongData then
    begin
      ActiveSongLineIndex := -1;
      if (Video <> nil) and (Video^.Object_ <> nil) then
        ActiveSongLineIndex := ResolveSongLyricsLineIndex(
          SongLines, Video^.Object_^.Frame);
      HasSongLine := (ActiveSongLineIndex >= 0) and
        (ActiveSongLineIndex < Length(SongLines));
      if HasSongLine then
      begin
        ActiveSongLine := SongLines[ActiveSongLineIndex];
        LyricsText := ActiveSongLine.SourceText;
      end
      else
        LyricsText := '';
    end;
    CommonSettings := DefaultDisplayCommonSettings;
    PlacementItems := nil;
    PlacementsMatchLyrics := False;
    if Assigned(DisplaySettingsTextItem.Value) then
      TryDecodeDisplaySettingsText(string(DisplaySettingsTextItem.Value),
        LyricsText, CommonSettings, PlacementItems,
        PlacementsMatchLyrics);
    if HasSongLine then
      Inc(CommonSettings.PositionY, (ActiveSongLine.DisplayLane - 2) *
        (CommonSettings.BaseFontHeight +
         CommonSettings.RubyFontHeight + 16));
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
    ApplyDisplayDecoration(CommonSettings, RenderSettings);
    ApplySerifSyncStyle(RenderSettings);
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
    EffectivePreDisplaySeconds := Max(0.0, PreDisplayTimeItem.Value);
    MusicOffsetSeconds := EnsureRange(MusicOffsetItem.Value, -5.0, 5.0);
    EffectiveSyncText := '';
    if Assigned(SyncDataItem.Value) then
      EffectiveSyncText := string(SyncDataItem.Value);
    if HasSongLine then
    begin
      EffectiveSyncText := ActiveSongLine.SyncText;
    end;
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
          Video^.Object_^.FrameE, ObjectStartFrame,
          Video^.Object_^.Frame, FrameState.Rate, FrameState.Scale);
      end;
      SyncStartSeconds := ObjectSecondsToMusicSeconds(
        ObjectStartSeconds + EffectivePreDisplaySeconds,
        MusicOffsetSeconds);
      if TryParseSyncText(EffectiveSyncText, SyncData) then
        case SyncData.Mode of
          smMusic:
            if HasSongLine then
              ResolveAdjustedMusicSyncProgressWithOffset(MusicFileName,
                Track, ObjectSecondsToMusicSeconds(
                  EffectivePreDisplaySeconds, MusicOffsetSeconds),
                ObjectSecondsToMusicSeconds(Video^.Object_^.Frame *
                  FrameState.Scale / FrameState.Rate,
                  MusicOffsetSeconds),
                ActiveSongLine.StartNoteIndex, DisplayUnitCount,
                SyncData.MusicStages, SyncProgress)
            else
              ResolveAdjustedMusicSyncProgress(MusicFileName, Track,
                SyncStartSeconds, ObjectSecondsToMusicSeconds(
                  FrameState.TimeSeconds, MusicOffsetSeconds),
                DisplayUnitCount,
                SyncData.MusicStages, SyncProgress);
          smManual:
            ResolveManualSyncProgress(ObjectSecondsToMusicSeconds(
              FrameState.TimeSeconds, MusicOffsetSeconds),
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
        if HasSongLine and (ActiveSongLine.DisplayStartFrame >= 0) then
          LocalSeconds := Max(0,
            Video^.Object_^.Frame - ActiveSongLine.DisplayStartFrame) *
            FrameState.Scale / FrameState.Rate;
        if HasSongLine and (ActiveSongLine.DisplayEndFrame >= 0) then
          RemainingSeconds := Max(0,
            ActiveSongLine.DisplayEndFrame -
            Video^.Object_^.Frame) *
            FrameState.Scale / FrameState.Rate;
        AnimationSettings.SyncAnimation := CurrentSerifSyncAnimation;
        AnimationSettings.StartAnimation := CurrentSerifStartAnimation;
        AnimationSettings.EndAnimation := CurrentSerifEndAnimation;
        AnimationSettings.StartDurationSeconds :=
          CurrentSerifStartAnimationDuration;
        AnimationSettings.EndDurationSeconds :=
          CurrentSerifEndAnimationDuration;
        AnimationSettings.BaseFontHeight :=
          RenderSettings.BaseFontHeight;
        AnimationSettings.StartDirection := SerifBeforeDirectionItem.Value;
        AnimationSettings.StartZoomOrigin :=
          SerifBeforeZoomOriginItem.Value;
        AnimationSettings.EndDirection := SerifAfterDirectionItem.Value;
        AnimationSettings.EndZoomDestination :=
          SerifAfterZoomDestinationItem.Value;
        ResolveLyricsAnimationTransform(AnimationSettings, LocalSeconds,
          RemainingSeconds, SyncProgress, AnimationTransform);
        AnimationOpacity := AnimationTransform.Opacity;
        AnimationOffsetY := 0;
        RenderSettings.LayerOffsetX := AnimationTransform.OffsetX;
        RenderSettings.LayerOffsetY := AnimationTransform.OffsetY;
        RenderSettings.LayerScaleX := AnimationTransform.ScaleX;
        RenderSettings.LayerScaleY := AnimationTransform.ScaleY;
        RenderSettings.LayerRotationDegrees :=
          AnimationTransform.RotationDegrees;
        RenderSettings.LayerBlurRadius := AnimationTransform.BlurRadius;
        RenderSettings.LayerWipeDirection :=
          AnimationTransform.WipeDirection;
        RenderSettings.LayerWipeProgress :=
          AnimationTransform.WipeProgress;
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

function LyricsProcVideoMulti(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
var
  ActiveIndexes: TLyricsSongLineIndexes;
  Buffer: PPIXEL_RGBA;
  FrameState: TSyncLyricsFrameState;
  HasFrameState: Boolean;
  Height: Integer;
  I: Integer;
  LanePlacementTexts: TLyricsLanePlacementTexts;
  MusicFileName: string;
  MusicOffsetSeconds: Double;
  PlacementMode: TLyricsPlacementMode;
  ObjectStartFrame: Integer;
  ObjectStartSeconds: Double;
  SelectedPlacementMode: Integer;
  SongDataText: string;
  SongLines: TLyricsSongLines;
  SongStartFrame: Int64;
  SongStartSeconds: Double;
  StartLineID: Int64;
  PixelCount: NativeInt;
  Track: Integer;
  Width: Integer;
begin
  Buffer := nil;
  try
    try
      SongDataText := '';
      if Assigned(SongDocumentItem.Value) then
        SongDataText := string(SongDocumentItem.Value);
      if (SongDataText = '') or
        not TryGetSongLyricsDocument(SongDataText, SongLines,
          StartLineID, LanePlacementTexts, PlacementMode) then
        Exit(LyricsProcVideo(Video));

      CaptureLastFrame(Video);
      if not TryGetLyricsRenderSize(Video, Width, Height) then
        Exit(1);
      PixelCount := NativeInt(Width) * Height;
      GetMem(Buffer, PixelCount * SizeOf(TPIXEL_RGBA));
      InitializeLyricsRenderBuffer(Video, Buffer, PixelCount);
      HasFrameState := TryGetLyricsFrameState(Video, FrameState);
      MusicOffsetSeconds := EnsureRange(MusicOffsetItem.Value, -5.0, 5.0);
      if HasFrameState then
      begin
        SongLines := ApplyMusicOffsetToSongLyricsLines(SongLines,
          MusicOffsetSeconds, FrameState.Rate, FrameState.Scale);
        SongLines := ApplyDisplayDurationsToSongLyricsLines(SongLines,
          Max(0.0, PreDisplayTimeItem.Value),
          Max(0.0, HoldTimeItem.Value),
          FrameState.Rate, FrameState.Scale);
      end;
      SongLines := AlignSongLyricsLinesToStartLine(SongLines,
        StartLineID, SongStartFrame);
      SongStartSeconds := 0;
      if HasFrameState then
        SongStartSeconds := SongStartFrame *
          FrameState.Scale / FrameState.Rate;
      ObjectStartSeconds := 0;
      if HasFrameState then
        ObjectStartSeconds := FrameState.TimeSeconds;
      if HasFrameState and (Video <> nil) and
        (Video^.Object_ <> nil) and (FrameState.Rate > 0) then
      begin
        ObjectStartFrame := FrameState.Frame - Video^.Object_^.Frame;
        ObjectStartSeconds := ObjectStartSeconds -
          Video^.Object_^.Frame * FrameState.Scale / FrameState.Rate;
        RecordMusicSyncAnchor(Video^.Object_^.ID,
          Video^.Object_^.EffectID, Video^.Object_^.Layer,
          Video^.Object_^.FrameS, Video^.Object_^.FrameE,
          ObjectStartFrame, Video^.Object_^.Frame,
          FrameState.Rate, FrameState.Scale);
      end;

      SetLength(ActiveIndexes, 0);
      if (Video <> nil) and (Video^.Object_ <> nil) then
        ActiveIndexes := ResolveSongLyricsLineIndexes(SongLines,
          Video^.Object_^.Frame);
      MusicFileName := '';
      if Assigned(MusicFileItem.Value) then
        MusicFileName := string(MusicFileItem.Value);
      Track := Round(TrackItem.Value);
      SelectedPlacementMode := Ord(PlacementMode);
      for I := 0 to High(ActiveIndexes) do
        if (ActiveIndexes[I] >= 0) and
          (ActiveIndexes[I] < Length(SongLines)) then
          RenderLyricsLine(Video, FrameState, HasFrameState,
            ObjectStartSeconds, SongStartSeconds, MusicFileName, Track,
            SelectedPlacementMode,
            SongLines[ActiveIndexes[I]].SourceText, True,
            SongLines[ActiveIndexes[I]],
            LanePlacementTexts[EnsureRange(
              SongLines[ActiveIndexes[I]].DisplayLane, 1, 3)],
            Buffer, Width, Height);
      Video^.SetImageData(Buffer, Width, Height);
    except
      // Delphi例外をAviUtl2のコールバック境界より外へ漏らさない。
    end;
  finally
    if Buffer <> nil then
      FreeMem(Buffer);
  end;
  Result := 1;
end;

function GetLyricsFilterTable: PFILTER_PLUGIN_TABLE;
begin
  if Plugin.Items = nil then
  begin
    // AviUtl2はnil終端された項目ポインター配列を参照する。
    InitializeSerifAnimationItems;
    PluginItems[0] := @MusicFileItem;
    PluginItems[1] := @TrackItem;
    PluginItems[2] := @MusicOffsetItem;
    PluginItems[3] := @MusicSyncSettingsButton;
    PluginItems[4] := @DisplayEffectItem;
    PluginItems[5] := @DisplaySettingsButton;
    PluginItems[6] := @SerifBeforeGroup;
    PluginItems[7] := @PreDisplayTimeItem;
    PluginItems[8] := @SerifBeforeTypeItem;
    PluginItems[9] := @SerifBeforeDirectionItem;
    PluginItems[10] := @SerifBeforeZoomOriginItem;
    PluginItems[11] := @SerifBeforeTimeItem;
    PluginItems[12] := @SerifDuringGroup;
    PluginItems[13] := @SerifDuringEmotionItem;
    PluginItems[14] := @SerifDuringSpeedItem;
    PluginItems[15] := @SerifSyncGroup;
    PluginItems[16] := @SerifSyncTypeItem;
    PluginItems[17] := @SerifSyncFillItem;
    PluginItems[18] := @SerifSyncAfterItem;
    PluginItems[19] := @SerifSyncShapeItem;
    PluginItems[20] := @SerifSyncColorItem;
    PluginItems[21] := @SerifSyncSizeItem;
    PluginItems[22] := @SerifSyncOffsetXItem;
    PluginItems[23] := @SerifSyncOffsetYItem;
    PluginItems[24] := @SerifAfterGroup;
    PluginItems[25] := @HoldTimeItem;
    PluginItems[26] := @SerifAfterTypeItem;
    PluginItems[27] := @SerifAfterDirectionItem;
    PluginItems[28] := @SerifAfterZoomDestinationItem;
    PluginItems[29] := @SerifAfterTimeItem;
    PluginItems[30] := @SongDocumentItem;
    PluginItems[31] := @DisplaySettingsTextItem;
    PluginItems[32] := nil;
    Plugin.Items := @PluginItems[0];
  end;
  Result := @Plugin;
end;

procedure InitializeLyricsFilter;
begin
  InitializeLastFrameCapture;
  InitializeSongLyricsRuntime;
  InitializeMusicSyncAnchor;
  InitializeMusicSync;
  InitializeLyricsRenderer;
end;

procedure FinalizeLyricsFilter;
begin
  FinalizeLyricsRenderer;
  FinalizeMusicSync;
  FinalizeMusicSyncAnchor;
  FinalizeSongLyricsRuntime;
  FinalizeLastFrameCapture;
end;

end.
