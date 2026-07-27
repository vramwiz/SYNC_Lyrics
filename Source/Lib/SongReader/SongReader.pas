unit SongReader;

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
