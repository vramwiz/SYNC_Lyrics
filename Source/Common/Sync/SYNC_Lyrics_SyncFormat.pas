unit SYNC_Lyrics_SyncFormat;

// 曲同期と手動同期で共用する、バージョン付き同期テキスト形式を読み書きする。

interface

type
  TSyncMode = (smUnknown, smMusic, smManual);
  TSyncIntegerArray = array of Integer;

  TSyncTextData = record
    Version: Integer;               // テキスト形式のバージョン
    Mode: TSyncMode;                // 同期元の種類
    MusicStages: TSyncIntegerArray; // 曲同期で順番に適用する音数・表示単位数の対応値
  end;

const
  SYNC_TEXT_VERSION = 1;
  DEFAULT_MUSIC_SYNC_TEXT = 'SYNC_LYRICS_SYNC/1;mode=music;stages=';

// ヘッダとモードを検証し、対応形式だけをDataへ復元する。失敗時はDataを空へ戻す。
function TryParseSyncText(const Text: string; out Data: TSyncTextData): Boolean;

// 曲同期の段階値を、現在の形式バージョンを持つ共通テキストへ変換する。
function SerializeMusicSyncText(const Stages: array of Integer): string;

implementation

uses
  System.StrUtils,
  System.SysUtils;

const
  SYNC_TEXT_HEADER = 'SYNC_LYRICS_SYNC/';
  MIN_MUSIC_STAGE_VALUE = -63;
  MAX_MUSIC_STAGE_VALUE = 63;

procedure ClearSyncTextData(out Data: TSyncTextData);
begin
  Data.Version := 0;
  Data.Mode := smUnknown;
  SetLength(Data.MusicStages, 0);
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

function TryParseSyncText(const Text: string; out Data: TSyncTextData): Boolean;
var
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
    else
    begin
      ClearSyncTextData(Data);
      Exit(False);
    end;
  end;

  Result := ModeFound and
    (((Data.Mode = smMusic) and StagesFound) or
    ((Data.Mode = smManual) and not StagesFound));
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

end.
