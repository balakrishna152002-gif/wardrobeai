import 'dart:io';

import 'package:flutter/material.dart';

import '../models/clothing_item.dart';

class OutfitSlotCard extends StatelessWidget {
  final String label;
  final ClothingItem? item;

  const OutfitSlotCard({super.key, required this.label, required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: item == null
                ? Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.block, color: colorScheme.onSurfaceVariant),
                  )
                : Image.file(
                    File(item!.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        if (item != null)
          Text(
            item!.colour,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}
