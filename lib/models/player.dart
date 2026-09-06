/// players/{playerId} — SPEC.md §6
class PlayerGameRecord {
  const PlayerGameRecord({this.wins = 0, this.losses = 0});

  final int wins;
  final int losses;

  factory PlayerGameRecord.fromMap(Map<String, dynamic> map) {
    return PlayerGameRecord(
      wins: (map['wins'] as num?)?.toInt() ?? 0,
      losses: (map['losses'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'wins': wins, 'losses': losses};

  PlayerGameRecord copyWith({int? wins, int? losses}) {
    return PlayerGameRecord(
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
    );
  }
}

class Player {
  const Player({
    required this.id,
    required this.lineUserId,
    required this.kanjiName,
    this.rating = 0,
    this.stats01 = 0,
    this.statsCricket = 0,
    this.manualRating,
    this.isProvisional = false,
    this.winLossByGame = const {},
    this.winRate = 0,
    this.isAdmin = false,
  });

  final String id;
  final String lineUserId;
  final String kanjiName;
  final double rating;
  final double stats01;
  final double statsCricket;

  /// 新規メンバーはスクレイプ対象データがまだ無いため、この値を暫定使用する。
  /// 実データが取得できた時点で `isProvisional=false` にしてスクレイプ値へ置換する。
  final double? manualRating;
  final bool isProvisional;

  /// ゲーム番号(1-11)ごとの勝敗。
  final Map<int, PlayerGameRecord> winLossByGame;
  final double winRate;
  final bool isAdmin;

  /// 01系・クリケット系それぞれの強さ算出に使う実効値。
  /// provisional/ゲストは手入力レートを両軸の代用値として使う（SPEC §5）。
  double get effectiveStats01 => isProvisional ? (manualRating ?? 0) : stats01;
  double get effectiveStatsCricket =>
      isProvisional ? (manualRating ?? 0) : statsCricket;

  factory Player.fromMap(String id, Map<String, dynamic> map) {
    final rawWinLoss = (map['winLossByGame'] as Map?) ?? {};
    return Player(
      id: id,
      lineUserId: map['lineUserId'] as String? ?? '',
      kanjiName: map['kanjiName'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      stats01: (map['stats01'] as num?)?.toDouble() ?? 0,
      statsCricket: (map['statsCricket'] as num?)?.toDouble() ?? 0,
      manualRating: (map['manualRating'] as num?)?.toDouble(),
      isProvisional: map['isProvisional'] as bool? ?? false,
      winLossByGame: rawWinLoss.map(
        (key, value) => MapEntry(
          int.parse(key.toString()),
          PlayerGameRecord.fromMap(Map<String, dynamic>.from(value as Map)),
        ),
      ),
      winRate: (map['winRate'] as num?)?.toDouble() ?? 0,
      isAdmin: map['isAdmin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lineUserId': lineUserId,
      'kanjiName': kanjiName,
      'rating': rating,
      'stats01': stats01,
      'statsCricket': statsCricket,
      'manualRating': manualRating,
      'isProvisional': isProvisional,
      'winLossByGame': winLossByGame.map(
        (key, value) => MapEntry(key.toString(), value.toMap()),
      ),
      'winRate': winRate,
      'isAdmin': isAdmin,
    };
  }

  Player copyWith({
    String? kanjiName,
    double? rating,
    double? stats01,
    double? statsCricket,
    double? manualRating,
    bool? isProvisional,
    Map<int, PlayerGameRecord>? winLossByGame,
    double? winRate,
    bool? isAdmin,
  }) {
    return Player(
      id: id,
      lineUserId: lineUserId,
      kanjiName: kanjiName ?? this.kanjiName,
      rating: rating ?? this.rating,
      stats01: stats01 ?? this.stats01,
      statsCricket: statsCricket ?? this.statsCricket,
      manualRating: manualRating ?? this.manualRating,
      isProvisional: isProvisional ?? this.isProvisional,
      winLossByGame: winLossByGame ?? this.winLossByGame,
      winRate: winRate ?? this.winRate,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
