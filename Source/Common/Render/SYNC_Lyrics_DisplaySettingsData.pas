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
    BaseFontName: string;
    RubyFontName: string;
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
  DISPLAY_SETTINGS_VERSION = 5;
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
  TStoredFontRunV4 = packed record
    StartIndex: Byte;
    Count: Byte;
    BaseFontId: Byte;
    RubyFontId: Byte;
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
  AssignedItems: TArray<Boolean>;
  BaseFontId: Integer;
  I: Integer;
  FontCount: Integer;
  FontId: Integer;
  FontLength: Integer;
  FontNames: TArray<string>;
  FontRun: TStoredFontRunV4;
  GroupCount: Integer;
  Mask: TBytes;
  MaskSize: Integer;
  Offset: Integer;
  RubyFontId: Integer;
  StoredV2: PStoredDisplayPlacementV2;
  StoredV3: PStoredDisplayPlacementV3;
  Utf8FontName: TBytes;
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
      Items[I].BaseFontName := '';
      Items[I].RubyFontName := '';
      Inc(StoredV2);
    end;
  end
  else if Data.Version in [3, 4, DISPLAY_SETTINGS_VERSION] then
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
      Items[I].BaseFontName := '';
      Items[I].RubyFontName := '';
      Inc(StoredV3);
    end;
    if Data.Version in [4, DISPLAY_SETTINGS_VERSION] then
    begin
      Offset := Data.ItemCount * SizeOf(TStoredDisplayPlacementV3);
      if Offset >= DISPLAY_SETTINGS_PAYLOAD_SIZE then
        Exit(False);
      FontCount := Data.Payload[Offset];
      Inc(Offset);
      SetLength(FontNames, FontCount + 1);
      for I := 1 to FontCount do
      begin
        if Offset >= DISPLAY_SETTINGS_PAYLOAD_SIZE then
          Exit(False);
        FontLength := Data.Payload[Offset];
        Inc(Offset);
        if (FontLength = 0) or
          (Offset + FontLength > DISPLAY_SETTINGS_PAYLOAD_SIZE) then
          Exit(False);
        SetLength(Utf8FontName, FontLength);
        Move(Data.Payload[Offset], Utf8FontName[0], FontLength);
        Inc(Offset, FontLength);
        FontNames[I] := TEncoding.UTF8.GetString(Utf8FontName);
        if FontNames[I] = '' then
          Exit(False);
      end;
      if Offset >= DISPLAY_SETTINGS_PAYLOAD_SIZE then
        Exit(False);
      GroupCount := Data.Payload[Offset];
      Inc(Offset);
      if Data.Version = 4 then
      begin
        for I := 0 to GroupCount - 1 do
        begin
          if Offset + SizeOf(FontRun) >
            DISPLAY_SETTINGS_PAYLOAD_SIZE then
            Exit(False);
          Move(Data.Payload[Offset], FontRun, SizeOf(FontRun));
          Inc(Offset, SizeOf(FontRun));
          if (FontRun.Count = 0) or
            (Integer(FontRun.StartIndex) + FontRun.Count >
              Length(Items)) or
            (FontRun.BaseFontId > High(FontNames)) or
            (FontRun.RubyFontId > High(FontNames)) then
            Exit(False);
          for FontId := FontRun.StartIndex to
            FontRun.StartIndex + FontRun.Count - 1 do
          begin
            if FontRun.BaseFontId > 0 then
              Items[FontId].BaseFontName :=
                FontNames[FontRun.BaseFontId];
            if FontRun.RubyFontId > 0 then
              Items[FontId].RubyFontName :=
                FontNames[FontRun.RubyFontId];
          end;
        end;
      end
      else
      begin
        MaskSize := (Length(Items) + 7) div 8;
        SetLength(AssignedItems, Length(Items));
        SetLength(Mask, MaskSize);
        for I := 0 to GroupCount - 1 do
        begin
          if Offset + 2 + MaskSize >
            DISPLAY_SETTINGS_PAYLOAD_SIZE then
            Exit(False);
          BaseFontId := Data.Payload[Offset];
          RubyFontId := Data.Payload[Offset + 1];
          Inc(Offset, 2);
          if ((BaseFontId = 0) and (RubyFontId = 0)) or
            (BaseFontId > High(FontNames)) or
            (RubyFontId > High(FontNames)) then
            Exit(False);
          if MaskSize > 0 then
          begin
            Move(Data.Payload[Offset], Mask[0], MaskSize);
            Inc(Offset, MaskSize);
          end;
          for FontId := 0 to High(Items) do
            if (Mask[FontId div 8] and
              (Byte(1) shl (FontId mod 8))) <> 0 then
            begin
              if AssignedItems[FontId] then
                Exit(False);
              AssignedItems[FontId] := True;
              if BaseFontId > 0 then
                Items[FontId].BaseFontName :=
                  FontNames[BaseFontId];
              if RubyFontId > 0 then
                Items[FontId].RubyFontName :=
                  FontNames[RubyFontId];
            end;
        end;
      end;
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
  BaseFontIds: TArray<Byte>;
  FontBytes: TBytes;
  FontGroupBaseIds: TArray<Byte>;
  FontGroupMasks: TArray<TBytes>;
  FontGroupRubyIds: TArray<Byte>;
  FontNames: TArray<string>;
  GroupIndex: Integer;
  I: Integer;
  MaskSize: Integer;
  Offset: Integer;
  RubyFontIds: TArray<Byte>;
  Stored: PStoredDisplayPlacementV3;

  function FontIdForName(const FontName: string): Integer;
  var
    FontIndex: Integer;
  begin
    if FontName = '' then
      Exit(0);
    for FontIndex := 0 to High(FontNames) do
      if SameText(FontNames[FontIndex], FontName) then
        Exit(FontIndex + 1);
    if Length(FontNames) >= 255 then
      Exit(-1);
    SetLength(FontNames, Length(FontNames) + 1);
    FontNames[High(FontNames)] := FontName;
    Result := Length(FontNames);
  end;

  function WriteByte(Value: Byte): Boolean;
  begin
    Result := Offset < DISPLAY_SETTINGS_PAYLOAD_SIZE;
    if Result then
    begin
      Data.Payload[Offset] := Value;
      Inc(Offset);
    end;
  end;

  function WriteBuffer(const Buffer; Count: Integer): Boolean;
  begin
    Result := (Count >= 0) and
      (Offset + Count <= DISPLAY_SETTINGS_PAYLOAD_SIZE);
    if Result and (Count > 0) then
    begin
      Move(Buffer, Data.Payload[Offset], Count);
      Inc(Offset, Count);
    end;
  end;

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

  SetLength(BaseFontIds, Length(Items));
  SetLength(RubyFontIds, Length(Items));
  for I := 0 to High(Items) do
  begin
    Offset := FontIdForName(Items[I].BaseFontName);
    if Offset < 0 then
      Exit(False);
    BaseFontIds[I] := Offset;
    Offset := FontIdForName(Items[I].RubyFontName);
    if Offset < 0 then
      Exit(False);
    RubyFontIds[I] := Offset;
  end;

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
  Offset := Length(Items) * SizeOf(TStoredDisplayPlacementV3);
  if not WriteByte(Length(FontNames)) then
    Exit(False);
  for I := 0 to High(FontNames) do
  begin
    FontBytes := TEncoding.UTF8.GetBytes(FontNames[I]);
    if (Length(FontBytes) = 0) or (Length(FontBytes) > 255) or
      not WriteByte(Length(FontBytes)) or
      not WriteBuffer(FontBytes[0], Length(FontBytes)) then
      Exit(False);
  end;

  MaskSize := (Length(Items) + 7) div 8;
  for I := 0 to High(Items) do
  begin
    if (BaseFontIds[I] = 0) and (RubyFontIds[I] = 0) then
      Continue;
    GroupIndex := -1;
    for var J := 0 to High(FontGroupBaseIds) do
      if (FontGroupBaseIds[J] = BaseFontIds[I]) and
        (FontGroupRubyIds[J] = RubyFontIds[I]) then
      begin
        GroupIndex := J;
        Break;
      end;
    if GroupIndex < 0 then
    begin
      GroupIndex := Length(FontGroupBaseIds);
      if GroupIndex >= 255 then
        Exit(False);
      SetLength(FontGroupBaseIds, GroupIndex + 1);
      SetLength(FontGroupRubyIds, GroupIndex + 1);
      SetLength(FontGroupMasks, GroupIndex + 1);
      FontGroupBaseIds[GroupIndex] := BaseFontIds[I];
      FontGroupRubyIds[GroupIndex] := RubyFontIds[I];
      SetLength(FontGroupMasks[GroupIndex], MaskSize);
    end;
    FontGroupMasks[GroupIndex][I div 8] :=
      FontGroupMasks[GroupIndex][I div 8] or
      (Byte(1) shl (I mod 8));
  end;
  if not WriteByte(Length(FontGroupBaseIds)) then
    Exit(False);
  for I := 0 to High(FontGroupBaseIds) do
    if not WriteByte(FontGroupBaseIds[I]) or
      not WriteByte(FontGroupRubyIds[I]) or
      ((MaskSize > 0) and
        not WriteBuffer(FontGroupMasks[I][0], MaskSize)) then
      Exit(False);
  Result := True;
end;

end.
