object FormLyricsSyncEditor: TFormLyricsSyncEditor
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = #27468#35422#21516#26399#32232#38598
  ClientHeight = 620
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object ContentPanel: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 568
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 0
    object LineListPanel: TPanel
      Left = 0
      Top = 0
      Width = 320
      Height = 568
      Align = alLeft
      BevelOuter = bvNone
      BorderWidth = 12
      TabOrder = 0
      object LineToolbarPanel: TPanel
        Left = 12
        Top = 12
        Width = 296
        Height = 32
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
      end
      object FrameCommandPanel: TPanel
        Left = 12
        Top = 44
        Width = 296
        Height = 36
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 1
        object CurrentFrameLabel: TLabel
          Left = 0
          Top = 10
          Width = 296
          Height = 15
          AutoSize = False
          Caption = #29694#22312#20301#32622': '#21462#24471#19981#21487
        end
      end
      object LineListBox: TSyncLyricsListBoxEdit
        Left = 12
        Top = 80
        Width = 296
        Height = 476
        Align = alClient
        ItemHeight = 28
        Style = lbOwnerDrawFixed
        TabOrder = 2
        OnClick = LineListBoxClick
        OnDblClick = LineListBoxDblClick
        OnDrawItem = LineListBoxDrawItem
        OnKeyDown = LineListBoxKeyDown
      end
    end
    object PlaceholderPanel: TPanel
      Left = 0
      Top = 0
      Width = 900
      Height = 568
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 0
      object PlaceholderLabel: TLabel
        Left = 32
        Top = 32
        Width = 516
        Height = 25
        Alignment = taCenter
        AutoSize = False
        Caption = #21516#26399#32232#38598#30011#38754
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -19
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
    end
  end
  object BottomPanel: TPanel
    Left = 0
    Top = 0
    Width = 900
    Height = 52
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object SyncStateLabel: TLabel
      Left = 140
      Top = 12
      Width = 132
      Height = 28
      AutoSize = False
      Caption = #21516#26399': '#26410#35373#23450
      Layout = tlCenter
    end
  end
end
