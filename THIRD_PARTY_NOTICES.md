# Third-party notices

## FFmpeg

SYNC_Lyricsは、WAVの速度変更再生機能のためにFFmpeg共有ライブラリを使用します。

- Product: FFmpeg
- Binary distribution: FFmpeg 8.1.1 full shared Windows build from Gyan.dev
- Build identifier: `8.1.1-full_build-www.gyan.dev`
- Binary license: GNU General Public License version 3
- Upstream project: https://ffmpeg.org/
- Windows build distribution: https://www.gyan.dev/ffmpeg/builds/
- Corresponding FFmpeg source revision:
  https://github.com/FFmpeg/FFmpeg/commit/239f2c733d
- Build support repository: https://github.com/GyanD/codexffmpeg

バイナリ配布元に含まれていたライセンス全文とビルド情報は、変更せず以下へ収録しています。

- `ThirdParty/FFmpeg/LICENSE`
- `ThirdParty/FFmpeg/README.txt`

同梱DLL:

- `avutil-60.dll`
- `swresample-6.dll`
- `swscale-9.dll`
- `avcodec-62.dll`
- `avformat-62.dll`
- `avfilter-11.dll`

FFmpegはFFmpegプロジェクトおよび各貢献者の著作物です。本プロジェクトはFFmpegの
著作権を主張しません。FFmpegはFabrice Bellardに由来する商標です。

## Delphi FFmpeg binding

`Source/Lib/FFmpeg` のDelphiユニットは、同じGPLv3プロジェクトであるVideoMinerの
FFmpegバインディングを基にしています。SYNC_Lyricsで利用する前に、持続型`atempo`
グラフおよび0.25倍速対応へ変更する予定です。

