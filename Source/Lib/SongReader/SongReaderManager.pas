unit SongReaderManager;

interface

uses
  SysUtils, Classes, Generics.Collections,
  SongReader, SongData;

// 拡張子と対応する Reader クラスを保持する要素クラス
// Manager 内部でのみ使用される登録情報コンテナ
type
  TSongReaderItem = class
  public
    Ext: string;                           // 対応する拡張子（小文字で保持）
    ReaderClass: TSongReaderClass;         // 生成対象となる Reader クラス
  end;

// Reader 登録情報を管理するリストクラス
// 拡張子から対応する ReaderClass を検索する
  TSongReaderList = class(TObjectList<TSongReaderItem>)
  public
    // 拡張子から対応 Reader クラスを取得
    function FindReaderClass(const Ext: string): TSongReaderClass;
  end;

// 音楽ファイル解析を統括する Manager クラス
// 拡張子判定・Reader生成・実行・破棄を担当する
  TSongReaderManager = class
  private
    FReaderList: TSongReaderList;           // 拡張子と Reader の対応表
    // 拡張子と Reader クラスを登録
    procedure RegisterExt(const Ext: string; ReaderClass: TSongReaderClass);
    // 拡張子から対応 Reader クラスを取得
    function GetReaderClass(const Ext: string): TSongReaderClass;

  public
    // 登録テーブルを構築
    constructor Create;
    // 登録テーブルを解放
    destructor Destroy; override;
    // ファイル解析を実行
    function Load(const FileName: string; SongData: TSongData): Boolean;
  end;

implementation

uses
  SongReaderSMF, SongReaderVSQX, SongReaderUST,
  SongReaderMusicXML, SongReaderMusicMSCZ, SongReaderMusicMSC;

{ TSongReaderList }

function TSongReaderList.FindReaderClass(const Ext: string): TSongReaderClass;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if SameText(Items[i].Ext, Ext) then
      Exit(Items[i].ReaderClass);
end;

{ TSongReaderManager }

// 拡張子と Reader 対応表を構築
constructor TSongReaderManager.Create;
begin
  FReaderList := TSongReaderList.Create(True); // 所有権ありリスト
  RegisterExt('.mid', TSongReaderSMF);
  RegisterExt('.midi', TSongReaderSMF);
  RegisterExt('.ust', TSongReaderUST);
  RegisterExt('.vsq', TSongReaderVSQX);
  RegisterExt('.vsqx', TSongReaderVSQX);
  RegisterExt('.musicxml', TSongReaderMusicXML);
  RegisterExt('.mxl', TSongReaderMusicXML);
  RegisterExt('.xml', TSongReaderMusicXML);
  RegisterExt('.mscx', TSongReaderMusicMSCX);
  RegisterExt('.mscz', TSongReaderMusicMSCZ);
end;

// 登録テーブルを解放
destructor TSongReaderManager.Destroy;
begin
  FReaderList.Free; // 登録情報解放
  inherited;
end;

// 拡張子と Reader クラスを登録
procedure TSongReaderManager.RegisterExt(const Ext: string; ReaderClass: TSongReaderClass);
var
  Item: TSongReaderItem;
begin
  Item := TSongReaderItem.Create;
  Item.Ext := LowerCase(Ext); // 小文字で統一
  Item.ReaderClass := ReaderClass;
  FReaderList.Add(Item);
end;

// 拡張子から対応 Reader クラスを取得
function TSongReaderManager.GetReaderClass(const Ext: string): TSongReaderClass;
begin
  Result := FReaderList.FindReaderClass(LowerCase(Ext)); // 小文字比較
end;

// 拡張子判定→Reader生成→解析実行
function TSongReaderManager.Load(const FileName: string; SongData: TSongData): Boolean;
var
  Ext: string;
  ReaderClass: TSongReaderClass;
  Reader: TSongReader;
begin
  Result := False;
  Ext := LowerCase(ExtractFileExt(FileName)); // 拡張子取得
  ReaderClass := GetReaderClass(Ext);
  if ReaderClass = nil then Exit; // 未対応形式
  Reader := ReaderClass.Create;
  try
    Result := Reader.LoadFromFile(FileName, SongData); // 実解析の成否を伝える
  finally
    Reader.Free; // Reader破棄
  end;
end;

end.
