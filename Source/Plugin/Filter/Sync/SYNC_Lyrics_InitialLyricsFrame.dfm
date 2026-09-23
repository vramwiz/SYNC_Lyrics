object FrameLyricsInitialInput: TFrameLyricsInitialInput
  Left = 0
  Top = 0
  Width = 880
  Height = 560
  Align = alClient
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  ParentBackground = False
  ParentColor = False
  ParentFont = False
  TabOrder = 0
  DesignSize = (
    880
    560)
  object HeaderLabel: TLabel
    Left = 24
    Top = 24
    Width = 832
    Height = 25
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = #27468#35422#20840#20307#12434#20837#21147
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -19
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object InstructionsLabel: TLabel
    Left = 24
    Top = 59
    Width = 832
    Height = 38
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = #26354#20840#20307#12398#27468#35422#12434#34892#21336#20301#12391#20837#21147#12375#12390#12367#12384#12373#12356#12290#12523#12499#12399' ['#26412#25991']('#12523#12499') '#24418#24335#12391#35352#36848#12391#12365#12414#12377#12290
    WordWrap = True
  end
  object StatusLabel: TLabel
    Left = 24
    Top = 518
    Width = 720
    Height = 18
    Anchors = [akLeft, akRight, akBottom]
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clRed
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object LyricsMemo: TMemo
    Left = 24
    Top = 108
    Width = 832
    Height = 392
    Anchors = [akLeft, akTop, akRight, akBottom]
    ScrollBars = ssBoth
    TabOrder = 0
    WantTabs = True
    WordWrap = False
  end
  object ConfirmButton: TButton
    Left = 752
    Top = 512
    Width = 104
    Height = 30
    Anchors = [akRight, akBottom]
    Caption = #27468#35422#12434#30906#23450
    Default = True
    TabOrder = 1
    OnClick = ConfirmButtonClick
  end
end
