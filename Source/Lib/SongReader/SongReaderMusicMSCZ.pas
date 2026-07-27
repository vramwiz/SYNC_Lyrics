unit SongReaderMusicMSCZ;

interface

uses Windows,SysUtils, Classes, Xml.XMLDoc, Xml.XMLIntf, Generics.Collections,
     SongData,System.Zip,SongReaderMusicMSC,SongReader;


type
  TSongReaderMusicMSCX = class(TSongReaderMusicMSC)
  private
  public
    // ファイル読込
    function LoadFromFile(const FileName: string; SongData: TSongData) : Boolean;override;
  end;

type
  TSongReaderMusicMSCZ = class(TSongReaderMusicMSC)
  private
  public
    // ファイル読込
    function LoadFromFile(const FileName: string; SongData: TSongData) : Boolean;override;
  end;

implementation

{ TSongReaderMusicMSCX }

function TSongReaderMusicMSCX.LoadFromFile(const FileName: string; SongData: TSongData): Boolean;
var
  Stream: TFileStream;
begin
  Result := False;
  if (FileName = '') or (SongData = nil) then Exit;

  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      Stream.Position := 0;
      Result := LoadFromStream(Stream, SongData);
    finally
      Stream.Free;
    end;
  except
    Result := False; // 例外は外へ出さない
  end;
end;

{ TSongReaderMusicMSC }

function TSongReaderMusicMSCZ.LoadFromFile(const FileName: string; SongData: TSongData): Boolean;
var
  Zip: TZipFile;
  I: Integer;
  EntryStream: TStream;
  Header: TZipHeader;
begin
  Result := False;
  if (FileName = '') or (SongData = nil) then Exit;
  try
    Zip := TZipFile.Create;
    try
      if not FileExists(FileName) then Exit;
      Zip.Open(FileName, zmRead);

      for I := 0 to Zip.FileCount - 1 do
      begin
        if SameText(ExtractFileExt(Zip.FileNames[I]), '.mscx') then
        begin
          EntryStream := nil;
          Zip.Read(I, EntryStream, Header, False);
          try
            EntryStream.Position := 0;
            Result := LoadFromStream(EntryStream, SongData);
          finally
            EntryStream.Free;  // ← 必須
          end;
          Exit;
        end;
      end;

    finally
      Zip.Free;
    end;
  except
    Result := False;
  end;
end;

end.
