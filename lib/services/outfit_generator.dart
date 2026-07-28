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

  /// 0-100 "wearability" score - colour harmony and occasion/style fit.
  final int score;

  const GeneratedOutfit({
    required this.top,
    this.bottom,
    this.shoe,
    this.accessory,
    required this.occasion,
    this.aiReasoning,
    required this.score,
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
  /// against the actual wardrobe. When [anchor] is set (One-Tap Match), the
  /// AI path is skipped in favour of the local heuristic, which pins the
  /// anchor into its slot and matches everything else around it.
  static Future<GeneratedOutfit> generateSmart(
    Occasion occasion,
    ClothingGender gender, {
    ClothingItem? anchor,
  }) async {
    if (anchor != null) return generate(occasion, gender, anchor: anchor);

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
        final bottom = byId[suggestion.bottomId];
        final shoe = byId[suggestion.shoeId];
        final accessory = byId[suggestion.accessoryId];
        return GeneratedOutfit(
          top: top,
          bottom: bottom,
          shoe: shoe,
          accessory: accessory,
          occasion: occasion,
          aiReasoning: suggestion.reasoning,
          score: suggestion.score ??
              _computeScore([top, bottom, shoe, accessory], _desiredStyleFor(occasion)),
        );
      }
    }

    return generate(occasion, gender);
  }

  static Future<GeneratedOutfit> generate(
    Occasion occasion,
    ClothingGender gender, {
    ClothingItem? anchor,
  }) async {
    final all = _forGender(await DatabaseHelper.instance.getAllClothingItems(), gender);
    final recentOutfits = await DatabaseHelper.instance.getAllOutfits();
    final recentSignatures = recentOutfits
        .take(_recentComboCheckCount)
        .map((o) => '${o.topId}-${o.bottomId}-${o.shoeId}-${o.accessoryId}')
        .toSet();

    final desiredStyle = _desiredStyleFor(occasion);
    final anchorSlot = anchor?.category.outfitSlot;

    List<ClothingItem> byCategories(List<WardrobeCategory> cats) =>
        all.where((i) => cats.contains(i.category)).toList();

    List<ClothingItem> preferStyle(List<ClothingItem> items) {
      if (desiredStyle == null) return items;
      final matching = items.where((i) => i.style == desiredStyle).toList();
      return matching.isNotEmpty ? matching : items;
    }

    final topCandidates = preferStyle(byCategories(WardrobeCategoryX.topSlot));
    if (topCandidates.isEmpty && anchorSlot != OutfitSlot.top) {
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
      final worn = <String>[if (anchor != null) anchor.colour];

      final top = anchorSlot == OutfitSlot.top
          ? anchor!
          : topCandidates[_random.nextInt(topCandidates.length)];
      if (anchorSlot != OutfitSlot.top) worn.add(top.colour);

      ClothingItem? bottom;
      if (anchorSlot == OutfitSlot.bottom) {
        bottom = anchor;
      } else if (top.category != WardrobeCategory.dresses && bottomCandidates.isNotEmpty) {
        bottom = _pickBestMatch(bottomCandidates, worn);
        worn.add(bottom.colour);
      }

      ClothingItem? shoe;
      if (anchorSlot == OutfitSlot.shoe) {
        shoe = anchor;
      } else if (shoeCandidates.isNotEmpty) {
        shoe = _pickBestMatch(shoeCandidates, worn);
        worn.add(shoe.colour);
      }

      ClothingItem? accessory;
      if (anchorSlot == OutfitSlot.accessory) {
        accessory = anchor;
      } else if (accessoryCandidates.isNotEmpty && _random.nextDouble() < 0.7) {
        accessory = _pickBestMatch(accessoryCandidates, worn);
      }

      return GeneratedOutfit(
        top: top,
        bottom: bottom,
        shoe: shoe,
        accessory: accessory,
        occasion: occasion,
        score: _computeScore([top, bottom, shoe, accessory], desiredStyle),
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

  /// 0-100 wearability score: average pairwise colour-harmony across every
  /// item in the outfit, with a bonus when everything matches the
  /// occasion's desired style.
  static int _computeScore(List<ClothingItem?> slots, ClothingStyle? desiredStyle) {
    final items = slots.whereType<ClothingItem>().toList();
    double colourTotal = 0;
    var pairs = 0;
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        colourTotal += _colourScore(items[i].colour, items[j].colour);
        pairs++;
      }
    }
    final avgColour = pairs == 0 ? 0.75 : colourTotal / pairs;
    final styleMatches = desiredStyle == null || items.every((i) => i.style == desiredStyle);
    final raw = (avgColour + (styleMatches ? 0.1 : 0.0)).clamp(0.0, 1.0);
    return (raw * 100).round();
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
