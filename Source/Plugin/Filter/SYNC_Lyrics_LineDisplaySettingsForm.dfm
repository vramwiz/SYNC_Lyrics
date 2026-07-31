object FormLyricsLineDisplaySettings: TFormLyricsLineDisplaySettings
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  Caption = #49#34892#34920#31034#35373#23450
  ClientHeight = 682
  ClientWidth = 920
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
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
  object DescriptionLabel: TLabel
    Left = 12
    Top = 48
    Width = 896
    Height = 20
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = #26412#25991#12414#12383#12399#12523#12499#12434#36984#25246#12375#12289#12501#12457#12531#12488#19968#35239#12392#12484#12540#12523#12496#12540#12391#23550#35937#20840#20307#12434#32232#38598#12375#12414#12377#12290
  end
  object LyricsLabel: TLabel
    Left = 12
    Top = 83
    Width = 24
    Height = 15
    Caption = #27468#35422
  end
  object SelectionLabel: TLabel
    Left = 12
    Top = 114
    Width = 896
    Height = 20
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = #36984#25246#20013#58#32#26412#25991#20840#20307
  end
  object BaseFontLabel: TLabel
    Left = 12
    Top = 145
    Width = 72
    Height = 15
    Caption = #27468#35422#12501#12457#12531#12488
  end
  object RubyFontLabel: TLabel
    Left = 412
    Top = 145
    Width = 72
    Height = 15
    Caption = #12523#12499#12501#12457#12531#12488
  end
  object PreviewPaintBox: TPaintBox
    Left = 12
    Top = 205
    Width = 896
    Height = 415
    Anchors = [akLeft, akTop, akRight, akBottom]
    OnMouseDown = PreviewPaintBoxMouseDown
    OnMouseMove = PreviewPaintBoxMouseMove
    OnMouseUp = PreviewPaintBoxMouseUp
    OnPaint = PreviewPaintBoxPaint
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
  object LyricsEdit: TEdit
    Left = 52
    Top = 80
    Width = 856
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    MaxLength = 32767
    TabOrder = 1
    OnChange = LyricsEditChange
  end
  object BaseFontCombo: TComboBox
    Left = 92
    Top = 140
    Width = 300
    Height = 23
    Style = csDropDownList
    DropDownCount = 16
    Sorted = True
    TabOrder = 2
    OnChange = BaseFontComboChange
  end
  object RubyFontCombo: TComboBox
    Left = 492
    Top = 140
    Width = 300
    Height = 23
    Style = csDropDownList
    DropDownCount = 16
    Sorted = True
    TabOrder = 3
    OnChange = RubyFontComboChange
  end
  object ButtonPanel: TPanel
    Left = 0
    Top = 632
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
