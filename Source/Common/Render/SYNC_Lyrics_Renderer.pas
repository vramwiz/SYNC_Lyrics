unit SYNC_Lyrics_Renderer;

// 歌詞文字列をAviUtl2のRGBA画像へ変換する最小描画処理を担当する。

interface

uses
  AviUtl2FilterTypes;

type
  // AviUtl2の色項目から独立して描画処理へ渡す不透明RGB色。
  TLyricsRenderColor = record
    R: Byte;
    G: Byte;
    B: Byte;
  end;

  // 1行の本文とルビに適用する基本表示設定。
  TLyricsRenderSettings = record
    BaseFontName: string;
    RubyFontName: string;
    BaseBold: Boolean;
    BaseItalic: Boolean;
    BaseUnderline: Boolean;
    BaseStrikeOut: Boolean;
    RubyBold: Boolean;
    RubyItalic: Boolean;
    RubyUnderline: Boolean;
    RubyStrikeOut: Boolean;
    BaseFontHeight: Integer;
    RubyFontHeight: Integer;
    RubyGapAdjustment: Integer;
    BaseCharacterSpacing: Integer;
    BeforeColor: TLyricsRenderColor;
    AfterColor: TLyricsRenderColor;
  end;

// 描画用の共有資源を初期化する。Filterの初期化時に1回だけ呼び出す。
procedure InitializeLyricsRenderer;

// 従来の検証済み表示と同じ基本表示設定を返す。
function DefaultLyricsRenderSettings: TLyricsRenderSettings;

// 入力文字列を中央基準の指定座標へ配置し、表示単位進捗をクリッピング描画してAviUtl2へ渡す。
function RenderLyrics(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings; PositionX, PositionY: Integer): Boolean;

// 描画用の共有資源を解放する。処理中のコールバックがない状態で呼び出す。
procedure FinalizeLyricsRenderer;

implementation

uses
  System.Math,
  System.SysUtils,
  SYNC_Lyrics_LyricParser,
  Winapi.Windows;

const
  MAX_RENDER_DIMENSION = 16384;
  DEFAULT_LYRIC_FONT_HEIGHT = 96;
  DEFAULT_RUBY_FONT_HEIGHT = 42;
  DEFAULT_RUBY_GAP = 4;
  MIN_FONT_HEIGHT = 1;
  MAX_FONT_HEIGHT = 1024;
  MIN_RUBY_GAP = -1024;
  MAX_RUBY_GAP = 1024;
  MIN_CHARACTER_SPACING = -1024;
  MAX_CHARACTER_SPACING = 1024;

var
  RendererLock: TRTLCriticalSection;
  RendererInitialized: Boolean;

function ResolveRenderSize(Video: PFILTER_PROC_VIDEO; out Width, Height: Integer): Boolean;
begin
  Width := 0;
  Height := 0;
  if (Video = nil) or not Assigned(Video^.SetImageData) then
    Exit(False);

  if Video^.Object_ <> nil then
  begin
    Width := Video^.Object_^.Width;
    Height := Video^.Object_^.Height;
  end;
  if ((Width <= 0) or (Height <= 0)) and (Video^.Scene <> nil) then
  begin
    Width := Video^.Scene^.Width;
    Height := Video^.Scene^.Height;
  end;

  Result := (Width > 0) and (Height > 0) and
    (Width <= MAX_RENDER_DIMENSION) and (Height <= MAX_RENDER_DIMENSION);
end;

procedure ConvertDibToRgba(ColorBits, MaskBits: Pointer;
  Buffer: PPIXEL_RGBA; PixelCount: NativeInt);
var
  Coverage: Byte;
  CoverageSrc: PByte;
  Dst: PPIXEL_RGBA;
  ColorSrc: PByte;
  I: NativeInt;
begin
  ColorSrc := ColorBits;
  CoverageSrc := MaskBits;
  Dst := Buffer;
  for I := 0 to PixelCount - 1 do
  begin
    // 色とは別の白文字マスクからカバレッジを取得し、黒や暗色でも透明度を失わないようにする。
    Coverage := Max(CoverageSrc[0], Max(CoverageSrc[1], CoverageSrc[2]));
    Dst^.R := ColorSrc[2];
    Dst^.G := ColorSrc[1];
    Dst^.B := ColorSrc[0];
    Dst^.A := Coverage;
    Inc(ColorSrc, 4);
    Inc(CoverageSrc, 4);
    Inc(Dst);
  end;
end;

function DefaultLyricsRenderSettings: TLyricsRenderSettings;
begin
  Result.BaseFontName := 'Yu Gothic UI';
  Result.RubyFontName := 'Yu Gothic UI';
  Result.BaseBold := True;
  Result.BaseItalic := False;
  Result.BaseUnderline := False;
  Result.BaseStrikeOut := False;
  Result.RubyBold := True;
  Result.RubyItalic := False;
  Result.RubyUnderline := False;
  Result.RubyStrikeOut := False;
  Result.BaseFontHeight := DEFAULT_LYRIC_FONT_HEIGHT;
  Result.RubyFontHeight := DEFAULT_RUBY_FONT_HEIGHT;
  Result.RubyGapAdjustment := 0;
  Result.BaseCharacterSpacing := 0;
  Result.BeforeColor.R := 255;
  Result.BeforeColor.G := 255;
  Result.BeforeColor.B := 255;
  Result.AfterColor.R := 0;
  Result.AfterColor.G := 255;
  Result.AfterColor.B := 255;
end;

function LyricsColorToColorRef(const Color: TLyricsRenderColor): COLORREF;
begin
  Result := Color.R or (Cardinal(Color.G) shl 8) or
    (Cardinal(Color.B) shl 16);
end;

function CreateLyricsFont(const FontName: string; FontHeight: Integer;
  Bold, Italic, Underline, StrikeOut: Boolean): HFONT;
var
  FontWeight: Integer;
  ResolvedFontName: string;
begin
  ResolvedFontName := FontName;
  if ResolvedFontName = '' then
    ResolvedFontName := 'Yu Gothic UI';
  FontHeight := EnsureRange(FontHeight, MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  FontWeight := FW_NORMAL;
  if Bold then
    FontWeight := FW_BOLD;
  Result := CreateFontW(FontHeight, 0, 0, 0, FontWeight,
    Ord(Italic), Ord(Underline), Ord(StrikeOut),
    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
    ANTIALIASED_QUALITY, DEFAULT_PITCH or FF_DONTCARE,
    PWideChar(ResolvedFontName));
end;

function MeasureTextWidth(DC: HDC; const Text: string): Integer;
var
  TextSize: TSize;
begin
  if Text = '' then
    Exit(0);
  if not GetTextExtentPoint32W(DC, PWideChar(Text), Length(Text), TextSize) then
    Exit(0);
  Result := TextSize.cx;
end;

function GetDisplayUnitProgress(const Units: TLyricsDisplayUnits; UnitIndex: Integer;
  ProgressUnits: Double): Double;
begin
  if (UnitIndex < 0) or (UnitIndex >= Length(Units)) then
    Exit(0);
  if Units[UnitIndex].SyncUnitIndex < 0 then
    Exit(0);
  Result := EnsureRange(ProgressUnits -
    Units[UnitIndex].SyncUnitIndex, 0.0, 1.0);
end;

function FindRubyUnitIndex(const Units: TLyricsDisplayUnits; RubyIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(Units) do
    if Units[I].RubyIndex = RubyIndex then
      Exit(I);
end;

function MeasureBaseProgressWidth(DC: HDC; const PlainText: string;
  const Units: TLyricsDisplayUnits; ProgressUnits: Double): Integer;
var
  PrefixText: string;
  Progress: Double;
  UnitIndex: Integer;
  UnitText: string;
begin
  Result := 0;
  for UnitIndex := 0 to High(Units) do
  begin
    Progress := GetDisplayUnitProgress(Units, UnitIndex, ProgressUnits);
    if Progress <= 0 then
      Break;
    PrefixText := Copy(PlainText, 1, Units[UnitIndex].BaseStart - 1);
    UnitText := Copy(PlainText, Units[UnitIndex].BaseStart, Units[UnitIndex].BaseLength);
    Result := MeasureTextWidth(DC, PrefixText) +
      Round(MeasureTextWidth(DC, UnitText) * Progress);
    if Progress < 1 then
      Break;
  end;
end;

procedure DrawParsedLyrics(DC: HDC; Width, Height: Integer; const Source: string;
  ProgressUnits: Double; const Settings: TLyricsRenderSettings;
  PositionX, PositionY: Integer);
var
  BaseFont: HFONT;
  BaseFontHeight: Integer;
  BaseCharacterSpacing: Integer;
  BaseProgressWidth: Integer;
  BaseWidth: Integer;
  BaseX: Integer;
  BaseY: Integer;
  ClipState: Integer;
  I: Integer;
  OldFont: HGDIOBJ;
  OldCharacterSpacing: Integer;
  PlainText: string;
  PrefixText: string;
  PrefixWidth: Integer;
  RubyFont: HFONT;
  RubyFontHeight: Integer;
  RubyGap: Integer;
  RubySpans: TLyricsRubySpans;
  RubyWidth: Integer;
  RubyX: Integer;
  RubyY: Integer;
  SpanText: string;
  SpanWidth: Integer;
  UnitIndex: Integer;
  UnitProgress: Double;
  Units: TLyricsDisplayUnits;
begin
  ParseLyrics(Source, PlainText, RubySpans);
  BuildLyricsDisplayUnits(PlainText, RubySpans, Units);
  BaseFontHeight := EnsureRange(Settings.BaseFontHeight,
    MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  RubyFontHeight := EnsureRange(Settings.RubyFontHeight,
    MIN_FONT_HEIGHT, MAX_FONT_HEIGHT);
  RubyGap := EnsureRange(DEFAULT_RUBY_GAP + Settings.RubyGapAdjustment,
    MIN_RUBY_GAP, MAX_RUBY_GAP);
  BaseCharacterSpacing := EnsureRange(Settings.BaseCharacterSpacing,
    MIN_CHARACTER_SPACING, MAX_CHARACTER_SPACING);
  BaseFont := CreateLyricsFont(Settings.BaseFontName, BaseFontHeight,
    Settings.BaseBold, Settings.BaseItalic, Settings.BaseUnderline,
    Settings.BaseStrikeOut);
  RubyFont := CreateLyricsFont(Settings.RubyFontName, RubyFontHeight,
    Settings.RubyBold, Settings.RubyItalic, Settings.RubyUnderline,
    Settings.RubyStrikeOut);
  if (BaseFont = 0) or (RubyFont = 0) then
  begin
    if BaseFont <> 0 then
      DeleteObject(BaseFont);
    if RubyFont <> 0 then
      DeleteObject(RubyFont);
    Exit;
  end;
  try
    OldFont := SelectObject(DC, BaseFont);
    OldCharacterSpacing := GetTextCharacterExtra(DC);
    SetTextCharacterExtra(DC, BaseCharacterSpacing);
    BaseWidth := MeasureTextWidth(DC, PlainText);
    // X・Yはグループ制御後に各行だけを微調整する中央基準のオフセットとする。
    BaseX := (Width - BaseWidth) div 2 + PositionX;
    if Length(RubySpans) = 0 then
      BaseY := (Height - BaseFontHeight) div 2 + PositionY
    else
      BaseY := (Height - (RubyFontHeight + RubyGap + BaseFontHeight)) div 2 +
        RubyFontHeight + RubyGap + PositionY;
    SetTextColor(DC, LyricsColorToColorRef(Settings.BeforeColor));
    TextOutW(DC, BaseX, BaseY, PWideChar(PlainText), Length(PlainText));

    if Length(RubySpans) > 0 then
    begin
      SelectObject(DC, RubyFont);
      SetTextCharacterExtra(DC, 0);
      RubyY := BaseY - RubyGap - RubyFontHeight;
      for I := 0 to High(RubySpans) do
      begin
        PrefixText := Copy(PlainText, 1, RubySpans[I].BaseStart - 1);
        SpanText := Copy(PlainText, RubySpans[I].BaseStart, RubySpans[I].BaseLength);
        SelectObject(DC, BaseFont);
        SetTextCharacterExtra(DC, BaseCharacterSpacing);
        PrefixWidth := MeasureTextWidth(DC, PrefixText);
        SpanWidth := MeasureTextWidth(DC, SpanText);
        SelectObject(DC, RubyFont);
        SetTextCharacterExtra(DC, 0);
        RubyWidth := MeasureTextWidth(DC, RubySpans[I].RubyText);
        RubyX := BaseX + PrefixWidth + (SpanWidth - RubyWidth) div 2;
        SetTextColor(DC, LyricsColorToColorRef(Settings.BeforeColor));
        TextOutW(DC, RubyX, RubyY, PWideChar(RubySpans[I].RubyText),
          Length(RubySpans[I].RubyText));

        UnitIndex := FindRubyUnitIndex(Units, I);
        UnitProgress := GetDisplayUnitProgress(Units, UnitIndex, ProgressUnits);
        if UnitProgress > 0 then
        begin
          ClipState := SaveDC(DC);
          try
            IntersectClipRect(DC, RubyX, RubyY,
              RubyX + Round(RubyWidth * UnitProgress), RubyY + RubyFontHeight);
            SetTextColor(DC, LyricsColorToColorRef(Settings.AfterColor));
            TextOutW(DC, RubyX, RubyY, PWideChar(RubySpans[I].RubyText),
              Length(RubySpans[I].RubyText));
          finally
            RestoreDC(DC, ClipState);
          end;
        end;
      end;
    end;

    SelectObject(DC, BaseFont);
    SetTextCharacterExtra(DC, BaseCharacterSpacing);
    BaseProgressWidth := MeasureBaseProgressWidth(DC, PlainText, Units, ProgressUnits);
    if BaseProgressWidth > 0 then
    begin
      ClipState := SaveDC(DC);
      try
        IntersectClipRect(DC, BaseX, BaseY, BaseX + BaseProgressWidth,
          BaseY + BaseFontHeight);
        SetTextColor(DC, LyricsColorToColorRef(Settings.AfterColor));
        TextOutW(DC, BaseX, BaseY, PWideChar(PlainText), Length(PlainText));
      finally
        RestoreDC(DC, ClipState);
      end;
    end;
    SetTextCharacterExtra(DC, OldCharacterSpacing);
    SelectObject(DC, OldFont);
  finally
    DeleteObject(RubyFont);
    DeleteObject(BaseFont);
  end;
end;

function RenderLocked(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  PositionX, PositionY, Width, Height: Integer): Boolean;
var
  Bitmap: HBITMAP;
  BitmapInfo: TBitmapInfo;
  Bits: Pointer;
  Buffer: PPIXEL_RGBA;
  DC: HDC;
  MaskBitmap: HBITMAP;
  MaskBits: Pointer;
  MaskDC: HDC;
  MaskOldBitmap: HGDIOBJ;
  MaskSettings: TLyricsRenderSettings;
  OldBitmap: HGDIOBJ;
  PixelCount: NativeInt;
begin
  Result := False;
  PixelCount := NativeInt(Width) * Height;
  GetMem(Buffer, PixelCount * SizeOf(TPIXEL_RGBA));
  try
    FillChar(Buffer^, PixelCount * SizeOf(TPIXEL_RGBA), 0);

    // 空文字でも透明画像を確定し、直前フレームの歌詞を残さない。
    if (Lyrics = nil) or (Lyrics^ = #0) then
    begin
      Video^.SetImageData(Buffer, Width, Height);
      Exit(True);
    end;

    FillChar(BitmapInfo, SizeOf(BitmapInfo), 0);
    BitmapInfo.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
    BitmapInfo.bmiHeader.biWidth := Width;
    BitmapInfo.bmiHeader.biHeight := -Height;
    BitmapInfo.bmiHeader.biPlanes := 1;
    BitmapInfo.bmiHeader.biBitCount := 32;
    BitmapInfo.bmiHeader.biCompression := BI_RGB;

    Bits := nil;
    Bitmap := CreateDIBSection(0, BitmapInfo, DIB_RGB_COLORS, Bits, 0, 0);
    if (Bitmap = 0) or (Bits = nil) then
      Exit;
    try
      FillChar(Bits^, PixelCount * 4, 0);
      MaskBits := nil;
      MaskBitmap := CreateDIBSection(0, BitmapInfo, DIB_RGB_COLORS,
        MaskBits, 0, 0);
      if (MaskBitmap = 0) or (MaskBits = nil) then
        Exit;
      try
        FillChar(MaskBits^, PixelCount * 4, 0);
        DC := CreateCompatibleDC(0);
        MaskDC := CreateCompatibleDC(0);
        if (DC = 0) or (MaskDC = 0) then
        begin
          if DC <> 0 then
            DeleteDC(DC);
          if MaskDC <> 0 then
            DeleteDC(MaskDC);
          Exit;
        end;
        try
          OldBitmap := SelectObject(DC, Bitmap);
          MaskOldBitmap := SelectObject(MaskDC, MaskBitmap);
          SetBkMode(DC, TRANSPARENT);
          SetBkMode(MaskDC, TRANSPARENT);
          DrawParsedLyrics(DC, Width, Height, string(Lyrics), ProgressUnits,
            Settings, PositionX, PositionY);
          MaskSettings := Settings;
          MaskSettings.BeforeColor.R := 255;
          MaskSettings.BeforeColor.G := 255;
          MaskSettings.BeforeColor.B := 255;
          MaskSettings.AfterColor := MaskSettings.BeforeColor;
          DrawParsedLyrics(MaskDC, Width, Height, string(Lyrics), ProgressUnits,
            MaskSettings, PositionX, PositionY);
          SelectObject(MaskDC, MaskOldBitmap);
          SelectObject(DC, OldBitmap);
        finally
          DeleteDC(MaskDC);
          DeleteDC(DC);
        end;

        ConvertDibToRgba(Bits, MaskBits, Buffer, PixelCount);
        Video^.SetImageData(Buffer, Width, Height);
        Result := True;
      finally
        DeleteObject(MaskBitmap);
      end;
    finally
      DeleteObject(Bitmap);
    end;
  finally
    FreeMem(Buffer);
  end;
end;

function RenderLyrics(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
  const Settings: TLyricsRenderSettings;
  PositionX, PositionY: Integer): Boolean;
var
  Height: Integer;
  Width: Integer;
begin
  Result := ResolveRenderSize(Video, Width, Height);
  if not Result then
    Exit;

  EnterCriticalSection(RendererLock);
  try
    Result := RenderLocked(Video, Lyrics, ProgressUnits, Settings,
      PositionX, PositionY, Width, Height);
  finally
    LeaveCriticalSection(RendererLock);
  end;
end;

procedure InitializeLyricsRenderer;
begin
  if RendererInitialized then
    Exit;
  InitializeCriticalSection(RendererLock);
  RendererInitialized := True;
end;

procedure FinalizeLyricsRenderer;
begin
  if not RendererInitialized then
    Exit;
  DeleteCriticalSection(RendererLock);
  RendererInitialized := False;
end;

end.
