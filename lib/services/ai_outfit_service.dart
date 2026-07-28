import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../models/wardrobe_category.dart';

class AiOutfitSuggestion {
  final int topId;
  final int? bottomId;
  final int? shoeId;
  final int? accessoryId;
  final String reasoning;
  final int? score;

  const AiOutfitSuggestion({
    required this.topId,
    this.bottomId,
    this.shoeId,
    this.accessoryId,
    required this.reasoning,
    this.score,
  });
}

/// Calls the WardrobeAI Cloudflare Worker, which holds the Groq API key
/// server-side, to get a styled outfit suggestion with reasoning. Falls
/// back to null on any failure (offline, endpoint down, bad response) so
/// callers can fall back to the local colour-harmony heuristic.
class AiOutfitService {
  static const _endpoint = 'https://wardrobeai-outfit.balakrishna152002.workers.dev';
  static const _appKey = 'f82752d90f77c71190a5c1424c4d26984408df4557be70fb';

  static Future<AiOutfitSuggestion?> suggest({
    required List<ClothingItem> wardrobe,
    required Occasion occasion,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-App-Key': _appKey,
            },
            body: jsonEncode({
              'occasion': occasion.label,
              'items': wardrobe
                  .map((i) => {
                        'id': i.id,
                        'category': i.category.dbKey,
                        'colour': i.colour,
                        'pattern': i.pattern,
                        'style': i.style.name,
                        'season': i.season.name,
                      })
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['topId'] == null) return null;

      return AiOutfitSuggestion(
        topId: (data['topId'] as num).toInt(),
        bottomId: (data['bottomId'] as num?)?.toInt(),
        shoeId: (data['shoeId'] as num?)?.toInt(),
        accessoryId: (data['accessoryId'] as num?)?.toInt(),
        reasoning: data['reasoning'] as String? ?? '',
        score: (data['score'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }
}
