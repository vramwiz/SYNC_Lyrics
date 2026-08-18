unit PluginFilterSerifDrawSyncHighlight;

interface

uses
  System.Types;

function CalculateSerifSyncHighlightIndex(const AUnitCount: Integer;
  const AProgress: Double): Integer;
procedure CalculateSerifSyncHighlightPosition(const AUnitCount: Integer;
  const AProgress: Double; out AIndex: Integer; out ALocalProgress: Double);
function CalculateSerifSyncSmoothFillProgress(const ALocalProgress,
  ASizePercent: Double): Double;
procedure CalculateSerifSyncSmoothWindow(const AIndex: Integer;
  const ALocalProgress, ASizePercent: Double; out AStartPosition,
  AEndPosition: Double);
function CalculateSerifSyncHighlightRectAtIndex(
  const ATextUnitBounds: TArray<TRect>;
  const AIndex: Integer): TRect;

implementation

uses
  System.Math;

function CalculateSerifSyncHighlightIndex(const AUnitCount: Integer;
  const AProgress: Double): Integer;
var
  LocalProgress: Double;
begin
  CalculateSerifSyncHighlightPosition(AUnitCount, AProgress, Result,
    LocalProgress);
end;

procedure CalculateSerifSyncHighlightPosition(const AUnitCount: Integer;
  const AProgress: Double; out AIndex: Integer; out ALocalProgress: Double);
var
  Position: Double;
  Progress: Double;
begin
  AIndex := -1;
  ALocalProgress := 0.0;
  if AUnitCount <= 0 then
    Exit;
  Progress := EnsureRange(AProgress, 0.0, 1.0);
  if Progress >= 1.0 then
  begin
    AIndex := AUnitCount - 1;
    ALocalProgress := 1.0;
    Exit;
  end;
  Position := Progress * AUnitCount;
  AIndex := Min(AUnitCount - 1, Floor(Position));
  ALocalProgress := Frac(Position);
end;

function CalculateSerifSyncSmoothFillProgress(const ALocalProgress,
  ASizePercent: Double): Double;
begin
  Result := EnsureRange(ALocalProgress * Max(0.0, ASizePercent) / 100.0,
    0.0, 1.0);
end;

procedure CalculateSerifSyncSmoothWindow(const AIndex: Integer;
  const ALocalProgress, ASizePercent: Double; out AStartPosition,
  AEndPosition: Double);
var
  BandWidth: Double;
begin
  AEndPosition := AIndex + EnsureRange(ALocalProgress, 0.0, 1.0);
  BandWidth := Max(0.01, ASizePercent) / 100.0;
  AStartPosition := AEndPosition - BandWidth;
end;

function CalculateSerifSyncHighlightRectAtIndex(
  const ATextUnitBounds: TArray<TRect>; const AIndex: Integer): TRect;
begin
  if (AIndex < 0) or (AIndex >= Length(ATextUnitBounds)) then
    Exit(TRect.Empty);
  Result := ATextUnitBounds[AIndex];
end;

end.
