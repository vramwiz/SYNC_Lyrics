unit TextRendererSkiaBootstrap;

// プラグインと同じフォルダーにあるSkiaランタイムのパスを返す。

interface

// DLLロード後の公開初期化関数から渡す、同梱sk4d.dllの絶対パスを返す。
function BundledSkiaRuntimeFileName: string;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

function BundledSkiaRuntimeFileName: string;
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
  Result := ExtractFilePath(Result) + 'sk4d.dll';
end;

end.
