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
  SYNC_Lyrics_FontSettingsForm,
  SYNC_Lyrics_FrameShared,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_MusicSync,
  SYNC_Lyrics_Renderer,
  SYNC_Lyrics_Time,
  Vcl.Dialogs,
  Vcl.Forms;

function LyricsProcVideo(Video: PFILTER_PROC_VIDEO): Byte; cdecl; forward;
procedure FontSettingsButtonCallback(Edit: PEDIT_SECTION); cdecl; forward;

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
      '音楽ファイル (*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz)'#0 +
      '*.mid;*.midi;*.ust;*.vsq;*.vsqx;*.musicxml;*.mxl;*.xml;*.mscx;*.mscz'#0#0
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
  RubyFontItem: TFILTER_ITEM_STRING = (
    ItemType: 'string';
    Name: 'フォント名（ルビ）';
    Value: 'Yu Gothic UI'
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
  PluginItems: array[0..15] of Pointer;
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

procedure ShowFontSettingsError(const MessageText: string);
begin
  MessageDlg(MessageText, mtError, [mbOK], 0);
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
  DisplayUnitCount: Integer;
  FrameState: TSyncLyricsFrameState;
  LyricsText: string;
  MusicFileName: string;
  ObjectStartSeconds: Double;
  RenderSettings: TLyricsRenderSettings;
  SyncStartSeconds: Double;
  SyncProgress: Double;
  Track: Integer;
begin
  try
    RenderSettings := DefaultLyricsRenderSettings;
    if Assigned(BaseFontItem.Value) then
      RenderSettings.BaseFontName := string(BaseFontItem.Value);
    if Assigned(RubyFontItem.Value) then
      RenderSettings.RubyFontName := string(RubyFontItem.Value);
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
        ObjectStartSeconds := ObjectStartSeconds -
          Video^.Object_^.Frame * FrameState.Scale / FrameState.Rate;
      SyncStartSeconds := ObjectStartSeconds +
        Max(0.0, PreDisplayTimeItem.Value);
      ResolveMusicSyncProgressForUnits(MusicFileName, Track, SyncStartSeconds,
        FrameState.TimeSeconds, DisplayUnitCount, SyncProgress);
    end;
    RenderLyrics(Video, PWideChar(LyricsText), SyncProgress, RenderSettings,
      Round(PositionXItem.Value), Round(PositionYItem.Value));
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
    PluginItems[0] := @LyricsItem;
    PluginItems[1] := @MusicFileItem;
    PluginItems[2] := @TrackItem;
    PluginItems[3] := @PositionXItem;
    PluginItems[4] := @PositionYItem;
    PluginItems[5] := @FontSettingsButton;
    PluginItems[6] := @BaseFontItem;
    PluginItems[7] := @RubyFontItem;
    PluginItems[8] := @BeforeColorItem;
    PluginItems[9] := @AfterColorItem;
    PluginItems[10] := @BaseFontSizeItem;
    PluginItems[11] := @RubyFontSizeItem;
    PluginItems[12] := @RubyGapAdjustmentItem;
    PluginItems[13] := @BaseCharacterSpacingItem;
    PluginItems[14] := @PreDisplayTimeItem;
    PluginItems[15] := nil;
    Plugin.Items := @PluginItems[0];
  end;
  Result := @Plugin;
end;

procedure InitializeLyricsFilter;
begin
  InitializeLyricsFrameShared;
  InitializeLyricsContexts;
  InitializeMusicSync;
  InitializeLyricsRenderer;
end;

procedure FinalizeLyricsFilter;
begin
  FinalizeLyricsRenderer;
  FinalizeMusicSync;
  FinalizeLyricsContexts;
  FinalizeLyricsFrameShared;
end;

end.
