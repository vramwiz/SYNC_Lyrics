unit MVTransitionMovement;

// 方向別移動と文字順を使う移動演出。登場・退場は同じ基準位置へ接続する。
interface

uses MVAnimationTypes;

// 左から入り、左へ抜ける移動とフェード。
procedure MVSlideLeft(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 右から入り、右へ抜ける移動とフェード。
procedure MVSlideRight(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 上から入り、上へ抜ける移動とフェード。
procedure MVSlideUp(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 下から入り、下へ抜ける移動とフェード。
procedure MVSlideDown(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 指定側と反対側を文字順で交互に切り替えて、集合／分離する。
procedure MVAlternatingSlide(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 指定方向への移動と焦点変化を組み合わせる。
procedure MVBlurSlide(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math, MVTransitionBasic;

procedure DirectionalSlide(var Motion: TMVMotion; const Input: TMVAnimationInput; DX, DY: Double);
var Hidden: Double;
begin
  Hidden := 1 - MVTransitionVisibility(Input);
  Motion.X := DX * Input.Amount * Hidden;
  Motion.Y := DY * Input.Amount * Hidden;
  Motion.Opacity := 1 - Hidden;
end;

procedure MVSlideLeft(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  DirectionalSlide(Motion, Input, -1, 0);
end;

procedure MVSlideRight(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  DirectionalSlide(Motion, Input, 1, 0);
end;

procedure MVSlideUp(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  DirectionalSlide(Motion, Input, 0, -1);
end;

procedure MVSlideDown(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  DirectionalSlide(Motion, Input, 0, 1);
end;

procedure MVAlternatingSlide(var Motion: TMVMotion; const Input: TMVAnimationInput);
var DirectedInput: TMVAnimationInput;
begin
  DirectedInput := Input;
  if Odd(Input.UnitIndex) then DirectedInput.Direction := OppositeMVDirection(Input.Direction);
  MVSlide(Motion, DirectedInput);
end;

procedure MVBlurSlide(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  MVSlide(Motion, Input);
  Motion.BlurSigma := Min(32.0, Input.Amount * 0.15) * (1 - MVTransitionVisibility(Input));
end;

end.
