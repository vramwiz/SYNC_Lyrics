unit SongReaderVSQX;

interface

uses
  SysUtils,Classes,Xml.XMLDoc,Xml.XMLIntf,SongData,SongReader;

type
  //========================================================
  // 正規化ノート
  //========================================================
  TNormalizedNote = record
    TrackIndex : Integer;
    TickOn     : Integer;
    TickOff    : Integer;
    Key        : Integer;
    Lyric      : string;
  end;

  //========================================================
  // VSQX Reader
  //========================================================
  TSongReaderVSQX = class(TSongReader)
  private
    function ParseVSQX(const Doc: IXMLDocument; SongData: TSongData) : Boolean;

    function  DetectVersion(const Root: IXMLNode): Integer;

    procedure ParseMasterTrack(const Root: IXMLNode; SongData: TSongData);

    function ParseVSQ4(const Root: IXMLNode; SongData: TSongData) : Boolean;
    function ParseVSQ3(const Root: IXMLNode; SongData: TSongData) : Boolean;

    procedure AddNormalizedNote(const Note: TNormalizedNote; SongData: TSongData);

    function  TickToSec(Tick: Integer; SongData: TSongData): Double;
  public
    function LoadFromFile(const FileName: string; SongData: TSongData): Boolean;override;
  end;

implementation


{==========================================================
  Load
==========================================================}
function TSongReaderVSQX.LoadFromFile(const FileName: string; SongData: TSongData): Boolean;
var
  Doc: IXMLDocument;
begin
  Doc := NewXMLDocument;
  Doc.LoadFromFile(FileName);
  Doc.Active := True;

  Result := ParseVSQX(Doc, SongData);
end;

{==========================================================
  Root dispatcher
==========================================================}
function TSongReaderVSQX.ParseVSQX(const Doc: IXMLDocument; SongData: TSongData) : Boolean;
var
  Root    : IXMLNode;
  Version : Integer;
begin
  Result := False;
  Root := Doc.DocumentElement;
  if Root = nil then Exit;

  // ---- masterTrack は必ず最初に読む ----
  ParseMasterTrack(Root, SongData);

  Version := DetectVersion(Root);

  case Version of
    4: Result := ParseVSQ4(Root, SongData);
    3: Result := ParseVSQ3(Root, SongData);
  else
    Result := False;
  end;
end;

{==========================================================
  Version detect
==========================================================}
function TSongReaderVSQX.DetectVersion(const Root: IXMLNode): Integer;
begin
  if SameText(Root.LocalName, 'vsq4') then Exit(4);
  if SameText(Root.LocalName, 'vsq3') then Exit(3);
  Result := 0;
end;

{==========================================================
  MasterTrack
==========================================================}
procedure TSongReaderVSQX.ParseMasterTrack(const Root: IXMLNode; SongData: TSongData);
var
  i        : Integer;
  Node     : IXMLNode;
  Sub      : IXMLNode;
  Tick     : Integer;
  Tempo    : Integer;
  Num      : Integer;
begin
  // ---- 初期値 ----
  SongData.Info.Division := 480; // VSQ4 標準
  SongData.Info.TimeSigNumerator := 4;
  SongData.Info.TimeSigDenominator := 4;

  for i := 0 to Root.ChildNodes.Count - 1 do
  begin
    Node := Root.ChildNodes[i];
    if not SameText(Node.LocalName, 'masterTrack') then
      Continue;

    // -------- resolution --------
    Sub := Node.ChildNodes.FindNode('resolution');
    if (Sub <> nil) and TryStrToInt(Sub.Text, Tick) and (Tick > 0) then
      SongData.Info.Division := Tick;

    // -------- tempo --------
    Sub := Node.ChildNodes.FindNode('tempo');
    if Sub <> nil then
    begin
      if (Sub.ChildNodes.FindNode('t') <> nil) and
         (Sub.ChildNodes.FindNode('v') <> nil) and
         TryStrToInt(Sub.ChildNodes['t'].Text, Tick) then
      begin
        if TryStrToInt(Sub.ChildNodes['v'].Text, Tempo) then
        begin
          // VSQ4: v = BPM * 100
          // SMF互換: μsec / quarter
          // μsec = 60,000,000 / BPM
          if Tempo > 0 then
          begin
            SongData.Tempos.AddTempo(
              Tick,
              6000000000 / Tempo, // ← 60,000,000 * 100 / (BPM*100)
              SongData.Info.Division
            );
          end;
        end;
      end;
    end;

    // -------- timeSig（任意） --------
    Sub := Node.ChildNodes.FindNode('timeSig');
    if Sub <> nil then
    begin
      if (Sub.ChildNodes.FindNode('nu') <> nil) and
         TryStrToInt(Sub.ChildNodes['nu'].Text, Num) then
        SongData.Info.TimeSigNumerator := Num;

      if (Sub.ChildNodes.FindNode('de') <> nil) and
         TryStrToInt(Sub.ChildNodes['de'].Text, Num) then
        SongData.Info.TimeSigDenominator := Num;
    end;
  end;
end;


{==========================================================
  VSQ4
==========================================================}
function TSongReaderVSQX.ParseVSQ4(const Root: IXMLNode; SongData: TSongData) : Boolean;
var
  i, j, k  : Integer;
  TrackNode, PartNode, NoteNode, Sub : IXMLNode;
  TrackIndex : Integer;
  Note : TNormalizedNote;
  TickOn, Dur, Key : Integer;
begin
  for i := 0 to Root.ChildNodes.Count - 1 do
  begin
    TrackNode := Root.ChildNodes[i];
    if not SameText(TrackNode.LocalName, 'vsTrack') then
      Continue;

    // TrackIndex
    Sub := TrackNode.ChildNodes.FindNode('tNo');
    if (Sub <> nil) and TryStrToInt(Sub.Text, TrackIndex) then
      SongData.Tracks.AddTrackName(TrackIndex, '')
    else
      TrackIndex := 0;

    for j := 0 to TrackNode.ChildNodes.Count - 1 do
    begin
      PartNode := TrackNode.ChildNodes[j];
      if not SameText(PartNode.LocalName, 'vsPart') then
        Continue;

      for k := 0 to PartNode.ChildNodes.Count - 1 do
      begin
        NoteNode := PartNode.ChildNodes[k];
        if not SameText(NoteNode.LocalName, 'note') then
          Continue;

        if (NoteNode.ChildNodes.FindNode('t') = nil) or
           (NoteNode.ChildNodes.FindNode('dur') = nil) or
           (NoteNode.ChildNodes.FindNode('n') = nil) then
          Continue;

        if not TryStrToInt(NoteNode.ChildNodes['t'].Text, TickOn) then Continue;
        if not TryStrToInt(NoteNode.ChildNodes['dur'].Text, Dur) then Continue;
        if not TryStrToInt(NoteNode.ChildNodes['n'].Text, Key) then Continue;

        Note.TrackIndex := TrackIndex;
        Note.TickOn     := TickOn;
        Note.TickOff    := TickOn + Dur;
        Note.Key        := Key;

        Sub := NoteNode.ChildNodes.FindNode('y');
        if Sub <> nil then
          Note.Lyric := Sub.Text
        else
          Note.Lyric := '';

        AddNormalizedNote(Note, SongData);
      end;
    end;
  end;
  Result := True;
end;

{==========================================================
  VSQ3（最低限）
==========================================================}
function TSongReaderVSQX.ParseVSQ3(const Root: IXMLNode; SongData: TSongData) : Boolean;
begin
  // 将来必要になった場合に実装
  Result := False;
end;

{==========================================================
  Common register
==========================================================}
procedure TSongReaderVSQX.AddNormalizedNote(
  const Note: TNormalizedNote; SongData: TSongData);
var
  SecOn, SecOff : Double;
begin
  SecOn  := TickToSec(Note.TickOn, SongData);
  SecOff := TickToSec(Note.TickOff, SongData);

  SongData.Notes.AddNoteOn(Note.TrackIndex, Note.Key, 100, SecOn);
  SongData.Notes.AddNoteOff(Note.TrackIndex, Note.Key, SecOff);

  if Note.Lyric <> '' then
    SongData.Notes.AddLyric(Note.TrackIndex, SecOn, Note.Lyric);
end;

{==========================================================
  Tick → Sec
==========================================================}
function TSongReaderVSQX.TickToSec(Tick: Integer; SongData: TSongData): Double;
begin
  Result := SongData.Tempos.DeltaToSec(Tick, SongData.Info.Division);
end;

end.

