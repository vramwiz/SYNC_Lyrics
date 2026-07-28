object FormLyricsMusicSyncSettings: TFormLyricsMusicSyncSettings
  Left = 0
  Top = 0
  Caption = '曲同期設定'
  ClientHeight = 620
  ClientWidth = 900
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  TextHeight = 15
  object AnchorDescriptionLabel: TLabel
    Left = 16
    Top = 16
    Width = 268
    Height = 15
    Caption = '最後にFilterが発火した位置を編集の基準にします。'
  end
  object AnchorFrameLabel: TLabel
    Left = 16
    Top = 48
    Width = 131
    Height = 15
    Caption = '基準絶対フレーム: 未取得'
  end
  object AnchorTimeLabel: TLabel
    Left = 16
    Top = 72
    Width = 244
    Height = 15
    Caption = '基準時刻: Filterを一度描画してから開いてください'
  end
  object MusicFileLabel: TLabel
    Left = 16
    Top = 108
    Width = 68
    Height = 15
    Caption = '音楽ファイル'
  end
  object TrackLabel: TLabel
    Left = 16
    Top = 140
    Width = 43
    Height = 15
    Caption = 'トラック'
  end
  object TrackValueLabel: TLabel
    Left = 96
    Top = 140
    Width = 12
    Height = 15
    Caption = '-1'
  end
  object PianoRollLabel: TLabel
    Left = 16
    Top = 172
    Width = 60
    Height = 15
    Caption = 'ピアノロール'
  end
  object PianoRollPaintBox: TPaintBox
    Left = 16
    Top = 193
    Width = 868
    Height = 337
    OnPaint = PianoRollPaintBoxPaint
  end
  object PianoRollStatusLabel: TLabel
    Left = 16
    Top = 542
    Width = 186
    Height = 15
    Caption = '音楽データはまだ読み込まれていません。'
  end
  object MusicFileEdit: TEdit
    Left = 96
    Top = 104
    Width = 788
    Height = 23
    ReadOnly = True
    TabOrder = 0
  end
  object BottomPanel: TPanel
    Left = 0
    Top = 568
    Width = 900
    Height = 52
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object CloseButton: TButton
      Left = 796
      Top = 12
      Width = 88
      Height = 28
      Cancel = True
      Caption = '閉じる'
      ModalResult = 2
      TabOrder = 0
    end
  end
end
