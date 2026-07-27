unit SongReaderMusicXML;

interface

uses SysUtils, Classes, Xml.XMLDoc, Xml.XMLIntf, Generics.Collections, SongData,SongReader;

type
  TSongReaderMusicXML = class(TSongReader)
  private
    FTotalTick : Integer; // 現在の累積Tick
    FDivision  : Integer; // divisions値
    FTrackIndex: Integer; // 現在のTrackIndex
    FTieTable  : TDictionary<Integer,Integer>; // tie開始Tick保持

    // score解析
    procedure ParseScore(const Root: IXMLNode; SongData: TSongData);
    // part解析
    procedure ParsePart(const PartNode: IXMLNode; SongData: TSongData);
    // measure解析
    procedure ParseMeasure(const MeasureNode: IXMLNode; SongData: TSongData);
    // attributes解析
    procedure ParseAttributes(const AttrNode: IXMLNode; SongData: TSongData);
    // direction解析（テンポ）
    procedure ParseDirection(const DirNode: IXMLNode; SongData: TSongData);
    // note解析
    procedure ParseNote(const NoteNode: IXMLNode; SongData: TSongData);
    // pitch→MIDI変換
    function PitchToKey(const PitchNode: IXMLNode): Integer;
    // Tick→Sec変換
    function TickToSec(Tick: Integer; SongData: TSongData): Double;
  public
    // ファイル読込
    function LoadFromFile(const FileName: string; SongData: TSongData) : Boolean;override;
  end;

implementation

// ファイル読込
// ファイル読込（DOCTYPE除去対応）
function TSongReaderMusicXML.LoadFromFile(const FileName: string; SongData: TSongData) : Boolean;
var
  Doc: IXMLDocument;
  Root: IXMLNode;
  SL: TStringList;
  S: string;
  P1, P2: Integer;
begin
  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName, TEncoding.UTF8); // UTF8前提
    S := SL.Text;

    // DOCTYPE削除（複数行対応）
    P1 := Pos('<!DOCTYPE', S);
    if P1 > 0 then begin // DOCTYPE存在
      P2 := Pos('>', S, P1);
      if P2 > 0 then
        Delete(S, P1, P2 - P1 + 1);
    end;

    Doc := NewXMLDocument;
    Doc.Active := False;
    Doc.LoadFromXML(S); // 文字列から読み込む
    Doc.Active := True;

    Root := Doc.DocumentElement;

    FTotalTick := 0;
    FDivision := 480;
    FTieTable := TDictionary<Integer,Integer>.Create;
    try
      SongData.Info.Division := FDivision;
      // 最低1テンポ保証
      if SongData.Tempos.Count = 0 then SongData.Tempos.AddTempo(0, 500000, FDivision);
      if Root <> nil then ParseScore(Root, SongData);    // ルート確認
      Result := True;
    finally
      FTieTable.Free;
    end;

  finally
    SL.Free;
  end;
end;

// score解析
procedure TSongReaderMusicXML.ParseScore(const Root: IXMLNode; SongData: TSongData);
var i: Integer; Node: IXMLNode;
begin
  for i := 0 to Root.ChildNodes.Count-1 do begin
    Node := Root.ChildNodes[i];
    if SameText(Node.LocalName,'part') then begin // partのみ処理
      FTotalTick := 0;
      FTrackIndex := SongData.Tracks.Count;
      SongData.Tracks.AddTrackName(FTrackIndex,'');
      ParsePart(Node,SongData);
    end;
  end;
end;

// part解析
procedure TSongReaderMusicXML.ParsePart(const PartNode: IXMLNode; SongData: TSongData);
var i: Integer; Node: IXMLNode;
begin
  for i := 0 to PartNode.ChildNodes.Count-1 do begin
    Node := PartNode.ChildNodes[i];
    if SameText(Node.LocalName,'measure') then begin // measure処理
      ParseMeasure(Node,SongData);
    end;
  end;
end;

// measure解析
procedure TSongReaderMusicXML.ParseMeasure(const MeasureNode: IXMLNode; SongData: TSongData);
var i: Integer; Node: IXMLNode;
begin
  for i := 0 to MeasureNode.ChildNodes.Count-1 do begin
    Node := MeasureNode.ChildNodes[i];
    if SameText(Node.LocalName,'attributes') then begin // attributes処理
      ParseAttributes(Node,SongData);
    end else
    if SameText(Node.LocalName,'direction') then begin // direction処理
      ParseDirection(Node,SongData);
    end else
    if SameText(Node.LocalName,'note') then begin // note処理
      ParseNote(Node,SongData);
    end;
  end;
end;

// attributes解析
procedure TSongReaderMusicXML.ParseAttributes(const AttrNode: IXMLNode; SongData: TSongData);
var DivNode: IXMLNode; v: Integer;
begin
  DivNode := AttrNode.ChildNodes.FindNode('divisions');
  if (DivNode<>nil) and TryStrToInt(DivNode.Text,v) and (v>0) then begin // divisions更新
    FDivision := v;
    SongData.Info.Division := v;
  end;
end;

// direction解析（テンポ）
procedure TSongReaderMusicXML.ParseDirection(const DirNode: IXMLNode; SongData: TSongData);
var SoundNode: IXMLNode; BPM: Double; μsec: Double;
begin
  SoundNode := DirNode.ChildNodes.FindNode('sound');
  if (SoundNode<>nil) and (SoundNode.HasAttribute('tempo')) then begin // tempo存在
    BPM := StrToFloatDef(SoundNode.Attributes['tempo'],0);
    if BPM>0 then begin // BPM有効
      μsec := 60000000/BPM;
      SongData.Tempos.AddTempo(FTotalTick,μsec,FDivision);
    end;
  end;
end;

// note解析
procedure TSongReaderMusicXML.ParseNote(const NoteNode: IXMLNode; SongData: TSongData);
var DurNode,PitchNode,LyricNode,TieNode: IXMLNode; Dur,Key,StartTick,EndTick: Integer; IsRest,IsChord,IsTieStart,IsTieStop: Boolean; SecOn,SecOff: Double; Lyric: string;
begin
  IsRest := NoteNode.ChildNodes.FindNode('rest')<>nil;
  IsChord := NoteNode.ChildNodes.FindNode('chord')<>nil;
  DurNode := NoteNode.ChildNodes.FindNode('duration');
  if DurNode=nil then Exit;
  if not TryStrToInt(DurNode.Text,Dur) then Exit;
  if IsRest then begin // 休符
    FTotalTick := FTotalTick + Dur;
    Exit;
  end;
  PitchNode := NoteNode.ChildNodes.FindNode('pitch');
  if PitchNode=nil then Exit;
  Key := PitchToKey(PitchNode);
  TieNode := NoteNode.ChildNodes.FindNode('tie');
  IsTieStart := False;
  IsTieStop := False;
  if TieNode<>nil then begin // tie判定
    if SameText(TieNode.Attributes['type'],'start') then IsTieStart := True;
    if SameText(TieNode.Attributes['type'],'stop') then IsTieStop := True;
  end;
  if not IsChord then StartTick := FTotalTick else StartTick := FTotalTick;
  EndTick := StartTick + Dur;
  LyricNode := NoteNode.ChildNodes.FindNode('lyric');
  if (LyricNode<>nil) and (LyricNode.ChildNodes.FindNode('text')<>nil) then Lyric := LyricNode.ChildNodes['text'].Text else Lyric := '';
  if IsTieStart then begin // tie開始
    FTieTable.AddOrSetValue(Key,StartTick);
  end else
  if IsTieStop then begin // tie終了
    if FTieTable.ContainsKey(Key) then begin
      StartTick := FTieTable[Key];
      FTieTable.Remove(Key);
      SecOn := TickToSec(StartTick,SongData);
      SecOff := TickToSec(EndTick,SongData);
      SongData.Notes.AddNoteOn(FTrackIndex,Key,100,SecOn);
      SongData.Notes.AddNoteOff(FTrackIndex,Key,SecOff);
      if Lyric<>'' then SongData.Notes.AddLyric(FTrackIndex,SecOn,Lyric);
    end;
  end else begin // 通常ノート
    SecOn := TickToSec(StartTick,SongData);
    SecOff := TickToSec(EndTick,SongData);
    SongData.Notes.AddNoteOn(FTrackIndex,Key,100,SecOn);
    SongData.Notes.AddNoteOff(FTrackIndex,Key,SecOff);
    if Lyric<>'' then SongData.Notes.AddLyric(FTrackIndex,SecOn,Lyric);
  end;
  if not IsChord then FTotalTick := FTotalTick + Dur;
end;

// pitch→MIDI変換
function TSongReaderMusicXML.PitchToKey(const PitchNode: IXMLNode): Integer;
var StepNode,AlterNode,OctNode: IXMLNode; Step: string; Alter,Oct: Integer; C: Char;
begin
  StepNode := PitchNode.ChildNodes.FindNode('step');
  AlterNode := PitchNode.ChildNodes.FindNode('alter');
  OctNode := PitchNode.ChildNodes.FindNode('octave');
  Step := '';
  Alter := 0;
  Oct := 4;
  if StepNode<>nil then Step := StepNode.Text;
  if (AlterNode<>nil) and not TryStrToInt(AlterNode.Text,Alter) then Alter := 0;
  if (OctNode<>nil) and not TryStrToInt(OctNode.Text,Oct) then Oct := 4;
  if Step<>'' then C := UpCase(Step[1]) else C := 'C'; // step先頭1文字（空ならC扱い）
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

// Tick→Sec変換
function TSongReaderMusicXML.TickToSec(Tick: Integer; SongData: TSongData): Double;
begin
  Result := SongData.Tempos.DeltaToSec(Tick,FDivision);
end;

end.
