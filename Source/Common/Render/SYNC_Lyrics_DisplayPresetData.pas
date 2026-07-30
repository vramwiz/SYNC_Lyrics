unit SYNC_Lyrics_DisplayPresetData;

// Serializes reusable display styles without object coordinates or placements.

interface

uses
  SYNC_Lyrics_DisplaySettingsData;

type
  TDisplayPreset = record
    BaseFontName: string;
    RubyFontName: string;
    BaseFontHeight: Integer;
    RubyFontHeight: Integer;
    BaseFontStyle: Byte;
    RubyFontStyle: Byte;
    BeforeColor: Cardinal;
    AfterColor: Cardinal;
    RubyGapAdjustment: Integer;
    BaseCharacterSpacing: Integer;
    RubyCharacterSpacing: Integer;
    DisplayEffect: Integer;
    SyncAnimation: Integer;
    StartAnimation: Integer;
    StartAnimationMilliseconds: Integer;
    EndAnimation: Integer;
    EndAnimationMilliseconds: Integer;
  end;

procedure BuildDisplayPreset(const Common: TDisplayCommonSettings;
  DisplayEffect, SyncAnimation, StartAnimation: Integer;
  StartAnimationSeconds: Double; EndAnimation: Integer;
  EndAnimationSeconds: Double; out Preset: TDisplayPreset);
procedure ApplyDisplayPreset(const Preset: TDisplayPreset;
  var Common: TDisplayCommonSettings; out DisplayEffect, SyncAnimation,
  StartAnimation: Integer; out StartAnimationSeconds: Double;
  out EndAnimation: Integer; out EndAnimationSeconds: Double);
function TryDecodeDisplayPreset(const Text: string;
  out Preset: TDisplayPreset): Boolean;
function TryEncodeDisplayPreset(const Preset: TDisplayPreset;
  out Text: string): Boolean;

implementation

uses
  System.Classes,
  System.Math,
  System.SysUtils;

const
  DISPLAY_PRESET_PREFIX = 'SLP1';

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

function TryDecodeUtf8Hex(const Value: string;
  out Decoded: string): Boolean;
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

function IsValidDisplayPreset(const Preset: TDisplayPreset): Boolean;
begin
  Result := (Preset.BaseFontName <> '') and
    (Preset.RubyFontName <> '') and
    (Preset.BaseFontHeight >= 1) and (Preset.BaseFontHeight <= 1024) and
    (Preset.RubyFontHeight >= 1) and (Preset.RubyFontHeight <= 1024) and
    (Preset.BaseFontStyle <= $0F) and (Preset.RubyFontStyle <= $0F) and
    (Preset.BeforeColor <= $FFFFFF) and
    (Preset.AfterColor <= $FFFFFF) and
    (Preset.RubyGapAdjustment >= -200) and
    (Preset.RubyGapAdjustment <= 500) and
    (Preset.BaseCharacterSpacing >= -100) and
    (Preset.BaseCharacterSpacing <= 100) and
    (Preset.RubyCharacterSpacing >= -100) and
    (Preset.RubyCharacterSpacing <= 100) and
    InRange(Preset.DisplayEffect, 0, 2) and
    InRange(Preset.SyncAnimation, 0, 1) and
    InRange(Preset.StartAnimation, 0, 1) and
    InRange(Preset.StartAnimationMilliseconds, 10, 10000) and
    InRange(Preset.EndAnimation, 0, 1) and
    InRange(Preset.EndAnimationMilliseconds, 10, 10000);
end;

procedure BuildDisplayPreset(const Common: TDisplayCommonSettings;
  DisplayEffect, SyncAnimation, StartAnimation: Integer;
  StartAnimationSeconds: Double; EndAnimation: Integer;
  EndAnimationSeconds: Double; out Preset: TDisplayPreset);
begin
  Preset.BaseFontName := Common.BaseFontName;
  Preset.RubyFontName := Common.RubyFontName;
  Preset.BaseFontHeight := Common.BaseFontHeight;
  Preset.RubyFontHeight := Common.RubyFontHeight;
  Preset.BaseFontStyle := Common.BaseFontStyle;
  Preset.RubyFontStyle := Common.RubyFontStyle;
  Preset.BeforeColor := Common.BeforeColor;
  Preset.AfterColor := Common.AfterColor;
  Preset.RubyGapAdjustment := Common.RubyGapAdjustment;
  Preset.BaseCharacterSpacing := Common.BaseCharacterSpacing;
  Preset.RubyCharacterSpacing := Common.RubyCharacterSpacing;
  Preset.DisplayEffect := DisplayEffect;
  Preset.SyncAnimation := SyncAnimation;
  Preset.StartAnimation := StartAnimation;
  Preset.StartAnimationMilliseconds := Round(StartAnimationSeconds * 1000);
  Preset.EndAnimation := EndAnimation;
  Preset.EndAnimationMilliseconds := Round(EndAnimationSeconds * 1000);
end;

procedure ApplyDisplayPreset(const Preset: TDisplayPreset;
  var Common: TDisplayCommonSettings; out DisplayEffect, SyncAnimation,
  StartAnimation: Integer; out StartAnimationSeconds: Double;
  out EndAnimation: Integer; out EndAnimationSeconds: Double);
begin
  Common.BaseFontName := Preset.BaseFontName;
  Common.RubyFontName := Preset.RubyFontName;
  Common.BaseFontHeight := Preset.BaseFontHeight;
  Common.RubyFontHeight := Preset.RubyFontHeight;
  Common.BaseFontStyle := Preset.BaseFontStyle;
  Common.RubyFontStyle := Preset.RubyFontStyle;
  Common.BeforeColor := Preset.BeforeColor;
  Common.AfterColor := Preset.AfterColor;
  Common.RubyGapAdjustment := Preset.RubyGapAdjustment;
  Common.BaseCharacterSpacing := Preset.BaseCharacterSpacing;
  Common.RubyCharacterSpacing := Preset.RubyCharacterSpacing;
  DisplayEffect := Preset.DisplayEffect;
  SyncAnimation := Preset.SyncAnimation;
  StartAnimation := Preset.StartAnimation;
  StartAnimationSeconds := Preset.StartAnimationMilliseconds / 1000;
  EndAnimation := Preset.EndAnimation;
  EndAnimationSeconds := Preset.EndAnimationMilliseconds / 1000;
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

function TryEncodeDisplayPreset(const Preset: TDisplayPreset;
  out Text: string): Boolean;
begin
  Text := '';
  if not IsValidDisplayPreset(Preset) then
    Exit(False);
  Text := Format(
    '%s|%s|%s|%d|%d|%d|%d|%.6X|%.6X|%d|%d|%d|%d|%d|%d|%d|%d|%d',
    [DISPLAY_PRESET_PREFIX, EncodeUtf8Hex(Preset.BaseFontName),
     EncodeUtf8Hex(Preset.RubyFontName), Preset.BaseFontHeight,
     Preset.RubyFontHeight, Preset.BaseFontStyle and $0F,
     Preset.RubyFontStyle and $0F, Preset.BeforeColor and $FFFFFF,
     Preset.AfterColor and $FFFFFF, Preset.RubyGapAdjustment,
     Preset.BaseCharacterSpacing, Preset.RubyCharacterSpacing,
     Preset.DisplayEffect, Preset.SyncAnimation, Preset.StartAnimation,
     Preset.StartAnimationMilliseconds, Preset.EndAnimation,
     Preset.EndAnimationMilliseconds]);
  Result := (Pos(#10, Text) = 0) and (Pos(#13, Text) = 0);
  if not Result then
    Text := '';
end;

function TryDecodeDisplayPreset(const Text: string;
  out Preset: TDisplayPreset): Boolean;
var
  Fields: TStringList;
  IntegerValue: Integer;
begin
  Preset := Default(TDisplayPreset);
  Result := False;
  if (Text = '') or (Pos(#10, Text) <> 0) or (Pos(#13, Text) <> 0) then
    Exit;
  Fields := TStringList.Create;
  try
    Fields.StrictDelimiter := True;
    Fields.Delimiter := '|';
    Fields.DelimitedText := Text;
    if (Fields.Count <> 18) or (Fields[0] <> DISPLAY_PRESET_PREFIX) or
      not TryDecodeUtf8Hex(Fields[1], Preset.BaseFontName) or
      not TryDecodeUtf8Hex(Fields[2], Preset.RubyFontName) or
      not TryParseInteger(Fields[3], Preset.BaseFontHeight) or
      not TryParseInteger(Fields[4], Preset.RubyFontHeight) or
      not TryParseInteger(Fields[5], IntegerValue) or
      not InRange(IntegerValue, 0, $0F) then
      Exit;
    Preset.BaseFontStyle := IntegerValue;
    if not TryParseInteger(Fields[6], IntegerValue) or
      not InRange(IntegerValue, 0, $0F) then
      Exit;
    Preset.RubyFontStyle := IntegerValue;
    if not TryParseHexCardinal(Fields[7], Preset.BeforeColor) or
      not TryParseHexCardinal(Fields[8], Preset.AfterColor) or
      not TryParseInteger(Fields[9], Preset.RubyGapAdjustment) or
      not TryParseInteger(Fields[10], Preset.BaseCharacterSpacing) or
      not TryParseInteger(Fields[11], Preset.RubyCharacterSpacing) or
      not TryParseInteger(Fields[12], Preset.DisplayEffect) or
      not TryParseInteger(Fields[13], Preset.SyncAnimation) or
      not TryParseInteger(Fields[14], Preset.StartAnimation) or
      not TryParseInteger(Fields[15],
        Preset.StartAnimationMilliseconds) or
      not TryParseInteger(Fields[16], Preset.EndAnimation) or
      not TryParseInteger(Fields[17], Preset.EndAnimationMilliseconds) or
      not IsValidDisplayPreset(Preset) then
      Exit;
    Result := True;
  finally
    Fields.Free;
  end;
end;

end.
