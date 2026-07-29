unit SYNC_Lyrics_DisplaySettingsData;

// Stores the first-stage display-settings debug payload in a fixed binary block.

interface

const
  DISPLAY_SETTINGS_DATA_SIZE = 1024;
  DISPLAY_SETTINGS_PAYLOAD_SIZE = DISPLAY_SETTINGS_DATA_SIZE - 12;

type
  TDisplaySettingsData = packed record
    Signature: Cardinal;
    Version: Cardinal;
    TextLength: Cardinal;
    Payload: array[0..DISPLAY_SETTINGS_PAYLOAD_SIZE - 1] of Byte;
  end;
  PDisplaySettingsData = ^TDisplaySettingsData;

procedure ClearDisplaySettingsData(out Data: TDisplaySettingsData);
function DecodeDisplaySettingsText(const Data: TDisplaySettingsData): string;
function TryEncodeDisplaySettingsText(const Text: string;
  out Data: TDisplaySettingsData): Boolean;

implementation

uses
  System.SysUtils;

const
  DISPLAY_SETTINGS_SIGNATURE = $44594C53;
  DISPLAY_SETTINGS_VERSION = 1;

procedure ClearDisplaySettingsData(out Data: TDisplaySettingsData);
begin
  FillChar(Data, SizeOf(Data), 0);
  Data.Signature := DISPLAY_SETTINGS_SIGNATURE;
  Data.Version := DISPLAY_SETTINGS_VERSION;
end;

function DecodeDisplaySettingsText(const Data: TDisplaySettingsData): string;
var
  TextBytes: TBytes;
begin
  Result := '';
  if (Data.Signature <> DISPLAY_SETTINGS_SIGNATURE) or
    (Data.Version <> DISPLAY_SETTINGS_VERSION) or
    (Data.TextLength > DISPLAY_SETTINGS_PAYLOAD_SIZE) then
    Exit;
  SetLength(TextBytes, Data.TextLength);
  if Data.TextLength > 0 then
    Move(Data.Payload[0], TextBytes[0], Data.TextLength);
  Result := TEncoding.UTF8.GetString(TextBytes);
end;

function TryEncodeDisplaySettingsText(const Text: string;
  out Data: TDisplaySettingsData): Boolean;
var
  TextBytes: TBytes;
begin
  ClearDisplaySettingsData(Data);
  TextBytes := TEncoding.UTF8.GetBytes(Text);
  Result := Length(TextBytes) <= DISPLAY_SETTINGS_PAYLOAD_SIZE;
  if not Result then
    Exit;
  Data.TextLength := Length(TextBytes);
  if Length(TextBytes) > 0 then
    Move(TextBytes[0], Data.Payload[0], Length(TextBytes));
end;

end.
