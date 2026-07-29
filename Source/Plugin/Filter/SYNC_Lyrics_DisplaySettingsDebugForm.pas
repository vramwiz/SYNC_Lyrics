unit SYNC_Lyrics_DisplaySettingsDebugForm;

// Provides a minimal editor used to verify hidden filter-data persistence.

interface

uses
  System.Classes,
  System.SysUtils,
  Winapi.Windows,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls;

type
  TFormLyricsDisplaySettingsDebug = class(TForm)
    DescriptionLabel: TLabel;
    BackgroundImage: TImage;
    DataMemo: TMemo;
    ButtonPanel: TPanel;
    ButtonOK: TButton;
    ButtonCancel: TButton;
  public
    function SettingsText: string;
    procedure SetBackgroundRgba(const Pixels: TBytes;
      Width, Height: Integer);
    procedure SetCaptureStatus(const Value: string);
    procedure SetSettingsText(const Value: string);
  end;

implementation

{$R *.dfm}

function TFormLyricsDisplaySettingsDebug.SettingsText: string;
begin
  Result := DataMemo.Text;
end;

procedure TFormLyricsDisplaySettingsDebug.SetBackgroundRgba(
  const Pixels: TBytes; Width, Height: Integer);
var
  Bitmap: TBitmap;
  Destination: PByte;
  Source: PByte;
  X: Integer;
  Y: Integer;
begin
  if (Width <= 0) or (Height <= 0) or
    (Length(Pixels) <> NativeInt(Width) * Height * 4) then
    Exit;

  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := pf32bit;
    Bitmap.SetSize(Width, Height);
    Source := @Pixels[0];
    for Y := 0 to Height - 1 do
    begin
      Destination := Bitmap.ScanLine[Y];
      for X := 0 to Width - 1 do
      begin
        Destination[0] := Source[2];
        Destination[1] := Source[1];
        Destination[2] := Source[0];
        Destination[3] := Source[3];
        Inc(Destination, 4);
        Inc(Source, 4);
      end;
    end;
    BackgroundImage.Picture.Assign(Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TFormLyricsDisplaySettingsDebug.SetCaptureStatus(
  const Value: string);
begin
  DescriptionLabel.Caption := Value;
end;

procedure TFormLyricsDisplaySettingsDebug.SetSettingsText(
  const Value: string);
begin
  DataMemo.Text := Value;
end;

end.
