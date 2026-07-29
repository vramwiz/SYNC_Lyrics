object FormLyricsDisplaySettingsDebug: TFormLyricsDisplaySettingsDebug
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #25991#23383#33258#30001#37197#32622#35373#23450#65288#12487#12496#12483#12464#65289
  ClientHeight = 610
  ClientWidth = 820
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object DescriptionLabel: TLabel
    Left = 12
    Top = 12
    Width = 796
    Height = 32
    AutoSize = False
    Caption = #38750#34920#31034#12398#12300#34920#31034#35373#23450#12487#12540#12479#12301#12392#30456#20114#12395#35501#12415#26360#12365#12377#12427#12487#12496#12483#12464#27396#12391#12377#12290
    WordWrap = True
  end
  object BackgroundImage: TImage
    Left = 12
    Top = 48
    Width = 796
    Height = 360
    Center = True
    Proportional = True
    Stretch = True
  end
  object DataMemo: TMemo
    Left = 12
    Top = 420
    Width = 796
    Height = 132
    ScrollBars = ssBoth
    TabOrder = 0
    WantTabs = True
    WordWrap = False
  end
  object ButtonPanel: TPanel
    Left = 0
    Top = 560
    Width = 820
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object ButtonOK: TButton
      Left = 648
      Top = 12
      Width = 75
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object ButtonCancel: TButton
      Left = 733
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
