object FrameColorPickerRGBEdit: TFrameColorPickerRGBEdit
  Left = 0
  Top = 0
  Width = 265
  Height = 17
  TabOrder = 0
  object pBoxColor: TPaintBox
    Left = 0
    Top = 0
    Width = 100
    Height = 17
    Align = alClient
    OnPaint = pBoxColorPaint
    ExplicitLeft = -40
    ExplicitTop = -81
    ExplicitWidth = 105
    ExplicitHeight = 105
  end
  object PanelBaseB: TPanel
    Left = 210
    Top = 0
    Width = 55
    Height = 17
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 2
    object PanelB: TPanel
      Left = 0
      Top = 0
      Width = 24
      Height = 17
      Align = alLeft
      BevelOuter = bvNone
      Caption = 'B'
      TabOrder = 0
      ExplicitHeight = 22
    end
    object EditB: TEdit
      Tag = 2
      Left = 24
      Top = 0
      Width = 31
      Height = 17
      Align = alClient
      TabOrder = 1
      OnChange = EditChange
      ExplicitWidth = 51
      ExplicitHeight = 23
    end
  end
  object PanelBaseG: TPanel
    Left = 155
    Top = 0
    Width = 55
    Height = 17
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitLeft = 135
    object PanelG: TPanel
      Left = 0
      Top = 0
      Width = 24
      Height = 17
      Align = alLeft
      BevelOuter = bvNone
      Caption = 'G'
      TabOrder = 0
      ExplicitHeight = 22
    end
    object EditG: TEdit
      Tag = 1
      Left = 24
      Top = 0
      Width = 31
      Height = 17
      Align = alClient
      TabOrder = 1
      OnChange = EditChange
      ExplicitWidth = 51
      ExplicitHeight = 23
    end
  end
  object PanelBaseR: TPanel
    Left = 100
    Top = 0
    Width = 55
    Height = 17
    Align = alRight
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitLeft = 60
    object PanelR: TPanel
      Left = 0
      Top = 0
      Width = 24
      Height = 17
      Align = alLeft
      BevelOuter = bvNone
      Caption = 'R'
      TabOrder = 0
      ExplicitHeight = 22
    end
    object EditR: TEdit
      Left = 24
      Top = 0
      Width = 31
      Height = 17
      Align = alClient
      TabOrder = 1
      OnChange = EditChange
      ExplicitWidth = 42
    end
  end
end
