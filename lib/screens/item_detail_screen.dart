import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../models/wardrobe_category.dart';

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
  bool _saving = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.category.label),
        actions: [
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.file(
                File(widget.item.imagePath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
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
