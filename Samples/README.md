# 歌詞同期サンプル

- `SYNC_Lyrics_sample.mid`: 120 BPM、1トラック、30音のメロディ。各ノートにUTF-8のMIDI歌詞イベントを入れている。歌詞イベントの文字はひらがな・カタカナだけ。
- `SYNC_Lyrics_sample_lyrics.txt`: 対応する4行の歌詞。漢字部分は`[本文](よみ)`でふりがなを指定している。

Filterの音楽ファイルにMIDIを選び、同期画面へ歌詞テキストの4行を貼り付ける。
MIDIの歌詞とふりがなから自動割り当てされる。MIDIの音を聴く場合はMIDI再生環境が必要。
データを変更するときは`node make_sample_midi.js`で両ファイルを再生成する。
