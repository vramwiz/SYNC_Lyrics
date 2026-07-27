unit SharedMemoryBase;

// Syncroh2から移入し、旧共有フレーム経路に必要な名前付き共有メモリ管理だけを提供する。

interface

uses
  Winapi.Windows;

type
  TSharedMemoryBase = class
  private
    FHandle: THandle;
    FView: Pointer;
    FSize: Cardinal;
    FIsOwner: Boolean;
  public
    constructor Create(const Name: string; Size: Cardinal);
    destructor Destroy; override;

    property View: Pointer read FView;
    property Size: Cardinal read FSize;
    property IsOwner: Boolean read FIsOwner;
  end;

implementation

uses
  System.SysUtils;

constructor TSharedMemoryBase.Create(const Name: string; Size: Cardinal);
begin
  inherited Create;
  if (Name = '') or (Size = 0) then
    raise EArgumentException.Create('Invalid shared memory parameters');

  FSize := Size;
  FHandle := CreateFileMapping(INVALID_HANDLE_VALUE, nil, PAGE_READWRITE,
    0, FSize, PChar(Name));
  if FHandle = 0 then
    RaiseLastOSError;

  FIsOwner := GetLastError <> ERROR_ALREADY_EXISTS;
  FView := MapViewOfFile(FHandle, FILE_MAP_ALL_ACCESS, 0, 0, FSize);
  if FView = nil then
  begin
    CloseHandle(FHandle);
    FHandle := 0;
    RaiseLastOSError;
  end;

  if FIsOwner then
    FillChar(FView^, FSize, 0);
end;

destructor TSharedMemoryBase.Destroy;
begin
  if FView <> nil then
  begin
    UnmapViewOfFile(FView);
    FView := nil;
  end;
  if FHandle <> 0 then
  begin
    CloseHandle(FHandle);
    FHandle := 0;
  end;
  inherited Destroy;
end;

end.
