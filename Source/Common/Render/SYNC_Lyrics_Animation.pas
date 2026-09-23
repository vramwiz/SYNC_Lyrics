unit SYNC_Lyrics_Animation;

// オブジェクト区間と同期進捗から、描画へ渡す不透明度と位置補正を求める。

interface

uses MVAnimationTypes;

type
  TLyricsUnitDisplayEffect = (
    ludeKaraoke,
    ludeUnitEmphasis,
    ludeUnitReveal
  );

  TLyricsUnitEffectState = record
    DrawBefore: Boolean;
    AfterProgress: Double;
    Opacity: Double;
    OffsetX: Single;
    OffsetY: Single;
    ScaleX: Single;
    ScaleY: Single;
  end;

  TLyricsSyncAnimation = (
    lsaNone,
    lsaBounce
  );

  TLyricsEdgeAnimation = (
    leaNone,
    leaFade,
    leaSlide,
    leaZoom,
    leaWipe,
    leaBlur,
    leaRotate,
    leaPop,
    leaBounce
  );

  TLyricsAnimationTransform = record
    Opacity: Double;
    OffsetX: Double;
    OffsetY: Double;
    ScaleX: Double;
    ScaleY: Double;
    RotationDegrees: Double;
    BlurRadius: Double;
    WipeDirection: Integer;
    WipeProgress: Double;
  end;

  TLyricsAnimationSettings = record
    SyncAnimation: TLyricsSyncAnimation;
    StartAnimation: TLyricsEdgeAnimation;
    EndAnimation: TLyricsEdgeAnimation;
    StartDurationSeconds: Double;
    EndDurationSeconds: Double;
    BaseFontHeight: Integer;
    StartDirection: Integer;
    StartZoomOrigin: Integer;
    EndDirection: Integer;
    EndZoomDestination: Integer;
  end;

  TLyricsEdgeSettings = record
    BeforeMotionID, BeforeDisplayID: Integer; // MVスタジオの登場動作・表示の固定ID。
    AfterMotionID, AfterDisplayID: Integer; // MVスタジオの退場動作・表示の固定ID。
    BeforeDirection, AfterDirection: Integer; // Filterの標準・左・右・上・下。
    BeforeZoomOrigin, AfterZoomDestination: Integer; // 既存の奥・手前選択。
    BeforeDuration, AfterDuration: Double; // 行の表示範囲内での実効秒数。
    LocalSeconds, RemainingSeconds: Double; // 行の表示開始・終了からの秒数。
  end;

procedure ResolveLyricsUnitEffect(Effect: TLyricsUnitDisplayEffect;
  UnitProgress: Double; out State: TLyricsUnitEffectState);
procedure ResolveLyricsAnimation(const Settings: TLyricsAnimationSettings;
  LocalSeconds, RemainingSeconds, SyncProgress: Double;
  out Opacity: Double; out OffsetY: Integer);
procedure ResolveLyricsAnimationTransform(
  const Settings: TLyricsAnimationSettings;
  LocalSeconds, RemainingSeconds, SyncProgress: Double;
  out Transform: TLyricsAnimationTransform);
// 現在フレームで表示前または表示後の単位別合成が必要かを返す。
function HasActiveLyricsEdgeAnimation(const Settings: TLyricsEdgeSettings): Boolean;
// 参考元の固定IDを評価し、本文とルビをまとめた1表示単位の一時変形を返す。
function ResolveLyricsEdgeMotion(const Settings: TLyricsEdgeSettings;
  UnitIndex, UnitCount: Integer): TMVMotion;

implementation

uses
  System.Math, MVTransitionComposition, MVTransitionParts;

function HasActiveLyricsEdgeAnimation(const Settings: TLyricsEdgeSettings): Boolean;
begin
  Result := (((Settings.BeforeMotionID <> 0) or
    (Settings.BeforeDisplayID <> 0)) and
    (Settings.LocalSeconds < Settings.BeforeDuration)) or
    (((Settings.AfterMotionID <> 0) or
    (Settings.AfterDisplayID <> 0)) and
    (Settings.RemainingSeconds < Settings.AfterDuration));
end;

function EdgeDirection(Value: Integer; Leaving: Boolean): TMVAnimationDirection;
begin
  case Value of
    1: Result := madLeft;
    2: Result := madRight;
    3: Result := madUp;
    4: Result := madDown;
  else
    if Leaving then Result := madRight else Result := madLeft;
  end;
end;

function ResolveLyricsEdgeMotion(const Settings: TLyricsEdgeSettings;
  UnitIndex, UnitCount: Integer): TMVMotion;
var
  BeforeActive: Boolean;
  Input: TMVAnimationInput;
  Leaving: Boolean;
  MotionID, DisplayID, ZoomSide: Integer;
  Progress, Duration: Double;
begin
  Result := DefaultMVMotion;
  if not HasActiveLyricsEdgeAnimation(Settings) then Exit;
  BeforeActive := ((Settings.BeforeMotionID <> 0) or
    (Settings.BeforeDisplayID <> 0)) and
    (Settings.LocalSeconds < Settings.BeforeDuration);
  Leaving := not BeforeActive;
  if Leaving then
  begin
    MotionID := Settings.AfterMotionID;
    DisplayID := Settings.AfterDisplayID;
    ZoomSide := Settings.AfterZoomDestination;
    Duration := Max(0.0001, Settings.AfterDuration);
    Progress := 1 - Settings.RemainingSeconds / Duration;
  end
  else
  begin
    MotionID := Settings.BeforeMotionID;
    DisplayID := Settings.BeforeDisplayID;
    ZoomSide := Settings.BeforeZoomOrigin;
    Duration := Max(0.0001, Settings.BeforeDuration);
    Progress := Settings.LocalSeconds / Duration;
  end;
  if (MotionID = 0) and (DisplayID = 0) then Exit;
  Input := Default(TMVAnimationInput);
  Input.Amount := 60;
  Input.CurveAmount := 30;
  Input.UnitIndex := UnitIndex;
  Input.Leaving := Leaving;
  if Leaving then Input.Direction := EdgeDirection(Settings.AfterDirection, True)
  else Input.Direction := EdgeDirection(Settings.BeforeDirection, False);
  // 文字送りには専用の遅延項目を設けないため、設定時間を表示単位数へ等分する。
  if DisplayID = 6 then
    Progress := EnsureRange(Progress * Max(1, UnitCount) - UnitIndex, 0.0, 1.0);
  ApplyMVTransition(Result, 0, MotionID, DisplayID, 0,
    EnsureRange(Progress, 0.0, 1.0), 1, Input);
  if (ZoomSide = 1) and (MotionID in [3, 4, 15, 16, 17]) then
    Result.Scale := Max(0.01, 2 - Result.Scale);
  Result.EffectSeed := UnitIndex;
end;

procedure ResolveLyricsUnitEffect(Effect: TLyricsUnitDisplayEffect;
  UnitProgress: Double; out State: TLyricsUnitEffectState);
begin
  UnitProgress := EnsureRange(UnitProgress, 0.0, 1.0);
  State.DrawBefore := Effect <> ludeUnitReveal;
  State.AfterProgress := UnitProgress;
  State.Opacity := 1;
  State.OffsetX := 0;
  State.OffsetY := 0;
  State.ScaleX := 1;
  State.ScaleY := 1;
  if (Effect <> ludeKaraoke) and (UnitProgress > 0) then
    State.AfterProgress := 1;
end;

procedure ResolveLyricsAnimation(const Settings: TLyricsAnimationSettings;
  LocalSeconds, RemainingSeconds, SyncProgress: Double;
  out Opacity: Double; out OffsetY: Integer);
var
  Transform: TLyricsAnimationTransform;
begin
  ResolveLyricsAnimationTransform(Settings, LocalSeconds,
    RemainingSeconds, SyncProgress, Transform);
  Opacity := Transform.Opacity;
  OffsetY := Round(Transform.OffsetY);
end;

function SmoothStep(Value: Double): Double;
begin
  Value := EnsureRange(Value, 0.0, 1.0);
  Result := Value * Value * (3.0 - 2.0 * Value);
end;

procedure ResolveLyricsAnimationTransform(
  const Settings: TLyricsAnimationSettings;
  LocalSeconds, RemainingSeconds, SyncProgress: Double;
  out Transform: TLyricsAnimationTransform);
var
  Duration: Double;
  Factor: Double;
  Progress: Double;
  StartOffset: Double;
  Travel: Double;
  UnitProgress: Double;
begin
  Transform := Default(TLyricsAnimationTransform);
  Transform.Opacity := 1;
  Transform.ScaleX := 1;
  Transform.ScaleY := 1;
  Transform.WipeProgress := 1;

  Duration := Settings.StartDurationSeconds;
  if Duration <= 0 then
    Duration := 0.3;
  Progress := EnsureRange(LocalSeconds / Duration, 0.0, 1.0);
  case Settings.StartAnimation of
    leaFade:
      Transform.Opacity := Min(Transform.Opacity, Progress);
    leaSlide:
      begin
        StartOffset := 48.0 * (1.0 - SmoothStep(Progress));
        case Settings.StartDirection of
          2: Transform.OffsetX := Transform.OffsetX + StartOffset;
          3: Transform.OffsetY := Transform.OffsetY - StartOffset;
          4: Transform.OffsetY := Transform.OffsetY + StartOffset;
        else
          Transform.OffsetX := Transform.OffsetX - StartOffset;
        end;
        Transform.Opacity := Min(Transform.Opacity,
          EnsureRange(LocalSeconds / 0.08, 0.0, 1.0));
      end;
    leaZoom:
      begin
        Progress := SmoothStep(Progress);
        if Settings.StartZoomOrigin = 1 then
          Factor := 1.28 - 0.28 * Progress
        else
          Factor := 0.72 + 0.28 * Progress;
        Transform.ScaleX := Transform.ScaleX * Factor;
        Transform.ScaleY := Transform.ScaleY * Factor;
        Transform.Opacity := Min(Transform.Opacity,
          EnsureRange(LocalSeconds / 0.10, 0.0, 1.0));
      end;
    leaPop:
      begin
        if Settings.StartZoomOrigin = 1 then
        begin
          if Progress < 0.7 then
            Factor := 1.28 + (0.92 - 1.28) * (Progress / 0.7)
          else
            Factor := 0.92 + 0.08 * ((Progress - 0.7) / 0.3);
        end
        else if Progress < 0.7 then
          Factor := 0.72 + (1.08 - 0.72) * (Progress / 0.7)
        else
          Factor := 1.08 - 0.08 * ((Progress - 0.7) / 0.3);
        Transform.ScaleX := Transform.ScaleX * Factor;
        Transform.ScaleY := Transform.ScaleY * Factor;
        Transform.Opacity := Min(Transform.Opacity,
          EnsureRange(LocalSeconds / 0.08, 0.0, 1.0));
      end;
    leaWipe:
      begin
        Transform.WipeDirection := Settings.StartDirection;
        Transform.WipeProgress := SmoothStep(Progress);
      end;
    leaBlur:
      begin
        Progress := SmoothStep(Progress);
        Transform.BlurRadius := 6.0 * (1.0 - Progress);
        Transform.Opacity := Min(Transform.Opacity,
          EnsureRange(LocalSeconds / 0.10, 0.0, 1.0));
      end;
    leaRotate:
      begin
        Progress := SmoothStep(Progress);
        if Settings.StartDirection = 2 then
          Transform.RotationDegrees := 8.0 * (1.0 - Progress)
        else
          Transform.RotationDegrees := -8.0 * (1.0 - Progress);
        Factor := 0.90 + 0.10 * Progress;
        Transform.ScaleX := Transform.ScaleX * Factor;
        Transform.ScaleY := Transform.ScaleY * Factor;
        Transform.Opacity := Min(Transform.Opacity,
          EnsureRange(LocalSeconds / 0.08, 0.0, 1.0));
      end;
    leaBounce:
      begin
        if Progress < 0.62 then
          StartOffset := 32.0 * (1.0 - SmoothStep(Progress / 0.62))
        else if Progress < 0.78 then
          StartOffset := 7.0 * SmoothStep((Progress - 0.62) / 0.16)
        else
          StartOffset := 7.0 *
            (1.0 - SmoothStep((Progress - 0.78) / 0.22));
        case Settings.StartDirection of
          1: Transform.OffsetX := Transform.OffsetX - StartOffset;
          2: Transform.OffsetX := Transform.OffsetX + StartOffset;
          4: Transform.OffsetY := Transform.OffsetY + StartOffset;
        else
          Transform.OffsetY := Transform.OffsetY - StartOffset;
        end;
        Transform.Opacity := Min(Transform.Opacity,
          EnsureRange(LocalSeconds / 0.08, 0.0, 1.0));
      end;
  end;

  Duration := Settings.EndDurationSeconds;
  if Duration <= 0 then
    Duration := 0.3;
  Progress := EnsureRange(1.0 - RemainingSeconds / Duration, 0.0, 1.0);
  case Settings.EndAnimation of
    leaFade:
      Transform.Opacity := Min(Transform.Opacity, 1.0 - Progress);
    leaSlide:
      begin
        Travel := 64.0 * SmoothStep(Progress);
        case Settings.EndDirection of
          1: Transform.OffsetX := Transform.OffsetX - Travel;
          3: Transform.OffsetY := Transform.OffsetY - Travel;
          4: Transform.OffsetY := Transform.OffsetY + Travel;
        else
          Transform.OffsetX := Transform.OffsetX + Travel;
        end;
        Transform.Opacity := Min(Transform.Opacity,
          1.0 - EnsureRange((Progress - 0.55) / 0.45, 0.0, 1.0));
      end;
    leaZoom:
      begin
        Progress := SmoothStep(Progress);
        if Settings.EndZoomDestination = 1 then
          Factor := 1.0 + 0.28 * Progress
        else
          Factor := 1.0 - 0.28 * Progress;
        Transform.ScaleX := Transform.ScaleX * Factor;
        Transform.ScaleY := Transform.ScaleY * Factor;
        Transform.Opacity := Min(Transform.Opacity,
          1.0 - EnsureRange((Progress - 0.45) / 0.55, 0.0, 1.0));
      end;
    leaWipe:
      begin
        Transform.WipeDirection := Settings.EndDirection;
        if Transform.WipeDirection = 0 then
          Transform.WipeDirection := 2;
        Transform.WipeProgress := 1.0 - SmoothStep(Progress);
      end;
    leaBlur:
      begin
        Progress := SmoothStep(Progress);
        Transform.BlurRadius := Max(Transform.BlurRadius,
          8.0 * Progress);
        Transform.Opacity := Min(Transform.Opacity, 1.0 - Progress);
      end;
    leaRotate:
      begin
        Progress := SmoothStep(Progress);
        if Settings.EndDirection = 1 then
          Transform.RotationDegrees := Transform.RotationDegrees -
            12.0 * Progress
        else
          Transform.RotationDegrees := Transform.RotationDegrees +
            12.0 * Progress;
        Factor := 1.0 - 0.10 * Progress;
        Transform.ScaleX := Transform.ScaleX * Factor;
        Transform.ScaleY := Transform.ScaleY * Factor;
        Transform.Opacity := Min(Transform.Opacity,
          1.0 - EnsureRange((Progress - 0.45) / 0.55, 0.0, 1.0));
      end;
  end;

  if Settings.SyncAnimation = lsaBounce then
  begin
    UnitProgress := SyncProgress - Floor(SyncProgress);
    if UnitProgress > 0 then
      Transform.OffsetY := Transform.OffsetY -
        Round(Sin(Pi * UnitProgress) *
          Max(1, Settings.BaseFontHeight) * 0.12);
  end;
end;

end.
