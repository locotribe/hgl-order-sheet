import 'package:cloud_firestore/cloud_firestore.dart';

/// weeks/{weekId}/attendance/{playerId} — SPEC.md §6
class Attendance {
  const Attendance({
    required this.playerId,
    required this.present,
    this.joinedAt,
    this.arrivalTime,
    this.isArrived = false,
  });

  final String playerId;
  final bool present;
  final DateTime? joinedAt;
  final String? arrivalTime;
  final bool isArrived;

  factory Attendance.fromMap(String playerId, Map<String, dynamic> map) {
    final rawJoinedAt = map['joinedAt'];
    return Attendance(
      playerId: playerId,
      present: map['present'] as bool? ?? false,
      joinedAt: rawJoinedAt is Timestamp ? rawJoinedAt.toDate() : null,
      arrivalTime: map['arrivalTime'] as String?,
      isArrived: map['isArrived'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'present': present,
      'joinedAt': joinedAt != null
          ? Timestamp.fromDate(joinedAt!)
          : FieldValue.serverTimestamp(),
      'arrivalTime': arrivalTime,
      'isArrived': isArrived,
    };
  }

  Attendance copyWith({
    bool? present,
    DateTime? joinedAt,
    String? arrivalTime,
    bool? isArrived,
  }) {
    return Attendance(
      playerId: playerId,
      present: present ?? this.present,
      joinedAt: joinedAt ?? this.joinedAt,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      isArrived: isArrived ?? this.isArrived,
    );
  }
}