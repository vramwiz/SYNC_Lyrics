unit MVTransitionExtended;

// バウンス・フリップ・ぼかし・ワイプの値を計算する。描画APIは呼ばない。
interface

uses MVAnimationTypes;

// 減衰する跳ね返りで基準位置へ着地する。退場時は軌道を逆にたどる。
procedure MVBounce(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 方向に対応した軸の倍率で倒れた状態を表す疑似フリップ。文字を裏返さない。
procedure MVFlip(var Motion: TMVMotion; const Input: TMVAnimationInput);
// フェードとともに焦点を合わせる／外す。ぼかしの実描画は描画層へ委ねる。
procedure MVBlur(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 指定側から露出し、退場は指定側へ表示範囲を縮めるワイプ。
procedure MVWipe(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math, MVTransitionTiming;

procedure MVBounce(var Motion: TMVMotion; const Input: TMVAnimationInput);
var P: Double;
begin
  P := Input.Progress;
  if Input.Leaving then P := 1 - P;
  SetMVDirectedOffset(Motion, Input.Direction, Input.Amount * (1 - MVBounceProgress(P)));
  Motion.Opacity := MVTransitionVisibility(Input);
end;

procedure MVFlip(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  if Input.Direction in [madUp, madDown] then Motion.ScaleY := Sin(Pi * Visible / 2)
  else Motion.ScaleX := Sin(Pi * Visible / 2);
  Motion.Opacity := Visible;
end;

procedure MVBlur(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  Motion.Opacity := MVTransitionVisibility(Input);
  Motion.BlurSigma := Min(40.0, Input.Amount * 0.2) * (1 - Motion.Opacity);
end;

procedure MVWipe(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  case Input.Direction of
    madLeft: Motion.ClipRight := Visible;
    madRight: Motion.ClipLeft := 1 - Visible;
    madUp: Motion.ClipBottom := Visible;
    madDown: Motion.ClipTop := 1 - Visible;
  end;
end;

end.
