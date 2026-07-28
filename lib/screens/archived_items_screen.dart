import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../widgets/clothing_thumb.dart';
import 'item_detail_screen.dart';

class ArchivedItemsScreen extends StatefulWidget {
  const ArchivedItemsScreen({super.key});

  @override
  State<ArchivedItemsScreen> createState() => _ArchivedItemsScreenState();
}

class _ArchivedItemsScreenState extends State<ArchivedItemsScreen> {
  late Future<List<ClothingItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _itemsFuture = DatabaseHelper.instance.getArchivedClothingItems();
  }

  Future<void> _reload() async {
    setState(_load);
    await _itemsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archived')),
      body: FutureBuilder<List<ClothingItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No archived items'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return ClothingThumb(
                item: item,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ItemDetailScreen(item: item),
                    ),
                  );
                  await _reload();
                },
              );
            },
          );
        },
      ),
    );
  }
}
