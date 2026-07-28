unit SYNC_Lyrics_MusicSyncFixedLyrics;

// ピアノロール下部の固定Y歌詞レーンを描画する。
// 各文字を同期先ノートの開始Xへ合わせ、音程とは独立した固定Yへ配置する。

interface

uses
  System.Types,
  Vcl.Graphics,
  SYNC_Lyrics_MusicSyncEditModel,
  SYNC_Lyrics_MusicSyncPianoRoll;

// 本文とルビを固定レーンへ描画する。現段階では表示のみを担当する。
procedure DrawFixedLyrics(Canvas: TCanvas; PianoWidth,
  PianoHeight: Integer; const Model: TMusicSyncEditModel;
  const Layout: TPianoRollLayout);

implementation

uses
  System.Math,
  Winapi.Windows;

procedure DrawFixedLyrics(Canvas: TCanvas; PianoWidth,
  PianoHeight: Integer; const Model: TMusicSyncEditModel;
  const Layout: TPianoRollLayout);
var
  BaseChar: string;
  CharacterX: Integer;
  CharacterXCursor: Integer;
  CharCount: Integer;
  CharIndex: Integer;
  CharacterNoteIndex: Integer;
  GroupEndNote: Integer;
  GroupIndex: Integer;
  GroupStartNote: Integer;
  NoteRect: TRect;
  RubyText: string;
  SpanLeft: Integer;
  TextWidth: Integer;
  UnitEndX: Integer;
  UnitIndex: Integer;
  UnitStartX: Integer;
begin
  Canvas.Brush.Color := RGB(16, 19, 26);
  Canvas.FillRect(Rect(0, Layout.RollHeight, PianoWidth, PianoHeight));
  Canvas.Pen.Width := 1;
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
      UnitStartX := -1;
      UnitEndX := -1;
      Canvas.Brush.Style := bsClear;
      Canvas.Font.Name := 'Segoe UI';
      Canvas.Font.Height := -15;
      Canvas.Font.Style := [];
      Canvas.Font.Color := RGB(238, 242, 248);
      for CharIndex := 1 to CharCount do
      begin
        if Model.TryGetExpandedCharacterNoteIndex(UnitIndex,
          CharIndex - 1, CharacterNoteIndex) and
          (CharacterNoteIndex >= 0) and
          (CharacterNoteIndex < Length(Layout.SyncNoteRects)) then
          CharacterX :=
            Layout.SyncNoteRects[CharacterNoteIndex].Left
        else
          CharacterX := CharacterXCursor;
        BaseChar := Copy(Model.Units[UnitIndex].Text, CharIndex, 1);
        TextWidth := Canvas.TextWidth(BaseChar);
        if UnitStartX < 0 then
          UnitStartX := CharacterX;
        Canvas.TextOut(CharacterX, Layout.RollHeight + 28, BaseChar);
        UnitEndX := CharacterX + TextWidth;
        if Model.Groups[GroupIndex].NoteCount <= 1 then
          CharacterXCursor := UnitEndX;
      end;
      RubyText := Model.Units[UnitIndex].RubyText;
      if (RubyText <> '') and (UnitStartX >= 0) then
      begin
        Canvas.Font.Height := -11;
        Canvas.Font.Color := RGB(185, 194, 208);
        TextWidth := Canvas.TextWidth(RubyText);
        Canvas.TextOut(UnitStartX +
          (UnitEndX - UnitStartX - TextWidth) div 2,
          Layout.RollHeight + 8, RubyText);
      end;
    end;
  end;
  Canvas.Brush.Style := bsSolid;
end;

end.
