object FormLyricsCharacterLayoutSettings: TFormLyricsCharacterLayoutSettings
  Left = 0
  Top = 0
  BorderStyle = bsSizeable
  Caption = #25991#23383#21336#20301#33258#30001#37197#32622#35373#23450
  ClientHeight = 646
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
    Caption = #20877#12463#12522#12483#12463#12391#40644#33394#65288#31227#21205#12539#22793#24418#65289#8594#27700#33394#65288#25991#23383#38291#65289#8594#32043#65288#12523#12499#65289#12434#20999#26367#12290#24038#21491#28857#12391#38291#38548#12289#32043#12398#19978#28857#12391#12523#12499#20301#32622#12434#35519#25972#12375#12414#12377#12290
  end
  object BackgroundPaintBox: TPaintBox
    Left = 12
    Top = 78
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
    Top = 78
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
      Height = 490
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
  end
  object ButtonPanel: TPanel
    Left = 0
    Top = 596
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
