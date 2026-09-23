unit MVHoldExtended;

// 点滅・振り子・連続回転の表示中演出を計算する。
interface

uses MVAnimationTypes;

// 1周期の半分ずつ点灯／消灯する。登場・退場端では消灯の強さを弱める。
procedure MVBlink(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 左右の円弧移動と傾きを組み合わせて振り子の動きを作る。
procedure MVPendulum(var Motion: TMVMotion; const Input: TMVAnimationInput);
// ホスト指定の周期で1回転する。退場端で角度を巻き戻さない。
procedure MVSpin(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

procedure MVBlink(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  if Cos(Input.Phase) < 0 then Motion.Opacity := Motion.Opacity * (1 - Input.Envelope * Min(1.0, Input.Strength));
end;

procedure MVPendulum(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Angle, Radius: Double;
begin
  Angle := Sin(Input.Phase) * DegToRad(Min(45.0, Input.Amount * 0.25)) * Input.Envelope;
  Radius := Input.Amount * 0.5;
  Motion.X := Motion.X + Sin(Angle) * Radius;
  Motion.Y := Motion.Y + (1 - Cos(Angle)) * Radius;
  Motion.Angle := Motion.Angle - RadToDeg(Angle);
end;

procedure MVSpin(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  // 周回数を落として、長時間のシークでもSingle角度の精度を保つ。
  Motion.Angle := Motion.Angle + 360 * Frac(Input.Phase * Input.Strength / (2 * Pi));
end;

end.
