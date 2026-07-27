object FormLyricsFontSettings: TFormLyricsFontSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'フォント設定'
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
    Width = 48
    Height = 15
    Caption = '本文用'
  end
  object RubyFontLabel: TLabel
    Left = 386
    Top = 12
    Width = 48
    Height = 15
    Caption = 'ルビ用'
  end
  object BasePreviewPanel: TPanel
    Left = 12
    Top = 33
    Width = 362
    Height = 72
    BevelOuter = bvLowered
    Caption = 'aA1 あいうえお 漢字'
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
    Caption = 'ルビ ふりがな'
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
    Height = 329
    ItemHeight = 15
    Sorted = True
    TabOrder = 2
    OnClick = BaseFontListClick
  end
  object RubyFontList: TListBox
    Left = 386
    Top = 113
    Width = 362
    Height = 329
    ItemHeight = 15
    Sorted = True
    TabOrder = 3
    OnClick = RubyFontListClick
  end
  object ButtonPanel: TPanel
    Left = 0
    Top = 450
    Width = 760
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 4
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
      Caption = 'キャンセル'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
