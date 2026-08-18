unit TextRendererTypes;

// 描画バックエンドから独立した文字描画要求、測定結果、RGBA画像を定義する。

interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes;

type
  TTextRenderFontStyleItem = (Bold, Italic, Underline, StrikeOut);
  TTextRenderFontStyle = set of TTextRenderFontStyleItem;
  TTextRenderDirection = (Horizontal, Vertical);
  TTextRenderAlignment = (Leading, Center, Trailing);

  TTextRenderOutline = record
    BlurRadius: Single;
    Color: TAlphaColor;
    Width: Single;
    class function Create(const AWidth: Single;
      const AColor: TAlphaColor): TTextRenderOutline; overload; static;
    class function Create(const AWidth, ABlurRadius: Single;
      const AColor: TAlphaColor): TTextRenderOutline; overload; static;
  end;

  TTextRenderShadow = record
    BlurRadius: Single;
    Color: TAlphaColor;
    Offset: TPointF;
    SpreadRadius: Single;
  end;

  TTextRenderRequest = record
    Alignment: TTextRenderAlignment;
    CaptureTextUnits: Boolean;
    Direction: TTextRenderDirection;
    FillColor: TAlphaColor;
    FontFamilies: TArray<string>;
    FontSize: Single;
    FontStyle: TTextRenderFontStyle;
    LetterSpacing: Single;
    LineSpacing: Single;
    MaxHeight: Single;
    MaxWidth: Single;
    Outlines: TArray<TTextRenderOutline>;
    Shadows: TArray<TTextRenderShadow>;
    Text: string;
    TrimTransparentBounds: Boolean;
    class function Default: TTextRenderRequest; static;
  end;

  TTextRenderPixel = packed record
    R: Byte;
    G: Byte;
    B: Byte;
    A: Byte;
  end;
  PTextRenderPixel = ^TTextRenderPixel;

  TTextRenderMetrics = record
    DrawMilliseconds: Double;
    LayoutMilliseconds: Double;
    NonTransparentPixelCount: NativeUInt;
    TotalMilliseconds: Double;
  end;

  TTextRenderImage = class
  private
    FBounds: TRect;
    FLayoutBounds: TRect;
    FLineLayoutBounds: TArray<TRect>;
    FPixels: TArray<TTextRenderPixel>;
    FTextUnitAdvances: TArray<Single>;
    FTextUnitBounds: TArray<TRect>;
    FTextUnitImages: TArray<TTextRenderImage>;
    FTextUnitOrigins: TArray<TPointF>;
    function GetHeight: Integer;
    function GetStride: NativeInt;
    function GetWidth: Integer;
  public
    constructor Create(const ABounds: TRect); overload;
    constructor Create(const ABounds, ALayoutBounds: TRect); overload;
    destructor Destroy; override;
    procedure Clear;
    function Data: PTextRenderPixel;
    function IsEmpty: Boolean;
    function PixelCount: NativeInt;
    procedure SetTextUnitImages(const AImages: TArray<TTextRenderImage>);
    property Bounds: TRect read FBounds;
    property Height: Integer read GetHeight;
    property LayoutBounds: TRect read FLayoutBounds;
    property LineLayoutBounds: TArray<TRect> read FLineLayoutBounds
      write FLineLayoutBounds;
    property Pixels: TArray<TTextRenderPixel> read FPixels;
    property Stride: NativeInt read GetStride;
    // 各文字・グリフの横方向の送り幅。LetterSpacingを含む。
    property TextUnitAdvances: TArray<Single> read FTextUnitAdvances
      write FTextUnitAdvances;
    // レンダラーが配置した文字・グリフ単位の実描画範囲。画像左上を原点とする。
    property TextUnitBounds: TArray<TRect> read FTextUnitBounds
      write FTextUnitBounds;
    // 各文字・グリフだけを描いた独立レイヤー。CaptureTextUnits要求時だけ生成する。
    property TextUnitImages: TArray<TTextRenderImage> read FTextUnitImages;
    // 各文字・グリフの描画原点。画像左上を原点とする。
    property TextUnitOrigins: TArray<TPointF> read FTextUnitOrigins
      write FTextUnitOrigins;
    property Width: Integer read GetWidth;
  end;

implementation

{ TTextRenderOutline }

class function TTextRenderOutline.Create(const AWidth: Single;
  const AColor: TAlphaColor): TTextRenderOutline;
begin
  Result.Width := AWidth;
  Result.BlurRadius := 0;
  Result.Color := AColor;
end;

class function TTextRenderOutline.Create(const AWidth,
  ABlurRadius: Single; const AColor: TAlphaColor): TTextRenderOutline;
begin
  Result.Width := AWidth;
  Result.BlurRadius := ABlurRadius;
  Result.Color := AColor;
end;

{ TTextRenderRequest }

class function TTextRenderRequest.Default: TTextRenderRequest;
begin
  Result := System.Default(TTextRenderRequest);
  Result.Alignment := TTextRenderAlignment.Leading;
  Result.Direction := TTextRenderDirection.Horizontal;
  Result.FillColor := TAlphaColorRec.White;
  Result.FontFamilies := ['Yu Gothic UI', 'Meiryo UI', 'Segoe UI'];
  Result.FontSize := 32;
  Result.TrimTransparentBounds := True;
end;

{ TTextRenderImage }

constructor TTextRenderImage.Create(const ABounds: TRect);
begin
  Create(ABounds, ABounds);
end;

constructor TTextRenderImage.Create(const ABounds,
  ALayoutBounds: TRect);
begin
  inherited Create;
  if (ABounds.Width < 0) or (ABounds.Height < 0) then
    raise EArgumentOutOfRangeException.Create('Image bounds must not have negative dimensions.');
  if (ALayoutBounds.Width < 0) or (ALayoutBounds.Height < 0) then
    raise EArgumentOutOfRangeException.Create(
      'Image layout bounds must not have negative dimensions.');
  FBounds := ABounds;
  FLayoutBounds := ALayoutBounds;
  SetLength(FPixels, NativeInt(ABounds.Width) * ABounds.Height);
end;

destructor TTextRenderImage.Destroy;
var
  Image: TTextRenderImage;
begin
  for Image in FTextUnitImages do
    Image.Free;
  inherited;
end;

procedure TTextRenderImage.Clear;
begin
  if Length(FPixels) > 0 then
    FillChar(FPixels[0], Length(FPixels) * SizeOf(TTextRenderPixel), 0);
end;

function TTextRenderImage.Data: PTextRenderPixel;
begin
  if Length(FPixels) = 0 then
    Result := nil
  else
    Result := @FPixels[0];
end;

function TTextRenderImage.GetHeight: Integer;
begin
  Result := FBounds.Height;
end;

function TTextRenderImage.GetStride: NativeInt;
begin
  Result := NativeInt(Width) * SizeOf(TTextRenderPixel);
end;

function TTextRenderImage.GetWidth: Integer;
begin
  Result := FBounds.Width;
end;

function TTextRenderImage.IsEmpty: Boolean;
begin
  Result := Length(FPixels) = 0;
end;

function TTextRenderImage.PixelCount: NativeInt;
begin
  Result := Length(FPixels);
end;

procedure TTextRenderImage.SetTextUnitImages(
  const AImages: TArray<TTextRenderImage>);
var
  Image: TTextRenderImage;
begin
  for Image in FTextUnitImages do
    Image.Free;
  FTextUnitImages := System.Copy(AImages, 0, Length(AImages));
end;

end.
