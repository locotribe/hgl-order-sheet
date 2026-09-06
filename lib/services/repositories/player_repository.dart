import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/player.dart';

class PlayerRepository {
  PlayerRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Player> get _collection => _firestore
      .collection('players')
      .withConverter<Player>(
        fromFirestore: (snap, _) => Player.fromMap(snap.id, snap.data()!),
        toFirestore: (player, _) => player.toMap(),
      );

  Stream<List<Player>> watchAll() {
    return _collection.snapshots().map(
      (snap) => snap.docs.map((d) => d.data()).toList(),
    );
  }

  Future<Player?> findByLineUserId(String lineUserId) async {
    final snap = await _collection
        .where('lineUserId', isEqualTo: lineUserId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  Future<Player?> getById(String playerId) async {
    final snap = await _collection.doc(playerId).get();
    return snap.data();
  }

  Stream<Player?> watchById(String playerId) {
    return _collection.doc(playerId).snapshots().map((s) => s.data());
  }

  Future<String> createFromLiff({
    required String lineUserId,
    required String kanjiName,
  }) async {
    final doc = _collection.doc();
    await doc.set(
      Player(
        id: doc.id,
        lineUserId: lineUserId,
        kanjiName: kanjiName,
        isProvisional: true,
      ),
    );
    return doc.id;
  }

  Future<void> update(Player player) => _collection.doc(player.id).set(player);

  Future<void> setManualRating({
    required String playerId,
    required double manualRating,
  }) {
    return _firestore.collection('players').doc(playerId).update({
      'manualRating': manualRating,
      'isProvisional': true,
    });
  }

  Future<void> setAdmin(String playerId, bool isAdmin) {
    return _firestore.collection('players').doc(playerId).update({
      'isAdmin': isAdmin,
    });
  }
}
