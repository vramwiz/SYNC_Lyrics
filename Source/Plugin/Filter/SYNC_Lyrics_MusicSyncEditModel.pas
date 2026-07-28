unit SYNC_Lyrics_MusicSyncEditModel;

// 曲同期GUIの歌詞単位、同期グループ、ドラッグ編集、保存形式変換を管理する。
// 描画座標やVCLコントロールには依存せず、フォームと各描画層の共通モデルとする。

interface

type
  TLyricEditUnit = record
    PrefixText: string;
    Text: string;
    SuffixText: string;
    RubyText: string;
    ConsumesNote: Boolean;
  end;
  TLyricEditUnits = TArray<TLyricEditUnit>;

  TMusicSyncEditGroup = record
    UnitStart: Integer;
    UnitCount: Integer;
    NoteCount: Integer;
  end;
  TMusicSyncEditGroups = TArray<TMusicSyncEditGroup>;

  TMusicSyncEditModel = class
  private
    FDragGroupEnd: Integer;
    FDragGroupIndex: Integer;
    FDragGroupNoteCount: Integer;
    FDragGroupStart: Integer;
    FDragOriginalGroups: TMusicSyncEditGroups;
    FDefaultSyncGenerated: Boolean;
    FSelectedUnitIndex: Integer;
    procedure AppendGroup(var Target: TMusicSyncEditGroups;
      UnitCount, NoteCount: Integer);
    procedure AppendPreservedGroups(const Source: TMusicSyncEditGroups;
      FirstUnit, LastUnit: Integer; var Target: TMusicSyncEditGroups);
    procedure BuildDefaultGroups;
    procedure RebuildIndexes;
    procedure RebuildGroupsAfterLyricsEdit(
      const OldUnits: TLyricEditUnits;
      const OldGroups: TMusicSyncEditGroups);
  public
    Groups: TMusicSyncEditGroups;
    UnitGroupIndexes: TArray<Integer>;
    UnitNoteIndexes: TArray<Integer>;
    Units: TLyricEditUnits;
    constructor Create;
    // 歌詞構文を表示単位へ変換し、編集前と重なる範囲の同期グループを保持する。
    procedure SetLyrics(const Lyrics: string);
    // 保存済みstagesを、開始歌詞・歌詞数・音数を持つ編集グループへ展開する。
    procedure LoadSyncText(const SyncText: string);
    // 全表示単位を1文字1音の独立グループへ戻す。
    procedure Reset;
    // 選択時点の所属グループを固定し、以後のドラッグ量を同じ基準から評価する。
    function BeginDrag(UnitIndex: Integer): Boolean;
    // 左は直前グループとの結合、右は共有からの分離または担当音数増加として反映する。
    procedure ApplyDragStep(Step: Integer);
    procedure EndDrag;
    // 1表示単位が複数音を使う場合だけ、本文中の文字が移る同期ノート番号を返す。
    function TryGetExpandedCharacterNoteIndex(UnitIndex,
      CharacterIndex: Integer; out NoteIndex: Integer): Boolean;
    // 編集グループをFilterが使用するstages形式へ圧縮する。
    function SerializeSyncText: string;
    property DefaultSyncGenerated: Boolean read FDefaultSyncGenerated;
    property SelectedUnitIndex: Integer read FSelectedUnitIndex
      write FSelectedUnitIndex;
  end;

implementation

uses
  System.Math,
  SYNC_Lyrics_LyricParser,
  SYNC_Lyrics_SyncFormat;

type
  TIntegerMatrix = TArray<TArray<Integer>>;

constructor TMusicSyncEditModel.Create;
begin
  inherited Create;
  FSelectedUnitIndex := -1;
end;

procedure TMusicSyncEditModel.BuildDefaultGroups;
var
  UnitIndex: Integer;
begin
  SetLength(Groups, 0);
  for UnitIndex := 0 to High(Units) do
    AppendGroup(Groups, 1, 1);
  RebuildIndexes;
end;

procedure TMusicSyncEditModel.AppendGroup(
  var Target: TMusicSyncEditGroups; UnitCount, NoteCount: Integer);
var
  GroupIndex: Integer;
begin
  if UnitCount <= 0 then
    Exit;
  GroupIndex := Length(Target);
  SetLength(Target, GroupIndex + 1);
  if GroupIndex = 0 then
    Target[GroupIndex].UnitStart := 0
  else
    Target[GroupIndex].UnitStart :=
      Target[GroupIndex - 1].UnitStart +
      Target[GroupIndex - 1].UnitCount;
  Target[GroupIndex].UnitCount := UnitCount;
  Target[GroupIndex].NoteCount := Max(1, NoteCount);
end;

procedure TMusicSyncEditModel.AppendPreservedGroups(
  const Source: TMusicSyncEditGroups; FirstUnit, LastUnit: Integer;
  var Target: TMusicSyncEditGroups);
var
  GroupEnd: Integer;
  GroupIndex: Integer;
  IntersectionEnd: Integer;
  IntersectionStart: Integer;
  PreservedNoteCount: Integer;
begin
  if FirstUnit > LastUnit then
    Exit;
  for GroupIndex := 0 to High(Source) do
  begin
    GroupEnd := Source[GroupIndex].UnitStart +
      Source[GroupIndex].UnitCount - 1;
    IntersectionStart := Max(FirstUnit, Source[GroupIndex].UnitStart);
    IntersectionEnd := Min(LastUnit, GroupEnd);
    if IntersectionStart > IntersectionEnd then
      Continue;
    if Source[GroupIndex].UnitCount = 1 then
      PreservedNoteCount := Source[GroupIndex].NoteCount
    else
      PreservedNoteCount := 1;
    AppendGroup(Target, IntersectionEnd - IntersectionStart + 1,
      PreservedNoteCount);
  end;
end;

procedure TMusicSyncEditModel.RebuildIndexes;
var
  GroupIndex: Integer;
  I: Integer;
  NoteIndex: Integer;
begin
  SetLength(UnitGroupIndexes, Length(Units));
  SetLength(UnitNoteIndexes, Length(Units));
  for I := 0 to High(UnitGroupIndexes) do
  begin
    UnitGroupIndexes[I] := -1;
    UnitNoteIndexes[I] := -1;
  end;
  NoteIndex := 0;
  for GroupIndex := 0 to High(Groups) do
  begin
    for I := Groups[GroupIndex].UnitStart to
      Min(High(UnitNoteIndexes), Groups[GroupIndex].UnitStart +
        Groups[GroupIndex].UnitCount - 1) do
    begin
      UnitGroupIndexes[I] := GroupIndex;
      UnitNoteIndexes[I] := NoteIndex;
    end;
    Inc(NoteIndex, Groups[GroupIndex].NoteCount);
  end;
end;

procedure TMusicSyncEditModel.RebuildGroupsAfterLyricsEdit(
  const OldUnits: TLyricEditUnits;
  const OldGroups: TMusicSyncEditGroups);
var
  CanPreserve: Boolean;
  GroupIndex: Integer;
  I: Integer;
  J: Integer;
  MatchLengths: TIntegerMatrix;
  NewGroups: TMusicSyncEditGroups;
  NewIndex: Integer;
  NewToOld: TArray<Integer>;
  OldIndex: Integer;
  OldStartGroupIndexes: TArray<Integer>;
  OldToNew: TArray<Integer>;
  PreservedGroupIndex: Integer;
begin
  SetLength(NewToOld, Length(Units));
  for I := 0 to High(NewToOld) do
    NewToOld[I] := -1;
  SetLength(OldToNew, Length(OldUnits));
  for I := 0 to High(OldToNew) do
    OldToNew[I] := -1;

  // 本文が一致する発音単位の最長共通部分列を求める。
  // ルビや付随記号だけの編集では同期を維持できるよう、本文だけを比較する。
  SetLength(MatchLengths, Length(OldUnits) + 1);
  for I := 0 to High(MatchLengths) do
    SetLength(MatchLengths[I], Length(Units) + 1);
  for I := High(OldUnits) downto 0 do
    for J := High(Units) downto 0 do
      if OldUnits[I].Text = Units[J].Text then
        MatchLengths[I][J] := MatchLengths[I + 1][J + 1] + 1
      else
        MatchLengths[I][J] := Max(MatchLengths[I + 1][J],
          MatchLengths[I][J + 1]);
  I := 0;
  J := 0;
  while (I < Length(OldUnits)) and (J < Length(Units)) do
    if OldUnits[I].Text = Units[J].Text then
    begin
      OldToNew[I] := J;
      NewToOld[J] := I;
      Inc(I);
      Inc(J);
    end
    else if MatchLengths[I + 1][J] >= MatchLengths[I][J + 1] then
      Inc(I)
    else
      Inc(J);

  SetLength(OldStartGroupIndexes, Length(OldUnits));
  for I := 0 to High(OldStartGroupIndexes) do
    OldStartGroupIndexes[I] := -1;
  for GroupIndex := 0 to High(OldGroups) do
    if (OldGroups[GroupIndex].UnitStart >= 0) and
      (OldGroups[GroupIndex].UnitStart <
        Length(OldStartGroupIndexes)) then
      OldStartGroupIndexes[OldGroups[GroupIndex].UnitStart] :=
        GroupIndex;

  SetLength(NewGroups, 0);
  NewIndex := 0;
  while NewIndex < Length(Units) do
  begin
    CanPreserve := False;
    PreservedGroupIndex := -1;
    OldIndex := NewToOld[NewIndex];
    if (OldIndex >= 0) and
      (OldIndex < Length(OldStartGroupIndexes)) then
    begin
      PreservedGroupIndex := OldStartGroupIndexes[OldIndex];
      if PreservedGroupIndex >= 0 then
      begin
        CanPreserve :=
          NewIndex + OldGroups[PreservedGroupIndex].UnitCount <=
            Length(Units);
        if CanPreserve then
          for I := 0 to OldGroups[PreservedGroupIndex].UnitCount - 1 do
            if (OldIndex + I >= Length(OldToNew)) or
              (OldToNew[OldIndex + I] <> NewIndex + I) then
            begin
              CanPreserve := False;
              Break;
            end;
      end;
    end;
    if CanPreserve then
    begin
      AppendGroup(NewGroups,
        OldGroups[PreservedGroupIndex].UnitCount,
        OldGroups[PreservedGroupIndex].NoteCount);
      Inc(NewIndex, OldGroups[PreservedGroupIndex].UnitCount);
    end
    else
    begin
      AppendGroup(NewGroups, 1, 1);
      Inc(NewIndex);
    end;
  end;
  Groups := NewGroups;
  RebuildIndexes;

  if Length(Units) = 0 then
    FSelectedUnitIndex := -1
  else if (FSelectedUnitIndex >= 0) and
    (FSelectedUnitIndex < Length(OldToNew)) and
    (OldToNew[FSelectedUnitIndex] >= 0) then
    FSelectedUnitIndex := OldToNew[FSelectedUnitIndex]
  else if FSelectedUnitIndex < 0 then
    FSelectedUnitIndex := 0
  else
    FSelectedUnitIndex := Min(FSelectedUnitIndex, High(Units));
end;

procedure TMusicSyncEditModel.SetLyrics(const Lyrics: string);
var
  I: Integer;
  NewUnits: TLyricEditUnits;
  OldGroups: TMusicSyncEditGroups;
  OldUnits: TLyricEditUnits;
  PendingPrefix: string;
  PlainText: string;
  RubySpans: TLyricsRubySpans;
  ParsedUnits: TLyricsDisplayUnits;
  ParsedText: string;
  UnitIndex: Integer;
begin
  OldUnits := Copy(Units);
  OldGroups := Copy(Groups);
  ParseLyrics(Lyrics, PlainText, RubySpans);
  BuildLyricsDisplayUnits(PlainText, RubySpans, ParsedUnits);
  SetLength(NewUnits, 0);
  PendingPrefix := '';
  for I := 0 to High(ParsedUnits) do
  begin
    ParsedText := Copy(PlainText, ParsedUnits[I].BaseStart,
      ParsedUnits[I].BaseLength);
    if not ParsedUnits[I].ConsumesNote then
    begin
      if Length(NewUnits) = 0 then
        PendingPrefix := PendingPrefix + ParsedText
      else
        NewUnits[High(NewUnits)].SuffixText :=
          NewUnits[High(NewUnits)].SuffixText + ParsedText;
      Continue;
    end;

    UnitIndex := Length(NewUnits);
    SetLength(NewUnits, UnitIndex + 1);
    NewUnits[UnitIndex].PrefixText := PendingPrefix;
    PendingPrefix := '';
    NewUnits[UnitIndex].Text := ParsedText;
    NewUnits[UnitIndex].SuffixText := '';
    NewUnits[UnitIndex].ConsumesNote := True;
    if ParsedUnits[I].RubyIndex >= 0 then
      NewUnits[UnitIndex].RubyText :=
        RubySpans[ParsedUnits[I].RubyIndex].RubyText
    else
      NewUnits[UnitIndex].RubyText := '';
  end;
  Units := NewUnits;
  RebuildGroupsAfterLyricsEdit(OldUnits, OldGroups);
end;

procedure TMusicSyncEditModel.LoadSyncText(const SyncText: string);
var
  Data: TSyncTextData;
  NoteCount: Integer;
  StageIndex: Integer;
  StageValue: Integer;
  UnitCount: Integer;
  UnitIndex: Integer;
begin
  SetLength(Groups, 0);
  if not TryParseSyncText(SyncText, Data) or
    (Data.Mode <> smMusic) then
    SetLength(Data.MusicStages, 0);
  FDefaultSyncGenerated := Length(Data.MusicStages) = 0;
  if FDefaultSyncGenerated then
  begin
    BuildDefaultGroups;
    Exit;
  end;
  StageIndex := 0;
  UnitIndex := 0;
  while UnitIndex < Length(Units) do
  begin
    if StageIndex < Length(Data.MusicStages) then
      StageValue := Data.MusicStages[StageIndex]
    else
      StageValue := 0;
    if StageValue < 0 then
    begin
      UnitCount := Min(Abs(StageValue) + 1,
        Length(Units) - UnitIndex);
      NoteCount := 1;
    end
    else
    begin
      UnitCount := 1;
      NoteCount := StageValue + 1;
    end;
    AppendGroup(Groups, UnitCount, NoteCount);
    Inc(UnitIndex, UnitCount);
    Inc(StageIndex);
  end;
  RebuildIndexes;
end;

procedure TMusicSyncEditModel.Reset;
begin
  FDefaultSyncGenerated := True;
  SetLength(FDragOriginalGroups, 0);
  BuildDefaultGroups;
end;

function TMusicSyncEditModel.BeginDrag(UnitIndex: Integer): Boolean;
var
  GroupIndex: Integer;
begin
  Result := False;
  if (UnitIndex < 0) or (UnitIndex >= Length(UnitGroupIndexes)) then
    Exit;
  GroupIndex := UnitGroupIndexes[UnitIndex];
  if (GroupIndex < 0) or (GroupIndex >= Length(Groups)) then
    Exit;
  FSelectedUnitIndex := UnitIndex;
  FDragGroupIndex := GroupIndex;
  FDragOriginalGroups := Copy(Groups);
  FDragGroupStart := Groups[GroupIndex].UnitStart;
  FDragGroupEnd := FDragGroupStart + Groups[GroupIndex].UnitCount - 1;
  FDragGroupNoteCount := Groups[GroupIndex].NoteCount;
  Result := True;
end;

procedure TMusicSyncEditModel.ApplyDragStep(Step: Integer);
var
  DesiredGroupIndex: Integer;
  DesiredStart: Integer;
  LeftUnitCount: Integer;
  NewGroups: TMusicSyncEditGroups;
  RightUnitCount: Integer;
  TotalUnitCount: Integer;
begin
  if (FSelectedUnitIndex < 0) or
    (FSelectedUnitIndex >= Length(Units)) or
    (Length(FDragOriginalGroups) = 0) then
    Exit;
  Groups := Copy(FDragOriginalGroups);
  if Step = 0 then
  begin
    RebuildIndexes;
    Exit;
  end;

  TotalUnitCount := Length(Units);
  SetLength(NewGroups, 0);
  if Step < 0 then
  begin
    DesiredGroupIndex := Max(0, FDragGroupIndex + Step);
    DesiredStart := FDragOriginalGroups[DesiredGroupIndex].UnitStart;
    AppendPreservedGroups(FDragOriginalGroups, 0,
      DesiredStart - 1, NewGroups);
    AppendGroup(NewGroups, FDragGroupEnd - DesiredStart + 1, 1);
    AppendPreservedGroups(FDragOriginalGroups, FDragGroupEnd + 1,
      TotalUnitCount - 1, NewGroups);
  end
  else if FDragGroupEnd > FDragGroupStart then
  begin
    AppendPreservedGroups(FDragOriginalGroups, 0,
      FDragGroupStart - 1, NewGroups);
    LeftUnitCount := FSelectedUnitIndex - FDragGroupStart;
    RightUnitCount := FDragGroupEnd - FSelectedUnitIndex;
    AppendGroup(NewGroups, LeftUnitCount, 1);
    AppendGroup(NewGroups, 1, 1);
    AppendGroup(NewGroups, RightUnitCount, 1);
    AppendPreservedGroups(FDragOriginalGroups, FDragGroupEnd + 1,
      TotalUnitCount - 1, NewGroups);
  end
  else
  begin
    AppendPreservedGroups(FDragOriginalGroups, 0,
      FDragGroupStart - 1, NewGroups);
    AppendGroup(NewGroups, 1, Min(64, FDragGroupNoteCount + Step));
    AppendPreservedGroups(FDragOriginalGroups, FDragGroupEnd + 1,
      TotalUnitCount - 1, NewGroups);
  end;
  Groups := NewGroups;
  RebuildIndexes;
end;

procedure TMusicSyncEditModel.EndDrag;
begin
  SetLength(FDragOriginalGroups, 0);
end;

function TMusicSyncEditModel.TryGetExpandedCharacterNoteIndex(
  UnitIndex, CharacterIndex: Integer; out NoteIndex: Integer): Boolean;
var
  CharacterCount: Integer;
  GroupIndex: Integer;
  NoteOffset: Integer;
begin
  Result := False;
  NoteIndex := -1;
  if (UnitIndex < 0) or (UnitIndex >= Length(Units)) or
    (UnitIndex >= Length(UnitGroupIndexes)) or
    (UnitIndex >= Length(UnitNoteIndexes)) then
    Exit;
  GroupIndex := UnitGroupIndexes[UnitIndex];
  if (GroupIndex < 0) or (GroupIndex >= Length(Groups)) or
    (Groups[GroupIndex].UnitCount <> 1) or
    (Groups[GroupIndex].NoteCount <= 1) then
    Exit;
  CharacterCount := Length(Units[UnitIndex].Text);
  if (CharacterIndex < 0) or (CharacterIndex >= CharacterCount) then
    Exit;

  // 1音時は本文を通常の文字間隔で表示する。複数音へ広げた時だけ、
  // 先頭文字を元の音へ残し、後続文字を担当音の開始位置へ移す。
  if CharacterCount <= 1 then
    NoteOffset := 0
  else
    NoteOffset := Round(CharacterIndex *
      (Groups[GroupIndex].NoteCount - 1) / (CharacterCount - 1));
  NoteOffset := EnsureRange(NoteOffset, 0,
    Groups[GroupIndex].NoteCount - 1);
  NoteIndex := UnitNoteIndexes[UnitIndex] + NoteOffset;
  Result := True;
end;

function TMusicSyncEditModel.SerializeSyncText: string;
var
  GroupIndex: Integer;
  LastNonZero: Integer;
  Stages: TArray<Integer>;
begin
  SetLength(Stages, Length(Groups));
  for GroupIndex := 0 to High(Groups) do
    if Groups[GroupIndex].UnitCount > 1 then
      Stages[GroupIndex] := -(Groups[GroupIndex].UnitCount - 1)
    else
      Stages[GroupIndex] := Groups[GroupIndex].NoteCount - 1;
  LastNonZero := High(Stages);
  while (LastNonZero >= 0) and (Stages[LastNonZero] = 0) do
    Dec(LastNonZero);
  SetLength(Stages, LastNonZero + 1);
  Result := SerializeMusicSyncText(Stages);
end;

end.
