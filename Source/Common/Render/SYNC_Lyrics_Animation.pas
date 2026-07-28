unit SYNC_Lyrics_Animation;

// オブジェクト区間と同期進捗から、描画へ渡す不透明度と位置補正を求める。

interface

type
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

procedure ResolveLyricsAnimation(const Settings: TLyricsAnimationSettings;
  LocalSeconds, RemainingSeconds, SyncProgress: Double;
  out Opacity: Double; out OffsetY: Integer);

implementation

uses
  System.Math;

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
