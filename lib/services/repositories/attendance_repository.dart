import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/attendance.dart';

class AttendanceRepository {
  AttendanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Attendance> _collection(String weekId) => _firestore
      .collection('weeks/$weekId/attendance')
      .withConverter<Attendance>(
    fromFirestore: (snap, _) => Attendance.fromMap(snap.id, snap.data()!),
    toFirestore: (a, _) => a.toMap(),
  );

  Stream<List<Attendance>> watchAll(String weekId) {
    return _collection(
      weekId,
    ).snapshots().map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> setPresent({
    required String weekId,
    required String playerId,
    required bool present,
    String? arrivalTime,
    bool? isArrived,
  }) async {
    final docRef = _collection(weekId).doc(playerId);

    if (!present) {
      await docRef.set(
        Attendance(
          playerId: playerId,
          present: false,
          joinedAt: DateTime.now(),
          arrivalTime: null,
          isArrived: false,
        ),
      );
      return;
    }

    final docSnap = await docRef.get();
    final existing = docSnap.data();

    await docRef.set(
      Attendance(
        playerId: playerId,
        present: true,
        joinedAt: existing?.joinedAt ?? DateTime.now(),
        arrivalTime: arrivalTime ?? existing?.arrivalTime,
        isArrived: isArrived ?? existing?.isArrived ?? false,
      ),
      SetOptions(merge: true),
    );
  }

  Future<void> setArrived({
    required String weekId,
    required String playerId,
    required bool isArrived,
  }) async {
    await _collection(weekId).doc(playerId).update({
      'isArrived': isArrived,
    });
  }
}