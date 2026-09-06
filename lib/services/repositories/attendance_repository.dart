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
  }) {
    return _collection(weekId).doc(playerId).set(
      Attendance(playerId: playerId, present: present, joinedAt: DateTime.now()),
    );
  }
}
