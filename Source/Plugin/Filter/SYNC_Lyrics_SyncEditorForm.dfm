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
      object LineListHeaderLabel: TLabel
        Left = 12
        Top = 12
        Width = 132
        Height = 28
        Align = alTop
        AutoSize = False
        Caption = #27468#35422#34892
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -15
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object AddLineButton: TButton
        Left = 164
        Top = 8
        Width = 68
        Height = 26
        Anchors = [akTop, akRight]
        Caption = #36861#21152
        TabOrder = 1
        OnClick = AddLineButtonClick
      end
      object DeleteLineButton: TButton
        Left = 240
        Top = 8
        Width = 68
        Height = 26
        Anchors = [akTop, akRight]
        Caption = #21066#38500
        TabOrder = 2
        OnClick = DeleteLineButtonClick
      end
      object FrameCommandPanel: TPanel
        Left = 12
        Top = 40
        Width = 296
        Height = 36
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 3
        object CurrentFrameLabel: TLabel
          Left = 148
          Top = 10
          Width = 148
          Height = 15
          AutoSize = False
          Caption = #29694#22312#20301#32622': '#21462#24471#19981#21487
        end
        object StartFrameButton: TButton
          Left = 0
          Top = 4
          Width = 70
          Height = 27
          Caption = #38283#22987#35373#23450
          TabOrder = 0
          OnClick = StartFrameButtonClick
        end
        object EndFrameButton: TButton
          Left = 74
          Top = 4
          Width = 70
          Height = 27
          Caption = #32066#20102#35373#23450
          TabOrder = 1
          OnClick = EndFrameButtonClick
        end
      end
      object LineHintLabel: TLabel
        Left = 12
        Top = 526
        Width = 296
        Height = 30
        Align = alBottom
        AutoSize = False
        Caption = #25968#23383#12461#12540' 1'#65374'3: '#34920#31034#27573#12434#35373#23450#12375#12390#27425#12398#34892#12408' / F2: '#27083#25991#32232#38598
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        WordWrap = True
      end
      object LineListBox: TListBox
        Left = 12
        Top = 76
        Width = 296
        Height = 450
        Align = alClient
        ItemHeight = 28
        Style = lbOwnerDrawFixed
        TabOrder = 0
        OnClick = LineListBoxClick
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
      object SummaryLabel: TLabel
        Left = 32
        Top = 76
        Width = 516
        Height = 68
        Alignment = taCenter
        AutoSize = False
        Caption = '-'
        WordWrap = True
      end
    end
  end
  object BottomPanel: TPanel
    Left = 0
    Top = 568
    Width = 900
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object SyncStateLabel: TLabel
      Left = 336
      Top = 18
      Width = 112
      Height = 15
      AutoSize = False
      Caption = #21516#26399': '#26410#35373#23450
    end
    object ConfirmSyncButton: TButton
      Left = 456
      Top = 11
      Width = 136
      Height = 30
      Caption = #21516#26399#12434#30906#23450
      TabOrder = 0
      OnClick = ConfirmSyncButtonClick
    end
    object FinishButton: TButton
      Left = 664
      Top = 11
      Width = 128
      Height = 30
      Caption = #36969#29992#12375#12390#38281#12376#12427
      TabOrder = 1
      OnClick = FinishButtonClick
    end
    object CancelButton: TButton
      Left = 800
      Top = 11
      Width = 88
      Height = 30
      Cancel = True
      Caption = #12461#12515#12531#12475#12523
      ModalResult = 2
      TabOrder = 2
    end
  end
end
