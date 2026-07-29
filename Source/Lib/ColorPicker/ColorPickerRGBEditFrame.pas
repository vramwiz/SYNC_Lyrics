unit ColorPickerRGBEditFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls;

type
  TFrameColorPickerRGBEdit = class(TFrame)
    PanelB: TPanel;
    PanelBaseB: TPanel;
    PanelBaseG: TPanel;
    PanelG: TPanel;
    EditG: TEdit;
    PanelBaseR: TPanel;
    PanelR: TPanel;
    pBoxColor: TPaintBox;
    EditR: TEdit;
    EditB: TEdit;
    procedure pBoxColorPaint(Sender: TObject);
    procedure EditChange(Sender: TObject);
  private
    FColor: TColor;
    FOnChange: TNotifyEvent;
    FUpdating: Boolean;
    procedure SetColor(const Value: TColor);
  protected
    procedure DoChange;
  public
    procedure ShowColor;
    property Color : TColor read FColor write SetColor;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

uses
  System.Math;

{$R *.dfm}

{ TFrameColorPickerRGBEdit }

procedure TFrameColorPickerRGBEdit.pBoxColorPaint(Sender: TObject);
var
  RBack, RFrame, RColor: TRect;
  Col: TColor;
begin
  // 全体
  RBack := pBoxColor.ClientRect;

  // ===== 1. 背景 =====
  pBoxColor.Canvas.Brush.Color := clWhite;
  pBoxColor.Canvas.FillRect(RBack);

  // ===== 2. 枠（少し内側）=====
  RFrame := RBack;
  InflateRect(RFrame, -4, -4);   // ← ここがポイント

  pBoxColor.Canvas.Brush.Style := bsClear;
  pBoxColor.Canvas.Pen.Style   := psSolid;
  pBoxColor.Canvas.Pen.Color   := clGray;
  pBoxColor.Canvas.Rectangle(RFrame);

  // ===== 3. 色表示 =====
  RColor := RFrame;
  InflateRect(RColor, -1, -1);

  Col := ColorToRGB(FColor);

  pBoxColor.Canvas.Brush.Style := bsSolid;
  pBoxColor.Canvas.Brush.Color := Col;
  pBoxColor.Canvas.Pen.Style   := psClear;
  pBoxColor.Canvas.Rectangle(RColor);
end;



procedure TFrameColorPickerRGBEdit.SetColor(const Value: TColor);
begin
  FColor := ColorToRGB(Value);
  ShowColor;
end;

procedure TFrameColorPickerRGBEdit.ShowColor;
var
  Col: TColor;
  R, G, B: Byte;
begin
  Col := ColorToRGB(FColor);

  R := GetRValue(Col);
  G := GetGValue(Col);
  B := GetBValue(Col);

  FUpdating := True;
  try
    EditR.Text := IntToStr(R);
    EditG.Text := IntToStr(G);
    EditB.Text := IntToStr(B);
  finally
    FUpdating := False;
  end;
  pBoxColor.Invalidate;
end;

procedure TFrameColorPickerRGBEdit.EditChange(Sender: TObject);
var
  E: TEdit;
  V: Integer;
  R, G, B: Byte;
begin
  if FUpdating or not (Sender is TEdit) then
    Exit;
  E := TEdit(Sender);
  if (E.Text = '') or not TryStrToInt(E.Text, V) then
    Exit;
  V := EnsureRange(V, 0, 255);
  if E.Text <> IntToStr(V) then
  begin
    FUpdating := True;
    try
      E.Text := IntToStr(V);
      E.SelStart := Length(E.Text);
    finally
      FUpdating := False;
    end;
  end;
  R := GetRValue(ColorToRGB(FColor));
  G := GetGValue(ColorToRGB(FColor));
  B := GetBValue(ColorToRGB(FColor));

  case E.Tag of
    0: R := V;
    1: G := V;
    2: B := V;
  else
    Exit;
  end;

  FColor := RGB(R, G, B);
  pBoxColor.Invalidate;
  DoChange;
end;

procedure TFrameColorPickerRGBEdit.DoChange;
begin
  if Assigned(FOnChange) then
    FOnChange(Self);
end;

end.
