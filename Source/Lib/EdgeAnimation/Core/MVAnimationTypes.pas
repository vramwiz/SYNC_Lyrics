unit MVAnimationTypes;

// 演出の入力と描画への出力を定義する。文書・SDK・Skiaの状態は保持しない。
interface

type
  TMVAnimationKind = (makTransition, makHold);
  TMVAnimationDirection = (madUp, madDown, madLeft, madRight);
  TMVAnimationMask = (mamNone, mamBlinds, mamDissolve);

  TMVMotion = record
    X, Y: Single; // 配置へ加える出力座標の移動量。
    Scale: Single; // 配置へ乗算する共通倍率。
    ScaleX, ScaleY: Single; // フリップ等で使う軸別の追加倍率。
    Angle: Single; // 配置へ加える回転角度。
    Opacity: Single; // 0..1の描画不透明度。
    BlurSigma: Single; // 文字画像のローカル座標でのぼかし標準偏差。
    ClipLeft, ClipRight: Single; // 文字矩形内で表示する横方向の範囲。0..1。
    ClipTop, ClipBottom: Single; // 文字矩形内で表示する縦方向の範囲。0..1。
    Tracking: Single; // 行中央を基準に文字間へ加える出力ピクセル数。文字画像の幅は変えない。
    Mask: TMVAnimationMask; // 文字画像内の部分表示。描画層が形状を作る。
    MaskVisibility: Single; // 部分表示の進行。0で非表示、1で全体表示。
    MaskDirection: TMVAnimationDirection; // ブラインドの各帯を露出／収縮する側。
    EffectSeed: Integer; // 文字順から決まる模様。乱数生成器の状態を使わない。
    GlitchAmount: Single; // 帯ごとの横ずれ幅。文字画像のローカルピクセル単位。
    GlitchStep: Integer; // 現在時刻から求めた模様の切替番号。
  end;

  TMVAnimationInput = record
    Progress: Double; // 曲線適用後の進行。開始0・終了1だが、引き・行き過ぎは範囲外にもなる。
    CustomTiming: Boolean; // Trueなら選んだ曲線を使用済み。共通の平滑化を重ねない。
    Phase: Double; // 表示中演出のラジアン位相。過去のフレームには依存しない。
    Envelope: Double; // 登場・退場の端で表示中の振幅を弱める0..1の係数。
    Amount: Double; // ホストが指定した演出の強さ。
    Strength: Double; // 状態別の強さ倍率。表示中の固定振幅や連続回転にも適用する。
    CurveAmount: Double; // 軌道演出の進行軸に直交する膨らみ。出力ピクセル単位。
    UnitIndex: Integer; // フレーズ内の文字順序。波の位相等に用いる。
    Leaving: Boolean; // Trueは退場、Falseは登場。
    Direction: TMVAnimationDirection; // 登場元・退場先。軸だけを使う演出は上下を縦、左右を横とする。
  end;

  TMVEvaluateAnimation = procedure(var Motion: TMVMotion; const Input: TMVAnimationInput);

  TMVAnimationDescriptor = record
    ID: Integer; // 保存済み値との互換性を保つ固定ID。並べ替え時も変更しない。
    Name: string; // AviUtl2の選択肢へ公開する名前。
    Evaluate: TMVEvaluateAnimation; // 状態を保持しない計算処理。なし・静止はnil。
  end;

// 静止表示と同じ出力を返す。新しい乗算項目はここで初期化する。
function DefaultMVMotion: TMVMotion;
// 登場・退場の進行を基準状態への到達割合にする。行き過ぎは保持し、描画範囲は評価後に制限する。
function MVTransitionVisibility(const Input: TMVAnimationInput): Double;
// 方向パラメータの固定値に対応する表示名を返す。
function MVAnimationDirectionName(Direction: TMVAnimationDirection): string;
// 指定方向に沿う移動量を設定する。使用しない軸は0へ戻す。
procedure SetMVDirectedOffset(var Motion: TMVMotion; Direction: TMVAnimationDirection; Distance: Double);
// 上下または左右で反対側の方向を返す。
function OppositeMVDirection(Direction: TMVAnimationDirection): TMVAnimationDirection;
// 方向を保存していない旧文書で、従来の演出に対応する方向値を返す。
function LegacyMVDirection(EffectID: Integer; Leaving: Boolean): Integer;
// 旧方向別IDを共通の種類と独立した方向値へ変換する。
// 他の演出IDと方向値には触れず、旧IDは今後も別の演出に再利用しない。
procedure NormalizeMVDirection(var EffectID, Direction: Integer; Leaving: Boolean);

implementation

function MVAnimationDirectionName(Direction: TMVAnimationDirection): string;
const Names: array[TMVAnimationDirection] of string = ('上', '下', '左', '右');
begin
  Result := Names[Direction];
end;

procedure SetMVDirectedOffset(var Motion: TMVMotion; Direction: TMVAnimationDirection; Distance: Double);
begin
  Motion.X := 0;
  Motion.Y := 0;
  case Direction of
    madUp: Motion.Y := -Distance;
    madDown: Motion.Y := Distance;
    madLeft: Motion.X := -Distance;
    madRight: Motion.X := Distance;
  end;
end;

function OppositeMVDirection(Direction: TMVAnimationDirection): TMVAnimationDirection;
const Opposite: array[TMVAnimationDirection] of TMVAnimationDirection = (madDown, madUp, madRight, madLeft);
begin
  Result := Opposite[Direction];
end;

function LegacyMVDirection(EffectID: Integer; Leaving: Boolean): Integer;
begin
  if Leaving then Result := Ord(madUp) else Result := Ord(madDown);
  case EffectID of
    8, 18, 24, 27: Result := Ord(madLeft);
    10: if Leaving then Result := Ord(madRight) else Result := Ord(madLeft);
  end;
end;

procedure NormalizeMVDirection(var EffectID, Direction: Integer; Leaving: Boolean);
begin
  case EffectID of
    11..14:
      begin
        case EffectID of
          11: Direction := Ord(madLeft);
          12: Direction := Ord(madRight);
          13: Direction := Ord(madUp);
          14: Direction := Ord(madDown);
        end;
        EffectID := 2;
      end;
    19: begin EffectID := 18; Direction := Ord(madUp); end;
    20: begin EffectID := 8; Direction := Ord(madUp); end;
    21..23:
      begin
        case EffectID of
          21: Direction := Ord(madRight);
          22: Direction := Ord(madUp);
          23: Direction := Ord(madDown);
        end;
        if Leaving then Direction := Ord(OppositeMVDirection(TMVAnimationDirection(Direction)));
        EffectID := 10;
      end;
    25: begin EffectID := 24; Direction := Ord(madUp); end;
  end;
end;

function DefaultMVMotion: TMVMotion;
begin
  Result := Default(TMVMotion);
  Result.Scale := 1;
  Result.ScaleX := 1;
  Result.ScaleY := 1;
  Result.Opacity := 1;
  Result.ClipRight := 1;
  Result.ClipBottom := 1;
  Result.MaskVisibility := 1;
end;

function MVTransitionVisibility(const Input: TMVAnimationInput): Double;
begin
  if Input.CustomTiming then Result := Input.Progress
  else Result := Input.Progress * Input.Progress * (3 - 2 * Input.Progress);
  if Input.Leaving then Result := 1 - Result;
end;

end.
