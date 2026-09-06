class Player {
  final String id;
  final String lineUserId;
  final String kanjiName; // 成績スクレイプ照合用の固定キー
  final String? displayName; // アプリ内表示用ネーム（何度でも変更可能）
  final double rating;
  final double? manualRating;
  final double stats01;
  final double statsCricket;
  final int wins;
  final int losses;
  final bool isProvisional;

  Player({
    required this.id,
    required this.lineUserId,
    required this.kanjiName,
    this.displayName,
    this.rating = 0.0,
    this.manualRating,
    this.stats01 = 0.0,
    this.statsCricket = 0.0,
    this.wins = 0,
    this.losses = 0,
    this.isProvisional = true,
  });

  /// アプリ内で描画する際の名前（displayNameがあれば優先、無ければkanjiName）
  String get effectiveName =>
      (displayName != null && displayName!.trim().isNotEmpty)
          ? displayName!
          : kanjiName;

  double get effectiveStats01 => manualRating ?? stats01;
  double get effectiveStatsCricket => manualRating ?? statsCricket;

  double get winRate {
    final total = wins + losses;
    if (total == 0) return 0.0;
    return wins / total;
  }

  Map<String, dynamic> toMap() {
    return {
      'lineUserId': lineUserId,
      'kanjiName': kanjiName,
      'displayName': displayName,
      'rating': rating,
      'manualRating': manualRating,
      'stats01': stats01,
      'statsCricket': statsCricket,
      'wins': wins,
      'losses': losses,
      'isProvisional': isProvisional,
    };
  }

  factory Player.fromMap(String id, Map<String, dynamic> map) {
    return Player(
      id: id,
      lineUserId: map['lineUserId'] ?? '',
      kanjiName: map['kanjiName'] ?? '',
      displayName: map['displayName'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      manualRating: map['manualRating'] != null
          ? (map['manualRating'] as num).toDouble()
          : null,
      stats01: (map['stats01'] ?? 0.0).toDouble(),
      statsCricket: (map['statsCricket'] ?? map['stats01'] ?? 0.0).toDouble(),
      wins: map['wins'] ?? 0,
      losses: map['losses'] ?? 0,
      isProvisional: map['isProvisional'] ?? (map['manualRating'] != null),
    );
  }

  Player copyWith({
    String? lineUserId,
    String? kanjiName,
    String? displayName,
    double? rating,
    double? manualRating,
    double? stats01,
    double? statsCricket,
    int? wins,
    int? losses,
    bool? isProvisional,
  }) {
    return Player(
      id: id,
      lineUserId: lineUserId ?? this.lineUserId,
      kanjiName: kanjiName ?? this.kanjiName,
      displayName: displayName ?? this.displayName,
      rating: rating ?? this.rating,
      manualRating: manualRating ?? this.manualRating,
      stats01: stats01 ?? this.stats01,
      statsCricket: statsCricket ?? this.statsCricket,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      isProvisional: isProvisional ?? this.isProvisional,
    );
  }
}