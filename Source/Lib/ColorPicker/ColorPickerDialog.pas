unit ColorPickerDialog;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs,ColorPickerDialogFrame, Vcl.StdCtrls,
  Vcl.ExtCtrls;

type
  TFormColorPickerDialog = class(TForm)
    Panel1: TPanel;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FFrame: TFrameColorPickerDialog;
    procedure ProcResize;
    function GetColor: TColor;
    procedure SetColor(const Value: TColor);
  public
    function Execute: Boolean;
    property Color: TColor read GetColor write SetColor;
  end;

function ExecuteColorPicker(AOwner: TComponent;
  var AColor: TColor): Boolean;

implementation

{$R *.dfm}

procedure TFormColorPickerDialog.FormCreate(Sender: TObject);
begin
  FFrame := TFrameColorPickerDialog.Create(Self);
  FFrame.Parent := Self;
  FFrame.Align := alClient;
end;

procedure TFormColorPickerDialog.FormDestroy(Sender: TObject);
begin
end;

procedure TFormColorPickerDialog.FormShow(Sender: TObject);
begin
  ProcResize;
  FFrame.ShowColor;
end;

function TFormColorPickerDialog.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

procedure TFormColorPickerDialog.ProcResize;
begin
  btnOk.Width := ClientWidth div 2;
end;

function TFormColorPickerDialog.GetColor: TColor;
begin
  Result := FFrame.Color;
end;

procedure TFormColorPickerDialog.SetColor(const Value: TColor);
begin
  FFrame.Color := Value;
end;

function ExecuteColorPicker(AOwner: TComponent;
  var AColor: TColor): Boolean;
var
  Dialog: TFormColorPickerDialog;
begin
  Dialog := TFormColorPickerDialog.Create(AOwner);
  try
    Dialog.Color := AColor;
    Result := Dialog.Execute;
    if Result then
      AColor := Dialog.Color;
  finally
    Dialog.Free;
  end;
end;

end.
