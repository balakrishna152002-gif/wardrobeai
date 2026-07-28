import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/wardrobe_category.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _nameKey = 'profile_name';
  String _name = 'You';
  bool _editing = false;
  final _nameCtrl = TextEditingController();

  late Future<List<ClothingItem>> _itemsFuture;
  late Future<int> _favouriteOutfitCountFuture;

  @override
  void initState() {
    super.initState();
    _loadName();
    _itemsFuture = DatabaseHelper.instance.getAllClothingItems();
    _favouriteOutfitCountFuture =
        DatabaseHelper.instance.getFavouriteOutfits().then((l) => l.length);
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_nameKey);
    if (stored != null && mounted) {
      setState(() => _name = stored);
    }
  }

  Future<void> _saveName() async {
    final prefs = await SharedPreferences.getInstance();
    final newName = _nameCtrl.text.trim();
    if (newName.isNotEmpty) {
      await prefs.setString(_nameKey, newName);
      setState(() => _name = newName);
    }
    setState(() => _editing = false);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 42,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(Icons.person, size: 42, color: colorScheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _editing
                ? SizedBox(
                    width: 220,
                    child: TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      onSubmitted: (_) => _saveName(),
                      decoration: InputDecoration(
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: _saveName,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () {
                      _nameCtrl.text = _name;
                      setState(() => _editing = true);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_name, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(width: 6),
                        const Icon(Icons.edit, size: 16),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 32),
          Text('Wardrobe stats', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          FutureBuilder<List<ClothingItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              final items = snapshot.data ?? [];
              final byCategory = <WardrobeCategory, int>{};
              for (final item in items) {
                byCategory[item.category] = (byCategory[item.category] ?? 0) + 1;
              }
              return Column(
                children: [
                  Row(
                    children: [
                      _StatCard(label: 'Total items', value: '${items.length}'),
                      const SizedBox(width: 12),
                      FutureBuilder<int>(
                        future: _favouriteOutfitCountFuture,
                        builder: (context, s) => _StatCard(
                          label: 'Saved outfits',
                          value: '${s.data ?? 0}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final entry in byCategory.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text(entry.key.emoji),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.key.label)),
                          Text('${entry.value}'),
                        ],
                      ),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
