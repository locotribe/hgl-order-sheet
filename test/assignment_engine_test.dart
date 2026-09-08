// [修正] アルゴリズム動作検証テスト (v.1.1)
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:hgl_order_sheet/config/game_definitions.dart';
import 'package:hgl_order_sheet/logic/assignment_engine.dart';
import 'package:hgl_order_sheet/models/game_slot.dart';
import 'package:hgl_order_sheet/models/week.dart';

List<AssignmentEntrant> _randomEntrants(Random random, int n) {
  return List.generate(
    n,
        (i) => AssignmentEntrant(
      id: 'p$i',
      name: 'Player $i',
      stats01: 20 + random.nextDouble() * 60,
      statsCricket: 1 + random.nextDouble() * 4,
    ),
  );
}

void _assertNoRuleViolations(
    List<AssignmentEntrant> entrants,
    AssignmentResult result,
    ) {
  final singlesCount = <String, int>{};
  final doublesCount = <String, int>{};
  final triosCount = <String, int>{};
  final pairCount = <String, int>{};

  for (final a in result.assignments) {
    final def = kGameDefinitions.firstWhere((d) => d.number == a.gameNumber);

    expect(
      a.assignedIds.toSet().length,
      a.assignedIds.length,
      reason: 'ゲーム${a.gameNumber}: 同じ人が重複割当されている',
    );

    if (result.feasible) {
      expect(
        a.assignedIds.length,
        def.format.playerCount,
        reason: 'ゲーム${a.gameNumber}: 割当人数が形式と一致しない',
      );
    }

    for (final id in a.assignedIds) {
      switch (def.format) {
        case GameFormat.singles:
          singlesCount[id] = (singlesCount[id] ?? 0) + 1;
        case GameFormat.doubles:
          doublesCount[id] = (doublesCount[id] ?? 0) + 1;
        case GameFormat.trios:
          triosCount[id] = (triosCount[id] ?? 0) + 1;
      }
    }

    if (def.format == GameFormat.doubles && a.assignedIds.length == 2) {
      final sorted = [...a.assignedIds]..sort();
      final key = '${sorted[0]}|${sorted[1]}';
      pairCount[key] = (pairCount[key] ?? 0) + 1;
    }
  }

  singlesCount.forEach((id, count) {
    expect(count, lessThanOrEqualTo(1), reason: '$id: シングルス上限(1)違反');
  });
  doublesCount.forEach((id, count) {
    expect(count, lessThanOrEqualTo(4), reason: '$id: ダブルス上限(4)違反');
  });
  triosCount.forEach((id, count) {
    expect(count, lessThanOrEqualTo(3), reason: '$id: トリオス上限(3)違反');
  });
  pairCount.forEach((key, count) {
    expect(count, lessThanOrEqualTo(kMaxSamePairDoubles), reason: 'ペア$key: 同ペア上限違反');
  });
}

void main() {
  final engine = AssignmentEngine();

  test('3人ケースはSPEC通りの解（各ペア2回・全トリオスに3人参加）になる', () {
    final entrants = _randomEntrants(Random(1), 3);
    final result = engine.generate(
      entrants: entrants,
      homeAway: HomeAway.home,
      randomSeed: 1,
    );

    expect(result.feasible, isTrue);
    _assertNoRuleViolations(entrants, result);

    final pairCount = <String, int>{};
    for (final a in result.assignments) {
      final def = kGameDefinitions.firstWhere((d) => d.number == a.gameNumber);
      if (def.format == GameFormat.trios) {
        expect(a.assignedIds.toSet(), entrants.map((e) => e.id).toSet());
      }
      if (def.format == GameFormat.doubles) {
        final sorted = [...a.assignedIds]..sort();
        final key = '${sorted[0]}|${sorted[1]}';
        pairCount[key] = (pairCount[key] ?? 0) + 1;
      }
    }
    expect(pairCount.length, 3, reason: '3人なら3ペア全てが使われるはず');
    for (final count in pairCount.values) {
      expect(count, 2, reason: '3人ケースは各ペアちょうど2回になるはず');
    }
  });

  test('第1ゲームの先攻後攻はHOME/AWAYと一致する', () {
    final entrants = _randomEntrants(Random(2), 5);

    final homeResult = engine.generate(
      entrants: entrants,
      homeAway: HomeAway.home,
      randomSeed: 2,
    );
    expect(homeResult.assignments.first.firstThrow, FirstThrow.first);

    final awayResult = engine.generate(
      entrants: entrants,
      homeAway: HomeAway.away,
      randomSeed: 2,
    );
    expect(awayResult.assignments.first.firstThrow, FirstThrow.second);

    for (final a in homeResult.assignments.skip(1)) {
      expect(a.firstThrow, FirstThrow.undecided);
    }
  });

  test('3人未満はエラーになる', () {
    final entrants = _randomEntrants(Random(3), 2);
    expect(
          () => engine.generate(entrants: entrants, homeAway: HomeAway.home),
      throwsA(isA<AssignmentException>()),
    );
  });

  test('3〜10人 x 先攻/後攻 のランダムケースで規定違反ゼロ', () {
    final random = Random(42);
    for (var trial = 0; trial < 2000; trial++) {
      final n = 3 + random.nextInt(8); // 3..10
      final entrants = _randomEntrants(random, n);
      final homeAway = random.nextBool() ? HomeAway.home : HomeAway.away;
      final result = engine.generate(
        entrants: entrants,
        homeAway: homeAway,
        randomSeed: trial,
      );
      expect(
        result.feasible,
        isTrue,
        reason: 'trial=$trial n=$n で編成が成立しなかった',
      );
      _assertNoRuleViolations(entrants, result);
    }
  });

  test('第1ゲーム(Trios 01)の選出ルール検証 (HOME: 低3人, AWAY: 低2人+中央値1人)', () {
    final entrants = [
      const AssignmentEntrant(id: 'p1', name: 'P1', stats01: 10.0, statsCricket: 1.0), // 低1
      const AssignmentEntrant(id: 'p2', name: 'P2', stats01: 15.0, statsCricket: 2.0), // 低2
      const AssignmentEntrant(id: 'p3', name: 'P3', stats01: 30.0, statsCricket: 3.0), // 中央値 (30.0)
      const AssignmentEntrant(id: 'p4', name: 'P4', stats01: 45.0, statsCricket: 4.0),
      const AssignmentEntrant(id: 'p5', name: 'P5', stats01: 50.0, statsCricket: 5.0),
    ];

    // HOME (先攻): stats01 が最も低い3人 (p1, p2, p3)
    final homeResult = engine.generate(
      entrants: entrants,
      homeAway: HomeAway.home,
    );
    final homeAssigned = homeResult.assignments.first.assignedIds;
    expect(homeAssigned.toSet(), equals({'p1', 'p2', 'p3'}));

    // AWAY (後攻): 低い2人 (p1, p2) + 中央値30.0に一番近い1人 (p3)
    final awayResult = engine.generate(
      entrants: entrants,
      homeAway: HomeAway.away,
    );
    final awayAssigned = awayResult.assignments.first.assignedIds;
    expect(awayAssigned.toSet(), equals({'p1', 'p2', 'p3'}));
  });
}