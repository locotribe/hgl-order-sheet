import 'package:cloud_firestore/cloud_firestore.dart';

/// weeks/{weekId}/attendance/{playerId} — SPEC.md §6
class Attendance {
  const Attendance({
    required this.playerId,
    required this.present,
    this.joinedAt,
  });

  final String playerId;
  final bool present;
  final DateTime? joinedAt;

  factory Attendance.fromMap(String playerId, Map<String, dynamic> map) {
    final rawJoinedAt = map['joinedAt'];
    return Attendance(
      playerId: playerId,
      present: map['present'] as bool? ?? false,
      joinedAt: rawJoinedAt is Timestamp ? rawJoinedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'present': present,
      'joinedAt': joinedAt != null
          ? Timestamp.fromDate(joinedAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}
