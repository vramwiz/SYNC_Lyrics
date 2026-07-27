unit SongDataNote;

interface

uses
  Windows, Messages, SysUtils, Classes,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistentIni,SongAIUEO;


type
  TSongNoteItem = class(TRTTIPersistentIni)
  private
    FStartSec   : Double;        // ノート開始時刻（秒）
    FEndSec     : Double;        // ノート終了時刻（秒、未確定時は負値）
    FKey        : Integer;       // MIDIノート番号
    FLyric      : string;        // ノートに対応する歌詞
    FVelocity   : Integer;       // ベロシティ値
    FTrackIndex : Integer;       // 所属トラック番号
    FPrevNote   : TSongNoteItem; // 前のノート
    FPrevCnt    : Integer;       // 前のノートとの接続数
    FLyricAIUEO: string;         // 空文字　aiueon が入る
  public
    property PrevNote   : TSongNoteItem read FPrevNote write FPrevNote;
    property PrevCnt    : Integer       read FPrevCnt  write FPrevCnt;
  published
    property StartSec   : Double        read FStartSec    write FStartSec;
    property EndSec     : Double        read FEndSec      write FEndSec;
    property Key        : Integer       read FKey         write FKey;
    property Lyric      : string        read FLyric       write FLyric;
    property Velocity   : Integer       read FVelocity    write FVelocity;
    property TrackIndex : Integer       read FTrackIndex  write FTrackIndex;
    property LyricAIUEO : string        read FLyricAIUEO  write FLyricAIUEO;
  end;

  TSongNoteList = class(TRTTIPersistentIniList<TSongNoteItem>)
  private
    function GetNotes(Index: Integer): TSongNoteItem; // Notes プロパティ用アクセサ
  public
    // NoteOn を追加または既存ノートに情報を付与
    procedure AddNoteOn(TrackIndex, Key, Velocity: Integer; StartSec: Double);
    // NoteOff を処理しノートの終了時刻を確定
    procedure AddNoteOff(TrackIndex, Key: Integer; TimeSec: Double);
    // 歌詞イベントをノートに関連付ける
    procedure AddLyric(TrackIndex: Integer; StartSec: Double; const Lyric: string);
    // NoteOff 用：未終了の NoteOn を探す
    function IndexOfTrackKey(TrackIndex, Key: Integer): Integer;
    // Lyric 用：StartSec が一致する NoteOn を探す
    function IndexOfStartSec(TrackIndex: Integer; StartSec: Double): Integer;
    // 秒に該当するノートのインデックス値
    function IndexOfSec(const Sec : Double) : Integer;
    // ノート情報を読み込み
    procedure LoadFromStrings(ts : TStringList); reintroduce;
    // ノート情報を保存
    procedure SaveToStrings(ts : TStringList); reintroduce;

    property Notes[Index : Integer] : TSongNoteItem read GetNotes; default;
  end;

type
  TSongNoteListEx = class(TList<TSongNoteItem>)
  private
    function GetTracks(Index: Integer): TSongNoteItem;
    //function GetFirst: TSongNoteItem;
    //function GetLast: TSongNoteItem; // トラック内ノート取得
  public
    // 秒に該当するノートのインデックス値
    function IndexOfSec(const Sec : Double) : Integer;
    property Notes[Index: Integer]: TSongNoteItem read GetTracks; default;
    //property First: TSongNoteItem read GetFirst;
    //property Last : TSongNoteItem read GetLast;
  end;



implementation

uses SectionFileManager;


{ TSongNoteList }

procedure TSongNoteList.AddNoteOn(TrackIndex, Key, Velocity: Integer; StartSec: Double);
var
  i : Integer;
  Item: TSongNoteItem;
begin
  i := IndexOfStartSec(TrackIndex,StartSec);
  if I = -1 then begin
    Item := AddNew;
    Item.TrackIndex := TrackIndex;
    Item.StartSec   := StartSec;
    Item.EndSec     := -1;          // 未確定
  end
  else begin
    Item := Items[I];
  end;
  Item.Key        := Key;
  Item.Velocity   := Velocity;
end;

procedure TSongNoteList.AddLyric(TrackIndex: Integer; StartSec: Double; const Lyric: string);
var
  i : Integer;
  Item: TSongNoteItem;
begin
  i := IndexOfStartSec(TrackIndex,StartSec);
  if I = -1 then begin
    Item := AddNew();
    Item.TrackIndex := TrackIndex;
    Item.StartSec := StartSec;
    Item.EndSec     := -1;   // 未確定
  end
  else begin
    Item := Items[I];
  end;
  Item.Lyric := Lyric;
end;

procedure TSongNoteList.AddNoteOff(TrackIndex, Key: Integer; TimeSec: Double);
var
  I: Integer;
  Item: TSongNoteItem;
begin
  // 対応する NoteOn を探す
  I := IndexOfTrackKey(TrackIndex, Key);
  if I = -1 then Exit;

  Item := Items[I];
  Item.EndSec := TimeSec;
end;

function TSongNoteList.GetNotes(Index: Integer): TSongNoteItem;
begin
  Result := inherited Items[Index];
end;


function TSongNoteList.IndexOfSec(const Sec: Double): Integer;
var
  i : Integer;
  note : TSongNoteItem;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    note := Notes[i];
    if (note.FStartSec <= Sec) and (Sec < note.FEndSec) then Exit(i);
  end;
end;

function TSongNoteList.IndexOfStartSec(TrackIndex: Integer; StartSec: Double): Integer;
var
  I: Integer;
begin
  Result := -1;

  // StartSec 完全一致（まずは厳密比較）
  for I := Count - 1 downto 0 do
  begin
    if Items[I].StartSec   <> StartSec then continue;
    if Items[I].TrackIndex <> TrackIndex then continue;
    Result := I;
    Exit;
  end;
end;

function TSongNoteList.IndexOfTrackKey(TrackIndex, Key: Integer): Integer;
var
  I: Integer;
  Item: TSongNoteItem;
begin
  Result := -1;

  // 直近の NoteOn を優先するため後ろから探索
  for I := Count - 1 downto 0 do
  begin
    Item := Items[I];
    if (Item.TrackIndex = TrackIndex) and
       (Item.Key = Key) and
       (Item.EndSec < 0) then
    begin
      Result := I;
      Exit;
    end;
  end;
end;

procedure TSongNoteList.LoadFromStrings(ts: TStringList);
var
  j : Integer;
  t : TStringList;
  ms : TSectionFileManager;
  note : TSongNoteItem;
begin
  ms := TSectionFileManager.Create;
  try
    ms.SetBrackets('{','}');
    ms.LoadFromStrings(ts);
    j := 0;
    while j < 9999 do begin
      t := ms.GetSection(IntToStr(j));
      if t = nil then break;
      note := AddNew();
      note.DeserializeFromStrings(note,t);
      Inc(j);
    end;
  finally
    ms.Free;
  end;
end;

procedure TSongNoteList.SaveToStrings(ts: TStringList);
var
  j : Integer;
  t : TStringList;
  ms : TSectionFileManager;
  note : TSongNoteItem;
begin
  ms := TSectionFileManager.Create;
  t := TStringList.Create;
  try
    ms.SetBrackets('{','}');
    for j := 0 to Count-1 do begin
      note := Notes[j];
      t.Clear;
      note.SerializeToStrings(note,t);
      ms.AddSection(IntToStr(j),t);
    end;
    ms.SaveToStrings(ts);
  finally
    ms.Free;
    t.Free;
  end;
end;

{ TSongNoteListEx }
{
function TSongNoteListEx.GetFirst: TSongNoteItem;
begin
  Result := nil;
  if Count = 0 then Exit;
  Result := Notes[0];
end;

function TSongNoteListEx.GetLast: TSongNoteItem;
begin
  Result := nil;
  if Count = 0 then Exit;
  Result := Notes[Count - 1];
end;
}

function TSongNoteListEx.GetTracks(Index: Integer): TSongNoteItem;
begin
  Result := TSongNoteItem(inherited Items[Index]);
end;

function TSongNoteListEx.IndexOfSec(const Sec: Double): Integer;
var
  i : Integer;
  note : TSongNoteItem;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    note := Notes[i];
    if (note.FStartSec <= Sec) and (Sec < note.FEndSec) then Exit(i);
  end;
end;



end.
