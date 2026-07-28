import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/wardrobe_category.dart';
import '../widgets/category_tile.dart';
import 'category_gallery_screen.dart';
import 'search_screen.dart';
import 'upload_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  late Future<List<ClothingItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _itemsFuture = DatabaseHelper.instance.getAllClothingItems();
  }

  Future<void> _reload() async {
    setState(_refresh);
    await _itemsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wardrobe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<ClothingItem>>(
          future: _itemsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snapshot.data!;
            final counts = <WardrobeCategory, int>{
              for (final c in WardrobeCategory.values) c: 0,
            };
            for (final item in items) {
              counts[item.category] = (counts[item.category] ?? 0) + 1;
            }
            return GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                for (final category in WardrobeCategory.values)
                  CategoryTile(
                    category: category,
                    count: counts[category] ?? 0,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoryGalleryScreen(category: category),
                        ),
                      );
                      await _reload();
                    },
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UploadScreen()),
          );
          await _reload();
        },
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Add item'),
      ),
    );
  }
}
