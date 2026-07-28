enum Occasion { casual, office, date, party }

extension OccasionX on Occasion {
  String get label {
    switch (this) {
      case Occasion.casual:
        return 'Casual';
      case Occasion.office:
        return 'Office';
      case Occasion.date:
        return 'Date';
      case Occasion.party:
        return 'Party';
    }
  }
}

class Outfit {
  final int? id;
  final String name;
  final int topId;
  final int? bottomId;
  final int? shoeId;
  final int? accessoryId;
  final Occasion occasion;
  final bool favourite;
  final DateTime dateCreated;

  const Outfit({
    this.id,
    required this.name,
    required this.topId,
    this.bottomId,
    this.shoeId,
    this.accessoryId,
    required this.occasion,
    this.favourite = false,
    required this.dateCreated,
  });

  Outfit copyWith({
    int? id,
    String? name,
    int? topId,
    int? bottomId,
    int? shoeId,
    int? accessoryId,
    Occasion? occasion,
    bool? favourite,
    DateTime? dateCreated,
  }) {
    return Outfit(
      id: id ?? this.id,
      name: name ?? this.name,
      topId: topId ?? this.topId,
      bottomId: bottomId ?? this.bottomId,
      shoeId: shoeId ?? this.shoeId,
      accessoryId: accessoryId ?? this.accessoryId,
      occasion: occasion ?? this.occasion,
      favourite: favourite ?? this.favourite,
      dateCreated: dateCreated ?? this.dateCreated,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'top_id': topId,
      'bottom_id': bottomId,
      'shoe_id': shoeId,
      'accessory_id': accessoryId,
      'occasion': occasion.name,
      'favourite': favourite ? 1 : 0,
      'date_created': dateCreated.toIso8601String(),
    };
  }

  factory Outfit.fromMap(Map<String, Object?> map) {
    return Outfit(
      id: map['id'] as int?,
      name: map['name'] as String,
      topId: map['top_id'] as int,
      bottomId: map['bottom_id'] as int?,
      shoeId: map['shoe_id'] as int?,
      accessoryId: map['accessory_id'] as int?,
      occasion: Occasion.values.firstWhere(
        (o) => o.name == map['occasion'],
        orElse: () => Occasion.casual,
      ),
      favourite: (map['favourite'] as int? ?? 0) == 1,
      dateCreated: DateTime.parse(map['date_created'] as String),
    );
  }
}
