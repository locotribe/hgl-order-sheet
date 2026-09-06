import '../config/game_definitions.dart';
import '../models/game_slot.dart';

/// 現在の11ゲーム割り当てから、出場回数・ペア使用回数を再計算するヘルパー。
/// リザルトシートの入れ替えUIでR1制約（出場上限）チェックに使う。
class RosterCounts {
  final Map<String, int> singles = {};
  final Map<String, int> doubles = {};
  final Map<String, int> trios = {};

  /// key: ソート済み "id1|id2"
  final Map<String, int> pairs = {};

  int countFor(GameFormat format, String id) {
    switch (format) {
      case GameFormat.singles:
        return singles[id] ?? 0;
      case GameFormat.doubles:
        return doubles[id] ?? 0;
      case GameFormat.trios:
        return trios[id] ?? 0;
    }
  }

  static String pairKey(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}|${sorted[1]}';
  }

  static RosterCounts compute(List<GameSlot> games, {int? excludeGameNumber}) {
    final counts = RosterCounts();
    for (final g in games) {
      if (g.number == excludeGameNumber) continue;
      final def = kGameDefinitions.firstWhere((d) => d.number == g.number);
      for (final id in g.assigned) {
        switch (def.format) {
          case GameFormat.singles:
            counts.singles[id] = (counts.singles[id] ?? 0) + 1;
          case GameFormat.doubles:
            counts.doubles[id] = (counts.doubles[id] ?? 0) + 1;
          case GameFormat.trios:
            counts.trios[id] = (counts.trios[id] ?? 0) + 1;
        }
      }
      if (def.format == GameFormat.doubles && g.assigned.length == 2) {
        final key = pairKey(g.assigned[0], g.assigned[1]);
        counts.pairs[key] = (counts.pairs[key] ?? 0) + 1;
      }
    }
    return counts;
  }
}

String formatLabel(GameFormat format) {
  switch (format) {
    case GameFormat.singles:
      return 'シングルス';
    case GameFormat.doubles:
      return 'ダブルス';
    case GameFormat.trios:
      return 'トリオス';
  }
}

String formatShortLetter(GameFormat format) {
  switch (format) {
    case GameFormat.singles:
      return 'S';
    case GameFormat.doubles:
      return 'D';
    case GameFormat.trios:
      return 'T';
  }
}
