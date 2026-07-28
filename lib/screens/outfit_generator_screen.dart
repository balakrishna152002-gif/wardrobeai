import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/outfit.dart';
import '../models/outfit_history.dart';
import '../services/outfit_generator.dart';
import '../widgets/outfit_slot_card.dart';

class OutfitGeneratorScreen extends StatefulWidget {
  const OutfitGeneratorScreen({super.key});

  @override
  State<OutfitGeneratorScreen> createState() => _OutfitGeneratorScreenState();
}

class _OutfitGeneratorScreenState extends State<OutfitGeneratorScreen> {
  Occasion _occasion = Occasion.casual;
  GeneratedOutfit? _outfit;
  bool _loading = false;
  String? _error;
  bool _savedThisOutfit = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final outfit = await OutfitGeneratorService.generateSmart(_occasion);
      setState(() {
        _outfit = outfit;
        _savedThisOutfit = false;
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

  Future<void> _saveFavourite() async {
    final o = _outfit;
    if (o == null) return;
    final outfit = Outfit(
      name: '${o.occasion.label} outfit',
      topId: o.top.id!,
      bottomId: o.bottom?.id,
      shoeId: o.shoe?.id,
      accessoryId: o.accessory?.id,
      occasion: o.occasion,
      favourite: true,
      dateCreated: DateTime.now(),
    );
    final id = await DatabaseHelper.instance.insertOutfit(outfit);
    await DatabaseHelper.instance.insertHistoryEntry(
      OutfitHistoryEntry(outfitId: id, date: DateTime.now()),
    );
    setState(() => _savedThisOutfit = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to favourite outfits')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate Outfit')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                                                color: Theme.of(context).colorScheme.primary),
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
