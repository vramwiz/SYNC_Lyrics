unit SYNC_Lyrics_MidiLyricAutoAssign;

// MIDI歌詞による自動割り当てのための解析入口。現在は同期データを変更しない。

interface

uses
  SYNC_Lyrics_SongLyricsModel;

procedure AnalyzeMidiLyricAssignment(const MusicFileName: string;
  Track: Integer; const SongModel: TLyricsSongModel);
procedure AutoAssignMidiLyrics(const MusicFileName: string; Track: Integer;
  PreDisplaySeconds: Double; const SongModel: TLyricsSongModel);

implementation

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  SYNC_Lyrics_MusicSync,
  SYNC_Lyrics_MusicSyncEditModel,
  SYNC_Lyrics_MidiLyricMatcher;

procedure AutoAssignMidiLyrics(const MusicFileName: string; Track: Integer;
  PreDisplaySeconds: Double; const SongModel: TLyricsSongModel);
var
  AllNotes: TMusicNoteStarts;
  Cost: Double;
  I: Integer;
  Notes: TMusicNoteStarts;
{$IFDEF DEBUG}
  Status: string;
  Success: Boolean;
{$ENDIF}
begin
  if (SongModel = nil) or
    ((not SameText(ExtractFileExt(MusicFileName), '.mid')) and
     (not SameText(ExtractFileExt(MusicFileName), '.midi'))) then
    Exit;
  try
    if not LoadMusicNoteStarts(MusicFileName, AllNotes) then
      Exit;
    SetLength(Notes, 0);
    for I := 0 to High(AllNotes) do
      if (Track < 0) or (AllNotes[I].TrackIndex = Track) then
      begin
        SetLength(Notes, Length(Notes) + 1);
        Notes[High(Notes)] := AllNotes[I];
      end;
{$IFDEF DEBUG}
    Status := 'alignment';
    for I := 0 to SongModel.LineCount - 1 do
      if SongModel[I].SyncState in [lssConfirmed, lssInconsistent] then
      begin
        Status := 'confirmed or inconsistent sync preserved';
        Break;
      end;
    for I := 0 to High(Notes) do
      if Trim(Notes[I].Lyric) = '' then
      begin
        Status := 'empty MIDI lyric';
        Break;
      end;
    Success := TryAssignMidiLyricSync(Notes, PreDisplaySeconds,
      SongModel, Cost);
    try
      TFile.AppendAllText(TPath.Combine(TPath.GetTempPath,
        'SYNC_Lyrics_MidiLyricAutoAssign.log'),
        sLineBreak + 'AssignmentSuccess=' + BoolToStr(Success, True) +
        ' MatchCost=' + FloatToStr(Cost, TFormatSettings.Invariant) +
        ' Guard=' + Status,
        TEncoding.UTF8);
    except
    end;
{$ELSE}
    TryAssignMidiLyricSync(Notes, PreDisplaySeconds, SongModel, Cost);
{$ENDIF}
  except
    // MIDI読み込み・照合失敗時は既存の手動同期を使用する。
  end;
end;

procedure AnalyzeMidiLyricAssignment(const MusicFileName: string;
  Track: Integer; const SongModel: TLyricsSongModel);
{$IFDEF DEBUG}
var
  EditModel: TMusicSyncEditModel;
  I: Integer;
  J: Integer;
  LineData: TLyricsSongLine;
  Log: TStringBuilder;
  Notes: TMusicNoteStarts;
  SelectedIndex: Integer;
{$ENDIF}
begin
{$IFDEF DEBUG}
  if (SongModel = nil) or
    ((not SameText(ExtractFileExt(MusicFileName), '.mid')) and
     (not SameText(ExtractFileExt(MusicFileName), '.midi'))) then
    Exit;
  Log := TStringBuilder.Create;
  EditModel := TMusicSyncEditModel.Create;
  try
    try
      Log.AppendLine('SYNC_Lyrics MIDI lyric assignment analysis');
      Log.AppendLine('MusicFile=' + MusicFileName);
      Log.AppendLine('Track=' + IntToStr(Track));
      Log.AppendLine('Lines=' + IntToStr(SongModel.LineCount));
      for I := 0 to SongModel.LineCount - 1 do
      begin
        LineData := SongModel[I];
        EditModel.SetLyrics(LineData.SourceText);
        Log.AppendLine(Format('Line[%d] ID=%d StartNote=%d SyncState=%d SyncText=%s Source=%s Plain=%s Units=%d',
          [I, LineData.LineID, LineData.StartNoteIndex, Ord(LineData.SyncState),
          LineData.SyncText, LineData.SourceText,
          LineData.PlainText, Length(EditModel.Units)]));
        for J := 0 to High(EditModel.Units) do
          Log.AppendLine(Format('  Unit[%d] Prefix=%s Text=%s Suffix=%s Ruby=%s ConsumesNote=%s',
            [J, EditModel.Units[J].PrefixText, EditModel.Units[J].Text,
            EditModel.Units[J].SuffixText, EditModel.Units[J].RubyText,
            BoolToStr(EditModel.Units[J].ConsumesNote, True)]));
      end;
      if LoadMusicNoteStarts(MusicFileName, Notes) then
      begin
        Log.AppendLine('AllNotes=' + IntToStr(Length(Notes)));
        SelectedIndex := 0;
        for I := 0 to High(Notes) do
        begin
          if (Track >= 0) and (Notes[I].TrackIndex <> Track) then
            Continue;
          Log.AppendLine(Format('  Note[%d] SourceIndex=%d Track=%d Start=%s End=%s Key=%d Lyric=%s',
            [SelectedIndex, I, Notes[I].TrackIndex,
            FloatToStr(Notes[I].Seconds, TFormatSettings.Invariant),
            FloatToStr(Notes[I].EndSeconds, TFormatSettings.Invariant),
            Notes[I].Key, Notes[I].Lyric]));
          Inc(SelectedIndex);
        end;
        Log.AppendLine('SelectedNotes=' + IntToStr(SelectedIndex));
      end
      else
        Log.AppendLine('MusicLoadFailed');
      TFile.WriteAllText(TPath.Combine(TPath.GetTempPath,
        'SYNC_Lyrics_MidiLyricAutoAssign.log'), Log.ToString, TEncoding.UTF8);
    except
      // 解析ログの失敗で歌詞確定や同期画面への遷移を止めない。
    end;
  finally
    EditModel.Free;
    Log.Free;
  end;
{$ENDIF}
end;

end.
