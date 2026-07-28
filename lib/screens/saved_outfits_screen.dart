import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../widgets/outfit_slot_card.dart';
import 'outfit_history_screen.dart';

class SavedOutfitsScreen extends StatefulWidget {
  const SavedOutfitsScreen({super.key});

  @override
  State<SavedOutfitsScreen> createState() => _SavedOutfitsScreenState();
}

class _SavedOutfitsScreenState extends State<SavedOutfitsScreen> {
  late Future<List<Outfit>> _outfitsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _outfitsFuture = DatabaseHelper.instance.getFavouriteOutfits();
  }

  Future<void> _reload() async {
    setState(_load);
    await _outfitsFuture;
  }

  Future<void> _delete(Outfit outfit) async {
    await DatabaseHelper.instance.deleteOutfit(outfit.id!);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Outfits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Outfit history',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OutfitHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Outfit>>(
          future: _outfitsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final outfits = snapshot.data!;
            if (outfits.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: const Center(
                      child: Text('No favourite outfits yet'),
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: outfits.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) => _OutfitCard(
                outfit: outfits[i],
                onDelete: () => _delete(outfits[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OutfitCard extends StatelessWidget {
  final Outfit outfit;
  final VoidCallback onDelete;

  const _OutfitCard({required this.outfit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final ids = [
      outfit.topId,
      if (outfit.bottomId != null) outfit.bottomId!,
      if (outfit.shoeId != null) outfit.shoeId!,
      if (outfit.accessoryId != null) outfit.accessoryId!,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<List<ClothingItem>>(
          future: DatabaseHelper.instance.getClothingItemsByIds(ids),
          builder: (context, snapshot) {
            final items = {for (final i in snapshot.data ?? []) i.id: i};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        outfit.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(label: Text(outfit.occasion.label)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: OutfitSlotCard(label: 'Top', item: items[outfit.topId]),
                    ),
                    const SizedBox(width: 10),
                    if (outfit.bottomId != null)
                      SizedBox(
                        width: 90,
                        child: OutfitSlotCard(
                            label: 'Bottom', item: items[outfit.bottomId]),
                      ),
                    const SizedBox(width: 10),
                    if (outfit.shoeId != null)
                      SizedBox(
                        width: 90,
                        child: OutfitSlotCard(label: 'Shoes', item: items[outfit.shoeId]),
                      ),
                    const SizedBox(width: 10),
                    if (outfit.accessoryId != null)
                      SizedBox(
                        width: 90,
                        child: OutfitSlotCard(
                            label: 'Accessory', item: items[outfit.accessoryId]),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
