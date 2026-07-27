unit SYNC_Lyrics_Renderer;

// 歌詞文字列をAviUtl2のRGBA画像へ変換する最小描画処理を担当する。

interface

uses
  AviUtl2FilterTypes;

// 描画用の共有資源を初期化する。Filterの初期化時に1回だけ呼び出す。
procedure InitializeLyricsRenderer;

// 入力文字列を中央基準の指定座標へ配置し、表示単位進捗をクリッピング描画してAviUtl2へ渡す。
function RenderLyrics(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
  PositionX, PositionY: Integer): Boolean;

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
  LYRIC_FONT_HEIGHT = 96;
  RUBY_FONT_HEIGHT = 42;
  RUBY_GAP = 4;
  COLOR_BEFORE = $00FFFFFF;
  COLOR_AFTER = $00FFFF00;

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

procedure ConvertDibToRgba(Bits: Pointer; Buffer: PPIXEL_RGBA; PixelCount: NativeInt);
var
  Coverage: Byte;
  Dst: PPIXEL_RGBA;
  Src: PByte;
  I: NativeInt;
begin
  Src := Bits;
  Dst := Buffer;
  for I := 0 to PixelCount - 1 do
  begin
    // GDIはアルファを書かないため、描画色の最大成分をカバレッジとしてRGBAへ移す。
    Coverage := Max(Src[0], Max(Src[1], Src[2]));
    Dst^.R := Src[2];
    Dst^.G := Src[1];
    Dst^.B := Src[0];
    Dst^.A := Coverage;
    Inc(Src, 4);
    Inc(Dst);
  end;
end;

function CreateLyricsFont(FontHeight: Integer): HFONT;
begin
  Result := CreateFontW(FontHeight, 0, 0, 0, FW_BOLD, 0, 0, 0,
    DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
    ANTIALIASED_QUALITY, DEFAULT_PITCH or FF_DONTCARE, 'Yu Gothic UI');
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
  Result := EnsureRange(ProgressUnits - UnitIndex, 0.0, 1.0);
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
  ProgressUnits: Double; PositionX, PositionY: Integer);
var
  BaseFont: HFONT;
  BaseProgressWidth: Integer;
  BaseWidth: Integer;
  BaseX: Integer;
  BaseY: Integer;
  ClipState: Integer;
  I: Integer;
  OldFont: HGDIOBJ;
  PlainText: string;
  PrefixText: string;
  PrefixWidth: Integer;
  RubyFont: HFONT;
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
  BaseFont := CreateLyricsFont(LYRIC_FONT_HEIGHT);
  RubyFont := CreateLyricsFont(RUBY_FONT_HEIGHT);
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
    BaseWidth := MeasureTextWidth(DC, PlainText);
    // X・Yはグループ制御後に各行だけを微調整する中央基準のオフセットとする。
    BaseX := (Width - BaseWidth) div 2 + PositionX;
    if Length(RubySpans) = 0 then
      BaseY := (Height - LYRIC_FONT_HEIGHT) div 2 + PositionY
    else
      BaseY := (Height - (RUBY_FONT_HEIGHT + RUBY_GAP + LYRIC_FONT_HEIGHT)) div 2 +
        RUBY_FONT_HEIGHT + RUBY_GAP + PositionY;
    SetTextColor(DC, COLOR_BEFORE);
    TextOutW(DC, BaseX, BaseY, PWideChar(PlainText), Length(PlainText));

    if Length(RubySpans) > 0 then
    begin
      SelectObject(DC, RubyFont);
      RubyY := BaseY - RUBY_GAP - RUBY_FONT_HEIGHT;
      for I := 0 to High(RubySpans) do
      begin
        PrefixText := Copy(PlainText, 1, RubySpans[I].BaseStart - 1);
        SpanText := Copy(PlainText, RubySpans[I].BaseStart, RubySpans[I].BaseLength);
        SelectObject(DC, BaseFont);
        PrefixWidth := MeasureTextWidth(DC, PrefixText);
        SpanWidth := MeasureTextWidth(DC, SpanText);
        SelectObject(DC, RubyFont);
        RubyWidth := MeasureTextWidth(DC, RubySpans[I].RubyText);
        RubyX := BaseX + PrefixWidth + (SpanWidth - RubyWidth) div 2;
        SetTextColor(DC, COLOR_BEFORE);
        TextOutW(DC, RubyX, RubyY, PWideChar(RubySpans[I].RubyText),
          Length(RubySpans[I].RubyText));

        UnitIndex := FindRubyUnitIndex(Units, I);
        UnitProgress := GetDisplayUnitProgress(Units, UnitIndex, ProgressUnits);
        if UnitProgress > 0 then
        begin
          ClipState := SaveDC(DC);
          try
            IntersectClipRect(DC, RubyX, RubyY,
              RubyX + Round(RubyWidth * UnitProgress), RubyY + RUBY_FONT_HEIGHT);
            SetTextColor(DC, COLOR_AFTER);
            TextOutW(DC, RubyX, RubyY, PWideChar(RubySpans[I].RubyText),
              Length(RubySpans[I].RubyText));
          finally
            RestoreDC(DC, ClipState);
          end;
        end;
      end;
    end;

    SelectObject(DC, BaseFont);
    BaseProgressWidth := MeasureBaseProgressWidth(DC, PlainText, Units, ProgressUnits);
    if BaseProgressWidth > 0 then
    begin
      ClipState := SaveDC(DC);
      try
        IntersectClipRect(DC, BaseX, BaseY, BaseX + BaseProgressWidth,
          BaseY + LYRIC_FONT_HEIGHT);
        SetTextColor(DC, COLOR_AFTER);
        TextOutW(DC, BaseX, BaseY, PWideChar(PlainText), Length(PlainText));
      finally
        RestoreDC(DC, ClipState);
      end;
    end;
    SelectObject(DC, OldFont);
  finally
    DeleteObject(RubyFont);
    DeleteObject(BaseFont);
  end;
end;

function RenderLocked(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
  PositionX, PositionY, Width, Height: Integer): Boolean;
var
  Bitmap: HBITMAP;
  BitmapInfo: TBitmapInfo;
  Bits: Pointer;
  Buffer: PPIXEL_RGBA;
  DC: HDC;
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
      DC := CreateCompatibleDC(0);
      if DC = 0 then
        Exit;
      try
        OldBitmap := SelectObject(DC, Bitmap);
        SetBkMode(DC, TRANSPARENT);
        DrawParsedLyrics(DC, Width, Height, string(Lyrics), ProgressUnits,
          PositionX, PositionY);
        SelectObject(DC, OldBitmap);
      finally
        DeleteDC(DC);
      end;

      ConvertDibToRgba(Bits, Buffer, PixelCount);
      Video^.SetImageData(Buffer, Width, Height);
      Result := True;
    finally
      DeleteObject(Bitmap);
    end;
  finally
    FreeMem(Buffer);
  end;
end;

function RenderLyrics(Video: PFILTER_PROC_VIDEO; Lyrics: LPCWSTR; ProgressUnits: Double;
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
    Result := RenderLocked(Video, Lyrics, ProgressUnits, PositionX, PositionY,
      Width, Height);
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
