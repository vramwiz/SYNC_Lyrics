unit SYNC_Lyrics_SerifAnimationItems;

// 表示前・同期・非同期・表示後の演出項目を登録する。

interface

uses
  AviUtl2FilterTypes;

const
  SERIF_SYNC_NONE = 0;
  SERIF_SYNC_COLOR = 1;
  SERIF_SYNC_FRONT = 2;
  SERIF_SYNC_BACKING = 3;
  SERIF_SYNC_UNDERLINE = 4;
  SERIF_SYNC_GLOW = 6;
  SERIF_SYNC_BLINK = 8;
  SERIF_SYNC_GLITCH = 9;
  SERIF_SYNC_MOTION_ZOOM = 16;
  SERIF_SYNC_MOTION_JUMP = 17;
  SERIF_COLOR_FILL_CHARACTER = 0;
  SERIF_COLOR_FILL_SMOOTH = 1;
  SERIF_COLOR_AFTER_RESTORE = 0;
  SERIF_COLOR_AFTER_KEEP = 1;
  SERIF_SYNC_SHAPE_AUTO = 0;
  SERIF_SYNC_SHAPE_CIRCLE = 1;
  SERIF_SYNC_SHAPE_SQUARE = 2;
  SERIF_SYNC_SHAPE_TRIANGLE = 3;

var
  SerifBeforeGroup: TFILTER_ITEM_GROUP = (
    ItemType: 'group'; Name: '表示前'; DefaultVisible: 1);
  SerifBeforeMotionItem: TFILTER_ITEM_SELECT;
  SerifBeforeDisplayItem: TFILTER_ITEM_SELECT;
  SerifBeforeDirectionItem: TFILTER_ITEM_SELECT;
  SerifBeforeZoomOriginItem: TFILTER_ITEM_SELECT;
  SerifBeforeTimeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '前 時間'; Value: 0.30; S: 0.01; E: 3.00;
    Step: 0.01);

  SerifSyncGroup: TFILTER_ITEM_GROUP = (
    ItemType: 'group'; Name: '同期'; DefaultVisible: 1);
  SerifSyncMotionItem: TFILTER_ITEM_SELECT;
  SerifSyncDisplayItem: TFILTER_ITEM_SELECT;
  SerifSyncFillItem: TFILTER_ITEM_SELECT;
  SerifSyncAfterItem: TFILTER_ITEM_SELECT;
  SerifSyncShapeItem: TFILTER_ITEM_SELECT;
  SerifSyncColorItem: TFILTER_ITEM_COLOR = (
    ItemType: 'color'; Name: '同期 色'; B: 0; G: 255; R: 255; X: 255);
  SerifSyncSizeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '同期 サイズ'; Value: 100; S: 1; E: 1000;
    Step: 0.01);
  SerifSyncOffsetXItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: 'オフセットX'; Value: 0; S: -100; E: 100;
    Step: 1);
  SerifSyncOffsetYItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: 'オフセットY'; Value: 0; S: -100; E: 100;
    Step: 1);

  SerifDuringGroup: TFILTER_ITEM_GROUP = (
    ItemType: 'group'; Name: '非同期'; DefaultVisible: 1);
  SerifDuringTypeItem: TFILTER_ITEM_SELECT;
  SerifDuringSpeedItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '非同期 速さ'; Value: 1; S: 0; E: 100;
    Step: 0.01);

  SerifAfterGroup: TFILTER_ITEM_GROUP = (
    ItemType: 'group'; Name: '表示後'; DefaultVisible: 1);
  SerifAfterMotionItem: TFILTER_ITEM_SELECT;
  SerifAfterDisplayItem: TFILTER_ITEM_SELECT;
  SerifAfterDirectionItem: TFILTER_ITEM_SELECT;
  SerifAfterZoomDestinationItem: TFILTER_ITEM_SELECT;
  SerifAfterTimeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '後 時間'; Value: 0.30; S: 0.01; E: 3.00;
    Step: 0.01);

procedure InitializeSerifAnimationItems;

implementation

var
  EdgeMotionList: array[0..21] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: 0),
    (Name: 'スライド'; Value: 2),
    (Name: 'ズーム'; Value: 3),
    (Name: 'ポップ'; Value: 4),
    (Name: '回転'; Value: 5),
    (Name: 'バウンス'; Value: 7),
    (Name: 'フリップ'; Value: 8),
    (Name: '拡大ズーム'; Value: 15),
    (Name: '弾性ズーム'; Value: 16),
    (Name: '回転ズーム'; Value: 17),
    (Name: 'ストレッチ'; Value: 18),
    (Name: '集合・飛散'; Value: 26),
    (Name: '交互スライド'; Value: 27),
    (Name: '弾性スライド'; Value: 29),
    (Name: 'スウィング'; Value: 30),
    (Name: '螺旋'; Value: 31),
    (Name: '字間展開'; Value: 32),
    (Name: 'スクイーズ'; Value: 33),
    (Name: '波に沿う'; Value: 37),
    (Name: 'S字で流れ込む'; Value: 38),
    (Name: 'ジグザグで入る'; Value: 39),
    (Name: nil; Value: 0));
  EdgeDisplayList: array[0..9] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: 0),
    (Name: 'フェード'; Value: 1),
    (Name: 'ぼかし'; Value: 9),
    (Name: 'ワイプ'; Value: 10),
    (Name: '中央ワイプ'; Value: 24),
    (Name: 'ブラインド'; Value: 34),
    (Name: 'ブロックディゾルブ'; Value: 35),
    (Name: 'グリッチ'; Value: 36),
    (Name: '文字送り'; Value: 6),
    (Name: nil; Value: 0));
  DirectionList: array[0..5] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '標準'; Value: 0),
    (Name: '左'; Value: 1),
    (Name: '右'; Value: 2),
    (Name: '上'; Value: 3),
    (Name: '下'; Value: 4),
    (Name: nil; Value: 0));
  BeforeZoomList: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '奥から'; Value: 0),
    (Name: '手前から'; Value: 1),
    (Name: nil; Value: 0));
  SyncMotionList: array[0..12] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: 0),
    (Name: '拡大'; Value: SERIF_SYNC_MOTION_ZOOM),
    (Name: 'ジャンプ'; Value: SERIF_SYNC_MOTION_JUMP),
    (Name: '脈動'; Value: 2),
    (Name: '波'; Value: 3),
    (Name: '揺れ'; Value: 4),
    (Name: '跳躍'; Value: 9),
    (Name: 'ゼリー'; Value: 10),
    (Name: '鼓動'; Value: 11),
    (Name: '拡縮ウェーブ'; Value: 12),
    (Name: '震え'; Value: 13),
    (Name: '字間呼吸'; Value: 14),
    (Name: nil; Value: 0));
  SyncDisplayList: array[0..8] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: SERIF_SYNC_NONE),
    (Name: '色変え'; Value: SERIF_SYNC_COLOR),
    (Name: '前面'; Value: SERIF_SYNC_FRONT),
    (Name: '背面'; Value: SERIF_SYNC_BACKING),
    (Name: '下線'; Value: SERIF_SYNC_UNDERLINE),
    (Name: '発光'; Value: SERIF_SYNC_GLOW),
    (Name: '点滅'; Value: SERIF_SYNC_BLINK),
    (Name: 'グリッチ'; Value: SERIF_SYNC_GLITCH),
    (Name: nil; Value: 0));
  DuringTypeList: array[0..16] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: 0),
    (Name: '浮遊'; Value: 1),
    (Name: '脈動'; Value: 2),
    (Name: '波'; Value: 3),
    (Name: '揺れ'; Value: 4),
    (Name: '点滅'; Value: 5),
    (Name: '振り子'; Value: 6),
    (Name: '回転'; Value: 7),
    (Name: '漂流'; Value: 8),
    (Name: 'ジャンプ'; Value: 9),
    (Name: 'ゼリー'; Value: 10),
    (Name: '鼓動'; Value: 11),
    (Name: '拡縮ウェーブ'; Value: 12),
    (Name: '震え'; Value: 13),
    (Name: '字間呼吸'; Value: 14),
    (Name: 'グリッチ'; Value: 15),
    (Name: nil; Value: 0));
  SyncFillList: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '文字単位'; Value: SERIF_COLOR_FILL_CHARACTER),
    (Name: 'なめらか'; Value: SERIF_COLOR_FILL_SMOOTH),
    (Name: nil; Value: 0));
  SyncAfterList: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '戻す'; Value: SERIF_COLOR_AFTER_RESTORE),
    (Name: '維持'; Value: SERIF_COLOR_AFTER_KEEP),
    (Name: nil; Value: 0));
  SyncShapeList: array[0..4] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '自動'; Value: SERIF_SYNC_SHAPE_AUTO),
    (Name: '丸'; Value: SERIF_SYNC_SHAPE_CIRCLE),
    (Name: '四角'; Value: SERIF_SYNC_SHAPE_SQUARE),
    (Name: '三角'; Value: SERIF_SYNC_SHAPE_TRIANGLE),
    (Name: nil; Value: 0));
  AfterZoomList: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '奥へ'; Value: 0),
    (Name: '手前へ'; Value: 1),
    (Name: nil; Value: 0));

procedure InitializeSerifAnimationItems;
begin
  SerifBeforeMotionItem.ItemType := 'select';
  SerifBeforeMotionItem.Name := '前 動作';
  SerifBeforeMotionItem.Value := 0;
  SerifBeforeMotionItem.List := @EdgeMotionList[0];
  SerifBeforeDisplayItem.ItemType := 'select';
  SerifBeforeDisplayItem.Name := '前 表示';
  SerifBeforeDisplayItem.Value := 0;
  SerifBeforeDisplayItem.List := @EdgeDisplayList[0];
  SerifBeforeDirectionItem.ItemType := 'select';
  SerifBeforeDirectionItem.Name := '前 方向';
  SerifBeforeDirectionItem.Value := 0;
  SerifBeforeDirectionItem.List := @DirectionList[0];
  SerifBeforeZoomOriginItem.ItemType := 'select';
  SerifBeforeZoomOriginItem.Name := '前 奥行き';
  SerifBeforeZoomOriginItem.Value := 0;
  SerifBeforeZoomOriginItem.List := @BeforeZoomList[0];

  SerifSyncMotionItem.ItemType := 'select';
  SerifSyncMotionItem.Name := '同期 動作';
  SerifSyncMotionItem.Value := 0;
  SerifSyncMotionItem.List := @SyncMotionList[0];
  SerifSyncDisplayItem.ItemType := 'select';
  SerifSyncDisplayItem.Name := '同期 表示';
  SerifSyncDisplayItem.Value := SERIF_SYNC_COLOR;
  SerifSyncDisplayItem.List := @SyncDisplayList[0];
  SerifSyncFillItem.ItemType := 'select';
  SerifSyncFillItem.Name := '色塗り';
  SerifSyncFillItem.Value := SERIF_COLOR_FILL_SMOOTH;
  SerifSyncFillItem.List := @SyncFillList[0];
  SerifSyncAfterItem.ItemType := 'select';
  SerifSyncAfterItem.Name := '通過後';
  SerifSyncAfterItem.Value := SERIF_COLOR_AFTER_KEEP;
  SerifSyncAfterItem.List := @SyncAfterList[0];
  SerifSyncShapeItem.ItemType := 'select';
  SerifSyncShapeItem.Name := '同期 形';
  SerifSyncShapeItem.Value := SERIF_SYNC_SHAPE_AUTO;
  SerifSyncShapeItem.List := @SyncShapeList[0];

  SerifDuringTypeItem.ItemType := 'select';
  SerifDuringTypeItem.Name := '非同期 種類';
  SerifDuringTypeItem.Value := 0;
  SerifDuringTypeItem.List := @DuringTypeList[0];

  SerifAfterMotionItem.ItemType := 'select';
  SerifAfterMotionItem.Name := '後 動作';
  SerifAfterMotionItem.Value := 0;
  SerifAfterMotionItem.List := @EdgeMotionList[0];
  SerifAfterDisplayItem.ItemType := 'select';
  SerifAfterDisplayItem.Name := '後 表示';
  SerifAfterDisplayItem.Value := 0;
  SerifAfterDisplayItem.List := @EdgeDisplayList[0];
  SerifAfterDirectionItem.ItemType := 'select';
  SerifAfterDirectionItem.Name := '後 方向';
  SerifAfterDirectionItem.Value := 0;
  SerifAfterDirectionItem.List := @DirectionList[0];
  SerifAfterZoomDestinationItem.ItemType := 'select';
  SerifAfterZoomDestinationItem.Name := '後 奥行き';
  SerifAfterZoomDestinationItem.Value := 0;
  SerifAfterZoomDestinationItem.List := @AfterZoomList[0];
end;

end.
