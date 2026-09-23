unit MVTransitionPath;

// 保存配置を終点として、波・S字・折れ線の軌道を方向と曲がりの強さから評価する。
interface

uses MVAnimationTypes;

// 2周期のなめらかな波をたどる。文字順による位相は加えず、共通の文字遅延で追従させる。
procedure MVWavePath(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 反対側へ張り出す2つの制御点を持つ3次ベジェ軌道をたどる。
procedure MVSCurvePath(var Motion: TMVMotion; const Input: TMVAnimationInput);
// 左右へ4回張り出す折れ線をたどる。曲がり角を丸めずリズムのある動きにする。
procedure MVZigzagPath(var Motion: TMVMotion; const Input: TMVAnimationInput);

implementation

uses System.Math;

type
  TMVPathKind = (mpkWave, mpkSCurve, mpkZigzag);

function PathBend(Kind: TMVPathKind; P: Double): Double;
const
  Zigzag: array[0..5] of Double = (0, 1, -1, 1, -1, 0); // 等間隔の折れ点。両端は基準軸上。
var
  Envelope, Position: Double;
  Segment: Integer;
begin
  case Kind of
    mpkWave:
      begin
        // 両端で横方向の位置と傾きを0にし、行き過ぎ部分は進行軸へそのまま延ばす。
        if (P <= 0) or (P >= 1) then Exit(0);
        Envelope := Sqr(Sin(Pi * P));
        Result := Sin(4 * Pi * P) * Envelope;
      end;
    mpkSCurve:
      begin
        // ベジェの横変位を最大1へ正規化する。区間外は端の接線で延ばし、バウンドにも連続対応する。
        if P < 0 then Result := 6 * Sqrt(3) * P
        else if P > 1 then Result := 6 * Sqrt(3) * (P - 1)
        else Result := 6 * Sqrt(3) * P * (1 - P) * (1 - 2 * P);
      end;
    mpkZigzag:
      begin
        // 区間外でも最初／最後の線分を延長し、加速曲線の引き・行き過ぎを切り捨てない。
        Position := P * 5;
        Segment := Floor(EnsureRange(Position, 0.0, 4.0));
        Result := Zigzag[Segment] + (Zigzag[Segment + 1] - Zigzag[Segment]) * (Position - Segment);
      end;
  else
    Result := 0;
  end;
end;

procedure ApplyPath(var Motion: TMVMotion; const Input: TMVAnimationInput; Kind: TMVPathKind);
var Hidden, Bend: Double;
begin
  Motion.Opacity := MVTransitionVisibility(Input);
  Hidden := 1 - MVTransitionVisibility(Input);
  Bend := Input.CurveAmount * PathBend(Kind, Hidden);
  SetMVDirectedOffset(Motion, Input.Direction, Input.Amount * Hidden);
  // 軌道全体を指定方向へ回す。文字の個別回転と保存位置は変えない。
  case Input.Direction of
    madUp: Motion.X := Bend;
    madDown: Motion.X := -Bend;
    madLeft: Motion.Y := -Bend;
    madRight: Motion.Y := Bend;
  end;
end;

procedure MVWavePath(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  ApplyPath(Motion, Input, mpkWave);
end;

procedure MVSCurvePath(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  ApplyPath(Motion, Input, mpkSCurve);
end;

procedure MVZigzagPath(var Motion: TMVMotion; const Input: TMVAnimationInput);
begin
  ApplyPath(Motion, Input, mpkZigzag);
end;

end.
