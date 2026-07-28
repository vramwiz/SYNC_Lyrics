unit SYNC_Lyrics_ManualSync;

// WAV先頭基準の境界秒列から、歌詞の連続表示進捗を求める。

interface

function ResolveManualSyncProgress(CurrentSeconds: Double;
  DisplayUnitCount: Integer; const Boundaries: array of Double;
  out ProgressUnits: Double): Boolean;

implementation

uses
  System.Math;

const
  MANUAL_TIME_EPSILON = 0.000001;

function ResolveManualSyncProgress(CurrentSeconds: Double;
  DisplayUnitCount: Integer; const Boundaries: array of Double;
  out ProgressUnits: Double): Boolean;
var
  Duration: Double;
  I: Integer;
begin
  Result := False;
  ProgressUnits := 0;
  if DisplayUnitCount < 0 then
    Exit;
  if Length(Boundaries) <> DisplayUnitCount + 1 then
    Exit;
  if DisplayUnitCount = 0 then
    Exit(True);

  for I := 0 to High(Boundaries) do
    if IsNan(Boundaries[I]) or IsInfinite(Boundaries[I]) or
      (Boundaries[I] < 0) or
      ((I > 0) and
      (Boundaries[I] <= Boundaries[I - 1] + MANUAL_TIME_EPSILON)) then
      Exit;

  Result := True;
  if CurrentSeconds < Boundaries[0] then
    Exit;
  if CurrentSeconds >= Boundaries[High(Boundaries)] then
  begin
    ProgressUnits := DisplayUnitCount;
    Exit;
  end;

  for I := 0 to DisplayUnitCount - 1 do
    if CurrentSeconds < Boundaries[I + 1] then
    begin
      Duration := Boundaries[I + 1] - Boundaries[I];
      ProgressUnits := I +
        EnsureRange((CurrentSeconds - Boundaries[I]) / Duration, 0.0, 1.0);
      Exit;
    end;
end;

end.
