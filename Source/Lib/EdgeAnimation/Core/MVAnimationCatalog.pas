unit MVAnimationCatalog;

// 演出の固定ID・名前・評価関数を一元化する読取専用カタログ。
// 演出追加は専用ユニットの関数とこの一覧へ登録し、保存IDを再利用しない。
interface

uses MVAnimationTypes;

// 終端項目を除いた登録数。ホストの選択肢数もこの値から構築する。
function MVAnimationCount(Kind: TMVAnimationKind): Integer;
// 表示順のIndexから登録情報を返す。保存IDとIndexを同じ値と仮定しない。
function MVAnimationAt(Kind: TMVAnimationKind; Index: Integer): TMVAnimationDescriptor;
// 保存IDから検索する。未登録ならFalse、出力は既定値にする。
function FindMVAnimation(Kind: TMVAnimationKind; ID: Integer; out Item: TMVAnimationDescriptor): Boolean;
// 登録IDの妥当性を検証する。文書とホストの選択肢で同じ一覧を使う。
function IsMVAnimationID(Kind: TMVAnimationKind; ID: Integer): Boolean;

implementation

uses System.SysUtils, MVTransitionBasic, MVTransitionExtended, MVHoldBasic, MVHoldExtended,
  MVTransitionMovement, MVTransitionScale, MVTransitionMasks, MVTransitionScatter,
  MVTransitionKinetic, MVTransitionPattern, MVTransitionPath, MVHoldKinetic, MVHoldAccent;

const
  Transitions: array[0..29] of TMVAnimationDescriptor = (
    (ID: 0; Name: 'なし'; Evaluate: nil),
    (ID: 1; Name: 'フェード'; Evaluate: MVFade),
    (ID: 2; Name: 'スライド'; Evaluate: MVSlide),
    (ID: 3; Name: 'ズーム'; Evaluate: MVZoom),
    (ID: 4; Name: 'ポップ'; Evaluate: MVPop),
    (ID: 5; Name: '回転'; Evaluate: MVTurn),
    (ID: 6; Name: '文字送り'; Evaluate: MVTypeOn),
    (ID: 7; Name: 'バウンス'; Evaluate: MVBounce),
    (ID: 8; Name: 'フリップ'; Evaluate: MVFlip),
    (ID: 9; Name: 'ぼかし'; Evaluate: MVBlur),
    (ID: 10; Name: 'ワイプ'; Evaluate: MVWipe),
    (ID: 15; Name: '拡大ズーム'; Evaluate: MVLargeZoom),
    (ID: 16; Name: '弾性ズーム'; Evaluate: MVElasticZoom),
    (ID: 17; Name: '回転ズーム'; Evaluate: MVRotatingZoom),
    (ID: 18; Name: 'ストレッチ'; Evaluate: MVStretch),
    (ID: 24; Name: '中央ワイプ'; Evaluate: MVWipeCenter),
    (ID: 26; Name: '集合・飛散'; Evaluate: MVScatter),
    (ID: 27; Name: '交互スライド'; Evaluate: MVAlternatingSlide),
    (ID: 28; Name: 'ぼかしスライド'; Evaluate: MVBlurSlide),
    (ID: 29; Name: '弾性スライド'; Evaluate: MVSpringSlide),
    (ID: 30; Name: 'スウィング'; Evaluate: MVSwing),
    (ID: 31; Name: '螺旋'; Evaluate: MVSpiral),
    (ID: 32; Name: '字間展開'; Evaluate: MVTrackingSpread),
    (ID: 33; Name: 'スクイーズ'; Evaluate: MVSqueeze),
    (ID: 34; Name: 'ブラインド'; Evaluate: MVBlinds),
    (ID: 35; Name: 'ブロックディゾルブ'; Evaluate: MVBlockDissolve),
    (ID: 36; Name: 'グリッチ'; Evaluate: MVGlitchTransition),
    (ID: 37; Name: '波に沿う'; Evaluate: MVWavePath),
    (ID: 38; Name: 'S字で流れ込む'; Evaluate: MVSCurvePath),
    (ID: 39; Name: 'ジグザグで入る'; Evaluate: MVZigzagPath)
  );
  // 旧文書の読込・評価だけに使い、ホストの選択肢へは公開しない。
  LegacyDirections: array[0..9] of TMVAnimationDescriptor = (
    (ID: 11; Name: 'スライド'; Evaluate: MVSlideLeft),
    (ID: 12; Name: 'スライド'; Evaluate: MVSlideRight),
    (ID: 13; Name: 'スライド'; Evaluate: MVSlideUp),
    (ID: 14; Name: 'スライド'; Evaluate: MVSlideDown),
    (ID: 19; Name: 'ストレッチ'; Evaluate: MVStretchVertical),
    (ID: 20; Name: 'フリップ'; Evaluate: MVFlipVertical),
    (ID: 21; Name: 'ワイプ'; Evaluate: MVWipeRightToLeft),
    (ID: 22; Name: 'ワイプ'; Evaluate: MVWipeTopToBottom),
    (ID: 23; Name: 'ワイプ'; Evaluate: MVWipeBottomToTop),
    (ID: 25; Name: '中央ワイプ'; Evaluate: MVWipeCenterVertical)
  );
  Holds: array[0..15] of TMVAnimationDescriptor = (
    (ID: 0; Name: '静止'; Evaluate: nil),
    (ID: 1; Name: '浮遊'; Evaluate: MVFloat),
    (ID: 2; Name: '脈動'; Evaluate: MVPulse),
    (ID: 3; Name: '波'; Evaluate: MVWave),
    (ID: 4; Name: '揺れ'; Evaluate: MVWobble),
    (ID: 5; Name: '点滅'; Evaluate: MVBlink),
    (ID: 6; Name: '振り子'; Evaluate: MVPendulum),
    (ID: 7; Name: '回転'; Evaluate: MVSpin),
    (ID: 8; Name: '漂流'; Evaluate: MVDrift),
    (ID: 9; Name: 'ジャンプ'; Evaluate: MVHop),
    (ID: 10; Name: 'ゼリー'; Evaluate: MVJelly),
    (ID: 11; Name: '鼓動'; Evaluate: MVHeartbeat),
    (ID: 12; Name: '拡縮ウェーブ'; Evaluate: MVScaleWave),
    (ID: 13; Name: '震え'; Evaluate: MVJitter),
    (ID: 14; Name: '字間呼吸'; Evaluate: MVTrackingBreath),
    (ID: 15; Name: 'グリッチ'; Evaluate: MVGlitchHold)
  );

function MVAnimationCount(Kind: TMVAnimationKind): Integer;
begin
  if Kind = makTransition then Result := Length(Transitions) else Result := Length(Holds);
end;

function MVAnimationAt(Kind: TMVAnimationKind; Index: Integer): TMVAnimationDescriptor;
begin
  if (Index < 0) or (Index >= MVAnimationCount(Kind)) then
    raise EArgumentOutOfRangeException.Create('演出一覧の位置が範囲外です。');
  if Kind = makTransition then Result := Transitions[Index] else Result := Holds[Index];
end;

function FindMVAnimation(Kind: TMVAnimationKind; ID: Integer; out Item: TMVAnimationDescriptor): Boolean;
var I: Integer;
begin
  for I := 0 to MVAnimationCount(Kind) - 1 do
  begin
    Item := MVAnimationAt(Kind, I);
    if Item.ID = ID then Exit(True);
  end;
  if Kind = makTransition then
    for I := 0 to High(LegacyDirections) do
      if LegacyDirections[I].ID = ID then
      begin
        Item := LegacyDirections[I];
        Exit(True);
      end;
  Item := Default(TMVAnimationDescriptor);
  Result := False;
end;

function IsMVAnimationID(Kind: TMVAnimationKind; ID: Integer): Boolean;
var Item: TMVAnimationDescriptor;
begin
  Result := FindMVAnimation(Kind, ID, Item);
end;

end.
