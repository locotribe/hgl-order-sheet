// [修正] 全週のゲームデータからプレイヤーの出場回数を集計するロジック (v1.9.7)
// - type / format / result の組み合わせで集計
import 'package:cloud_firestore/cloud_firestore.dart';

class GameTypeStats {
  final String type;
  final String format;
  int total = 0;
  int wins = 0;
  int losses = 0;

  GameTypeStats({required this.type, required this.format});
}

class HistoricalStatsCalculator {
  /// Firestore の collectionGroup を使用して、対象プレイヤーがアサインされている全ゲームを取得し、
  /// type × format の組み合わせごとの出場回数と勝敗を集計する。
  Future<List<GameTypeStats>> getPlayerGameTypeStats(String playerId) async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('games')
        .where('assigned', arrayContains: playerId)
        .get();

    // (type, format) の組み合わせで集計
    final stats = <String, GameTypeStats>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final type = data['type'] as String?;
      final format = data['format'] as String?;
      final result = data['result'] as String?;

      if (type == null || format == null) continue;

      final key = '$type|$format';
      stats[key] ??= GameTypeStats(type: type, format: format);
      stats[key]!.total++;
      if (result == 'win') stats[key]!.wins++;
      if (result == 'loss') stats[key]!.losses++;
    }

    // 出場回数順（降順）にソート
    final list = stats.values.toList()..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// formatの文字列を日本語の表示名に変換するヘルパーメソッド
  static String formatLabel(String format) {
    switch (format) {
      case 'singles':
        return 'シングルス';
      case 'doubles':
        return 'ダブルス';
      case 'trios':
        return 'トリオス';
      case 'gallon':
        return 'ガロン';
      default:
        return format;
    }
  }
}
