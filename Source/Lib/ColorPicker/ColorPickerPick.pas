unit ColorPickerPick;

{
  ColorPickerPick
  ----------------
  画面全体を一度キャプチャし、その画像を最前面の疑似フルスクリーンフォームに表示することで、
  他アプリを操作せずに「他アプリ上の色を拾っているように見せる」スポイト機能を実現するユニット。
  左クリックで色確定、右クリックまたは ESC、非アクティブ化で即終了する。
}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.Classes, System.Types, System.SysUtils,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms;

type
  TColorPickerPickEvent = procedure(Sender: TObject; const AColor: TColor) of object;

  TColorPickerPick = class
  private
    FActive    : Boolean;                 // スポイトが現在有効かどうか
    FOnPick    : TColorPickerPickEvent;   // 色確定時に呼ばれるイベント
    FOldCursor : TCursor;                 // スポイト開始前のカーソルを保持
    FForm      : TForm;                   // 疑似画面表示用の前面フォーム
    FBitmap    : TBitmap;                 // 画面キャプチャを保持するビットマップ
    FVirtualLeft: Integer;
    FVirtualTop: Integer;
    FVirtualWidth: Integer;
    FVirtualHeight: Integer;

    // 疑似画面フォーム上でのマウスクリック処理（左：確定／右：キャンセル）
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    // 疑似画面フォームでのキー入力処理（ESCでキャンセル）
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    // 疑似画面フォームが非アクティブになった際の即時終了処理
    procedure FormDeactivate(Sender: TObject);
    // 疑似画面フォームの再描画時にキャプチャ画像を描画する
    procedure FormPaint(Sender: TObject);

    // 現在の画面全体をビットマップとしてキャプチャする
    function CaptureScreen: Boolean;
    procedure DetachFormEvents;
    // 指定座標の色を取得し OnPick を通知する
    procedure DoPick(X, Y: Integer);
  public
    // インスタンス生成と内部リソース初期化
    constructor Create;
    // スポイト停止と内部リソース解放
    destructor Destroy; override;

    // スポイト処理を開始し、疑似画面フォームを表示する
    procedure Start;
    // スポイト処理を停止し、疑似画面フォームを破棄する
    procedure Stop;

    property Active: Boolean read FActive;
    property OnPick: TColorPickerPickEvent read FOnPick write FOnPick;
  end;


implementation

const
  CAPTUREBLT_ROP = DWORD($40000000);

{ TColorPickerPick }

constructor TColorPickerPick.Create;
begin
  inherited Create;
  FBitmap := TBitmap.Create;
end;

destructor TColorPickerPick.Destroy;
begin
  if FActive then
    Screen.Cursor := FOldCursor;
  FActive := False;
  if Assigned(FForm) then
  begin
    DetachFormEvents;
    FreeAndNil(FForm);
  end;
  FBitmap.Free;
  inherited Destroy;
end;

function TColorPickerPick.CaptureScreen: Boolean;
var
  DC: HDC;
begin
  Result := False;
  FVirtualLeft := GetSystemMetrics(SM_XVIRTUALSCREEN);
  FVirtualTop := GetSystemMetrics(SM_YVIRTUALSCREEN);
  FVirtualWidth := GetSystemMetrics(SM_CXVIRTUALSCREEN);
  FVirtualHeight := GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if (FVirtualWidth <= 0) or (FVirtualHeight <= 0) then
    Exit;
  FBitmap.PixelFormat := pf24bit;
  FBitmap.SetSize(FVirtualWidth, FVirtualHeight);

  DC := GetDC(0);
  if DC = 0 then
    Exit;
  try
    Result := BitBlt(
      FBitmap.Canvas.Handle,
      0, 0,
      FVirtualWidth,
      FVirtualHeight,
      DC,
      FVirtualLeft,
      FVirtualTop,
      SRCCOPY or CAPTUREBLT_ROP
    );
  finally
    ReleaseDC(0, DC);
  end;
end;

procedure TColorPickerPick.Start;
begin
  if FActive then
    Exit;
  if not CaptureScreen then
    Exit;

  FOldCursor := Screen.Cursor;
  Screen.Cursor := crCross;
  FForm := TForm.Create(nil);
  FForm.BorderStyle := bsNone;
  FForm.FormStyle := fsStayOnTop;
  FForm.Position := poDesigned;
  FForm.Scaled := False;
  FForm.SetBounds(FVirtualLeft, FVirtualTop,
    FVirtualWidth, FVirtualHeight);
  FForm.KeyPreview := True;
  FForm.OnMouseDown := FormMouseDown;
  FForm.OnKeyDown := FormKeyDown;
  FForm.OnDeactivate := FormDeactivate;
  FForm.OnPaint := FormPaint;

  FActive := True;
  FForm.Show;
  FForm.BringToFront;
  FForm.SetFocus;
end;

procedure TColorPickerPick.Stop;
var
  FormToRelease: TForm;
begin
  if not FActive then
    Exit;
  FActive := False;
  Screen.Cursor := FOldCursor;
  if Assigned(FForm) then
  begin
    FormToRelease := FForm;
    FForm := nil;
    FormToRelease.OnMouseDown := nil;
    FormToRelease.OnKeyDown := nil;
    FormToRelease.OnDeactivate := nil;
    FormToRelease.OnPaint := nil;
    FormToRelease.Release;
  end;
end;

procedure TColorPickerPick.DetachFormEvents;
begin
  if not Assigned(FForm) then
    Exit;
  FForm.OnMouseDown := nil;
  FForm.OnKeyDown := nil;
  FForm.OnDeactivate := nil;
  FForm.OnPaint := nil;
end;

procedure TColorPickerPick.FormDeactivate(Sender: TObject);
begin
  Stop;
end;

procedure TColorPickerPick.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Stop;
end;

procedure TColorPickerPick.FormMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  case Button of
    mbLeft:
      begin
        DoPick(X, Y);
        Stop;
      end;
    mbRight:
      Stop;
  end;
end;

procedure TColorPickerPick.FormPaint(Sender: TObject);
begin
  if Assigned(FBitmap) and (Sender is TForm) then
    TForm(Sender).Canvas.Draw(0, 0, FBitmap);
end;

procedure TColorPickerPick.DoPick(X, Y: Integer);
var
  Col: TColor;
begin
  if (X < 0) or (Y < 0) or
    (X >= FBitmap.Width) or (Y >= FBitmap.Height) then
    Exit;
  Col := FBitmap.Canvas.Pixels[X, Y];
  if Assigned(FOnPick) then
    FOnPick(Self, Col);
end;

end.

