import 'package:cloud_firestore/cloud_firestore.dart';

/// weeks/{weekId} — SPEC.md §6
enum HomeAway { home, away }

enum WeekStatus { scheduled, inProgress, completed }

HomeAway homeAwayFromString(String? value) {
  return value == 'away' ? HomeAway.away : HomeAway.home;
}

WeekStatus weekStatusFromString(String? value) {
  switch (value) {
    case 'inProgress':
      return WeekStatus.inProgress;
    case 'completed':
      return WeekStatus.completed;
    default:
      return WeekStatus.scheduled;
  }
}

class Week {
  const Week({
    required this.id,
    required this.date,
    required this.opponentTeam,
    required this.homeAway,
    this.status = WeekStatus.scheduled,
  });

  final String id;
  final DateTime date;
  final String opponentTeam;
  final HomeAway homeAway;
  final WeekStatus status;

  factory Week.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['date'];
    return Week(
      id: id,
      date: rawDate is Timestamp
          ? rawDate.toDate()
          : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now(),
      opponentTeam: map['opponentTeam'] as String? ?? '',
      homeAway: homeAwayFromString(map['homeAway'] as String?),
      status: weekStatusFromString(map['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'opponentTeam': opponentTeam,
      'homeAway': homeAway.name,
      'status': status.name,
    };
  }
}
