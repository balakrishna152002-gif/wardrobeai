import 'dart:io';

import 'package:flutter/material.dart';

import '../models/clothing_item.dart';

class ClothingThumb extends StatelessWidget {
  final ClothingItem item;
  final VoidCallback? onTap;

  const ClothingThumb({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(item.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
            if (item.favourite)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.favorite, color: Colors.redAccent, size: 20),
              ),
            if (item.gender != ClothingGender.unisex)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.gender == ClothingGender.men ? 'M' : 'W',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
