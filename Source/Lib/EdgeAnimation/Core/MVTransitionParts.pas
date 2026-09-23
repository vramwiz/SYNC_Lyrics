unit MVTransitionParts;

// 登場・退場を動きと見え方へ分類し、旧複合IDを2要素へ読み替える。SDKの状態は保持しない。
interface

uses MVAnimationTypes;

const
  MV_TRANSITION_INHERIT = -1; // ホストの旧項目に保存された要素を引き継ぐ。0の「なし」と区別する。

type
  TMVTransitionPartKind = (mtpMotion, mtpVisibility);
  TMVTransitionParts = record
    MotionID: Integer; // 位置・回転・拡縮・字間だけを評価する固定ID。
    VisibilityID: Integer; // 不透明度・ぼかし・クリップ・模様だけを評価する固定ID。
  end;

// 分類ごとの選択肢数。「引き継ぐ」はホストUIが別に追加する。
function MVTransitionPartCount(Kind: TMVTransitionPartKind): Integer;
// 表示順から固定IDと名前を返す。評価関数の出力は合成側で担当要素だけを取り出す。
function MVTransitionPartAt(Kind: TMVTransitionPartKind; Index: Integer): TMVAnimationDescriptor;
// 引継ぎ指定または公開中の要素IDかを確認する。異なる分類のIDは拒否する。
function IsMVTransitionPartID(Kind: TMVTransitionPartKind; ID: Integer): Boolean;
// 旧IDを分解してから明示指定の要素を上書きする。旧方向別IDも同じ種類へ読み替える。
function ResolveMVTransitionParts(LegacyID, MotionID, VisibilityID: Integer): TMVTransitionParts;
// どちらかの要素が有効なら所要時間と文字遅延を使用する。
function HasMVTransitionParts(LegacyID, MotionID, VisibilityID: Integer): Boolean;

implementation

uses System.SysUtils, MVAnimationCatalog;

const
  MotionIDs: array[0..20] of Integer = (0, 2, 3, 4, 5, 7, 8, 15, 16, 17, 18, 26, 27, 29, 30, 31, 32, 33, 37, 38, 39);
  VisibilityIDs: array[0..8] of Integer = (0, 1, 9, 10, 24, 34, 35, 36, 6); // 文字送りも見え方として単独指定できる。

function MVTransitionPartCount(Kind: TMVTransitionPartKind): Integer;
begin
  if Kind = mtpMotion then Result := Length(MotionIDs) else Result := Length(VisibilityIDs);
end;

function MVTransitionPartAt(Kind: TMVTransitionPartKind; Index: Integer): TMVAnimationDescriptor;
var ID: Integer;
begin
  if (Index < 0) or (Index >= MVTransitionPartCount(Kind)) then
    raise EArgumentOutOfRangeException.Create('演出要素の一覧位置が範囲外です。');
  if Kind = mtpMotion then ID := MotionIDs[Index] else ID := VisibilityIDs[Index];
  if not FindMVAnimation(makTransition, ID, Result) then
    raise EArgumentException.Create('演出要素がカタログへ登録されていません。');
end;

function IsMVTransitionPartID(Kind: TMVTransitionPartKind; ID: Integer): Boolean;
var Candidate: Integer;
begin
  if ID = MV_TRANSITION_INHERIT then Exit(True);
  if Kind = mtpMotion then
  begin
    for Candidate in MotionIDs do if ID = Candidate then Exit(True);
  end
  else
    for Candidate in VisibilityIDs do if ID = Candidate then Exit(True);
  Result := False;
end;

function ResolveMVTransitionParts(LegacyID, MotionID, VisibilityID: Integer): TMVTransitionParts;
var Direction: Integer;
begin
  Direction := 0;
  NormalizeMVDirection(LegacyID, Direction, False);
  Result := Default(TMVTransitionParts);
  case LegacyID of
    1, 6, 9, 10, 24, 34, 35, 36: Result.VisibilityID := LegacyID;
    28:
      begin
        Result.MotionID := 2;
        // 従来のぼかしスライドは通常ぼかしより弱い。内部評価だけで元の係数を維持する。
        Result.VisibilityID := 28;
      end;
  else
    if (LegacyID <> 0) and IsMVTransitionPartID(mtpMotion, LegacyID) then
    begin
      Result.MotionID := LegacyID;
      Result.VisibilityID := 1;
    end;
  end;
  if MotionID <> MV_TRANSITION_INHERIT then Result.MotionID := MotionID;
  if VisibilityID <> MV_TRANSITION_INHERIT then Result.VisibilityID := VisibilityID;
end;

function HasMVTransitionParts(LegacyID, MotionID, VisibilityID: Integer): Boolean;
var Parts: TMVTransitionParts;
begin
  Parts := ResolveMVTransitionParts(LegacyID, MotionID, VisibilityID);
  Result := (Parts.MotionID <> 0) or (Parts.VisibilityID <> 0);
end;

end.
