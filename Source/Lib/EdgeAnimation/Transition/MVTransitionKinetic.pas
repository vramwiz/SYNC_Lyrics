unit MVTransitionKinetic;

// MVの歌詞に使う弾性移動・円弧・螺旋・字間・圧縮の登場と退場を計算する。
interface

uses MVAnimationTypes;

// 指定方向から移動し、行き過ぎと揺り戻しを減衰させて基準位置へ収める。
procedure MVSpringSlide(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 指定側への円弧移動に傾きを重ねる。退場は同じ軌道を逆にたどる。
procedure MVSwing(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 指定側を起点とする螺旋移動と回転・縮小で集合／離脱する。
procedure MVSpiral(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 各行の中央を保ち、広がった字間から整える／広げて消す。方向は使用しない。
procedure MVTrackingSpread(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 上下は縦、左右は横に押しつぶし、直交する軸を膨らませる。
procedure MVSqueeze(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

procedure MVSpringSlide(var Motion: TMVMotion; const Input: TMVAnimationInput);
var P, Rest: Double;
begin
  P := Input.Progress;
  if Input.Leaving then P := 1 - P;
  Rest := 1 - P;
  SetMVDirectedOffset(Motion, Input.Direction, Input.Amount * Rest * Rest * Rest * Cos(3 * Pi * P));
  Motion.Opacity := MVTransitionVisibility(Input);
end;

procedure MVSwing(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Hidden, Arc, Side: Double;
begin
  Hidden := 1 - MVTransitionVisibility(Input);
  Arc := Hidden * Pi / 2;
  SetMVDirectedOffset(Motion, Input.Direction, Input.Amount * Sin(Arc));
  Side := Input.Amount * (1 - Cos(Arc)) * 0.5;
  if Input.Direction in [madUp, madDown] then Motion.X := Side else Motion.Y := Side;
  Motion.Angle := Min(80.0, Input.Amount) * Hidden;
  if Input.Direction in [madUp, madRight] then Motion.Angle := -Motion.Angle;
  Motion.Opacity := 1 - Hidden;
end;

procedure MVSpiral(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Hidden, Angle, DX, DY: Double;
begin
  Hidden := 1 - MVTransitionVisibility(Input);
  Angle := 2 * Pi * Hidden;
  if Input.Leaving then Angle := -Angle;
  SetMVDirectedOffset(Motion, Input.Direction, Input.Amount * Hidden);
  DX := Motion.X;
  DY := Motion.Y;
  Motion.X := DX * Cos(Angle) - DY * Sin(Angle);
  Motion.Y := DX * Sin(Angle) + DY * Cos(Angle);
  Motion.Angle := RadToDeg(Angle);
  Motion.Scale := 1 - 0.75 * Hidden;
  Motion.Opacity := 1 - Hidden;
end;

procedure MVTrackingSpread(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  Motion.Opacity := MVTransitionVisibility(Input);
  Motion.Tracking := Min(80.0, Input.Amount * 0.25) * (1 - Motion.Opacity);
end;

procedure MVSqueeze(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Hidden, Strength: Double;
begin
  Hidden := 1 - MVTransitionVisibility(Input);
  Strength := Min(1.0, Input.Amount / 60) * Hidden;
  if Input.Direction in [madUp, madDown] then
  begin
    Motion.ScaleX := 1 + 0.6 * Strength;
    Motion.ScaleY := 1 - 0.95 * Strength;
  end
  else
  begin
    Motion.ScaleX := 1 - 0.95 * Strength;
    Motion.ScaleY := 1 + 0.6 * Strength;
  end;
  Motion.Opacity := 1 - Hidden;
end;

end.
