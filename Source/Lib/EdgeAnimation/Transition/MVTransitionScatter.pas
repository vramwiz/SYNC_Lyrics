unit MVTransitionScatter;

// 文字順だけから飛散方向を求める。乱数状態を使わず、シーク・並列描画で同じ結果を返す。
interface

uses MVAnimationTypes;

// 各文字が異なる方向・距離・角度から集まり、退場では同じ経路へ飛散する。
procedure MVScatter(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

procedure MVScatter(var Motion: TMVMotion; const Input: TMVAnimationInput);
const GoldenAngle = 2.399963229728653; // 文字ごとの方向が重なりにくいラジアン角。
var Angle, Radius, Hidden: Double;
begin
  Hidden := 1 - MVTransitionVisibility(Input);
  Angle := Input.UnitIndex * GoldenAngle - Pi / 2;
  Radius := Input.Amount * (0.6 + 0.4 * Sqr(Sin(Input.UnitIndex * 2.123 + 0.3)));
  Motion.X := Cos(Angle) * Radius * Hidden;
  Motion.Y := Sin(Angle) * Radius * Hidden;
  Motion.Angle := ((Input.UnitIndex mod 7) - 3) * 45 * Hidden;
  Motion.Scale := 1 - 0.7 * Hidden;
  Motion.Opacity := 1 - Hidden;
end;

end.
