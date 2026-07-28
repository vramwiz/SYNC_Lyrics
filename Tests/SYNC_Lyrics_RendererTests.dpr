program SYNC_Lyrics_RendererTests;

// 歌詞文字列がRGBA画像へ描画され、空文字が透明になることを検証する。

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SYNC_Lyrics_LyricParser in 'Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_Renderer in 'Source\Common\Render\SYNC_Lyrics_Renderer.pas';

const
  TEST_WIDTH = 640;
  TEST_HEIGHT = 300;

var
  CapturedPixels: array of TPIXEL_RGBA;
  CapturedWidth: Integer;
  CapturedHeight: Integer;

function TestRenderSettings: TLyricsRenderSettings;
begin
  Result := DefaultLyricsRenderSettings;
end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CaptureImage(Buffer: PPIXEL_RGBA; Width, Height: Integer); cdecl;
begin
  CapturedWidth := Width;
  CapturedHeight := Height;
  SetLength(CapturedPixels, Width * Height);
  Move(Buffer^, CapturedPixels[0], Length(CapturedPixels) * SizeOf(TPIXEL_RGBA));
end;

function CountVisiblePixels: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(CapturedPixels) do
    if CapturedPixels[I].A <> 0 then
      Inc(Result);
end;

function CapturedPixelHash: UInt64;
var
  I: Integer;
begin
  Result := UInt64($CBF29CE484222325);
  for I := 0 to High(CapturedPixels) do
  begin
    Result := (Result xor CapturedPixels[I].R) * UInt64($100000001B3);
    Result := (Result xor CapturedPixels[I].G) * UInt64($100000001B3);
    Result := (Result xor CapturedPixels[I].B) * UInt64($100000001B3);
    Result := (Result xor CapturedPixels[I].A) * UInt64($100000001B3);
  end;
end;

procedure FindVisibleBounds(out Left, Top, Right, Bottom: Integer);
var
  X: Integer;
  Y: Integer;
begin
  Left := CapturedWidth;
  Top := CapturedHeight;
  Right := -1;
  Bottom := -1;
  for Y := 0 to CapturedHeight - 1 do
    for X := 0 to CapturedWidth - 1 do
      if CapturedPixels[Y * CapturedWidth + X].A <> 0 then
      begin
        if X < Left then
          Left := X;
        if X > Right then
          Right := X;
        if Y < Top then
          Top := Y;
        if Y > Bottom then
          Bottom := Y;
      end;
end;

function CountVisiblePixelsInRows(TopRow, BottomRow: Integer): Integer;
var
  X: Integer;
  Y: Integer;
begin
  Result := 0;
  for Y := TopRow to BottomRow do
    for X := 0 to CapturedWidth - 1 do
      if CapturedPixels[Y * CapturedWidth + X].A <> 0 then
        Inc(Result);
end;

function CountAfterColorPixels: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(CapturedPixels) do
    if (CapturedPixels[I].G > CapturedPixels[I].R) and
      (CapturedPixels[I].B > CapturedPixels[I].R) and
      (CapturedPixels[I].A <> 0) then
      Inc(Result);
end;

function CountAfterColorPixelsInRows(TopRow, BottomRow: Integer): Integer;
var
  X: Integer;
  Y: Integer;
begin
  Result := 0;
  for Y := TopRow to BottomRow do
    for X := 0 to CapturedWidth - 1 do
      if (CapturedPixels[Y * CapturedWidth + X].G >
        CapturedPixels[Y * CapturedWidth + X].R) and
        (CapturedPixels[Y * CapturedWidth + X].B >
        CapturedPixels[Y * CapturedWidth + X].R) then
        Inc(Result);
end;

procedure TestRubyParser;
var
  PlainText: string;
  RubySpans: TLyricsRubySpans;
  Units: TLyricsDisplayUnits;
begin
  ParseLyrics('[世界](せかい)は[広い](ひろい)', PlainText, RubySpans);
  Check(PlainText = '世界は広い', 'ruby syntax remained in plain text');
  Check(Length(RubySpans) = 2, 'ruby span count mismatch');
  Check((RubySpans[0].BaseStart = 1) and (RubySpans[0].BaseLength = 2) and
    (RubySpans[0].RubyText = 'せかい'), 'first ruby span mismatch');
  Check((RubySpans[1].BaseStart = 4) and (RubySpans[1].BaseLength = 2) and
    (RubySpans[1].RubyText = 'ひろい'), 'second ruby span mismatch');

  ParseLyrics('[漢字](かんじ)を読(よ)む', PlainText, RubySpans);
  Check(PlainText = '漢字を読む', 'short ruby syntax remained in plain text');
  Check(Length(RubySpans) = 2, 'mixed ruby span count mismatch');
  Check((RubySpans[0].BaseStart = 1) and (RubySpans[0].BaseLength = 2) and
    (RubySpans[0].RubyText = 'かんじ'), 'mixed bracket ruby span mismatch');
  Check((RubySpans[1].BaseStart = 4) and (RubySpans[1].BaseLength = 1) and
    (RubySpans[1].RubyText = 'よ'), 'short ruby span mismatch');
  BuildLyricsDisplayUnits(PlainText, RubySpans, Units);
  Check(Length(Units) = 4, 'display unit count mismatch');
  Check((Units[0].BaseStart = 1) and (Units[0].BaseLength = 2) and
    (Units[0].RubyIndex = 0), 'bracket ruby display unit mismatch');
  Check((Units[2].BaseStart = 4) and (Units[2].BaseLength = 1) and
    (Units[2].RubyIndex = 1), 'short ruby display unit mismatch');
  Check(Units[0].ConsumesNote and Units[1].ConsumesNote and
    Units[2].ConsumesNote and Units[3].ConsumesNote,
    'sounding lyric unit classification mismatch');
  Check(CountLyricsDisplayUnits('[漢字](かんじ)を読(よ)む') = 4,
    'display unit count mismatch');

  ParseLyrics('「歌、 空。」', PlainText, RubySpans);
  BuildLyricsDisplayUnits(PlainText, RubySpans, Units);
  Check((Length(Units) = 7) and not Units[0].ConsumesNote and
    Units[1].ConsumesNote and not Units[2].ConsumesNote and
    not Units[3].ConsumesNote and Units[4].ConsumesNote and
    not Units[5].ConsumesNote and not Units[6].ConsumesNote,
    'space and punctuation classification mismatch');
  Check((Units[0].SyncUnitIndex = 0) and
    (Units[1].SyncUnitIndex = 0) and
    (Units[2].SyncUnitIndex = 0) and
    (Units[3].SyncUnitIndex = 0) and
    (Units[4].SyncUnitIndex = 1) and
    (Units[5].SyncUnitIndex = 1) and
    (Units[6].SyncUnitIndex = 1),
    'space and punctuation attachment mismatch');
  Check(CountLyricsDisplayUnits('「歌、 空。」') = 2,
    'non-sounding characters consumed sync units');
  Check(IsSoundingLyricsText('ー') and IsSoundingLyricsText('々') and
    not IsSoundingLyricsText('、 '),
    'Japanese sounding mark classification mismatch');

  ParseLyrics('[世界](せかい', PlainText, RubySpans);
  Check(PlainText = '[世界](せかい', 'broken syntax was not preserved');
  Check(Length(RubySpans) = 0, 'broken syntax created a ruby span');
end;

procedure TestVisibleJapaneseLyrics;
var
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '入力した歌詞', 0, Settings, 0, 0),
    'lyrics render failed');
  Check((CapturedWidth = TEST_WIDTH) and (CapturedHeight = TEST_HEIGHT),
    'render size mismatch');
  Check(CountVisiblePixels > 0, 'lyrics produced no visible pixels');
end;

procedure TestRubyIsDrawnAboveLyrics;
var
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '[世界](せかい)は広い', 0, Settings, 0, 0),
    'ruby render failed');
  Check(CountVisiblePixelsInRows(60, 120) > 0, 'ruby produced no pixels above lyrics');
end;

procedure TestConsumedLyricsUseAfterColor;
var
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '同期', 0.5, Settings, 0, 0),
    'consumed lyrics render failed');
  Check(CountAfterColorPixels > 0, 'consumed lyrics produced no after-color pixels');
end;

procedure TestRubyAndBaseShareProgress;
var
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '[漢字](かんじ)', 0.5, Settings, 0, 0),
    'shared ruby progress render failed');
  Check(CountAfterColorPixelsInRows(60, 123) > 0,
    'ruby did not receive partial after color');
  Check(CountAfterColorPixelsInRows(124, 230) > 0,
    'ruby base did not receive partial after color');
end;

procedure TestEmptyLyricsIsTransparent;
var
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '', 0, Settings, 0, 0),
    'empty lyrics render failed');
  Check(CountVisiblePixels = 0, 'empty lyrics left visible pixels');
end;

procedure TestPositionOffsetsMoveBaseAndRuby;
var
  BaseBottom: Integer;
  BaseLeft: Integer;
  BaseRight: Integer;
  BaseTop: Integer;
  MovedBottom: Integer;
  MovedLeft: Integer;
  MovedRight: Integer;
  MovedTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '[座標](ざひょう)', 0, Settings, 0, 0),
    'base position render failed');
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);
  Check(RenderLyrics(@Video, '[座標](ざひょう)', 0, Settings, 37, 19),
    'offset position render failed');
  FindVisibleBounds(MovedLeft, MovedTop, MovedRight, MovedBottom);
  Check((MovedLeft - BaseLeft = 37) and (MovedRight - BaseRight = 37),
    'X offset did not move all lyrics pixels');
  Check((MovedTop - BaseTop = 19) and (MovedBottom - BaseBottom = 19),
    'Y offset did not move all lyrics pixels');
end;

procedure TestConfiguredColorsAreUsed;
var
  BlackPixels: Integer;
  I: Integer;
  ObjectInfo: TOBJECT_INFO;
  RedPixels: Integer;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Settings.BeforeColor.R := 255;
  Settings.BeforeColor.G := 0;
  Settings.BeforeColor.B := 0;
  Check(RenderLyrics(@Video, '色設定', 0, Settings, 0, 0),
    'configured color render failed');
  RedPixels := 0;
  for I := 0 to High(CapturedPixels) do
    if (CapturedPixels[I].R > CapturedPixels[I].G) and
      (CapturedPixels[I].R > CapturedPixels[I].B) and
      (CapturedPixels[I].A <> 0) then
      Inc(RedPixels);
  Check(RedPixels > 0, 'configured before color produced no red pixels');

  Settings.BeforeColor.R := 0;
  Check(RenderLyrics(@Video, '黒色', 0, Settings, 0, 0),
    'black color render failed');
  BlackPixels := 0;
  for I := 0 to High(CapturedPixels) do
    if (CapturedPixels[I].R = 0) and (CapturedPixels[I].G = 0) and
      (CapturedPixels[I].B = 0) and (CapturedPixels[I].A <> 0) then
      Inc(BlackPixels);
  Check(BlackPixels > 0, 'configured black color became transparent');
end;

procedure TestConfiguredFontSizesChangeBounds;
var
  LargeBottom: Integer;
  LargeLeft: Integer;
  LargeRight: Integer;
  LargeTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  SmallBottom: Integer;
  SmallLeft: Integer;
  SmallRight: Integer;
  SmallTop: Integer;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Settings.BaseFontHeight := 48;
  Check(RenderLyrics(@Video, 'サイズ', 0, Settings, 0, 0),
    'small font render failed');
  FindVisibleBounds(SmallLeft, SmallTop, SmallRight, SmallBottom);
  Settings.BaseFontHeight := 144;
  Check(RenderLyrics(@Video, 'サイズ', 0, Settings, 0, 0),
    'large font render failed');
  FindVisibleBounds(LargeLeft, LargeTop, LargeRight, LargeBottom);
  Check((LargeRight - LargeLeft) > (SmallRight - SmallLeft),
    'configured base font size did not increase text width');
  Check((LargeBottom - LargeTop) > (SmallBottom - SmallTop),
    'configured base font size did not increase text height');
end;

procedure TestConfiguredCharacterSpacingChangesWidth;
var
  BaseBottom: Integer;
  BaseLeft: Integer;
  BaseRight: Integer;
  BaseTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  SpacedBottom: Integer;
  SpacedLeft: Integer;
  SpacedRight: Integer;
  SpacedTop: Integer;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '文字間隔', 0, Settings, 0, 0),
    'base character spacing render failed');
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);
  Settings.BaseCharacterSpacing := 16;
  Check(RenderLyrics(@Video, '文字間隔', 0, Settings, 0, 0),
    'expanded character spacing render failed');
  FindVisibleBounds(SpacedLeft, SpacedTop, SpacedRight, SpacedBottom);
  Check((SpacedRight - SpacedLeft) > (BaseRight - BaseLeft),
    'configured character spacing did not increase text width');
end;

procedure TestConfiguredFontStylesAreUsed;
var
  BaseHash: UInt64;
  ItalicHash: UInt64;
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Settings.BaseBold := False;
  Settings.BaseItalic := False;
  Settings.BaseUnderline := False;
  Settings.BaseStrikeOut := False;
  Check(RenderLyrics(@Video, 'Font Style', 0, Settings, 0, 0),
    'plain font-style render failed');
  BaseHash := CapturedPixelHash;

  Settings.BaseItalic := True;
  Check(RenderLyrics(@Video, 'Font Style', 0, Settings, 0, 0),
    'italic font-style render failed');
  ItalicHash := CapturedPixelHash;
  Check(ItalicHash <> BaseHash,
    'configured italic style did not change rendered pixels');

  Settings.BaseItalic := False;
  Settings.BaseUnderline := True;
  Check(RenderLyrics(@Video, 'Font Style', 0, Settings, 0, 0),
    'underline font-style render failed');
  Check(CapturedPixelHash <> BaseHash,
    'configured underline style did not change rendered pixels');
end;

procedure TestRubyGapAdjustmentChangesRowDistance;
var
  BaseBottom: Integer;
  BaseLeft: Integer;
  BaseRight: Integer;
  BaseTop: Integer;
  ExpandedBottom: Integer;
  ExpandedLeft: Integer;
  ExpandedRight: Integer;
  ExpandedTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '[行間](ぎょうかん)', 0, Settings, 0, 0),
    'base ruby gap render failed');
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);
  Settings.RubyGapAdjustment := 30;
  Check(RenderLyrics(@Video, '[行間](ぎょうかん)', 0, Settings, 0, 0),
    'expanded ruby gap render failed');
  FindVisibleBounds(ExpandedLeft, ExpandedTop, ExpandedRight, ExpandedBottom);
  Check((ExpandedBottom - ExpandedTop) > (BaseBottom - BaseTop),
    'configured ruby gap did not increase row distance');
end;

begin
  InitializeLyricsRenderer;
  try
    TestRubyParser;
    TestVisibleJapaneseLyrics;
    TestRubyIsDrawnAboveLyrics;
    TestConsumedLyricsUseAfterColor;
    TestRubyAndBaseShareProgress;
    TestPositionOffsetsMoveBaseAndRuby;
    TestConfiguredColorsAreUsed;
    TestConfiguredFontSizesChangeBounds;
    TestConfiguredCharacterSpacingChangesWidth;
    TestConfiguredFontStylesAreUsed;
    TestRubyGapAdjustmentChangesRowDistance;
    TestEmptyLyricsIsTransparent;
    Writeln('PASS');
  finally
    FinalizeLyricsRenderer;
  end;
end.
