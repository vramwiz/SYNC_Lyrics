unit SongDataInfo;

interface

uses
  Windows, Messages, SysUtils, Classes,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistentIni,SongAIUEO;


type
  TSongInfo = class(TRTTIPersistentIni)
  private
    FDivision           : Integer;          // ticks per quarter（PPQ）
    FTimeSigNumerator   : Integer;
    FTimeSigDenominator : Integer;
    FLengthSec          : Double;
    FFileName           : string;
    FLab                : string;
  public
    // 基本情報を読み込み
    procedure LoadInfo(ts : TStringList);
    // 基本情報を保存
    procedure SaveInfo(ts : TStringList);

  published
    property Division : Integer read FDivision write FDivision;
    property TimeSigNumerator : Integer read FTimeSigNumerator write FTimeSigNumerator;
    property TimeSigDenominator : Integer read FTimeSigDenominator write FTimeSigDenominator;
    property LengthSec : Double read FLengthSec write FLengthSec;
    property Lab : string read FLab write FLab;
    property FileName : string read FFileName write FFileName;
  end;



implementation

uses SectionFileManager;


{ TSongInfo }

procedure TSongInfo.LoadInfo(ts: TStringList);
var
  t : TStringList;
  ms : TSectionFileManager;
begin
  ms := TSectionFileManager.Create;
  try
    ms.SetBrackets('{','}');
    ms.LoadFromStrings(ts);
    t := ms.GetSection('Root');
    if t = nil then Exit;
    DeserializeFromStrings(Self,t);
  finally
    ms.Free;
  end;
end;

procedure TSongInfo.SaveInfo(ts: TStringList);
var
  t : TStringList;
  ms : TSectionFileManager;
begin
  ms := TSectionFileManager.Create;
  t := TStringList.Create;
  try
    ms.SetBrackets('{','}');
    SerializeToStrings(Self,t);
    ms.AddSection('Root',t);
    ms.SaveToStrings(ts);
  finally
    ms.Free;
    t.Free;
  end;
end;

end.
