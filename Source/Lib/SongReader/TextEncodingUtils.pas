unit TextEncodingUtils;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,StrUtils,
  System.IOUtils;


// ファイルを正しい文字コードで読み込む
function LoadTextAutoEncoding(const FileName: string): string;
function DecodeTextAutoEncoding(const Bytes: TBytes): string;

implementation

function IsValidUtf8Bytes(const B: TBytes; out HasMultibyte: Boolean): Boolean;
var
  i: Integer;
  c: Byte;
  need: Integer;
begin
  Result := True;
  HasMultibyte := False;
  i := 0;

  while i < Length(B) do
  begin
    c := B[i];

    // ASCII
    if c <= $7F then
    begin
      Inc(i);
      Continue;
    end;

    // 先頭バイトから必要な継続バイト数を決定
    if (c >= $C2) and (c <= $DF) then need := 1
    else if (c >= $E0) and (c <= $EF) then need := 2
    else if (c >= $F0) and (c <= $F4) then need := 3
    else
    begin
      Result := False;
      Exit;
    end;

    HasMultibyte := True;

    // 継続バイト数が足りない
    if i + need >= Length(B) then
    begin
      Result := False;
      Exit;
    end;

    // UTF-8の細かい禁止パターン（過剰形式・サロゲート等）を弾く
    // 2バイト: C2..DF 80..BF は上でOK
    if need = 2 then
    begin
      // E0: A0..BF 80..BF（過剰形式回避）
      if (c = $E0) and not ((B[i+1] >= $A0) and (B[i+1] <= $BF)) then begin Result := False; Exit; end;
      // ED: 80..9F 80..BF（サロゲート回避）
      if (c = $ED) and not ((B[i+1] >= $80) and (B[i+1] <= $9F)) then begin Result := False; Exit; end;
    end
    else if need = 3 then
    begin
      // F0: 90..BF 80..BF 80..BF（過剰形式回避）
      if (c = $F0) and not ((B[i+1] >= $90) and (B[i+1] <= $BF)) then begin Result := False; Exit; end;
      // F4: 80..8F 80..BF 80..BF（U+10FFFF超え回避）
      if (c = $F4) and not ((B[i+1] >= $80) and (B[i+1] <= $8F)) then begin Result := False; Exit; end;
    end;

    // 継続バイトは 80..BF
    if not ((B[i+1] >= $80) and (B[i+1] <= $BF)) then begin Result := False; Exit; end;
    if (need >= 2) and not ((B[i+2] >= $80) and (B[i+2] <= $BF)) then begin Result := False; Exit; end;
    if (need >= 3) and not ((B[i+3] >= $80) and (B[i+3] <= $BF)) then begin Result := False; Exit; end;

    Inc(i, need + 1);
  end;
end;


function DecodeTextAutoEncoding(const Bytes: TBytes): string;
var
  HasMultibyteUtf8: Boolean;
begin

  // --------------------------------------------------
  // 1) BOMで確定
  // --------------------------------------------------
  if Length(Bytes) >= 3 then
    if (Bytes[0] = $EF) and (Bytes[1] = $BB) and (Bytes[2] = $BF) then
      Exit(TEncoding.UTF8.GetString(Bytes, 3, Length(Bytes) - 3)); // UTF-8 BOM除去

  if Length(Bytes) >= 2 then
  begin
    if (Bytes[0] = $FF) and (Bytes[1] = $FE) then
      Exit(TEncoding.Unicode.GetString(Bytes)); // UTF-16 LE（BOM込みOK）

    if (Bytes[0] = $FE) and (Bytes[1] = $FF) then
      Exit(TEncoding.BigEndianUnicode.GetString(Bytes)); // UTF-16 BE
  end;

  // --------------------------------------------------
  // 2) BOMなしUTF-8判定
  // --------------------------------------------------
  if IsValidUtf8Bytes(Bytes, HasMultibyteUtf8) and HasMultibyteUtf8 then
    Exit(TEncoding.UTF8.GetString(Bytes));

  // --------------------------------------------------
  // 3) Shift-JIS
  // --------------------------------------------------
  Result := TEncoding.GetEncoding(932).GetString(Bytes);
end;


// ファイルを正しい文字コードで読み込む
// ファイルを正しい文字コードで読み込む（UTF-8 BOM除去対応）
function LoadTextAutoEncoding(const FileName: string): string;
begin
  Result := DecodeTextAutoEncoding(TFile.ReadAllBytes(FileName));
end;


end.
