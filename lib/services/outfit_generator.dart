import 'dart:math';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../models/wardrobe_category.dart';
import 'ai_outfit_service.dart';

class GeneratedOutfit {
  final ClothingItem top;
  final ClothingItem? bottom;
  final ClothingItem? shoe;
  final ClothingItem? accessory;
  final Occasion occasion;
  final String? aiReasoning;

  const GeneratedOutfit({
    required this.top,
    this.bottom,
    this.shoe,
    this.accessory,
    required this.occasion,
    this.aiReasoning,
  });

  bool get isFromAi => aiReasoning != null;

  String get _signature => '${top.id}-${bottom?.id}-${shoe?.id}-${accessory?.id}';
}

class NotEnoughItemsException implements Exception {
  final String message;
  NotEnoughItemsException(this.message);
}

class OutfitGeneratorService {
  static final _random = Random();
  static const _recentComboCheckCount = 5;
  static const _maxRetries = 6;

  static ClothingStyle? _desiredStyleFor(Occasion occasion) {
    switch (occasion) {
      case Occasion.casual:
        return ClothingStyle.casual;
      case Occasion.office:
      case Occasion.party:
        return ClothingStyle.formal;
      case Occasion.date:
        return null; // mix of both is fine
    }
  }

  static List<ClothingItem> _forGender(List<ClothingItem> items, ClothingGender gender) {
    return items
        .where((i) => i.gender == gender || i.gender == ClothingGender.unisex)
        .toList();
  }

  /// Tries the cloud AI stylist first for a reasoned outfit pick; falls
  /// back to the local colour-harmony heuristic if the AI is unavailable
  /// (offline, endpoint down) or returns something that doesn't check out
  /// against the actual wardrobe.
  static Future<GeneratedOutfit> generateSmart(
    Occasion occasion,
    ClothingGender gender,
  ) async {
    final all = _forGender(await DatabaseHelper.instance.getAllClothingItems(), gender);
    if (all.isEmpty) {
      throw NotEnoughItemsException(
        'Add at least one ${gender.label.toLowerCase()} or unisex top to generate an outfit.',
      );
    }

    final suggestion = await AiOutfitService.suggest(wardrobe: all, occasion: occasion);
    if (suggestion != null) {
      final byId = {for (final i in all) i.id: i};
      final top = byId[suggestion.topId];
      if (top != null && WardrobeCategoryX.topSlot.contains(top.category)) {
        return GeneratedOutfit(
          top: top,
          bottom: byId[suggestion.bottomId],
          shoe: byId[suggestion.shoeId],
          accessory: byId[suggestion.accessoryId],
          occasion: occasion,
          aiReasoning: suggestion.reasoning,
        );
      }
    }

    return generate(occasion, gender);
  }

  static Future<GeneratedOutfit> generate(Occasion occasion, ClothingGender gender) async {
    final all = _forGender(await DatabaseHelper.instance.getAllClothingItems(), gender);
    final recentOutfits = await DatabaseHelper.instance.getAllOutfits();
    final recentSignatures = recentOutfits
        .take(_recentComboCheckCount)
        .map((o) => '${o.topId}-${o.bottomId}-${o.shoeId}-${o.accessoryId}')
        .toSet();

    final desiredStyle = _desiredStyleFor(occasion);

    List<ClothingItem> byCategories(List<WardrobeCategory> cats) =>
        all.where((i) => cats.contains(i.category)).toList();

    List<ClothingItem> preferStyle(List<ClothingItem> items) {
      if (desiredStyle == null) return items;
      final matching = items.where((i) => i.style == desiredStyle).toList();
      return matching.isNotEmpty ? matching : items;
    }

    final topCandidates = preferStyle(byCategories(WardrobeCategoryX.topSlot));
    if (topCandidates.isEmpty) {
      throw NotEnoughItemsException(
        'Add at least one ${gender.label.toLowerCase()} or unisex top to generate an outfit.',
      );
    }

    final bottomCandidates = preferStyle(byCategories(WardrobeCategoryX.bottomSlot));
    final shoeCandidates = byCategories([WardrobeCategory.shoes]);
    final accessoryCandidates = byCategories([
      WardrobeCategory.accessories,
      WardrobeCategory.bags,
      WardrobeCategory.caps,
    ]);

    GeneratedOutfit build() {
      final top = topCandidates[_random.nextInt(topCandidates.length)];
      final worn = <String>[top.colour];

      ClothingItem? bottom;
      if (top.category != WardrobeCategory.dresses && bottomCandidates.isNotEmpty) {
        bottom = _pickBestMatch(bottomCandidates, worn);
        worn.add(bottom.colour);
      }

      final shoe =
          shoeCandidates.isEmpty ? null : _pickBestMatch(shoeCandidates, worn);
      if (shoe != null) worn.add(shoe.colour);

      ClothingItem? accessory;
      if (accessoryCandidates.isNotEmpty && _random.nextDouble() < 0.7) {
        accessory = _pickBestMatch(accessoryCandidates, worn);
      }

      return GeneratedOutfit(
        top: top,
        bottom: bottom,
        shoe: shoe,
        accessory: accessory,
        occasion: occasion,
      );
    }

    var candidate = build();
    var attempts = 0;
    while (recentSignatures.contains(candidate._signature) && attempts < _maxRetries) {
      candidate = build();
      attempts++;
    }
    return candidate;
  }

  /// Picks a colour-compatible item rather than a uniformly random one.
  /// Scores every candidate against the colours already in the outfit, then
  /// picks randomly among the top-scoring third - keeps some variety
  /// between generations while still favouring outfits that go together.
  static ClothingItem _pickBestMatch(
    List<ClothingItem> candidates,
    List<String> alreadyWornColours,
  ) {
    if (candidates.length == 1) return candidates.first;
    final scored = candidates
        .map((c) => MapEntry(
              c,
              alreadyWornColours
                      .map((worn) => _colourScore(c.colour, worn))
                      .reduce((a, b) => a + b) /
                  alreadyWornColours.length,
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final poolSize = max(1, (scored.length / 3).ceil());
    final pool = scored.take(poolSize).map((e) => e.key).toList();
    return pool[_random.nextInt(pool.length)];
  }

  static const _neutralColours = {
    'white', 'black', 'grey', 'gray', 'beige', 'cream', 'ivory', 'navy',
  };

  /// Approximate hue angle (0-360) for common colour names, so free-text
  /// colour fields can still be compared for harmony. Unrecognised names
  /// fall back to a neutral score rather than being treated as clashing.
  static const _hueMap = <String, double>{
    'red': 0, 'maroon': 0, 'pink': 320, 'magenta': 320,
    'orange': 30, 'brown': 30, 'peach': 30,
    'yellow': 55, 'gold': 50, 'mustard': 45,
    'green': 120, 'olive': 90, 'mint': 140,
    'sky blue': 195, 'teal': 185, 'turquoise': 175, 'cyan': 185,
    'blue': 230, 'indigo': 245,
    'purple': 275, 'lavender': 275, 'violet': 275,
  };

  static double _colourScore(String? a, String? b) {
    if (a == null || b == null) return 0.5;
    final la = a.toLowerCase().trim();
    final lb = b.toLowerCase().trim();
    if (la.isEmpty || lb.isEmpty) return 0.5;
    if (la == lb) return 0.7; // monochrome - fine, but not the top pick
    if (_neutralColours.contains(la) || _neutralColours.contains(lb)) return 0.9;
    final ha = _hueMap[la];
    final hb = _hueMap[lb];
    if (ha == null || hb == null) return 0.5;
    var diff = (ha - hb).abs();
    if (diff > 180) diff = 360 - diff;
    if (diff <= 35) return 0.8; // analogous hues
    if (diff >= 150) return 0.75; // complementary hues
    return 0.3; // likely to clash
  }
}
