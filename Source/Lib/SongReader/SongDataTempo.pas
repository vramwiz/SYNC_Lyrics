unit SongDataTempo;

interface

uses
  Windows, Messages, SysUtils, Classes,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistentIni,SongAIUEO,SongDataNote;

type
  TSongTempoItem = class(TRTTIPersistentIni)
  private
    FDelta  : Integer; // 絶対Tick値
    FSec    : Double;  // このDelta時点の絶対秒
    FTempo  : Double;  // μsec per quarter
    FIndex: Integer;   // 拍子に使用するときのインデックス
  published
    property Delta : Integer read FDelta write FDelta;
    property Tempo : Double read FTempo write FTempo;
    property Sec   : Double  read FSec   write FSec;
    property Index : Integer read FIndex write FIndex;
  end;

type
  TSongTempoList = class(TRTTIPersistentIniList<TSongTempoItem>)
  private
    function GetTempos(Index: Integer): TSongTempoItem; // Items アクセサ
  public
    // テンポ変更イベントを登録し絶対秒を算出
    procedure AddTempo(Delta : Integer;Tempo : Double;Division: Integer);
    // 任意Deltaから秒数へ変換
    function DeltaToSec(Delta,Division: Integer): Double;
    // テンポ情報を読み込み
    procedure LoadFromStrings(ts : TStringList); reintroduce;
    // テンポ情報を保存
    procedure SaveToStrings(ts : TStringList); reintroduce;
    property Tempos[Index: Integer]: TSongTempoItem read GetTempos; default;
  end;


implementation

uses SectionFileManager;



{ TSongTempoList }

procedure TSongTempoList.AddTempo(Delta : Integer;Tempo : Double;Division: Integer);
var
  Item,Prev : TSongTempoItem;
  DeltaDiff : Integer;
begin
  Item := AddNew();
  Item.Delta := Delta;
  Item.Tempo := Tempo;

  if Count = 1 then begin
    // 最初の実テンポ
    Item.Sec := 0.0;
  end
  else
  begin
    Prev :=  Items[Count-2];
    DeltaDiff := Delta - Prev.Delta;
    Item.Sec :=
      Prev.Sec +
      (DeltaDiff / Division) * (Prev.Tempo / 1_000_000);
  end;
end;

function TSongTempoList.DeltaToSec(Delta,Division: Integer): Double;
var
  I       : Integer;
  Item    : TSongTempoItem;
  Prev    : TSongTempoItem;
  DeltaDiff: Integer;
  UseTempo: Double;
  UseSec  : Double;
begin
  Prev := nil;

  for I := 0 to Count - 1 do
  begin
    Item := Items[I];
    if Item.Delta > Delta then
      Break;
    Prev := Item;
  end;

  if Prev = nil then
  begin
    // 実テンポがまだ無い → 初期テンポ保険
    UseTempo := 500000;
    UseSec   := 0.0;
    DeltaDiff := Delta;
  end
  else
  begin
    UseTempo := Prev.Tempo;
    UseSec   := Prev.Sec;
    DeltaDiff := Delta - Prev.Delta;
  end;

  Result :=
    UseSec +
    (DeltaDiff / Division) * (UseTempo / 1_000_000);
end;


function TSongTempoList.GetTempos(Index: Integer): TSongTempoItem;
begin
  Result := inherited Items[Index];
end;



procedure TSongTempoList.LoadFromStrings(ts: TStringList);
var
  j : Integer;
  t : TStringList;
  ms : TSectionFileManager;
  Tempo : TSongTempoItem;
begin
  ms := TSectionFileManager.Create;
  try
    ms.SetBrackets('{','}');
    ms.LoadFromStrings(ts);
    j := 0;
    while j < 9999 do begin
      t := ms.GetSection(IntToStr(j));
      if t = nil then break;
      Tempo := AddNew();
      Tempo.DeserializeFromStrings(Tempo,t);
      inc(j);
    end;
  finally
    ms.Free;
  end;
end;

procedure TSongTempoList.SaveToStrings(ts: TStringList);
var
  j : Integer;
  t : TStringList;
  ms : TSectionFileManager;
  Tempo : TSongTempoItem;
begin
  ms := TSectionFileManager.Create;
  t := TStringList.Create;
  try
    ms.SetBrackets('{','}');
    for j := 0 to Count-1 do begin
      Tempo := Tempos[j];
      t.Clear;
      Tempo.SerializeToStrings(Tempo,t);
      ms.AddSection(IntToStr(j),t);
    end;
    ms.SaveToStrings(ts);
  finally
    ms.Free;
    t.Free;
  end;
end;

end.
