unit MVHoldKinetic;

// 周期と文字順から、漂流・跳躍・弾性変形・鼓動・拡縮の波を計算する。
interface

uses MVAnimationTypes;

// 横と縦で周波数を変え、閉じた8の字軌道をゆっくり漂わせる。
procedure MVDrift(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 文字順に跳ね、接地時に短く押しつぶす。周期後は同じ状態へ戻る。
procedure MVHop(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 縦横を逆方向に伸縮し、柔らかい文字の揺れを作る。
procedure MVJelly(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 1周期に大小2つの膨らみを作り、鼓動のように強調する。
procedure MVHeartbeat(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 文字順に位相をずらした拡縮。位置の波とは独立した演出。
procedure MVScaleWave(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

procedure MVDrift(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Strength: Double;
begin
  Strength := Input.Amount * 0.15 * Input.Envelope;
  Motion.X := Motion.X + Sin(Input.Phase) * Strength;
  Motion.Y := Motion.Y + Sin(Input.Phase * 2) * Strength * 0.5;
end;

procedure MVHop(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Wave, Jump, Squash: Double;
begin
  Wave := Sin(Input.Phase - Input.UnitIndex * 0.6);
  Jump := Max(0.0, Wave);
  Squash := Max(0.0, -Wave) * Min(0.25, Input.Amount * 0.002) * Input.Envelope;
  Motion.Y := Motion.Y - Jump * Input.Amount * 0.3 * Input.Envelope;
  Motion.ScaleX := Motion.ScaleX * (1 + Squash);
  Motion.ScaleY := Motion.ScaleY * (1 - Squash);
end;

procedure MVJelly(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Wave: Double;
begin
  Wave := Sin(Input.Phase) * Min(0.35, Input.Amount * 0.002) * Input.Envelope;
  Motion.ScaleX := Motion.ScaleX * (1 + Wave);
  Motion.ScaleY := Motion.ScaleY / (1 + Wave);
  Motion.Angle := Motion.Angle + Sin(Input.Phase * 2) * Min(8.0, Input.Amount * 0.05) * Input.Envelope;
end;

function BeatLobe(P, Center, Width: Double): Double;
var Distance: Double;
begin
  Distance := Abs(P - Center) / Width;
  if Distance >= 1 then Exit(0);
  Result := 0.5 + 0.5 * Cos(Pi * Distance);
end;

procedure MVHeartbeat(var Motion: TMVMotion; const Input: TMVAnimationInput);
var P, Beat: Double;
begin
  P := Frac(Input.Phase / (2 * Pi));
  Beat := BeatLobe(P, 0.18, 0.14) + 0.6 * BeatLobe(P, 0.46, 0.12);
  Motion.Scale := Motion.Scale * (1 + Beat * Min(0.3, Input.Amount * 0.0025) * Input.Envelope);
end;

procedure MVScaleWave(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Wave: Double;
begin
  Wave := Sin(Input.Phase - Input.UnitIndex * 0.65);
  Motion.Scale := Motion.Scale * (1 + Wave * Min(0.35, Input.Amount * 0.002) * Input.Envelope);
end;

end.
