object FormLyricsMusicSyncSettings: TFormLyricsMusicSyncSettings
  Left = 0
  Top = 0
  Caption = #26354#21516#26399#35373#23450
  ClientHeight = 620
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  DoubleBuffered = True
  Position = poScreenCenter
  TextHeight = 15
  object PianoRollPaintBox: TPaintBox
    Left = 0
    Top = 0
    Width = 900
    Height = 568
    Align = alClient
    OnMouseDown = PianoRollPaintBoxMouseDown
    OnMouseMove = PianoRollPaintBoxMouseMove
    OnMouseUp = PianoRollPaintBoxMouseUp
    OnPaint = PianoRollPaintBoxPaint
  end
  object BottomPanel: TPanel
    Left = 0
    Top = 568
    Width = 900
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
    object LyricsLabel: TLabel
      Left = 16
      Top = 19
      Width = 28
      Height = 15
      Caption = #27468#35422
    end
    object LyricsEdit: TEdit
      Left = 56
      Top = 14
      Width = 472
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
      OnChange = LyricsEditChange
    end
    object ResetSyncButton: TButton
      Left = 540
      Top = 12
      Width = 120
      Height = 28
      Anchors = [akTop, akRight]
      Caption = #21516#26399#12434#21021#26399#21270
      TabOrder = 1
      OnClick = ResetSyncButtonClick
    end
    object ApplyButton: TButton
      Left = 672
      Top = 12
      Width = 100
      Height = 28
      Anchors = [akTop, akRight]
      Caption = #36969#29992
      Default = True
      ModalResult = 1
      TabOrder = 2
    end
    object CloseButton: TButton
      Left = 796
      Top = 12
      Width = 88
      Height = 28
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = #38281#12376#12427
      ModalResult = 2
      TabOrder = 3
    end
  end
end
