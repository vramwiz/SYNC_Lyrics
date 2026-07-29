object FormLyricsDisplaySettingsDebug: TFormLyricsDisplaySettingsDebug
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  Caption = #25991#23383#33258#30001#37197#32622#35373#23450
  ClientHeight = 610
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
  object DescriptionLabel: TLabel
    Left = 12
    Top = 12
    Width = 896
    Height = 24
    Anchors = [akLeft, akTop, akRight]
    AutoSize = False
    Caption = #32972#26223#19978#12398#25991#23383#12434#24038#12489#12521#12483#12464#12375#12390#37197#32622#12375#12414#12377#12290
  end
  object BackgroundPaintBox: TPaintBox
    Left = 12
    Top = 42
    Width = 896
    Height = 510
    Anchors = [akLeft, akTop, akRight, akBottom]
    OnMouseDown = BackgroundPaintBoxMouseDown
    OnMouseMove = BackgroundPaintBoxMouseMove
    OnMouseUp = BackgroundPaintBoxMouseUp
    OnPaint = BackgroundPaintBoxPaint
  end
  object ButtonPanel: TPanel
    Left = 0
    Top = 560
    Width = 920
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 0
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
      Caption = #12461#12515#12531#12475#12523
      ModalResult = 2
      TabOrder = 1
    end
  end
end
