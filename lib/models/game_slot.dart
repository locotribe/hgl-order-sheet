import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/game_definitions.dart';

/// 先攻/後攻。
enum FirstThrow { first, second, undecided }

/// ○×（勝敗）。
enum GameResult { pending, win, loss }

FirstThrow firstThrowFromString(String? value) {
  switch (value) {
    case 'first':
      return FirstThrow.first;
    case 'second':
      return FirstThrow.second;
    default:
      return FirstThrow.undecided;
  }
}

GameResult gameResultFromString(String? value) {
  switch (value) {
    case 'win':
      return GameResult.win;
    case 'loss':
      return GameResult.loss;
    default:
      return GameResult.pending;
  }
}

/// weeks/{weekId}/games/{1..11} — SPEC.md §6
class GameSlot {
  const GameSlot({
    required this.number,
    required this.type,
    required this.format,
    required this.handicap,
    this.rounds,
    this.credits,
    this.firstThrow = FirstThrow.undecided,
    this.assigned = const [],
    this.result = GameResult.pending,
    this.lastEditedBy,
    this.editedAt,
  });

  final int number;
  final String type;
  final GameFormat format;
  final HandicapType handicap;
  final int? rounds;
  final int? credits;
  final FirstThrow firstThrow;

  /// 割り当てられたメンバー/ゲストのID（players または guests のドキュメントID）。
  final List<String> assigned;
  final GameResult result;
  final String? lastEditedBy;
  final DateTime? editedAt;

  factory GameSlot.fromDefinition(GameDefinition def) {
    return GameSlot(
      number: def.number,
      type: def.name,
      format: def.format,
      handicap: def.handicap,
    );
  }

  factory GameSlot.fromMap(int number, Map<String, dynamic> map) {
    final rawEditedAt = map['editedAt'];
    return GameSlot(
      number: number,
      type: map['type'] as String? ?? '',
      format: GameFormat.values.byName(map['format'] as String? ?? 'singles'),
      handicap: HandicapType.values.byName(
        map['handicap'] as String? ?? 'none',
      ),
      rounds: (map['rounds'] as num?)?.toInt(),
      credits: (map['credits'] as num?)?.toInt(),
      firstThrow: firstThrowFromString(map['firstThrow'] as String?),
      assigned: List<String>.from(map['assigned'] as List? ?? const []),
      result: gameResultFromString(map['result'] as String?),
      lastEditedBy: map['lastEditedBy'] as String?,
      editedAt: rawEditedAt is Timestamp ? rawEditedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'format': format.name,
      'handicap': handicap.name,
      'rounds': rounds,
      'credits': credits,
      'firstThrow': firstThrow.name,
      'assigned': assigned,
      'result': result.name,
      'lastEditedBy': lastEditedBy,
      'editedAt': FieldValue.serverTimestamp(),
    };
  }

  GameSlot copyWith({
    FirstThrow? firstThrow,
    List<String>? assigned,
    GameResult? result,
    String? lastEditedBy,
  }) {
    return GameSlot(
      number: number,
      type: type,
      format: format,
      handicap: handicap,
      rounds: rounds,
      credits: credits,
      firstThrow: firstThrow ?? this.firstThrow,
      assigned: assigned ?? this.assigned,
      result: result ?? this.result,
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      editedAt: editedAt,
    );
  }
}
