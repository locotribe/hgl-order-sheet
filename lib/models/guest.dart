/// weeks/{weekId}/guests/{guestId} — SPEC.md §6
/// その日限りの参加者。恒久的な登録は残さない。
class Guest {
  const Guest({required this.id, required this.name, required this.rating});

  final String id;
  final String name;
  final double rating;

  factory Guest.fromMap(String id, Map<String, dynamic> map) {
    return Guest(
      id: id,
      name: map['name'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'rating': rating};
}
