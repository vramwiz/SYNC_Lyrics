unit SongReader;

// 音楽ファイル形式ごとの読込器に共通する抽象インターフェースを定義する。

interface

uses
  SysUtils, Classes,SongData;

type
  // 解析基底クラス
  TSongReader = class
  public
    function LoadFromFile(const FileName: string; SongData: TSongData) : Boolean; virtual; abstract;
  end;

  TSongReaderClass = class of TSongReader;

implementation

end.
