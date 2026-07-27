unit AviUtl2FilterTypes;

// AviUtl2 フィルタープラグイン登録に必要な最小ABI定義。

{$ALIGN 8}

interface

type
  LPCWSTR = PWideChar;
  OBJECT_HANDLE = Pointer;

  PEDIT_SECTION = ^TEDIT_SECTION;
  TFilterItemButtonCallback = procedure(Edit: PEDIT_SECTION); cdecl;
  TSetObjectItemValueFunc = function(Obj: OBJECT_HANDLE; Effect: LPCWSTR;
    Item: LPCWSTR; Value: PAnsiChar): Byte; cdecl;
  TGetFocusObjectFunc = function: OBJECT_HANDLE; cdecl;

  // ボタンコールバックで、選択中オブジェクトのGUI項目を一括変更する最小編集API。
  TEDIT_SECTION = record
    Info: Pointer;
    CreateObjectFromAlias: Pointer;
    FindObject: Pointer;
    CountObjectEffect: Pointer;
    GetObjectLayerFrame: Pointer;
    GetObjectAlias: Pointer;
    GetObjectItemValue: Pointer;
    SetObjectItemValue: TSetObjectItemValueFunc;
    MoveObject: Pointer;
    DeleteObject: Pointer;
    GetFocusObject: TGetFocusObjectFunc;
  end;

  PSCENE_INFO = ^TSCENE_INFO;
  TSCENE_INFO = record
    Width, Height: Integer;
    Rate, Scale: Integer;
    SampleRate: Integer;
  end;

  POBJECT_INFO = ^TOBJECT_INFO;
  TOBJECT_INFO = record
    ID: Int64;
    Frame: Integer;
    FrameTotal: Integer;
    Time: Double;
    TimeTotal: Double;
    Width, Height: Integer;
    SampleIndex: Int64;
    SampleTotal: Int64;
    SampleNum: Integer;
    ChannelNum: Integer;
    EffectID: Int64;
    Flag: Integer;
    Layer: Integer;
    Index: Integer;
    Num: Integer;
    FrameS: Integer;
    FrameE: Integer;
  end;

  TPIXEL_RGBA = packed record
    R, G, B, A: Byte;
  end;
  PPIXEL_RGBA = ^TPIXEL_RGBA;

  TFILTER_PROC_VIDEO_GET_TEX2D = function: Pointer; cdecl;
  PFILTER_PROC_VIDEO = ^TFILTER_PROC_VIDEO;
  TFILTER_PROC_VIDEO = record
    Scene: PSCENE_INFO;
    Object_: POBJECT_INFO;
    GetImageData: procedure(Buffer: PPIXEL_RGBA); cdecl;
    SetImageData: procedure(Buffer: PPIXEL_RGBA; Width, Height: Integer); cdecl;
    GetImageTexture2D: TFILTER_PROC_VIDEO_GET_TEX2D;
    GetFramebufferTexture2D: TFILTER_PROC_VIDEO_GET_TEX2D;
  end;

  TFuncProcVideo = function(Video: PFILTER_PROC_VIDEO): Byte; cdecl;
  TFuncProcAudio = function(Audio: Pointer): Byte; cdecl;

  // AviUtl2が1行のUnicode文字列を保持する文字列項目。
  PFILTER_ITEM_STRING = ^TFILTER_ITEM_STRING;
  TFILTER_ITEM_STRING = record
    ItemType: LPCWSTR; // SDK項目種別の固定値 `string`。
    Name    : LPCWSTR; // GUI表示名兼、設定取得時の項目識別名。
    Value   : LPCWSTR; // AviUtl2が管理する現在の文字列。
  end;

  // AviUtl2が現在値と範囲を管理する数値トラック項目。
  PFILTER_ITEM_TRACK = ^TFILTER_ITEM_TRACK;
  TFILTER_ITEM_TRACK = record
    ItemType : LPCWSTR; // SDK項目種別の固定値 `track`。
    Name     : LPCWSTR; // GUI表示名兼、設定取得時の項目識別名。
    Value    : Double;  // 初期値。配置後はAviUtl2が現在値を保持する。
    S        : Double;  // 最小値。
    E        : Double;  // 最大値。
    Step     : Double;  // GUI上の変更単位。
  end;

  // 列挙値から1つを選ぶ選択項目。ListはName=nilの要素で終端する。
  PFILTER_ITEM_SELECT = ^TFILTER_ITEM_SELECT;
  TFILTER_ITEM_SELECT_ITEM = record
    Name : LPCWSTR; // GUIに表示する選択肢名。
    Value: Integer; // 選択時にValueへ格納される識別値。
  end;
  TFILTER_ITEM_SELECT = record
    ItemType: LPCWSTR;                   // SDK項目種別の固定値 `select`。
    Name    : LPCWSTR;                   // GUI表示名兼、設定取得時の項目識別名。
    Value   : Integer;                   // 現在選択されている識別値。
    List    : ^TFILTER_ITEM_SELECT_ITEM; // nil終端された選択肢配列。
  end;

  // 選択中オブジェクトへ設定を反映する編集コールバック付きボタン。
  PFILTER_ITEM_BUTTON = ^TFILTER_ITEM_BUTTON;
  TFILTER_ITEM_BUTTON = record
    ItemType: LPCWSTR;
    Name: LPCWSTR;
    Callback: TFilterItemButtonCallback;
  end;

  // SDK配置はB,G,R,X。Xは予約領域であり、描画アルファには使用しない。
  PFILTER_ITEM_COLOR = ^TFILTER_ITEM_COLOR;
  TFILTER_ITEM_COLOR = record
    ItemType: LPCWSTR; // SDK項目種別の固定値 `color`。
    Name: LPCWSTR;     // GUI表示名兼、設定取得時の項目識別名。
    B, G, R, X: Byte;  // 青、緑、赤、予約領域。
  end;

  // AviUtl2が選択したファイルパスをValueへ保持するファイル選択項目。
  PFILTER_ITEM_FILE = ^TFILTER_ITEM_FILE;
  TFILTER_ITEM_FILE = record
    ItemType   : LPCWSTR; // SDK項目種別の固定値 `file`。
    Name       : LPCWSTR; // GUI表示名兼、設定取得時の項目識別名。
    Value      : LPCWSTR; // AviUtl2が管理する現在のファイルパス。
    FileFilter : LPCWSTR; // ファイル選択ダイアログ用の二重nil終端フィルター。
  end;

  PFILTER_PLUGIN_TABLE = ^TFILTER_PLUGIN_TABLE;
  TFILTER_PLUGIN_TABLE = record
    Flag: Integer;
    Name: LPCWSTR;
    Label_: LPCWSTR;
    Information: LPCWSTR;
    Items: ^Pointer;
    Func_Proc_Video: TFuncProcVideo;
    Func_Proc_Audio: TFuncProcAudio;
  end;

const
  FILTER_FLAG_VIDEO = 1;
  FILTER_FLAG_FILTER = 8;

implementation

end.
