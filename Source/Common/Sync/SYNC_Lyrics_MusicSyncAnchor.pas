unit SYNC_Lyrics_MusicSyncAnchor;

// 曲同期GUIを開く基準として、Filterが最後に解決した絶対フレーム位置を保持する。

interface

type
  TMusicSyncAnchor = record
    ObjectID: Int64;       // Filter描画時のオブジェクト識別値
    EffectID: Int64;       // 同一オブジェクト内のFilter識別値
    Layer: Integer;        // タイムライン上のレイヤー
    StartFrame: Integer;   // タイムライン上のオブジェクト開始フレーム
    EndFrame: Integer;     // タイムライン上のオブジェクト終了フレーム
    Frame: Integer;        // Input素材上のオブジェクト先頭絶対フレーム
    Rate: Integer;         // フレームレートの分子
    Scale: Integer;        // フレームレートの分母
  end;

// Filter読込時に基準位置の排他資源を初期化する。
procedure InitializeMusicSyncAnchor;

// Filter解放時に基準位置の排他資源を解放する。
procedure FinalizeMusicSyncAnchor;

// Filterが正常に発火した素材先頭位置を、オブジェクト配置ごとに記録する。
procedure RecordMusicSyncAnchor(ObjectID, EffectID: Int64;
  Layer, StartFrame, EndFrame, Frame, Rate, Scale: Integer);

// 選択オブジェクトの配置に一致する基準位置を返す。
function TryGetMusicSyncAnchor(Layer, StartFrame, EndFrame: Integer;
  out Anchor: TMusicSyncAnchor): Boolean;

implementation

uses
  System.Generics.Collections,
  System.SyncObjs,
  System.SysUtils;

var
  AnchorLock: TCriticalSection;
  Anchors: TList<TMusicSyncAnchor>;

procedure InitializeMusicSyncAnchor;
begin
  if AnchorLock <> nil then
    Exit;
  AnchorLock := TCriticalSection.Create;
  Anchors := TList<TMusicSyncAnchor>.Create;
end;

procedure FinalizeMusicSyncAnchor;
begin
  FreeAndNil(Anchors);
  FreeAndNil(AnchorLock);
end;

procedure RecordMusicSyncAnchor(ObjectID, EffectID: Int64;
  Layer, StartFrame, EndFrame, Frame, Rate, Scale: Integer);
var
  Anchor: TMusicSyncAnchor;
  I: Integer;
begin
  if (Rate <= 0) or (Scale <= 0) then
    Exit;
  InitializeMusicSyncAnchor;
  AnchorLock.Acquire;
  try
    // 移動・長さ変更後の古い配置キーを同じオブジェクトIDで残さない。
    for I := Anchors.Count - 1 downto 0 do
      if ((Anchors[I].ObjectID = ObjectID) and
        (Anchors[I].EffectID = EffectID)) or
        ((Anchors[I].Layer = Layer) and
        (Anchors[I].StartFrame = StartFrame) and
        (Anchors[I].EndFrame = EndFrame)) then
        Anchors.Delete(I);

    Anchor.ObjectID := ObjectID;
    Anchor.EffectID := EffectID;
    Anchor.Layer := Layer;
    Anchor.StartFrame := StartFrame;
    Anchor.EndFrame := EndFrame;
    Anchor.Frame := Frame;
    Anchor.Rate := Rate;
    Anchor.Scale := Scale;
    Anchors.Add(Anchor);
  finally
    AnchorLock.Release;
  end;
end;

function TryGetMusicSyncAnchor(Layer, StartFrame, EndFrame: Integer;
  out Anchor: TMusicSyncAnchor): Boolean;
var
  I: Integer;
begin
  FillChar(Anchor, SizeOf(Anchor), 0);
  InitializeMusicSyncAnchor;
  AnchorLock.Acquire;
  try
    Result := False;
    for I := Anchors.Count - 1 downto 0 do
      if (Anchors[I].Layer = Layer) and
        (Anchors[I].StartFrame = StartFrame) and
        (Anchors[I].EndFrame = EndFrame) then
      begin
        Anchor := Anchors[I];
        Exit(True);
      end;
  finally
    AnchorLock.Release;
  end;
end;

end.
