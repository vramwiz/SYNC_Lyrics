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
    Width = 668
    Height = 510
    Anchors = [akLeft, akTop, akRight, akBottom]
    OnMouseDown = BackgroundPaintBoxMouseDown
    OnMouseMove = BackgroundPaintBoxMouseMove
    OnMouseUp = BackgroundPaintBoxMouseUp
    OnPaint = BackgroundPaintBoxPaint
  end
  object ElementPanel: TPanel
    Left = 692
    Top = 42
    Width = 216
    Height = 510
    Anchors = [akTop, akRight, akBottom]
    BevelOuter = bvNone
    TabOrder = 0
    object ElementListLabel: TLabel
      Left = 0
      Top = 0
      Width = 216
      Height = 20
      AutoSize = False
      Caption = #37197#32622#35201#32032
    end
    object ElementListView: TListView
      Left = 0
      Top = 20
      Width = 216
      Height = 139
      Anchors = [akLeft, akTop, akRight, akBottom]
      Columns = <
        item
          Caption = '#'
          Width = 38
        end
        item
          Caption = #25991#23383
          Width = 150
        end>
      HideSelection = False
      MultiSelect = True
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
      OnSelectItem = ElementListViewSelectItem
    end
    object SelectedSettingsGroup: TGroupBox
      Left = 0
      Top = 167
      Width = 216
      Height = 159
      Anchors = [akLeft, akRight, akBottom]
      Caption = #36984#25246#35201#32032#12398#35373#23450
      TabOrder = 1
      object LabelPositionX: TLabel
        Left = 10
        Top = 25
        Width = 12
        Height = 15
        Caption = 'X'
      end
      object LabelPositionY: TLabel
        Left = 111
        Top = 25
        Width = 11
        Height = 15
        Caption = 'Y'
      end
      object LabelScaleX: TLabel
        Left = 10
        Top = 58
        Width = 30
        Height = 15
        Caption = #27178' %'
      end
      object LabelScaleY: TLabel
        Left = 111
        Top = 58
        Width = 30
        Height = 15
        Caption = #32294' %'
      end
      object EditPositionX: TEdit
        Left = 29
        Top = 21
        Width = 67
        Height = 23
        TabOrder = 0
      end
      object EditPositionY: TEdit
        Left = 128
        Top = 21
        Width = 67
        Height = 23
        TabOrder = 1
      end
      object EditScaleX: TEdit
        Left = 47
        Top = 54
        Width = 49
        Height = 23
        TabOrder = 2
      end
      object EditScaleY: TEdit
        Left = 146
        Top = 54
        Width = 49
        Height = 23
        TabOrder = 3
      end
      object ButtonApplySelectedSettings: TButton
        Left = 10
        Top = 91
        Width = 185
        Height = 26
        Caption = #36984#25246#35201#32032#12408#36969#29992
        TabOrder = 4
        OnClick = ButtonApplySelectedSettingsClick
      end
      object ButtonFont: TButton
        Left = 10
        Top = 122
        Width = 185
        Height = 26
        Caption = #12501#12457#12531#12488'...'
        TabOrder = 5
        OnClick = ButtonFontClick
      end
    end
    object ButtonMoveToCenter: TButton
      Left = 0
      Top = 336
      Width = 216
      Height = 28
      Anchors = [akLeft, akRight, akBottom]
      Caption = #36984#25246#12434#30011#38754#20013#22830#12408
      TabOrder = 2
      OnClick = ButtonMoveToCenterClick
    end
    object ButtonResetSelected: TButton
      Left = 0
      Top = 370
      Width = 216
      Height = 28
      Anchors = [akLeft, akRight, akBottom]
      Caption = #36984#25246#12434#21021#26399#20301#32622#12408
      TabOrder = 3
      OnClick = ButtonResetSelectedClick
    end
    object ButtonResetAll: TButton
      Left = 0
      Top = 404
      Width = 216
      Height = 28
      Anchors = [akLeft, akRight, akBottom]
      Caption = #12377#12409#12390#21021#26399#37197#32622
      TabOrder = 4
      OnClick = ButtonResetAllClick
    end
    object ButtonAlignHorizontal: TButton
      Left = 0
      Top = 438
      Width = 216
      Height = 28
      Anchors = [akLeft, akRight, akBottom]
      Caption = #36984#25246#12434#27178#19968#21015#12408
      TabOrder = 5
      OnClick = ButtonAlignHorizontalClick
    end
    object ButtonDistributeHorizontal: TButton
      Left = 0
      Top = 472
      Width = 216
      Height = 28
      Anchors = [akLeft, akRight, akBottom]
      Caption = #36984#25246#38291#38548#12434#22343#31561#12395
      TabOrder = 6
      OnClick = ButtonDistributeHorizontalClick
    end
  end
  object ButtonPanel: TPanel
    Left = 0
    Top = 560
    Width = 920
    Height = 50
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
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
