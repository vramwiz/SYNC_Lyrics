unit TextRenderer;

// 文字描画バックエンドが実装する共通境界を定義する。

interface

uses
  TextRendererTypes;

type
  TCustomTextRenderer = class abstract
  public
    // 診断表示用のバックエンド名を返す。
    function BackendName: string; virtual; abstract;
    // 描画要求をRGBA画像へ変換し、処理時間と画素数を返す。
    function Render(const ARequest: TTextRenderRequest;
      out AMetrics: TTextRenderMetrics): TTextRenderImage; virtual; abstract;
  end;

implementation

end.
