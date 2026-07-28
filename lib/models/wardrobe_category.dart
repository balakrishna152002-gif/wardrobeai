enum WardrobeCategory {
  tops,
  jeans,
  pants,
  shorts,
  dresses,
  jackets,
  shoes,
  caps,
  bags,
  accessories,
}

extension WardrobeCategoryX on WardrobeCategory {
  String get label {
    switch (this) {
      case WardrobeCategory.tops:
        return 'Tops';
      case WardrobeCategory.jeans:
        return 'Jeans';
      case WardrobeCategory.pants:
        return 'Pants';
      case WardrobeCategory.shorts:
        return 'Shorts';
      case WardrobeCategory.dresses:
        return 'Dresses';
      case WardrobeCategory.jackets:
        return 'Jackets';
      case WardrobeCategory.shoes:
        return 'Shoes';
      case WardrobeCategory.caps:
        return 'Caps';
      case WardrobeCategory.bags:
        return 'Bags';
      case WardrobeCategory.accessories:
        return 'Accessories';
    }
  }

  String get emoji {
    switch (this) {
      case WardrobeCategory.tops:
        return '👕';
      case WardrobeCategory.jeans:
        return '👖';
      case WardrobeCategory.pants:
        return '👖';
      case WardrobeCategory.shorts:
        return '🩳';
      case WardrobeCategory.dresses:
        return '👗';
      case WardrobeCategory.jackets:
        return '🧥';
      case WardrobeCategory.shoes:
        return '👟';
      case WardrobeCategory.caps:
        return '🧢';
      case WardrobeCategory.bags:
        return '👜';
      case WardrobeCategory.accessories:
        return '⌚';
    }
  }

  /// Storage key used in the database, stable even if [label] changes.
  String get dbKey => name;

  static WardrobeCategory fromDbKey(String key) {
    return WardrobeCategory.values.firstWhere(
      (c) => c.dbKey == key,
      orElse: () => WardrobeCategory.tops,
    );
  }

  bool get hasSleeves =>
      this == WardrobeCategory.tops ||
      this == WardrobeCategory.dresses ||
      this == WardrobeCategory.jackets;

  /// Categories that can fill the "top" slot in an outfit.
  static List<WardrobeCategory> get topSlot => [
        WardrobeCategory.tops,
        WardrobeCategory.dresses,
      ];

  /// Categories that can fill the "bottom" slot in an outfit.
  static List<WardrobeCategory> get bottomSlot => [
        WardrobeCategory.jeans,
        WardrobeCategory.pants,
        WardrobeCategory.shorts,
      ];
}
