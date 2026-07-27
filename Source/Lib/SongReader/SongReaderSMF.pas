unit SongReaderSMF;

interface

uses
  SysUtils, Classes, Winapi.Windows,
  SongData, System.Diagnostics,SongReader,TextEncodingUtils;

type
  TSongReaderSMF = class(TSongReader)
  private
    FTimeSec    : Double;     // 現在の絶対時間（秒）
    FTotalDelta : Integer;    // 先頭から現在までのDelta時間位置
    FTrackMax   : Integer;    // 最大トラック数

    function ParseHeader(Stream: TStream; SongData: TSongData) : Boolean;

    function ParseTrack(Stream: TStream; TrackIndex: Integer; SongData: TSongData) : Boolean;
    function ParseTrackMetaEvent( Stream   : TStream;SongData : TSongData;TrackIndex : Integer): Boolean;  // True = EndOfTrack
    procedure ParseNoteEvent(Stream : TStream;TrackIndex : Integer;Status : Byte;Data1 : Byte;FTimeSec : Double;SongData   : TSongData);

    function  ReadVariableLength(Stream: TStream): Integer;

  public
    function LoadFromFile(const FileName: string; SongData: TSongData) : Boolean;override;
  end;

implementation

{ ---------------------------------------------------------
  Endian 変換
--------------------------------------------------------- }
function SwapEndian32(Value: Cardinal): Cardinal;
begin
  Result :=
    ((Value and $000000FF) shl 24) or
    ((Value and $0000FF00) shl 8)  or
    ((Value and $00FF0000) shr 8)  or
    ((Value and $FF000000) shr 24);
end;

function SwapEndian16(Value: Word): Word;
begin
  Result :=
    ((Value and $00FF) shl 8) or
    ((Value and $FF00) shr 8);
end;
function DecodeSMFText(const Buf: TBytes): string;
begin
  Result := DecodeTextAutoEncoding(Buf);
end;

function DecodeSMFTextLyric(const Buf: TBytes; out Lyric: string): Boolean;
begin
  Lyric := Trim(DecodeSMFText(Buf));

  // KAR系のText meta eventにはタイトル等のメタ情報も混ざる。
  if Lyric = '' then Exit(False);
  if Lyric[1] = '@' then Exit(False);

  // 行頭の \ / / は歌詞行区切りとして扱い、表示歌詞から外す。
  while (Lyric <> '') and CharInSet(Lyric[1], ['\', '/']) do
    Delete(Lyric, 1, 1);
  Lyric := Trim(Lyric);

  Result := Lyric <> '';
end;

{ ---------------------------------------------------------
  Variable Length
--------------------------------------------------------- }
function TSongReaderSMF.ReadVariableLength(Stream: TStream): Integer;
var
  B: Byte;
begin
  Result := 0;
  repeat
    Stream.ReadBuffer(B, 1);
    Result := (Result shl 7) or (B and $7F);
  until (B and $80) = 0;
end;

{ ---------------------------------------------------------
  Header
--------------------------------------------------------- }
function TSongReaderSMF.ParseHeader(Stream: TStream; SongData: TSongData) : Boolean;
var
  ID: array[0..3] of AnsiChar;
  ChunkSize: Cardinal;
  FormatType: Word;
  NumTracks: Word;
  Division: Word;
begin
  Result := False;
  Stream.ReadBuffer(ID, 4);
  Stream.ReadBuffer(ChunkSize, 4);
  ChunkSize := SwapEndian32(ChunkSize);

  if ID <> 'MThd' then Exit;

  Stream.ReadBuffer(FormatType, 2);
  Stream.ReadBuffer(NumTracks, 2);
  Stream.ReadBuffer(Division, 2);

  FormatType := SwapEndian16(FormatType);
  NumTracks  := SwapEndian16(NumTracks);
  Division   := SwapEndian16(Division);

  SongData.Info.Division := Division;
  //FTempo := 500000;  // default
  FTimeSec := 0;

  FTrackMax := NumTracks;

  Result := True;
end;


{ ---------------------------------------------------------
  Track
--------------------------------------------------------- }
function TSongReaderSMF.ParseTrack(Stream: TStream; TrackIndex: Integer; SongData: TSongData) : Boolean;
var
  ID: array[0..3] of AnsiChar;
  ChunkSize: Cardinal;
  TrackEndPos: Int64;

  Delta: Integer;
  Status, RunningStatus: Byte;
  Data1 : Byte;
  Len: Integer;
begin
  Result := False;
  Stream.ReadBuffer(ID, 4);
  Stream.ReadBuffer(ChunkSize, 4);
  ChunkSize := SwapEndian32(ChunkSize);
  TrackEndPos := Stream.Position + ChunkSize;

  if ID <> 'MTrk' then Exit;

  //OutputDebugString(PChar(  Format('[SMF] Track %d START Pos=%d End=%d',  [TrackIndex, Stream.Position, TrackEndPos])));

  RunningStatus := 0;
  FTotalDelta := 0;

  while Stream.Position < TrackEndPos do
  begin
    // Δtime
    Delta := ReadVariableLength(Stream);
    //FTimeSec := FTimeSec + (Delta / FPPQ) * (FTempo / 1_000_000);
    FTotalDelta := FTotalDelta + Delta;
    FTimeSec := SongData.Tempos.DeltaToSec(FTotalDelta,SongData.Info.Division);

    //OutputDebugString(PChar(Format('  Δ=%d  Time=%.6f', [Delta, FTimeSec])));

    // Status
    Stream.ReadBuffer(Status, 1);

    // -------- Meta Event --------
    if Status = $FF then
    begin
      if ParseTrackMetaEvent(Stream, SongData,TrackIndex) then Break;
      Continue;
    end;

    // -------- SysEx --------
    if (Status = $F0) or (Status = $F7) then
    begin
      Len := ReadVariableLength(Stream);
      Stream.Seek(Len, soFromCurrent);
      //OutputDebugString(PChar(Format('  SysEx len=%d', [Len])));
      Continue;
    end;

    // -------- Channel Event --------
    if Status < $80 then
    begin
      // Running Status
      Data1 := Status;
      Status := RunningStatus;
    end
    else
    begin
      RunningStatus := Status;
      Stream.ReadBuffer(Data1, 1);
    end;

    // -------- Channel Event : Note --------
    ParseNoteEvent(Stream,TrackIndex,Status,Data1,FTimeSec,SongData);

  end;

  Result := True;
end;


function TSongReaderSMF.ParseTrackMetaEvent(Stream: TStream;SongData: TSongData;TrackIndex : Integer): Boolean;
var
  MetaType : Byte;
  Len      : Integer;
  Buf      : TBytes;
  Tempo    : Double;
  LyricText: string;
begin
  Result := False;

  // MetaType
  Stream.ReadBuffer(MetaType, 1);
  Len := ReadVariableLength(Stream);

  case MetaType of
    $01: // Text (KAR系では歌詞として使われることがある)
    begin
      SetLength(Buf, Len);
      if Len > 0 then
        Stream.ReadBuffer(Buf[0], Len);

      if DecodeSMFTextLyric(Buf, LyricText) then
        SongData.Notes.AddLyric(TrackIndex,SongData.Tempos.DeltaToSec(FTotalDelta,SongData.Info.Division),LyricText);
    end;
    $03: // TrackName
    begin
      SetLength(Buf, Len);
      if Len > 0 then
        Stream.ReadBuffer(Buf[0], Len);

      //OutputDebugString(PChar('  Meta TrackName: ' + TEncoding.ANSI.GetString(Buf)));

      SongData.Tracks.AddTrackName(TrackIndex,DecodeSMFText(Buf));
    end;

    $05: // Lyric
    begin
      SetLength(Buf, Len);
      if Len > 0 then
        Stream.ReadBuffer(Buf[0], Len);

      //OutputDebugString(PChar('  Meta Lyric: ' + TEncoding.ANSI.GetString(Buf)));

      // ★ 実データ反映
      // 現在の累積Δから秒を算出して歌詞を追加
      SongData.Notes.AddLyric(TrackIndex,SongData.Tempos.DeltaToSec(FTotalDelta,SongData.Info.Division),DecodeSMFText(Buf));
    end;

    $51: // Tempo
    begin
      // Tempo は常に 3byte
      SetLength(Buf, 3);
      Stream.ReadBuffer(Buf[0], 3);

      Tempo := (Buf[0] shl 16) or (Buf[1] shl 8) or Buf[2];
      SongData.Tempos.AddTempo(FTotalDelta,Tempo,SongData.Info.Division);

      //OutputDebugString(PChar(Format('  Meta Tempo: %d', [Tempo])));
    end;

    $2F: // EndOfTrack
    begin
      //OutputDebugString('  Meta EndOfTrack');
      if Len > 0 then Stream.Seek(Len, soFromCurrent);

      Result := True; // トラック終了通知
    end;
  else
    // 未対応 MetaEvent
    if Len > 0 then Stream.Seek(Len, soFromCurrent);
  end;
end;

procedure TSongReaderSMF.ParseNoteEvent(
  Stream     : TStream;
  TrackIndex : Integer;
  Status     : Byte;
  Data1      : Byte;
  FTimeSec   : Double;
  SongData   : TSongData
);
var
  Data2: Byte;
begin
  case (Status and $F0) of
    $80: // NoteOff
    begin
      Stream.ReadBuffer(Data2, 1);

      //OutputDebugString(PChar(Format('  NoteOff ch=%d key=%d',[Status and $0F, Data1])));

      // ★ 実データ反映
      SongData.Notes.AddNoteOff(
        TrackIndex,
        Data1,
        FTimeSec
      );
    end;

    $90: // NoteOn
    begin
      Stream.ReadBuffer(Data2, 1);

      if Data2 = 0 then
      begin
        //OutputDebugString(PChar(Format('  NoteOff(ch=%d) key=%d',[Status and $0F, Data1])));

        // ★ velocity=0 → NoteOff
        SongData.Notes.AddNoteOff(TrackIndex,Data1,FTimeSec);
      end
      else
      begin
        //OutputDebugString(PChar(Format('  NoteOn  ch=%d key=%d vel=%d',[Status and $0F, Data1, Data2])));

        // ★ 実データ反映
        SongData.Notes.AddNoteOn(TrackIndex,Data1,Data2,FTimeSec);
      end;
    end;

    $A0, $B0, $E0:
      Stream.ReadBuffer(Data2, 1); // 2byte event

    $C0, $D0:
      ; // 1byte event
  end;
end;


{ ---------------------------------------------------------
  LoadFromFile
--------------------------------------------------------- }
function TSongReaderSMF.LoadFromFile(const FileName: string; SongData: TSongData) : Boolean;
var
  FS: TFileStream;
  i: Integer;
  f : Boolean;
begin
  Result := False;
  FS := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    f := ParseHeader(FS, SongData);
    if not f then Exit;

    for i := 0 to FTrackMax - 1 do begin
      f := ParseTrack(FS, i, SongData);
      if not f  then Exit;
    end;
    Result := True;
  finally
    FS.Free;
  end;
end;

end.

