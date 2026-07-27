unit SongAIUEO;

interface

uses
  Windows, Messages, SysUtils, Classes,System.Types,System.Generics.Collections,
  TypInfo,System.Rtti,System.Generics.Defaults,RTTIPersistent;

type
  TSongAIUEO = class(TPersistent)
  private
    FDics : TStringList;
    procedure Add(const str : string);
  public
    constructor Create();
    destructor Destroy;override;
    //  True:長音記号
    function IsLongVowel(const Lyric: string): Boolean;
    // True : 発音記号
    function IsVoice(const Lyric: string): Boolean;
    function IndexOfDic(const Lyric : string) : Integer;
    // 歌詞をaiueonに変換
    function LyricToAIUEO(const Lyric : string) : string;

    //procedure LyricToAIUEO(note : TSongNoteItem);
  end;


implementation

{ TSongAIUEO }

procedure TSongAIUEO.Add(const str: string);
begin
  FDics.Add(str);
end;

constructor TSongAIUEO.Create;
begin
  FDics := TStringList.Create;
  Add('a=a');
  Add('i=i');
  Add('u=u');
  Add('e=e');
  Add('o=o');
  Add('wo=o');
  Add('あ=a');
  Add('い=i');
  Add('う=u');
  Add('え=e');
  Add('お=o');
  Add('か=a');
  Add('き=i');
  Add('く=u');
  Add('け=e');
  Add('こ=o');
  Add('さ=a');
  Add('し=i');
  Add('す=u');
  Add('せ=e');
  Add('そ=o');
  Add('た=a');
  Add('ち=i');
  Add('つ=u');
  Add('て=e');
  Add('と=o');
  Add('な=a');
  Add('に=i');
  Add('ぬ=u');
  Add('ね=e');
  Add('の=o');
  Add('は=a');
  Add('ひ=i');
  Add('ふ=u');
  Add('へ=e');
  Add('ほ=o');
  Add('ま=a');
  Add('み=i');
  Add('む=u');
  Add('め=e');
  Add('も=o');
  Add('や=a');
  Add('ゆ=u');
  Add('よ=o');
  Add('ら=a');
  Add('り=i');
  Add('る=u');
  Add('れ=e');
  Add('ろ=o');
  Add('わ=a');
  Add('を=o');
  Add('ん=n');
  Add('が=a');
  Add('ぎ=i');
  Add('ぐ=u');
  Add('げ=e');
  Add('ご=o');
  Add('ざ=a');
  Add('じ=i');
  Add('ず=u');
  Add('ぜ=e');
  Add('ぞ=o');
  Add('だ=a');
  Add('ぢ=i');
  Add('づ=u');
  Add('で=e');
  Add('ど=o');
  Add('ば=a');
  Add('び=i');
  Add('ぶ=u');
  Add('べ=e');
  Add('ぼ=o');
  Add('ぱ=a');
  Add('ぴ=i');
  Add('ぷ=u');
  Add('ぺ=e');
  Add('ぽ=o');
  Add('ぁ=a');
  Add('ぃ=i');
  Add('ぅ=u');
  Add('ぇ=e');
  Add('ぉ=o');
  Add('ゃ=a');
  Add('ゅ=u');
  Add('ょ=o');
  Add('っ=n');
  Add('ア=a');
  Add('イ=i');
  Add('ウ=u');
  Add('エ=e');
  Add('オ=o');
  Add('カ=a');
  Add('キ=i');
  Add('ク=u');
  Add('ケ=e');
  Add('コ=o');
  Add('サ=a');
  Add('シ=i');
  Add('ス=u');
  Add('セ=e');
  Add('ソ=o');
  Add('タ=a');
  Add('チ=i');
  Add('ツ=u');
  Add('テ=e');
  Add('ト=o');
  Add('ナ=a');
  Add('ニ=i');
  Add('ヌ=u');
  Add('ネ=e');
  Add('ノ=o');
  Add('ハ=a');
  Add('ヒ=i');
  Add('フ=u');
  Add('ヘ=e');
  Add('ホ=o');
  Add('マ=a');
  Add('ミ=i');
  Add('ム=u');
  Add('メ=e');
  Add('モ=o');
  Add('ヤ=a');
  Add('ユ=u');
  Add('ヨ=o');
  Add('ラ=a');
  Add('リ=i');
  Add('ル=u');
  Add('レ=e');
  Add('ロ=o');
  Add('ワ=a');
  Add('ヲ=o');
  Add('ン=n');
  Add('ガ=a');
  Add('ギ=i');
  Add('グ=u');
  Add('ゲ=e');
  Add('ゴ=o');
  Add('ザ=a');
  Add('ジ=i');
  Add('ズ=u');
  Add('ゼ=e');
  Add('ゾ=o');
  Add('ダ=a');
  Add('ヂ=i');
  Add('ヅ=u');
  Add('デ=e');
  Add('ド=o');
  Add('バ=a');
  Add('ビ=i');
  Add('ブ=u');
  Add('ベ=e');
  Add('ボ=o');
  Add('パ=a');
  Add('ピ=i');
  Add('プ=u');
  Add('ペ=e');
  Add('ポ=o');
  Add('ァ=a');
  Add('ィ=i');
  Add('ゥ=u');
  Add('ェ=e');
  Add('ォ=o');
  Add('ャ=a');
  Add('ュ=u');
  Add('ョ=o');
  Add('ッ=n');
  Add('ヴ=u');

end;

destructor TSongAIUEO.Destroy;
begin
  FDics.Free;
  inherited;
end;

function TSongAIUEO.IndexOfDic(const Lyric: string): Integer;
begin
  Result := FDics.IndexOf(Lyric);
end;

function TSongAIUEO.IsLongVowel(const Lyric: string): Boolean;
const
  TBL: array[0..3] of string = (
    'ー', '－', '-', ' '
  );
var
  i: Integer;
begin
  Result := False;
  if Lyric = '' then Exit;

  for i := Low(TBL) to High(TBL) do begin
    if Lyric = TBL[i] then Exit(True);
  end;
end;

function TSongAIUEO.IsVoice(const Lyric: string): Boolean;
var
  i : Integer;
begin
  if IsLongVowel(Lyric) then Exit(True);
  i := FDics.IndexOfName(Lyric);
  Result := i <> -1;
end;

function TSongAIUEO.LyricToAIUEO(const Lyric: string): string;
begin
  Result := FDics.Values[Lyric];
end;

{
procedure TSongAIUEO.LyricToAIUEO(note: TSongNoteItem);
var
  i: Integer;
  key, v: string;
  HasLongSuffix: Boolean;
  s: string;
begin
  if note = nil then Exit;

  note.LyricAIUEO := '';

  if note.Lyric = '' then Exit;

  // 作業用文字列
  s := note.Lyric;

  // === 追加：末尾の促音（っ／ッ）を削除 ===
  while (Length(s) > 0) and ((s[Length(s)] = 'っ') or (s[Length(s)] = 'ッ')) do
    Delete(s, Length(s), 1);

  if s = '' then Exit;

  HasLongSuffix := False;

  // === 右側から探索し、変換できた最初の文字を採用 ===
  for i := Length(s) downto 1 do
  begin
    key := s[i];

    // 長音記号は一旦スキップ
    if IsLongVowel(key) then
    begin
      if i = Length(s) then
        HasLongSuffix := True;
      Continue;
    end;

    // 辞書変換
    v := FDics.Values[key];
    if v <> '' then
    begin
      note.LyricAIUEO := v;
      Exit;
    end;

    // 変換できない記号は無視して次へ
  end;

  // === 長音のみだった場合のフォールバック ===
  if HasLongSuffix then
  begin
    if (note.PrevNote <> nil) and (note.PrevNote.LyricAIUEO <> '') then
      note.LyricAIUEO := note.PrevNote.LyricAIUEO
    else
      note.LyricAIUEO := 'a';
  end;
end;
}




end.

