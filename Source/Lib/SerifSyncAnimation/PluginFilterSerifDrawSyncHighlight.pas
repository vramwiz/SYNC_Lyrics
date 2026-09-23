unit PluginFilterSerifDrawSyncHighlight;

// 同期進捗から文字単位の強調位置と滑らかな色塗り範囲を計算する。

interface

uses
  System.Types;

// 進捗に対応する表示単位番号を返す。単位がない場合は-1。
function CalculateSerifSyncHighlightIndex(const AUnitCount: Integer;
  const AProgress: Double): Integer;
// 曲全体進捗を単位番号とその単位内の0～1進捗へ分解する。
procedure CalculateSerifSyncHighlightPosition(const AUnitCount: Integer;
  const AProgress: Double; out AIndex: Integer; out ALocalProgress: Double);
// 帯幅を反映した単位内の塗り進捗を0～1へ制限して返す。
function CalculateSerifSyncSmoothFillProgress(const ALocalProgress,
  ASizePercent: Double): Double;
// 滑らかな色帯の開始・終了を表示単位座標で返す。
procedure CalculateSerifSyncSmoothWindow(const AIndex: Integer;
  const ALocalProgress, ASizePercent: Double; out AStartPosition,
  AEndPosition: Double);
// 番号が有効なら表示単位の矩形、無効なら空矩形を返す。
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
