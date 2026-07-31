unit SYNC_Lyrics_SyncFormat;

// 曲同期と手動同期で共用する、バージョン付き同期テキスト形式を読み書きする。

interface

type
  TSyncMode = (smUnknown, smMusic, smManual);
  TSyncIntegerArray = array of Integer;
  TSyncDoubleArray = array of Double;

  TSyncTextData = record
    Version: Integer;               // テキスト形式のバージョン
    Mode: TSyncMode;                // 同期元の種類
    MusicStages: TSyncIntegerArray; // 曲同期で順番に適用する音数・表示単位数の対応値
    ManualBoundaries: TSyncDoubleArray; // 手動同期の各表示単位を囲むWAV先頭基準秒
  end;

const
  SYNC_TEXT_VERSION = 1;
  DEFAULT_MUSIC_SYNC_TEXT = 'SYNC_LYRICS_SYNC/1;mode=music;stages=';

// ヘッダとモードを検証し、対応形式だけをDataへ復元する。失敗時はDataを空へ戻す。
function TryParseSyncText(const Text: string; out Data: TSyncTextData): Boolean;

// 曲同期の段階値を、現在の形式バージョンを持つ共通テキストへ変換する。
function SerializeMusicSyncText(const Stages: array of Integer): string;

// 手動同期の境界秒列を、現在の形式バージョンを持つ共通テキストへ変換する。
function SerializeManualSyncText(const Boundaries: array of Double): string;

// Returns how many sequential music notes the stages consume for the given units.
function CountMusicSyncRequiredNotes(const Text: string;
  DisplayUnitCount: Integer): Integer;

implementation

uses
  System.Math,
  System.StrUtils,
  System.SysUtils;

const
  SYNC_TEXT_HEADER = 'SYNC_LYRICS_SYNC/';
  MIN_MUSIC_STAGE_VALUE = -63;
  MAX_MUSIC_STAGE_VALUE = 63;
  MAX_MANUAL_BOUNDARY_COUNT = 65536;
  MANUAL_TIME_EPSILON = 0.000001;

procedure ClearSyncTextData(out Data: TSyncTextData);
begin
  Data.Version := 0;
  Data.Mode := smUnknown;
  SetLength(Data.MusicStages, 0);
  SetLength(Data.ManualBoundaries, 0);
end;

function ParseMusicStages(const Value: string;
  out Stages: TSyncIntegerArray): Boolean;
var
  I: Integer;
  Parts: TArray<string>;
  StageValue: Integer;
begin
  SetLength(Stages, 0);
  if Value = '' then
    Exit(True);

  Parts := Value.Split([',']);
  SetLength(Stages, Length(Parts));
  for I := 0 to High(Parts) do
  begin
    if not TryStrToInt(Trim(Parts[I]), StageValue) or
      (StageValue < MIN_MUSIC_STAGE_VALUE) or
      (StageValue > MAX_MUSIC_STAGE_VALUE) then
    begin
      SetLength(Stages, 0);
      Exit(False);
    end;
    Stages[I] := StageValue;
  end;
  Result := True;
end;

function ParseManualBoundaries(const Value: string;
  out Boundaries: TSyncDoubleArray): Boolean;
var
  Boundary: Double;
  I: Integer;
  Parts: TArray<string>;
begin
  SetLength(Boundaries, 0);
  if Value = '' then
    Exit(True);

  Parts := Value.Split([',']);
  if Length(Parts) > MAX_MANUAL_BOUNDARY_COUNT then
    Exit(False);
  SetLength(Boundaries, Length(Parts));
  for I := 0 to High(Parts) do
  begin
    if not TryStrToFloat(Trim(Parts[I]), Boundary,
      TFormatSettings.Invariant) or IsNan(Boundary) or IsInfinite(Boundary) or
      (Boundary < 0) or
      ((I > 0) and
      (Boundary <= Boundaries[I - 1] + MANUAL_TIME_EPSILON)) then
    begin
      SetLength(Boundaries, 0);
      Exit(False);
    end;
    Boundaries[I] := Boundary;
  end;
  Result := True;
end;

function TryParseSyncText(const Text: string; out Data: TSyncTextData): Boolean;
var
  BoundariesFound: Boolean;
  HeaderVersion: Integer;
  I: Integer;
  Key: string;
  ModeFound: Boolean;
  Pair: TArray<string>;
  Parts: TArray<string>;
  StagesFound: Boolean;
  Value: string;
begin
  ClearSyncTextData(Data);
  Parts := Text.Split([';']);
  if (Length(Parts) < 2) or
    not StartsText(SYNC_TEXT_HEADER, Trim(Parts[0])) or
    not TryStrToInt(Copy(Trim(Parts[0]), Length(SYNC_TEXT_HEADER) + 1,
      MaxInt), HeaderVersion) or
    (HeaderVersion <> SYNC_TEXT_VERSION) then
    Exit(False);

  Data.Version := HeaderVersion;
  BoundariesFound := False;
  ModeFound := False;
  StagesFound := False;
  for I := 1 to High(Parts) do
  begin
    Pair := Parts[I].Split(['=']);
    if Length(Pair) <> 2 then
    begin
      ClearSyncTextData(Data);
      Exit(False);
    end;
    Key := LowerCase(Trim(Pair[0]));
    Value := Trim(Pair[1]);
    if Key = 'mode' then
    begin
      if ModeFound then
      begin
        ClearSyncTextData(Data);
        Exit(False);
      end;
      ModeFound := True;
      if SameText(Value, 'music') then
        Data.Mode := smMusic
      else if SameText(Value, 'manual') then
        Data.Mode := smManual
      else
      begin
        ClearSyncTextData(Data);
        Exit(False);
      end;
    end
    else if Key = 'stages' then
    begin
      if StagesFound or not ParseMusicStages(Value, Data.MusicStages) then
      begin
        ClearSyncTextData(Data);
        Exit(False);
      end;
      StagesFound := True;
    end
    else if Key = 'boundaries' then
    begin
      if BoundariesFound or
        not ParseManualBoundaries(Value, Data.ManualBoundaries) then
      begin
        ClearSyncTextData(Data);
        Exit(False);
      end;
      BoundariesFound := True;
    end
    else
    begin
      ClearSyncTextData(Data);
      Exit(False);
    end;
  end;

  Result := ModeFound and
    (((Data.Mode = smMusic) and StagesFound and not BoundariesFound) or
    ((Data.Mode = smManual) and BoundariesFound and not StagesFound));
  if not Result then
    ClearSyncTextData(Data);
end;

function SerializeMusicSyncText(const Stages: array of Integer): string;
var
  I: Integer;
  StageValue: Integer;
begin
  Result := DEFAULT_MUSIC_SYNC_TEXT;
  for I := 0 to High(Stages) do
  begin
    if I > 0 then
      Result := Result + ',';
    StageValue := Stages[I];
    if StageValue < MIN_MUSIC_STAGE_VALUE then
      StageValue := MIN_MUSIC_STAGE_VALUE
    else if StageValue > MAX_MUSIC_STAGE_VALUE then
      StageValue := MAX_MUSIC_STAGE_VALUE;
    Result := Result + IntToStr(StageValue);
  end;
end;

function SerializeManualSyncText(const Boundaries: array of Double): string;
var
  Boundary: Double;
  I: Integer;
  Previous: Double;
begin
  Result := 'SYNC_LYRICS_SYNC/1;mode=manual;boundaries=';
  Previous := -1;
  for I := 0 to High(Boundaries) do
  begin
    Boundary := Boundaries[I];
    if IsNan(Boundary) or IsInfinite(Boundary) or (Boundary < 0) or
      ((I > 0) and (Boundary <= Previous + MANUAL_TIME_EPSILON)) then
      raise EArgumentException.Create(
        'Manual sync boundaries must be finite, non-negative and increasing');
    if I > 0 then
      Result := Result + ',';
    Result := Result + FloatToStr(Boundary, TFormatSettings.Invariant);
    Previous := Boundary;
  end;
end;

function CountMusicSyncRequiredNotes(const Text: string;
  DisplayUnitCount: Integer): Integer;
var
  Data: TSyncTextData;
  NoteCount: Integer;
  StageIndex: Integer;
  StageValue: Integer;
  UnitCount: Integer;
  UnitIndex: Integer;
begin
  Result := 0;
  DisplayUnitCount := Max(0, DisplayUnitCount);
  if not TryParseSyncText(Text, Data) or (Data.Mode <> smMusic) then
    SetLength(Data.MusicStages, 0);
  StageIndex := 0;
  UnitIndex := 0;
  while UnitIndex < DisplayUnitCount do
  begin
    if StageIndex <= High(Data.MusicStages) then
      StageValue := Data.MusicStages[StageIndex]
    else
      StageValue := 0;
    if StageValue < 0 then
    begin
      UnitCount := Min(Abs(StageValue) + 1,
        DisplayUnitCount - UnitIndex);
      NoteCount := 1;
    end
    else
    begin
      UnitCount := 1;
      NoteCount := StageValue + 1;
    end;
    Inc(Result, NoteCount);
    Inc(UnitIndex, UnitCount);
    Inc(StageIndex);
  end;
end;

end.
