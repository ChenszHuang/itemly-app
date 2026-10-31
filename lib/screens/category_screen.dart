import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../widgets/category_name_dialog.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List<Category> _categories = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  String? _error;

  bool get _hasSelection => _selectedIds.isNotEmpty;
  bool get _allSelected =>
      _categories.isNotEmpty && _selectedIds.length == _categories.length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await Repository.instance.categories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load categories.\n$error';
      });
    }
  }

  Future<void> _addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const CategoryNameDialog(),
    );
    if (name == null) return;

    try {
      await Repository.instance.addCategory(name);
      await _load();
    } catch (error) {
      _showError('Could not add category: $error');
    }
  }

  Future<void> _editCategory(Category category) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => CategoryNameDialog(initialName: category.name),
    );
    if (name == null) return;

    try {
      await Repository.instance.updateCategory(category.id, name);
      await _load();
    } catch (error) {
      _showError('Could not update category: $error');
    }
  }

  Future<void> _deleteSelectedCategories() async {
    final selected = _categories
        .where((category) => _selectedIds.contains(category.id))
        .toList();
    await _deleteCategories(selected);
  }

  Future<void> _deleteCategories(List<Category> categories) async {
    if (categories.isEmpty) return;
    final categoryNames = categories.map((category) => category.name).toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete ${categories.length == 1 ? 'category' : '${categories.length} categories'}?',
        ),
        content: Text(
          categories.length == 1
              ? 'Products in "${categoryNames.first}" will no longer have a category.'
              : 'Products in these categories will no longer have a category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Repository.instance.deleteCategories(
        categories.map((category) => category.id).toList(),
      );
      if (!mounted) return;
      setState(_selectedIds.clear);
      await _load();
    } catch (error) {
      _showError('Could not delete categories: $error');
    }
  }

  void _toggleSelection(String categoryId) {
    setState(() {
      if (!_selectedIds.add(categoryId)) {
        _selectedIds.remove(categoryId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_categories.map((category) => category.id));
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() => _loading = true);
                        _load();
                      },
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : _categories.isEmpty
          ? const Center(
              child: Text('No categories yet. Add one to organize products.'),
            )
          : Column(
              children: [
                if (_hasSelection)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedIds.length} selected',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _toggleSelectAll,
                          icon: Icon(
                            _allSelected
                                ? Icons.deselect_outlined
                                : Icons.select_all,
                          ),
                          label: Text(
                            _allSelected ? 'Deselect all' : 'Select all',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete selected',
                          onPressed: _deleteSelectedCategories,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final selected = _selectedIds.contains(category.id);
                      return Card(
                        color: selected
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                        child: ListTile(
                          leading: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.category_outlined,
                          ),
                          title: Text(category.name),
                          onTap: _hasSelection
                              ? () => _toggleSelection(category.id)
                              : () => _editCategory(category),
                          onLongPress: () => _toggleSelection(category.id),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCategory,
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
    );
  }
}
