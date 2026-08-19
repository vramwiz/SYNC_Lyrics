unit SYNC_Lyrics_DisplaySettingsData;

// Serializes common display settings and free placements into one string item.

interface

type
  TDisplayCommonSettings = record
    PositionX: Integer;
    PositionY: Integer;
    BaseFontName: string;
    RubyFontName: string;
    BaseFontHeight: Integer;
    RubyFontHeight: Integer;
    BaseFontStyle: Byte;
    RubyFontStyle: Byte;
    BeforeColor: Cardinal;
    AfterColor: Cardinal;
    BeforeOpacity: Byte;
    AfterOpacity: Byte;
    BeforeOutlineColor: Cardinal;
    AfterOutlineColor: Cardinal;
    BeforeOutlineOpacity: Byte;
    AfterOutlineOpacity: Byte;
    BeforeShadowColor: Cardinal;
    AfterShadowColor: Cardinal;
    BeforeShadowOpacity: Byte;
    AfterShadowOpacity: Byte;
    BeforeBlurColor: Cardinal;
    AfterBlurColor: Cardinal;
    BeforeBlurOpacity: Byte;
    AfterBlurOpacity: Byte;
    OutlineEnabled: Boolean;
    OutlineWidth: Single;
    OutlineBlur: Single;
    ShadowEnabled: Boolean;
    ShadowOffsetX: Single;
    ShadowOffsetY: Single;
    ShadowBlur: Single;
    ShadowSpread: Single;
    RubyGapAdjustment: Integer;
    BaseCharacterSpacing: Integer;
    RubyCharacterSpacing: Integer;
  end;

  TDisplayPlacementItem = record
    Index: Integer;
    X: Single;
    Y: Single;
    ScaleX: Single;
    ScaleY: Single;
    BaseFontName: string;
    RubyFontName: string;
    HasBeforeColor: Boolean;
    BeforeColor: Cardinal;
    HasAfterColor: Boolean;
    AfterColor: Cardinal;
    HasBaseFontHeight: Boolean;
    BaseFontHeight: Word;
    HasRubyFontHeight: Boolean;
    RubyFontHeight: Word;
    HasBaseFontStyle: Boolean;
    BaseFontStyle: Byte;
    HasRubyFontStyle: Boolean;
    RubyFontStyle: Byte;
    HasBaseCharacterSpacing: Boolean;
    BaseCharacterSpacing: SmallInt;
    HasRubyCharacterSpacing: Boolean;
    RubyCharacterSpacing: SmallInt;
    HasRubyOffsetX: Boolean;
    RubyOffsetX: SmallInt;
    HasRubyOffsetY: Boolean;
    RubyOffsetY: SmallInt;
  end;
  TDisplayPlacementItems = TArray<TDisplayPlacementItem>;

const
  MAX_DISPLAY_PLACEMENT_ITEMS = 100;
  // Keep generated text within the default Win32 edit-control input limit.
  MAX_DISPLAY_SETTINGS_TEXT_LENGTH = 32767;

function CalculateDisplayLyricsHash(const Lyrics: string): Cardinal;
function DefaultDisplayCommonSettings: TDisplayCommonSettings;
function TryDecodeDisplaySettingsText(const Text, Lyrics: string;
  out Common: TDisplayCommonSettings; out Items: TDisplayPlacementItems;
  out PlacementsMatchLyrics: Boolean): Boolean;
function TryEncodeDisplaySettingsText(const Lyrics: string;
  const Common: TDisplayCommonSettings;
  const Items: TDisplayPlacementItems; out Text: string): Boolean;

implementation

uses
  System.Classes,
  System.Math,
  System.SysUtils;

const
  DISPLAY_SETTINGS_TEXT_PREFIX = 'SL2';
  FNV1A_OFFSET_BASIS = Cardinal(2166136261);
  FNV1A_PRIME = Cardinal(16777619);
  MIN_PLACEMENT_SCALE = 0.05;
  MAX_PLACEMENT_SCALE = 10.0;

  FLAG_BEFORE_COLOR = 1;
  FLAG_AFTER_COLOR = 2;
  FLAG_BASE_FONT_HEIGHT = 4;
  FLAG_RUBY_FONT_HEIGHT = 8;
  FLAG_BASE_FONT_STYLE = 16;
  FLAG_RUBY_FONT_STYLE = 32;
  FLAG_BASE_CHARACTER_SPACING = 64;
  FLAG_RUBY_CHARACTER_SPACING = 128;
  FLAG_RUBY_OFFSET_X = 256;
  FLAG_RUBY_OFFSET_Y = 512;

function DefaultDisplayCommonSettings: TDisplayCommonSettings;
begin
  Result.PositionX := 0;
  Result.PositionY := 0;
  Result.BaseFontName := 'Yu Gothic UI';
  Result.RubyFontName := 'Yu Gothic UI';
  Result.BaseFontHeight := 96;
  Result.RubyFontHeight := 42;
  Result.BaseFontStyle := 1;
  Result.RubyFontStyle := 1;
  Result.BeforeColor := $00FFFFFF;
  Result.AfterColor := $00FFFF00;
  Result.BeforeOpacity := 255;
  Result.AfterOpacity := 255;
  Result.BeforeOutlineColor := $00000000;
  Result.AfterOutlineColor := $00000000;
  Result.BeforeOutlineOpacity := 255;
  Result.AfterOutlineOpacity := 255;
  Result.BeforeShadowColor := $00000000;
  Result.AfterShadowColor := $00000000;
  Result.BeforeShadowOpacity := 160;
  Result.AfterShadowOpacity := 160;
  Result.BeforeBlurColor := $00000000;
  Result.AfterBlurColor := $00000000;
  Result.BeforeBlurOpacity := 255;
  Result.AfterBlurOpacity := 255;
  Result.OutlineEnabled := False;
  Result.OutlineWidth := 8;
  Result.OutlineBlur := 0;
  Result.ShadowEnabled := False;
  Result.ShadowOffsetX := 10;
  Result.ShadowOffsetY := 10;
  Result.ShadowBlur := 4;
  Result.ShadowSpread := 0;
  Result.RubyGapAdjustment := 0;
  Result.BaseCharacterSpacing := 0;
  Result.RubyCharacterSpacing := 0;
end;

function CalculateDisplayLyricsHash(const Lyrics: string): Cardinal;
var
  Bytes: TBytes;
  I: Integer;
begin
  Result := FNV1A_OFFSET_BASIS;
  Bytes := TEncoding.UTF8.GetBytes(Lyrics);
  for I := 0 to High(Bytes) do
  begin
    Result := Result xor Bytes[I];
    Result := Cardinal((UInt64(Result) * FNV1A_PRIME) and $FFFFFFFF);
  end;
end;

function EncodeUtf8Hex(const Value: string): string;
const
  HEX: array[0..15] of Char = '0123456789ABCDEF';
var
  Bytes: TBytes;
  I: Integer;
begin
  Bytes := TEncoding.UTF8.GetBytes(Value);
  SetLength(Result, Length(Bytes) * 2);
  for I := 0 to High(Bytes) do
  begin
    Result[I * 2 + 1] := HEX[Bytes[I] shr 4];
    Result[I * 2 + 2] := HEX[Bytes[I] and $0F];
  end;
end;

function HexDigit(Value: Char; out Digit: Byte): Boolean;
begin
  case Value of
    '0'..'9':
      Digit := Ord(Value) - Ord('0');
    'A'..'F':
      Digit := Ord(Value) - Ord('A') + 10;
    'a'..'f':
      Digit := Ord(Value) - Ord('a') + 10;
  else
    Exit(False);
  end;
  Result := True;
end;

function TryDecodeUtf8Hex(const Value: string; out Decoded: string): Boolean;
var
  Bytes: TBytes;
  HighDigit: Byte;
  I: Integer;
  LowDigit: Byte;
begin
  Decoded := '';
  if Odd(Length(Value)) then
    Exit(False);
  SetLength(Bytes, Length(Value) div 2);
  for I := 0 to High(Bytes) do
  begin
    if not HexDigit(Value[I * 2 + 1], HighDigit) or
      not HexDigit(Value[I * 2 + 2], LowDigit) then
      Exit(False);
    Bytes[I] := (HighDigit shl 4) or LowDigit;
  end;
  try
    Decoded := TEncoding.UTF8.GetString(Bytes);
  except
    Exit(False);
  end;
  Result := True;
end;

function IsValidCoordinate(Value: Single): Boolean;
begin
  Result := not IsNan(Value) and not IsInfinite(Value) and
    (Value >= Low(SmallInt)) and (Value <= High(SmallInt));
end;

function IsValidScale(Value: Single): Boolean;
begin
  Result := not IsNan(Value) and not IsInfinite(Value) and
    (Value >= MIN_PLACEMENT_SCALE) and
    (Value <= MAX_PLACEMENT_SCALE);
end;

function BuildFlags(const Item: TDisplayPlacementItem): Integer;
begin
  Result := 0;
  if Item.HasBeforeColor then
    Result := Result or FLAG_BEFORE_COLOR;
  if Item.HasAfterColor then
    Result := Result or FLAG_AFTER_COLOR;
  if Item.HasBaseFontHeight then
    Result := Result or FLAG_BASE_FONT_HEIGHT;
  if Item.HasRubyFontHeight then
    Result := Result or FLAG_RUBY_FONT_HEIGHT;
  if Item.HasBaseFontStyle then
    Result := Result or FLAG_BASE_FONT_STYLE;
  if Item.HasRubyFontStyle then
    Result := Result or FLAG_RUBY_FONT_STYLE;
  if Item.HasBaseCharacterSpacing then
    Result := Result or FLAG_BASE_CHARACTER_SPACING;
  if Item.HasRubyCharacterSpacing then
    Result := Result or FLAG_RUBY_CHARACTER_SPACING;
  if Item.HasRubyOffsetX then
    Result := Result or FLAG_RUBY_OFFSET_X;
  if Item.HasRubyOffsetY then
    Result := Result or FLAG_RUBY_OFFSET_Y;
end;

function IsValidCommonSettings(
  const Common: TDisplayCommonSettings): Boolean;
begin
  Result := (Common.PositionX >= -10000) and
    (Common.PositionX <= 10000) and
    (Common.PositionY >= -10000) and (Common.PositionY <= 10000) and
    (Common.BaseFontName <> '') and (Common.RubyFontName <> '') and
    (Common.BaseFontHeight >= 1) and (Common.BaseFontHeight <= 1024) and
    (Common.RubyFontHeight >= 1) and (Common.RubyFontHeight <= 1024) and
    (Common.BaseFontStyle <= $0F) and (Common.RubyFontStyle <= $0F) and
    (Common.BeforeColor <= $FFFFFF) and
    (Common.AfterColor <= $FFFFFF) and
    (Common.BeforeOutlineColor <= $FFFFFF) and
    (Common.AfterOutlineColor <= $FFFFFF) and
    (Common.BeforeShadowColor <= $FFFFFF) and
    (Common.AfterShadowColor <= $FFFFFF) and
    (Common.BeforeBlurColor <= $FFFFFF) and
    (Common.AfterBlurColor <= $FFFFFF) and
    not IsNan(Common.OutlineWidth) and not IsInfinite(Common.OutlineWidth) and
    (Common.OutlineWidth >= 0) and (Common.OutlineWidth <= 500) and
    not IsNan(Common.OutlineBlur) and not IsInfinite(Common.OutlineBlur) and
    (Common.OutlineBlur >= 0) and (Common.OutlineBlur <= 500) and
    not IsNan(Common.ShadowOffsetX) and not IsInfinite(Common.ShadowOffsetX) and
    (Common.ShadowOffsetX >= -2000) and (Common.ShadowOffsetX <= 2000) and
    not IsNan(Common.ShadowOffsetY) and not IsInfinite(Common.ShadowOffsetY) and
    (Common.ShadowOffsetY >= -2000) and (Common.ShadowOffsetY <= 2000) and
    not IsNan(Common.ShadowBlur) and not IsInfinite(Common.ShadowBlur) and
    (Common.ShadowBlur >= 0) and (Common.ShadowBlur <= 500) and
    not IsNan(Common.ShadowSpread) and not IsInfinite(Common.ShadowSpread) and
    (Common.ShadowSpread >= 0) and (Common.ShadowSpread <= 500) and
    (Common.RubyGapAdjustment >= -200) and
    (Common.RubyGapAdjustment <= 500) and
    (Common.BaseCharacterSpacing >= -100) and
    (Common.BaseCharacterSpacing <= 100) and
    (Common.RubyCharacterSpacing >= -100) and
    (Common.RubyCharacterSpacing <= 100);
end;

function TryEncodeDisplaySettingsText(const Lyrics: string;
  const Common: TDisplayCommonSettings;
  const Items: TDisplayPlacementItems; out Text: string): Boolean;
var
  CommonText: string;
  I: Integer;
  Item: TDisplayPlacementItem;
  RecordText: string;
begin
  Text := '';
  if (Length(Items) > MAX_DISPLAY_PLACEMENT_ITEMS) or
    (Length(Items) > 255) or not IsValidCommonSettings(Common) then
    Exit(False);
  Text := Format('%s|%.8X|%d', [DISPLAY_SETTINGS_TEXT_PREFIX,
    CalculateDisplayLyricsHash(Lyrics), Length(Items)]);
  CommonText := Format(
    '%d,%d,%s,%s,%d,%d,%d,%d,%.6X,%.6X,%d,%d,%d',
    [Common.PositionX, Common.PositionY,
     EncodeUtf8Hex(Common.BaseFontName),
     EncodeUtf8Hex(Common.RubyFontName),
     Common.BaseFontHeight, Common.RubyFontHeight,
     Common.BaseFontStyle and $0F, Common.RubyFontStyle and $0F,
     Common.BeforeColor and $FFFFFF, Common.AfterColor and $FFFFFF,
      Common.RubyGapAdjustment, Common.BaseCharacterSpacing,
      Common.RubyCharacterSpacing]);
  CommonText := CommonText + Format(
    ',%d,%d,%.6X,%.6X,%d,%d,%.6X,%.6X,%d,%d,%.6X,%.6X,%d,%d,' +
    '%d,%d,%d,%d,%d,%d,%d,%d',
    [Common.BeforeOpacity, Common.AfterOpacity,
     Common.BeforeOutlineColor and $FFFFFF,
     Common.AfterOutlineColor and $FFFFFF,
     Common.BeforeOutlineOpacity, Common.AfterOutlineOpacity,
     Common.BeforeShadowColor and $FFFFFF,
     Common.AfterShadowColor and $FFFFFF,
     Common.BeforeShadowOpacity, Common.AfterShadowOpacity,
     Common.BeforeBlurColor and $FFFFFF,
     Common.AfterBlurColor and $FFFFFF,
     Common.BeforeBlurOpacity, Common.AfterBlurOpacity,
     Ord(Common.OutlineEnabled), Round(Common.OutlineWidth * 1000),
     Round(Common.OutlineBlur * 1000), Ord(Common.ShadowEnabled),
     Round(Common.ShadowOffsetX * 1000), Round(Common.ShadowOffsetY * 1000),
     Round(Common.ShadowBlur * 1000), Round(Common.ShadowSpread * 1000)]);
  Text := Text + '|' + CommonText;
  for I := 0 to High(Items) do
  begin
    Item := Items[I];
    if (Item.Index <> I) or not IsValidCoordinate(Item.X) or
      not IsValidCoordinate(Item.Y) or not IsValidScale(Item.ScaleX) or
      not IsValidScale(Item.ScaleY) then
    begin
      Text := '';
      Exit(False);
    end;
    RecordText := Format(
      '%d,%d,%d,%d,%d,%d,%s,%s,%.6X,%.6X,%d,%d,%d,%d,%d,%d,%d,%d',
      [Item.Index, Round(Item.X), Round(Item.Y),
       Round(Item.ScaleX * 1000), Round(Item.ScaleY * 1000),
       BuildFlags(Item), EncodeUtf8Hex(Item.BaseFontName),
       EncodeUtf8Hex(Item.RubyFontName), Item.BeforeColor and $FFFFFF,
       Item.AfterColor and $FFFFFF, Item.BaseFontHeight,
       Item.RubyFontHeight, Item.BaseFontStyle and $0F,
       Item.RubyFontStyle and $0F, Item.BaseCharacterSpacing,
       Item.RubyCharacterSpacing, Item.RubyOffsetX, Item.RubyOffsetY]);
    Text := Text + '|' + RecordText;
  end;
  Result := (Length(Text) <= MAX_DISPLAY_SETTINGS_TEXT_LENGTH) and
    (Pos(#10, Text) = 0) and (Pos(#13, Text) = 0);
  if not Result then
    Text := '';
end;

function TryParseInteger(const Value: string; out Parsed: Integer): Boolean;
begin
  Result := TryStrToInt(Value, Parsed);
end;

function TryParseHexCardinal(const Value: string;
  out Parsed: Cardinal): Boolean;
var
  Parsed64: UInt64;
begin
  Result := TryStrToUInt64('$' + Value, Parsed64) and
    (Parsed64 <= $FFFFFF);
  if Result then
    Parsed := Cardinal(Parsed64);
end;

function TryDecodeDisplaySettingsText(const Text, Lyrics: string;
  out Common: TDisplayCommonSettings; out Items: TDisplayPlacementItems;
  out PlacementsMatchLyrics: Boolean): Boolean;
var
  CommonFields: TStringList;
  Fields: TStringList;
  Flags: Integer;
  Header: TStringList;
  I: Integer;
  IntegerValue: Integer;
  Item: TDisplayPlacementItem;
  ItemCount: Integer;
  Records: TStringList;
  StoredHash: Cardinal;
  StoredHash64: UInt64;
begin
  Common := DefaultDisplayCommonSettings;
  Items := nil;
  PlacementsMatchLyrics := False;
  Result := False;
  if (Text = '') or (Length(Text) > MAX_DISPLAY_SETTINGS_TEXT_LENGTH) or
    (Pos(#10, Text) <> 0) or (Pos(#13, Text) <> 0) then
    Exit;
  Records := TStringList.Create;
  Header := TStringList.Create;
  Fields := TStringList.Create;
  CommonFields := TStringList.Create;
  try
    Records.StrictDelimiter := True;
    Records.Delimiter := '|';
    Records.DelimitedText := Text;
    if Records.Count < 4 then
      Exit;
    if Records[0] <> DISPLAY_SETTINGS_TEXT_PREFIX then
      Exit;
    Header.StrictDelimiter := True;
    Header.Delimiter := ',';
    Header.DelimitedText := Records[1] + ',' + Records[2];
    if (Header.Count <> 2) or
      not TryStrToUInt64('$' + Header[0], StoredHash64) or
      (StoredHash64 > High(Cardinal)) or
      not TryParseInteger(Header[1], ItemCount) then
      Exit;
    StoredHash := Cardinal(StoredHash64);
    if (ItemCount < 0) or (ItemCount > MAX_DISPLAY_PLACEMENT_ITEMS) or
      (Records.Count <> ItemCount + 4) then
      Exit;
    PlacementsMatchLyrics :=
      StoredHash = CalculateDisplayLyricsHash(Lyrics);

    CommonFields.StrictDelimiter := True;
    CommonFields.Delimiter := ',';
    CommonFields.DelimitedText := Records[3];
    if not (CommonFields.Count in [13, 35]) or
      not TryParseInteger(CommonFields[0], Common.PositionX) or
      not TryParseInteger(CommonFields[1], Common.PositionY) or
      not TryDecodeUtf8Hex(CommonFields[2], Common.BaseFontName) or
      not TryDecodeUtf8Hex(CommonFields[3], Common.RubyFontName) or
      not TryParseInteger(CommonFields[4], Common.BaseFontHeight) or
      not TryParseInteger(CommonFields[5], Common.RubyFontHeight) or
      not TryParseInteger(CommonFields[6], IntegerValue) or
      (IntegerValue < 0) or (IntegerValue > $0F) then
      Exit;
    Common.BaseFontStyle := IntegerValue;
    if not TryParseInteger(CommonFields[7], IntegerValue) or
      (IntegerValue < 0) or (IntegerValue > $0F) then
      Exit;
    Common.RubyFontStyle := IntegerValue;
    if not TryParseHexCardinal(CommonFields[8], Common.BeforeColor) or
      not TryParseHexCardinal(CommonFields[9], Common.AfterColor) or
      not TryParseInteger(CommonFields[10], Common.RubyGapAdjustment) or
      not TryParseInteger(CommonFields[11],
        Common.BaseCharacterSpacing) or
      not TryParseInteger(CommonFields[12],
        Common.RubyCharacterSpacing) then
      Exit;
    if CommonFields.Count = 35 then
    begin
      if not TryParseInteger(CommonFields[13], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > 255) then Exit;
      Common.BeforeOpacity := IntegerValue;
      if not TryParseInteger(CommonFields[14], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > 255) then Exit;
      Common.AfterOpacity := IntegerValue;
      if not TryParseHexCardinal(CommonFields[15],
        Common.BeforeOutlineColor) or
        not TryParseHexCardinal(CommonFields[16],
          Common.AfterOutlineColor) then Exit;
      if not TryParseInteger(CommonFields[17], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > 255) then Exit;
      Common.BeforeOutlineOpacity := IntegerValue;
      if not TryParseInteger(CommonFields[18], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > 255) then Exit;
      Common.AfterOutlineOpacity := IntegerValue;
      if not TryParseHexCardinal(CommonFields[19],
        Common.BeforeShadowColor) or
        not TryParseHexCardinal(CommonFields[20],
          Common.AfterShadowColor) then Exit;
      if not TryParseInteger(CommonFields[21], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > 255) then Exit;
      Common.BeforeShadowOpacity := IntegerValue;
      if not TryParseInteger(CommonFields[22], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > 255) then Exit;
      Common.AfterShadowOpacity := IntegerValue;
      if not TryParseHexCardinal(CommonFields[23],
        Common.BeforeBlurColor) or
        not TryParseHexCardinal(CommonFields[24],
          Common.AfterBlurColor) then Exit;
      if not TryParseInteger(CommonFields[25], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > 255) then Exit;
      Common.BeforeBlurOpacity := IntegerValue;
      if not TryParseInteger(CommonFields[26], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > 255) then Exit;
      Common.AfterBlurOpacity := IntegerValue;
      if not TryParseInteger(CommonFields[27], IntegerValue) or
        not (IntegerValue in [0, 1]) then Exit;
      Common.OutlineEnabled := IntegerValue <> 0;
      if not TryParseInteger(CommonFields[28], IntegerValue) then Exit;
      Common.OutlineWidth := IntegerValue / 1000;
      if not TryParseInteger(CommonFields[29], IntegerValue) then Exit;
      Common.OutlineBlur := IntegerValue / 1000;
      if not TryParseInteger(CommonFields[30], IntegerValue) or
        not (IntegerValue in [0, 1]) then Exit;
      Common.ShadowEnabled := IntegerValue <> 0;
      if not TryParseInteger(CommonFields[31], IntegerValue) then Exit;
      Common.ShadowOffsetX := IntegerValue / 1000;
      if not TryParseInteger(CommonFields[32], IntegerValue) then Exit;
      Common.ShadowOffsetY := IntegerValue / 1000;
      if not TryParseInteger(CommonFields[33], IntegerValue) then Exit;
      Common.ShadowBlur := IntegerValue / 1000;
      if not TryParseInteger(CommonFields[34], IntegerValue) then Exit;
      Common.ShadowSpread := IntegerValue / 1000;
    end;
    if not IsValidCommonSettings(Common) then
      Exit;

    SetLength(Items, ItemCount);
    Fields.StrictDelimiter := True;
    Fields.Delimiter := ',';
    for I := 0 to ItemCount - 1 do
    begin
      Fields.DelimitedText := Records[I + 4];
      if Fields.Count <> 18 then
        Exit;
      FillChar(Item, SizeOf(Item), 0);
      if not TryParseInteger(Fields[0], Item.Index) or
        (Item.Index <> I) or
        not TryParseInteger(Fields[1], IntegerValue) or
        (IntegerValue < Low(SmallInt)) or (IntegerValue > High(SmallInt)) then
        Exit;
      Item.X := IntegerValue;
      if not TryParseInteger(Fields[2], IntegerValue) or
        (IntegerValue < Low(SmallInt)) or (IntegerValue > High(SmallInt)) then
        Exit;
      Item.Y := IntegerValue;
      if not TryParseInteger(Fields[3], IntegerValue) or
        (IntegerValue < Round(MIN_PLACEMENT_SCALE * 1000)) or
        (IntegerValue > Round(MAX_PLACEMENT_SCALE * 1000)) then
        Exit;
      Item.ScaleX := IntegerValue / 1000;
      if not TryParseInteger(Fields[4], IntegerValue) or
        (IntegerValue < Round(MIN_PLACEMENT_SCALE * 1000)) or
        (IntegerValue > Round(MAX_PLACEMENT_SCALE * 1000)) then
        Exit;
      Item.ScaleY := IntegerValue / 1000;
      if not TryParseInteger(Fields[5], Flags) or (Flags < 0) or
        (Flags > 1023) or
        not TryDecodeUtf8Hex(Fields[6], Item.BaseFontName) or
        not TryDecodeUtf8Hex(Fields[7], Item.RubyFontName) or
        not TryParseHexCardinal(Fields[8], Item.BeforeColor) or
        not TryParseHexCardinal(Fields[9], Item.AfterColor) then
        Exit;
      if not TryParseInteger(Fields[10], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > High(Word)) then
        Exit;
      Item.BaseFontHeight := IntegerValue;
      if not TryParseInteger(Fields[11], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > High(Word)) then
        Exit;
      Item.RubyFontHeight := IntegerValue;
      if not TryParseInteger(Fields[12], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > $0F) then
        Exit;
      Item.BaseFontStyle := IntegerValue;
      if not TryParseInteger(Fields[13], IntegerValue) or
        (IntegerValue < 0) or (IntegerValue > $0F) then
        Exit;
      Item.RubyFontStyle := IntegerValue;
      if not TryParseInteger(Fields[14], IntegerValue) or
        (IntegerValue < Low(SmallInt)) or (IntegerValue > High(SmallInt)) then
        Exit;
      Item.BaseCharacterSpacing := IntegerValue;
      if not TryParseInteger(Fields[15], IntegerValue) or
        (IntegerValue < Low(SmallInt)) or (IntegerValue > High(SmallInt)) then
        Exit;
      Item.RubyCharacterSpacing := IntegerValue;
      if not TryParseInteger(Fields[16], IntegerValue) or
        (IntegerValue < Low(SmallInt)) or (IntegerValue > High(SmallInt)) then
        Exit;
      Item.RubyOffsetX := IntegerValue;
      if not TryParseInteger(Fields[17], IntegerValue) or
        (IntegerValue < Low(SmallInt)) or (IntegerValue > High(SmallInt)) then
        Exit;
      Item.RubyOffsetY := IntegerValue;

      Item.HasBeforeColor := (Flags and FLAG_BEFORE_COLOR) <> 0;
      Item.HasAfterColor := (Flags and FLAG_AFTER_COLOR) <> 0;
      Item.HasBaseFontHeight := (Flags and FLAG_BASE_FONT_HEIGHT) <> 0;
      Item.HasRubyFontHeight := (Flags and FLAG_RUBY_FONT_HEIGHT) <> 0;
      Item.HasBaseFontStyle := (Flags and FLAG_BASE_FONT_STYLE) <> 0;
      Item.HasRubyFontStyle := (Flags and FLAG_RUBY_FONT_STYLE) <> 0;
      Item.HasBaseCharacterSpacing :=
        (Flags and FLAG_BASE_CHARACTER_SPACING) <> 0;
      Item.HasRubyCharacterSpacing :=
        (Flags and FLAG_RUBY_CHARACTER_SPACING) <> 0;
      Item.HasRubyOffsetX := (Flags and FLAG_RUBY_OFFSET_X) <> 0;
      Item.HasRubyOffsetY := (Flags and FLAG_RUBY_OFFSET_Y) <> 0;
      Items[I] := Item;
    end;
    Result := True;
  finally
    CommonFields.Free;
    Fields.Free;
    Header.Free;
    Records.Free;
    if not Result then
    begin
      Common := DefaultDisplayCommonSettings;
      Items := nil;
      PlacementsMatchLyrics := False;
    end;
  end;
end;

end.
