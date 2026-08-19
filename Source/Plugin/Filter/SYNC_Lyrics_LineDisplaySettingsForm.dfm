object FormLyricsLineDisplaySettings: TFormLyricsLineDisplaySettings
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  Caption = #49#34892#34920#31034#35373#23450
  ClientHeight = 548
  ClientWidth = 920
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  Position = poScreenCenter
  TextHeight = 15
  object CandidateLabel: TLabel
    Left = 12
    Top = 12
    Width = 48
    Height = 15
    Caption = #32232#38598#23550#35937
    Visible = False
  end
  object BaseFontLabel: TLabel
    Left = 12
    Top = 45
    Width = 72
    Height = 15
    Caption = #27468#35422#12501#12457#12531#12488
  end
  object RubyFontLabel: TLabel
    Left = 260
    Top = 45
    Width = 72
    Height = 15
    Caption = #12523#12499#12501#12457#12531#12488
  end
  object PreviewPaintBox: TPaintBox
    Left = 12
    Top = 74
    Width = 896
    Height = 412
    Anchors = [akLeft, akTop, akRight, akBottom]
    OnMouseDown = PreviewPaintBoxMouseDown
    OnMouseMove = PreviewPaintBoxMouseMove
    OnMouseUp = PreviewPaintBoxMouseUp
    OnPaint = PreviewPaintBoxPaint
  end
  object ColorPanel: TPanel
    Left = 720
    Top = 74
    Width = 188
    Height = 412
    Anchors = [akTop, akRight, akBottom]
    BevelOuter = bvNone
    Caption = ''
    TabOrder = 3
  end
  object CandidateCombo: TComboBox
    Left = 68
    Top = 8
    Width = 840
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    Style = csDropDownList
    TabOrder = 0
    Visible = False
    OnChange = CandidateComboChange
  end
  object BaseFontCombo: TComboBox
    Left = 92
    Top = 40
    Width = 150
    Height = 23
    Style = csDropDownList
    DropDownCount = 16
    Sorted = True
    TabOrder = 1
    OnChange = BaseFontComboChange
  end
  object RubyFontCombo: TComboBox
    Left = 340
    Top = 40
    Width = 150
    Height = 23
    Style = csDropDownList
    DropDownCount = 16
    Sorted = True
    TabOrder = 2
    OnChange = RubyFontComboChange
  end
  object ButtonPanel: TPanel
    Left = 0
    Top = 498
    Width = 920
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
    object ButtonOK: TButton
      Left = 748
      Top = 12
      Width = 75
      Height = 26
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object ButtonCancel: TButton
      Left = 833
      Top = 12
      Width = 75
      Height = 26
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
