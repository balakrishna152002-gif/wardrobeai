import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/clothing_item.dart';
import '../widgets/clothing_thumb.dart';
import 'item_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<ClothingItem> _results = [];
  bool _searched = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    final results = await DatabaseHelper.instance.searchClothingItems(query.trim());
    if (!mounted) return;
    setState(() {
      _results = results;
      _searched = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by colour, pattern, brand...',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
          onChanged: _search,
        ),
      ),
      body: !_searched
          ? const Center(child: Text('Try "Black" or "Nike"'))
          : _results.isEmpty
              ? const Center(child: Text('No matches found'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final item = _results[i];
                    return ClothingThumb(
                      item: item,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ItemDetailScreen(item: item),
                          ),
                        );
                        await _search(_controller.text);
                      },
                    );
                  },
                ),
    );
  }
}
