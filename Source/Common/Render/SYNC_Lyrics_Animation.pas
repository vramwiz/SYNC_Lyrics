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
    leaFade
  );

  TLyricsAnimationSettings = record
    SyncAnimation: TLyricsSyncAnimation;
    StartAnimation: TLyricsEdgeAnimation;
    EndAnimation: TLyricsEdgeAnimation;
    StartDurationSeconds: Double;
    EndDurationSeconds: Double;
    BaseFontHeight: Integer;
  end;

procedure ResolveLyricsUnitEffect(Effect: TLyricsUnitDisplayEffect;
  UnitProgress: Double; out State: TLyricsUnitEffectState);
procedure ResolveLyricsAnimation(const Settings: TLyricsAnimationSettings;
  LocalSeconds, RemainingSeconds, SyncProgress: Double;
  out Opacity: Double; out OffsetY: Integer);

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
  UnitProgress: Double;
begin
  Opacity := 1;
  OffsetY := 0;

  if (Settings.StartAnimation = leaFade) and
    (Settings.StartDurationSeconds > 0) then
    Opacity := Min(Opacity, EnsureRange(
      LocalSeconds / Settings.StartDurationSeconds, 0.0, 1.0));
  if (Settings.EndAnimation = leaFade) and
    (Settings.EndDurationSeconds > 0) then
    Opacity := Min(Opacity, EnsureRange(
      RemainingSeconds / Settings.EndDurationSeconds, 0.0, 1.0));

  if Settings.SyncAnimation = lsaBounce then
  begin
    UnitProgress := SyncProgress - Floor(SyncProgress);
    if UnitProgress > 0 then
      OffsetY := -Round(Sin(Pi * UnitProgress) *
        Max(1, Settings.BaseFontHeight) * 0.12);
  end;
end;

end.
