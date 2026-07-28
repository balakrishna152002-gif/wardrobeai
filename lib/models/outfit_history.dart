class OutfitHistoryEntry {
  final int? id;
  final int outfitId;
  final DateTime date;

  const OutfitHistoryEntry({
    this.id,
    required this.outfitId,
    required this.date,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'outfit_id': outfitId,
      'date': date.toIso8601String(),
    };
  }

  factory OutfitHistoryEntry.fromMap(Map<String, Object?> map) {
    return OutfitHistoryEntry(
      id: map['id'] as int?,
      outfitId: map['outfit_id'] as int,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
