unit MVTransitionComposition;

// 同じ進行・方向から動きと見え方を独立評価し、担当する値だけを合成する。
interface

uses MVAnimationTypes;

// Motionを1状態の結果へ置換する。旧設定の引継ぎ、曲線、強さ、描画値域の制限もここで行う。
// 文字ごとの開始前・退場後の非表示は、曲線適用前の時刻を持つ呼出し側が管理する。
procedure ApplyMVTransition(var Motion: TMVMotion; LegacyID, MotionID, VisibilityID, Timing: Integer;
  Progress, Strength: Double; const Input: TMVAnimationInput);

implementation

uses System.Math, MVAnimationCatalog, MVTransitionParts, MVTransitionTiming;

function EvaluatePart(ID: Integer; const Input: TMVAnimationInput): TMVMotion;
var Item: TMVAnimationDescriptor;
begin
  Result := DefaultMVMotion;
  if FindMVAnimation(makTransition, ID, Item) and Assigned(Item.Evaluate) then Item.Evaluate(Result, Input);
end;

procedure ApplyMVTransition(var Motion: TMVMotion; LegacyID, MotionID, VisibilityID, Timing: Integer;
  Progress, Strength: Double; const Input: TMVAnimationInput);
var
  Parts: TMVTransitionParts;
  Movement, Visibility: TMVMotion;
  EvaluatedInput: TMVAnimationInput;
  Direction: Integer;
begin
  EvaluatedInput := Input;
  Direction := Ord(Input.Direction);
  NormalizeMVDirection(LegacyID, Direction, Input.Leaving);
  EvaluatedInput.Direction := TMVAnimationDirection(Direction);
  EvaluatedInput.CustomTiming := Timing <> MV_TIMING_DEFAULT;
  EvaluatedInput.Progress := EnsureRange(Progress, 0.0, 1.0);
  if EvaluatedInput.CustomTiming then
    EvaluatedInput.Progress := EvaluateMVTiming(Timing, EvaluatedInput.Progress);
  Parts := ResolveMVTransitionParts(LegacyID, MotionID, VisibilityID);
  Movement := EvaluatePart(Parts.MotionID, EvaluatedInput);
  Visibility := EvaluatePart(Parts.VisibilityID, EvaluatedInput);
  // 既存評価のフェードは移動量の計算にも使うため、計算後に幾何成分だけを取り出す。
  // 見え方を一度だけ適用し、移動側に含まれる透明度やぼかしが重複することを防ぐ。
  Motion := Visibility;
  Motion.X := Movement.X * Strength;
  Motion.Y := Movement.Y * Strength;
  Motion.Angle := Movement.Angle * Strength;
  Motion.Tracking := Movement.Tracking * Strength;
  Motion.Scale := 1 + (Movement.Scale - 1) * Strength;
  Motion.ScaleX := 1 + (Movement.ScaleX - 1) * Strength;
  Motion.ScaleY := 1 + (Movement.ScaleY - 1) * Strength;
  Motion.BlurSigma := Motion.BlurSigma * Strength;
  Motion.GlitchAmount := Motion.GlitchAmount * Strength;
  // 位置・角度・字間には行き過ぎを残し、画像の値域と反転しない倍率だけを制限する。
  Motion.Opacity := EnsureRange(Motion.Opacity, Single(0), Single(1));
  Motion.Scale := Max(Single(0), Motion.Scale);
  Motion.ScaleX := Max(Single(0), Motion.ScaleX);
  Motion.ScaleY := Max(Single(0), Motion.ScaleY);
  Motion.BlurSigma := EnsureRange(Motion.BlurSigma, Single(0), Single(40));
  Motion.GlitchAmount := EnsureRange(Motion.GlitchAmount, Single(0), Single(40));
  Motion.ClipLeft := EnsureRange(Motion.ClipLeft, Single(0), Single(1));
  Motion.ClipRight := EnsureRange(Motion.ClipRight, Single(0), Single(1));
  Motion.ClipTop := EnsureRange(Motion.ClipTop, Single(0), Single(1));
  Motion.ClipBottom := EnsureRange(Motion.ClipBottom, Single(0), Single(1));
  Motion.MaskVisibility := EnsureRange(Motion.MaskVisibility, Single(0), Single(1));
end;

end.
