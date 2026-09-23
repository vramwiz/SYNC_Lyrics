# 配布ファイル

Release構成のFilterをビルドしてから`make_release_zip.bat`を実行する。
`SYNC_Lyrics.zip`には`SYNC_Lyrics/`フォルダー以下のFilter、Skia、FFmpeg DLLと
ライセンス文書と`Samples/`の歌詞同期データを収録する。生成ZIPはGitへ登録しない。

`SYNC_Lyrics.catalog.json`はAviUtl2カタログ登録用の下書き。
GitHub ReleaseへZIPを登録する際にタグ名と公開日を確定し、`version`配列へ
参照先の形式に従って版、公開日、`SYNC_Lyrics_Filter.auf2`の`XXH3_128`を追加する。
ハッシュはZIP内のFilterファイルに対して計算する。
