unit SYNC_Lyrics_SongLyricsData;

// Serializes the whole-song line model into one AviUtl2 Filter string item.

interface

uses
  SYNC_Lyrics_SongLyricsModel;

const
  MAX_SONG_LYRICS_TEXT_LENGTH = 32767;

function TryEncodeSongLyrics(const Model: TLyricsSongModel;
  out Text, ErrorText: string): Boolean;
function TryDecodeSongLyrics(const Text: string; Model: TLyricsSongModel;
  out ErrorText: string): Boolean;

implementation

uses
  System.NetEncoding,
  System.SysUtils;

const
  FILE_HEADER = 'SLS1';
  LINE_FIELD_COUNT = 14;

function DecodeTextField(const Value: string; out Decoded: string): Boolean;
begin
  Result := False;
  try
    Decoded := TNetEncoding.Base64.Decode(Value);
    Result := True;
  except
    Decoded := '';
  end;
end;

function EncodeTextField(const Value: string): string;
begin
  Result := TNetEncoding.Base64.Encode(Value);
end;

function HasDuplicateLineID(const Lines: TLyricsSongLines;
  LastIndex: Integer; LineID: Int64): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to LastIndex - 1 do
    if Lines[I].LineID = LineID then
      Exit(True);
end;

function TryDecodeSongLyrics(const Text: string; Model: TLyricsSongModel;
  out ErrorText: string): Boolean;
var
  Fields: TArray<string>;
  I: Integer;
  IntegerValue: Integer;
  Lines: TLyricsSongLines;
  Records: TArray<string>;
begin
  Result := False;
  ErrorText := '';
  if Model = nil then
  begin
    ErrorText := 'The destination model is not available.';
    Exit;
  end;
  if (Text = '') or (Length(Text) > MAX_SONG_LYRICS_TEXT_LENGTH) then
  begin
    ErrorText := 'The whole-song text length is invalid.';
    Exit;
  end;
  Records := Text.Split(['|']);
  if (Length(Records) < 1) or (Records[0] <> FILE_HEADER) then
  begin
    ErrorText := 'The whole-song text header is invalid.';
    Exit;
  end;
  SetLength(Lines, Length(Records) - 1);
  for I := 1 to High(Records) do
  begin
    Fields := Records[I].Split([',']);
    if (Length(Fields) <> LINE_FIELD_COUNT) or (Fields[0] <> 'L') or
      not TryStrToInt64(Fields[1], Lines[I - 1].LineID) or
      (Lines[I - 1].LineID <= 0) or
      HasDuplicateLineID(Lines, I - 1, Lines[I - 1].LineID) or
      not TryStrToInt(Fields[2], IntegerValue) or
      (IntegerValue < 1) or (IntegerValue > 3) then
    begin
      ErrorText := 'A whole-song line header is invalid.';
      Exit;
    end;
    Lines[I - 1].DisplayLane := IntegerValue;
    if not TryStrToInt(Fields[3], IntegerValue) or
      (IntegerValue < Ord(Low(TLyricsLineSyncState))) or
      (IntegerValue > Ord(High(TLyricsLineSyncState))) or
      not TryStrToFloat(Fields[4], Lines[I - 1].PreDisplaySeconds,
        TFormatSettings.Invariant) or
      not TryStrToFloat(Fields[5], Lines[I - 1].HoldSeconds,
        TFormatSettings.Invariant) or
      (Lines[I - 1].HoldSeconds < 0) or
      not TryStrToInt64(Fields[6], Lines[I - 1].DisplayStartFrame) or
      not TryStrToInt64(Fields[7], Lines[I - 1].DisplayEndFrame) or
      not TryStrToInt64(Fields[8], Lines[I - 1].SyncStartFrame) or
      not TryStrToInt64(Fields[9], Lines[I - 1].SyncEndFrame) or
      not TryStrToInt(Fields[10], Lines[I - 1].StartNoteIndex) or
      (Lines[I - 1].StartNoteIndex < 0) then
    begin
      ErrorText := 'A whole-song timing field is invalid.';
      Exit;
    end;
    Lines[I - 1].SyncState := TLyricsLineSyncState(IntegerValue);
    if not DecodeTextField(Fields[11], Lines[I - 1].SourceText) or
      (Trim(Lines[I - 1].SourceText) = '') or
      not DecodeTextField(Fields[12], Lines[I - 1].SyncText) or
      not DecodeTextField(Fields[13], Lines[I - 1].PlacementText) then
    begin
      ErrorText := 'A whole-song text field is invalid.';
      Exit;
    end;
  end;
  Model.ReplaceLines(Lines);
  Result := True;
end;

function TryEncodeSongLyrics(const Model: TLyricsSongModel;
  out Text, ErrorText: string): Boolean;
var
  I: Integer;
  LineData: TLyricsSongLine;
begin
  Result := False;
  Text := '';
  ErrorText := '';
  if Model = nil then
  begin
    ErrorText := 'The source model is not available.';
    Exit;
  end;
  Text := FILE_HEADER;
  for I := 0 to Model.LineCount - 1 do
  begin
    LineData := Model[I];
    Text := Text + '|L,' +
      IntToStr(LineData.LineID) + ',' +
      IntToStr(LineData.DisplayLane) + ',' +
      IntToStr(Ord(LineData.SyncState)) + ',' +
      FloatToStr(LineData.PreDisplaySeconds,
        TFormatSettings.Invariant) + ',' +
      FloatToStr(LineData.HoldSeconds,
        TFormatSettings.Invariant) + ',' +
      IntToStr(LineData.DisplayStartFrame) + ',' +
      IntToStr(LineData.DisplayEndFrame) + ',' +
      IntToStr(LineData.SyncStartFrame) + ',' +
      IntToStr(LineData.SyncEndFrame) + ',' +
      IntToStr(LineData.StartNoteIndex) + ',' +
      EncodeTextField(LineData.SourceText) + ',' +
      EncodeTextField(LineData.SyncText) + ',' +
      EncodeTextField(LineData.PlacementText);
    if Length(Text) > MAX_SONG_LYRICS_TEXT_LENGTH then
    begin
      Text := '';
      ErrorText := 'The whole-song text exceeds 32,767 characters.';
      Exit;
    end;
  end;
  Result := True;
end;

end.
