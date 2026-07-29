unit ColorPickerDialogFrame;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ColorPickerRGBEditFrame,
  Vcl.ExtCtrls,ColorPickerHueBar, Vcl.Buttons, System.ImageList, Vcl.ImgList,ColorPickerPick,
  ColorPickerSVArea;

type
  TFrameColorPickerDialog = class(TFrame)
    PanelEdit: TPanel;
    Panel1: TPanel;
    PanelHueBar: TPanel;
    spdBtn: TSpeedButton;
    imgList: TImageList;
    PanelSVArea: TPanel;
    procedure FrameResize(Sender: TObject);
    procedure spdBtnClick(Sender: TObject);
  private
    FColor: TColor;
    FCurrentHue: Double;
    FEdit: TFrameColorPickerRGBEdit;
    FHueBar: TColorPickerHueBar;
    FPick: TColorPickerPick;
    FSVArea: TColorPickerSVArea;
    FUpdating: Boolean;
    procedure ProcResize;
    procedure SetColor(const Value: TColor);
    procedure SyncControls;
    procedure OnEditChange(Sender: TObject);
    procedure OnHueBarChange(Sender: TObject);
    procedure OnSVAreaChange(Sender: TObject);
    procedure OnPick(Sender: TObject; const AColor: TColor);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowColor;
    property Color: TColor read FColor write SetColor;
  end;

implementation

uses
  ColorPickerColorMath;

{$R *.dfm}

{ TFrameColorPickerDialog }

constructor TFrameColorPickerDialog.Create(AOwner: TComponent);
begin
  inherited;
  FColor := clWhite;
  FCurrentHue := 0;
  FEdit := TFrameColorPickerRGBEdit.Create(Self);
  FEdit.Parent := PanelEdit;
  FEdit.Align := alClient;
  FEdit.OnChange := OnEditChange;

  FHueBar := TColorPickerHueBar.Create(Self);
  FHueBar.Parent := PanelHueBar;
  FHueBar.Align := alClient;
  FHueBar.OnChange := OnHueBarChange;

  FSVArea := TColorPickerSVArea.Create(Self);
  FSVArea.Parent := PanelSVArea;
  FSVArea.Align := alClient;
  FSVArea.OnChange := OnSVAreaChange;

  FPick := TColorPickerPick.Create;
  FPick.OnPick := OnPick;
end;

destructor TFrameColorPickerDialog.Destroy;
begin
  FPick.Free;
  inherited;
end;

procedure TFrameColorPickerDialog.FrameResize(Sender: TObject);
begin
  ProcResize;
end;

procedure TFrameColorPickerDialog.SetColor(const Value: TColor);
var
  Hue: Double;
  Saturation: Double;
  ColorValue: Double;
begin
  FColor := ColorToRGB(Value);
  ColorToHsv(FColor, Hue, Saturation, ColorValue);
  if (Saturation > 0.000001) and (ColorValue > 0) then
    FCurrentHue := Hue;
  SyncControls;
end;

procedure TFrameColorPickerDialog.SyncControls;
begin
  if FUpdating then
    Exit;
  FUpdating := True;
  try
    FEdit.Color := FColor;
    FHueBar.Color := HsvToColor(FCurrentHue, 1, 1);
    FSVArea.BaseColor := HsvToColor(FCurrentHue, 1, 1);
    FSVArea.Color := FColor;
  finally
    FUpdating := False;
  end;
end;

procedure TFrameColorPickerDialog.ShowColor;
begin
  SyncControls;
  ProcResize;
end;

procedure TFrameColorPickerDialog.spdBtnClick(Sender: TObject);
begin
  if spdBtn.Down then
  begin
    // スポイト開始
    FPick.Start;
  end
  else
  begin
    // スポイト中断
    FPick.Stop;
  end;
end;

procedure TFrameColorPickerDialog.OnEditChange(Sender: TObject);
var
  Hue: Double;
  Saturation: Double;
  ColorValue: Double;
begin
  if FUpdating then
    Exit;
  FColor := FEdit.Color;
  ColorToHsv(FColor, Hue, Saturation, ColorValue);
  if (Saturation > 0.000001) and (ColorValue > 0) then
    FCurrentHue := Hue;
  SyncControls;
end;

procedure TFrameColorPickerDialog.OnHueBarChange(Sender: TObject);
var
  Saturation: Double;
  ColorValue: Double;
begin
  if FUpdating then
    Exit;
  FCurrentHue := ColorHue(FHueBar.Color);
  ColorToSv(FColor, Saturation, ColorValue);
  FColor := HsvToColor(FCurrentHue, Saturation, ColorValue);
  SyncControls;
end;

procedure TFrameColorPickerDialog.OnPick(Sender: TObject; const AColor: TColor);
begin
  SetColor(AColor);
  spdBtn.Down := False;
  FPick.Stop;
end;

procedure TFrameColorPickerDialog.OnSVAreaChange(Sender: TObject);
begin
  if FUpdating then
    Exit;
  FColor := FSVArea.Color;
  SyncControls;
end;

procedure TFrameColorPickerDialog.ProcResize;
begin
  spdBtn.Width := PanelHueBar.Width;
end;

end.
