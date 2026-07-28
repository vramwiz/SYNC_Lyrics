unit SYNC_Lyrics_SyncSourceKind;

// 同期元ファイルを、SongReaderで扱う楽譜形式とFFmpegで扱う音声形式へ振り分ける。

interface

function IsMusicScoreFileName(const FileName: string): Boolean;

implementation

uses
  System.SysUtils;

function IsMusicScoreFileName(const FileName: string): Boolean;
var
  Extension: string;
begin
  Extension := LowerCase(ExtractFileExt(Trim(FileName)));
  Result :=
    (Extension = '.mid') or
    (Extension = '.midi') or
    (Extension = '.ust') or
    (Extension = '.vsq') or
    (Extension = '.vsqx') or
    (Extension = '.musicxml') or
    (Extension = '.mxl') or
    (Extension = '.xml') or
    (Extension = '.mscx') or
    (Extension = '.mscz');
end;

end.
