unit SYNC_Lyrics_ManualSyncEditModel;

// 手動同期GUIの境界初期配置、リアルタイム入力、ドラッグ調整を管理する。

interface

uses
  SYNC_Lyrics_SyncFormat;

type
  TManualSyncEditModel = class
  private
    FAudioDurationSeconds: Double;
    FBoundaries: TSyncDoubleArray;
    FDefaultSpanSeconds: Double;
    FTimingInputStarted: Boolean;
    FUnitCount: Integer;
    procedure BuildDefaultBoundaries;
  public
    procedure Initialize(UnitCount: Integer; AudioDurationSeconds: Double;
      const SyncText: string; DefaultSpanSeconds: Double = -1);
    function AddTimingBoundary(PositionSeconds: Double): Boolean;
    function BoundaryCount: Integer;
    function BoundarySeconds(Index: Integer): Double;
    function Complete: Boolean;
    function MoveBoundary(Index: Integer; PositionSeconds: Double): Boolean;
    // 行先頭を指定位置へ移し、表示単位間の間隔を保つ。
    function MoveLineStart(PositionSeconds: Double): Boolean;
    // Index以降の境界を一緒に移し、前の表示単位の長さだけを変える。
    function MoveSuffix(Index: Integer; PositionSeconds: Double): Boolean;
    procedure RearmTimingInput;
    function SerializeSyncText: string;
    property TimingInputStarted: Boolean read FTimingInputStarted;
    property UnitCount: Integer read FUnitCount;
  end;

implementation

uses
  System.Math,
  System.SysUtils;

const
  MIN_BOUNDARY_DISTANCE = 0.001;

procedure TManualSyncEditModel.BuildDefaultBoundaries;
var
  I: Integer;
begin
  SetLength(FBoundaries, FUnitCount + 1);
  if FUnitCount <= 0 then
    Exit;
  for I := 0 to FUnitCount do
    FBoundaries[I] := FDefaultSpanSeconds * I / FUnitCount;
end;

procedure TManualSyncEditModel.Initialize(UnitCount: Integer;
  AudioDurationSeconds: Double; const SyncText: string;
  DefaultSpanSeconds: Double);
var
  Data: TSyncTextData;
begin
  FUnitCount := Max(0, UnitCount);
  FAudioDurationSeconds := Max(0.001, AudioDurationSeconds);
  if DefaultSpanSeconds <= 0 then
    FDefaultSpanSeconds := FAudioDurationSeconds
  else
    FDefaultSpanSeconds := Min(DefaultSpanSeconds,
      FAudioDurationSeconds);
  FTimingInputStarted := False;
  if TryParseSyncText(SyncText, Data) and (Data.Mode = smManual) and
    (Length(Data.ManualBoundaries) = FUnitCount + 1) and
    ((Length(Data.ManualBoundaries) = 0) or
    (Data.ManualBoundaries[High(Data.ManualBoundaries)] <=
      FAudioDurationSeconds + MIN_BOUNDARY_DISTANCE)) then
    FBoundaries := Copy(Data.ManualBoundaries)
  else
    BuildDefaultBoundaries;
end;

function TManualSyncEditModel.AddTimingBoundary(
  PositionSeconds: Double): Boolean;
var
  NewIndex: Integer;
begin
  Result := False;
  if FUnitCount <= 0 then
    Exit;
  PositionSeconds := EnsureRange(PositionSeconds, 0.0,
    FAudioDurationSeconds);
  if not FTimingInputStarted then
  begin
    SetLength(FBoundaries, 1);
    FBoundaries[0] := PositionSeconds;
    FTimingInputStarted := True;
    Exit(True);
  end;
  if Length(FBoundaries) >= FUnitCount + 1 then
    Exit;
  if PositionSeconds <=
    FBoundaries[High(FBoundaries)] + MIN_BOUNDARY_DISTANCE then
    Exit;
  NewIndex := Length(FBoundaries);
  SetLength(FBoundaries, NewIndex + 1);
  FBoundaries[NewIndex] := PositionSeconds;
  Result := True;
end;

function TManualSyncEditModel.BoundaryCount: Integer;
begin
  Result := Length(FBoundaries);
end;

function TManualSyncEditModel.BoundarySeconds(Index: Integer): Double;
begin
  if (Index < 0) or (Index >= Length(FBoundaries)) then
    raise EArgumentOutOfRangeException.Create('Boundary index');
  Result := FBoundaries[Index];
end;

function TManualSyncEditModel.Complete: Boolean;
begin
  Result := (FUnitCount > 0) and
    (Length(FBoundaries) = FUnitCount + 1);
end;

function TManualSyncEditModel.MoveBoundary(Index: Integer;
  PositionSeconds: Double): Boolean;
var
  MaximumValue: Double;
  MinimumValue: Double;
begin
  Result := False;
  if (Index < 0) or (Index >= Length(FBoundaries)) then
    Exit;
  MinimumValue := 0;
  MaximumValue := FAudioDurationSeconds;
  if Index > 0 then
    MinimumValue := FBoundaries[Index - 1] + MIN_BOUNDARY_DISTANCE;
  if Index < High(FBoundaries) then
    MaximumValue := FBoundaries[Index + 1] - MIN_BOUNDARY_DISTANCE;
  if MaximumValue < MinimumValue then
    Exit;
  PositionSeconds := EnsureRange(PositionSeconds, MinimumValue,
    MaximumValue);
  if SameValue(FBoundaries[Index], PositionSeconds, 0.0000001) then
    Exit;
  FBoundaries[Index] := PositionSeconds;
  Result := True;
end;

function TManualSyncEditModel.MoveLineStart(
  PositionSeconds: Double): Boolean;
begin
  Result := MoveSuffix(0, PositionSeconds);
end;

function TManualSyncEditModel.MoveSuffix(Index: Integer;
  PositionSeconds: Double): Boolean;
var
  DeltaSeconds: Double;
  I: Integer;
  MaximumPosition: Double;
  MinimumPosition: Double;
begin
  Result := False;
  if (Length(FBoundaries) < 2) or
    (Index < 0) or (Index >= High(FBoundaries)) then
    Exit;
  MinimumPosition := 0;
  if Index > 0 then
    MinimumPosition := FBoundaries[Index - 1] +
      MIN_BOUNDARY_DISTANCE;
  MaximumPosition := FAudioDurationSeconds -
    (FBoundaries[High(FBoundaries)] - FBoundaries[Index]);
  if MaximumPosition < MinimumPosition then
    Exit;
  PositionSeconds := EnsureRange(PositionSeconds,
    MinimumPosition, MaximumPosition);
  DeltaSeconds := PositionSeconds - FBoundaries[Index];
  if SameValue(DeltaSeconds, 0.0, 0.0000001) then
    Exit;
  for I := Index to High(FBoundaries) do
    FBoundaries[I] := FBoundaries[I] + DeltaSeconds;
  Result := True;
end;

procedure TManualSyncEditModel.RearmTimingInput;
begin
  FTimingInputStarted := False;
end;

function TManualSyncEditModel.SerializeSyncText: string;
begin
  if not Complete then
    raise EInvalidOpException.Create(
      'すべての同期位置が入力されていません。');
  Result := SYNC_Lyrics_SyncFormat.SerializeManualSyncText(FBoundaries);
end;

end.
