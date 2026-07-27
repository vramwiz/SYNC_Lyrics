unit SYNC_Lyrics_ContextManager;

// Inputの共有絶対フレームとFilterの相対フレームをオブジェクトごとに対応付ける。

interface

uses
  AviUtl2FilterTypes,
  SYNC_Lyrics_FrameShared;

procedure InitializeLyricsContexts;
procedure FinalizeLyricsContexts;
function ResolveLyricsFrameState(Video: PFILTER_PROC_VIDEO;
  const SharedState: TSyncLyricsFrameState;
  out EffectiveState: TSyncLyricsFrameState): Boolean;

implementation

uses
  System.Generics.Collections,
  System.SyncObjs,
  System.SysUtils;

type
  TLyricsObjectContext = class
  public
    ObjectID         : Int64;   // Filterが属するオブジェクトの識別値。
    EffectID         : Int64;   // 同一オブジェクト内のFilterを区別する識別値。
    HasAnchor        : Boolean; // 共有絶対フレームとの対応を取得済みか。
    LastSequence     : Integer; // 最後に処理した共有メモリの更新番号。
    AnchorInputFrame : Integer; // Inputから最後に受け取った絶対フレーム。
    AnchorLocalFrame : Integer; // 同じ時点のFilter相対フレーム。
    Rate             : Integer; // フレームレートの分子。
    Scale            : Integer; // フレームレートの分母。
    UpdateTick       : UInt64;  // 基準にしたInput更新時刻。
  end;

  TLyricsContextList = class
  private
    FItems: TObjectList<TLyricsObjectContext>;
    FLock : TCriticalSection;
    function FindByKey(ObjectID, EffectID: Int64): TLyricsObjectContext;
    function GetOrCreate(ObjectID, EffectID: Int64): TLyricsObjectContext;
  public
    constructor Create;
    destructor Destroy; override;
    function Resolve(Video: PFILTER_PROC_VIDEO;
      const SharedState: TSyncLyricsFrameState;
      out EffectiveState: TSyncLyricsFrameState): Boolean;
  end;

var
  LyricsContexts: TLyricsContextList;

constructor TLyricsContextList.Create;
begin
  inherited Create;
  FItems := TObjectList<TLyricsObjectContext>.Create(True);
  FLock := TCriticalSection.Create;
end;

destructor TLyricsContextList.Destroy;
begin
  FLock.Free;
  FItems.Free;
  inherited Destroy;
end;

function TLyricsContextList.FindByKey(ObjectID,
  EffectID: Int64): TLyricsObjectContext;
var
  Context: TLyricsObjectContext;
begin
  Result := nil;
  for Context in FItems do
    if (Context.ObjectID = ObjectID) and (Context.EffectID = EffectID) then
      Exit(Context);
end;

function TLyricsContextList.GetOrCreate(ObjectID,
  EffectID: Int64): TLyricsObjectContext;
begin
  Result := FindByKey(ObjectID, EffectID);
  if Result <> nil then
    Exit;

  Result := TLyricsObjectContext.Create;
  Result.ObjectID := ObjectID;
  Result.EffectID := EffectID;
  Result.HasAnchor := False;
  FItems.Add(Result);
end;

function TLyricsContextList.Resolve(Video: PFILTER_PROC_VIDEO;
  const SharedState: TSyncLyricsFrameState;
  out EffectiveState: TSyncLyricsFrameState): Boolean;
var
  Context   : TLyricsObjectContext;
  ObjectInfo: POBJECT_INFO;
begin
  FillChar(EffectiveState, SizeOf(EffectiveState), 0);
  Result := False;
  if (Video = nil) or (Video^.Object_ = nil) then
    Exit;

  ObjectInfo := Video^.Object_;
  FLock.Acquire;
  try
    Context := GetOrCreate(ObjectInfo^.ID, ObjectInfo^.EffectID);

    // Inputが新しいフレームを公開した時だけ、絶対位置と相対位置の基準を更新する。
    if not Context.HasAnchor or
      (Context.LastSequence <> SharedState.Sequence) then
    begin
      Context.HasAnchor := True;
      Context.LastSequence := SharedState.Sequence;
      Context.AnchorInputFrame := SharedState.Frame;
      Context.AnchorLocalFrame := ObjectInfo^.Frame;
      Context.Rate := SharedState.Rate;
      Context.Scale := SharedState.Scale;
      Context.UpdateTick := SharedState.UpdateTick;
    end;

    if not Context.HasAnchor or (Context.Rate <= 0) or
      (Context.Scale <= 0) then
      Exit;

    // Inputがキャッシュで再発火しなくても、Filterの相対フレーム差で絶対位置を進める。
    EffectiveState := SharedState;
    EffectiveState.Sequence := Context.LastSequence;
    EffectiveState.Frame := Context.AnchorInputFrame +
      (ObjectInfo^.Frame - Context.AnchorLocalFrame);
    EffectiveState.Rate := Context.Rate;
    EffectiveState.Scale := Context.Scale;
    EffectiveState.TimeSeconds := EffectiveState.Frame *
      Context.Scale / Context.Rate;
    EffectiveState.UpdateTick := Context.UpdateTick;
    Result := True;
  finally
    FLock.Release;
  end;
end;

procedure InitializeLyricsContexts;
begin
  if LyricsContexts <> nil then
    Exit;
  try
    LyricsContexts := TLyricsContextList.Create;
  except
    FreeAndNil(LyricsContexts);
  end;
end;

procedure FinalizeLyricsContexts;
begin
  FreeAndNil(LyricsContexts);
end;

function ResolveLyricsFrameState(Video: PFILTER_PROC_VIDEO;
  const SharedState: TSyncLyricsFrameState;
  out EffectiveState: TSyncLyricsFrameState): Boolean;
begin
  InitializeLyricsContexts;
  Result := (LyricsContexts <> nil) and
    LyricsContexts.Resolve(Video, SharedState, EffectiveState);
end;

initialization
  LyricsContexts := nil;

finalization
  FinalizeLyricsContexts;

end.
