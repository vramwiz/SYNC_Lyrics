unit TextRendererSkiaBootstrap;

// System.Skiaの外部関数解決より前に、プラグイン同梱のsk4d.dllを読み込む。

interface

implementation

uses
  System.SysUtils,
  Winapi.Windows;

var
  BootstrapLibraryHandle: HMODULE;

function ModuleDirectory: string;
var
  Buffer: array[0..32767] of Char;
  PathLength: DWORD;
begin
  PathLength := GetModuleFileName(HInstance, Buffer, Length(Buffer));
  if PathLength = 0 then
    RaiseLastOSError;
  if PathLength >= DWORD(Length(Buffer)) then
    raise EPathTooLongException.Create('The plugin path is too long');
  SetString(Result, Buffer, PathLength);
  Result := ExtractFilePath(Result);
end;

procedure LoadBundledSkiaRuntime;
var
  LibraryFileName: string;
begin
  LibraryFileName := ModuleDirectory + 'sk4d.dll';
  BootstrapLibraryHandle := LoadLibrary(PChar(LibraryFileName));
  if BootstrapLibraryHandle = 0 then
    raise EOSError.CreateFmt('Cannot load Skia runtime: %s (error %d)',
      [LibraryFileName, GetLastError]);
end;

initialization
  LoadBundledSkiaRuntime;

finalization
  if BootstrapLibraryHandle <> 0 then
    FreeLibrary(BootstrapLibraryHandle);

end.
