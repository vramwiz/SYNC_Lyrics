unit SongReaderMusicMSC;

interface

uses Windows,SysUtils, Classes, Xml.XMLDoc, Xml.XMLIntf, Generics.Collections, SongData,System.Zip,SongReader;

type
  TSongReaderMusicMSC = class(TSongReader)
  private
    FSongData  : TSongData;
    FTotalTick : Integer;
    FDivision  : Integer;
    FTrackIndex: Integer;
    FTieTable  : TDictionary<Integer,Integer>;

    procedure ParseScore(const Root: IXMLNode);
    //procedure ParsePart(const PartNode: IXMLNode);
    procedure ParseStaff(const StaffNode: IXMLNode);
    procedure ParseMeasure(const MeasureNode: IXMLNode);
    procedure ParseVoice(const VoiceNode: IXMLNode);
    procedure ParseRest(const RestNode: IXMLNode);
    function  RestTicks(const RestNode: IXMLNode): Integer;
    function  DurationTypeToTicks(const DurationType: string): Integer;
    procedure ParseChord(const ChordNode: IXMLNode);
    procedure ParseTempo(const TempoNode: IXMLNode);
    //function PitchToKey(const PitchNode: IXMLNode): Integer;
    procedure ParseChordNotes(const ChordNode: IXMLNode;Ticks: Integer);
  protected
    function LoadFromStream(Stream: TStream; SongData: TSongData) : Boolean; virtual;
  public
  end;



implementation

{ TSongReaderMusicMSC }

function TSongReaderMusicMSC.LoadFromStream(Stream: TStream; SongData: TSongData): Boolean;
var
  Doc: IXMLDocument;
  Root: IXMLNode;
begin
  Result := False;
  FSongData := SongData;
  if (Stream = nil) or (SongData = nil) then Exit;

  Doc := NewXMLDocument;
  try
    Stream.Position := 0;
    Doc.LoadFromStream(Stream);
    Doc.Active := True;
    Root := Doc.DocumentElement;

    FTotalTick := 0;
    FDivision  := 480;
    FTieTable  := TDictionary<Integer,Integer>.Create;
    try
      SongData.Info.Division := FDivision;

      // 先頭テンポ保証（存在しない場合）
      if SongData.Tempos.Count = 0 then
        SongData.Tempos.AddTempo(0, 500000, FDivision);

      if Root <> nil then
        ParseScore(Root);

      Result := True;
    finally
      FTieTable.Free;
    end;

  except
    Result := False;
  end;
end;

procedure DebugDumpNode(const Node: IXMLNode; Depth: Integer);
var
  i: Integer;
  s: string;
begin
  if Node = nil then Exit;

  s := 'Depth='+ IntToStr(Depth) + ' LocalName=' + Node.LocalName;
  OutputDebugString(PChar(s));

  for i := 0 to Node.ChildNodes.Count - 1 do
    DebugDumpNode(Node.ChildNodes[i], Depth + 1);
end;

procedure TSongReaderMusicMSC.ParseScore(const Root: IXMLNode);
var
  i: Integer;
  Node: IXMLNode;
begin
  if Root = nil then Exit;

  // Scoreノードに到達したら
  if SameText(Root.LocalName, 'Score') then
  begin
    for i := 0 to Root.ChildNodes.Count - 1 do
    begin
      Node := Root.ChildNodes[i];

      // ① Part（定義）
      if SameText(Node.LocalName, 'Part') then
        Continue; // 今回は無視

      // ② 実データStaff
      if SameText(Node.LocalName, 'Staff') then
      begin
        FTotalTick := 0;
        FTrackIndex := FSongData.Tracks.Count;
        FSongData.Tracks.AddTrackName(FTrackIndex, '');

        ParseStaff(Node);
      end;
    end;
    Exit;
  end;

  // 再帰探索
  for i := 0 to Root.ChildNodes.Count - 1 do
    ParseScore(Root.ChildNodes[i]);
end;

procedure TSongReaderMusicMSC.ParseStaff(const StaffNode: IXMLNode);
var
  i: Integer;
  Node: IXMLNode;
begin
  OutputDebugString(PChar('--- ParseStaff ---'));

  for i := 0 to StaffNode.ChildNodes.Count - 1 do
  begin
    Node := StaffNode.ChildNodes[i];

    OutputDebugString(PChar('  Staff Child: ' + Node.LocalName));

    if SameText(Node.LocalName, 'Measure') then
    begin
      OutputDebugString(PChar('    >>> Measure FOUND'));
      ParseMeasure(Node);
    end;
  end;
end;

{
procedure TSongReaderMusicMSC.ParsePart(const PartNode: IXMLNode);
var
  i, j: Integer;
  StaffNode, ChildNode: IXMLNode;
  HasMeasure: Boolean;
begin

  OutputDebugString(PChar('Checking Staff Node:'));
  DebugDumpNode(StaffNode, 1);

  if PartNode = nil then Exit;


  for i := 0 to PartNode.ChildNodes.Count - 1 do
  begin
    StaffNode := PartNode.ChildNodes[i];

    if not SameText(StaffNode.LocalName, 'Staff') then
      Continue;

    HasMeasure := False;

    // Staff内部を確認
    for j := 0 to StaffNode.ChildNodes.Count - 1 do
    begin
      ChildNode := StaffNode.ChildNodes[j];
      if SameText(ChildNode.LocalName, 'Measure') then
      begin
        HasMeasure := True;
        Break;
      end;
    end;

    if not HasMeasure then
      Continue;

    // 実データStaff
    FTotalTick := 0;
    FTrackIndex := FSongData.Tracks.Count;

    FSongData.Tracks.AddTrackName(FTrackIndex, '');

    ParseStaff(StaffNode);
  end;
end;
}


procedure TSongReaderMusicMSC.ParseMeasure(const MeasureNode: IXMLNode);
var
  i: Integer;
  Node: IXMLNode;
begin
  for i := 0 to MeasureNode.ChildNodes.Count - 1 do
  begin
    Node := MeasureNode.ChildNodes[i];

    if SameText(Node.LocalName, 'voice') then
      ParseVoice(Node);
  end;
end;

procedure TSongReaderMusicMSC.ParseTempo(const TempoNode: IXMLNode);
var
  qnPerSec: Double;
  μsec: Double;
  TempoVal: string;
begin
  TempoVal := TempoNode.ChildNodes['tempo'].Text;

  // MuseScore tempo は quarter notes per second
  qnPerSec := StrToFloatDef(TempoVal, 0);

  if qnPerSec > 0 then
  begin
    // microseconds per quarter note
    μsec := 1000000 / qnPerSec;

    FSongData.Tempos.AddTempo(FTotalTick, μsec, FDivision);
  end;
end;

procedure TSongReaderMusicMSC.ParseVoice(const VoiceNode: IXMLNode);
var
  i: Integer;
  Node: IXMLNode;
begin
  for i := 0 to VoiceNode.ChildNodes.Count - 1 do
  begin
    Node := VoiceNode.ChildNodes[i];

    if SameText(Node.LocalName, 'Chord') then
      ParseChord(Node)
    else if SameText(Node.LocalName, 'Rest') then
      ParseRest(Node)
    else if SameText(Node.LocalName, 'Tempo') then
      ParseTempo(Node);
  end;
end;

procedure TSongReaderMusicMSC.ParseChord(const ChordNode: IXMLNode);
var
  TypeNode, DotsNode: IXMLNode;
  DurationType: string;
  BaseTicks, Ticks: Integer;
  Dots: Integer;
begin
  if ChordNode = nil then Exit;

  // durationType取得
  TypeNode := ChordNode.ChildNodes.FindNode('durationType');
  if TypeNode = nil then Exit;

  DurationType := Trim(TypeNode.Text);
  BaseTicks := DurationTypeToTicks(DurationType);

  // 付点対応
  Dots := 0;
  DotsNode := ChordNode.ChildNodes.FindNode('dots');
  if DotsNode <> nil then
    Dots := StrToIntDef(Trim(DotsNode.Text), 0);

  Ticks := BaseTicks;

  if Dots >= 1 then Inc(Ticks, BaseTicks div 2);
  if Dots >= 2 then Inc(Ticks, BaseTicks div 4);
  if Dots >= 3 then Inc(Ticks, BaseTicks div 8);

  // ---- Note取得 ----
  ParseChordNotes(ChordNode, Ticks);

  // 時間を進める
  Inc(FTotalTick, Ticks);
end;

procedure TSongReaderMusicMSC.ParseChordNotes(const ChordNode: IXMLNode;Ticks: Integer);
var
  i: Integer;
  Node: IXMLNode;
  PitchNode: IXMLNode;
  LyricsNode: IXMLNode;
  TextNode: IXMLNode;
  Pitch: Integer;
  LyricText: string;
  SecOn, SecOff: Double;
begin
  if ChordNode = nil then Exit;

  // ---- Lyrics取得 ----
  LyricText := '';
  LyricsNode := ChordNode.ChildNodes.FindNode('Lyrics');
  if LyricsNode <> nil then
  begin
    TextNode := LyricsNode.ChildNodes.FindNode('text');
    if TextNode <> nil then
      LyricText := Trim(TextNode.Text);
  end;

  // 秒へ変換
  SecOn  := FSongData.Tempos.DeltaToSec(FTotalTick,FDivision);
  SecOff := FSongData.Tempos.DeltaToSec(FTotalTick + Ticks,FDivision);
  //SecOn  := TickToSec(FTotalTick);               DeltaToSec
  //SecOff := TickToSec(FTotalTick + Ticks);

  // ---- Note走査 ----
  for i := 0 to ChordNode.ChildNodes.Count - 1 do
  begin
    Node := ChordNode.ChildNodes[i];

    if not SameText(Node.LocalName, 'Note') then
      Continue;

    PitchNode := Node.ChildNodes.FindNode('pitch');
    if PitchNode = nil then
      Continue;

    Pitch := StrToIntDef(Trim(PitchNode.Text), -1);
    if Pitch < 0 then
      Continue;

    // ---- 既存API形式で追加 ----
    FSongData.Notes.AddNoteOn(FTrackIndex, Pitch, 100, SecOn);
    FSongData.Notes.AddNoteOff(FTrackIndex, Pitch, SecOff);

    if LyricText <> '' then FSongData.Notes.AddLyric(FTrackIndex, SecOn, LyricText);
  end;
end;

{
function TSongReaderMusicMSC.PitchToKey(const PitchNode: IXMLNode): Integer;
var
  StepNode, AlterNode, OctNode: IXMLNode;
  Step: string;
  Alter, Oct: Integer;
  C: Char;
begin
  StepNode  := PitchNode.ChildNodes.FindNode('step');
  AlterNode := PitchNode.ChildNodes.FindNode('alter');
  OctNode   := PitchNode.ChildNodes.FindNode('octave');

  Step  := '';
  Alter := 0;
  Oct   := 4;

  if StepNode<>nil then Step := StepNode.Text;
  if (AlterNode<>nil) and not TryStrToInt(AlterNode.Text,Alter) then Alter := 0;
  if (OctNode<>nil) and not TryStrToInt(OctNode.Text,Oct) then Oct := 4;

  if Step<>'' then C := UpCase(Step[1]) else C := 'C';

  case C of
    'C': Result := 0;
    'D': Result := 2;
    'E': Result := 4;
    'F': Result := 5;
    'G': Result := 7;
    'A': Result := 9;
    'B': Result := 11;
  else Result := 0;
  end;

  Result := Result + Alter + (Oct+1)*12;
end;
}

procedure TSongReaderMusicMSC.ParseRest(const RestNode: IXMLNode);
var
  Ticks: Integer;
begin
  if RestNode = nil then Exit;

  Ticks := RestTicks(RestNode);

  // 休符＝発音なしで時間だけ進める
  Inc(FTotalTick, Ticks);

  // デバッグ（必要なら）
  // OutputDebugString(PChar(Format('Rest: +%d ticks (Total=%d)', [Ticks, FTotalTick])));
end;

function TSongReaderMusicMSC.RestTicks(const RestNode: IXMLNode): Integer;
var
  DurNode, TypeNode, DotsNode: IXMLNode;
  DurText, TypeText: string;
  BaseTicks: Integer;
  Dots: Integer;
begin
  Result := 0;
  if RestNode = nil then Exit;

  // 1) duration があれば最優先（整数）
  DurNode := RestNode.ChildNodes.FindNode('duration');
  if (DurNode <> nil) then
  begin
    DurText := Trim(DurNode.Text);
    if DurText <> '' then
    begin
      Result := StrToIntDef(DurText, 0);
      if Result > 0 then Exit;
    end;
  end;

  // 2) durationType + dots で計算
  TypeNode := RestNode.ChildNodes.FindNode('durationType');
  if TypeNode = nil then Exit;

  TypeText := Trim(TypeNode.Text);
  BaseTicks := DurationTypeToTicks(TypeText);
  if BaseTicks <= 0 then Exit;

  Dots := 0;
  DotsNode := RestNode.ChildNodes.FindNode('dots');
  if DotsNode <> nil then
    Dots := StrToIntDef(Trim(DotsNode.Text), 0);

  // 付点計算（1dot=+1/2, 2dot=+1/4, 3dot=+1/8 ...）
  Result := BaseTicks;
  case Dots of
    0: ; // no-op
    1: Inc(Result, BaseTicks div 2);
    2: begin
         Inc(Result, BaseTicks div 2);
         Inc(Result, BaseTicks div 4);
       end;
    3: begin
         Inc(Result, BaseTicks div 2);
         Inc(Result, BaseTicks div 4);
         Inc(Result, BaseTicks div 8);
       end;
  else
    // dotsが4以上は稀なので一般式で処理
    // Result := BaseTicks + BaseTicks/2 + BaseTicks/4 + ...
    // ※整数丸め誤差を嫌うなら分数管理にする
    while Dots > 0 do
    begin
      BaseTicks := BaseTicks div 2;
      if BaseTicks <= 0 then Break;
      Inc(Result, BaseTicks);
      Dec(Dots);
    end;
  end;
end;

function TSongReaderMusicMSC.DurationTypeToTicks(const DurationType: string): Integer;
var
  s: string;
begin
  // ここは「あなたの基準tick」に合わせてください。
  // MuseScore側は Division などが絡みますが、まずは仮のPPQを置いて進められます。
  //
  // 例：quarter=480 を基準（よくあるPPQ）
  // あなたの既存実装があれば、それに合わせて差し替えてOKです。
  s := LowerCase(Trim(DurationType));

  if s = 'measure' then
  begin
    // 小節休符：拍子が必要（TimeSig）なので、最低限は 0 か「現在小節長」を返す
    // いまは保留：とりあえず 0（必要になったら実装）
    Exit(0);
  end;

  if s = 'whole'   then Exit(480 * 4);
  if s = 'half'    then Exit(480 * 2);
  if s = 'quarter' then Exit(480 * 1);
  if s = 'eighth'  then Exit(480 div 2);
  if s = '16th'    then Exit(480 div 4);
  if s = '32nd'    then Exit(480 div 8);
  if s = '64th'    then Exit(480 div 16);

  // MuseScoreで出ることがある派生
  if s = 'breve'   then Exit(480 * 8);

  Result := 0;
end;

end.
