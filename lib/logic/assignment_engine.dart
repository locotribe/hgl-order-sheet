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
      // 第1ゲームはHOME先攻(強い人寄せ=1)、AWAY後攻(弱い人寄せ=-1)。以降は0(中立)
      final leanSign = def.number == 1
          ? (homeAway == HomeAway.home ? 1 : -1)
          : 0;

      final capField = switch (def.format) {
        GameFormat.singles => singlesCount,
        GameFormat.doubles => doublesCount,
        GameFormat.trios => triosCount,
      };

      // 各フォーマットの出場上限に達していないメンバーを抽出
      final eligible = entrants
          .where((e) => capField[e.id]! < def.perPlayerCap)
          .toList();

      final scored = {for (final e in eligible) e.id: score(e, def, leanSign)};

      List<String> chosen;

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
}