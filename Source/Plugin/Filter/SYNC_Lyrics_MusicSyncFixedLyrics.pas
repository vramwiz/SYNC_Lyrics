unit SYNC_Lyrics_MusicSyncFixedLyrics;

// ピアノロール下部の固定Y歌詞レーンを描画する。
// 各文字を同期先ノートの開始Xへ合わせ、音程とは独立した固定Yへ配置する。

interface

uses
  System.Types,
  Vcl.Graphics,
  SYNC_Lyrics_MusicSyncEditModel,
  SYNC_Lyrics_MusicSyncPianoRoll;

// 本文とルビを固定レーンへ描画し、上段と共通の歌詞単位別ヒット領域を返す。
procedure DrawFixedLyrics(Canvas: TCanvas; PianoWidth,
  PianoHeight: Integer; const Model: TMusicSyncEditModel;
  const Layout: TPianoRollLayout; var HitRects: TArray<TRect>);

// 描画時に作成した矩形から、固定レーン上の歌詞単位を返す。
function HitTestFixedLyrics(const HitRects: TArray<TRect>;
  X, Y: Integer): Integer;

implementation

uses
  System.Math,
  Winapi.Windows;

procedure DrawFixedLyrics(Canvas: TCanvas; PianoWidth,
  PianoHeight: Integer; const Model: TMusicSyncEditModel;
  const Layout: TPianoRollLayout; var HitRects: TArray<TRect>);
var
  BaseChar: string;
  CharacterX: Integer;
  CharacterXCursor: Integer;
  CharCount: Integer;
  CharIndex: Integer;
  CharacterNoteIndex: Integer;
  CoreEndX: Integer;
  CoreStartX: Integer;
  GroupEndNote: Integer;
  GroupIndex: Integer;
  GroupStartNote: Integer;
  NoteRect: TRect;
  PrefixText: string;
  PrefixWidth: Integer;
  RubyText: string;
  SpanLeft: Integer;
  SuffixText: string;
  TextHeight: Integer;
  TextWidth: Integer;
  UnitEndX: Integer;
  UnitIndex: Integer;
  UnitStartX: Integer;
begin
  SetLength(HitRects, Length(Model.Units));
  for UnitIndex := 0 to High(HitRects) do
    HitRects[UnitIndex] := Rect(0, 0, 0, 0);

  Canvas.Brush.Color := RGB(16, 19, 26);
  Canvas.FillRect(Rect(0, Layout.RollHeight, PianoWidth, PianoHeight));
  Canvas.Pen.Width := ScaleMusicSyncMetric(1, Layout.Dpi);
  Canvas.Pen.Color := RGB(82, 89, 104);
  Canvas.MoveTo(0, Layout.RollHeight);
  Canvas.LineTo(PianoWidth, Layout.RollHeight);

  for GroupIndex := 0 to High(Model.Groups) do
  begin
    if (Model.Groups[GroupIndex].UnitStart < 0) or
      (Model.Groups[GroupIndex].UnitStart >=
        Length(Model.UnitNoteIndexes)) then
      Continue;
    GroupStartNote :=
      Model.UnitNoteIndexes[Model.Groups[GroupIndex].UnitStart];
    GroupEndNote := GroupStartNote +
      Model.Groups[GroupIndex].NoteCount - 1;
    if (GroupStartNote < 0) or
      (GroupEndNote >= Length(Layout.SyncNoteRects)) then
      Continue;
    NoteRect := Layout.SyncNoteRects[GroupStartNote];
    if NoteRect.Right <= NoteRect.Left then
      Continue;
    SpanLeft := NoteRect.Left;
    NoteRect := Layout.SyncNoteRects[GroupEndNote];
    if NoteRect.Right <= NoteRect.Left then
      Continue;

    CharacterXCursor := SpanLeft;
    for UnitIndex := Model.Groups[GroupIndex].UnitStart to
      Model.Groups[GroupIndex].UnitStart +
        Model.Groups[GroupIndex].UnitCount - 1 do
    begin
      if UnitIndex >= Length(Model.Units) then
        Break;
      CharCount := Length(Model.Units[UnitIndex].Text);
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Name := 'Segoe UI';
      Canvas.Font.Height :=
        -ScaleMusicSyncMetric(15, Layout.Dpi);
      Canvas.Font.Style := [];
      Canvas.Font.Color := RGB(238, 242, 248);
      TextHeight := Canvas.TextHeight('漢');
      PrefixText := Model.Units[UnitIndex].PrefixText;
      PrefixWidth := Canvas.TextWidth(PrefixText);
      UnitStartX := CharacterXCursor;
      UnitEndX := CharacterXCursor;
      if PrefixText <> '' then
      begin
        Canvas.TextOut(CharacterXCursor, Layout.RollHeight +
          ScaleMusicSyncMetric(28, Layout.Dpi), PrefixText);
        Inc(CharacterXCursor, PrefixWidth);
        UnitEndX := CharacterXCursor;
      end;
      CoreStartX := -1;
      CoreEndX := -1;
      for CharIndex := 1 to CharCount do
      begin
        if Model.TryGetExpandedCharacterNoteIndex(UnitIndex,
          CharIndex - 1, CharacterNoteIndex) and
          (CharacterNoteIndex >= 0) and
          (CharacterNoteIndex < Length(Layout.SyncNoteRects)) then
        begin
          CharacterX :=
            Layout.SyncNoteRects[CharacterNoteIndex].Left;
          if CharIndex = 1 then
            Inc(CharacterX, PrefixWidth);
        end
        else
          CharacterX := CharacterXCursor;
        BaseChar := Copy(Model.Units[UnitIndex].Text, CharIndex, 1);
        TextWidth := Canvas.TextWidth(BaseChar);
        if CoreStartX < 0 then
          CoreStartX := CharacterX;
        UnitStartX := Min(UnitStartX, CharacterX);
        Canvas.TextOut(CharacterX, Layout.RollHeight +
          ScaleMusicSyncMetric(28, Layout.Dpi), BaseChar);
        CoreEndX := Max(CoreEndX, CharacterX + TextWidth);
        UnitEndX := Max(UnitEndX, CoreEndX);
        if Model.Groups[GroupIndex].NoteCount <= 1 then
          CharacterXCursor := UnitEndX;
      end;
      SuffixText := Model.Units[UnitIndex].SuffixText;
      if SuffixText <> '' then
      begin
        Canvas.TextOut(UnitEndX, Layout.RollHeight +
          ScaleMusicSyncMetric(28, Layout.Dpi), SuffixText);
        UnitEndX := UnitEndX + Canvas.TextWidth(SuffixText);
        if Model.Groups[GroupIndex].NoteCount <= 1 then
          CharacterXCursor := UnitEndX;
      end;
      if UnitStartX >= 0 then
      begin
        HitRects[UnitIndex] := Rect(Max(0, UnitStartX -
          ScaleMusicSyncMetric(3, Layout.Dpi)),
          Layout.RollHeight + ScaleMusicSyncMetric(26, Layout.Dpi),
          Min(PianoWidth, UnitEndX +
            ScaleMusicSyncMetric(3, Layout.Dpi)),
          Min(PianoHeight, Layout.RollHeight +
            ScaleMusicSyncMetric(30, Layout.Dpi) + TextHeight));
        if UnitIndex = Model.SelectedUnitIndex then
        begin
          Canvas.Pen.Width :=
            ScaleMusicSyncMetric(2, Layout.Dpi);
          Canvas.Pen.Color := RGB(255, 210, 70);
          Canvas.Rectangle(HitRects[UnitIndex]);
          Canvas.Pen.Width :=
            ScaleMusicSyncMetric(1, Layout.Dpi);
        end;
      end;
      RubyText := Model.Units[UnitIndex].RubyText;
      if (RubyText <> '') and (CoreStartX >= 0) then
      begin
        Canvas.Font.Height :=
          -ScaleMusicSyncMetric(11, Layout.Dpi);
        Canvas.Font.Color := RGB(185, 194, 208);
        TextWidth := Canvas.TextWidth(RubyText);
        Canvas.TextOut(CoreStartX +
          (CoreEndX - CoreStartX - TextWidth) div 2,
          Layout.RollHeight +
            ScaleMusicSyncMetric(8, Layout.Dpi), RubyText);
      end;
    end;
  end;
  Canvas.Brush.Style := bsSolid;
end;

function HitTestFixedLyrics(const HitRects: TArray<TRect>;
  X, Y: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(HitRects) do
    if PtInRect(HitRects[I], Point(X, Y)) then
      Exit(I);
end;

end.
