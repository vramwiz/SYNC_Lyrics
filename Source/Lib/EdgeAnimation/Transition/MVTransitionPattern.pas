unit MVTransitionPattern;

// 帯・ブロック・横ずれによる登場と退場。画像分割の描画はRendering層が担当する。
interface

uses MVAnimationTypes;

// 各帯を指定側から開く／指定側へ閉じる。文字位置は動かさない。
procedure MVBlinds(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 固定模様の小ブロックを埋める／取り除く。全体フェードとは分けて扱う。
procedure MVBlockDissolve(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 文字を横帯にずらし、短い明滅とともに整える／崩す。歌詞は置換しない。
procedure MVGlitchTransition(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

procedure MVBlinds(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  Motion.Mask := mamBlinds;
  Motion.MaskVisibility := MVTransitionVisibility(Input);
  Motion.MaskDirection := Input.Direction;
end;

procedure MVBlockDissolve(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  Motion.Mask := mamDissolve;
  Motion.MaskVisibility := MVTransitionVisibility(Input);
  Motion.EffectSeed := Input.UnitIndex;
end;

procedure MVGlitchTransition(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Hidden, Flicker: Double;
begin
  Hidden := 1 - MVTransitionVisibility(Input);
  Motion.GlitchAmount := Min(40.0, Input.Amount * 0.35) * Hidden;
  Motion.GlitchStep := Floor(Input.Progress * 18);
  Motion.EffectSeed := Input.UnitIndex;
  Flicker := 0.5 + 0.5 * Sin(Motion.GlitchStep * 2.17 + Input.UnitIndex * 1.31);
  Motion.Opacity := (1 - Hidden) * (1 - 0.5 * Hidden * Flicker);
end;

end.
