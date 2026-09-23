unit MVTransitionBasic;

// 基本の登場・退場演出。種類ごとの軌道と透明度を計算する。
interface

uses MVAnimationTypes;

// 滑らかな不透明度変化を適用する。
procedure MVFade(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 独立した方向パラメータから登場元・退場先を決め、移動とフェードを適用する。
procedure MVSlide(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 小さな状態との間を拡縮し、フェードを併用する。
procedure MVZoom(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 一度膨らむ倍率変化とフェードを適用する。
procedure MVPop(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 傾いた状態との間を回転し、フェードを併用する。
procedure MVTurn(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 文字ごとの表示を切り替える。順送り時刻は共通評価側で決める。
procedure MVTypeOn(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

procedure MVFade(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  Motion.Opacity := MVTransitionVisibility(Input);
end;

procedure MVSlide(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Distance: Double;
begin
  MVFade(Motion, Input);
  Distance := Input.Amount * (1 - Motion.Opacity);
  SetMVDirectedOffset(Motion, Input.Direction, Distance);
end;

procedure MVZoom(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  MVFade(Motion, Input);
  Motion.Scale := 1 - 0.8 * (1 - Motion.Opacity);
end;

procedure MVPop(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  MVFade(Motion, Input);
  Motion.Scale := Motion.Opacity + 0.25 * Sin(Pi * Input.Progress);
end;

procedure MVTurn(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  MVFade(Motion, Input);
  Motion.Angle := -45 * (1 - Motion.Opacity);
end;

procedure MVTypeOn(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  if Input.Leaving then Motion.Opacity := Ord(Input.Progress < 1)
  else Motion.Opacity := Ord(Input.Progress > 0);
end;

end.
