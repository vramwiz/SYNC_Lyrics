unit TextRendererSkiaRuntime;

// sk4d.dllとSkiaのプロセス単位初期化を参照カウント付きで管理する。

interface

type
  TTextRendererSkiaRuntime = class sealed
  public
    // 指定したsk4d.dllを共有取得し、初回だけSkiaを初期化する。
    class procedure Acquire(const ALibraryFileName: string); static;
    // Skiaランタイムが取得済みか返す。
    class function IsAcquired: Boolean; static;
    // 共有参照を解放し、最後の解放時にキャッシュとDLLを破棄する。
    class procedure Release; static;
  end;

implementation

uses
  TextRendererSkiaBootstrap,
  System.Skia,
  System.SysUtils,
  Winapi.Windows;

var
  RuntimeFileName: string;
  RuntimeLibraryHandle: HMODULE;
  RuntimeLock: TRTLCriticalSection;
  RuntimeReferenceCount: Integer;

class procedure TTextRendererSkiaRuntime.Acquire(const ALibraryFileName: string);
var
  ExpandedFileName: string;
begin
  ExpandedFileName := ExpandFileName(ALibraryFileName);
  EnterCriticalSection(RuntimeLock);
  try
    if RuntimeReferenceCount > 0 then
    begin
      if not SameText(RuntimeFileName, ExpandedFileName) then
        raise EInvalidOp.CreateFmt(
          'Skia runtime is already loaded from a different path: %s',
          [RuntimeFileName]);
      Inc(RuntimeReferenceCount);
      Exit;
    end;

    RuntimeLibraryHandle := LoadLibrary(PChar(ExpandedFileName));
    if RuntimeLibraryHandle = 0 then
      raise EOSError.CreateFmt('Cannot load Skia runtime: %s (error %d)',
        [ExpandedFileName, GetLastError]);
    try
      TSkGraphics.Init;
      RuntimeFileName := ExpandedFileName;
      RuntimeReferenceCount := 1;
    except
      FreeLibrary(RuntimeLibraryHandle);
      RuntimeLibraryHandle := 0;
      raise;
    end;
  finally
    LeaveCriticalSection(RuntimeLock);
  end;
end;

class function TTextRendererSkiaRuntime.IsAcquired: Boolean;
begin
  EnterCriticalSection(RuntimeLock);
  try
    Result := RuntimeReferenceCount > 0;
  finally
    LeaveCriticalSection(RuntimeLock);
  end;
end;

class procedure TTextRendererSkiaRuntime.Release;
begin
  EnterCriticalSection(RuntimeLock);
  try
    if RuntimeReferenceCount = 0 then
      Exit;
    Dec(RuntimeReferenceCount);
    if RuntimeReferenceCount > 0 then
      Exit;

    TSkGraphics.PurgeAllCaches;
    FreeLibrary(RuntimeLibraryHandle);
    RuntimeLibraryHandle := 0;
    RuntimeFileName := '';
  finally
    LeaveCriticalSection(RuntimeLock);
  end;
end;

initialization
  InitializeCriticalSection(RuntimeLock);

finalization
  while RuntimeReferenceCount > 0 do
    TTextRendererSkiaRuntime.Release;
  DeleteCriticalSection(RuntimeLock);

end.
