unit SYNC_Lyrics_MusicSyncAnchor;

// 曲同期GUIを開く基準として、Filterが最後に解決した絶対フレーム位置を保持する。

interface

type
  TMusicSyncAnchor = record
    Frame: Integer;  // InputとFilterから解決した絶対フレーム
    Rate: Integer;   // フレームレートの分子
    Scale: Integer;  // フレームレートの分母
  end;

// Filter読込時に基準位置の排他資源を初期化する。
procedure InitializeMusicSyncAnchor;

// Filter解放時に基準位置の排他資源を解放する。
procedure FinalizeMusicSyncAnchor;

// Filterが正常に発火した絶対フレーム位置を、GUIから取得できる最新値として記録する。
procedure RecordMusicSyncAnchor(Frame, Rate, Scale: Integer);

// 最後に記録した基準位置を返す。未発火または無効値の場合はFalseを返す。
function TryGetMusicSyncAnchor(out Anchor: TMusicSyncAnchor): Boolean;

implementation

uses
  System.SyncObjs,
  System.SysUtils;

var
  AnchorLock: TCriticalSection;
  LastAnchor: TMusicSyncAnchor;
  HasLastAnchor: Boolean;

procedure InitializeMusicSyncAnchor;
begin
  if AnchorLock <> nil then
    Exit;
  AnchorLock := TCriticalSection.Create;
  HasLastAnchor := False;
  FillChar(LastAnchor, SizeOf(LastAnchor), 0);
end;

procedure FinalizeMusicSyncAnchor;
begin
  FreeAndNil(AnchorLock);
  HasLastAnchor := False;
  FillChar(LastAnchor, SizeOf(LastAnchor), 0);
end;

procedure RecordMusicSyncAnchor(Frame, Rate, Scale: Integer);
begin
  if (Rate <= 0) or (Scale <= 0) then
    Exit;
  InitializeMusicSyncAnchor;
  AnchorLock.Acquire;
  try
    LastAnchor.Frame := Frame;
    LastAnchor.Rate := Rate;
    LastAnchor.Scale := Scale;
    HasLastAnchor := True;
  finally
    AnchorLock.Release;
  end;
end;

function TryGetMusicSyncAnchor(out Anchor: TMusicSyncAnchor): Boolean;
begin
  FillChar(Anchor, SizeOf(Anchor), 0);
  InitializeMusicSyncAnchor;
  AnchorLock.Acquire;
  try
    Result := HasLastAnchor;
    if Result then
      Anchor := LastAnchor;
  finally
    AnchorLock.Release;
  end;
end;

end.
