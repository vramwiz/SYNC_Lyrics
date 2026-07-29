unit SYNC_Lyrics_DisplaySettingsData;

// Stores versioned free-placement coordinates in AviUtl2's hidden data item.

interface

const
  DISPLAY_SETTINGS_DATA_SIZE = 1024;
  DISPLAY_SETTINGS_HEADER_SIZE = 16;
  DISPLAY_SETTINGS_PAYLOAD_SIZE =
    DISPLAY_SETTINGS_DATA_SIZE - DISPLAY_SETTINGS_HEADER_SIZE;

type
  TDisplayPlacementItem = record
    Index: Integer;
    X: Single;
    Y: Single;
    ScaleX: Single;
    ScaleY: Single;
  end;
  TDisplayPlacementItems = TArray<TDisplayPlacementItem>;

const
  MAX_DISPLAY_PLACEMENT_ITEMS = 100;

type
  TDisplaySettingsData = packed record
    Signature: Cardinal;
    Version: Cardinal;
    LyricsHash: Cardinal;
    ItemCount: Word;
    ItemSize: Word;
    Payload: array[0..DISPLAY_SETTINGS_PAYLOAD_SIZE - 1] of Byte;
  end;
  PDisplaySettingsData = ^TDisplaySettingsData;

procedure ClearDisplaySettingsData(out Data: TDisplaySettingsData);
function CalculateDisplayLyricsHash(const Lyrics: string): Cardinal;
function TryDecodeDisplayPlacements(const Data: TDisplaySettingsData;
  const Lyrics: string; ExpectedItemCount: Integer;
  out Items: TDisplayPlacementItems): Boolean;
function TryEncodeDisplayPlacements(const Lyrics: string;
  const Items: TDisplayPlacementItems;
  out Data: TDisplaySettingsData): Boolean;

implementation

uses
  System.Math,
  System.SysUtils;

const
  DISPLAY_SETTINGS_SIGNATURE = $44594C53;
  DISPLAY_SETTINGS_VERSION = 3;
  FNV1A_OFFSET_BASIS = Cardinal(2166136261);
  FNV1A_PRIME = Cardinal(16777619);
  MIN_PLACEMENT_SCALE = 0.05;
  MAX_PLACEMENT_SCALE = 10.0;

type
  TStoredDisplayPlacementV2 = packed record
    Index: Word;
    X: Single;
    Y: Single;
  end;
  TStoredDisplayPlacementV3 = packed record
    Index: Byte;
    X: SmallInt;
    Y: SmallInt;
    ScaleXPermille: Word;
    ScaleYPermille: Word;
  end;
  PStoredDisplayPlacementV2 = ^TStoredDisplayPlacementV2;
  PStoredDisplayPlacementV3 = ^TStoredDisplayPlacementV3;

procedure ClearDisplaySettingsData(out Data: TDisplaySettingsData);
begin
  FillChar(Data, SizeOf(Data), 0);
  Data.Signature := DISPLAY_SETTINGS_SIGNATURE;
  Data.Version := DISPLAY_SETTINGS_VERSION;
  Data.ItemSize := SizeOf(TStoredDisplayPlacementV3);
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

function TryDecodeDisplayPlacements(const Data: TDisplaySettingsData;
  const Lyrics: string; ExpectedItemCount: Integer;
  out Items: TDisplayPlacementItems): Boolean;
var
  I: Integer;
  StoredV2: PStoredDisplayPlacementV2;
  StoredV3: PStoredDisplayPlacementV3;
begin
  Items := nil;
  Result := (Data.Signature = DISPLAY_SETTINGS_SIGNATURE) and
    (Data.LyricsHash = CalculateDisplayLyricsHash(Lyrics)) and
    (Data.ItemCount = ExpectedItemCount) and
    (Data.ItemCount <= MAX_DISPLAY_PLACEMENT_ITEMS);
  if not Result then
    Exit;

  SetLength(Items, Data.ItemCount);
  if Data.Version = 2 then
  begin
    if Data.ItemSize <> SizeOf(TStoredDisplayPlacementV2) then
    begin
      Items := nil;
      Exit(False);
    end;
    StoredV2 := @Data.Payload[0];
    for I := 0 to High(Items) do
    begin
      Items[I].Index := StoredV2^.Index;
      Items[I].X := StoredV2^.X;
      Items[I].Y := StoredV2^.Y;
      Items[I].ScaleX := 1;
      Items[I].ScaleY := 1;
      Inc(StoredV2);
    end;
  end
  else if Data.Version = DISPLAY_SETTINGS_VERSION then
  begin
    if Data.ItemSize <> SizeOf(TStoredDisplayPlacementV3) then
    begin
      Items := nil;
      Exit(False);
    end;
    StoredV3 := @Data.Payload[0];
    for I := 0 to High(Items) do
    begin
      Items[I].Index := StoredV3^.Index;
      Items[I].X := StoredV3^.X;
      Items[I].Y := StoredV3^.Y;
      Items[I].ScaleX := StoredV3^.ScaleXPermille / 1000;
      Items[I].ScaleY := StoredV3^.ScaleYPermille / 1000;
      Inc(StoredV3);
    end;
  end
  else
  begin
    Items := nil;
    Exit(False);
  end;

  for I := 0 to High(Items) do
    if (Items[I].Index <> I) or not IsValidCoordinate(Items[I].X) or
      not IsValidCoordinate(Items[I].Y) or
      not IsValidScale(Items[I].ScaleX) or
      not IsValidScale(Items[I].ScaleY) then
    begin
      Items := nil;
      Exit(False);
    end;
end;

function TryEncodeDisplayPlacements(const Lyrics: string;
  const Items: TDisplayPlacementItems;
  out Data: TDisplaySettingsData): Boolean;
var
  I: Integer;
  Stored: PStoredDisplayPlacementV3;
begin
  ClearDisplaySettingsData(Data);
  Result := Length(Items) <= MAX_DISPLAY_PLACEMENT_ITEMS;
  if not Result then
    Exit;
  for I := 0 to High(Items) do
    if (Items[I].Index <> I) or not IsValidCoordinate(Items[I].X) or
      not IsValidCoordinate(Items[I].Y) or
      not IsValidScale(Items[I].ScaleX) or
      not IsValidScale(Items[I].ScaleY) then
      Exit(False);

  Data.LyricsHash := CalculateDisplayLyricsHash(Lyrics);
  Data.ItemCount := Length(Items);
  Stored := @Data.Payload[0];
  for I := 0 to High(Items) do
  begin
    Stored^.Index := Items[I].Index;
    Stored^.X := Round(Items[I].X);
    Stored^.Y := Round(Items[I].Y);
    Stored^.ScaleXPermille := Round(Items[I].ScaleX * 1000);
    Stored^.ScaleYPermille := Round(Items[I].ScaleY * 1000);
    Inc(Stored);
  end;
  Result := True;
end;

end.
