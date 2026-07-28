import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/wardrobe_category.dart';
import '../services/image_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _nameKey = 'profile_name';
  static const _photoKey = 'profile_photo_path';
  static const _genderKey = 'profile_gender';
  static const _styleKey = 'profile_style';

  String _name = 'You';
  String? _photoPath;
  ClothingGender? _gender;
  ClothingStyle? _style;
  bool _editingName = false;
  final _nameCtrl = TextEditingController();

  late Future<List<ClothingItem>> _itemsFuture;
  late Future<int> _favouriteOutfitCountFuture;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _itemsFuture = DatabaseHelper.instance.getAllClothingItems();
    _favouriteOutfitCountFuture =
        DatabaseHelper.instance.getFavouriteOutfits().then((l) => l.length);
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _name = prefs.getString(_nameKey) ?? _name;
      _photoPath = prefs.getString(_photoKey);
      final genderName = prefs.getString(_genderKey);
      _gender = ClothingGender.values
          .where((g) => g.name == genderName)
          .cast<ClothingGender?>()
          .firstOrNull;
      final styleName = prefs.getString(_styleKey);
      _style = ClothingStyle.values
          .where((s) => s.name == styleName)
          .cast<ClothingStyle?>()
          .firstOrNull;
    });
  }

  Future<void> _saveName() async {
    final prefs = await SharedPreferences.getInstance();
    final newName = _nameCtrl.text.trim();
    if (newName.isNotEmpty) {
      await prefs.setString(_nameKey, newName);
      setState(() => _name = newName);
    }
    setState(() => _editingName = false);
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null || !mounted) return;

    final persisted = await ImageStore.persist(File(picked.path));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_photoKey, persisted.path);
    if (!mounted) return;
    setState(() => _photoPath = persisted.path);
  }

  Future<void> _setGender(ClothingGender gender) async {
    final prefs = await SharedPreferences.getInstance();
    final next = _gender == gender ? null : gender;
    if (next == null) {
      await prefs.remove(_genderKey);
    } else {
      await prefs.setString(_genderKey, next.name);
    }
    setState(() => _gender = next);
  }

  Future<void> _setStyle(ClothingStyle style) async {
    final prefs = await SharedPreferences.getInstance();
    final next = _style == style ? null : style;
    if (next == null) {
      await prefs.remove(_styleKey);
    } else {
      await prefs.setString(_styleKey, next.name);
    }
    setState(() => _style = next);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage:
                        _photoPath != null ? FileImage(File(_photoPath!)) : null,
                    child: _photoPath == null
                        ? Icon(Icons.person, size: 44, color: colorScheme.onPrimaryContainer)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.surface, width: 2),
                      ),
                      child: Icon(Icons.camera_alt, size: 16, color: colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _editingName
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
                      setState(() => _editingName = true);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_name, style: textTheme.headlineSmall),
                        const SizedBox(width: 6),
                        Icon(Icons.edit, size: 16, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 32),
          Text('Preferences', style: textTheme.labelLarge),
          const SizedBox(height: 12),
          Text('Gender', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final g in ClothingGender.values)
                ChoiceChip(
                  label: Text(g.label),
                  selected: _gender == g,
                  onSelected: (_) => _setGender(g),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Everyday style', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ClothingStyle.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _style == s,
                  onSelected: (_) => _setStyle(s),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Text('Wardrobe stats', style: textTheme.labelLarge),
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
                  if (byCategory.isEmpty)
                    Text(
                      'Add items to your wardrobe to see a breakdown here.',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    )
                  else
                    for (final entry in byCategory.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Text(entry.key.emoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 10),
                            Expanded(child: Text(entry.key.label, style: textTheme.bodyMedium)),
                            Text('${entry.value}', style: textTheme.bodyMedium),
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            children: [
              Text(value, style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
