import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/guest.dart';

class GuestRepository {
  GuestRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Guest> _collection(String weekId) => _firestore
      .collection('weeks/$weekId/guests')
      .withConverter<Guest>(
        fromFirestore: (snap, _) => Guest.fromMap(snap.id, snap.data()!),
        toFirestore: (g, _) => g.toMap(),
      );

  Stream<List<Guest>> watchAll(String weekId) {
    return _collection(
      weekId,
    ).snapshots().map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<String> add({
    required String weekId,
    required String name,
    required double rating,
  }) async {
    final doc = _collection(weekId).doc();
    await doc.set(Guest(id: doc.id, name: name, rating: rating));
    return doc.id;
  }

  Future<void> remove({required String weekId, required String guestId}) {
    return _collection(weekId).doc(guestId).delete();
  }
}
