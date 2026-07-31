program SYNC_Lyrics_MusicSyncTests;

// SongReader経由の音楽ファイル読込と、区間内ノート消費数を検証する。

{$APPTYPE CONSOLE}

uses
  System.IOUtils,
  System.SysUtils,
  System.Types,
  Vcl.Graphics,
  Winapi.Windows,
  SYNC_Lyrics_ToolbarButtons in
    'Source\Lib\SYNC_Lyrics_ToolbarButtons.pas',
  RTTIPersistent in 'Source\Lib\SongReader\RTTIPersistent.pas',
  RTTIPersistentIni in 'Source\Lib\SongReader\RTTIPersistentIni.pas',
  SectionFileManager in 'Source\Lib\SongReader\SectionFileManager.pas',
  TextEncodingUtils in 'Source\Lib\SongReader\TextEncodingUtils.pas',
  SongAIUEO in 'Source\Lib\SongReader\SongAIUEO.pas',
  SongDataInfo in 'Source\Lib\SongReader\SongDataInfo.pas',
  SongDataNote in 'Source\Lib\SongReader\SongDataNote.pas',
  SongDataTempo in 'Source\Lib\SongReader\SongDataTempo.pas',
  SongDataTrack in 'Source\Lib\SongReader\SongDataTrack.pas',
  SongData in 'Source\Lib\SongReader\SongData.pas',
  SongReader in 'Source\Lib\SongReader\SongReader.pas',
  SongReaderSMF in 'Source\Lib\SongReader\SongReaderSMF.pas',
  SongReaderUST in 'Source\Lib\SongReader\SongReaderUST.pas',
  SongReaderVSQX in 'Source\Lib\SongReader\SongReaderVSQX.pas',
  SongReaderMusicXML in 'Source\Lib\SongReader\SongReaderMusicXML.pas',
  SongReaderMusicMSC in 'Source\Lib\SongReader\SongReaderMusicMSC.pas',
  SongReaderMusicMSCZ in 'Source\Lib\SongReader\SongReaderMusicMSCZ.pas',
  SongReaderManager in 'Source\Lib\SongReader\SongReaderManager.pas',
  SYNC_Lyrics_LyricParser in 'Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_SongLyricsModel in
    'Source\Common\Lyrics\SYNC_Lyrics_SongLyricsModel.pas',
  SYNC_Lyrics_DisplaySettingsData in
    'Source\Common\Render\SYNC_Lyrics_DisplaySettingsData.pas',
  SYNC_Lyrics_DisplayPresetData in
    'Source\Common\Render\SYNC_Lyrics_DisplayPresetData.pas',
  SYNC_Lyrics_CharacterLayoutInteraction in
    'Source\Plugin\Filter\SYNC_Lyrics_CharacterLayoutInteraction.pas',
  SYNC_Lyrics_SyncFormat in 'Source\Common\Sync\SYNC_Lyrics_SyncFormat.pas',
  SYNC_Lyrics_SyncSourceKind in
    'Source\Common\Sync\SYNC_Lyrics_SyncSourceKind.pas',
  SYNC_Lyrics_ManualSync in
    'Source\Common\Sync\SYNC_Lyrics_ManualSync.pas',
  SYNC_Lyrics_ManualSyncEditModel in
    'Source\Common\Sync\SYNC_Lyrics_ManualSyncEditModel.pas',
  SYNC_Lyrics_MusicSyncAnchor in
    'Source\Common\Sync\SYNC_Lyrics_MusicSyncAnchor.pas',
  SYNC_Lyrics_MusicSync in 'Source\Common\Sync\SYNC_Lyrics_MusicSync.pas',
  SYNC_Lyrics_MusicSyncPianoRoll in
    'Source\Plugin\Filter\SYNC_Lyrics_MusicSyncPianoRoll.pas',
  SYNC_Lyrics_MusicSyncEditModel in
    'Source\Plugin\Filter\SYNC_Lyrics_MusicSyncEditModel.pas',
  SYNC_Lyrics_TimeRuler in
    'Source\Plugin\Filter\SYNC_Lyrics_TimeRuler.pas';

const
  TEST_MIDI: array[0..50] of Byte = (
    $4D, $54, $68, $64, $00, $00, $00, $06, $00, $00, $00, $01, $01, $E0,
    $4D, $54, $72, $6B, $00, $00, $00, $1D,
    $00, $FF, $51, $03, $07, $A1, $20,
    $00, $90, $3C, $64,
    $83, $60, $80, $3C, $00,
    $00, $90, $3E, $64,
    $83, $60, $80, $3E, $00,
    $00, $FF, $2F, $00
  );

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

{$IFDEF LEGACY_DISPLAY_DATA_TEST}
procedure TestDisplaySettingsData;
var
  Data: TDisplaySettingsData;
  DecodedItems: TDisplayPlacementItems;
  I: Integer;
  Items: TDisplayPlacementItems;
  LegacyItems: TDisplayPlacementItems;
  OversizedItems: TDisplayPlacementItems;
begin
  Check(SizeOf(TDisplaySettingsData) = DISPLAY_SETTINGS_DATA_SIZE,
    'display settings data ABI size mismatch');
  SetLength(Items, 2);
  Items[0].Index := 0;
  Items[0].X := 12.5;
  Items[0].Y := -8;
  Items[0].ScaleX := 1.25;
  Items[0].ScaleY := 0.75;
  Items[0].BaseFontName := 'Meiryo';
  Items[0].RubyFontName := 'Yu Gothic UI';
  Items[0].HasBeforeColor := True;
  Items[0].BeforeColor := $0038220C;
  Items[0].HasAfterColor := True;
  Items[0].AfterColor := $007B5A4E;
  Items[0].HasBaseFontHeight := True;
  Items[0].BaseFontHeight := 144;
  Items[0].HasRubyFontHeight := True;
  Items[0].RubyFontHeight := 60;
  Items[0].HasBaseFontStyle := True;
  Items[0].BaseFontStyle := 1 or 2;
  Items[0].HasRubyFontStyle := True;
  Items[0].RubyFontStyle := 4 or 8;
  Items[0].HasBaseCharacterSpacing := True;
  Items[0].BaseCharacterSpacing := -11;
  Items[0].HasRubyCharacterSpacing := True;
  Items[0].RubyCharacterSpacing := 17;
  Items[0].HasRubyOffsetX := True;
  Items[0].RubyOffsetX := 9;
  Items[0].HasRubyOffsetY := True;
  Items[0].RubyOffsetY := -6;
  Items[1].Index := 1;
  Items[1].X := -20;
  Items[1].Y := 40.25;
  Items[1].ScaleX := 1;
  Items[1].ScaleY := 2;
  Check(TryEncodeDisplayPlacements('私[漢字](かんじ)', Items, Data),
    'display placements could not be encoded');
  Check(TryDecodeDisplayPlacements(Data, '私[漢字](かんじ)', 2,
    DecodedItems), 'display placements could not be decoded');
  Check((Length(DecodedItems) = 2) and
    (Abs(DecodedItems[0].X - 12) < 0.001) and
    (Abs(DecodedItems[1].Y - 40) < 0.001) and
    (Abs(DecodedItems[0].ScaleX - 1.25) < 0.001) and
    (Abs(DecodedItems[1].ScaleY - 2) < 0.001) and
    SameText(DecodedItems[0].BaseFontName, 'Meiryo') and
    SameText(DecodedItems[0].RubyFontName, 'Yu Gothic UI') and
    DecodedItems[0].HasBeforeColor and
    (DecodedItems[0].BeforeColor = $0038220C) and
    DecodedItems[0].HasAfterColor and
    (DecodedItems[0].AfterColor = $007B5A4E) and
    DecodedItems[0].HasBaseFontHeight and
    (DecodedItems[0].BaseFontHeight = 144) and
    DecodedItems[0].HasRubyFontHeight and
    (DecodedItems[0].RubyFontHeight = 60) and
    DecodedItems[0].HasBaseFontStyle and
    (DecodedItems[0].BaseFontStyle = 3) and
    DecodedItems[0].HasRubyFontStyle and
    (DecodedItems[0].RubyFontStyle = 12) and
    DecodedItems[0].HasBaseCharacterSpacing and
    (DecodedItems[0].BaseCharacterSpacing = -11) and
    DecodedItems[0].HasRubyCharacterSpacing and
    (DecodedItems[0].RubyCharacterSpacing = 17) and
    DecodedItems[0].HasRubyOffsetX and
    (DecodedItems[0].RubyOffsetX = 9) and
    DecodedItems[0].HasRubyOffsetY and
    (DecodedItems[0].RubyOffsetY = -6) and
    (DecodedItems[1].BaseFontName = '') and
    (DecodedItems[1].RubyFontName = '') and
    not DecodedItems[1].HasBeforeColor and
    not DecodedItems[1].HasAfterColor and
    not DecodedItems[1].HasBaseFontHeight and
    not DecodedItems[1].HasRubyFontHeight and
    not DecodedItems[1].HasBaseFontStyle and
    not DecodedItems[1].HasRubyFontStyle and
    not DecodedItems[1].HasBaseCharacterSpacing and
    not DecodedItems[1].HasRubyCharacterSpacing and
    not DecodedItems[1].HasRubyOffsetX and
    not DecodedItems[1].HasRubyOffsetY,
    'display placement coordinates did not round-trip');
  Check(not TryDecodeDisplayPlacements(Data, '変更後', 2,
    DecodedItems), 'placements survived a lyrics change');

  SetLength(LegacyItems, 1);
  LegacyItems[0].Index := 0;
  LegacyItems[0].ScaleX := 1;
  LegacyItems[0].ScaleY := 1;
  Check(TryEncodeDisplayPlacements('legacy-v9', LegacyItems, Data),
    'legacy-v9 base data could not be encoded');
  Data.Version := 9;
  Data.Payload[14] := 1;
  Data.Payload[15] := 23;
  Data.Payload[16] := 0;
  Data.Payload[17] := 1;
  Check(TryDecodeDisplayPlacements(Data, 'legacy-v9', 1,
    DecodedItems) and DecodedItems[0].HasRubyCharacterSpacing and
    (DecodedItems[0].RubyCharacterSpacing = 23),
    'version 9 ruby spacing did not remain backward compatible');

  Check(TryEncodeDisplayPlacements('legacy-v10', LegacyItems, Data),
    'legacy-v10 base data could not be encoded');
  Data.Version := 10;
  Data.Payload[14] := 1;
  Data.Payload[15] := 1;
  Data.Payload[16] := 19;
  Data.Payload[17] := 0;
  Data.Payload[18] := 0;
  Data.Payload[19] := 0;
  Data.Payload[20] := 0;
  Data.Payload[21] := 0;
  Data.Payload[22] := 1;
  Check(TryDecodeDisplayPlacements(Data, 'legacy-v10', 1,
    DecodedItems) and
    not DecodedItems[0].HasBaseCharacterSpacing and
    DecodedItems[0].HasRubyCharacterSpacing and
    (DecodedItems[0].RubyCharacterSpacing = 19),
    'version 10 interaction data did not remain backward compatible');

  Items := nil;
  SetLength(Items, MAX_DISPLAY_PLACEMENT_ITEMS);
  for I := 0 to High(Items) do
  begin
    Items[I].Index := I;
    Items[I].X := I;
    Items[I].Y := -I;
    Items[I].ScaleX := 1;
    Items[I].ScaleY := 1;
    if not Odd(I) then
    begin
      Items[I].BaseFontName := 'Meiryo';
      Items[I].RubyFontName := 'Yu Gothic UI';
      Items[I].HasBeforeColor := True;
      Items[I].BeforeColor := $001E140A;
      Items[I].HasAfterColor := True;
      Items[I].AfterColor := $003C3228;
      Items[I].HasBaseFontHeight := True;
      Items[I].BaseFontHeight := 128;
      Items[I].HasRubyFontHeight := True;
      Items[I].RubyFontHeight := 48;
      Items[I].HasBaseFontStyle := True;
      Items[I].BaseFontStyle := 1;
      Items[I].HasRubyFontStyle := True;
      Items[I].RubyFontStyle := 2;
    end;
  end;
  Check(TryEncodeDisplayPlacements('maximum', Items, Data),
    'maximum placements with shared fonts could not be encoded');
  Check(TryDecodeDisplayPlacements(Data, 'maximum',
    MAX_DISPLAY_PLACEMENT_ITEMS, DecodedItems) and
    SameText(DecodedItems[98].BaseFontName, 'Meiryo') and
    DecodedItems[98].HasBeforeColor and
    (DecodedItems[98].BeforeColor = $001E140A) and
    DecodedItems[98].HasBaseFontHeight and
    (DecodedItems[98].BaseFontHeight = 128) and
    DecodedItems[98].HasBaseFontStyle and
    (DecodedItems[98].BaseFontStyle = 1) and
    (DecodedItems[99].BaseFontName = '') and
    not DecodedItems[99].HasBeforeColor and
    not DecodedItems[99].HasBaseFontHeight and
    not DecodedItems[99].HasBaseFontStyle and
    not DecodedItems[99].HasBaseCharacterSpacing and
    not DecodedItems[99].HasRubyCharacterSpacing and
    not DecodedItems[99].HasRubyOffsetX and
    not DecodedItems[99].HasRubyOffsetY,
    'maximum placements with sparse shared styles did not round-trip');

  SetLength(OversizedItems, MAX_DISPLAY_PLACEMENT_ITEMS + 1);
  Check(not TryEncodeDisplayPlacements('oversized', OversizedItems, Data),
    'oversized display placement list was accepted');
end;

{$ENDIF}

procedure TestDisplaySettingsData;
var
  Common: TDisplayCommonSettings;
  DecodedCommon: TDisplayCommonSettings;
  DecodedItems: TDisplayPlacementItems;
  I: Integer;
  Items: TDisplayPlacementItems;
  OversizedItems: TDisplayPlacementItems;
  PlacementsMatchLyrics: Boolean;
  SettingsText: string;
begin
  Common := DefaultDisplayCommonSettings;
  Common.PositionX := 123;
  Common.PositionY := -45;
  Common.BaseFontName := '游ゴシック';
  Common.RubyFontName := 'Yu Gothic UI';
  Common.BaseFontHeight := 88;
  Common.RubyFontHeight := 36;
  Common.BaseFontStyle := 2 or 4;
  Common.RubyFontStyle := 1;
  Common.BeforeColor := $001E140A;
  Common.AfterColor := $003C3228;
  Common.RubyGapAdjustment := 12;
  Common.BaseCharacterSpacing := -3;
  Common.RubyCharacterSpacing := 5;
  SetLength(Items, MAX_DISPLAY_PLACEMENT_ITEMS);
  for I := 0 to High(Items) do
  begin
    Items[I].Index := I;
    Items[I].X := I - 50;
    Items[I].Y := 50 - I;
    Items[I].ScaleX := 1 + I / 1000;
    Items[I].ScaleY := 1;
    Items[I].BaseFontName := '游ゴシック体-' + IntToStr(I);
    Items[I].RubyFontName := 'Yu Gothic UI';
    Items[I].HasBeforeColor := True;
    Items[I].BeforeColor := $001E140A + Cardinal(I);
    Items[I].HasAfterColor := True;
    Items[I].AfterColor := $003C3228 + Cardinal(I);
    Items[I].HasBaseFontHeight := True;
    Items[I].BaseFontHeight := 96 + I;
    Items[I].HasRubyFontHeight := True;
    Items[I].RubyFontHeight := 42;
    Items[I].HasBaseFontStyle := True;
    Items[I].BaseFontStyle := I and $0F;
    Items[I].HasRubyFontStyle := True;
    Items[I].RubyFontStyle := (I + 1) and $0F;
    Items[I].HasBaseCharacterSpacing := True;
    Items[I].BaseCharacterSpacing := I - 50;
    Items[I].HasRubyCharacterSpacing := True;
    Items[I].RubyCharacterSpacing := 50 - I;
    Items[I].HasRubyOffsetX := True;
    Items[I].RubyOffsetX := I;
    Items[I].HasRubyOffsetY := True;
    Items[I].RubyOffsetY := -I;
  end;

  Check(TryEncodeDisplaySettingsText('私[漢字](かんじ)', Common, Items,
    SettingsText), 'display settings could not be encoded as text');
  Check(Length(SettingsText) > 1024,
    'display settings text did not exercise the former 1024-byte wall');
  Check(Length(SettingsText) < MAX_DISPLAY_SETTINGS_TEXT_LENGTH,
    'maximum display settings text exceeds the default edit input limit');
  Check((Pos(#10, SettingsText) = 0) and (Pos(#13, SettingsText) = 0),
    'display settings text unexpectedly contains a line break');
  Check(TryDecodeDisplaySettingsText(SettingsText,
    '私[漢字](かんじ)', DecodedCommon, DecodedItems,
    PlacementsMatchLyrics), 'display settings text could not be decoded');
  Check(PlacementsMatchLyrics and
    (DecodedCommon.PositionX = 123) and
    (DecodedCommon.PositionY = -45) and
    SameText(DecodedCommon.BaseFontName, '游ゴシック') and
    (DecodedCommon.BaseFontHeight = 88) and
    (DecodedCommon.BaseFontStyle = 6) and
    (DecodedCommon.RubyGapAdjustment = 12) and
    (DecodedCommon.BaseCharacterSpacing = -3) and
    (DecodedCommon.RubyCharacterSpacing = 5) and
    (Length(DecodedItems) = MAX_DISPLAY_PLACEMENT_ITEMS) and
    SameText(DecodedItems[98].BaseFontName, '游ゴシック体-98') and
    SameText(DecodedItems[98].RubyFontName, 'Yu Gothic UI') and
    (Abs(DecodedItems[98].X - 48) < 0.001) and
    (Abs(DecodedItems[98].ScaleX - 1.098) < 0.001) and
    DecodedItems[98].HasBaseCharacterSpacing and
    (DecodedItems[98].BaseCharacterSpacing = 48) and
    DecodedItems[98].HasRubyOffsetY and
    (DecodedItems[98].RubyOffsetY = -98),
    'display settings text did not round-trip');
  Check(TryDecodeDisplaySettingsText(SettingsText, '変更後',
    DecodedCommon, DecodedItems, PlacementsMatchLyrics) and
    not PlacementsMatchLyrics and (DecodedCommon.PositionX = 123),
    'lyrics change did not preserve common settings and reject placements');

  SetLength(OversizedItems, MAX_DISPLAY_PLACEMENT_ITEMS + 1);
  Check(not TryEncodeDisplaySettingsText('oversized', Common,
    OversizedItems, SettingsText),
    'oversized display placement list was accepted');
end;

procedure TestDisplayPresetData;
var
  Common: TDisplayCommonSettings;
  Decoded: TDisplayPreset;
  DisplayEffect: Integer;
  EndAnimation: Integer;
  EndSeconds: Double;
  Preset: TDisplayPreset;
  PresetText: string;
  StartAnimation: Integer;
  StartSeconds: Double;
  SyncAnimation: Integer;
begin
  Common := DefaultDisplayCommonSettings;
  Common.PositionX := 321;
  Common.PositionY := -123;
  Common.BaseFontName := '游ゴシック';
  Common.RubyFontName := 'メイリオ';
  Common.BaseFontHeight := 120;
  Common.RubyFontHeight := 48;
  Common.BaseFontStyle := 3;
  Common.RubyFontStyle := 4;
  Common.BeforeColor := $00112233;
  Common.AfterColor := $00445566;
  Common.RubyGapAdjustment := 17;
  Common.BaseCharacterSpacing := -4;
  Common.RubyCharacterSpacing := 8;
  BuildDisplayPreset(Common, 2, 1, 1, 0.45, 1, 0.72, Preset);
  Check(TryEncodeDisplayPreset(Preset, PresetText),
    'display preset could not be encoded');
  Check(TryDecodeDisplayPreset(PresetText, Decoded),
    'display preset could not be decoded');

  Common := DefaultDisplayCommonSettings;
  Common.PositionX := 321;
  Common.PositionY := -123;
  ApplyDisplayPreset(Decoded, Common, DisplayEffect, SyncAnimation,
    StartAnimation, StartSeconds, EndAnimation, EndSeconds);
  Check((Common.PositionX = 321) and (Common.PositionY = -123) and
    SameText(Common.BaseFontName, '游ゴシック') and
    SameText(Common.RubyFontName, 'メイリオ') and
    (Common.BaseFontHeight = 120) and (Common.RubyFontHeight = 48) and
    (Common.BeforeColor = $00112233) and
    (Common.AfterColor = $00445566) and
    (Common.RubyGapAdjustment = 17) and
    (Common.BaseCharacterSpacing = -4) and
    (Common.RubyCharacterSpacing = 8) and
    (DisplayEffect = 2) and (SyncAnimation = 1) and
    (StartAnimation = 1) and (Abs(StartSeconds - 0.45) < 0.0001) and
    (EndAnimation = 1) and (Abs(EndSeconds - 0.72) < 0.0001),
    'display preset did not round-trip or preserve coordinates');
  Check(not TryDecodeDisplayPreset('broken', Decoded),
    'invalid display preset was accepted');
end;

procedure TestCharacterLayoutInteraction;
var
  CharacterCounts: TArray<Integer>;
  Placements: TDisplayPlacementItems;
  Selected: TArray<Boolean>;
  StartPlacements: TDisplayPlacementItems;
begin
  Check(NextCharacterLayoutSelectionMode(clsmTransform, False) =
    clsmCharacterSpacing, 'transform mode did not advance to spacing');
  Check(NextCharacterLayoutSelectionMode(clsmCharacterSpacing, False) =
    clsmTransform, 'non-ruby selection entered ruby mode');
  Check(NextCharacterLayoutSelectionMode(clsmCharacterSpacing, True) =
    clsmRuby, 'ruby selection did not enter ruby mode');
  Check(HitTestCharacterLayoutModeHandle(Rect(10, 20, 110, 80),
    clsmCharacterSpacing, 10, 50) = cldmSpacingLeft,
    'left spacing handle hit test failed');
  Check(HitTestCharacterLayoutModeHandle(Rect(10, 20, 110, 80),
    clsmRuby, 60, 20) = cldmRubyMove,
    'ruby move handle hit test failed');

  SetLength(Placements, 3);
  Placements[0].Index := 0;
  Placements[0].X := 0;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;
  Placements[1].Index := 1;
  Placements[1].X := 20;
  Placements[1].ScaleX := 1;
  Placements[1].ScaleY := 1;
  Placements[2].Index := 2;
  Placements[2].X := 40;
  Placements[2].ScaleX := 1;
  Placements[2].ScaleY := 1;
  StartPlacements := Copy(Placements);
  SetLength(Selected, 3);
  SetLength(CharacterCounts, 3);
  CharacterCounts[0] := 2;
  CharacterCounts[1] := 2;
  CharacterCounts[2] := 2;
  Selected[1] := True;
  ApplyCharacterLayoutSpacingDrag(Placements, Selected,
    CharacterCounts, StartPlacements, cldmSpacingRight, 10, 1);
  Check(Placements[1].HasBaseCharacterSpacing and
    (Placements[1].BaseCharacterSpacing = 20) and
    (Abs(Placements[0].X) < 0.001) and
    (Abs(Placements[1].X - 20) < 0.001) and
    (Abs(Placements[2].X - 40) < 0.001),
    'base character spacing drag changed element placement');

  StartPlacements := Copy(Placements);
  ApplyCharacterLayoutSpacingDrag(Placements, Selected,
    CharacterCounts, StartPlacements, cldmSpacingRight, -25, 1);
  Check(Placements[1].HasBaseCharacterSpacing and
    (Placements[1].BaseCharacterSpacing = -30),
    'negative base character spacing was not accepted');

  Placements := Copy(StartPlacements);
  ApplyCharacterLayoutSpacingDrag(Placements, Selected,
    CharacterCounts, StartPlacements, cldmSpacingLeft, -5, 1);
  Check(Placements[1].HasBaseCharacterSpacing and
    (Placements[1].BaseCharacterSpacing = 30),
    'left handle did not expand base character spacing');

  Placements := Copy(StartPlacements);
  Selected[0] := True;
  Selected[2] := True;
  ApplyCharacterLayoutSpacingDrag(Placements, Selected,
    CharacterCounts, StartPlacements, cldmSpacingRight, 20, 1);
  Check((Placements[0].BaseCharacterSpacing = 40) and
    (Placements[1].BaseCharacterSpacing = 60) and
    (Placements[2].BaseCharacterSpacing = 40),
    'multi-selection base character spacing failed');

  Placements := Copy(StartPlacements);
  Selected[0] := False;
  Selected[2] := False;
  ApplyCharacterLayoutRubySpacingDrag(Placements, Selected,
    StartPlacements, cldmSpacingRight, 12, 1);
  Check(Placements[1].HasRubyCharacterSpacing and
    (Placements[1].RubyCharacterSpacing = 12),
    'ruby spacing drag failed');
  StartPlacements := Copy(Placements);
  ApplyCharacterLayoutRubyMoveDrag(Placements, Selected,
    StartPlacements, 8, -6, 1);
  Check(Placements[1].HasRubyOffsetX and
    (Placements[1].RubyOffsetX = 8) and
    Placements[1].HasRubyOffsetY and
    (Placements[1].RubyOffsetY = -6),
    'ruby move drag failed');
end;

procedure TestToolbarButtonState;
var
  DialogButton: TSyncLyricsToolbarButton;
  Separator: TSyncLyricsToolbarButton;
  ToggleButton: TSyncLyricsToolbarButton;
  Toolbar: TSyncLyricsToolbarButtons;
begin
  Toolbar := TSyncLyricsToolbarButtons.Create(nil);
  try
    Toolbar.ButtonExtent := 32;
    Toolbar.SeparatorExtent := 7;
    ToggleButton := Toolbar.AddToggleButton('bold', tbgBold, 10);
    Separator := Toolbar.AddSeparator;
    DialogButton := Toolbar.AddDialogButton('font', tbgFont, 11);
    Check((Toolbar.ItemCount = 3) and
      (Toolbar.FindByTag(10) = ToggleButton) and
      (ToggleButton.Width = 32) and (Separator.Width = 7),
      'toolbar item creation or layout failed');
    ToggleButton.CheckState := tbcsMixed;
    ToggleButton.Execute;
    Check(ToggleButton.CheckState = tbcsChecked,
      'mixed toolbar toggle did not become checked');
    ToggleButton.Execute;
    Check(ToggleButton.CheckState = tbcsUnchecked,
      'checked toolbar toggle did not become unchecked');
    DialogButton.CheckState := tbcsMixed;
    DialogButton.Execute;
    Check(DialogButton.CheckState = tbcsMixed,
      'dialog toolbar button unexpectedly toggled state');
  finally
    Toolbar.Free;
  end;
end;

procedure TestTimeRuler;
var
  Interval: Double;
begin
  Interval := SelectTimeRulerInterval(10.0);
  Check(Abs(Interval - 1.0) < 0.000001,
    '10 second view did not select one-second ruler ticks');
  Check(FirstTimeRulerTickIndex(2.35, Interval) = 3,
    'ruler did not begin at the next absolute second');
  Check(LastTimeRulerTickIndex(5.35, Interval) = 5,
    'ruler did not end at the last visible absolute second');

  Interval := SelectTimeRulerInterval(1.0);
  Check(Abs(Interval - 0.1) < 0.000001,
    'one-second view did not select 0.1-second ruler ticks');
  Check(FirstTimeRulerTickIndex(0.21, Interval) = 3,
    'fractional ruler did not follow the absolute audio origin');
  Check(TimeRulerDecimalPlaces(Interval) = 1,
    'fractional ruler label precision mismatch');

  Check(Abs(SelectTimeRulerInterval(60.0) - 10.0) < 0.000001,
    'wide view selected an excessive number of ruler ticks');
end;

procedure TestSongReaderAndConsumption;
var
  Bytes: TBytes;
  FileName: string;
  I: Integer;
  Notes: TMusicNoteStarts;
  SongModel: TLyricsSongModel;
  ProgressUnits: Double;
  SyncData: TSyncTextData;
  SyncEndSeconds: Double;
  SyncParameters: TArray<Integer>;
  SyncStartSeconds: Double;
  SyncText: string;
begin
  Check(Abs(ObjectSecondsToMusicSeconds(0.5, 0.5)) < 0.000001,
    'positive music offset did not preserve pre-display time');
  Check(Abs(MusicSecondsToObjectSeconds(0.0, 0.5) - 0.5) < 0.000001,
    'positive music offset did not delay the source note');
  Check(Abs(ObjectSecondsToMusicSeconds(0.0, -0.25) - 0.25) <
    0.000001, 'negative music offset did not advance the source note');
  FileName := TPath.Combine(TPath.GetTempPath, 'SYNC_Lyrics_MusicSyncTests.mid');
  SetLength(Bytes, Length(TEST_MIDI));
  for I := 0 to High(TEST_MIDI) do
    Bytes[I] := TEST_MIDI[I];
  TFile.WriteAllBytes(FileName, Bytes);
  try
    Check(LoadMusicNoteStarts(FileName, Notes), 'SongReader MIDI load failed');
    Check(Length(Notes) = 2, 'SongReader note count mismatch');
    Check(Abs(Notes[0].Seconds) < 0.000001, 'first note time mismatch');
    Check(Notes[0].Key = 60, 'first note key mismatch');
    Check(Notes[0].Lyric = '', 'unexpected first note lyric');
    Check(Abs(Notes[1].Seconds - 0.5) < 0.000001, 'second note time mismatch');
    Check(Notes[1].Key = 62, 'second note key mismatch');
    Check(Abs(Notes[0].EndSeconds - 0.5) < 0.000001, 'first note end time mismatch');

    InitializeMusicSync;
    try
      SongModel := TLyricsSongModel.Create;
      try
        SongModel.SetLyricsText('a');
        SongModel.RecalculateMusicFrameRanges(FileName, -1,
          0.5, 0.5, 0.5, 30, 1);
        Check(SongModel[0].SyncStartFrame = 15,
          'music offset did not delay the generated sync range');
        Check(SongModel[0].DisplayStartFrame = 0,
          'pre-display range was not generated before an immediate note');
      finally
        SongModel.Free;
      end;
      Check(CountConsumedMusicNotes(FileName, -1, 0.0, 0.0) = 1,
        'first consumed note count mismatch');
      Check(CountConsumedMusicNotes(FileName, -1, 0.0, 0.5) = 2,
        'second consumed note count mismatch');
      Check(ResolveMusicSyncProgress(FileName, -1, 0.0, 0.25, ProgressUnits),
        'first continuous progress resolve failed');
      Check(Abs(ProgressUnits - 0.5) < 0.000001,
        'first continuous progress mismatch');
      Check(ResolveMusicSyncProgress(FileName, -1, 0.0, 0.75, ProgressUnits),
        'second continuous progress resolve failed');
      Check(Abs(ProgressUnits - 1.5) < 0.000001,
        'second continuous progress mismatch');

      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, -0.25, 2,
        ProgressUnits), 'pre-display state resolve failed');
      Check(Abs(ProgressUnits) < 0.000001,
        'pre-display state did not remain unconsumed');
      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, 0.75, 2,
        ProgressUnits), 'active display state resolve failed');
      Check(Abs(ProgressUnits - 1.5) < 0.000001,
        'active display state progress mismatch');
      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, 10.0, 2,
        ProgressUnits), 'completed display state resolve failed');
      Check(Abs(ProgressUnits - 2.0) < 0.000001,
        'completed lyrics did not remain complete');
      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, 1.01, 1,
        ProgressUnits), 'single-unit display state resolve failed');
      Check(Abs(ProgressUnits - 1.0) < 0.000001,
        'notes after the assigned unit changed progress');
      Check(ResolveMusicSyncProgressForUnits(FileName, -1, 0.0, 2.0, 3,
        ProgressUnits), 'insufficient-note display state resolve failed');
      Check(Abs(ProgressUnits - 2.0) < 0.000001,
        'insufficient notes did not preserve the incomplete state');

      SetLength(SyncParameters, 1);
      SyncParameters[0] := 1;
      Check(ResolveAdjustedMusicSyncProgress(FileName, -1, 0.0, 0.25, 1,
        SyncParameters, ProgressUnits), 'multi-note sync resolve failed');
      Check(Abs(ProgressUnits - 0.25) < 0.000001,
        'first of two notes did not advance one display unit proportionally');
      Check(ResolveAdjustedMusicSyncProgress(FileName, -1, 0.0, 0.75, 1,
        SyncParameters, ProgressUnits), 'second multi-note sync resolve failed');
      Check(Abs(ProgressUnits - 0.75) < 0.000001,
        'second of two notes did not continue the same display unit');
      SetLength(SyncParameters, 0);
      Check(ResolveAdjustedMusicSyncProgressWithOffset(FileName, -1,
        0.0, 0.75, 1, 1, SyncParameters, ProgressUnits),
        'line note offset resolve failed');
      Check(Abs(ProgressUnits - 0.5) < 0.000001,
        'the second line did not begin with the next music note');
      Check(TryResolveMusicSyncTimeRange(FileName, -1, 0.0,
        0, 2, SyncStartSeconds, SyncEndSeconds),
        'music synchronization time range resolve failed');
      Check((Abs(SyncStartSeconds) < 0.000001) and
        (Abs(SyncEndSeconds - 1.0) < 0.000001),
        'music synchronization time range mismatch');

      SetLength(SyncParameters, 1);
      SyncParameters[0] := -1;
      Check(ResolveAdjustedMusicSyncProgress(FileName, -1, 0.0, 0.25, 2,
        SyncParameters, ProgressUnits), 'multi-unit sync resolve failed');
      Check(Abs(ProgressUnits - 1.0) < 0.000001,
        'one note did not advance two display units proportionally');
      Check(ResolveAdjustedMusicSyncProgress(FileName, -1, 0.0, 0.75, 3,
        SyncParameters, ProgressUnits), 'implicit default sync resolve failed');
      Check(Abs(ProgressUnits - 2.5) < 0.000001,
        'implicit default sync after adjusted stage mismatch');

      SyncText := SerializeMusicSyncText([1, -1, 0]);
      Check(TryParseSyncText(SyncText, SyncData),
        'serialized music sync text could not be parsed');
      Check((SyncData.Version = SYNC_TEXT_VERSION) and
        (SyncData.Mode = smMusic), 'music sync header mismatch');
      Check((Length(SyncData.MusicStages) = 3) and
        (SyncData.MusicStages[0] = 1) and
        (SyncData.MusicStages[1] = -1) and
        (SyncData.MusicStages[2] = 0), 'music sync stages mismatch');
      Check(TryParseSyncText(DEFAULT_MUSIC_SYNC_TEXT, SyncData) and
        (Length(SyncData.MusicStages) = 0),
        'empty music sync stages were not accepted');
      Check(not TryParseSyncText(
        'SYNC_LYRICS_SYNC/2;mode=music;stages=0', SyncData),
        'unsupported sync text version was accepted');
      Check(not TryParseSyncText(
        'SYNC_LYRICS_SYNC/1;mode=music;stages=64', SyncData),
        'out-of-range music sync stage was accepted');
      SyncText := SerializeManualSyncText([0.25, 0.75, 1.5]);
      Check(TryParseSyncText(SyncText, SyncData) and
        (SyncData.Mode = smManual) and
        (Length(SyncData.ManualBoundaries) = 3),
        'serialized manual sync text could not be parsed');
      Check(Abs(SyncData.ManualBoundaries[1] - 0.75) < 0.000001,
        'manual sync boundary mismatch');
      Check(ResolveManualSyncProgress(0.0, 2,
        SyncData.ManualBoundaries, ProgressUnits) and
        (Abs(ProgressUnits) < 0.000001),
        'manual sync pre-roll mismatch');
      Check(ResolveManualSyncProgress(0.5, 2,
        SyncData.ManualBoundaries, ProgressUnits) and
        (Abs(ProgressUnits - 0.5) < 0.000001),
        'manual sync first unit mismatch');
      Check(ResolveManualSyncProgress(1.125, 2,
        SyncData.ManualBoundaries, ProgressUnits) and
        (Abs(ProgressUnits - 1.5) < 0.000001),
        'manual sync second unit mismatch');
      Check(ResolveManualSyncProgress(2.0, 2,
        SyncData.ManualBoundaries, ProgressUnits) and
        (Abs(ProgressUnits - 2.0) < 0.000001),
        'manual sync completion mismatch');
      Check(not ResolveManualSyncProgress(0.5, 3,
        SyncData.ManualBoundaries, ProgressUnits),
        'manual sync accepted a lyric/boundary count mismatch');
      Check(not TryParseSyncText(
        'SYNC_LYRICS_SYNC/1;mode=manual;boundaries=0.5,0.5', SyncData),
        'duplicate manual boundaries were accepted');
    finally
      FinalizeMusicSync;
    end;
  finally
    TFile.Delete(FileName);
  end;
end;

procedure TestExpandedRubyUnitCharacterNotes;
var
  Model: TMusicSyncEditModel;
  NoteIndex: Integer;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('[漢字](かんじ)を読む');
    Check(Length(Model.Units) = 4, 'ruby lyric unit count mismatch');
    Check(not Model.TryGetExpandedCharacterNoteIndex(0, 1, NoteIndex),
      'one-note ruby unit unexpectedly split its characters');

    Model.LoadSyncText(SerializeMusicSyncText([1, 0, 0, 0]));
    Check(Model.TryGetExpandedCharacterNoteIndex(0, 0, NoteIndex) and
      (NoteIndex = 0), 'first ruby character did not remain on first note');
    Check(Model.TryGetExpandedCharacterNoteIndex(0, 1, NoteIndex) and
      (NoteIndex = 1), 'second ruby character did not move to second note');
    Check(Model.UnitNoteIndexes[1] = 2,
      'unit after expanded ruby unit did not move past both notes');
  finally
    Model.Free;
  end;
end;

procedure TestNonSoundingLyricsAreAttached;
var
  Model: TMusicSyncEditModel;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('「歌、 空。」');
    Check(Length(Model.Units) = 2,
      'non-sounding characters created editable sync units');
    Check((Model.Units[0].PrefixText = '「') and
      (Model.Units[0].Text = '歌') and
      (Model.Units[0].SuffixText = '、 '),
      'leading or middle punctuation attachment mismatch');
    Check((Model.Units[1].Text = '空') and
      (Model.Units[1].SuffixText = '。」'),
      'trailing punctuation attachment mismatch');
    Check((Length(Model.Groups) = 2) and
      (Model.UnitNoteIndexes[0] = 0) and
      (Model.UnitNoteIndexes[1] = 1),
      'attached punctuation changed editable note indexes');
  finally
    Model.Free;
  end;
end;

procedure TestDefaultSyncGeneration;
var
  Model: TMusicSyncEditModel;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('「[漢字](かんじ)、 を!');
    Check(Length(Model.Units) = 2,
      'default sync did not use sounding display units');
    Model.LoadSyncText('');
    Check(Model.DefaultSyncGenerated,
      'missing sync text was not recognized as generated defaults');
    Check((Length(Model.Groups) = 2) and
      (Model.Groups[0].UnitCount = 1) and
      (Model.Groups[0].NoteCount = 1) and
      (Model.Groups[1].UnitCount = 1) and
      (Model.Groups[1].NoteCount = 1),
      'missing sync text did not create one-unit one-note defaults');
    Check(Model.SerializeSyncText = DEFAULT_MUSIC_SYNC_TEXT,
      'generated defaults were not serialized in canonical form');

    Model.LoadSyncText(SerializeMusicSyncText([1, 0]));
    Check(not Model.DefaultSyncGenerated,
      'explicit sync stages were mistaken for generated defaults');
  finally
    Model.Free;
  end;
end;

procedure TestSyncPreservedAcrossLyricsEdits;
var
  Model: TMusicSyncEditModel;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('あいう');
    Model.LoadSyncText(SerializeMusicSyncText([0, 1, 0]));
    Model.SelectedUnitIndex := 1;
    Model.SetLyrics('あえいう');
    Check((Length(Model.Groups) = 4) and
      (Model.Groups[0].NoteCount = 1) and
      (Model.Groups[1].NoteCount = 1) and
      (Model.Groups[2].NoteCount = 2) and
      (Model.Groups[3].NoteCount = 1),
      'insertion did not preserve matching multi-note unit');
    Check((Model.UnitNoteIndexes[0] = 0) and
      (Model.UnitNoteIndexes[1] = 1) and
      (Model.UnitNoteIndexes[2] = 2) and
      (Model.UnitNoteIndexes[3] = 4),
      'inserted unit note indexes mismatch');
    Check(Model.SelectedUnitIndex = 2,
      'selection did not follow matching unit after insertion');

    Model.SetLyrics('「あえいう、」');
    Check((Length(Model.Groups) = 4) and
      (Model.Groups[2].NoteCount = 2),
      'punctuation edit changed preserved sync');

    Model.SetLyrics('かきく');
    Model.LoadSyncText(SerializeMusicSyncText([-1, 0]));
    Model.SetLyrics('かきけく');
    Check((Length(Model.Groups) = 3) and
      (Model.Groups[0].UnitCount = 2) and
      (Model.Groups[0].NoteCount = 1) and
      (Model.Groups[1].UnitCount = 1) and
      (Model.Groups[2].UnitCount = 1),
      'insertion after shared group did not preserve the group');

    Model.SetLyrics('かきく');
    Model.LoadSyncText(SerializeMusicSyncText([-1, 0]));
    Model.SetLyrics('かけきく');
    Check((Length(Model.Groups) = 4) and
      (Model.Groups[0].UnitCount = 1) and
      (Model.Groups[1].UnitCount = 1) and
      (Model.Groups[2].UnitCount = 1),
      'edit inside shared group preserved an invalid group');

    Model.SetLyrics('[漢字](かんじ)を');
    Model.LoadSyncText(SerializeMusicSyncText([1, 0]));
    Model.SetLyrics('「[漢字](カンジ)、を」');
    Check((Length(Model.Groups) = 2) and
      (Model.Groups[0].NoteCount = 2),
      'ruby or attached punctuation edit changed base-text sync');
  finally
    Model.Free;
  end;
end;

procedure TestMusicSyncDpiLayout;
var
  Bitmap: Vcl.Graphics.TBitmap;
  BlackKeyY: Integer;
  Layout: TPianoRollLayout;
  Notes: TMusicNoteStarts;
  PixelColor: COLORREF;
begin
  Check(ScaleMusicSyncMetric(76, 96) = 76,
    '96 DPI metric changed its base size');
  Check(ScaleMusicSyncMetric(76, 192) = 152,
    '200 percent DPI metric mismatch');
  Check(MusicSyncKeyboardWidth(192) = 152,
    '200 percent keyboard width mismatch');

  Bitmap := Vcl.Graphics.TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(1800, 1240);
    SetLength(Notes, 0);
    DrawMusicSyncPianoRoll(Bitmap.Canvas, Bitmap.Width, Bitmap.Height,
      Notes, 0, 0, 0, 0, MUSIC_SYNC_DISPLAY_SECONDS, 192, Layout);
    Check((Layout.Dpi = 192) and
      (Layout.KeyboardWidth = 152) and
      (Layout.RollHeight = 1124) and
      (Layout.TimeWidth = 1648) and
      (Abs(Layout.ViewStartSeconds) < 0.000001) and
      (Abs(Layout.DisplaySeconds -
        MUSIC_SYNC_DISPLAY_SECONDS) < 0.000001),
      '200 percent piano-roll layout mismatch');
    // ノートなしの既定範囲はMIDI 48..71。黒鍵49の中心付近で、
    // 黒鍵幅62%より右側が白鍵ベースとして残ることを確認する。
    BlackKeyY := Round(Layout.RollHeight * 0.5 -
      (49 - 59.5) * (Layout.RollHeight / 24));
    PixelColor := GetPixel(Bitmap.Canvas.Handle, 40, BlackKeyY);
    Check((GetRValue(PixelColor) < 80) and
      (GetGValue(PixelColor) < 80) and
      (GetBValue(PixelColor) < 80),
      'black key itself was not painted dark');
    PixelColor := GetPixel(Bitmap.Canvas.Handle, 120, BlackKeyY);
    Check((GetRValue(PixelColor) > 100) and
      (GetGValue(PixelColor) > 100) and
      (GetBValue(PixelColor) > 100),
      'black key remainder was not painted with the white-key base');
  finally
    Bitmap.Free;
  end;
end;

procedure TestSyncSourceKind;
begin
  Check(IsMusicScoreFileName('song.mid'), 'MIDI was not classified as score');
  Check(IsMusicScoreFileName('SONG.MUSICXML'),
    'MusicXML classification was case-sensitive');
  Check(IsMusicScoreFileName('archive.mscz'),
    'MSCZ was not classified as score');
  Check(not IsMusicScoreFileName('voice.wav'),
    'WAV was unexpectedly classified as score');
  Check(not IsMusicScoreFileName('voice.flac'),
    'FLAC was unexpectedly classified as score');
  Check(not IsMusicScoreFileName('unknown.bin'),
    'unknown file was unexpectedly classified as score');
end;

procedure TestUnassignedLyrics;
var
  Model: TMusicSyncEditModel;
begin
  Model := TMusicSyncEditModel.Create;
  try
    Model.SetLyrics('あいう');
    Check(Model.FirstUnassignedUnitIndex(3) = -1,
      'fully assigned lyrics were reported as unassigned');
    Check(Model.FirstUnassignedUnitIndex(2) = 2,
      'remaining lyric unit index mismatch');
    Model.LoadSyncText(SerializeMusicSyncText([1, 0, 0]));
    Check(Model.FirstUnassignedUnitIndex(1) = 0,
      'partially supplied multi-note unit was not reported');
    Check(Model.FirstUnassignedUnitIndex(2) = 1,
      'unit after completed multi-note unit mismatch');
  finally
    Model.Free;
  end;
end;

procedure TestMusicSyncAnchorPerObject;
var
  Anchor: TMusicSyncAnchor;
begin
  InitializeMusicSyncAnchor;
  try
    RecordMusicSyncAnchor(101, 1001, 1, 0, 99, 300, 10, 30, 1);
    RecordMusicSyncAnchor(102, 1002, 1, 100, 199, 600, 20, 30, 1);
    Check(TryGetMusicSyncAnchor(1, 0, 99, Anchor) and
      (Anchor.ObjectID = 101) and (Anchor.Frame = 300) and
      (Anchor.CurrentFrame = 10),
      'first object music-sync anchor mismatch');
    Check(TryGetMusicSyncAnchor(1, 100, 199, Anchor) and
      (Anchor.ObjectID = 102) and (Anchor.Frame = 600),
      'second object music-sync anchor mismatch');
    Check(not TryGetMusicSyncAnchor(1, 200, 299, Anchor),
      'unexpected anchor found for unknown object');

    RecordMusicSyncAnchor(102, 1002, 2, 200, 299, 900, 30, 30, 1);
    Check(not TryGetMusicSyncAnchor(1, 100, 199, Anchor),
      'moved object retained its stale anchor');
    Check(TryGetMusicSyncAnchor(2, 200, 299, Anchor) and
      (Anchor.ObjectID = 102) and (Anchor.Frame = 900),
      'moved object music-sync anchor mismatch');
  finally
    FinalizeMusicSyncAnchor;
  end;
end;

procedure TestManualSyncEditModel;
var
  Model: TManualSyncEditModel;
begin
  Model := TManualSyncEditModel.Create;
  try
    Model.Initialize(3, 30.0, '', 10.0);
    Check(Abs(Model.BoundarySeconds(3) - 10.0) < 0.0001,
      'manual sync defaults were placed outside the initial view');
    Model.Initialize(3, 12.0, '');
    Check(Model.Complete and (Model.BoundaryCount = 4),
      'manual sync default boundaries were not generated');
    Check(Abs(Model.BoundarySeconds(1) - 4.0) < 0.0001,
      'manual sync default interval mismatch');
    Check(Model.AddTimingBoundary(1.25) and
      Model.TimingInputStarted and (Model.BoundaryCount = 1),
      'first timing key did not clear defaults and record the first point');
    Check(Model.AddTimingBoundary(2.5) and
      (Model.BoundaryCount = 2),
      'second timing point was not appended');
    Model.RearmTimingInput;
    Check(Model.BoundaryCount = 2,
      'rearming timing input unexpectedly deleted data');
    Check(Model.AddTimingBoundary(3.0) and
      (Model.BoundaryCount = 1) and
      (Abs(Model.BoundarySeconds(0) - 3.0) < 0.0001),
      'first timing key after rearm did not restart input');
    Check(Model.AddTimingBoundary(5.0) and
      Model.AddTimingBoundary(7.0) and
      Model.AddTimingBoundary(9.0) and Model.Complete,
      'manual timing input did not complete');
    Check(Model.MoveBoundary(1, 6.0) and
      (Model.BoundarySeconds(1) < Model.BoundarySeconds(2)),
      'manual boundary drag did not preserve ordering');
    Check(Pos('mode=manual', Model.SerializeSyncText) > 0,
      'manual sync serialization failed');
  finally
    Model.Free;
  end;
end;

begin
  TestDisplaySettingsData;
  TestDisplayPresetData;
  TestCharacterLayoutInteraction;
  TestToolbarButtonState;
  TestTimeRuler;
  TestSyncSourceKind;
  TestSongReaderAndConsumption;
  TestExpandedRubyUnitCharacterNotes;
  TestNonSoundingLyricsAreAttached;
  TestDefaultSyncGeneration;
  TestSyncPreservedAcrossLyricsEdits;
  TestMusicSyncDpiLayout;
  TestUnassignedLyrics;
  TestMusicSyncAnchorPerObject;
  TestManualSyncEditModel;
  Writeln('PASS');
end.
