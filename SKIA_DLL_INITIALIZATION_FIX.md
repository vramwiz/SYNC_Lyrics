# Delphi 製 AviUtl2 プラグインでの Skia DLL 初期化エラー対策

## 対象となるエラー

次のようなエラーが、AviUtl2 の起動時またはプラグイン走査時に発生する場合を対象とする。

```text
LoadLibrary() [... .auf2] failed
ダイナミック リンク ライブラリ (DLL) 初期化ルーチンの実行に失敗しました。
HRESULT: 0x8007045A
```

`0x8007045A` は Win32 エラー `1114` であり、対象プラグインまたはその依存 DLL の
`DllMain`／初期化処理が失敗したことを意味する。単純な DLL の配置漏れとは区別する。

## 原因

Delphi の DLL では、ユニットの `initialization` 節が DLL のロード中、すなわち
`DllMain` 相当のローダーロック中に実行される。

その中で `LoadLibrary()` により `sk4d.dll` を初回ロードすると、Skia 側の初期化で
OpenGL、フォント、COM、ユーザーインターフェース関連の DLL 初期化が連鎖する。
ローダーロック中の追加 DLL ロードは Windows の安全な使用条件を満たさず、OS、GPU
ドライバー、既にロード済みの DLL の順序によって `1114` になることがある。

```pascal
// 悪い例: DLL の initialization は DllMain 相当である。
initialization
  RuntimeHandle := LoadLibrary(PChar(RuntimeFileName));
```

別プラグインが先に同じ `sk4d.dll` をロードしていると正常に見える場合がある。
この場合は Skia が既にプロセスに存在するため、後続の `LoadLibrary()` で Skia の
初期化処理が再実行されないことがある。これは解決ではなく、ロード順に依存した状態である。

## 修正方針

1. `initialization`／`finalization` 節から `LoadLibrary()`／`FreeLibrary()` を削除する。
2. DLL と同じフォルダにある `sk4d.dll` の**パス解決だけ**を、軽量なユーティリティ
   関数として残す。
3. ホストがエクスポート関数を呼んだ後、例えば AviUtl2 の `InitializePlugin()` 内で
   `LoadLibrary()` と Skia の初期化を実行する。
4. `UninitializePlugin()` 内で参照を解放する。
5. DLL 本体（`.auf2`）と `sk4d.dll` は引き続き同じ配布・配置フォルダへ入れる。

## 実装例

### 1. ランタイムパスの解決だけを行うユニット

```pascal
unit TextRendererSkiaBootstrap;

interface

function BundledSkiaRuntimeFileName: string;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

function BundledSkiaRuntimeFileName: string;
var
  Buffer: array[0..32767] of Char;
  Length: DWORD;
begin
  Length := GetModuleFileName(HInstance, Buffer, System.Length(Buffer));
  if Length = 0 then
    RaiseLastOSError;
  SetString(Result, Buffer, Length);
  Result := ExtractFilePath(Result) + 'sk4d.dll';
end;

end.
```

このユニットには `initialization`、`finalization`、`LoadLibrary()`、`FreeLibrary()` を
置かない。

### 2. AviUtl2 の公開初期化関数でロードする

```pascal
function InitializePlugin(Version: Cardinal): Byte; cdecl;
begin
  TTextRendererSkiaRuntime.Acquire(BundledSkiaRuntimeFileName);
  try
    InitializePluginState;
    Result := 1;
  except
    TTextRendererSkiaRuntime.Release;
    raise;
  end;
end;

procedure UninitializePlugin; cdecl;
begin
  FinalizePluginState;
  TTextRendererSkiaRuntime.Release;
end;
```

実プロジェクトで既に `InitializePlugin()` から初期化手続きへ委譲している場合は、
その委譲先で `Acquire()` を一度だけ呼ぶ。失敗した場合に対応する `Release()` を行い、
Delphi 例外を AviUtl2 のコールバック境界外へ漏らさない。

## 確認手順

1. `TextRendererSkiaBootstrap` および使用ユニットを検索し、`initialization` 節からの
   `LoadLibrary` が残っていないことを確認する。
2. Win64 Release をビルドする。
3. 生成した `.auf2` と `sk4d.dll` を同じプラグインフォルダへ配置する。
4. Skia を使用する他プラグインをアンインストールまたは無効化した状態で AviUtl2 を起動する。
5. `LoadLibrary failed` と `0x8007045A` が出ないことを確認する。
6. 初期化成功後に、文字描画・Skia を使う編集画面・アンロード時の終了処理を確認する。

## 注意点

- `sk4d.dll` を同じフォルダへ置くだけでは、ローダーロック中に初回ロードする問題は解決しない。
- 他プラグインが先に動くことで再現しなくなる場合でも、そのロード順に依存する回避策にはしない。
- `LoadLibrary` の失敗コードが `126` なら DLL または依存 DLL の未配置を疑う。`1114` なら
  DLL 初期化の失敗を優先して調べる。
- 同じファイル名の Skia ランタイムを複数プラグインが使う場合も、各プラグインは DLL
  ロード完了後の公開初期化関数から取得する設計に統一する。
