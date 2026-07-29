unit ColorPickerHueBar;

{
  ColorPickerHueBar
  -----------------
  色相（Hue）を選択するためのシンプルなカラーバーコンポーネント。
  PaintBox を継承し、色相グラデーションの描画とマウス操作による
  色選択を行う。色が変更されると OnChange イベントを通知する。
}

interface

uses
  System.Classes, Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics, System.Types;

type
  TColorPickerHueBar = class(TPaintBox)
  private
    FColor    : TColor;        // 現在選択されている色（色相を含む）
    FOnChange : TNotifyEvent;  // 色が変更された際に通知されるイベント

    // 色相グラデーション全体を描画する
    procedure PaintGradient(const RectAll: TRect);
    // 現在の色位置を示すカーソルを描画する
    procedure PaintCursor(const RectAll: TRect);
    // 外部から色が設定された際の内部更新処理
    procedure SetColor(const Value: TColor);
  protected
    // 色変更時に OnChange を発火させるための共通処理
    procedure DoChange; virtual;

    // 色相バー全体の描画処理
    procedure Paint; override;
    // マウスクリックによる色相選択処理
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    // マウスドラッグによる色相変更処理
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  public
    // コンポーネント生成と初期化
    constructor Create(AOwner: TComponent); override;
  published
    property Color: TColor read FColor write SetColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;


implementation

uses
  ColorPickerColorMath,
  System.Math,
  Winapi.Windows;

{ TColorPickerHueBar }

constructor TColorPickerHueBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  // PaintBox の基本設定
  ControlStyle := ControlStyle + [csOpaque];
  Cursor := crHandPoint;

  FColor := clRed;
end;

procedure TColorPickerHueBar.SetColor(const Value: TColor);
begin
  if FColor <> Value then
  begin
    FColor := ColorToRGB(Value);
    Invalidate;
  end;
end;

procedure TColorPickerHueBar.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

procedure TColorPickerHueBar.Paint;
var
  RectAll: TRect;
begin
  RectAll := ClientRect;

  PaintGradient(RectAll);
  PaintCursor(RectAll);
end;

procedure TColorPickerHueBar.PaintCursor(const RectAll: TRect);
var
  CurHue: Double;
  Y: Integer;
begin
  CurHue := ColorHue(FColor);
  Y := RectAll.Top + Round(CurHue / 360 * (RectAll.Height - 1));
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Color := clBlack;
  Canvas.Rectangle(RectAll.Left, Y - 3, RectAll.Right, Y + 3);
  Canvas.Pen.Color := clWhite;
  Canvas.Rectangle(RectAll.Left + 1, Y - 2,
    RectAll.Right - 1, Y + 2);
end;


procedure TColorPickerHueBar.PaintGradient(const RectAll: TRect);
var
  Y: Integer;
  Hue: Double;
begin
  for Y := RectAll.Top to RectAll.Bottom - 1 do
  begin
    Hue := 360 * (Y - RectAll.Top) /
      Max(1, RectAll.Height - 1);
    Canvas.Pen.Color := HsvToColor(Hue, 1, 1);
    Canvas.MoveTo(RectAll.Left, Y);
    Canvas.LineTo(RectAll.Right, Y);
  end;
end;


procedure TColorPickerHueBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then
    MouseMove(Shift + [ssLeft], X, Y);
end;

procedure TColorPickerHueBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  H: Double;
begin
  if not (ssLeft in Shift) or (ClientHeight <= 0) then
    Exit;
  Y := EnsureRange(Y, 0, ClientHeight - 1);
  H := 360 * Y / Max(1, ClientHeight - 1);
  FColor := HsvToColor(H, 1, 1);
  Invalidate;
  DoChange;
end;

end.

