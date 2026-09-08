// [追加] A-1 リザルトシート自動生成のコア実装 (v.1.0)
import 'dart:math';
import '../config/game_definitions.dart';
import '../models/game_slot.dart';
import '../models/week.dart';

class AssignmentEntrant {
  const AssignmentEntrant({
    required this.id,
    required this.name,
    required this.stats01,
    required this.statsCricket,
  });

  final String id;
  final String name;
  final double stats01;
  final double statsCricket;
}

class GameAssignment {
  const GameAssignment({
    required this.gameNumber,
    required this.assignedIds,
    required this.firstThrow,
  });

  final int gameNumber;
  final List<String> assignedIds;
  final FirstThrow firstThrow;
}

class AssignmentResult {
  const AssignmentResult({required this.assignments, required this.feasible});

  final List<GameAssignment> assignments;
  final bool feasible;
}

class AssignmentException implements Exception {
  AssignmentException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AssignmentEngine {
  static const double _balanceWeight = 1000.0;
  static const double _pairRepeatWeight = 500.0;
  static const double _strengthWeight = 1.0;
  static const int _maxAttempts = 500;

  AssignmentResult generate({
    required List<AssignmentEntrant> entrants,
    required HomeAway homeAway,
    int? randomSeed,
  }) {
    if (entrants.length < 3) {
      throw AssignmentException('最低3名の参加者が必要です。現在の人数: ${entrants.length}名');
    }

    final random = Random(randomSeed);

    // 規定を完全に満たす編成を探索（ランダム性で複数回トライ）
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final result = _tryGenerate(entrants, homeAway, random);
      if (result != null) {
        return AssignmentResult(assignments: result, feasible: true);
      }
    }

    // 規定を完全に満たす解が見つからない場合は、ベストエフォート（ソフトルール違反許容）で生成
    final bestEffort = _tryGenerate(
      entrants,
      homeAway,
      random,
      bestEffort: true,
    )!;

    return AssignmentResult(assignments: bestEffort, feasible: false);
  }

  String _pairKey(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}|${sorted[1]}';
  }

  List<GameAssignment>? _tryGenerate(
      List<AssignmentEntrant> entrants,
      HomeAway homeAway,
      Random random, {
        bool bestEffort = false,
      }) {
    final singlesCount = <String, int>{for (final e in entrants) e.id: 0};
    final doublesCount = <String, int>{for (final e in entrants) e.id: 0};
    final triosCount = <String, int>{for (final e in entrants) e.id: 0};
    final totalGames = <String, int>{for (final e in entrants) e.id: 0};
    final pairCount = <String, int>{};

    double score(AssignmentEntrant e, GameDefinition def, int leanSign) {
      final base = -(totalGames[e.id]! * _balanceWeight);
      final axisStat = def.strengthAxis == StrengthAxis.zeroOne
          ? e.stats01
          : e.statsCricket;

      // 同点時のランダム揺らぎ
      final jitter = random.nextDouble() * 0.01;

      // ハンデなし、またはクリケットの場合は常に強さ優先（ポジティブ加点）
      if (def.handicap == HandicapType.none ||
          def.strengthAxis == StrengthAxis.cricket) {
        return base + (axisStat * _strengthWeight) + jitter;
      }

      // 01系オートハンデの場合、leanSign によって強弱の狙いを変える
      return base + (axisStat * _strengthWeight * leanSign) + jitter;
    }

    final assignments = <GameAssignment>[];

    for (final def in kGameDefinitions) {
      final capField = switch (def.format) {
        GameFormat.singles => singlesCount,
        GameFormat.doubles => doublesCount,
        GameFormat.trios => triosCount,
      };

      // 各フォーマットの出場上限に達していないメンバーを抽出
      final eligible = entrants
          .where((e) => capField[e.id]! < def.perPlayerCap)
          .toList();

      List<String> chosen;

      if (def.number == 1) {
        // 第1ゲーム専用の選出（HOME: 低3人 / AWAY: 低2人 + 中央値1人）
        chosen = _pickGame1(
          entrants: eligible,
          homeAway: homeAway,
        );
      } else {
        const leanSign = 0; // 第2ゲーム以降は中立
        final scored = {for (final e in eligible) e.id: score(e, def, leanSign)};

        if (def.format == GameFormat.doubles) {
          chosen = _pickPair(
            eligible: eligible,
            scored: scored,
            pairCount: pairCount,
            bestEffort: bestEffort,
          ) ?? [];
          if (chosen.length < 2 && !bestEffort) return null;
        } else {
          final needed = def.format.playerCount;
          if (eligible.length < needed && !bestEffort) return null;

          final sortedIds = [...eligible.map((e) => e.id)]
            ..sort((a, b) => scored[b]!.compareTo(scored[a]!));

          chosen = sortedIds.take(needed).toList();
        }
      }

      // カウントの更新
      for (final id in chosen) {
        totalGames[id] = totalGames[id]! + 1;
        capField[id] = capField[id]! + 1;
      }

      assignments.add(
        GameAssignment(
          gameNumber: def.number,
          assignedIds: chosen,
          firstThrow: def.number == 1
              ? (homeAway == HomeAway.home
              ? FirstThrow.first
              : FirstThrow.second)
              : FirstThrow.undecided,
        ),
      );
    }

    return assignments;
  }

  List<String>? _pickPair({
    required List<AssignmentEntrant> eligible,
    required Map<String, double> scored,
    required Map<String, int> pairCount,
    required bool bestEffort,
  }) {
    if (eligible.length < 2) {
      return bestEffort ? eligible.map((e) => e.id).toList() : null;
    }

    double? bestScore;
    List<AssignmentEntrant>? bestPair;

    for (var i = 0; i < eligible.length; i++) {
      for (var j = i + 1; j < eligible.length; j++) {
        final a = eligible[i];
        final b = eligible[j];

        final used = pairCount[_pairKey(a.id, b.id)] ?? 0;

        // ペア上限違反の回避（ベストエフォート時以外）
        if (used >= kMaxSamePairDoubles && !bestEffort) continue;

        final pairScore =
            scored[a.id]! + scored[b.id]! - (used * _pairRepeatWeight);

        if (bestScore == null || pairScore > bestScore) {
          bestScore = pairScore;
          bestPair = [a, b];
        }
      }
    }

    if (bestPair == null) {
      if (!bestEffort) return null;
      // 強制選出
      final sortedEligible = [...eligible]
        ..sort((x, y) => scored[y.id]!.compareTo(scored[x.id]!));
      return sortedEligible.take(2).map((e) => e.id).toList();
    }

    final key = _pairKey(bestPair[0].id, bestPair[1].id);
    pairCount[key] = (pairCount[key] ?? 0) + 1;

    return bestPair.map((e) => e.id).toList();
  }

  /// 第1ゲーム (901 トリオス オートハンデ) 専用の選出ロジック
  List<String> _pickGame1({
    required List<AssignmentEntrant> entrants,
    required HomeAway homeAway,
  }) {
    if (entrants.length <= 3) {
      return entrants.map((e) => e.id).toList();
    }

    // stats01 が低い順（昇順）にソート
    final sortedByStats = [...entrants]
      ..sort((a, b) => a.stats01.compareTo(b.stats01));

    if (homeAway == HomeAway.home) {
      // HOME (先攻): ハンデ最大化 -> stats01 が最も低い3人を選出
      return sortedByStats.take(3).map((e) => e.id).toList();
    } else {
      // AWAY (後攻): 相手ハンデ抑制 + 決定力保持
      // ① 最も stats01 が低い2人を抽出
      final low1 = sortedByStats[0];
      final low2 = sortedByStats[1];

      // ② 残りの候補者（3人目以降）
      final remaining = sortedByStats.sublist(2);

      // ③ チーム全体の stats01 中央値 (Median) を算出
      final statsList = entrants.map((e) => e.stats01).toList()..sort();
      final double median = _calculateMedian(statsList);

      // ④ 残りメンバーの中から |stats01 - median| (中央値との差) が最も小さい選手を選出
      remaining.sort((a, b) {
        final diffA = (a.stats01 - median).abs();
        final diffB = (b.stats01 - median).abs();
        return diffA.compareTo(diffB);
      });

      final mid1 = remaining[0];

      return [low1.id, low2.id, mid1.id];
    }
  }

  /// 中央値（Median）を計算するヘルパー関数
  double _calculateMedian(List<double> sortedList) {
    final count = sortedList.length;
    if (count % 2 == 1) {
      return sortedList[count ~/ 2];
    } else {
      return (sortedList[(count ~/ 2) - 1] + sortedList[count ~/ 2]) / 2.0;
    }
  }
}