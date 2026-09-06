// [修正] 特定のプレイヤーを未決着ゲームから自動削除する処理の追加 (v.1.1)
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/game_slot.dart';

class GameRepository {
  GameRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<GameSlot> _collection(String weekId) => _firestore
      .collection('weeks/$weekId/games')
      .withConverter<GameSlot>(
    fromFirestore: (snap, _) =>
        GameSlot.fromMap(int.parse(snap.id), snap.data()!),
    toFirestore: (g, _) => g.toMap(),
  );

  Stream<List<GameSlot>> watchAll(String weekId) {
    return _collection(weekId).orderBy(FieldPath.documentId).snapshots().map(
          (snap) => snap.docs.map((d) => d.data()).toList()
        ..sort((a, b) => a.number.compareTo(b.number)),
    );
  }

  Future<List<GameSlot>> getAllOnce(String weekId) async {
    final snap = await _collection(weekId).get();
    final list = snap.docs.map((d) => d.data()).toList();
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  Future<void> saveAssignment({
    required String weekId,
    required GameSlot slot,
    required String editedBy,
  }) {
    return _collection(
      weekId,
    ).doc(slot.number.toString()).set(slot.copyWith(lastEditedBy: editedBy));
  }

  Future<void> saveAll({
    required String weekId,
    required List<GameSlot> slots,
    required String editedBy,
  }) async {
    final batch = _firestore.batch();
    final col = _firestore.collection('weeks/$weekId/games');
    for (final slot in slots) {
      batch.set(
        col.doc(slot.number.toString()),
        slot.copyWith(lastEditedBy: editedBy).toMap(),
      );
    }
    await batch.commit();
  }

  // 追加: 管理者が不参加にした際、まだ勝敗が決まっていないゲームの枠のみを空（''）にする
  Future<void> removePlayerFromPendingGames({
    required String weekId,
    required String playerId,
    required String editedBy,
  }) async {
    final games = await getAllOnce(weekId);
    final batch = _firestore.batch();
    final col = _firestore.collection('weeks/$weekId/games');
    bool hasUpdates = false;

    for (final game in games) {
      if (game.result.name == 'pending' && game.assigned.contains(playerId)) {
        // 対象プレイヤーのIDだけを空文字に置き換える
        final newAssigned = game.assigned.map((id) => id == playerId ? '' : id).toList();
        batch.set(
          col.doc(game.number.toString()),
          game.copyWith(assigned: newAssigned, lastEditedBy: editedBy).toMap(),
        );
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }
}