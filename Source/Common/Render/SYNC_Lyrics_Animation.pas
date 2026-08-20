unit SYNC_Lyrics_Animation;

// オブジェクト区間と同期進捗から、描画へ渡す不透明度と位置補正を求める。

interface

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

procedure ResolveLyricsUnitEffect(Effect: TLyricsUnitDisplayEffect;
  UnitProgress: Double; out State: TLyricsUnitEffectState);
procedure ResolveLyricsAnimation(const Settings: TLyricsAnimationSettings;
  LocalSeconds, RemainingSeconds, SyncProgress: Double;
  out Opacity: Double; out OffsetY: Integer);
procedure ResolveLyricsAnimationTransform(
  const Settings: TLyricsAnimationSettings;
  LocalSeconds, RemainingSeconds, SyncProgress: Double;
  out Transform: TLyricsAnimationTransform);

implementation

uses
  System.Math;

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
