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

// 描画時に作成した矩形から、マウス位置の歌詞単位を返す。
function HitTestNoteFollowingLyrics(const HitRects: TArray<TRect>;
  X, Y: Integer): Integer;

implementation

uses
  System.Math,
  Winapi.Windows;

const
  NOTE_LYRIC_MARGIN = 5;

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
        LyricText := Model.Units[UnitIndex].Text;
        if LyricText = '' then
          Continue;
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Name := 'Segoe UI';
        Canvas.Font.Height := -13;
        Canvas.Font.Style := [];
        Canvas.Font.Color := RGB(238, 242, 248);
        TextHeight := Canvas.TextHeight(LyricText);
        TextWidth := Canvas.TextWidth(LyricText);
        TextY := NoteRect.Bottom + NOTE_LYRIC_MARGIN;
        TextRect := Rect(FilterTextX, TextY,
          Min(PianoWidth, FilterTextX + TextWidth + 2),
          Min(Layout.RollHeight, TextY + TextHeight + 1));
        Canvas.TextRect(TextRect, FilterTextX, TextY, LyricText);
        HitRects[UnitIndex] := Rect(TextRect.Left - 3,
          TextRect.Top - 2, TextRect.Right + 2,
          Min(Layout.RollHeight, TextRect.Bottom + 2));
        if UnitIndex = Model.SelectedUnitIndex then
        begin
          Canvas.Pen.Width := 2;
          Canvas.Pen.Color := RGB(255, 210, 70);
          Canvas.Rectangle(HitRects[UnitIndex]);
          Canvas.Pen.Width := 1;
        end;
        Inc(FilterTextX, TextWidth + 2);
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
