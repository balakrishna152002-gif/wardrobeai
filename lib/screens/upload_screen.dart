import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/wardrobe_category.dart';
import '../services/attribute_detector.dart';
import '../services/image_store.dart';

class UploadScreen extends StatefulWidget {
  final WardrobeCategory? initialCategory;

  const UploadScreen({super.key, this.initialCategory});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  WardrobeCategory? _category;
  File? _imageFile;
  bool _detecting = false;
  bool _saving = false;

  final _colourCtrl = TextEditingController();
  final _patternCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  String? _sleeveLength;
  ClothingSeason? _season;
  ClothingStyle? _style;
  ClothingGender _gender = ClothingGender.unisex;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _colourCtrl.dispose();
    _patternCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() {
      _imageFile = file;
      _detecting = true;
    });
    final attrs = await AttributeDetector.detect(imageFile: file);
    if (!mounted) return;
    setState(() {
      if (attrs.colour != null) _colourCtrl.text = attrs.colour!;
      if (attrs.pattern != null) _patternCtrl.text = attrs.pattern!;
      if (attrs.season != null) _season = attrs.season;
      if (attrs.style != null) _style = attrs.style;
      // Only apply an AI category guess if the user hasn't already picked
      // one - never override an explicit choice or the gallery's context.
      if (_category == null && attrs.category != null) _category = attrs.category;
      _detecting = false;
    });
  }

  Future<void> _save() async {
    if (_imageFile == null) return;
    setState(() => _saving = true);
    try {
      final persisted = await ImageStore.persist(_imageFile!);
      final item = ClothingItem(
        category: _category!,
        imagePath: persisted.path,
        colour: _colourCtrl.text.trim().isEmpty ? 'Unknown' : _colourCtrl.text.trim(),
        pattern: _patternCtrl.text.trim().isEmpty ? 'Solid' : _patternCtrl.text.trim(),
        sleeveLength: _category!.hasSleeves ? (_sleeveLength ?? 'Short') : null,
        season: _season ?? ClothingSeason.allSeason,
        style: _style ?? ClothingStyle.casual,
        gender: _gender,
        brand: _brandCtrl.text.trim(),
        dateAdded: DateTime.now(),
      );
      await DatabaseHelper.instance.insertClothingItem(item);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Add item')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () => _showImageSourceSheet(context),
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _imageFile == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 40, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('Tap to add a photo',
                            style: TextStyle(color: colorScheme.onSurfaceVariant)),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Category', style: Theme.of(context).textTheme.labelLarge),
              if (_category == null) ...[
                const SizedBox(width: 8),
                Text(
                  '(required)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in WardrobeCategory.values)
                ChoiceChip(
                  label: Text('${c.emoji} ${c.label}'),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          if (_detecting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Detecting colour and style...'),
                ],
              ),
            ),
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
          if (_category?.hasSleeves ?? false) ...[
            const SizedBox(height: 16),
            Text('Sleeve length', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final s in ['Sleeveless', 'Short', 'Long'])
                  ChoiceChip(
                    label: Text(s),
                    selected: _sleeveLength == s,
                    onSelected: (_) => setState(() => _sleeveLength = s),
                  ),
              ],
            ),
          ],
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
          const SizedBox(height: 28),
          FilledButton(
            onPressed:
                (_imageFile == null || _category == null || _saving) ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save to wardrobe'),
          ),
        ],
      ),
    );
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
