import 'package:cloud_firestore/cloud_firestore.dart';

/// scrapes/{timestamp} — SPEC.md §6
class ScrapeRecord {
  const ScrapeRecord({
    required this.id,
    required this.source,
    required this.rawSnapshot,
    required this.parsedAt,
  });

  final String id;
  final String source;
  final String rawSnapshot;
  final DateTime parsedAt;

  factory ScrapeRecord.fromMap(String id, Map<String, dynamic> map) {
    final rawParsedAt = map['parsedAt'];
    return ScrapeRecord(
      id: id,
      source: map['source'] as String? ?? '',
      rawSnapshot: map['rawSnapshot'] as String? ?? '',
      parsedAt: rawParsedAt is Timestamp ? rawParsedAt.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'rawSnapshot': rawSnapshot,
      'parsedAt': Timestamp.fromDate(parsedAt),
    };
  }
}
