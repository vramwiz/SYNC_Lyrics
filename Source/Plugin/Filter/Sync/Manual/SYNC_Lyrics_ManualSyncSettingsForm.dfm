object FormLyricsManualSyncSettings: TFormLyricsManualSyncSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #25163#21205#21516#26399#35373#23450
  ClientHeight = 650
  ClientWidth = 900
  Color = clBtnFace
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnMouseWheel = FormMouseWheel
  TextHeight = 15
  object FileValueLabel: TLabel
    Left = 24
    Top = 18
    Width = 852
    Height = 20
    AutoSize = False
    Caption = '-'
    EllipsisPosition = epPathEllipsis
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
    ParentShowHint = False
    ShowHint = True
  end
  object PlaybackPositionLabel: TLabel
    Left = 716
    Top = 56
    Width = 160
    Height = 15
    Alignment = taRightJustify
    AutoSize = False
    Caption = '0.000 / 0.000 '#31186
  end
  object StatusLabel: TLabel
    Left = 24
    Top = 616
    Width = 3
    Height = 15
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object WaveformPaintBox: TPaintBox
    Left = 24
    Top = 90
    Width = 852
    Height = 405
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
    Top = 511
    Width = 26
    Height = 15
    Caption = #27468#35422
  end
  object PlayButton: TButton
    Left = 24
    Top = 50
    Width = 80
    Height = 27
    Caption = #20877#29983
    TabOrder = 0
    OnClick = PlayButtonClick
  end
  object RateComboBox: TComboBox
    Left = 112
    Top = 52
    Width = 88
    Height = 23
    Style = csDropDownList
    ItemIndex = 0
    TabOrder = 1
    Text = '1.0 '#20493#36895
    OnChange = RateComboBoxChange
    Items.Strings = (
      '1.0 '#20493#36895
      '0.75 '#20493#36895
      '0.5 '#20493#36895)
  end
  object LoopCheckBox: TCheckBox
    Left = 216
    Top = 54
    Width = 72
    Height = 17
    Caption = #12523#12540#12503
    Checked = True
    State = cbChecked
    TabOrder = 2
  end
  object LyricsMemo: TMemo
    Left = 64
    Top = 506
    Width = 812
    Height = 78
    ScrollBars = ssVertical
    TabOrder = 3
    OnChange = LyricsMemoChange
  end
  object ApplyButton: TButton
    Left = 704
    Top = 606
    Width = 84
    Height = 28
    Caption = #30906#23450
    Default = True
    TabOrder = 4
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
    TabOrder = 5
  end
  object PlaybackTimer: TTimer
    Enabled = False
    Interval = 30
    OnTimer = PlaybackTimerTimer
    Left = 656
    Top = 608
  end
end
