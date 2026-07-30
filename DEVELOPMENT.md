# SYNC_Lyrics 開発・運用ルール

安全性、性能、ビルド、配布、コメント、Git運用の規約を置く。
通常は作業対象に関係する節だけを参照する。

## 安全性・性能ルール

- グローバルな可変状態を避け、AviUtl2からの並列呼び出しを前提に共有キャッシュと共有メモリを設計する。
- Input、Filter、GUIの各コールバック境界からDelphi例外を外へ漏らさない。
- ファイルI/O、解析、歌詞データ異常によってAviUtl2を停止・終了させないことを最優先とする。
- 毎フレームの処理ではファイル再読込、不要なメモリ確保、GUI値の書き戻しを行わない。
- 同じ同期データを複数オブジェクトが参照する場合は、解析結果を読み取り専用キャッシュとして共有する。
- ファイル不存在、未知形式、破損、解析失敗時の表示とフォールバック動作は実装前に確定する。

## 共通ビルドルール

- Delphi 37.0を使用し、対象プラットフォームはWin64だけとする。
- `_Input` と `_Filter` の両プロジェクトについて、DebugとReleaseのビルド設定を保つ。
- コンパイル警告とエラーを確認し、原則として警告0、エラー0で完了とする。
- Debugは生成した `.dll` と `.rsm` を調査用に残し、プラグイン拡張子のファイルも作る。
- Releaseは `.aui2` または `.auf2` を作った後、同じ出力先の `.dll` と `.rsm` を削除する。
- `Win32`、`Win64`、`.dcu`、`.rsm`、`.dll`、`.aui2`、`.auf2` はGitHubへ同期しない。
- ビルド前に `C:\ProgramData\aviutl2\Plugin\SYNC_Lyrics` がなければ作成し、DLLを同フォルダーへ出力する。
- Debugは同フォルダーでDLLを `.aui2` または `.auf2` へコピーし、DLLとRSMも残す。
- Releaseは同フォルダーでDLLを `.aui2` または `.auf2` へコピーした後、DLLとRSMを削除する。

作業フォルダーを使うビルドコマンドは次のとおり。

Input Debug Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_Lyrics\SYNC_Lyrics_Input.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Filter Debug Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_Lyrics\SYNC_Lyrics_Filter.dproj"" /t:Build /p:Config=Debug /p:Platform=Win64"
```

Input Release Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_Lyrics\SYNC_Lyrics_Input.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

Filter Release Win64:

```powershell
cmd /c "call ""C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"" && msbuild ""D:\DelphiProg\test\SYNC_Lyrics\SYNC_Lyrics_Filter.dproj"" /t:Build /p:Config=Release /p:Platform=Win64"
```

配備先:

```text
C:\ProgramData\aviutl2\Plugin\SYNC_Lyrics\SYNC_Lyrics_Input.aui2
C:\ProgramData\aviutl2\Plugin\SYNC_Lyrics\SYNC_Lyrics_Filter.auf2
```

## 配布・インストール用変数

パッケージインストーラーのパス指定には、固定の絶対パスではなく次の変数を使う。
特に解析キャッシュ、設定、その他の永続データを配置する段階では `{dataDir}` を使用する。

| 変数 | 指す場所 | 主な用途 |
| --- | --- | --- |
| `{tmp}` | パッケージとバージョンごとに自動作成される一時フォルダー | ダウンロード先、ZIP展開先、コピー元 |
| `{pluginsDir}` | AviUtl2のプラグイン配置先 | `.aui2`、`.auf2`、付属ファイルの配置 |
| `{scriptsDir}` | AviUtl2のスクリプト配置先 | `.anm2` 等のスクリプト配置 |
| `{dataDir}` | `Language`、`Plugin`、`Script` の親に当たるAviUtl2データ保存先 | 永続データ、解析キャッシュ、共通設定 |

インストール処理には `ダウンロード`、`ZIP展開`、`EXE実行`、`コピー` の4種類がある。
ダウンロードとZIP展開では保存先を指定せず、自動作成される `{tmp}` を使用する。
EXEの実行パスと引数、コピー元とコピー先の指定には上記変数を使用する。

コピー元にはファイルまたはフォルダーを指定できるが、コピー先にはフォルダーを指定する。
フォルダーをコピー元にした場合は、そのフォルダー自体ではなく内部のファイル一式がコピー先へ入る。

```text
コピー元: {tmp}/<展開フォルダー>/SYNC_Lyrics
コピー先: {pluginsDir}/SYNC_Lyrics
```

将来データファイルが必要になった場合は、プラグイン本体へ混在させず次のように分ける。

```text
コピー元: {tmp}/<展開フォルダー>/Data/SYNC_Lyrics
コピー先: {dataDir}/SYNC_Lyrics
```

アンインストール処理には `削除` と `EXE実行` を使用できる。利用者が生成した設定や解析キャッシュを
アンインストール時に削除するかは別途決め、インストール物と利用者生成データを同じ削除対象へまとめない。

バージョン管理にはハッシュ値を使用する。ハッシュ対象は主要ファイルに絞り、少なくとも
`SYNC_Lyrics_Input.aui2` と `SYNC_Lyrics_Filter.auf2` を候補とする。

## コメントルール

- コメントはコードを読み直しただけで分かる内容ではなく、目的、責務、注意点、状態や値の意味を補うために書く。
- 古い仕様や現在の実装と食い違うコメントは、見つけた時点で更新する。
- 不要なコメント、同じ内容の重複、処理を日本語へ置き換えただけのコメントを増やさない。
- ユニット先頭には、そのユニットの目的と担当範囲を `//` で書く。
- `interface` に公開する関数・手続きには、呼び出し側から見た責務、入出力、重要な副作用を書く。
- フィールドや定数の短い説明は行末へ置き、同じブロックでは `:`、`=`、`//` の位置を可能な範囲で揃える。
- レコードの各フィールドには用途または値の意味を書き、ABI定義では特に配置と型の理由を明記する。
- コメントと対象の宣言または実装の間に不要な空行を入れない。
- `var` ブロック内へローカル関数・手続きを置かず、必要な補助処理は同じ `implementation` の独立関数へ分ける。
- `property`、`procedure`、`function` の宣言は、112文字以内なら折り返さない。
- 日本語文字列リテラルを持つ `.pas` と `.dpr` はUTF-8 BOM付きで保存する。
- DelphiのSDKレコードはC/C++側のABIと正確に一致させ、フィールド追加時は順序、型、
  アラインメントを公式SDKと照合する。

## GitHub同期ルール

- 同期対象は `.pas`、`.dpr`、`.dproj`、`.res`、文書、配布・検証に必要なスクリプトと素材。
- ビルド成果物、IDEローカル設定、履歴・復旧データは同期しない。
- `.gitattributes` でPascal、プロジェクト、文書の改行をCRLFへ統一する。
- `.res`、画像、WAV、AviUtl2プロジェクト等はbinaryとして扱う。
- GitHub Releasesへ配布物を登録する場合も、通常のGit履歴へビルド成果物を直接追加しない。
