unit ColorPickerSVArea;

{
  ColorPickerSVArea
  -----------------
  彩度（Saturation）と明度（Value）を2次元で選択するためのカラーピッカー領域。
  PaintBox を継承し、指定された BaseColor（Hue 基準色）を元に SV グラデーションを描画する。
  マウス操作により SV 値を変更し、色が変化すると OnChange イベントを通知する。
}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.Math,
  Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics;

type
  PRGBTripleArray = ^TRGBTripleArray;
  TRGBTripleArray = array[0..MaxInt div SizeOf(TRGBTriple) - 1] of TRGBTriple;

type
  TColorPickerSVArea = class(TPaintBox)
  private
    FColor     : TColor;        // 現在選択されている色（RGB）
    FBaseColor : TColor;        // SV グラデーションの基準色（Hue）
    FOnChange  : TNotifyEvent;  // 色が変更された際に通知されるイベント
    FSVBitmap  : TBitmap;       // SV グラデーション描画用の内部ビットマップ

    // 外部から色が設定された際の内部更新処理
    procedure SetColor(const Value: TColor);
    // SV グラデーションの基準色（Hue）を設定する処理
    procedure SetBaseColor(const Value: TColor);
  protected
    // 色変更時に OnChange を発火させるための共通処理
    procedure DoChange; virtual;

    // SV エリア全体の描画処理
    procedure Paint; override;
    // マウスクリックによる SV 選択処理
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    // マウスドラッグによる SV 変更処理
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;

    // 彩度・明度グラデーションを描画する
    procedure PaintSV(const RectAll: TRect);
    // 現在の選択位置を示すカーソルを描画する
    procedure PaintCursor(const RectAll: TRect);
  public
    // コンポーネント生成と内部ビットマップの初期化
    constructor Create(AOwner: TComponent); override;
    // 内部ビットマップなどのリソース解放
    destructor Destroy; override;
  published
    property BaseColor: TColor read FBaseColor write SetBaseColor;
    property Color: TColor read FColor write SetColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;


implementation

uses
  ColorPickerColorMath;

{ TColorPickerSVArea }

constructor TColorPickerSVArea.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  Cursor := crCross;
  FColor := clRed;
  FBaseColor := clRed;
  FSVBitmap := TBitmap.Create;
end;

procedure TColorPickerSVArea.SetBaseColor(const Value: TColor);
begin
  if FBaseColor <> Value then
  begin
    FBaseColor := Value;
    Invalidate; // SV再描画
  end;
end;

procedure TColorPickerSVArea.SetColor(const Value: TColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    Invalidate;
  end;
end;

destructor TColorPickerSVArea.Destroy;
begin
  FSVBitmap.Free;
  inherited;
end;

procedure TColorPickerSVArea.DoChange;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TColorPickerSVArea.Paint;
begin
  PaintSV(ClientRect);

  if Assigned(FSVBitmap) then
    Canvas.Draw(0, 0, FSVBitmap);

  PaintCursor(ClientRect);
end;

procedure TColorPickerSVArea.PaintSV(const RectAll: TRect);
var
  Color: TColor;
  Hue: Double;
  Row: PRGBTripleArray;
  Saturation: Double;
  Value: Double;
  X: Integer;
  Y: Integer;
begin
  if (RectAll.Width <= 0) or (RectAll.Height <= 0) then
    Exit;

  FSVBitmap.SetSize(RectAll.Width, RectAll.Height);
  FSVBitmap.PixelFormat := pf24bit;
  Hue := ColorHue(FBaseColor);
  for Y := 0 to FSVBitmap.Height - 1 do
  begin
    Row := PRGBTripleArray(FSVBitmap.ScanLine[Y]);
    Value := 1 - Y / Max(1, FSVBitmap.Height - 1);
    for X := 0 to FSVBitmap.Width - 1 do
    begin
      Saturation := X / Max(1, FSVBitmap.Width - 1);
      Color := ColorToRGB(HsvToColor(Hue, Saturation, Value));
      Row[X].rgbtBlue := GetBValue(Color);
      Row[X].rgbtGreen := GetGValue(Color);
      Row[X].rgbtRed := GetRValue(Color);
    end;
  end;
end;



procedure TColorPickerSVArea.PaintCursor(const RectAll: TRect);
var
  Hue: Double;
  Saturation: Double;
  Value: Double;
  X: Integer;
  Y: Integer;
begin
  ColorToHsv(FColor, Hue, Saturation, Value);
  X := RectAll.Left + Round(Saturation * (RectAll.Width - 1));
  Y := RectAll.Top + Round((1 - Value) * (RectAll.Height - 1));
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := clBlack;
  Canvas.Ellipse(X - 4, Y - 4, X + 4, Y + 4);
  Canvas.Pen.Color := clWhite;
  Canvas.Ellipse(X - 3, Y - 3, X + 3, Y + 3);
end;

procedure TColorPickerSVArea.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
    MouseMove(Shift + [ssLeft], X, Y);
end;

procedure TColorPickerSVArea.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Hue: Double;
  Saturation: Double;
  Value: Double;
begin
  if not (ssLeft in Shift) or (ClientWidth <= 0) or
    (ClientHeight <= 0) then
    Exit;
  X := EnsureRange(X, 0, ClientWidth - 1);
  Y := EnsureRange(Y, 0, ClientHeight - 1);
  Saturation := X / Max(1, ClientWidth - 1);
  Value := 1 - Y / Max(1, ClientHeight - 1);
  Hue := ColorHue(FBaseColor);
  FColor := HsvToColor(Hue, Saturation, Value);
  Invalidate;
  DoChange;
end;

end.
