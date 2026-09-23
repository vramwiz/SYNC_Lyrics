unit MVTransitionScale;

// 拡縮・伸縮・回転を組み合わせる登場と退場。文書の個別倍率は書き換えない。
interface

uses MVAnimationTypes;

// 大きな状態から基準サイズへ収まり、退場は拡大して薄くなる。
procedure MVLargeZoom(var Motion: TMVMotion; const Input: TMVAnimationInput);
// バネのように行き過ぎと揺り戻しを繰り返して、基準倍率へ収束する。
procedure MVElasticZoom(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 4分の3回転と縮小状態を組み合わせ、退場時は逆方向へ回して縮める。
procedure MVRotatingZoom(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 横に伸びた薄い形と基準形の間で変形する。
procedure MVStretchHorizontal(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 上下指定では縦、左右指定では横に伸びた形との間で変形する。
procedure MVStretch(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 縦に伸びた細い形と基準形の間で変形する。
procedure MVStretchVertical(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 縦方向の倍率で横倒しの状態を表す疑似フリップ。反転は行わない。
procedure MVFlipVertical(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

procedure MVLargeZoom(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  Motion.Scale := 1 + 1.5 * (1 - Visible);
  Motion.Opacity := Visible;
end;

function ElasticOut(P: Double): Double;
begin
  // 動き方の曲線が指定した行き過ぎは、種類固有のバネの外側へ直線で延長する。
  if (P <= 0) or (P >= 1) then Exit(P);
  Result := 1 + Power(2, -10 * P) * Sin((10 * P - 0.75) * (2 * Pi / 3));
end;

procedure MVElasticZoom(var Motion: TMVMotion; const Input: TMVAnimationInput);
var P: Double;
begin
  P := Input.Progress;
  if Input.Leaving then P := 1 - P;
  Motion.Scale := Max(0.02, ElasticOut(P));
  Motion.Opacity := MVTransitionVisibility(Input);
end;

procedure MVRotatingZoom(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  Motion.Scale := 0.1 + 0.9 * Visible;
  Motion.Angle := -270 * (1 - Visible);
  if Input.Leaving then Motion.Angle := -Motion.Angle;
  Motion.Opacity := Visible;
end;

procedure MVStretchHorizontal(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Hidden: Double;
begin
  Hidden := 1 - MVTransitionVisibility(Input);
  Motion.ScaleX := 1 + 1.5 * Hidden;
  Motion.ScaleY := 1 - 0.9 * Hidden;
  Motion.Opacity := 1 - Hidden;
end;

procedure MVStretchVertical(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Hidden: Double;
begin
  Hidden := 1 - MVTransitionVisibility(Input);
  Motion.ScaleX := 1 - 0.9 * Hidden;
  Motion.ScaleY := 1 + 1.5 * Hidden;
  Motion.Opacity := 1 - Hidden;
end;

procedure MVStretch(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  if Input.Direction in [madUp, madDown] then MVStretchVertical(Motion, Input)
  else MVStretchHorizontal(Motion, Input);
end;

procedure MVFlipVertical(var Motion: TMVMotion; const Input: TMVAnimationInput);
var Visible: Double;
begin
  Visible := MVTransitionVisibility(Input);
  Motion.ScaleY := Sin(Pi * Visible / 2);
  Motion.Opacity := Visible;
end;

end.
