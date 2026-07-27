unit SongData;

interface

uses
  Windows, Messages, SysUtils, Classes,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistent,SongAIUEO,
  SongDataNote,SongDataTrack,SongDataTempo,SongDataInfo;

type
  TSongData = class(TPersistent)
  private
    FInfo     : TSongInfo;          // ファイル情報
    FTempos   : TSongTempoList;     // テンポ管理リスト
    FBeats    : TSongTempoList;     // 拍子管理リスト
    FNotes    : TSongNoteList;      // 全ノート（一次元）
    FTracks   : TSongTrackList;     // トラック別ノート
    // 内部データを全消去
    procedure Clear;
    // 一次元ノートをトラック別構造へ変換
    procedure NotesToTrack();
    // テンポから拍子を作成
    procedure TempoToBeat();
    function GetLengthSec: Double;
  public
    // SongData 初期化
    constructor Create;
    // SongData 解放
    destructor Destroy;override;
    procedure Assign(Source : TPersistent);override;
    // 音楽ファイルを解析して読み込む入口
    function LoadFromMusicFile(const FileName: string) : Boolean;
    // 内部保存形式から読み込み
    procedure LoadFromFile(const FileName: string);
    procedure LoadFromStrings(t : TStringList);
    // 内部保存形式で書き出し
    procedure SaveToFile(const FileName: string);
    procedure SaveToStrings(t : TStringList);

    property Info   : TSongInfo      read FInfo;
    property Notes  : TSongNoteList  read FNotes;
    property Tracks : TSongTrackList read FTracks;
    property Tempos : TSongTempoList read FTempos;
    property Beats  : TSongTempoList read FBeats;
    property LengthSec : Double read GetLengthSec;
  end;

implementation

uses SongReaderSMF,SongReaderVSQX,SongReaderUST,SongReaderMusicXML,SectionFileManager,
     SongReaderMusicMSCZ,SongReaderManager;

{ TSongData }

constructor TSongData.Create;
begin
  FInfo   := TSongInfo.Create;
  FTempos := TSongTempoList.Create();
  FBeats  := TSongTempoList.Create();
  FNotes  := TSongNoteList.Create;
  FTracks := TSongTrackList.Create;
end;

destructor TSongData.Destroy;
begin
  FTracks.Free;
  FNotes.Free;
  FBeats.Free;
  FTempos.Free;
  FInfo.Free;
  inherited;
end;

procedure TSongData.Assign(Source: TPersistent);
var
  Src : TSongData;
begin
  Clear;
  if not (Source is TSongData) then begin
    inherited Assign(Source);
    Exit;
  end;

  Src := TSongData(Source);
  FInfo.Division := Src.FInfo.Division;
  FNotes.Assign(src.FNotes);
  FTracks.Assign(src.FTracks);
  FTempos.Assign(src.FTempos);
end;

procedure TSongData.Clear;
begin
  FBeats.Clear;
  FTempos.Clear;
  FNotes.Clear;
  FTracks.Clear;
end;

procedure TSongData.NotesToTrack;
var
  i,j : Integer;
  note,prev : TSongNoteItem;
  track : TSongTrackItem;
  dics  : TSongAIUEO;
begin
  FTracks.Clear;
  FInfo.LengthSec := 0.0;
  dics := TSongAIUEO.Create;
  try
    for j := 0 to FNotes.Count-1 do begin
      note := FNotes[j];
      if FInfo.LengthSec < note.EndSec then begin
        FInfo.LengthSec := note.EndSec;     // 曲の長さを計算
      end;
      i :=FTracks.IndexOfTrack(note.TrackIndex);
      if i = -1 then begin
        track := FTracks.AddNew();
        track.TrackIndex := note.TrackIndex;
      end
      else begin
        track := FTracks[i];
      end;
      track.Notes.Add(note);
      if track.Notes.Count > 1 then begin
        prev := track.Notes[track.Notes.Count-2];
        if note.StartSec - prev.EndSec < 0.1 then begin
          note.PrevNote := prev;
          note.PrevCnt  := prev.PrevCnt + 1;
        end;
      end;
      //dics.LyricToAIUEO(note);
    end;
    for j := 0 to FTracks.Count-1 do begin
      track := FTracks[j];
      track.NoteToLyric(dics);
      track.LyricToAiueo(dics);
    end;
    FInfo.LengthSec :=  FInfo.LengthSec + 0.0;     // 曲の長さに余韻を追加

  finally
    dics.Free;
  end;
end;

function TSongData.GetLengthSec: Double;
begin
  Result := FInfo.LengthSec;
end;

// 音楽ファイルを解析して内部データへ読み込む
// ReaderManager に解析を委譲し、その後内部構造へ変換する
// 解析失敗時の厳密制御は将来 Reader の戻り値統一後に行う
function TSongData.LoadFromMusicFile(const FileName: string): Boolean;
var
  Manager: TSongReaderManager;
begin
  Clear;                                      // 既存データを初期化

  Manager := TSongReaderManager.Create;       // 解析統括用 Manager 生成
  try
    Result := Manager.Load(FileName, Self);   // 拡張子判定→Reader生成→解析実行
    // if not Result then Exit;               // 戻り値統一後に有効化予定
  finally
    Manager.Free;                             // Manager 破棄
  end;

  NotesToTrack;                               // 一次元ノート→トラック構造へ変換
  TempoToBeat;                                // テンポ情報から拍子リスト生成
end;

procedure TSongData.TempoToBeat;
var
  i ,idx      : Integer;
  smax, sStart,sEnd,s,stepSec : Double;
  noteEndMax  : Double;
  note        : TSongNoteItem;
  tempo,next,beat   : TSongTempoItem;
begin
  // 曲の最大秒（ノート終端 + 余韻を下限として保証）
  noteEndMax := 0.0;
  for i := 0 to FNotes.Count - 1 do begin
    note := FNotes[i];
    if note.EndSec > noteEndMax then noteEndMax := note.EndSec;
  end;
  smax := noteEndMax + 10.0;
  if LengthSec > smax then smax := LengthSec;
  if FInfo.LengthSec < smax then FInfo.LengthSec := smax;

  FBeats.Clear;
  idx := 0;

  // テンポが無い場合は既定テンポ(120 BPM)で拍線を生成
  if FTempos.Count = 0 then begin
    stepSec := 0.5; // 500000 usec / quarter
    s := 0.0;
    while s < smax do
    begin
      beat := FBeats.AddNew;
      beat.Sec   := s;
      beat.Delta := -1;
      beat.Tempo := 500000;
      beat.Index := idx;
      Inc(idx);
      s := s + stepSec;
    end;
    Exit;
  end;

  for i := 0 to FTempos.Count - 1 do
  begin
    tempo := FTempos[i];

    // このテンポ区間の開始秒
    sStart := tempo.Sec;

    // このテンポ区間の終了秒
    if i < FTempos.Count - 1 then
    begin
      next  := FTempos[i + 1];
      sEnd  := next.Sec;
    end
    else begin
      sEnd := smax;
    end;

    // 念のためのガード
    if sStart >= smax then Break;

    if sEnd > smax then sEnd := smax;

    // 1拍（四分音符）の秒数
    // Tempo は μsec per quarter
    stepSec := tempo.Tempo / 1000000.0;

    // Beat 生成
    s := sStart;
    while s < sEnd do
    begin
      beat := FBeats.AddNew;
      beat.Sec   := s;
      beat.Delta := -1;      // Delta は不要／後処理で必要なら算出
      beat.Tempo := tempo.Tempo; // 参考保持（不要なら削除可）
      beat.Index := idx;
      Inc(idx);
      s := s + stepSec;
    end;
  end;
end;
procedure TSongData.LoadFromStrings(t: TStringList);
var
  ts : TStringList;
  ms : TSectionFileManager;
begin
  Clear;
  ms := TSectionFileManager.Create;
  try
    if t = nil then Exit;
    ms.LoadFromStrings(t);

    ts := ms.GetSection('Info');
    if ts <> nil then FInfo.LoadInfo(ts);

    ts := ms.GetSection('Note');
    if ts <> nil then FNotes.LoadFromStrings(ts);

    ts := ms.GetSection('Track');
    if ts <> nil then FTracks.LoadFromStrings(ts);

    ts := ms.GetSection('Tempo');
    if ts <> nil then FTempos.LoadFromStrings(ts);

    ts := ms.GetSection('Beat');
    if ts <> nil then FBeats.LoadFromStrings(ts);

    NotesToTrack;          // 一次元ノートデータをトラック別に参照
    TempoToBeat;           // テンポから拍子を作成
  finally
    ms.Free;
  end;
end;


procedure TSongData.LoadFromFile(const FileName: string);
var
  ts : TStringList;
begin
  Clear;
  ts := TStringList.Create;
  try
    if not FileExists(FileName) then Exit;
    ts.LoadFromFile(FileName);
    LoadFromStrings(ts);
  finally
    ts.Free;
  end;
end;


procedure TSongData.SaveToStrings(t: TStringList);
var
  ts : TStringList;
  ms : TSectionFileManager;
begin
  ms := TSectionFileManager.Create;
  ts := TStringList.Create;
  try
    ts.Clear;
    FInfo.SaveInfo(ts);
    ms.AddSection('Info',ts);

    ts.Clear;
    FNotes.SaveToStrings(ts);
    ms.AddSection('Note',ts);

    ts.Clear;
    FTracks.SaveToStrings(ts);
    ms.AddSection('Track',ts);

    ts.Clear;
    FTempos.SaveToStrings(ts);
    ms.AddSection('Tempo',ts);

    ts.Clear;
    FBeats.SaveToStrings(ts);
    ms.AddSection('Beat',ts);

    ms.SaveToStrings(t);
  finally
    ms.Free;
    ts.Free;
  end;
end;

procedure TSongData.SaveToFile(const FileName: string);
var
  ts : TStringList;
begin
  ts := TStringList.Create;
  try
    SaveToStrings(ts);
    ts.SaveToFile(FileName,TEncoding.UTF8);
  finally
    ts.Free;
  end;
end;



end.

