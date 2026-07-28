import 'wardrobe_category.dart';

enum ClothingStyle { casual, formal }

enum ClothingSeason { summer, winter, allSeason }

enum ClothingGender { men, women, unisex }

extension ClothingStyleX on ClothingStyle {
  String get label => this == ClothingStyle.formal ? 'Formal' : 'Casual';
}

extension ClothingSeasonX on ClothingSeason {
  String get label {
    switch (this) {
      case ClothingSeason.summer:
        return 'Summer';
      case ClothingSeason.winter:
        return 'Winter';
      case ClothingSeason.allSeason:
        return 'All season';
    }
  }
}

extension ClothingGenderX on ClothingGender {
  String get label {
    switch (this) {
      case ClothingGender.men:
        return 'Men';
      case ClothingGender.women:
        return 'Women';
      case ClothingGender.unisex:
        return 'Unisex';
    }
  }
}

class ClothingItem {
  final int? id;
  final WardrobeCategory category;
  final String imagePath;
  final String colour;
  final String pattern;
  final String? sleeveLength;
  final ClothingSeason season;
  final ClothingStyle style;
  final ClothingGender gender;
  final String brand;
  final bool favourite;
  final bool archived;
  final DateTime dateAdded;

  const ClothingItem({
    this.id,
    required this.category,
    required this.imagePath,
    required this.colour,
    required this.pattern,
    this.sleeveLength,
    required this.season,
    required this.style,
    this.gender = ClothingGender.unisex,
    this.brand = '',
    this.favourite = false,
    this.archived = false,
    required this.dateAdded,
  });

  ClothingItem copyWith({
    int? id,
    WardrobeCategory? category,
    String? imagePath,
    String? colour,
    String? pattern,
    String? sleeveLength,
    ClothingSeason? season,
    ClothingStyle? style,
    ClothingGender? gender,
    String? brand,
    bool? favourite,
    bool? archived,
    DateTime? dateAdded,
  }) {
    return ClothingItem(
      id: id ?? this.id,
      category: category ?? this.category,
      imagePath: imagePath ?? this.imagePath,
      colour: colour ?? this.colour,
      pattern: pattern ?? this.pattern,
      sleeveLength: sleeveLength ?? this.sleeveLength,
      season: season ?? this.season,
      style: style ?? this.style,
      gender: gender ?? this.gender,
      brand: brand ?? this.brand,
      favourite: favourite ?? this.favourite,
      archived: archived ?? this.archived,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'category': category.dbKey,
      'image_path': imagePath,
      'colour': colour,
      'pattern': pattern,
      'sleeve_length': sleeveLength,
      'season': season.name,
      'style': style.name,
      'gender': gender.name,
      'brand': brand,
      'favourite': favourite ? 1 : 0,
      'archived': archived ? 1 : 0,
      'date_added': dateAdded.toIso8601String(),
    };
  }

  factory ClothingItem.fromMap(Map<String, Object?> map) {
    return ClothingItem(
      id: map['id'] as int?,
      category: WardrobeCategoryX.fromDbKey(map['category'] as String),
      imagePath: map['image_path'] as String,
      colour: map['colour'] as String,
      pattern: map['pattern'] as String,
      sleeveLength: map['sleeve_length'] as String?,
      season: ClothingSeason.values.firstWhere(
        (s) => s.name == map['season'],
        orElse: () => ClothingSeason.allSeason,
      ),
      style: ClothingStyle.values.firstWhere(
        (s) => s.name == map['style'],
        orElse: () => ClothingStyle.casual,
      ),
      gender: ClothingGender.values.firstWhere(
        (g) => g.name == map['gender'],
        orElse: () => ClothingGender.unisex,
      ),
      brand: map['brand'] as String? ?? '',
      favourite: (map['favourite'] as int? ?? 0) == 1,
      archived: (map['archived'] as int? ?? 0) == 1,
      dateAdded: DateTime.parse(map['date_added'] as String),
    );
  }
}
