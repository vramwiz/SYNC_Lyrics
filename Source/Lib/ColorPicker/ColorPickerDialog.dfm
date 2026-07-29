object FormColorPickerDialog: TFormColorPickerDialog
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #33394#36984#25246#12480#12452#12450#12525#12464
  ClientHeight = 267
  ClientWidth = 320
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnShow = FormShow
  Position = poScreenCenter
  TextHeight = 15
  object Panel1: TPanel
    Left = 0
    Top = 235
    Width = 320
    Height = 32
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitTop = 160
    ExplicitWidth = 243
    object btnOk: TButton
      Left = 0
      Top = 0
      Width = 160
      Height = 32
      Align = alLeft
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
      TabStop = False
    end
    object btnCancel: TButton
      Left = 160
      Top = 0
      Width = 160
      Height = 32
      Align = alClient
      Cancel = True
      Caption = #12461#12515#12531#12475#12523
      ModalResult = 2
      TabOrder = 1
      TabStop = False
      ExplicitWidth = 106
    end
  end
end
