object FormLyricsManualSyncSettings: TFormLyricsManualSyncSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #25163#21205#21516#26399#35373#23450
  ClientHeight = 650
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  DoubleBuffered = True
  KeyPreview = True
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnMouseWheel = FormMouseWheel
  PixelsPerInch = 96
  TextHeight = 15
  object TitleLabel: TLabel
    Left = 24
    Top = 20
    Width = 164
    Height = 21
    Caption = #25163#21205#21516#26399#29992#38899#22768#12501#12449#12452#12523
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -16
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object FileCaptionLabel: TLabel
    Left = 24
    Top = 64
    Width = 52
    Height = 15
    Caption = #12501#12449#12452#12523
  end
  object FileValueLabel: TLabel
    Left = 120
    Top = 64
    Width = 756
    Height = 15
    AutoSize = False
    Caption = '-'
    EllipsisPosition = epPathEllipsis
  end
  object DurationCaptionLabel: TLabel
    Left = 24
    Top = 96
    Width = 52
    Height = 15
    Caption = #20877#29983#26178#38291
  end
  object DurationValueLabel: TLabel
    Left = 120
    Top = 96
    Width = 6
    Height = 15
    Caption = '-'
  end
  object SampleRateCaptionLabel: TLabel
    Left = 24
    Top = 128
    Width = 86
    Height = 15
    Caption = #12469#12531#12503#12523#12524#12540#12488
  end
  object SampleRateValueLabel: TLabel
    Left = 120
    Top = 128
    Width = 6
    Height = 15
    Caption = '-'
  end
  object ChannelsCaptionLabel: TLabel
    Left = 24
    Top = 160
    Width = 52
    Height = 15
    Caption = #12481#12515#12531#12493#12523
  end
  object ChannelsValueLabel: TLabel
    Left = 120
    Top = 160
    Width = 6
    Height = 15
    Caption = '-'
  end
  object PlaybackCaptionLabel: TLabel
    Left = 24
    Top = 194
    Width = 52
    Height = 15
    Caption = #20877#29983#25805#20316
  end
  object PlaybackPositionLabel: TLabel
    Left = 812
    Top = 194
    Width = 84
    Height = 15
    Caption = '0.000 / 0.000 '#31186
  end
  object StatusLabel: TLabel
    Left = 24
    Top = 616
    Width = 664
    Height = 15
    Caption = #27874#24418#34920#31034#12539#20877#29983#12539#22659#30028#32232#38598#12399#27425#12398#27573#38542#12391#36861#21152#12375#12414#12377#12290
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object WaveformPaintBox: TPaintBox
    Left = 24
    Top = 226
    Width = 852
    Height = 300
    Hint = #12507#12452#12540#12523': '#25313#22823#32302#23567' / Shift+'#12507#12452#12540#12523': '#26178#38291#36600#31227#21205
    ParentShowHint = False
    ShowHint = True
    OnMouseDown = WaveformPaintBoxMouseDown
    OnMouseMove = WaveformPaintBoxMouseMove
    OnMouseUp = WaveformPaintBoxMouseUp
    OnPaint = WaveformPaintBoxPaint
  end
  object LyricsCaptionLabel: TLabel
    Left = 24
    Top = 540
    Width = 26
    Height = 15
    Caption = #27468#35422
  end
  object PlayButton: TButton
    Left = 200
    Top = 188
    Width = 80
    Height = 27
    Caption = #20877#29983
    TabOrder = 1
    OnClick = PlayButtonClick
  end
  object StopButton: TButton
    Left = 120
    Top = 188
    Width = 72
    Height = 27
    Caption = #20572#27490
    TabOrder = 0
    OnClick = StopButtonClick
  end
  object RateComboBox: TComboBox
    Left = 288
    Top = 190
    Width = 88
    Height = 23
    Style = csDropDownList
    ItemIndex = 0
    TabOrder = 2
    Text = '1.0 '#20493#36895
    OnChange = RateComboBoxChange
    Items.Strings = (
      '1.0 '#20493#36895
      '0.5 '#20493#36895
      '0.25 '#20493#36895)
  end
  object LoopCheckBox: TCheckBox
    Left = 736
    Top = 192
    Width = 72
    Height = 17
    Caption = #12523#12540#12503
    Checked = True
    State = cbChecked
    TabOrder = 6
  end
  object AdjustModeButton: TButton
    Left = 392
    Top = 188
    Width = 96
    Height = 27
    Caption = #35519#25972#12514#12540#12489
    TabOrder = 3
    OnClick = AdjustModeButtonClick
  end
  object TimingModeButton: TButton
    Left = 496
    Top = 188
    Width = 112
    Height = 27
    Caption = #12479#12452#12511#12531#12464#20837#21147
    TabOrder = 4
    OnClick = TimingModeButtonClick
  end
  object RearmButton: TButton
    Left = 616
    Top = 188
    Width = 104
    Height = 27
    Caption = #25171#12385#30452#12375
    TabOrder = 5
    OnClick = RearmButtonClick
  end
  object LyricsMemo: TMemo
    Left = 64
    Top = 536
    Width = 812
    Height = 58
    ScrollBars = ssVertical
    TabOrder = 7
    OnChange = LyricsMemoChange
  end
  object ApplyButton: TButton
    Left = 704
    Top = 606
    Width = 84
    Height = 28
    Caption = #30906#23450
    Default = True
    TabOrder = 8
    OnClick = ApplyButtonClick
  end
  object CancelButton: TButton
    Left = 796
    Top = 606
    Width = 88
    Height = 28
    Cancel = True
    Caption = #12461#12515#12531#12475#12523
    ModalResult = 2
    TabOrder = 9
  end
  object PlaybackTimer: TTimer
    Enabled = False
    Interval = 30
    OnTimer = PlaybackTimerTimer
    Left = 656
    Top = 608
  end
end
