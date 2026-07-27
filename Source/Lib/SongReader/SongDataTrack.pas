unit SongDataTrack;

interface

uses
  Windows, Messages, SysUtils, Classes,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistentIni,SongAIUEO,SongDataNote;


type
  TSongTrackItem = class(TRTTIPersistentIni)
  private
    FNotes      : TSongNoteListEx; // トラックに属するノート一覧
    FTrackName  : string;          // トラック名
    FTrackIndex : Integer;         // トラック番号
    FLyrics     : TSongNoteList;
    function GetCaption: string;   // トラックに属する歌詞
  public
    // トラック要素生成
    constructor Create;
    // トラック要素破棄
    destructor Destroy;override;
    // ノートから歌詞データを作成
    procedure NoteToLyric(dics  : TSongAIUEO);
    procedure LyricToAIUEO(dics  : TSongAIUEO);
    property Notes : TSongNoteListEx read FNotes;
    property Lyrics : TSongNoteList  read FLyrics;
    property Caption : string read GetCaption;
  published
    property TrackName  : string  read FTrackName  write FTrackName;
    property TrackIndex : Integer read FTrackIndex write FTrackIndex;
  end;

  TSongTrackList = class(TRTTIPersistentIniList<TSongTrackItem>)
  private
    function GetTracks(Index: Integer): TSongTrackItem; // Tracks プロパティ用
  public
    // トラック名をトラック番号に関連付けて追加
    procedure AddTrackName(const TrackIndex : Integer;const Name: string);
    // トラック番号からインデックス取得
    function IndexOfTrack(const ATrackIndex : Integer) : Integer;
    // トラック情報を読み込み
    procedure LoadFromStrings(ts : TStringList); reintroduce;
    // トラック情報を保存
    procedure SaveToStrings(ts : TStringList); reintroduce;

    property Tracks[Index: Integer]: TSongTrackItem read GetTracks; default;
  end;



implementation

uses SectionFileManager;


{ TSongTrackItem }

constructor TSongTrackItem.Create;
begin
  FNotes  := TSongNoteListEx.Create;
  FLyrics := TSongNoteList.Create;
end;

destructor TSongTrackItem.Destroy;
begin
  FLyrics.Free;
  FNotes.Free;
  inherited;
end;

function TSongTrackItem.GetCaption: string;
var
  s : string;
begin
  s := 'Track ' + IntToStr(TrackIndex);
  s := s + ':' +  TrackName;
  Result := s;
end;

function NormalizeLyricToPhoneme(const S: string): string;
const
  // 拗音・小文字テーブル（1音扱い）
  SmallChars: array[0..9] of WideChar = (
    'ゃ','ゅ','ょ','ャ','ュ','ョ',
    'ぁ','ぃ','ぅ','ぇ'
    // 'ぉ','ォ' を含めたければ追加
  );
var
  i, j: Integer;
  IsSmall: Boolean;
begin
  Result := '';
  i := 1;

  while i <= Length(S) do
  begin
    // 次の文字が小文字か判定
    IsSmall := False;
    if i < Length(S) then
    begin
      for j := Low(SmallChars) to High(SmallChars) do
      begin
        if S[i+1] = SmallChars[j] then
        begin
          IsSmall := True;
          Break;
        end;
      end;
    end;

    if IsSmall then
    begin
      // 2文字で1音 → 小文字側を採用
      Result := Result + S[i+1];
      Inc(i, 2);
    end
    else
    begin
      // 通常1文字
      Result := Result + S[i];
      Inc(i);
    end;
  end;
end;


procedure TSongTrackItem.NoteToLyric(dics  : TSongAIUEO);
var
  i,j : Integer;
  len : Double;
  s,ss,Lyric : string;
  noteFrom,noteTo : TSongNoteItem;
begin
  FLyrics.Clear;
  for j := 0 to FNotes.Count-1 do begin
    noteFrom := FNotes[j];
    Lyric := '';
    ss := noteFrom.Lyric;
    ss := NormalizeLyricToPhoneme(ss);
    for i := 1 to Length(ss) do begin
      s := ss[i];
      if dics.IsVoice(s) then Lyric := Lyric + s;
    end;
    for i := 1 to Length(Lyric) do begin
      noteTo := FLyrics.AddNew;
      noteTo.Assign(noteFrom);
      noteTo.Lyric := Lyric[i];
      // 1文字あたりの長さ
      len := (noteFrom.EndSec - noteFrom.StartSec) / Length(Lyric);

      // i は 1 始まりなので (i-1) を使う
      noteTo.StartSec := noteFrom.StartSec + len * (i - 1);
      noteTo.EndSec   := noteTo.StartSec + len;
    end;
  end;
end;

procedure TSongTrackItem.LyricToAIUEO(dics: TSongAIUEO);
var
  j : Integer;
  Lyric,aiueo : string;
  note,prev : TSongNoteItem;
begin
  prev := nil;
  for j := 0 to FLyrics.Count-1 do begin
    note := FLyrics[j];
    if j > 0 then prev := FLyrics[j-1];

    if prev <> nil then begin
      if note.StartSec - prev.EndSec < 0.1 then begin
        note.PrevNote := prev;
        note.PrevCnt  := prev.PrevCnt + 1;
      end;
    end;

    Lyric := note.Lyric;
    aiueo := '';
    if dics.IsLongVowel(Lyric) then begin
      if prev = nil then begin
        aiueo := 'a';
      end
      else begin
        Lyric := prev.Lyric;
        if dics.IsLongVowel(Lyric) then begin
          aiueo := 'a';
        end
        else begin
          aiueo := dics.LyricToAIUEO(Lyric);
        end;
      end;
    end
    else begin
      aiueo := dics.LyricToAIUEO(Lyric);
    end;
    note.LyricAIUEO := aiueo;
  end;

end;

{ TSongTrackList }


procedure TSongTrackList.AddTrackName(const TrackIndex : Integer;const Name: string);
var
  Item: TSongTrackItem;
begin
  Item := AddNew;
  Item.FTrackIndex := TrackIndex;
  Item.TrackName := Name;
end;

function TSongTrackList.GetTracks(Index: Integer): TSongTrackItem;
begin
  Result := inherited Items[Index];
end;

function TSongTrackList.IndexOfTrack(const ATrackIndex: Integer): Integer;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to Count-1 do begin
    if Items[i].FTrackIndex = ATrackIndex then Exit(i);
  end;
end;



procedure TSongTrackList.LoadFromStrings(ts: TStringList);
var
  j : Integer;
  t : TStringList;
  ms : TSectionFileManager;
  track : TSongTrackItem;
begin
  ms := TSectionFileManager.Create;
  try
    ms.SetBrackets('{','}');
    ms.LoadFromStrings(ts);
    j := 0;
    while j < 9999 do begin
      t := ms.GetSection(IntToStr(j));
      if t = nil then break;
      track := AddNew();
      track.DeserializeFromStrings(track,t);
      inc(j);
    end;
  finally
    ms.Free;
  end;
end;

procedure TSongTrackList.SaveToStrings(ts: TStringList);
var
  j : Integer;
  t : TStringList;
  ms : TSectionFileManager;
  track : TSongTrackItem;
begin
  ms := TSectionFileManager.Create;
  t := TStringList.Create;
  try
    ms.SetBrackets('{','}');
    for j := 0 to Count-1 do begin
      track := Tracks[j];
      t.Clear;
      track.SerializeToStrings(track,t);
      ms.AddSection(IntToStr(j),t);
    end;
    ms.SaveToStrings(ts);
  finally
    ms.Free;
    t.Free;
  end;
end;

end.
