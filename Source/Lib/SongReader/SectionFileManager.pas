unit SectionFileManager;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  {------------------------------------------------------------
    セクション 1 件を表すクラス
  ------------------------------------------------------------}
  TSectionItem = class
  private
    FName: string;
    FStrings: TStringList;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;

    property Name: string read FName;
    property Strings: TStringList read FStrings;
  end;

  {------------------------------------------------------------
    セクションファイル全体を管理するクラス
  ------------------------------------------------------------}
  TSectionFileManager = class
  private
    FSections: TObjectList<TSectionItem>;
    FTempList: TStringList;   // GetSection 用 作業バッファ

    FLeftBracket: string;     // 可変セパレータ（左）
    FRightBracket: string;    // 可変セパレータ（右）

    function FindSection(const SectionName: string): TSectionItem;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Clear;

    procedure AddSection(const SectionName: string; Values: TStringList);
    function GetSection(const SectionName: string): TStringList;

    procedure LoadFromFile(const FileName: string);
    procedure SaveToFile(const FileName: string);

    procedure LoadFromStrings(SL : TStringList);
    procedure SaveToStrings(SL : TStringList);

    { セパレータ設定 }
    procedure SetBrackets(const ALeft, ARight: string);

    property LeftBracket: string read FLeftBracket write FLeftBracket;
    property RightBracket: string read FRightBracket write FRightBracket;
  end;

implementation

{============================================================
  TSectionItem
============================================================}

constructor TSectionItem.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FStrings := TStringList.Create;
end;

destructor TSectionItem.Destroy;
begin
  FStrings.Free;
  inherited;
end;

{============================================================
  TSectionFileManager
============================================================}

constructor TSectionFileManager.Create;
begin
  inherited Create;
  FSections := TObjectList<TSectionItem>.Create(True); // 所有権あり
  FTempList := TStringList.Create;                     // 返却用バッファ

  // 初期値: 従来通りの [ ]
  FLeftBracket := '[';
  FRightBracket := ']';
end;

destructor TSectionFileManager.Destroy;
begin
  FSections.Free;
  FTempList.Free;
  inherited;
end;

procedure TSectionFileManager.Clear;
begin
  FSections.Clear;
  FTempList.Clear;
end;

{------------------------------------------------------------
  セクション名検索（大文字小文字は区別しない）
------------------------------------------------------------}
function TSectionFileManager.FindSection(const SectionName: string): TSectionItem;
var
  Item: TSectionItem;
begin
  Result := nil;
  for Item in FSections do
  begin
    if SameText(Item.Name, SectionName) then
      Exit(Item);
  end;
end;

{------------------------------------------------------------
  セクション追加（既存は上書き、返値なし）
------------------------------------------------------------}
procedure TSectionFileManager.AddSection(const SectionName: string; Values: TStringList);
var
  Item: TSectionItem;
begin
  Item := FindSection(SectionName);

  if Item = nil then
  begin
    Item := TSectionItem.Create(SectionName);
    FSections.Add(Item);
  end;

  Item.Strings.Assign(Values);
end;

{------------------------------------------------------------
  セクション取得（内部バッファにコピーして返す）
------------------------------------------------------------}
function TSectionFileManager.GetSection(const SectionName: string): TStringList;
var
  Item: TSectionItem;
begin
  FTempList.Clear;

  Item := FindSection(SectionName);
  if Item = nil then
    Exit(nil);

  FTempList.Assign(Item.Strings);
  Result := FTempList;
end;

{------------------------------------------------------------
  LoadFromFile（内部構造の構築のみ）
------------------------------------------------------------}
procedure TSectionFileManager.LoadFromFile(const FileName: string);
var
  SL: TStringList;
begin
  Clear;
  if not FileExists(FileName) then Exit;

  SL := TStringList.Create;
  try
    SL.LoadFromFile(FileName, TEncoding.UTF8);
    LoadFromStrings(SL);
  finally
    SL.Free;
  end;
end;

procedure TSectionFileManager.LoadFromStrings(SL : TStringList);
var
  S: string;            // 読み取り用
  Line: string;         // 処理用
  CurItem: TSectionItem;
  LLen, RLen: Integer;
begin
  Clear();
  CurItem := nil;

  LLen := Length(FLeftBracket);
  RLen := Length(FRightBracket);

  for S in SL do
  begin
    Line := Trim(S);

    { セクション開始判定（可変セパレータ対応） }
    if (Line <> '') and
       Line.StartsWith(FLeftBracket) and
       Line.EndsWith(FRightBracket) then
    begin
      CurItem := TSectionItem.Create(
        Copy(Line, LLen + 1, Length(Line) - LLen - RLen)
      );
      FSections.Add(CurItem);
    end
    else
    begin
      if CurItem <> nil then
        CurItem.Strings.Add(Line);
    end;
  end;
end;

{------------------------------------------------------------
  SaveToFile（UTF-8 BOM・空行なし）
------------------------------------------------------------}
procedure TSectionFileManager.SaveToFile(const FileName: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SaveToStrings(SL);
    SL.SaveToFile(FileName, TEncoding.UTF8);
  finally
    SL.Free;
  end;
end;

procedure TSectionFileManager.SaveToStrings(SL : TStringList);
var
  Item: TSectionItem;
begin
  for Item in FSections do
  begin
    SL.Add(FLeftBracket + Item.Name + FRightBracket);
    SL.AddStrings(Item.Strings);
  end;
end;

{------------------------------------------------------------
  セパレータをまとめて設定するメソッド
------------------------------------------------------------}
procedure TSectionFileManager.SetBrackets(const ALeft, ARight: string);
begin
  FLeftBracket := ALeft;
  FRightBracket := ARight;
end;

end.

