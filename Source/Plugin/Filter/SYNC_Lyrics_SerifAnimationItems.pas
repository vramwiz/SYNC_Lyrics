unit SYNC_Lyrics_SerifAnimationItems;

// 参照元セリフ表示と同じ固定スキーマのアニメーション項目を提供する。
// 固定スキーマを保ったまま、同期種類をSYNC_Lyricsの描画設定へ渡す。

interface

uses
  AviUtl2FilterTypes;

const
  SERIF_SYNC_NONE = 0;
  SERIF_SYNC_COLOR = 1;
  SERIF_SYNC_FRONT = 2;
  SERIF_SYNC_BACKING = 3;
  SERIF_SYNC_UNDERLINE = 4;
  SERIF_SYNC_ZOOM = 5;
  SERIF_SYNC_GLOW = 6;
  SERIF_SYNC_JUMP = 7;
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
  SerifBeforeTypeItem: TFILTER_ITEM_SELECT;
  SerifBeforeDirectionItem: TFILTER_ITEM_SELECT;
  SerifBeforeZoomOriginItem: TFILTER_ITEM_SELECT;
  SerifBeforeValue1Item: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '前 値1'; Value: 0; S: -1000; E: 1000;
    Step: 0.01);

  SerifDuringGroup: TFILTER_ITEM_GROUP = (
    ItemType: 'group'; Name: '常時'; DefaultVisible: 1);
  SerifDuringEmotionItem: TFILTER_ITEM_CHECK = (
    ItemType: 'check'; Name: '常時 感情表現'; Value: 0);
  SerifDuringSpeedItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '常時 速さ'; Value: 1; S: 0; E: 100;
    Step: 0.01);

  SerifSyncGroup: TFILTER_ITEM_GROUP = (
    ItemType: 'group'; Name: '同期'; DefaultVisible: 1);
  SerifSyncTypeItem: TFILTER_ITEM_SELECT;
  SerifSyncFillItem: TFILTER_ITEM_SELECT;
  SerifSyncAfterItem: TFILTER_ITEM_SELECT;
  SerifSyncShapeItem: TFILTER_ITEM_SELECT;
  SerifSyncColorItem: TFILTER_ITEM_COLOR = (
    ItemType: 'color'; Name: '同期 色'; B: 0; G: 255; R: 255; X: 255);
  SerifSyncSizeItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '同期 サイズ'; Value: 100; S: 1; E: 1000;
    Step: 0.01);
  SerifSyncOffsetXItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '同期 オフセットX'; Value: 0; S: -100; E: 100;
    Step: 1);
  SerifSyncOffsetYItem: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '同期 オフセットY'; Value: 0; S: -100; E: 100;
    Step: 1);

  SerifAfterGroup: TFILTER_ITEM_GROUP = (
    ItemType: 'group'; Name: '表示後'; DefaultVisible: 1);
  SerifAfterTypeItem: TFILTER_ITEM_SELECT;
  SerifAfterDirectionItem: TFILTER_ITEM_SELECT;
  SerifAfterZoomDestinationItem: TFILTER_ITEM_SELECT;
  SerifAfterValue1Item: TFILTER_ITEM_TRACK = (
    ItemType: 'track'; Name: '後 値1'; Value: 0; S: -1000; E: 1000;
    Step: 0.01);

procedure InitializeSerifAnimationItems;

implementation

var
  BeforeTypeList: array[0..9] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: 0),
    (Name: 'フェードイン'; Value: 1),
    (Name: 'スライドイン'; Value: 2),
    (Name: 'ズームイン'; Value: 3),
    (Name: 'ポップイン'; Value: 4),
    (Name: 'ワイプイン'; Value: 5),
    (Name: 'ブラーイン'; Value: 6),
    (Name: '回転イン'; Value: 10),
    (Name: 'バウンドイン'; Value: 11),
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
  SyncTypeList: array[0..8] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: SERIF_SYNC_NONE),
    (Name: '色変え'; Value: SERIF_SYNC_COLOR),
    (Name: '前面'; Value: SERIF_SYNC_FRONT),
    (Name: '背面'; Value: SERIF_SYNC_BACKING),
    (Name: '下線'; Value: SERIF_SYNC_UNDERLINE),
    (Name: '拡大'; Value: SERIF_SYNC_ZOOM),
    (Name: '発光'; Value: SERIF_SYNC_GLOW),
    (Name: 'ジャンプ'; Value: SERIF_SYNC_JUMP),
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
  AfterTypeList: array[0..7] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: 'なし'; Value: 0),
    (Name: 'フェードアウト'; Value: 1),
    (Name: 'スライドアウト'; Value: 2),
    (Name: 'ズームアウト'; Value: 3),
    (Name: 'ワイプアウト'; Value: 4),
    (Name: 'ブラーアウト'; Value: 5),
    (Name: '回転アウト'; Value: 6),
    (Name: nil; Value: 0));
  AfterZoomList: array[0..2] of TFILTER_ITEM_SELECT_ITEM = (
    (Name: '奥へ'; Value: 0),
    (Name: '手前へ'; Value: 1),
    (Name: nil; Value: 0));

procedure InitializeSerifAnimationItems;
begin
  SerifBeforeTypeItem.ItemType := 'select';
  SerifBeforeTypeItem.Name := '前 種類';
  SerifBeforeTypeItem.Value := 0;
  SerifBeforeTypeItem.List := @BeforeTypeList[0];
  SerifBeforeDirectionItem.ItemType := 'select';
  SerifBeforeDirectionItem.Name := '前 方向';
  SerifBeforeDirectionItem.Value := 0;
  SerifBeforeDirectionItem.List := @DirectionList[0];
  SerifBeforeZoomOriginItem.ItemType := 'select';
  SerifBeforeZoomOriginItem.Name := '前 奥行き';
  SerifBeforeZoomOriginItem.Value := 0;
  SerifBeforeZoomOriginItem.List := @BeforeZoomList[0];

  SerifSyncTypeItem.ItemType := 'select';
  SerifSyncTypeItem.Name := '同期 種類';
  SerifSyncTypeItem.Value := SERIF_SYNC_COLOR;
  SerifSyncTypeItem.List := @SyncTypeList[0];
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

  SerifAfterTypeItem.ItemType := 'select';
  SerifAfterTypeItem.Name := '後 種類';
  SerifAfterTypeItem.Value := 0;
  SerifAfterTypeItem.List := @AfterTypeList[0];
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
