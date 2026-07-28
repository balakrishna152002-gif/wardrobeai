import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../models/outfit_history.dart';
import '../widgets/clothing_thumb.dart';
import '../widgets/outfit_slot_card.dart';

class _HistoryRow {
  final OutfitHistoryEntry entry;
  final Outfit outfit;
  const _HistoryRow(this.entry, this.outfit);
}

class OutfitHistoryScreen extends StatefulWidget {
  const OutfitHistoryScreen({super.key});

  @override
  State<OutfitHistoryScreen> createState() => _OutfitHistoryScreenState();
}

class _OutfitHistoryScreenState extends State<OutfitHistoryScreen> {
  late Future<List<_HistoryRow>> _rowsFuture;
  late Future<_WearStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _rowsFuture = _loadRows();
    _statsFuture = _loadStats();
  }

  Future<List<_HistoryRow>> _loadRows() async {
    final entries = await DatabaseHelper.instance.getHistory();
    final rows = <_HistoryRow>[];
    for (final entry in entries) {
      final outfit = await DatabaseHelper.instance.getOutfitById(entry.outfitId);
      if (outfit != null) rows.add(_HistoryRow(entry, outfit));
    }
    return rows;
  }

  Future<_WearStats> _loadStats() async {
    final counts = await DatabaseHelper.instance.getItemWearCounts();
    final items = await DatabaseHelper.instance.getAllClothingItems();
    final worn = items.where((i) => counts.containsKey(i.id)).toList()
      ..sort((a, b) => counts[b.id]!.compareTo(counts[a.id]!));
    final neverWorn = items.where((i) => !counts.containsKey(i.id)).toList();
    return _WearStats(counts: counts, mostWorn: worn.take(6).toList(), neverWorn: neverWorn.take(6).toList());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Outfit History')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Wear stats', style: textTheme.labelLarge),
          const SizedBox(height: 12),
          FutureBuilder<_WearStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
              }
              final stats = snapshot.data!;
              if (stats.counts.isEmpty) {
                return Text(
                  'Mark an outfit as worn to start tracking stats.',
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats.mostWorn.isNotEmpty) ...[
                    Text('Most worn', style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                    const SizedBox(height: 8),
                    _ItemStrip(items: stats.mostWorn, counts: stats.counts),
                    const SizedBox(height: 16),
                  ],
                  if (stats.neverWorn.isNotEmpty) ...[
                    Text('Never worn', style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
                    const SizedBox(height: 8),
                    _ItemStrip(items: stats.neverWorn, counts: stats.counts),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text('Recently worn', style: textTheme.labelLarge),
          const SizedBox(height: 12),
          FutureBuilder<List<_HistoryRow>>(
            future: _rowsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snapshot.data!;
              if (rows.isEmpty) {
                return Text(
                  'No outfits marked as worn yet.',
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _HistoryCard(row: row),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WearStats {
  final Map<int, int> counts;
  final List<ClothingItem> mostWorn;
  final List<ClothingItem> neverWorn;

  const _WearStats({required this.counts, required this.mostWorn, required this.neverWorn});
}

class _ItemStrip extends StatelessWidget {
  final List<ClothingItem> items;
  final Map<int, int> counts;

  const _ItemStrip({required this.items, required this.counts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          final count = counts[item.id];
          return SizedBox(
            width: 70,
            child: Stack(
              children: [
                SizedBox(height: 70, width: 70, child: ClothingThumb(item: item)),
                if (count != null)
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${count}x',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final _HistoryRow row;

  const _HistoryCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final outfit = row.outfit;
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
                        DateFormat.yMMMd().format(row.entry.date),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(label: Text(outfit.occasion.label)),
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
                        child: OutfitSlotCard(label: 'Bottom', item: items[outfit.bottomId]),
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
                        child: OutfitSlotCard(label: 'Accessory', item: items[outfit.accessoryId]),
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
