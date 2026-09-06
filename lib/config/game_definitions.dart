// SPEC.md §3 の全11ゲーム構成の定数定義。

/// ゲームの人数フォーマット。
enum GameFormat {
  singles(1),
  doubles(2),
  trios(3);

  const GameFormat(this.playerCount);
  final int playerCount;
}

/// ハンデの有無。
enum HandicapType { none, auto }

/// 強さを測る軸（01系 or クリケット系）。
enum StrengthAxis { zeroOne, cricket }

class GameDefinition {
  const GameDefinition({
    required this.number,
    required this.name,
    required this.format,
    required this.handicap,
    required this.strengthAxis,
  });

  /// 1-indexed のゲーム番号（①〜⑪）。
  final int number;
  final String name;
  final GameFormat format;
  final HandicapType handicap;
  final StrengthAxis strengthAxis;

  /// この形式の1人あたり出場上限回数（SPEC §3）。
  int get perPlayerCap {
    switch (format) {
      case GameFormat.singles:
        return 1;
      case GameFormat.doubles:
        return 4;
      case GameFormat.trios:
        return 3;
    }
  }
}

/// SPEC §3 の表そのまま（①〜⑪）。
const List<GameDefinition> kGameDefinitions = [
  GameDefinition(
    number: 1,
    name: '901',
    format: GameFormat.trios,
    handicap: HandicapType.auto,
    strengthAxis: StrengthAxis.zeroOne,
  ),
  GameDefinition(
    number: 2,
    name: '701',
    format: GameFormat.doubles,
    handicap: HandicapType.auto,
    strengthAxis: StrengthAxis.zeroOne,
  ),
  GameDefinition(
    number: 3,
    name: 'SHOOT OUT',
    format: GameFormat.doubles,
    handicap: HandicapType.none,
    strengthAxis: StrengthAxis.zeroOne,
  ),
  GameDefinition(
    number: 4,
    name: '701',
    format: GameFormat.doubles,
    handicap: HandicapType.auto,
    strengthAxis: StrengthAxis.zeroOne,
  ),
  GameDefinition(
    number: 5,
    name: 'S.CRICKET',
    format: GameFormat.singles,
    handicap: HandicapType.auto,
    strengthAxis: StrengthAxis.cricket,
  ),
  GameDefinition(
    number: 6,
    name: 'HALF-IT',
    format: GameFormat.doubles,
    handicap: HandicapType.none,
    strengthAxis: StrengthAxis.cricket,
  ),
  GameDefinition(
    number: 7,
    name: 'S.CRICKET',
    format: GameFormat.trios,
    handicap: HandicapType.auto,
    strengthAxis: StrengthAxis.cricket,
  ),
  GameDefinition(
    number: 8,
    name: '701',
    format: GameFormat.singles,
    handicap: HandicapType.auto,
    strengthAxis: StrengthAxis.zeroOne,
  ),
  GameDefinition(
    number: 9,
    name: 'S.CRICKET',
    format: GameFormat.doubles,
    handicap: HandicapType.auto,
    strengthAxis: StrengthAxis.cricket,
  ),
  GameDefinition(
    number: 10,
    name: '701',
    format: GameFormat.doubles,
    handicap: HandicapType.auto,
    strengthAxis: StrengthAxis.zeroOne,
  ),
  GameDefinition(
    number: 11,
    name: '901',
    format: GameFormat.trios,
    handicap: HandicapType.auto,
    strengthAxis: StrengthAxis.zeroOne,
  ),
];

/// 同じペアでのダブルス出場上限（SPEC §3）。
const int kMaxSamePairDoubles = 2;
