object FormLyricsFontSettings: TFormLyricsFontSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #12501#12457#12531#12488#35373#23450
  ClientHeight = 500
  ClientWidth = 760
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnShow = FormShow
  TextHeight = 15
  object BaseFontLabel: TLabel
    Left = 12
    Top = 12
    Width = 39
    Height = 15
    Caption = #26412#25991#29992
  end
  object RubyFontLabel: TLabel
    Left = 386
    Top = 12
    Width = 33
    Height = 15
    Caption = #12523#12499#29992
  end
  object BasePreviewPanel: TPanel
    Left = 12
    Top = 33
    Width = 362
    Height = 72
    BevelOuter = bvLowered
    Caption = 'aA1 '#12354#12356#12358#12360#12362' '#28450#23383
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -27
    Font.Name = 'Yu Gothic UI'
    Font.Style = []
    ParentFont = False
    TabOrder = 0
  end
  object RubyPreviewPanel: TPanel
    Left = 386
    Top = 33
    Width = 362
    Height = 72
    BevelOuter = bvLowered
    Caption = #12523#12499' '#12405#12426#12364#12394
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -22
    Font.Name = 'Yu Gothic UI'
    Font.Style = []
    ParentFont = False
    TabOrder = 1
  end
  object BaseFontList: TListBox
    Left = 12
    Top = 113
    Width = 362
    Height = 257
    ItemHeight = 15
    Sorted = True
    TabOrder = 2
    OnClick = BaseFontListClick
  end
  object RubyFontList: TListBox
    Left = 386
    Top = 113
    Width = 362
    Height = 257
    ItemHeight = 15
    Sorted = True
    TabOrder = 3
    OnClick = RubyFontListClick
  end
  object BaseBoldCheck: TCheckBox
    Left = 12
    Top = 380
    Width = 80
    Height = 20
    Caption = #22826#23383
    TabOrder = 4
    OnClick = FontStyleClick
  end
  object BaseItalicCheck: TCheckBox
    Left = 102
    Top = 380
    Width = 80
    Height = 20
    Caption = #26012#20307
    TabOrder = 5
    OnClick = FontStyleClick
  end
  object BaseUnderlineCheck: TCheckBox
    Left = 192
    Top = 380
    Width = 80
    Height = 20
    Caption = #19979#32218
    TabOrder = 6
    OnClick = FontStyleClick
  end
  object BaseStrikeOutCheck: TCheckBox
    Left = 282
    Top = 380
    Width = 92
    Height = 20
    Caption = #21462#12426#28040#12375#32218
    TabOrder = 7
    OnClick = FontStyleClick
  end
  object RubyBoldCheck: TCheckBox
    Left = 386
    Top = 380
    Width = 80
    Height = 20
    Caption = #22826#23383
    TabOrder = 8
    OnClick = FontStyleClick
  end
  object RubyItalicCheck: TCheckBox
    Left = 476
    Top = 380
    Width = 80
    Height = 20
    Caption = #26012#20307
    TabOrder = 9
    OnClick = FontStyleClick
  end
  object RubyUnderlineCheck: TCheckBox
    Left = 566
    Top = 380
    Width = 80
    Height = 20
    Caption = #19979#32218
    TabOrder = 10
    OnClick = FontStyleClick
  end
  object RubyStrikeOutCheck: TCheckBox
    Left = 656
    Top = 380
    Width = 92
    Height = 20
    Caption = #21462#12426#28040#12375#32218
    TabOrder = 11
    OnClick = FontStyleClick
  end
  object ButtonPanel: TPanel
    Left = 0
    Top = 450
    Width = 760
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 12
    object ButtonOK: TButton
      Left = 588
      Top = 12
      Width = 75
      Height = 26
      Caption = 'OK'
      Default = True
      Enabled = False
      ModalResult = 1
      TabOrder = 0
    end
    object ButtonCancel: TButton
      Left = 673
      Top = 12
      Width = 75
      Height = 26
      Cancel = True
      Caption = #12461#12515#12531#12475#12523
      ModalResult = 2
      TabOrder = 1
    end
  end
end
