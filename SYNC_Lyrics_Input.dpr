library SYNC_Lyrics_Input;

// 標準変形を使う歌詞テロップ用の透明ベース映像を提供するAviUtl2入力境界。

uses
  Winapi.Windows,
  AviUtl2InputTypes in 'Source\Lib\AviUtl2InputTypes.pas',
  SharedMemoryBase in 'Source\Lib\SharedMemoryBase.pas',
  SYNC_Lyrics_FrameShared in 'Source\Common\Timeline\SYNC_Lyrics_FrameShared.pas',
  SYNC_Lyrics_InputPlugin in 'Source\Plugin\Input\SYNC_Lyrics_InputPlugin.pas';

function func_open(FileName: LPCWSTR): INPUT_HANDLE; cdecl;
begin
  Result := LyricsInputOpen(FileName);
end;

function func_close(Ih: INPUT_HANDLE): BOOL; cdecl;
begin
  Result := LyricsInputClose(Ih);
end;

function func_info_get(Ih: INPUT_HANDLE; Info: PInputInfo): BOOL; cdecl;
begin
  Result := LyricsInputGetInfo(Ih, Info);
end;

function func_read_video(Ih: INPUT_HANDLE; Frame: Integer; Buf: Pointer): Integer; cdecl;
begin
  Result := LyricsInputReadVideo(Ih, Frame, Buf);
end;

function func_read_audio(Ih: INPUT_HANDLE; Start, Length: Integer; Buf: Pointer): Integer; cdecl;
begin
  Result := 0;
end;

function func_config(Hwnd: HWND; Hinst: HINST): BOOL; cdecl;
begin
  Result := LyricsInputConfig(Hwnd, Hinst);
end;

var
  Plugin: TInputPluginTable = (
    flag: INPUT_PLUGIN_FLAG_VIDEO;
    name: 'SYNC_歌詞テロップ_Input';
    filefilter: '歌詞テロップベース (*.synclyrics)'#0'*.synclyrics'#0;
    information: '歌詞テロップ描画用フレーム位置入力';
    func_open: func_open;
    func_close: func_close;
    func_info_get: func_info_get;
    func_read_video: func_read_video;
    func_read_audio: func_read_audio;
    func_config: func_config;
    func_set_track: nil;
    func_time_to_frame: nil
  );

function GetInputPluginTable: PInputPluginTable; cdecl;
begin
  Result := @Plugin;
end;

exports
  GetInputPluginTable name 'GetInputPluginTable';

begin
end.
