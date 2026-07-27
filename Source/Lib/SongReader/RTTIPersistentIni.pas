{
******************************************************************************

  Unit Name : RTTIPersistentIni
  Purpose   : TPersistent 派生オブジェクトのRTTIベース保存・復元支援ユーティリティ

  概要：
    このユニットは、TPersistent を継承したオブジェクトに対し、RTTI を用いて
    プロパティの保存・復元処理を簡略化するためのクラス群を提供します。
    具体的には、INIファイルなどへの保存／読込、フォームの表示位置保存、
    ジェネリックなオブジェクトリストの永続化などに対応しています。

  主なクラス：
    - TRTTIPersistent       : RTTI による Assign 処理の基底クラス
    - TRTTIPersistentIni    : ファイル保存・読込機能を追加したクラス

******************************************************************************
}

unit RTTIPersistentIni;

interface

uses
  Windows, Messages, SysUtils, Classes,   Forms, Dialogs,System.DateUtils,
  StdCtrls, ExtCtrls,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,System.IOUtils,RTTIPersistent;

//--------------------------------------------------------------------------//
//  基本データ保存クラス                                                    //
//--------------------------------------------------------------------------//
type
	TRTTIPersistentIni = class(TRTTIPersistent)
	private
		{ Private 宣言 }
    FFilename     : string;        // 読み書きするファイル名
    FFileDateTime : TDateTime;     // 読み書きするファイルの更新日時
    // InstanceをIni形式でシリアライズ化して Destに出力
    function EscapeValueString(const Value: string): string;
    // \n, \=, \;, \\ を元の文字列に戻す
    function UnescapeValueString(const Value: string): string;
    function TryLoadText(SL: TStringList; const FileName: string): Boolean;
    // ISO8601 や一般的な日付文字列から TDateTime へ安全に変換する
    function TryParseDateTimeFromString(const S: string; out V: TDateTime): Boolean;
    // ロケールに依存しない方法で浮動小数値をパースする（小数点は常に .）
    function TryParseFloatInvariant(const S: string; out V: Double): Boolean;
  protected
	public
		{ Public 宣言 }
    // ファイル読み込み
    function LoadFromFile() : Boolean;virtual;
    // ファイル保存
    function SaveToFile() : Boolean;virtual;
    // True:ファイルが更新された
    function IsFileUpdated : Boolean;

    procedure SerializeToStrings(Instance: TPersistent; Dest: TStrings);virtual;
    // Ini形式の文字列リストからInstanceに入力
    // INIファイルで誤解される特殊文字を適切にエスケープ する
    procedure DeserializeFromStrings(Instance: TPersistent; const Src: TStrings);virtual;
    // 指定したクラスを xx=vvとして扱いやすい文字列で返す
    function SerializeToText(Instance: TPersistent): string; virtual;
    // 上記の関数で保存した文字列から復元
    procedure DeserializeFromText(Instance: TPersistent; const Text: string); virtual;

    // 読み込みや保存に使用するファイル名
    property Filename : string read FFilename write FFilename;
	end;

  // オブジェクトリストを使ったIniファイル管理
type
  TRTTIPersistentIniList<T: TRTTIPersistentIni, constructor> = class(TObjectList<T>)
  private
    FFilename     : string;        // 読み書きするファイル名
    FFileDateTime : TDateTime;     // 読み書きするファイルの更新日時
    FLeftBracket  : string;        // 可変セパレータ（左）
    FRightBracket : string;        // 可変セパレータ（右）
    function TryLoadText(SL: TStringList; const FileName: string): Boolean;
  protected
    procedure DoSaveSection(ItemSL : TStringList);virtual;
    procedure DoLoadSection(ItemSL : TStringList);virtual;
  public
    constructor Create; overload;
    constructor Create(AOwnsObjects: Boolean); overload;
    procedure Assign(Source: TObjectList<T>);
    // 要素追加
    function AddNew: T;virtual;
    // 要素挿入
    function InsertNew(Index: Integer): T;virtual;
    // 要素削除
    procedure DeleteItem(Item: T);
    // 要素入れ替え
    procedure Exchange(Index1, Index2: Integer);
    // 並び替える
    procedure Sort(const AComparer: TComparison<T>);
    // ファイル読み込み
    procedure LoadFromFile; virtual;
    // 文字列リストから読み込み
    procedure LoadFromStrings(const Src: TStringList);virtual;
    // ファイル保存
    procedure SaveToFile;virtual;
    // 文字列リストに保存
    procedure SaveToStrings(const Dest: TStringList);virtual;
    // True:ファイルが更新された
    function IsFileUpdated : Boolean;
    // 指定したクラスを xx=vvとして扱いやすい文字列で返す
    function SerializeToText(): string; virtual;
    // 上記の関数で保存した文字列から復元
    procedure DeserializeFromText(const Text: string); virtual;
    // セパレータ設定
    procedure SetBrackets(const ALeft, ARight: string);

    // 読み込みや保存に使用するファイル名
    property Filename: string read FFilename write FFilename;
  end;

  // リストを使ったIniファイル管理
type
  TRTTIPersistentIniListEx = class(TList)

	private
		{ Private 宣言 }
  protected
    FFilename: string;
    function DoCreate() : TRTTIPersistentIni;virtual;
    function TryLoadText(SL: TStringList; const FileName: string): Boolean;
    procedure DoSaveSection(ItemSL : TStringList);virtual;
    procedure DoLoadSection(ItemSL : TStringList);virtual;
	public
		{ Public 宣言 }
    procedure Assign(Source: TRTTIPersistentIniListEx);
    // 要素追加
    function AddNew() : TRTTIPersistentIni;virtual;
    // 要素挿入
    function InsertNew(const Index : Integer) : TRTTIPersistentIni;virtual;
    // 文字列リストから読み込み
    procedure LoadFromStrings(const Src: TStringList);
    // ファイル読み込み
    procedure LoadFromFile;virtual;
    // 文字列リストに保存
    procedure SaveToStrings(const Dest: TStringList);
    // ファイル保存
    procedure SaveToFile;virtual;
    // 指定したクラスを xx=vvとして扱いやすい文字列で返す
    function SerializeToText(): string; virtual;
    // 上記の関数で保存した文字列から復元
    procedure DeserializeFromText(const Text: string); virtual;

    // 読み込みや保存に使用するファイル名
    property Filename: string read FFilename write FFilename;
	end;

implementation


uses SectionFileManager;


{ TRTTIPersistentIni }


function TRTTIPersistentIni.LoadFromFile() : Boolean;
var
  SL: TStringList;
begin
  Result := False;
  if not FileExists(FFilename) then Exit;

  SL := TStringList.Create;
  try
    if TryLoadText(SL,FFilename) then
      DeserializeFromStrings(Self, SL);
    Result := True;
  finally
    SL.Free;
  end;
  FFileDateTime := TFile.GetLastWriteTime(FFilename);  // ファイルの日時を取得
end;

function TRTTIPersistentIni.SaveToFile() : Boolean;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SerializeToStrings(Self, SL);                   // 自身をシリアライズ化
    SL.SaveToFile(FFilename, TEncoding.UTF8);       // 明示的に UTF-8 で保存
    Result := True;
  finally
    SL.Free;
  end;
  FFileDateTime := TFile.GetLastWriteTime(FFilename);  // ファイルの日時を取得
end;


procedure TRTTIPersistentIni.SerializeToStrings(Instance: TPersistent;
  Dest: TStrings);
var
  ctx: TRttiContext;
  typ: TRttiInstanceType; // ← 型を明示的にキャスト;
  prop: TRttiProperty;
  val: TValue;
  tmpSL: TStringList;
  s: string;
begin
  ctx := TRttiContext.Create;
  try
    typ := ctx.GetType(Instance.ClassType) as TRttiInstanceType;
    for prop in typ.GetProperties do
    begin
      // Published以外はは除外
      if prop.Visibility <> mvPublished then Continue;
      if not prop.IsReadable or not prop.IsWritable then Continue;
      val := prop.GetValue(Instance);

      case prop.PropertyType.TypeKind of
        tkInteger, tkFloat, tkEnumeration,
        tkChar, tkWChar, tkString, tkLString, tkWString, tkUString:
          Dest.Add(prop.Name + '=' + TRTTIPersistentIni(Instance).EscapeValueString(val.ToString));

        tkClass:
          if val.IsObject and (val.AsObject is TPersistent) then
          begin
            tmpSL := TStringList.Create;
            try
              {
              if val.AsObject is TRTTIPersistentIni then
                SerializeToStrings(TRTTIPersistentIni(val.AsObject), tmpSL) // 再帰！
              else
                SerializeToStrings(TPersistent(val.AsObject), tmpSL); // 汎用変換
              }
              SerializeToStrings(TPersistent(val.AsObject), tmpSL); // 再帰！
              s := tmpSL.Text;
              s := TRTTIPersistentIni(Instance).EscapeValueString(s);
              Dest.Add(prop.Name + '=' + s);
            finally
              tmpSL.Free;
            end;
          end;
      end;
    end;
  finally
    ctx.Free;
  end;
end;

function TRTTIPersistentIni.SerializeToText(Instance: TPersistent): string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    // 既存のシリアライズ処理をそのまま利用
    SerializeToStrings(Instance, SL);
    // 複数行テキストとしてまとめて返す
    Result := EscapeValueString(SL.Text);
  finally
    SL.Free;
  end;
end;

function TRTTIPersistentIni.TryLoadText(SL: TStringList;
  const FileName: string): Boolean;
begin
  Result := False;

  if not FileExists(FileName) then
    Exit;

  try
    SL.LoadFromFile(FileName, TEncoding.UTF8);
    Result := True;
  except
    on E: Exception do
      OutputDebugString(PChar('UTF-8 読み込み失敗: ' + E.Message));
  end;

  if not Result then
  begin
    try
      SL.LoadFromFile(FileName, TEncoding.Default); // fallback: Shift-JISなど
      Result := True;
      OutputDebugString('Shift-JIS で再読み込み成功');
    except
      on E: Exception do
        OutputDebugString(PChar('Shift-JIS 読み込みも失敗: ' + E.Message));
    end;
  end;
end;

function TRTTIPersistentIni.TryParseDateTimeFromString(const S: string;
  out V: TDateTime): Boolean;
var
  Temp: TDateTime;
begin
  Result := False;
  V := 0;

  if Trim(S) = '' then Exit;

  // 1. Invariant 形式でパース（例: '2025/05/16 11:58:46' なども対応）
  Result := TryStrToDateTime(S, Temp, TFormatSettings.Invariant);

  // 2. ローカルロケール（日本など）
  if not Result then
    Result := TryStrToDateTime(S, Temp);

  // 3. ISO8601（2025-05-16T11:58:46 など）
  if not Result then
    Result := TryISO8601ToDate(S, Temp, True);

  if Result then
    V := Temp;
end;

function TRTTIPersistentIni.TryParseFloatInvariant(const S: string;
  out V: Double): Boolean;
begin
  // 初期化
  Result := False;
  V := 0;

  // 空文字列は即失敗
  if Trim(S) = '' then
    Exit;

  // Invariant（ロケール非依存、"." を小数点とみなす）
  Result := TryStrToFloat(S, V, TFormatSettings.Invariant);
end;

procedure TRTTIPersistentIni.DeserializeFromStrings(Instance: TPersistent;
  const Src: TStrings);
var
  ctx       : TRttiContext;
  typ: TRttiInstanceType; // ← 型を明示的にキャスト;
  prop      : TRttiProperty;
  I, P      : Integer;
  Line      : string;
  Key       : string;
  ValueStr  : string;
  Kind      : TTypeKind;
  SubObj    : TObject;
  tmpSL     : TStringList;
  EnumVal   : Integer;
  FloatValue: Double;
  DateValue : TDateTime;
begin
  ctx := TRttiContext.Create;
  try
    typ := ctx.GetType(Instance.ClassType) as TRttiInstanceType;

    for I := 0 to Src.Count - 1 do
    begin
      Line := Trim(Src[I]);
      if Line = '' then Continue;

      P := Pos('=', Line);
      if P <= 0 then Continue;

      Key := Trim(Copy(Line, 1, P - 1));
      ValueStr := Copy(Line, P + 1, MaxInt);
      ValueStr := TRTTIPersistentIni(Instance).UnescapeValueString(ValueStr);

      prop := typ.GetProperty(Key);
      if (prop = nil) or (not prop.IsWritable) then Continue;

      Kind := prop.PropertyType.TypeKind;

      case Kind of
        tkInteger:
          prop.SetValue(Instance, StrToIntDef(ValueStr, 0));

        tkInt64:
          prop.SetValue(Instance, StrToInt64Def(ValueStr, 0));

        tkFloat:
        begin
          //prop.SetValue(Instance, StrToFloatDef(ValueStr, 0));
          if prop.PropertyType.Handle = TypeInfo(TDateTime) then
          begin
            if TryParseDateTimeFromString(ValueStr, DateValue) then
              prop.SetValue(Instance, DateValue);
          end
          else
          begin
            if TryParseFloatInvariant(ValueStr, FloatValue) then
              prop.SetValue(Instance, FloatValue);
          end;
        end;

        tkEnumeration:
          begin
            EnumVal := GetEnumValue(prop.PropertyType.Handle, ValueStr);
            if EnumVal <> -1 then
              prop.SetValue(Instance, TValue.FromOrdinal(prop.PropertyType.Handle, EnumVal));
          end;

        tkChar, tkWChar, tkString, tkLString, tkWString, tkUString:
          prop.SetValue(Instance, ValueStr);

        tkClass:
          begin
            SubObj := prop.GetValue(Instance).AsObject;
            if Assigned(SubObj) and (SubObj is TPersistent) then
            begin
              tmpSL := TStringList.Create;
              try
                tmpSL.Text := ValueStr;
                DeserializeFromStrings(TPersistent(SubObj), tmpSL); // 再帰！
              finally
                tmpSL.Free;
              end;
            end;
          end;
      end;
    end;

  finally
    ctx.Free;
  end;
end;

procedure TRTTIPersistentIni.DeserializeFromText(Instance: TPersistent;  const Text: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    // Text をそのまま文字列リスト化
    SL.Text := UnescapeValueString(Text);

    // 既存の複数行読み込みロジックに丸投げ
    DeserializeFromStrings(Instance, SL);

  finally
    SL.Free;
  end;
end;

function TRTTIPersistentIni.EscapeValueString(const Value: string): string;
var
  i: Integer;
  ch: Char;
begin
  Result := '';
  for i := 1 to Length(Value) do
  begin
    ch := Value[i];
    case ch of
      '&': Result := Result + '&&';   // エスケープ文字
      '=': Result := Result + '&e';   // key=value の誤認防止
      ',': Result := Result + '&c';   // 改行をテキスト化するときに使われる, の誤認防止
      #9 : Result := Result + '&t';   // TABの変換
      #13: Result := Result + '&n';   // 改行 → \n
      #10: Result := Result + '&a';   // 改行 → \a
    else
      Result := Result + ch;
    end;
  end;
end;

function TRTTIPersistentIni.IsFileUpdated: Boolean;
begin
  if FFileDateTime = 0 then Exit(True);
  if not FileExists(FFilename) then Exit(False);
  Result := TFile.GetLastWriteTime(FFilename) <> FFileDateTime;
end;

function TRTTIPersistentIni.UnescapeValueString(const Value: string): string;
var
  i: Integer;
  f : Boolean; // 旧形式互換用
  ch: Char;
begin
  Result := '';
  i := 1;
  f := Pos('\\',Value) <> 0;

  while i <= Length(Value) do
  begin
    ch := Value[i];

    if (ch = '\') and f then
    begin
      Inc(i);
      if i > Length(Value) then
        Break;

      case Value[i] of                                        // 互換性用将来不要
        'a': Result := Result + #10;  // 改行
        'n': Result := Result + #13;  // 改行
        '=': Result := Result + '=';  // イコール
        ';': Result := Result + ';';  // セミコロン
        '\': Result := Result + '\';  // バックスラッシュ
        '[': Result := Result + '[';  // セクション開始文字
        ']': Result := Result + ']';  // セクション終了文字
        '{': Result := Result + '{';  // セクション開始文字
        '}': Result := Result + '}';  // セクション終了文字
        ',': Result := Result + ',';  // カンマ
        '&': Result := Result + '&';  // アンパサンド
      else
        // 不明なエスケープ：そのまま出力（既存仕様維持）
        Result := Result + '\' + Value[i];
      end;
    end
    else if ch = '&' then
    begin
      Inc(i);
      if i > Length(Value) then
        Break;

      case Value[i] of
        'a': Result := Result + #10;  // 改行
        'n': Result := Result + #13;  // 改行
        'e': Result := Result + '=';  // イコール
        'c': Result := Result + ',';  // イコール
        't': Result := Result + #9;  // タブ
        '&': Result := Result + '&';  // アンパサンド
      else
        // 不明なエスケープ：そのまま出力（既存仕様維持）
        Result := Result + '&' + Value[i];
      end;
    end
    else
      Result := Result + ch;

    Inc(i);
  end;
end;

{ TRTTIPersistentIniList<T> }

function TRTTIPersistentIniList<T>.AddNew: T;
begin
  Result := T.Create; // ← ここがポイント：GenericsのT型をインスタンス化
  Add(Result);        // TObjectList<T> に追加（このクラス自体がTObjectList<T>を継承している）
end;

procedure TRTTIPersistentIniList<T>.Assign(Source: TObjectList<T>);
var
  SrcList: TRTTIPersistentIniList<T>;
  i: Integer;
  Src, Dst: T;
begin
  if Source is TRTTIPersistentIniList<T> then
  begin
    SrcList := TRTTIPersistentIniList<T>(Source);
    Clear;
    for i := 0 to SrcList.Count - 1 do
    begin
      Src := SrcList[i];
      Dst := T.Create;
      Dst.Assign(Src); // ← T が TRTTIPersistentIni を継承しているため可
      Add(Dst);
    end;
  end
  else
    inherited; // 念のため
end;

constructor TRTTIPersistentIniList<T>.Create;
begin
  Create(True);
end;

constructor TRTTIPersistentIniList<T>.Create(AOwnsObjects: Boolean);
begin
  inherited Create(AOwnsObjects);
  // 初期値: 従来通りの [ ]
  FLeftBracket := '[';
  FRightBracket := ']';
end;

procedure TRTTIPersistentIniList<T>.DeleteItem(Item: T);
var
  i: Integer;
begin
  i := IndexOf(Item);
  if i >= 0 then
    Delete(i);
end;

procedure TRTTIPersistentIniList<T>.Exchange(Index1, Index2: Integer);
var
  TempOwns: Boolean;
  Temp: T;
begin
  if (Index1 < 0) or (Index1 >= Count) then Exit;
  if (Index2 < 0) or (Index2 >= Count) then Exit;
  if Index1 = Index2 then Exit;

  TempOwns := OwnsObjects;
  OwnsObjects := False;
  try
    Temp := Items[Index1];
    Items[Index1] := Items[Index2];
    Items[Index2] := Temp;
  finally
    OwnsObjects := TempOwns;
  end;
end;

function TRTTIPersistentIniList<T>.InsertNew(Index: Integer): T;
begin
  Result := T.Create;
  Insert(Index, Result);  // TObjectList<T> の Insert を呼ぶ
end;

function TRTTIPersistentIniList<T>.IsFileUpdated: Boolean;
begin
  if FFileDateTime = 0 then Exit(True);
  if not FileExists(FFilename) then Exit(False);
  Result := TFile.GetLastWriteTime(FFilename) <> FFileDateTime;
end;

procedure TRTTIPersistentIniList<T>.LoadFromFile;
var
  SL: TStringList;
begin
  if not FileExists(FFilename) then Exit;

  SL := TStringList.Create;
  try
    if not TryLoadText(SL, FFilename) then  Exit;
    LoadFromStrings(SL);   // 文字列リストとして読み込む
    FFileDateTime := TFile.GetLastWriteTime(FFilename);  // ファイルの日時を取得
  finally
    SL.Free;
  end;
end;


procedure TRTTIPersistentIniList<T>.LoadFromStrings(const Src: TStringList);
var
  SecMgr : TSectionFileManager;
  SL     : TStringList;
  i      : Integer;
  Item   : T;
begin
  Clear;

  SecMgr := TSectionFileManager.Create;
  try
    SecMgr.SetBrackets(FLeftBracket,FRightBracket);
    SecMgr.LoadFromStrings(Src);

    { Root 読み込み }
    SL := SecMgr.GetSection('Root');
    if SL <> nil then DoLoadSection(SL);

    { Item 読み込み }
    i := 0;
    while i < 9999 do
    begin
      SL := SecMgr.GetSection(IntToStr(i));
      if SL = nil then Break;

      Item := AddNew;
      Item.DeserializeFromStrings(Item, SL);

      Inc(i);
    end;

  finally
    SecMgr.Free;
  end;
end;


procedure TRTTIPersistentIniList<T>.SaveToFile;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    SaveToStrings(SL);                          // 関数を呼ぶ
    if FFilename = '' then Exit;
    SL.SaveToFile(FFilename, TEncoding.UTF8);   // 書き込みだけ担当
  finally
    SL.Free;
  end;
  FFileDateTime := TFile.GetLastWriteTime(FFilename);  // ファイルの日時を取得
end;


procedure TRTTIPersistentIniList<T>.SaveToStrings(const Dest: TStringList);
var
  SecMgr  : TSectionFileManager;
  ItemSL  : TStringList;
  i       : Integer;
  Item    : T;
begin
  Dest.Clear;

  SecMgr := TSectionFileManager.Create;
  ItemSL := TStringList.Create;
  try
    SecMgr.SetBrackets(FLeftBracket,FRightBracket);

    { Root セクション }
    ItemSL.Clear;

    DoSaveSection(ItemSL);
    SecMgr.AddSection('Root', ItemSL);

    { 各要素 }
    for i := 0 to Count - 1 do
    begin
      Item := Items[i];

      ItemSL.Clear;
      Item.SerializeToStrings(Item, ItemSL);

      SecMgr.AddSection(IntToStr(i), ItemSL);
    end;

    { 出力 }
    SecMgr.SaveToStrings(Dest);

  finally
    ItemSL.Free;
    SecMgr.Free;
  end;
end;


procedure TRTTIPersistentIniList<T>.DeserializeFromText(const Text: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    // Text をそのまま文字列リスト化
    SL.Text := Text;

    // 既存の複数行読み込みロジックに丸投げ
    LoadFromStrings(SL);

  finally
    SL.Free;
  end;
end;

procedure TRTTIPersistentIniList<T>.DoLoadSection(ItemSL: TStringList);
begin

end;

procedure TRTTIPersistentIniList<T>.DoSaveSection(ItemSL: TStringList);
begin

end;

function TRTTIPersistentIniList<T>.SerializeToText: string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    // 既存のシリアライズ処理をそのまま利用
    SaveToStrings(SL);
    // 複数行テキストとしてまとめて返す
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TRTTIPersistentIniList<T>.SetBrackets(const ALeft, ARight: string);
begin
 FLeftBracket  := ALeft;
 FRightBracket := ARight;
end;

procedure TRTTIPersistentIniList<T>.Sort(const AComparer: TComparison<T>);
begin
  inherited Sort(TComparer<T>.Construct(AComparer));
end;

function TRTTIPersistentIniList<T>.TryLoadText(SL: TStringList;
  const FileName: string): Boolean;
begin
  Result := False;

  if not FileExists(FileName) then
    Exit;

  try
    SL.LoadFromFile(FileName, TEncoding.UTF8);
    Result := True;
  except
    on E: Exception do
      OutputDebugString(PChar('UTF-8 読み込み失敗: ' + E.Message));
  end;

  if not Result then
  begin
    try
      SL.LoadFromFile(FileName, TEncoding.Default); // fallback: Shift-JISなど
      Result := True;
      OutputDebugString('Shift-JIS で再読み込み成功');
    except
      on E: Exception do
        OutputDebugString(PChar('Shift-JIS 読み込みも失敗: ' + E.Message));
    end;
  end;
end;

{ TRTTIPersistentIniListEx }

procedure TRTTIPersistentIniListEx.Assign(Source: TRTTIPersistentIniListEx);
begin
  if Source is TRTTIPersistentIniListEx then
  begin
    DeserializeFromText(Source.SerializeToText);
  end;
end;


function TRTTIPersistentIniListEx.AddNew: TRTTIPersistentIni;
var
  item : TRTTIPersistentIni;
begin
  item := DoCreate();              // 下位クラスで生成
  inherited Add(item);
  Result := item;
end;

function TRTTIPersistentIniListEx.DoCreate: TRTTIPersistentIni;
begin
  Result := TRTTIPersistentIni.Create;
end;

procedure TRTTIPersistentIniListEx.DoLoadSection(ItemSL: TStringList);
begin

end;

procedure TRTTIPersistentIniListEx.DoSaveSection(ItemSL: TStringList);
begin

end;

function TRTTIPersistentIniListEx.InsertNew(
  const Index: Integer): TRTTIPersistentIni;
var
  item : TRTTIPersistentIni;
begin
  item := DoCreate();              // 下位クラスで生成
  inherited Insert(Index,item);
  Result := item;
end;

procedure TRTTIPersistentIniListEx.LoadFromFile;
var
  SL: TStringList;
begin
  if not FileExists(FFilename) then
    Exit;

  SL := TStringList.Create;
  try
    if not TryLoadText(SL, FFilename) then
      Exit;

    LoadFromStrings(SL);   // 文字列リストとして読み込む
  finally
    SL.Free;
  end;
end;

procedure TRTTIPersistentIniListEx.LoadFromStrings(const Src: TStringList);
var
  SecMgr : TSectionFileManager;
  SL     : TStringList;
  i      : Integer;
  Item   : TRTTIPersistentIni;
begin
  Clear;

  SecMgr := TSectionFileManager.Create;
  try
    SecMgr.LoadFromStrings(Src);

    { Root 読み込み }
    SL := SecMgr.GetSection('Root');
    if SL <> nil then DoLoadSection(SL);

    { Item 読み込み }
    i := 0;
    while i < 9999 do
    begin
      SL := SecMgr.GetSection(IntToStr(i));
      if SL = nil then Break;

      Item := AddNew;
      Item.DeserializeFromStrings(Item, SL);

      Inc(i);
    end;

  finally
    SecMgr.Free;
  end;
end;


procedure TRTTIPersistentIniListEx.SaveToFile;
var
  SL: TStringList;
begin
  if Filename='' then Exit;

  SL := TStringList.Create;
  try
    SaveToStrings(SL);                          // 関数を呼ぶ
    SL.SaveToFile(FFilename, TEncoding.UTF8);   // 書き込みだけ担当
  finally
    SL.Free;
  end;
end;

procedure TRTTIPersistentIniListEx.SaveToStrings(const Dest: TStringList);
var
  SecMgr : TSectionFileManager;
  ItemSL : TStringList;
  i      : Integer;
  Item   : TRTTIPersistentIni;
begin
  Dest.Clear;

  SecMgr := TSectionFileManager.Create;
  ItemSL := TStringList.Create;
  try

    { Root セクション }
    ItemSL.Clear;
    DoSaveSection(ItemSL);
    SecMgr.AddSection('Root', ItemSL);

    { 各要素 }
    for i := 0 to Count - 1 do
    begin
      Item := Items[i];

      ItemSL.Clear;
      Item.SerializeToStrings(Item, ItemSL);

      SecMgr.AddSection(IntToStr(i), ItemSL);
    end;

    { 出力 }
    SecMgr.SaveToStrings(Dest);

  finally
    ItemSL.Free;
    SecMgr.Free;
  end;
end;

function TRTTIPersistentIniListEx.SerializeToText(): string;
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    // 既存のシリアライズ処理をそのまま利用
    SaveToStrings(SL);
    // 複数行テキストとしてまとめて返す
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

procedure TRTTIPersistentIniListEx.DeserializeFromText(const Text: string);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  try
    // Text をそのまま文字列リスト化
    SL.Text := Text;

    // 既存の複数行読み込みロジックに丸投げ
    LoadFromStrings(SL);

  finally
    SL.Free;
  end;
end;

function TRTTIPersistentIniListEx.TryLoadText(SL: TStringList;
  const FileName: string): Boolean;
begin
  Result := False;

  if not FileExists(FileName) then
    Exit;

  try
    SL.LoadFromFile(FileName, TEncoding.UTF8);
    Result := True;
  except
    on E: Exception do
      OutputDebugString(PChar('UTF-8 読み込み失敗: ' + E.Message));
  end;

  if not Result then
  begin
    try
      SL.LoadFromFile(FileName, TEncoding.Default); // fallback: Shift-JISなど
      Result := True;
      OutputDebugString('Shift-JIS で再読み込み成功');
    except
      on E: Exception do
        OutputDebugString(PChar('Shift-JIS 読み込みも失敗: ' + E.Message));
    end;
  end;
end;



end.
