import 'package:cloud_firestore/cloud_firestore.dart';

import '../../config/game_definitions.dart';
import '../../models/week.dart';
import '../../models/game_slot.dart';

class WeekRepository {
  WeekRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Week> get _collection => _firestore
      .collection('weeks')
      .withConverter<Week>(
        fromFirestore: (snap, _) => Week.fromMap(snap.id, snap.data()!),
        toFirestore: (week, _) => week.toMap(),
      );

  Stream<List<Week>> watchAll() {
    return _collection
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  /// 今日以降で最も近い週を「今週の試合」として返す。
  Stream<Week?> watchCurrentWeek() {
    final startOfToday = DateTime.now();
    final today = DateTime(startOfToday.year, startOfToday.month, startOfToday.day);
    return _collection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .orderBy('date')
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : snap.docs.first.data());
  }

  Future<Week?> getById(String weekId) async {
    final snap = await _collection.doc(weekId).get();
    return snap.data();
  }

  Future<void> upsert(Week week) => _collection.doc(week.id).set(week);

  /// 週のゲーム(1-11)を §3 の定義から初期化する（まだ無ければ）。
  Future<void> ensureGameSlotsInitialized(String weekId) async {
    final gamesRef = _firestore.collection('weeks/$weekId/games');
    final existing = await gamesRef.get();
    if (existing.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (final def in kGameDefinitions) {
      final slot = GameSlot.fromDefinition(def);
      batch.set(gamesRef.doc(def.number.toString()), slot.toMap());
    }
    await batch.commit();
  }
}
