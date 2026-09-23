unit SYNC_Lyrics_TimeRuler;

// Calculates scale-aware waveform ruler intervals anchored to audio time zero.

interface

function SelectTimeRulerInterval(DisplaySeconds: Double): Double;
function FirstTimeRulerTickIndex(ViewStartSeconds,
  IntervalSeconds: Double): Int64;
function LastTimeRulerTickIndex(ViewEndSeconds,
  IntervalSeconds: Double): Int64;
function TimeRulerDecimalPlaces(IntervalSeconds: Double): Integer;

implementation

uses
  System.Math;

const
  TARGET_RULER_DIVISIONS = 10.0;
  TICK_INDEX_EPSILON     = 1E-9;

function SelectTimeRulerInterval(DisplaySeconds: Double): Double;
var
  Magnitude: Double;
  Normalized: Double;
  RawInterval: Double;
begin
  RawInterval := Max(0.000001, DisplaySeconds) /
    TARGET_RULER_DIVISIONS;
  Magnitude := Power(10, Floor(Log10(RawInterval)));
  Normalized := RawInterval / Magnitude;
  if Normalized <= 1 then
    Result := Magnitude
  else if Normalized <= 2 then
    Result := 2 * Magnitude
  else if Normalized <= 5 then
    Result := 5 * Magnitude
  else
    Result := 10 * Magnitude;
end;

function FirstTimeRulerTickIndex(ViewStartSeconds,
  IntervalSeconds: Double): Int64;
begin
  Result := Ceil(ViewStartSeconds / IntervalSeconds -
    TICK_INDEX_EPSILON);
end;

function LastTimeRulerTickIndex(ViewEndSeconds,
  IntervalSeconds: Double): Int64;
begin
  Result := Floor(ViewEndSeconds / IntervalSeconds +
    TICK_INDEX_EPSILON);
end;

function TimeRulerDecimalPlaces(IntervalSeconds: Double): Integer;
begin
  if IntervalSeconds >= 1 then
    Result := 0
  else
    Result := EnsureRange(
      Ceil(-Log10(IntervalSeconds) - TICK_INDEX_EPSILON), 0, 6);
end;

end.
