import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/wardrobe_category.dart';
import '../widgets/clothing_thumb.dart';
import 'item_detail_screen.dart';
import 'upload_screen.dart';

class CategoryGalleryScreen extends StatefulWidget {
  final WardrobeCategory category;

  const CategoryGalleryScreen({super.key, required this.category});

  @override
  State<CategoryGalleryScreen> createState() => _CategoryGalleryScreenState();
}

class _CategoryGalleryScreenState extends State<CategoryGalleryScreen> {
  late Future<List<ClothingItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _itemsFuture =
        DatabaseHelper.instance.getClothingItemsByCategory(widget.category.dbKey);
  }

  Future<void> _reload() async {
    setState(_load);
    await _itemsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.emoji}  ${widget.category.label}'),
      ),
      body: FutureBuilder<List<ClothingItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No ${widget.category.label.toLowerCase()} yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap + to add your first item'),
                ],
              ),
            );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UploadScreen(initialCategory: widget.category),
            ),
          );
          await _reload();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
