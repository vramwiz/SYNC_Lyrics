unit MVTransitionTiming;

// 登場・退場の進み方を短い文章で選ぶカタログ。固定IDと時刻だけで曲線を評価する。
interface

const
  MV_TIMING_DEFAULT = 0; // 種類ごとの従来の緩急を保つ。旧文書の既定値。

// 固定IDを0から順に並べた選択肢数。項目の削除・並べ替えでIDを再利用しない。
function MVTimingCount: Integer;
// 固定IDに対応する文章。未知IDは既定項目の名前を返す。
function MVTimingName(ID: Integer): string;
// 保存・ホスト値に使える固定IDか確認する。
function IsMVTimingID(ID: Integer): Boolean;
// 経過割合Pを進行へ写す。始点0・終点1を厳密に保ち、引きや行き過ぎは範囲外を返す。
// ID=0は入力を返し、種類側の従来の曲線を残す。その他は共通の平滑化を重ねない。
function EvaluateMVTiming(ID: Integer; P: Double): Double;
// 減衰する跳ね返り。既存バウンスと動き方の両方で同じ曲線を使う。
// 0..1の外側は直線で延長し、別の曲線による引き・行き過ぎを保持する。
function MVBounceProgress(P: Double): Double;

implementation

uses System.Math;

const
  TimingNames: array[0..18] of string = (
    '演出に合わせる',
    '一定の速さで進む',
    'ゆっくり動き出す',
    '勢いよく動き出す',
    'ゆっくり始まり、ゆっくり止まる',
    'ぐっと加速する',
    'すっと減速する',
    'なめらかに加速して減速する',
    '少し待って動き出す',
    '早めに動いて余韻を残す',
    '一度引いてから進む',
    '少し行き過ぎて戻る',
    '大きく行き過ぎて戻る',
    '一度跳ねて止まる',
    '何度か跳ねて止まる',
    'バネのように揺れて止まる',
    '小刻みに震えながら進む',
    '途中で一度止まる',
    'コマ送りで進む'
  );

function MVTimingCount: Integer;
begin
  Result := Length(TimingNames);
end;

function IsMVTimingID(ID: Integer): Boolean;
begin
  Result := (ID >= 0) and (ID < Length(TimingNames));
end;

function MVTimingName(ID: Integer): string;
begin
  if IsMVTimingID(ID) then Result := TimingNames[ID]
  else Result := TimingNames[MV_TIMING_DEFAULT];
end;

function Smooth(P: Double): Double;
begin
  Result := P * P * (3 - 2 * P);
end;

function BackOut(P, Strength: Double): Double;
var Q: Double;
begin
  Q := P - 1;
  Result := 1 + (Strength + 1) * Q * Q * Q + Strength * Q * Q;
end;

function MVBounceProgress(P: Double): Double;
const N = 7.5625; D = 2.75;
begin
  if (P < 0) or (P > 1) then Exit(P);
  if P < 1 / D then Result := N * P * P
  else if P < 2 / D then begin P := P - 1.5 / D; Result := N * P * P + 0.75; end
  else if P < 2.5 / D then begin P := P - 2.25 / D; Result := N * P * P + 0.9375; end
  else begin P := P - 2.625 / D; Result := N * P * P + 0.984375; end;
end;

function EvaluateMVTiming(ID: Integer; P: Double): Double;
var Q: Double;
begin
  if IsNan(P) or IsInfinite(P) or (P <= 0) then Exit(0);
  if P >= 1 then Exit(1);
  case ID of
    2: Result := Sqr(P);
    3: Result := 1 - Sqr(1 - P);
    4: Result := Smooth(P);
    5: Result := Sqr(Sqr(P));
    6: Result := 1 - Sqr(Sqr(1 - P));
    7: Result := P * P * P * (P * (6 * P - 15) + 10);
    8:
      if P <= 0.2 then Result := 0
      else Result := Smooth((P - 0.2) / 0.8);
    9:
      if P >= 0.7 then Result := 1
      else
      begin
        Q := 1 - P / 0.7;
        Result := 1 - Q * Q * Q;
      end;
    10: Result := P * P * (2.7 * P - 1.7);
    11: Result := BackOut(P, 1.4);
    12: Result := BackOut(P, 3);
    13:
      if P <= 0.6 then Result := Sqr(P / 0.6)
      else
      begin
        Q := (P - 0.6) / 0.4;
        Result := 1 - 0.8 * Q * (1 - Q);
      end;
    14: Result := MVBounceProgress(P);
    15: Result := 1 - Sqr(Sqr(1 - P)) * Cos(4 * Pi * P);
    16: Result := P + 0.08 * Sin(12 * Pi * P) * Sin(Pi * P);
    17:
      if P < 0.4 then Result := 0.5 * Smooth(P / 0.4)
      else if P <= 0.6 then Result := 0.5
      else Result := 0.5 + 0.5 * Smooth((P - 0.6) / 0.4);
    18: Result := Floor(P * 6) / 6;
  else
    Result := P;
  end;
end;

end.
