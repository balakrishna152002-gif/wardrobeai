import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../models/outfit_history.dart';
import '../models/wardrobe_category.dart';
import '../services/outfit_generator.dart';
import '../widgets/outfit_slot_card.dart';

class OutfitGeneratorScreen extends StatefulWidget {
  final ClothingItem? anchor;

  const OutfitGeneratorScreen({super.key, this.anchor});

  @override
  State<OutfitGeneratorScreen> createState() => _OutfitGeneratorScreenState();
}

class _OutfitGeneratorScreenState extends State<OutfitGeneratorScreen> {
  static const _genderPrefKey = 'profile_gender';

  Occasion _occasion = Occasion.casual;
  ClothingGender _gender = ClothingGender.women;
  GeneratedOutfit? _outfit;
  bool _loading = false;
  String? _error;
  bool _savedThisOutfit = false;
  bool _loggedWornThisOutfit = false;
  int? _persistedOutfitId;

  @override
  void initState() {
    super.initState();
    if (widget.anchor != null && widget.anchor!.gender != ClothingGender.unisex) {
      _gender = widget.anchor!.gender;
    } else {
      _loadDefaultGender();
    }
    if (widget.anchor != null) {
      _generate();
    }
  }

  Future<void> _loadDefaultGender() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_genderPrefKey);
    if (saved == null || !mounted) return;
    final match = ClothingGender.values.where((g) => g.name == saved);
    if (match.isEmpty || match.first == ClothingGender.unisex) return;
    setState(() => _gender = match.first);
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final outfit = await OutfitGeneratorService.generateSmart(
        _occasion,
        _gender,
        anchor: widget.anchor,
      );
      setState(() {
        _outfit = outfit;
        _savedThisOutfit = false;
        _loggedWornThisOutfit = false;
        _persistedOutfitId = null;
      });
    } on NotEnoughItemsException catch (e) {
      setState(() {
        _outfit = null;
        _error = e.message;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<int> _ensurePersisted({bool favourite = false}) async {
    final o = _outfit!;
    if (_persistedOutfitId != null) {
      if (favourite && !_savedThisOutfit) {
        await DatabaseHelper.instance.updateOutfit(Outfit(
          id: _persistedOutfitId,
          name: '${o.occasion.label} outfit',
          topId: o.top.id!,
          bottomId: o.bottom?.id,
          shoeId: o.shoe?.id,
          accessoryId: o.accessory?.id,
          occasion: o.occasion,
          favourite: true,
          dateCreated: DateTime.now(),
        ));
      }
      return _persistedOutfitId!;
    }
    final id = await DatabaseHelper.instance.insertOutfit(Outfit(
      name: '${o.occasion.label} outfit',
      topId: o.top.id!,
      bottomId: o.bottom?.id,
      shoeId: o.shoe?.id,
      accessoryId: o.accessory?.id,
      occasion: o.occasion,
      favourite: favourite,
      dateCreated: DateTime.now(),
    ));
    _persistedOutfitId = id;
    return id;
  }

  Future<void> _saveFavourite() async {
    if (_outfit == null) return;
    await _ensurePersisted(favourite: true);
    setState(() => _savedThisOutfit = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to favourite outfits')),
    );
  }

  Future<void> _markWorn() async {
    if (_outfit == null) return;
    final id = await _ensurePersisted();
    await DatabaseHelper.instance.insertHistoryEntry(
      OutfitHistoryEntry(outfitId: id, date: DateTime.now()),
    );
    setState(() => _loggedWornThisOutfit = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as worn today')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.anchor != null ? 'Match: ${widget.anchor!.colour} ${widget.anchor!.category.label}' : 'Generate Outfit'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.anchor == null) ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final g in [ClothingGender.women, ClothingGender.men])
                    ChoiceChip(
                      label: Text(g.label),
                      selected: _gender == g,
                      onSelected: (_) => setState(() => _gender = g),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              children: [
                for (final o in Occasion.values)
                  ChoiceChip(
                    label: Text(o.label),
                    selected: _occasion == o,
                    onSelected: (_) => setState(() => _occasion = o),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : _error != null
                        ? Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          )
                        : _outfit == null
                            ? Text(
                                'Tap "Generate Outfit" to get a suggestion',
                                style: Theme.of(context).textTheme.bodyMedium,
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  children: [
                                    _ScoreBadge(score: _outfit!.score),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 16,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 130,
                                          child: OutfitSlotCard(
                                              label: 'Top', item: _outfit!.top),
                                        ),
                                        if (_outfit!.bottom != null)
                                          SizedBox(
                                            width: 130,
                                            child: OutfitSlotCard(
                                                label: 'Bottom', item: _outfit!.bottom),
                                          ),
                                        if (_outfit!.shoe != null)
                                          SizedBox(
                                            width: 130,
                                            child: OutfitSlotCard(
                                                label: 'Shoes', item: _outfit!.shoe),
                                          ),
                                        if (_outfit!.accessory != null)
                                          SizedBox(
                                            width: 130,
                                            child: OutfitSlotCard(
                                                label: 'Accessory',
                                                item: _outfit!.accessory),
                                          ),
                                      ],
                                    ),
                                    if (_outfit!.isFromAi) ...[
                                      const SizedBox(height: 20),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.auto_awesome,
                                                size: 16,
                                                color: colorScheme.primary),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                _outfit!.aiReasoning!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _generate,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Generate Outfit'),
                  ),
                ),
                if (_outfit != null) ...[
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: _loggedWornThisOutfit ? null : _markWorn,
                    icon: Icon(
                      _loggedWornThisOutfit ? Icons.check_circle : Icons.check_circle_outline,
                    ),
                    tooltip: 'Mark as worn today',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _savedThisOutfit ? null : _saveFavourite,
                    icon: Icon(
                      _savedThisOutfit ? Icons.favorite : Icons.favorite_outline,
                    ),
                    tooltip: 'Save as favourite',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final int score;

  const _ScoreBadge({required this.score});

  Color _colourFor(ColorScheme scheme) {
    if (score >= 75) return scheme.primary;
    if (score >= 50) return scheme.secondary;
    return scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colour = _colourFor(colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 18, color: colour),
          const SizedBox(width: 6),
          Text(
            '$score/100 wearability',
            style: TextStyle(color: colour, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
