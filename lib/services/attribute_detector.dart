import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:palette_generator/palette_generator.dart';

import '../models/clothing_item.dart';
import '../models/wardrobe_category.dart';

/// Fields the detector genuinely produced evidence for. Anything not
/// detected is left null so the UI can leave that field blank for the user
/// to fill in, rather than presenting a guess as if it were AI output.
class DetectedAttributes {
  final String? colour;
  final String? pattern;
  final ClothingSeason? season;
  final ClothingStyle? style;
  final WardrobeCategory? category;
  final List<String> rawLabels;

  const DetectedAttributes({
    this.colour,
    this.pattern,
    this.season,
    this.style,
    this.category,
    this.rawLabels = const [],
  });
}

/// Best-effort on-device attribute detection.
///
/// Colour comes from dominant-colour extraction (works on every platform).
/// Style/season hints come from Google ML Kit's generic image labeler, which
/// is only available on Android/iOS. When a signal isn't actually detected
/// (e.g. no ML Kit on this platform, or no matching label), the field is
/// left null rather than filled with a guessed default.
class AttributeDetector {
  static const _formalKeywords = [
    'suit',
    'blazer',
    'formal wear',
    'dress shirt',
    'necktie',
    'tuxedo',
  ];

  static const _casualKeywords = ['t-shirt', 'jeans', 'sportswear', 'shorts'];

  /// Checked in order - more specific garment keywords first, so e.g.
  /// "jeans" wins over a generic "pants" label on the same image.
  static const _categoryKeywords = <WardrobeCategory, List<String>>{
    WardrobeCategory.shorts: ['shorts', 'short pants'],
    WardrobeCategory.jeans: ['jeans', 'denim'],
    WardrobeCategory.dresses: ['dress', 'gown'],
    WardrobeCategory.jackets: ['jacket', 'coat', 'blazer', 'hoodie', 'sweater', 'cardigan'],
    WardrobeCategory.pants: ['trousers', 'pants', 'slacks', 'chinos'],
    WardrobeCategory.shoes: ['shoe', 'sneaker', 'boot', 'sandal', 'footwear', 'high heels'],
    WardrobeCategory.caps: ['cap', 'hat', 'beanie'],
    WardrobeCategory.bags: ['bag', 'handbag', 'backpack', 'purse'],
    WardrobeCategory.accessories: ['watch', 'belt', 'jewellery', 'jewelry', 'sunglasses', 'necklace'],
    WardrobeCategory.tops: ['t-shirt', 'shirt', 'top', 'blouse', 'polo'],
  };

  static Future<DetectedAttributes> detect({
    required File imageFile,
  }) async {
    final colour = await _dominantColourName(imageFile);
    ClothingStyle? style;
    ClothingSeason? season;
    WardrobeCategory? category;
    var labels = <String>[];

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        labels = await _labelImage(imageFile);
        final lower = labels.map((l) => l.toLowerCase()).toList();
        if (lower.any((l) => _formalKeywords.any(l.contains))) {
          style = ClothingStyle.formal;
        } else if (lower.any((l) => _casualKeywords.any(l.contains))) {
          style = ClothingStyle.casual;
        }
        if (lower.any((l) => l.contains('coat') || l.contains('sweater'))) {
          season = ClothingSeason.winter;
        } else if (lower.any((l) => l.contains('shorts'))) {
          season = ClothingSeason.summer;
        }
        for (final entry in _categoryKeywords.entries) {
          if (lower.any((l) => entry.value.any(l.contains))) {
            category = entry.key;
            break;
          }
        }
      } catch (_) {
        // ML Kit unavailable (e.g. model not downloaded yet) - leave blank.
      }
    }

    return DetectedAttributes(
      colour: colour,
      season: season,
      style: style,
      category: category,
      rawLabels: labels,
    );
  }

  static Future<List<String>> _labelImage(File imageFile) async {
    final labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.6),
    );
    try {
      final input = InputImage.fromFile(imageFile);
      final results = await labeler.processImage(input);
      return results.map((r) => r.label).toList();
    } finally {
      await labeler.close();
    }
  }

  static Future<String?> _dominantColourName(File imageFile) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        FileImage(imageFile),
        maximumColorCount: 12,
      );
      final dominant = palette.dominantColor?.color ?? palette.colors.firstOrNull;
      if (dominant == null) return null;
      return _classifyColour(dominant);
    } catch (_) {
      return null;
    }
  }

  /// Names a colour by hue rather than raw RGB distance to a fixed swatch
  /// list. Pastel/light colours (e.g. a light-blue shirt) have high
  /// lightness, which makes plain RGB-distance matching pull them toward
  /// "White" even though their hue is clearly blue - classifying by hue
  /// first (and only falling back to White/Black/Grey when saturation is
  /// genuinely low) avoids that.
  static String _classifyColour(Color colour) {
    final hsl = HSLColor.fromColor(colour);
    if (hsl.saturation < 0.15) {
      if (hsl.lightness > 0.85) return 'White';
      if (hsl.lightness < 0.15) return 'Black';
      return 'Grey';
    }
    final hue = hsl.hue;
    if (hue < 15 || hue >= 345) return 'Red';
    if (hue < 45) return hsl.lightness < 0.4 ? 'Brown' : 'Orange';
    if (hue < 65) return 'Yellow';
    if (hue < 170) return 'Green';
    if (hue < 200) return hsl.lightness > 0.6 ? 'Sky Blue' : 'Teal';
    if (hue < 260) return 'Blue';
    if (hue < 290) return 'Purple';
    if (hue < 330) return 'Pink';
    return 'Red';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
