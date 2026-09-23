unit SYNC_Lyrics_MusicSyncNoteLyrics;

// ノートの音程位置へ追従する歌詞表示と、仮想カーソル用ヒット領域を担当する。
// ドラッグによる同期グループ変更そのものは編集モデルへ委譲する。

interface

uses
  System.Types,
  Vcl.Graphics,
  SYNC_Lyrics_MusicSyncEditModel,
  SYNC_Lyrics_MusicSyncPianoRoll;

// 各同期ノートの直下へ対応歌詞を描き、選択可能な矩形を返す。
procedure DrawNoteFollowingLyrics(Canvas: TCanvas;
  const Model: TMusicSyncEditModel; const Layout: TPianoRollLayout;
  PianoWidth: Integer; var HitRects: TArray<TRect>);

// 前後行の歌詞を曲全体の音符番号へ合わせ、操作対象外の参考色で描画する。
procedure DrawReferenceNoteLyrics(Canvas: TCanvas;
  const Model: TMusicSyncEditModel; StartNoteIndex: Integer;
  const Layout: TPianoRollLayout; PianoWidth: Integer);

// 描画時に作成した矩形から、マウス位置の歌詞単位を返す。
function HitTestNoteFollowingLyrics(const HitRects: TArray<TRect>;
  X, Y: Integer): Integer;

implementation

uses
  System.Math,
  Winapi.Windows;

const
  NOTE_LYRIC_MARGIN_96 = 5;

procedure DrawReferenceNoteLyrics(Canvas: TCanvas;
  const Model: TMusicSyncEditModel; StartNoteIndex: Integer;
  const Layout: TPianoRollLayout; PianoWidth: Integer);
var
  LyricText: string;
  NoteIndex: Integer;
  NoteRect: TRect;
  TextHeight: Integer;
  TextRect: TRect;
  TextWidth: Integer;
  TextY: Integer;
  UnitIndex: Integer;
begin
  if Model = nil then
    Exit;
  for UnitIndex := 0 to High(Model.Units) do
  begin
    if UnitIndex >= Length(Model.UnitNoteIndexes) then
      Break;
    NoteIndex := StartNoteIndex + Model.UnitNoteIndexes[UnitIndex];
    if (NoteIndex < 0) or
      (NoteIndex >= Length(Layout.SequenceNoteRects)) then
      Continue;
    NoteRect := Layout.SequenceNoteRects[NoteIndex];
    if (NoteRect.Right <= NoteRect.Left) or
      (NoteRect.Bottom <= NoteRect.Top) then
      Continue;
    LyricText := Model.Units[UnitIndex].PrefixText +
      Model.Units[UnitIndex].Text +
      Model.Units[UnitIndex].SuffixText;
    if LyricText = '' then
      Continue;
    Canvas.Brush.Style := bsClear;
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -ScaleMusicSyncMetric(12, Layout.Dpi);
    Canvas.Font.Style := [];
    Canvas.Font.Color := RGB(126, 134, 148);
    TextHeight := Canvas.TextHeight(LyricText);
    TextWidth := Canvas.TextWidth(LyricText);
    TextY := NoteRect.Bottom +
      ScaleMusicSyncMetric(NOTE_LYRIC_MARGIN_96, Layout.Dpi);
    TextRect := Rect(NoteRect.Left, TextY,
      Min(PianoWidth, NoteRect.Left + TextWidth +
        ScaleMusicSyncMetric(2, Layout.Dpi)),
      Min(Layout.RollHeight, TextY + TextHeight +
        ScaleMusicSyncMetric(1, Layout.Dpi)));
    Canvas.TextRect(TextRect, NoteRect.Left, TextY, LyricText);
  end;
  Canvas.Brush.Style := bsSolid;
end;

procedure DrawNoteFollowingLyrics(Canvas: TCanvas;
  const Model: TMusicSyncEditModel; const Layout: TPianoRollLayout;
  PianoWidth: Integer; var HitRects: TArray<TRect>);
var
  FilterTextX: Integer;
  LyricText: string;
  NoteIndex: Integer;
  NoteRect: TRect;
  TextHeight: Integer;
  TextRect: TRect;
  TextWidth: Integer;
  TextY: Integer;
  UnitIndex: Integer;
begin
  SetLength(HitRects, Length(Model.Units));
  for UnitIndex := 0 to High(HitRects) do
    HitRects[UnitIndex] := Rect(0, 0, 0, 0);

  for NoteIndex := 0 to High(Layout.SyncNoteRects) do
  begin
    NoteRect := Layout.SyncNoteRects[NoteIndex];
    if (NoteRect.Right <= NoteRect.Left) or
      (NoteRect.Bottom <= NoteRect.Top) then
      Continue;
    FilterTextX := NoteRect.Left;
    for UnitIndex := 0 to High(Model.Units) do
      if (UnitIndex < Length(Model.UnitNoteIndexes)) and
        (Model.UnitNoteIndexes[UnitIndex] = NoteIndex) then
      begin
        LyricText := Model.Units[UnitIndex].PrefixText +
          Model.Units[UnitIndex].Text +
          Model.Units[UnitIndex].SuffixText;
        if LyricText = '' then
          Continue;
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Name := 'Segoe UI';
        Canvas.Font.Height :=
          -ScaleMusicSyncMetric(13, Layout.Dpi);
        Canvas.Font.Style := [];
        Canvas.Font.Color := RGB(238, 242, 248);
        TextHeight := Canvas.TextHeight(LyricText);
        TextWidth := Canvas.TextWidth(LyricText);
        TextY := NoteRect.Bottom +
          ScaleMusicSyncMetric(NOTE_LYRIC_MARGIN_96, Layout.Dpi);
        TextRect := Rect(FilterTextX, TextY,
          Min(PianoWidth, FilterTextX + TextWidth +
            ScaleMusicSyncMetric(2, Layout.Dpi)),
          Min(Layout.RollHeight, TextY + TextHeight +
            ScaleMusicSyncMetric(1, Layout.Dpi)));
        Canvas.TextRect(TextRect, FilterTextX, TextY, LyricText);
        HitRects[UnitIndex] := Rect(TextRect.Left -
          ScaleMusicSyncMetric(3, Layout.Dpi),
          TextRect.Top - ScaleMusicSyncMetric(2, Layout.Dpi),
          TextRect.Right + ScaleMusicSyncMetric(2, Layout.Dpi),
          Min(Layout.RollHeight, TextRect.Bottom +
            ScaleMusicSyncMetric(2, Layout.Dpi)));
        if UnitIndex = Model.SelectedUnitIndex then
        begin
          Canvas.Pen.Width :=
            ScaleMusicSyncMetric(2, Layout.Dpi);
          Canvas.Pen.Color := RGB(255, 210, 70);
          Canvas.Rectangle(HitRects[UnitIndex]);
          Canvas.Pen.Width :=
            ScaleMusicSyncMetric(1, Layout.Dpi);
        end;
        Inc(FilterTextX, TextWidth +
          ScaleMusicSyncMetric(2, Layout.Dpi));
      end;
  end;
  Canvas.Brush.Style := bsSolid;
end;

function HitTestNoteFollowingLyrics(const HitRects: TArray<TRect>;
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
