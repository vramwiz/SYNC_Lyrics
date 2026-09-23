unit MVTransitionMasks;

// 文字を移動させず表示範囲だけを変える、方向別・中央開閉のワイプ。
interface

uses MVAnimationTypes;

// 上下指定では縦、左右指定では横に中央から開閉する。
procedure MVWipeCenter(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 境界を右から左へ進め、登場は露出、退場は隠す範囲を増やす。
procedure MVWipeRightToLeft(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 境界を上から下へ進める。
procedure MVWipeTopToBottom(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 境界を下から上へ進める。
procedure MVWipeBottomToTop(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 横方向に中央から開き、退場は両側から中央へ閉じる。
procedure MVWipeCenterHorizontal(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 縦方向に中央から開き、退場は上下から中央へ閉じる。
procedure MVWipeCenterVertical(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

procedure MVWipeCenter(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  if Input.Direction in [madUp, madDown] then MVWipeCenterVertical(Motion, Input)
  else MVWipeCenterHorizontal(Motion, Input);
end;

procedure MVWipeRightToLeft(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  if Input.Leaving then Motion.ClipRight := Visible else Motion.ClipLeft := 1 - Visible;
end;

procedure MVWipeTopToBottom(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  if Input.Leaving then Motion.ClipTop := 1 - Visible else Motion.ClipBottom := Visible;
end;

procedure MVWipeBottomToTop(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  if Input.Leaving then Motion.ClipBottom := Visible else Motion.ClipTop := 1 - Visible;
end;

procedure MVWipeCenterHorizontal(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  Motion.ClipLeft := (1 - Visible) / 2;
  Motion.ClipRight := (1 + Visible) / 2;
end;

procedure MVWipeCenterVertical(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  Motion.ClipTop := (1 - Visible) / 2;
  Motion.ClipBottom := (1 + Visible) / 2;
end;

end.
