unit MVHoldBasic;

// 既存IDの表示中演出。共通の位相と包絡を使い、前フレームの状態を持たない。
interface

uses MVAnimationTypes;

// フレーズの文字を同じ位相で上下させる。
procedure MVFloat(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 基準倍率の前後でゆっくり脈動させる。
procedure MVPulse(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 文字順に位相をずらして波を伝える。
procedure MVWave(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 基準角度の前後へ小さく揺らす。
procedure MVWobble(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

procedure MVFloat(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  Motion.Y := Motion.Y + Sin(Input.Phase) * Input.Amount * 0.15 * Input.Envelope;
end;

procedure MVPulse(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  Motion.Scale := Motion.Scale * (1 + Sin(Input.Phase) * Min(0.9, 0.05 * Input.Strength) * Input.Envelope);
end;

procedure MVWave(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  Motion.Y := Motion.Y + Sin(Input.Phase + Input.UnitIndex * 0.6) * Input.Amount * 0.15 * Input.Envelope;
end;

procedure MVWobble(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  Motion.Angle := Motion.Angle + Sin(Input.Phase) * 5 * Input.Strength * Input.Envelope;
end;

end.
