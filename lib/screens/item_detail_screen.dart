import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/wardrobe_category.dart';
import '../services/image_store.dart';
import 'outfit_generator_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final ClothingItem item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late TextEditingController _colourCtrl;
  late TextEditingController _patternCtrl;
  late TextEditingController _brandCtrl;
  late ClothingSeason _season;
  late ClothingStyle _style;
  late ClothingGender _gender;
  late bool _favourite;
  late bool _archived;
  bool _saving = false;

  List<Map<String, Object?>> _extraPhotos = [];

  @override
  void initState() {
    super.initState();
    _colourCtrl = TextEditingController(text: widget.item.colour);
    _patternCtrl = TextEditingController(text: widget.item.pattern);
    _brandCtrl = TextEditingController(text: widget.item.brand);
    _season = widget.item.season;
    _style = widget.item.style;
    _gender = widget.item.gender;
    _favourite = widget.item.favourite;
    _archived = widget.item.archived;
    _loadExtraPhotos();
  }

  Future<void> _loadExtraPhotos() async {
    final rows = await DatabaseHelper.instance.getExtraPhotoRows(widget.item.id!);
    if (!mounted) return;
    setState(() => _extraPhotos = rows);
  }

  @override
  void dispose() {
    _colourCtrl.dispose();
    _patternCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.item.copyWith(
      colour: _colourCtrl.text.trim(),
      pattern: _patternCtrl.text.trim(),
      brand: _brandCtrl.text.trim(),
      season: _season,
      style: _style,
      gender: _gender,
      favourite: _favourite,
      archived: _archived,
    );
    await DatabaseHelper.instance.updateClothingItem(updated);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This removes it from your wardrobe permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteClothingItem(widget.item.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addExtraPhoto() async {
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
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return;

    final persisted = await ImageStore.persist(File(picked.path));
    await DatabaseHelper.instance.addExtraPhoto(widget.item.id!, persisted.path);
    await _loadExtraPhotos();
  }

  Future<void> _deleteExtraPhoto(int rowId) async {
    await DatabaseHelper.instance.deleteExtraPhoto(rowId);
    await _loadExtraPhotos();
  }

  Future<void> _matchFromThisItem() async {
    if (widget.item.category.outfitSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Matching from this category isn't supported yet.")),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OutfitGeneratorScreen(anchor: widget.item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.category.label),
        actions: [
          IconButton(
            icon: Icon(_archived ? Icons.unarchive_outlined : Icons.archive_outlined),
            tooltip: _archived ? 'Unarchive' : 'Archive',
            onPressed: () => setState(() => _archived = !_archived),
          ),
          IconButton(
            icon: Icon(
              _favourite ? Icons.favorite : Icons.favorite_outline,
              color: _favourite ? Colors.redAccent : null,
            ),
            onPressed: () => setState(() => _favourite = !_favourite),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_archived)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, size: 16, color: colorScheme.onSecondaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Archived - hidden from your wardrobe and outfit generation.',
                        style: TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.file(
                File(widget.item.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final row in _extraPhotos)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(row['image_path'] as String),
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              width: 72,
                              height: 72,
                              color: colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: GestureDetector(
                            onTap: () => _deleteExtraPhoto(row['id'] as int),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                GestureDetector(
                  onTap: _addExtraPhoto,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outline),
                    ),
                    child: Icon(Icons.add_a_photo_outlined, color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _matchFromThisItem,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Match an outfit from this item'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _colourCtrl,
            decoration: const InputDecoration(labelText: 'Colour'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _patternCtrl,
            decoration: const InputDecoration(labelText: 'Pattern'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _brandCtrl,
            decoration: const InputDecoration(labelText: 'Brand (optional)'),
          ),
          const SizedBox(height: 16),
          Text('Season', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ClothingSeason.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _season == s,
                  onSelected: (_) => setState(() => _season = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Style', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ClothingStyle.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _style == s,
                  onSelected: (_) => setState(() => _style = s),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Gender', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final g in ClothingGender.values)
                ChoiceChip(
                  label: Text(g.label),
                  selected: _gender == g,
                  onSelected: (_) => setState(() => _gender = g),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
