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
}
