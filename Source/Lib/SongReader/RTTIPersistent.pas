unit RTTIPersistent;
{
******************************************************************************

  Unit Name : RTTIPersistentLib
  Purpose   : TPersistent 派生オブジェクトのRTTIベース保存・復元支援ユーティリティ

  概要：
    このユニットは、TPersistent を継承したオブジェクトに対し、RTTI を用いて
    プロパティの保存・復元処理を簡略化するためのクラス群を提供します。
    具体的には、INIファイルなどへの保存／読込、フォームの表示位置保存、
    ジェネリックなオブジェクトリストの永続化などに対応しています。

  主なクラス：
    - TRTTIPersistent       : RTTI による Assign 処理の基底クラス
    - TRTTIPersistentIni    : ファイル保存・読込機能を追加したクラス
    - TRTTIFormPosition     : フォームの位置（Left/Top）を保存・復元
    - TRTTIFormBounds       : 上記に加えてサイズ・WindowState を保存・復元
    - TRTTIPersistentIniList<T> : オブジェクトのリストをファイルで保存・読込

******************************************************************************
}

interface

uses
  Windows, Messages, SysUtils, Classes,   Forms, Dialogs,
  StdCtrls, ExtCtrls,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults;


type
	TRTTIPersistent = class(TPersistent)
	private
		{ Private 宣言 }
    // 指定された PPropInfo を用いて Source から Dest にプロパティの値をコピーする
    procedure CopyPropValue(Dest, Source: TObject; Prop: PPropInfo);
  protected
    // 指定されたプロパティが書き込み可能か
    function PropIsWritable(Prop: PPropInfo): Boolean;virtual;
	public
		{ Public 宣言 }
    procedure Assign(Source : TPersistent);override;
	end;


implementation

uses System.DateUtils;



{ TRTTIPersistent }

procedure TRTTIPersistent.Assign(Source: TPersistent);
var
  i: Integer;
  Info: PTypeInfo;
  Data: PTypeData;
  Props: PPropList;
  Prop: PPropInfo;
begin
  if not (Source is TRTTIPersistent) then
  begin
    inherited Assign(Source);
    Exit;
  end;

  Info := Self.ClassInfo;
  Data := GetTypeData(Info);
  GetMem(Props, Data^.PropCount * SizeOf(PPropInfo));
  try
    GetPropInfos(Info, Props);
    for i := 0 to Data^.PropCount - 1 do
    begin
      Prop := Props^[i];

      // プロパティが保存対象かつ書き込み可能であることを確認
      if not IsStoredProp(Source, Prop) then  Continue;
      if not PropIsWritable(Prop)       then  Continue;
      // プロパティ値の代入処理
      CopyPropValue(Self, Source, Prop);
    end;
  finally
    FreeMem(Props);
  end;
end;


function TRTTIPersistent.PropIsWritable(Prop: PPropInfo): Boolean;
begin
  Result := Assigned(Prop) and Assigned(Prop^.SetProc);
end;

procedure TRTTIPersistent.CopyPropValue(Dest, Source: TObject; Prop: PPropInfo);
var
  Kind: TTypeKind;
  SourceObj,DestObj: TObject;
begin
  if not Assigned(Prop) or not Assigned(Prop^.GetProc) or not Assigned(Prop^.SetProc) then
    Exit;

  Kind := Prop^.PropType^.Kind;

  case Kind of
    tkInteger, tkChar, tkEnumeration, tkSet:
      SetOrdProp(Dest, Prop, GetOrdProp(Source, Prop));

    tkFloat:
      SetFloatProp(Dest, Prop, GetFloatProp(Source, Prop));

    tkString, tkLString, tkUString, tkWString:
      SetStrProp(Dest, Prop, GetStrProp(Source, Prop));

    tkInt64:
      SetInt64Prop(Dest, Prop, GetInt64Prop(Source, Prop));

    tkClass:
      begin
        // クラス型の場合は再帰的な Assign を試みる
        SourceObj := GetObjectProp(Source, Prop);
        DestObj   := GetObjectProp(Dest, Prop);
        if (SourceObj is TPersistent) and (DestObj is TPersistent) then
          TPersistent(DestObj).Assign(TPersistent(SourceObj))
        else
          SetObjectProp(Dest, Prop, SourceObj);  // 単純参照コピー
      end;

    // 他の型（tkMethod, tkVariantなど）は基本的に無視
  end;
end;



end.
