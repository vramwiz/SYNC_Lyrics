unit MVHoldAccent;

// 細かな震え、字間の呼吸、短いデジタルノイズを現在位相だけで計算する。
interface

uses MVAnimationTypes;

// 複数周波数を重ねた細かな位置の震え。逆順描画でも乱数状態を持たない。
procedure MVJitter(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 行中央を固定して字間を開閉する。1文字の行は動かない。
procedure MVTrackingBreath(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 周期内の短い区間だけ横帯をずらす。乱れのない区間は通常の文字像へ戻す。
procedure MVGlitchHold(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

procedure MVJitter(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Phase, Strength: Double;
begin
  Phase := Input.UnitIndex * 1.73;
  Strength := Min(24.0, Input.Amount * 0.08) * Input.Envelope;
  Motion.X := Motion.X + (Sin(Input.Phase * 7 + Phase) + 0.5 * Sin(Input.Phase * 13 - Phase)) * Strength / 1.5;
  Motion.Y := Motion.Y + (Sin(Input.Phase * 11 - Phase) + 0.5 * Sin(Input.Phase * 17 + Phase)) * Strength / 1.5;
end;

procedure MVTrackingBreath(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  // 開く側だけに動かし、元から狭い字間をさらに詰めない。
  Motion.Tracking := Motion.Tracking + (0.5 - 0.5 * Cos(Input.Phase)) *
    Min(16.0, Input.Amount * 0.08) * Input.Envelope;
end;

procedure MVGlitchHold(var Motion: TMVMotion; const Input: TMVAnimationInput);
var P, Burst, Strength: Double;
begin
  P := Frac(Input.Phase / (2 * Pi));
  if (P <= 0.12) or (P >= 0.32) then Exit;
  Burst := Sqr(Sin(Pi * (P - 0.12) / 0.2));
  Strength := Burst * Input.Envelope * Min(1.0, Input.Amount / 60);
  // 登場・退場側にもグリッチがあれば、より強い側の模様を維持する。
  if Motion.GlitchAmount < Min(32.0, Input.Amount * 0.25) * Burst * Input.Envelope then
  begin
    Motion.GlitchAmount := Min(32.0, Input.Amount * 0.25) * Burst * Input.Envelope;
    Motion.GlitchStep := Floor(P * 60);
    Motion.EffectSeed := Input.UnitIndex;
  end;
  Motion.Opacity := Motion.Opacity * (1 - 0.25 * Strength);
end;

end.
