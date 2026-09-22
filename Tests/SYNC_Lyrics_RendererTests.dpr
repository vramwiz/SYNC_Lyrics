program SYNC_Lyrics_RendererTests;

// 歌詞文字列がRGBA画像へ描画され、空文字が透明になることを検証する。

{$APPTYPE CONSOLE}

uses
  System.Math,
  System.SysUtils,
  TextRendererSkiaBootstrap in 'Source\Lib\TextRenderer\TextRendererSkiaBootstrap.pas',
  TextRendererTypes in 'Source\Lib\TextRenderer\TextRendererTypes.pas',
  TextRenderer in 'Source\Lib\TextRenderer\TextRenderer.pas',
  TextRendererSkiaRuntime in 'Source\Lib\TextRenderer\TextRendererSkiaRuntime.pas',
  TextRendererSkia in 'Source\Lib\TextRenderer\TextRendererSkia.pas',
  PluginFilterSerifDrawSyncHighlight in
    'Source\Lib\SerifSyncAnimation\PluginFilterSerifDrawSyncHighlight.pas',
  AviUtl2FilterTypes in 'Source\Lib\AviUtl2FilterTypes.pas',
  SYNC_Lyrics_LyricParser in 'Source\Common\Lyrics\SYNC_Lyrics_LyricParser.pas',
  SYNC_Lyrics_DisplaySettingsData in
    'Source\Common\Render\SYNC_Lyrics_DisplaySettingsData.pas',
  SYNC_Lyrics_ResolvedDisplayUnits in
    'Source\Common\Render\SYNC_Lyrics_ResolvedDisplayUnits.pas',
  SYNC_Lyrics_Animation in
    'Source\Common\Render\SYNC_Lyrics_Animation.pas',
  SYNC_Lyrics_SerifAnimationItems in
    'Source\Plugin\Filter\SYNC_Lyrics_SerifAnimationItems.pas',
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

procedure SupplyInputImage(Buffer: PPIXEL_RGBA); cdecl;
var
  I: Integer;
  Pixel: PPIXEL_RGBA;
begin
  Pixel := Buffer;
  for I := 0 to TEST_WIDTH * TEST_HEIGHT - 1 do
  begin
    Pixel^.R := 17;
    Pixel^.G := 34;
    Pixel^.B := 51;
    Pixel^.A := 255;
    Inc(Pixel);
  end;
end;

function MaximumAlpha: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(CapturedPixels) do
    if CapturedPixels[I].A > Result then
      Result := CapturedPixels[I].A;
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

procedure FindVisibleBoundsInColumns(FirstColumn, LastColumn: Integer;
  out Left, Top, Right, Bottom: Integer);
var
  X: Integer;
  Y: Integer;
begin
  Left := CapturedWidth;
  Top := CapturedHeight;
  Right := -1;
  Bottom := -1;
  FirstColumn := EnsureRange(FirstColumn, 0, CapturedWidth - 1);
  LastColumn := EnsureRange(LastColumn, 0, CapturedWidth - 1);
  for Y := 0 to CapturedHeight - 1 do
    for X := FirstColumn to LastColumn do
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

procedure TestSerifSyncEffects;
var
  BaseBottom: Integer;
  BaseHash: UInt64;
  BaseLeft: Integer;
  BaseRight: Integer;
  BaseTop: Integer;
  ColorAfterMode: TLyricsColorAfterMode;
  ColorFillMode: TLyricsColorFillMode;
  EffectBottom: Integer;
  EffectHash: UInt64;
  EffectLeft: Integer;
  EffectRight: Integer;
  EffectTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
  PreSyncHash: UInt64;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;

  procedure CheckEffectChangesImage(Kind: TLyricsSyncKind;
    const MessageText: string);
  begin
    Settings.SyncKind := Kind;
    Check(RenderLyrics(@Video, 'AB', 0.5, Settings, 0, 0), MessageText);
    EffectHash := CapturedPixelHash;
    Check(EffectHash <> BaseHash, MessageText + ' did not change image');
  end;

  procedure CheckFreeEffectChangesImage(Kind: TLyricsSyncKind;
    const MessageText: string);
  begin
    Settings.SyncKind := Kind;
    Check(RenderFreePlacementLyrics(@Video, 'AB', 0.5, Settings,
      Placements, 0, 0), MessageText);
    Check(CapturedPixelHash <> BaseHash,
      MessageText + ' did not change image');
  end;

begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Settings.BeforeColor.R := 32;
  Settings.BeforeColor.G := 32;
  Settings.BeforeColor.B := 32;
  Settings.AfterColor := Settings.BeforeColor;
  Settings.SyncColor.R := 255;
  Settings.SyncColor.G := 64;
  Settings.SyncColor.B := 32;
  Settings.ColorFillMode := lcfSmooth;
  Settings.ColorAfterMode := lcaRestore;
  Settings.SyncKind := lskNone;
  Check(RenderLyrics(@Video, 'AB', 0, Settings, 0, 0),
    'pre-sync effect baseline failed');
  PreSyncHash := CapturedPixelHash;
  Settings.SyncKind := lskBacking;
  Check(RenderLyrics(@Video, 'AB', 0, Settings, 0, 0),
    'pre-sync backing render failed');
  Check(CapturedPixelHash = PreSyncHash,
    'pre-sync state activated the first display unit');
  Settings.SyncKind := lskNone;
  Check(RenderLyrics(@Video, 'AB', 0.5, Settings, 0, 0),
    'sync effect baseline failed');
  BaseHash := CapturedPixelHash;
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);

  CheckEffectChangesImage(lskFront, 'front sync effect failed');
  CheckEffectChangesImage(lskBacking, 'backing sync effect failed');
  CheckEffectChangesImage(lskUnderline, 'underline sync effect failed');
  CheckEffectChangesImage(lskGlow, 'glow sync effect failed');

  Settings.ColorBandSizePercent := 150;
  for ColorFillMode := Low(TLyricsColorFillMode) to
    High(TLyricsColorFillMode) do
    for ColorAfterMode := Low(TLyricsColorAfterMode) to
      High(TLyricsColorAfterMode) do
    begin
      Settings.ColorFillMode := ColorFillMode;
      Settings.ColorAfterMode := ColorAfterMode;
      CheckEffectChangesImage(lskFront, 'front sync mode failed');
      CheckEffectChangesImage(lskBacking, 'backing sync mode failed');
      CheckEffectChangesImage(lskUnderline, 'underline sync mode failed');
      CheckEffectChangesImage(lskZoom, 'zoom sync mode failed');
      CheckEffectChangesImage(lskGlow, 'glow sync mode failed');
      CheckEffectChangesImage(lskJump, 'jump sync mode failed');
    end;

  Settings.ColorFillMode := lcfSmooth;
  Settings.ColorAfterMode := lcaRestore;
  Settings.SyncKind := lskZoom;
  Settings.ColorBandSizePercent := 150;
  Check(RenderLyrics(@Video, 'AB', 0.5, Settings, 0, 0),
    'zoom sync effect failed');
  FindVisibleBounds(EffectLeft, EffectTop, EffectRight, EffectBottom);
  Check(((EffectRight - EffectLeft) > (BaseRight - BaseLeft)) or
    ((EffectBottom - EffectTop) > (BaseBottom - BaseTop)),
    'zoom sync effect did not enlarge the active unit');
  Check(Abs(EffectBottom - BaseBottom) <= 2,
    'zoom sync effect moved the text bottom edge');

  Settings.SyncKind := lskJump;
  Check(RenderLyrics(@Video, 'AB', 0.5, Settings, 0, 0),
    'jump sync effect failed');
  FindVisibleBounds(EffectLeft, EffectTop, EffectRight, EffectBottom);
  Check(EffectTop < BaseTop,
    'jump sync effect did not move the active unit upward');

  SetLength(Placements, 2);
  Placements[0].Index := 0;
  Placements[0].X := -60;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;
  Placements[1].Index := 1;
  Placements[1].X := 60;
  Placements[1].ScaleX := 1;
  Placements[1].ScaleY := 1;
  Settings.ColorBandSizePercent := 150;
  Settings.SyncKind := lskNone;
  Check(RenderFreePlacementLyrics(@Video, 'AB', 0.5, Settings,
    Placements, 0, 0), 'free sync effect baseline failed');
  BaseHash := CapturedPixelHash;
  CheckFreeEffectChangesImage(lskFront, 'free front sync effect failed');
  CheckFreeEffectChangesImage(lskBacking, 'free backing sync effect failed');
  CheckFreeEffectChangesImage(lskUnderline,
    'free underline sync effect failed');
  CheckFreeEffectChangesImage(lskGlow, 'free glow sync effect failed');
  CheckFreeEffectChangesImage(lskZoom, 'free zoom sync effect failed');
  CheckFreeEffectChangesImage(lskJump, 'free jump sync effect failed');
end;

procedure TestLineUnitsShareBaseline;
var
  LeftBottom: Integer;
  LeftLeft: Integer;
  LeftRight: Integer;
  LeftTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  RightBottom: Integer;
  RightLeft: Integer;
  RightRight: Integer;
  RightTop: Integer;
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
  Settings.SyncKind := lskNone;
  Settings.BaseCharacterSpacing := 40;

  Check(RenderLyrics(@Video, 'Hx', 0, Settings, 0, 0),
    'line baseline render failed');
  FindVisibleBoundsInColumns(0, TEST_WIDTH div 2 - 1,
    LeftLeft, LeftTop, LeftRight, LeftBottom);
  FindVisibleBoundsInColumns(TEST_WIDTH div 2, TEST_WIDTH - 1,
    RightLeft, RightTop, RightRight, RightBottom);
  Check((LeftRight >= LeftLeft) and (RightRight >= RightLeft),
    'line baseline glyph bounds were not found');
  Check(Abs(LeftBottom - RightBottom) <= 2,
    'line units did not share a common baseline');
  Check(Abs(LeftTop - RightTop) >= 3,
    'line baseline test glyphs did not have distinct ascents');
end;

procedure TestLyricsLayersAreComposited;
var
  Buffer: PPIXEL_RGBA;
  PixelCount: NativeInt;
  Settings: TLyricsRenderSettings;
begin
  PixelCount := NativeInt(TEST_WIDTH) * TEST_HEIGHT;
  GetMem(Buffer, PixelCount * SizeOf(TPIXEL_RGBA));
  try
    FillChar(Buffer^, PixelCount * SizeOf(TPIXEL_RGBA), 0);
    Settings := TestRenderSettings;
    Settings.SyncKind := lskNone;
    Check(DrawLyricsLayer(Buffer, TEST_WIDTH, TEST_HEIGHT, 'A', 0,
      Settings, 0, -90), 'first lyrics layer render failed');
    Check(DrawLyricsLayer(Buffer, TEST_WIDTH, TEST_HEIGHT, 'B', 0,
      Settings, 0, 0), 'second lyrics layer render failed');
    Check(DrawLyricsLayer(Buffer, TEST_WIDTH, TEST_HEIGHT, 'C', 0,
      Settings, 0, 90), 'third lyrics layer render failed');
    CaptureImage(Buffer, TEST_WIDTH, TEST_HEIGHT);
    Check(CountVisiblePixelsInRows(0, 90) > 0,
      'later lyrics layers erased the first layer');
    Check(CountVisiblePixelsInRows(95, 180) > 0,
      'second lyrics layer was not composited');
    Check(CountVisiblePixelsInRows(185, 299) > 0,
      'third lyrics layer was not composited');
  finally
    FreeMem(Buffer);
  end;
end;

procedure TestResolvedDisplayUnits;
var
  BaseStyle: TResolvedLyricsStyle;
  LogicalUnits: TLyricsDisplayUnits;
  PlainText: string;
  Placements: TDisplayPlacementItems;
  ResolvedUnits: TResolvedLyricsDisplayUnits;
  RubySpans: TLyricsRubySpans;
  RubyStyle: TResolvedLyricsStyle;
begin
  BaseStyle := Default(TResolvedLyricsStyle);
  RubyStyle := Default(TResolvedLyricsStyle);
  BaseStyle.FontName := 'Base default';
  BaseStyle.FontHeight := 96;
  BaseStyle.FontStyle := 1;
  BaseStyle.CharacterSpacing := 2;
  BaseStyle.BeforeColor := $00112233;
  BaseStyle.AfterColor := $00445566;
  BaseStyle.BeforeOpacity := 210;
  BaseStyle.OutlineEnabled := True;
  BaseStyle.OutlineWidth := 2;
  BaseStyle.ShadowEnabled := False;
  RubyStyle.FontName := 'Ruby default';
  RubyStyle.FontHeight := 42;
  RubyStyle.FontStyle := 2;
  RubyStyle.CharacterSpacing := 3;
  RubyStyle.BeforeColor := $00112233;
  RubyStyle.AfterColor := $00445566;
  RubyStyle.BeforeOpacity := 210;
  RubyStyle.OutlineEnabled := True;
  RubyStyle.OutlineWidth := 2;
  RubyStyle.ShadowEnabled := False;

  SetLength(Placements, 0);
  Check(BuildResolvedLyricsDisplayUnits('私[漢字](かんじ)',
    BaseStyle, RubyStyle, Placements, False, PlainText, RubySpans,
    LogicalUnits, ResolvedUnits), 'line resolved-unit build failed');
  Check((PlainText = '私漢字') and (Length(ResolvedUnits) = 2),
    'line resolved-unit text or count mismatch');
  Check((ResolvedUnits[0].Base.Text = '私') and
    (ResolvedUnits[1].Base.Text = '漢字') and
    ResolvedUnits[1].HasRuby and
    (ResolvedUnits[1].Ruby.Text = 'かんじ'),
    'line resolved-unit parts mismatch');
  Check((ResolvedUnits[0].ScaleX = 1) and
    (ResolvedUnits[0].ScaleY = 1) and
    (ResolvedUnits[1].Base.Style.FontName = BaseStyle.FontName) and
    (ResolvedUnits[1].Ruby.Style.FontName = RubyStyle.FontName),
    'line resolved-unit defaults mismatch');

  SetLength(Placements, 2);
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;
  Placements[1].X := 120;
  Placements[1].Y := -40;
  Placements[1].ScaleX := 1.5;
  Placements[1].ScaleY := 0.75;
  Placements[1].BaseFontName := 'Base override';
  Placements[1].RubyFontName := 'Ruby override';
  Placements[1].HasBeforeColor := True;
  Placements[1].BeforeColor := $00010203;
  Placements[1].HasAfterColor := True;
  Placements[1].AfterColor := $00040506;
  Placements[1].HasBaseFontHeight := True;
  Placements[1].BaseFontHeight := 120;
  Placements[1].HasRubyFontHeight := True;
  Placements[1].RubyFontHeight := 50;
  Placements[1].HasBaseFontStyle := True;
  Placements[1].BaseFontStyle := 6;
  Placements[1].HasRubyFontStyle := True;
  Placements[1].RubyFontStyle := 9;
  Placements[1].HasBaseCharacterSpacing := True;
  Placements[1].BaseCharacterSpacing := 8;
  Placements[1].HasRubyCharacterSpacing := True;
  Placements[1].RubyCharacterSpacing := 9;
  Placements[1].HasRubyOffsetX := True;
  Placements[1].RubyOffsetX := 10;
  Placements[1].HasRubyOffsetY := True;
  Placements[1].RubyOffsetY := -11;
  Placements[1].HasBeforeOpacity := True;
  Placements[1].BeforeOpacity := 123;
  Placements[1].HasOutlineEnabled := True;
  Placements[1].OutlineEnabled := False;
  Placements[1].HasOutlineWidth := True;
  Placements[1].OutlineWidth := 5.5;
  Placements[1].HasShadowEnabled := True;
  Placements[1].ShadowEnabled := True;
  Placements[1].HasShadowOffsetX := True;
  Placements[1].ShadowOffsetX := -3.25;
  Check(BuildResolvedLyricsDisplayUnits('私[漢字](かんじ)',
    BaseStyle, RubyStyle, Placements, True, PlainText, RubySpans,
    LogicalUnits, ResolvedUnits), 'free resolved-unit build failed');
  Check((ResolvedUnits[1].X = 120) and (ResolvedUnits[1].Y = -40) and
    (ResolvedUnits[1].ScaleX = 1.5) and
    (ResolvedUnits[1].ScaleY = 0.75),
    'free resolved-unit placement mismatch');
  Check((ResolvedUnits[1].Base.Style.FontName = 'Base override') and
    (ResolvedUnits[1].Ruby.Style.FontName = 'Ruby override') and
    (ResolvedUnits[1].Base.Style.FontHeight = 120) and
    (ResolvedUnits[1].Ruby.Style.FontHeight = 50) and
    (ResolvedUnits[1].Base.Style.FontStyle = 6) and
    (ResolvedUnits[1].Ruby.Style.FontStyle = 9),
    'free resolved-unit font override mismatch');
  Check((ResolvedUnits[1].Base.Style.BeforeColor = $00010203) and
    (ResolvedUnits[1].Ruby.Style.AfterColor = $00040506) and
    (ResolvedUnits[1].Base.Style.CharacterSpacing = 8) and
    (ResolvedUnits[1].Ruby.Style.CharacterSpacing = 9) and
    (ResolvedUnits[1].Ruby.OffsetX = 10) and
    (ResolvedUnits[1].Ruby.OffsetY = -11),
    'free resolved-unit style override mismatch');
  Check((ResolvedUnits[1].Base.Style.BeforeOpacity = 123) and
    (ResolvedUnits[1].Ruby.Style.BeforeOpacity = 123) and
    not ResolvedUnits[1].Base.Style.OutlineEnabled and
    not ResolvedUnits[1].Ruby.Style.OutlineEnabled and
    (Abs(ResolvedUnits[1].Base.Style.OutlineWidth - 5.5) < 0.001) and
    (Abs(ResolvedUnits[1].Ruby.Style.OutlineWidth - 5.5) < 0.001) and
    ResolvedUnits[1].Base.Style.ShadowEnabled and
    ResolvedUnits[1].Ruby.Style.ShadowEnabled and
    (Abs(ResolvedUnits[1].Base.Style.ShadowOffsetX + 3.25) < 0.001) and
    (Abs(ResolvedUnits[1].Ruby.Style.ShadowOffsetX + 3.25) < 0.001),
    'free resolved-unit decoration override mismatch');

  SetLength(Placements, 1);
  Check(not BuildResolvedLyricsDisplayUnits('私[漢字](かんじ)',
    BaseStyle, RubyStyle, Placements, True, PlainText, RubySpans,
    LogicalUnits, ResolvedUnits), 'placement-count mismatch was accepted');
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

procedure TestSilentMarksSwitchAtNoteBoundary;
var
  I: Integer;
  LogicalUnits: TLyricsDisplayUnits;
  PlainText: string;
  ResolvedUnits: TResolvedLyricsDisplayUnits;
  RubySpans: TLyricsRubySpans;
begin
  ParseLyrics('「歌、 空。」', PlainText, RubySpans);
  BuildLyricsDisplayUnits(PlainText, RubySpans, LogicalUnits);
  SetLength(ResolvedUnits, Length(LogicalUnits));
  for I := 0 to High(LogicalUnits) do
  begin
    ResolvedUnits[I].ConsumesNote := LogicalUnits[I].ConsumesNote;
    ResolvedUnits[I].SyncUnitIndex := LogicalUnits[I].SyncUnitIndex;
  end;
  Check((ResolveLyricsDisplayUnitProgress(ResolvedUnits, 0, 0) = 0) and
    (ResolveLyricsDisplayUnitProgress(ResolvedUnits, 0, 0.25) = 1),
    'leading mark did not switch at the first note start');
  Check(SameValue(ResolveLyricsDisplayUnitProgress(
    ResolvedUnits, 1, 0.25), 0.25),
    'sounding lyric lost gradual progress');
  Check((ResolveLyricsDisplayUnitProgress(ResolvedUnits, 2, 0.99) = 0) and
    (ResolveLyricsDisplayUnitProgress(ResolvedUnits, 2, 1) = 1) and
    (ResolveLyricsDisplayUnitProgress(ResolvedUnits, 3, 1) = 1),
    'middle silent units did not switch at the previous note end');
  Check((ResolveLyricsDisplayUnitProgress(ResolvedUnits, 5, 1.99) = 0) and
    (ResolveLyricsDisplayUnitProgress(ResolvedUnits, 5, 2) = 1) and
    (ResolveLyricsDisplayUnitProgress(ResolvedUnits, 6, 2) = 1),
    'trailing silent units did not switch at the final note end');
  Check(SameValue(ResolveLyricsDisplayUnitProgress(
    ResolvedUnits, 4, 1.25), 0.25),
    'second sounding lyric lost gradual progress');
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

procedure TestInputImageIsPreserved;
var
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;

  procedure CheckBackgroundPixel(Index: Integer; const MessageText: string);
  begin
    Check((CapturedPixels[Index].R = 17) and
      (CapturedPixels[Index].G = 34) and
      (CapturedPixels[Index].B = 51) and
      (CapturedPixels[Index].A = 255), MessageText);
  end;

begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.GetImageData := SupplyInputImage;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '', 0, Settings, 0, 0),
    'input image passthrough failed');
  CheckBackgroundPixel(0, 'empty lyrics replaced the input image');
  CheckBackgroundPixel(High(CapturedPixels),
    'empty lyrics damaged the input image tail');

  Check(RenderLyrics(@Video, '歌詞', 0, Settings, 0, 0),
    'input image lyrics composite failed');
  CheckBackgroundPixel(0, 'lyrics render cleared the input image');
end;

procedure TestFourColorChangeModes;
var
  CompletionHalfPixels: Integer;
  CompletionStartPixels: Integer;
  EarlySmoothRestorePixels: Integer;
  NarrowBandPixels: Integer;
  CharacterKeepPixels: Integer;
  CharacterRestorePixels: Integer;
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  SmoothKeepPixels: Integer;
  SmoothRestorePixels: Integer;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;

  Settings := TestRenderSettings;
  Settings.DisplayType := ldtKaraoke;
  Settings.ColorAfterMode := lcaRestore;
  Settings.ColorFillMode := lcfSmooth;
  Check(RenderLyrics(@Video, 'AB', 0, Settings, 0, 0),
    'pre-sync smooth restore render failed');
  Check(CountAfterColorPixels = 0,
    'pre-sync state colored the first display unit');
  Check(RenderLyrics(@Video, 'AB', 0.01, Settings, 0, 0),
    'early smooth restore color mode failed');
  EarlySmoothRestorePixels := CountAfterColorPixels;
  Check(RenderLyrics(@Video, 'AB', 0.25, Settings, 0, 0),
    'smooth restore color mode failed');
  SmoothRestorePixels := CountAfterColorPixels;
  Check(SmoothRestorePixels > 0,
    'smooth restore mode produced no active color');
  Check((EarlySmoothRestorePixels > 0) and
    (EarlySmoothRestorePixels < SmoothRestorePixels),
    'smooth restore color band filled the first unit at sync start');
  Settings.ColorBandSizePercent := 25;
  Check(RenderLyrics(@Video, 'AB', 1.25, Settings, 0, 0),
    'narrow smooth restore color band failed');
  NarrowBandPixels := CountAfterColorPixels;
  Settings.ColorBandSizePercent := 100;
  Check(RenderLyrics(@Video, 'AB', 1.25, Settings, 0, 0),
    'full-width smooth restore color band failed');
  Check(CountAfterColorPixels > NarrowBandPixels,
    'sync size did not widen the smooth restore color band');
  Check(RenderLyrics(@Video, 'AB', 1.0, Settings, 0, 0),
    'smooth restore boundary state failed');
  Check(CountAfterColorPixels > 0,
    'smooth restore color band disappeared at a unit boundary');
  Settings.CompletionRestoreProgress := 0;
  Check(RenderLyrics(@Video, 'AB', 2.0, Settings, 0, 0),
    'smooth restore hold-start state failed');
  CompletionStartPixels := CountAfterColorPixels;
  Check(CompletionStartPixels > 0,
    'smooth restore mode removed the final band at hold start');
  Settings.CompletionRestoreProgress := 0.5;
  Check(RenderLyrics(@Video, 'AB', 2.0, Settings, 0, 0),
    'smooth restore hold-middle state failed');
  CompletionHalfPixels := CountAfterColorPixels;
  Check((CompletionHalfPixels > 0) and
    (CompletionHalfPixels < CompletionStartPixels),
    'smooth restore mode did not wipe the final band during hold');
  Settings.CompletionRestoreProgress := 1;
  Check(RenderLyrics(@Video, 'AB', 2.0, Settings, 0, 0),
    'smooth restore hold-end state failed');
  Check(CountAfterColorPixels = 0,
    'smooth restore mode retained the final band at hold end');

  Settings.ColorFillMode := lcfCharacter;
  Check(RenderLyrics(@Video, 'AB', 0.25, Settings, 0, 0),
    'character restore color mode failed');
  CharacterRestorePixels := CountAfterColorPixels;
  Check(CharacterRestorePixels > 0,
    'character restore mode produced no active color');
  Check(RenderLyrics(@Video, 'AB', 1.0, Settings, 0, 0),
    'character restore rest state failed');
  Check(CountAfterColorPixels = 0,
    'restore mode retained color while progress was between notes');

  Settings.ColorAfterMode := lcaKeep;
  Settings.ColorFillMode := lcfSmooth;
  Check(RenderLyrics(@Video, 'AB', 1.25, Settings, 0, 0),
    'smooth keep color mode failed');
  SmoothKeepPixels := CountAfterColorPixels;
  Settings.ColorAfterMode := lcaRestore;
  Check(RenderLyrics(@Video, 'AB', 1.25, Settings, 0, 0),
    'smooth restore comparison failed');
  Check(SmoothKeepPixels > CountAfterColorPixels,
    'smooth keep mode did not retain completed units');

  Settings.ColorFillMode := lcfCharacter;
  Settings.ColorAfterMode := lcaKeep;
  Check(RenderLyrics(@Video, 'AB', 1.25, Settings, 0, 0),
    'character keep color mode failed');
  CharacterKeepPixels := CountAfterColorPixels;
  Settings.ColorAfterMode := lcaRestore;
  Check(RenderLyrics(@Video, 'AB', 1.25, Settings, 0, 0),
    'character restore comparison failed');
  Check(CharacterKeepPixels > CountAfterColorPixels,
    'character keep mode did not retain completed units');
end;

function CountDominantGreenPixels: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(CapturedPixels) do
    if (CapturedPixels[I].G > CapturedPixels[I].R) and
      (CapturedPixels[I].G > CapturedPixels[I].B) and
      (CapturedPixels[I].A <> 0) then
      Inc(Result);
end;

function CountDominantBluePixels: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(CapturedPixels) do
    if (CapturedPixels[I].B > CapturedPixels[I].R) and
      (CapturedPixels[I].B > CapturedPixels[I].G) and
      (CapturedPixels[I].A <> 0) then
      Inc(Result);
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

procedure TestDisplayTypes;
var
  FreeKaraokeAfterPixels: Integer;
  KaraokeAfterPixels: Integer;
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
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
  Settings.DisplayType := ldtKaraoke;
  Check(RenderLyrics(@Video, 'AB', 0.1, Settings, 0, 0),
    'karaoke display-type render failed');
  KaraokeAfterPixels := CountAfterColorPixels;

  Settings.DisplayType := ldtUnitEmphasis;
  Check(RenderLyrics(@Video, 'AB', 0.1, Settings, 0, 0),
    'unit-emphasis display-type render failed');
  Check(CountAfterColorPixels > KaraokeAfterPixels,
    'unit emphasis did not color the whole active unit');

  Settings.DisplayType := ldtUnitReveal;
  Check(RenderLyrics(@Video, 'AB', 0, Settings, 0, 0),
    'unit-reveal initial render failed');
  Check(CountVisiblePixels = 0,
    'unit reveal displayed lyrics before the first unit');
  Check(RenderLyrics(@Video, 'AB', 0.1, Settings, 0, 0),
    'unit-reveal active render failed');
  Check(CountVisiblePixels > 0,
    'unit reveal did not display the active unit');

  SetLength(Placements, 2);
  Placements[0].X := -40;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;
  Placements[1].X := 40;
  Placements[1].ScaleX := 1;
  Placements[1].ScaleY := 1;

  Settings.DisplayType := ldtKaraoke;
  Check(RenderFreePlacementLyrics(@Video, 'AB', 0.1, Settings,
    Placements, 0, 0), 'free karaoke display-type render failed');
  FreeKaraokeAfterPixels := CountAfterColorPixels;

  Settings.DisplayType := ldtUnitEmphasis;
  Check(RenderFreePlacementLyrics(@Video, 'AB', 0.1, Settings,
    Placements, 0, 0), 'free unit-emphasis display-type render failed');
  Check(CountAfterColorPixels > FreeKaraokeAfterPixels,
    'free unit emphasis did not color the whole active unit');

  Settings.DisplayType := ldtUnitReveal;
  Check(RenderFreePlacementLyrics(@Video, 'AB', 0, Settings,
    Placements, 0, 0), 'free unit-reveal initial render failed');
  Check(CountVisiblePixels = 0,
    'free unit reveal displayed lyrics before the first unit');
  Check(RenderFreePlacementLyrics(@Video, 'AB', 0.1, Settings,
    Placements, 0, 0), 'free unit-reveal active render failed');
  Check(CountVisiblePixels > 0,
    'free unit reveal did not display the active unit');
end;

procedure TestLyricsAnimations;
var
  AnimationOffsetY: Integer;
  AnimationOpacity: Double;
  AnimationSettings: TLyricsAnimationSettings;
  AnimationTransform: TLyricsAnimationTransform;
  BackgroundHash: UInt64;
  BaseLayerHash: UInt64;
  BaseLeft: Integer;
  BaseTop: Integer;
  BaseRight: Integer;
  BaseBottom: Integer;
  TransformedLeft: Integer;
  TransformedTop: Integer;
  TransformedRight: Integer;
  TransformedBottom: Integer;
  EffectState: TLyricsUnitEffectState;
  FullAlpha: Integer;
  ObjectInfo: TOBJECT_INFO;
  Settings: TLyricsRenderSettings;
  Video: TFILTER_PROC_VIDEO;
begin
  ResolveLyricsUnitEffect(ludeKaraoke, 0.25, EffectState);
  Check(EffectState.DrawBefore and
    (Abs(EffectState.AfterProgress - 0.25) < 0.000001),
    'karaoke unit-effect state mismatch');
  ResolveLyricsUnitEffect(ludeUnitEmphasis, 0.25, EffectState);
  Check(EffectState.DrawBefore and
    (Abs(EffectState.AfterProgress - 1) < 0.000001),
    'unit-emphasis state mismatch');
  ResolveLyricsUnitEffect(ludeUnitReveal, 0, EffectState);
  Check(not EffectState.DrawBefore and
    (EffectState.AfterProgress = 0),
    'unit-reveal initial state mismatch');
  ResolveLyricsUnitEffect(ludeUnitReveal, 0.25, EffectState);
  Check(not EffectState.DrawBefore and
    (Abs(EffectState.AfterProgress - 1) < 0.000001) and
    (EffectState.Opacity = 1) and (EffectState.ScaleX = 1) and
    (EffectState.ScaleY = 1) and (EffectState.OffsetX = 0) and
    (EffectState.OffsetY = 0),
    'unit-reveal active state mismatch');

  AnimationSettings.SyncAnimation := lsaBounce;
  AnimationSettings.StartAnimation := leaFade;
  AnimationSettings.EndAnimation := leaFade;
  AnimationSettings.StartDurationSeconds := 0.4;
  AnimationSettings.EndDurationSeconds := 0.2;
  AnimationSettings.BaseFontHeight := 100;
  AnimationSettings.StartDirection := 0;
  AnimationSettings.StartZoomOrigin := 0;
  AnimationSettings.EndDirection := 0;
  AnimationSettings.EndZoomDestination := 0;
  ResolveLyricsAnimation(AnimationSettings, 0.2, 1.0, 0.5,
    AnimationOpacity, AnimationOffsetY);
  Check(Abs(AnimationOpacity - 0.5) < 0.000001,
    'start fade opacity mismatch');
  Check(AnimationOffsetY < 0, 'sync bounce did not move lyrics upward');
  ResolveLyricsAnimation(AnimationSettings, 1.0, 0.1, 1.0,
    AnimationOpacity, AnimationOffsetY);
  Check(Abs(AnimationOpacity - 0.5) < 0.000001,
    'end fade opacity mismatch');
  Check(AnimationOffsetY = 0,
    'sync bounce moved lyrics outside active progress');

  AnimationSettings.SyncAnimation := lsaNone;
  AnimationSettings.EndAnimation := leaNone;
  AnimationSettings.StartDurationSeconds := 0.2;
  AnimationSettings.StartAnimation := leaSlide;
  AnimationSettings.StartDirection := 1;
  ResolveLyricsAnimationTransform(AnimationSettings, 0.1, 1.0, 0,
    AnimationTransform);
  Check(AnimationTransform.OffsetX < 0,
    'start slide transform mismatch');
  AnimationSettings.StartAnimation := leaZoom;
  AnimationSettings.StartZoomOrigin := 0;
  ResolveLyricsAnimationTransform(AnimationSettings, 0.1, 1.0, 0,
    AnimationTransform);
  Check(AnimationTransform.ScaleX < 1,
    'start zoom transform mismatch');
  AnimationSettings.StartAnimation := leaPop;
  ResolveLyricsAnimationTransform(AnimationSettings, 0.1, 1.0, 0,
    AnimationTransform);
  Check(Abs(AnimationTransform.ScaleX - 1) > 0.01,
    'start pop transform mismatch');
  AnimationSettings.StartAnimation := leaWipe;
  ResolveLyricsAnimationTransform(AnimationSettings, 0.1, 1.0, 0,
    AnimationTransform);
  Check((AnimationTransform.WipeProgress > 0) and
    (AnimationTransform.WipeProgress < 1),
    'start wipe transform mismatch');
  AnimationSettings.StartAnimation := leaBlur;
  ResolveLyricsAnimationTransform(AnimationSettings, 0.1, 1.0, 0,
    AnimationTransform);
  Check(AnimationTransform.BlurRadius > 0,
    'start blur transform mismatch');
  AnimationSettings.StartAnimation := leaRotate;
  ResolveLyricsAnimationTransform(AnimationSettings, 0.1, 1.0, 0,
    AnimationTransform);
  Check(Abs(AnimationTransform.RotationDegrees) > 0,
    'start rotate transform mismatch');
  AnimationSettings.StartAnimation := leaBounce;
  AnimationSettings.StartDirection := 3;
  ResolveLyricsAnimationTransform(AnimationSettings, 0.1, 1.0, 0,
    AnimationTransform);
  Check(AnimationTransform.OffsetY < 0,
    'start bounce transform mismatch');

  AnimationSettings.StartAnimation := leaNone;
  AnimationSettings.EndDurationSeconds := 0.2;
  AnimationSettings.EndAnimation := leaSlide;
  AnimationSettings.EndDirection := 2;
  ResolveLyricsAnimationTransform(AnimationSettings, 1.0, 0.1, 1.0,
    AnimationTransform);
  Check((AnimationTransform.OffsetX > 0) and
    (AnimationTransform.Opacity > 0), 'end slide transform mismatch');
  AnimationSettings.EndAnimation := leaZoom;
  AnimationSettings.EndZoomDestination := 0;
  ResolveLyricsAnimationTransform(AnimationSettings, 1.0, 0.1, 1.0,
    AnimationTransform);
  Check((AnimationTransform.ScaleX < 1) and
    (AnimationTransform.ScaleY < 1), 'end zoom transform mismatch');
  AnimationSettings.EndAnimation := leaWipe;
  ResolveLyricsAnimationTransform(AnimationSettings, 1.0, 0.1, 1.0,
    AnimationTransform);
  Check((AnimationTransform.WipeProgress > 0) and
    (AnimationTransform.WipeProgress < 1), 'end wipe transform mismatch');
  AnimationSettings.EndAnimation := leaBlur;
  ResolveLyricsAnimationTransform(AnimationSettings, 1.0, 0.1, 1.0,
    AnimationTransform);
  Check((AnimationTransform.BlurRadius > 0) and
    (AnimationTransform.Opacity < 1), 'end blur transform mismatch');
  AnimationSettings.EndAnimation := leaRotate;
  ResolveLyricsAnimationTransform(AnimationSettings, 1.0, 0.1, 1.0,
    AnimationTransform);
  Check((Abs(AnimationTransform.RotationDegrees) > 0) and
    (AnimationTransform.ScaleX < 1), 'end rotate transform mismatch');

  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;
  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, 'Fade', 0, Settings, 0, 0),
    'full-opacity render failed');
  FullAlpha := MaximumAlpha;
  Settings.Opacity := 0.5;
  Check(RenderLyrics(@Video, 'Fade', 0, Settings, 0, 0),
    'half-opacity render failed');
  Check((MaximumAlpha > 0) and (MaximumAlpha < FullAlpha),
    'configured opacity did not reduce rendered alpha');

  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, 'Layer', 0, Settings, 0, 0),
    'base layer-transform render failed');
  BaseLayerHash := CapturedPixelHash;
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);
  Settings.LayerOffsetX := 40;
  Check(RenderLyrics(@Video, 'Layer', 0, Settings, 0, 0),
    'offset layer-transform render failed');
  FindVisibleBounds(TransformedLeft, TransformedTop, TransformedRight,
    TransformedBottom);
  Check(TransformedLeft > BaseLeft + 30,
    'layer-transform offset did not move the rendered lyrics');
  Settings := TestRenderSettings;
  Settings.LayerScaleX := 0.8;
  Settings.LayerScaleY := 0.8;
  Check(RenderLyrics(@Video, 'Layer', 0, Settings, 0, 0),
    'scale layer-transform render failed');
  Check((CountVisiblePixels > 0) and
    (CapturedPixelHash <> BaseLayerHash),
    'layer-transform scale did not change the rendered lyrics');
  Settings := TestRenderSettings;
  Settings.LayerRotationDegrees := 8;
  Check(RenderLyrics(@Video, 'Layer', 0, Settings, 0, 0),
    'rotation layer-transform render failed');
  Check((CountVisiblePixels > 0) and
    (CapturedPixelHash <> BaseLayerHash),
    'layer-transform rotation did not change the rendered lyrics');
  Settings := TestRenderSettings;
  Settings.LayerBlurRadius := 2;
  Check(RenderLyrics(@Video, 'Layer', 0, Settings, 0, 0),
    'blur layer-transform render failed');
  Check((CountVisiblePixels > 0) and
    (CapturedPixelHash <> BaseLayerHash),
    'layer-transform blur did not change the rendered lyrics');
  Settings := TestRenderSettings;
  Settings.LayerWipeDirection := 2;
  Settings.LayerWipeProgress := 0;
  Check(RenderLyrics(@Video, 'Layer', 0, Settings, 0, 0),
    'wipe layer-transform render failed');
  Check(CountVisiblePixels = 0,
    'completed end wipe left visible lyrics pixels');

  // 文字単位同期の追加レイヤーも、表示後フェードの最終透明度に従う。
  Video.GetImageData := SupplyInputImage;
  Settings := TestRenderSettings;
  Check(RenderLyrics(@Video, '', 0, Settings, 0, 0),
    'background-only render failed');
  BackgroundHash := CapturedPixelHash;
  Settings.DisplayType := ldtUnitEmphasis;
  Settings.ColorFillMode := lcfCharacter;
  Settings.ColorAfterMode := lcaKeep;
  Settings.Opacity := 0;
  Settings.SyncKind := lskFront;
  Check(RenderLyrics(@Video, 'AB', 0.5, Settings, 0, 0),
    'zero-opacity character front render failed');
  Check(CapturedPixelHash = BackgroundHash,
    'character front remained after the end fade');
  Settings.SyncKind := lskBacking;
  Check(RenderLyrics(@Video, 'AB', 0.5, Settings, 0, 0),
    'zero-opacity character backing render failed');
  Check(CapturedPixelHash = BackgroundHash,
    'character backing remained after the end fade');
  Settings.SyncKind := lskUnderline;
  Check(RenderLyrics(@Video, 'AB', 0.5, Settings, 0, 0),
    'zero-opacity character underline render failed');
  Check(CapturedPixelHash = BackgroundHash,
    'character underline remained after the end fade');
end;

procedure TestAnimationTimeItems;
begin
  InitializeSerifAnimationItems;
  Check((string(SerifSyncOffsetXItem.Name) = 'オフセットX') and
    (string(SerifSyncOffsetYItem.Name) = 'オフセットY'),
    'sync offset item names mismatch');
  Check((string(SerifBeforeTimeItem.Name) = '前 時間') and
    (Abs(SerifBeforeTimeItem.Value - 0.30) < 0.000001) and
    (Abs(SerifBeforeTimeItem.S - 0.01) < 0.000001) and
    (Abs(SerifBeforeTimeItem.E - 3.00) < 0.000001) and
    (Abs(SerifBeforeTimeItem.Step - 0.01) < 0.000001),
    'before animation time item mismatch');
  Check((string(SerifAfterTimeItem.Name) = '後 時間') and
    (Abs(SerifAfterTimeItem.Value - 0.30) < 0.000001) and
    (Abs(SerifAfterTimeItem.S - 0.01) < 0.000001) and
    (Abs(SerifAfterTimeItem.E - 3.00) < 0.000001) and
    (Abs(SerifAfterTimeItem.Step - 0.01) < 0.000001),
    'after animation time item mismatch');
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

procedure TestFreePlacementCoordinates;
var
  Bottom: Integer;
  Left: Integer;
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
  Right: Integer;
  Settings: TLyricsRenderSettings;
  Top: Integer;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;
  Settings := TestRenderSettings;
  SetLength(Placements, 1);
  Placements[0].Index := 0;
  Placements[0].X := 120;
  Placements[0].Y := 40;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;
  Check(RenderFreePlacementLyrics(@Video, '字', 0, Settings,
    Placements, 0, 0), 'free-placement render failed');
  FindVisibleBounds(Left, Top, Right, Bottom);
  Check(((Left + Right) > TEST_WIDTH) and
    ((Top + Bottom) > TEST_HEIGHT),
    'free-placement coordinates did not move the display-unit center');
end;

procedure TestFreePlacementRubyKeepsBaseBottom;
var
  BaseBottom: Integer;
  Bottom: Integer;
  Left: Integer;
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
  Right: Integer;
  Settings: TLyricsRenderSettings;
  Top: Integer;
  Video: TFILTER_PROC_VIDEO;
begin
  FillChar(ObjectInfo, SizeOf(ObjectInfo), 0);
  FillChar(Video, SizeOf(Video), 0);
  ObjectInfo.Width := TEST_WIDTH;
  ObjectInfo.Height := TEST_HEIGHT;
  Video.Object_ := @ObjectInfo;
  Video.SetImageData := CaptureImage;
  Settings := TestRenderSettings;
  SetLength(Placements, 1);
  Placements[0].Index := 0;
  Placements[0].X := 0;
  Placements[0].Y := 0;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;
  Check(RenderFreePlacementLyrics(@Video, '漢', 0, Settings,
    Placements, 0, 0), 'free-placement base render failed');
  FindVisibleBounds(Left, Top, Right, BaseBottom);
  Check(RenderFreePlacementLyrics(@Video, '[漢](かん)', 0, Settings,
    Placements, 0, 0), 'free-placement ruby render failed');
  FindVisibleBounds(Left, Top, Right, Bottom);
  Check(Abs(Bottom - BaseBottom) <= 1,
    'ruby changed the free-placement base bottom edge');
end;

procedure TestFreePlacementScale;
var
  BaseBottom: Integer;
  BaseHeight: Integer;
  BaseLeft: Integer;
  BaseRight: Integer;
  BaseTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
  ScaledBottom: Integer;
  ScaledLeft: Integer;
  ScaledRight: Integer;
  ScaledTop: Integer;
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
  SetLength(Placements, 1);
  Placements[0].Index := 0;
  Placements[0].X := 0;
  Placements[0].Y := 0;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;
  Check(RenderFreePlacementLyrics(@Video, '拡', 0, Settings,
    Placements, 0, 0), 'base free-placement scale render failed');
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);
  BaseHeight := BaseBottom - BaseTop;

  Placements[0].ScaleX := 2;
  Placements[0].ScaleY := 0.5;
  Check(RenderFreePlacementLyrics(@Video, '拡', 0, Settings,
    Placements, 0, 0), 'scaled free-placement render failed');
  FindVisibleBounds(ScaledLeft, ScaledTop, ScaledRight, ScaledBottom);
  Check((ScaledRight - ScaledLeft) > (BaseRight - BaseLeft),
    'free-placement horizontal scale did not increase width');
  Check((ScaledBottom - ScaledTop) < BaseHeight,
    'free-placement vertical scale did not reduce height');
end;

procedure TestFreePlacementElementColors;
var
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
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
  Settings.AfterColor := Settings.BeforeColor;
  SetLength(Placements, 1);
  Placements[0].Index := 0;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;
  Placements[0].HasBeforeColor := True;
  Placements[0].BeforeColor := $0000FF00;
  Placements[0].HasAfterColor := True;
  Placements[0].AfterColor := $00FF0000;

  Check(RenderFreePlacementLyrics(@Video, '色', 0, Settings,
    Placements, 0, 0), 'free-placement before-color render failed');
  Check(CountDominantGreenPixels > 0,
    'element before color was not used');
  Check(RenderFreePlacementLyrics(@Video, '色', 1, Settings,
    Placements, 0, 0), 'free-placement after-color render failed');
  Check(CountDominantBluePixels > 0,
    'element after color was not used');
end;

procedure TestFreePlacementElementFontSize;
var
  BaseBottom: Integer;
  BaseLeft: Integer;
  BaseRight: Integer;
  BaseTop: Integer;
  LargeBottom: Integer;
  LargeLeft: Integer;
  LargeRight: Integer;
  LargeTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
  RubyBaseBottom: Integer;
  RubyBaseLeft: Integer;
  RubyBaseRight: Integer;
  RubyBaseTop: Integer;
  RubyLargeBottom: Integer;
  RubyLargeLeft: Integer;
  RubyLargeRight: Integer;
  RubyLargeTop: Integer;
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
  Settings.BaseFontHeight := 48;
  SetLength(Placements, 1);
  Placements[0].Index := 0;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;

  Check(RenderFreePlacementLyrics(@Video, '大', 0, Settings,
    Placements, 0, 0), 'inherited element font-size render failed');
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);
  Placements[0].HasBaseFontHeight := True;
  Placements[0].BaseFontHeight := 144;
  Check(RenderFreePlacementLyrics(@Video, '大', 0, Settings,
    Placements, 0, 0), 'individual element font-size render failed');
  FindVisibleBounds(LargeLeft, LargeTop, LargeRight, LargeBottom);
  Check((LargeRight - LargeLeft) > (BaseRight - BaseLeft),
    'individual base font size did not increase width');
  Check((LargeBottom - LargeTop) > (BaseBottom - BaseTop),
    'individual base font size did not increase height');

  Placements[0].HasBaseFontHeight := False;
  Settings.RubyFontHeight := 16;
  Check(RenderFreePlacementLyrics(@Video, '[大](だい)', 0, Settings,
    Placements, 0, 0), 'inherited ruby font-size render failed');
  FindVisibleBounds(RubyBaseLeft, RubyBaseTop, RubyBaseRight,
    RubyBaseBottom);
  Placements[0].HasRubyFontHeight := True;
  Placements[0].RubyFontHeight := 64;
  Check(RenderFreePlacementLyrics(@Video, '[大](だい)', 0, Settings,
    Placements, 0, 0), 'individual ruby font-size render failed');
  FindVisibleBounds(RubyLargeLeft, RubyLargeTop, RubyLargeRight,
    RubyLargeBottom);
  Check((RubyLargeBottom - RubyLargeTop) >
    (RubyBaseBottom - RubyBaseTop),
    'individual ruby font size did not increase row height');
end;

procedure TestFreePlacementElementFontStyle;
var
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
  PlainHash: UInt64;
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
  SetLength(Placements, 1);
  Placements[0].Index := 0;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;

  Check(RenderFreePlacementLyrics(@Video, 'S', 0, Settings,
    Placements, 0, 0), 'inherited element font-style render failed');
  PlainHash := CapturedPixelHash;
  Placements[0].HasBaseFontStyle := True;
  Placements[0].BaseFontStyle := 2 or 4;
  Check(RenderFreePlacementLyrics(@Video, 'S', 0, Settings,
    Placements, 0, 0), 'individual element font-style render failed');
  Check(CapturedPixelHash <> PlainHash,
    'individual element font style did not change rendered pixels');
end;

procedure TestFreePlacementBaseCharacterSpacing;
var
  BaseBottom: Integer;
  BaseLeft: Integer;
  BaseRight: Integer;
  BaseTop: Integer;
  NegativeBottom: Integer;
  NegativeLeft: Integer;
  NegativeRight: Integer;
  NegativeTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
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
  Settings.BaseFontHeight := 48;
  Settings.RubyFontHeight := 12;
  SetLength(Placements, 1);
  Placements[0].Index := 0;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;

  Check(RenderFreePlacementLyrics(@Video, '[漢字漢字](か)', 0,
    Settings, Placements, 0, 0),
    'inherited base-spacing render failed');
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);
  Placements[0].HasBaseCharacterSpacing := True;
  Placements[0].BaseCharacterSpacing := 20;
  Check(RenderFreePlacementLyrics(@Video, '[漢字漢字](か)', 0,
    Settings, Placements, 0, 0),
    'positive individual base-spacing render failed');
  FindVisibleBounds(SpacedLeft, SpacedTop, SpacedRight, SpacedBottom);
  Check((SpacedRight - SpacedLeft) > (BaseRight - BaseLeft),
    'individual base character spacing did not increase width');
  Check(Abs((SpacedLeft + SpacedRight) -
    (BaseLeft + BaseRight)) <= 4,
    'base character spacing left a trailing gap after the last character');
  Check((SpacedTop = BaseTop) and (SpacedBottom = BaseBottom),
    'individual base character spacing changed character height');

  Placements[0].BaseCharacterSpacing := -10;
  Check(RenderFreePlacementLyrics(@Video, '[漢字漢字](か)', 0,
    Settings, Placements, 0, 0),
    'negative individual base-spacing render failed');
  FindVisibleBounds(NegativeLeft, NegativeTop, NegativeRight,
    NegativeBottom);
  Check((NegativeRight - NegativeLeft) < (BaseRight - BaseLeft),
    'negative base character spacing did not reduce width');
  Check((NegativeTop = BaseTop) and (NegativeBottom = BaseBottom),
    'negative base character spacing changed character height');
end;

procedure TestFreePlacementRubyCharacterSpacing;
var
  BaseBottom: Integer;
  BaseLeft: Integer;
  BaseRight: Integer;
  BaseTop: Integer;
  ObjectInfo: TOBJECT_INFO;
  Placements: TDisplayPlacementItems;
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
  Settings.BaseFontHeight := 24;
  Settings.RubyFontHeight := 24;
  SetLength(Placements, 1);
  Placements[0].Index := 0;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;

  Check(RenderFreePlacementLyrics(@Video, '[字](かなかな)', 0, Settings,
    Placements, 0, 0), 'inherited ruby-spacing render failed');
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);
  Placements[0].HasRubyCharacterSpacing := True;
  Placements[0].RubyCharacterSpacing := 20;
  Check(RenderFreePlacementLyrics(@Video, '[字](かなかな)', 0, Settings,
    Placements, 0, 0), 'individual ruby-spacing render failed');
  FindVisibleBounds(SpacedLeft, SpacedTop, SpacedRight, SpacedBottom);
  Check((SpacedRight - SpacedLeft) > (BaseRight - BaseLeft),
    'individual ruby character spacing did not increase width');
end;

procedure TestFreePlacementRubyOffset;
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
  Placements: TDisplayPlacementItems;
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
  SetLength(Placements, 1);
  Placements[0].Index := 0;
  Placements[0].ScaleX := 1;
  Placements[0].ScaleY := 1;

  Check(RenderFreePlacementLyrics(@Video, '[字](か)', 0, Settings,
    Placements, 0, 0), 'inherited ruby-offset render failed');
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);
  Placements[0].HasRubyOffsetX := True;
  Placements[0].RubyOffsetX := 50;
  Placements[0].HasRubyOffsetY := True;
  Placements[0].RubyOffsetY := -30;
  Check(RenderFreePlacementLyrics(@Video, '[字](か)', 0, Settings,
    Placements, 0, 0), 'individual ruby-offset render failed');
  FindVisibleBounds(MovedLeft, MovedTop, MovedRight, MovedBottom);
  Check(MovedRight > BaseRight,
    'individual ruby X offset did not move ruby right');
  Check(MovedTop < BaseTop,
    'individual ruby Y offset did not move ruby upward');
end;

procedure TestTextDecorationAndOpacity;
var
  BaseBottom: Integer;
  BaseLeft: Integer;
  BaseRight: Integer;
  BaseTop: Integer;
  DecoratedBottom: Integer;
  DecoratedLeft: Integer;
  DecoratedRight: Integer;
  DecoratedTop: Integer;
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
  Settings.SyncKind := lskNone;
  Settings.AfterColor := Settings.BeforeColor;
  Check(RenderLyrics(@Video, '装飾', 0, Settings, 0, 0),
    'plain decoration baseline failed');
  FindVisibleBounds(BaseLeft, BaseTop, BaseRight, BaseBottom);

  Settings.OutlineEnabled := True;
  Settings.OutlineWidth := 10;
  Settings.BeforeOutlineColor.A := 255;
  Settings.AfterOutlineColor := Settings.BeforeOutlineColor;
  Check(RenderLyrics(@Video, '装飾', 0, Settings, 0, 0),
    'outline render failed');
  FindVisibleBounds(DecoratedLeft, DecoratedTop, DecoratedRight,
    DecoratedBottom);
  Check(((DecoratedRight - DecoratedLeft) > (BaseRight - BaseLeft)) and
    ((DecoratedBottom - DecoratedTop) > (BaseBottom - BaseTop)),
    Format('outline did not expand visible bounds: base=%d,%d,%d,%d ' +
      'decorated=%d,%d,%d,%d', [BaseLeft, BaseTop, BaseRight, BaseBottom,
      DecoratedLeft, DecoratedTop, DecoratedRight, DecoratedBottom]));

  Settings.OutlineEnabled := False;
  Settings.ShadowEnabled := True;
  Settings.ShadowOffsetX := 24;
  Settings.ShadowOffsetY := 18;
  Settings.ShadowBlur := 3;
  Settings.BeforeShadowColor.A := 200;
  Settings.AfterShadowColor := Settings.BeforeShadowColor;
  Check(RenderLyrics(@Video, '装飾', 0, Settings, 0, 0),
    'shadow render failed');
  FindVisibleBounds(DecoratedLeft, DecoratedTop, DecoratedRight,
    DecoratedBottom);
  Check((DecoratedRight > BaseRight) and (DecoratedBottom > BaseBottom),
    'shadow did not expand visible bounds toward its offset');

  Settings.ShadowEnabled := False;
  Settings.BeforeColor.A := 96;
  Settings.AfterColor := Settings.BeforeColor;
  Check(RenderLyrics(@Video, '装飾', 0, Settings, 0, 0),
    'transparent text render failed');
  Check((MaximumAlpha > 0) and (MaximumAlpha <= 96),
    'text opacity was not applied to the rendered pixels');
end;

begin
  InitializeLyricsRenderer;
  try
    TestRubyParser;
    TestResolvedDisplayUnits;
    TestSerifSyncEffects;
    TestLineUnitsShareBaseline;
    TestLyricsLayersAreComposited;
    TestVisibleJapaneseLyrics;
    TestRubyIsDrawnAboveLyrics;
    TestConsumedLyricsUseAfterColor;
    TestSilentMarksSwitchAtNoteBoundary;
    TestFourColorChangeModes;
    TestRubyAndBaseShareProgress;
    TestPositionOffsetsMoveBaseAndRuby;
    TestConfiguredColorsAreUsed;
    TestConfiguredFontSizesChangeBounds;
    TestConfiguredCharacterSpacingChangesWidth;
    TestConfiguredFontStylesAreUsed;
    TestDisplayTypes;
    TestLyricsAnimations;
    TestAnimationTimeItems;
    TestRubyGapAdjustmentChangesRowDistance;
    TestFreePlacementCoordinates;
    TestFreePlacementRubyKeepsBaseBottom;
    TestFreePlacementScale;
    TestFreePlacementElementColors;
    TestFreePlacementElementFontSize;
    TestFreePlacementElementFontStyle;
    TestFreePlacementBaseCharacterSpacing;
    TestFreePlacementRubyCharacterSpacing;
    TestFreePlacementRubyOffset;
    TestTextDecorationAndOpacity;
    TestEmptyLyricsIsTransparent;
    TestInputImageIsPreserved;
    Writeln('PASS');
  finally
    FinalizeLyricsRenderer;
  end;
end.
