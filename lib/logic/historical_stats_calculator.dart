// [追加] 全週のゲームデータからプレイヤーの出場回数を集計するロジック (v1.9.6)
import 'package:cloud_firestore/cloud_firestore.dart';

class HistoricalStatsCalculator {
  /// Firestore の collectionGroup を使用して、対象プレイヤーがアサインされている全ゲームを取得し、
  /// ゲーム形式（format）ごとの累計出場回数を集計する。
  Future<Map<String, int>> getPlayerGameCounts(String playerId) async {
    // 'games' という名前の全サブコレクションを横断検索し、自分のIDが含まれるドキュメントのみを取得
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('games')
        .where('assigned', arrayContains: playerId)
        .get();

    final counts = <String, int>{
      'singles': 0,
      'doubles': 0,
      'trios': 0,
      'gallon': 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final format = data['format'] as String?;

      // formatが存在する場合のみカウントアップ
      if (format != null) {
        counts[format] = (counts[format] ?? 0) + 1;
      }
    }

    return counts;
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
        return 'その他 ($format)';
    }
  }
}