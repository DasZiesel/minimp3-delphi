object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'miniMP3 DirectShow/OpenAl Player'
  ClientHeight = 299
  ClientWidth = 635
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    635
    299)
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 12
    Top = 276
    Width = 31
    Height = 13
    Anchors = [akLeft, akBottom]
    Caption = 'Label1'
  end
  object Button1: TButton
    Left = 12
    Top = 8
    Width = 125
    Height = 25
    Caption = 'Chunk Stream Play'
    Enabled = False
    TabOrder = 0
    OnClick = Button1Click
  end
  object Memo1: TMemo
    Left = 12
    Top = 39
    Width = 381
    Height = 230
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 1
  end
  object Button2: TButton
    Left = 140
    Top = 8
    Width = 125
    Height = 25
    Caption = 'Stream Play'
    Enabled = False
    TabOrder = 2
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 268
    Top = 8
    Width = 125
    Height = 25
    Caption = 'Write To Wav'
    Enabled = False
    TabOrder = 3
    OnClick = Button3Click
  end
  object Panel1: TPanel
    Left = 399
    Top = 39
    Width = 228
    Height = 230
    Anchors = [akTop, akRight, akBottom]
    BevelKind = bkFlat
    BevelOuter = bvNone
    Caption = 'Drop your MP3 File here...'
    TabOrder = 4
  end
  object ComboBox1: TComboBox
    Left = 399
    Top = 12
    Width = 228
    Height = 21
    Style = csDropDownList
    Anchors = [akTop, akRight]
    ItemIndex = 0
    TabOrder = 5
    Text = 'DirectSound'
    Items.Strings = (
      'DirectSound'
      'OpenAL')
  end
  object SaveDialog1: TSaveDialog
    DefaultExt = '*.wav'
    Filter = 'Wave File|*.wav'
    Left = 416
    Top = 44
  end
end
