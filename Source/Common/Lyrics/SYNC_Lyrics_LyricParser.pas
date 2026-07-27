unit SYNC_Lyrics_LyricParser;

// 1行の歌詞から本文と `[本文](ルビ)` の対応区間を抽出する。

interface

type
  TLyricsRubySpan = record
    BaseStart : Integer; // 構文記号を除いた本文内で、対象文字列が始まる1始まりの位置。
    BaseLength: Integer; // ルビの表示幅を対応付ける本文文字数。
    RubyText  : string;  // 対象本文の上へ表示するルビ。
  end;
  TLyricsRubySpans = TArray<TLyricsRubySpan>;
  TLyricsDisplayUnit = record
    BaseStart : Integer; // 構文除去後の本文で表示単位が始まる1始まりの位置。
    BaseLength: Integer; // 1つのノート進捗を共有する本文文字数。
    RubyIndex : Integer; // 対応するRubySpansの添字。ルビがなければ-1。
  end;
  TLyricsDisplayUnits = TArray<TLyricsDisplayUnit>;

// 構文記号を除いた本文と全ルビ区間を返す。不完全な構文は通常文字として本文へ残す。
procedure ParseLyrics(const Source: string; out PlainText: string; out RubySpans: TLyricsRubySpans);

// ルビ対応本文を1単位、その他の各文字を1単位として、同期処理順の表示単位列を返す。
procedure BuildLyricsDisplayUnits(const PlainText: string; const RubySpans: TLyricsRubySpans;
  out Units: TLyricsDisplayUnits);

implementation

uses
  System.StrUtils,
  System.SysUtils;

procedure AddRubySpan(var RubySpans: TLyricsRubySpans; BaseStart, BaseLength: Integer;
  const RubyText: string);
var
  Index: Integer;
begin
  Index := Length(RubySpans);
  SetLength(RubySpans, Index + 1);
  RubySpans[Index].BaseStart := BaseStart;
  RubySpans[Index].BaseLength := BaseLength;
  RubySpans[Index].RubyText := RubyText;
end;

procedure AddDisplayUnit(var Units: TLyricsDisplayUnits; BaseStart, BaseLength, RubyIndex: Integer);
var
  Index: Integer;
begin
  Index := Length(Units);
  SetLength(Units, Index + 1);
  Units[Index].BaseStart := BaseStart;
  Units[Index].BaseLength := BaseLength;
  Units[Index].RubyIndex := RubyIndex;
end;

function TryReadRuby(const Source: string; StartIndex: Integer; out BaseText, RubyText: string;
  out NextIndex: Integer): Boolean;
var
  BaseEnd: Integer;
  RubyEnd: Integer;
  RubyStart: Integer;
begin
  Result := False;
  BaseText := '';
  RubyText := '';
  NextIndex := StartIndex;

  BaseEnd := PosEx(']', Source, StartIndex + 1);
  if (BaseEnd = 0) or (BaseEnd + 1 > Length(Source)) or (Source[BaseEnd + 1] <> '(') then
    Exit;

  RubyStart := BaseEnd + 2;
  RubyEnd := PosEx(')', Source, RubyStart);
  if RubyEnd = 0 then
    Exit;

  BaseText := Copy(Source, StartIndex + 1, BaseEnd - StartIndex - 1);
  RubyText := Copy(Source, RubyStart, RubyEnd - RubyStart);
  if (BaseText = '') or (RubyText = '') then
    Exit;

  NextIndex := RubyEnd + 1;
  Result := True;
end;

function TryReadSingleRuby(const Source: string; StartIndex: Integer; out RubyText: string;
  out NextIndex: Integer): Boolean;
var
  RubyEnd: Integer;
  RubyStart: Integer;
begin
  Result := False;
  RubyText := '';
  NextIndex := StartIndex;
  if (StartIndex >= Length(Source)) or (Source[StartIndex + 1] <> '(') then
    Exit;

  RubyStart := StartIndex + 2;
  RubyEnd := PosEx(')', Source, RubyStart);
  if RubyEnd = 0 then
    Exit;

  RubyText := Copy(Source, RubyStart, RubyEnd - RubyStart);
  if RubyText = '' then
    Exit;

  NextIndex := RubyEnd + 1;
  Result := True;
end;

procedure ParseLyrics(const Source: string; out PlainText: string; out RubySpans: TLyricsRubySpans);
var
  BaseText: string;
  Index: Integer;
  NextIndex: Integer;
  RubyText: string;
begin
  PlainText := '';
  SetLength(RubySpans, 0);
  Index := 1;
  while Index <= Length(Source) do
  begin
    if (Source[Index] = '[') and
      TryReadRuby(Source, Index, BaseText, RubyText, NextIndex) then
    begin
      AddRubySpan(RubySpans, Length(PlainText) + 1, Length(BaseText), RubyText);
      PlainText := PlainText + BaseText;
      Index := NextIndex;
      Continue;
    end;

    if TryReadSingleRuby(Source, Index, RubyText, NextIndex) then
    begin
      // 既存仕様では本文が1文字の場合だけ角括弧を省略できる。
      AddRubySpan(RubySpans, Length(PlainText) + 1, 1, RubyText);
      PlainText := PlainText + Source[Index];
      Index := NextIndex;
      Continue;
    end;

    PlainText := PlainText + Source[Index];
    Inc(Index);
  end;
end;

procedure BuildLyricsDisplayUnits(const PlainText: string; const RubySpans: TLyricsRubySpans;
  out Units: TLyricsDisplayUnits);
var
  Position: Integer;
  RubyIndex: Integer;
begin
  SetLength(Units, 0);
  Position := 1;
  RubyIndex := 0;
  while Position <= Length(PlainText) do
  begin
    if (RubyIndex < Length(RubySpans)) and
      (RubySpans[RubyIndex].BaseStart = Position) then
    begin
      AddDisplayUnit(Units, Position, RubySpans[RubyIndex].BaseLength, RubyIndex);
      Inc(Position, RubySpans[RubyIndex].BaseLength);
      Inc(RubyIndex);
    end
    else
    begin
      AddDisplayUnit(Units, Position, 1, -1);
      Inc(Position);
    end;
  end;
end;

end.
