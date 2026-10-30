import 'dart:async';

import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../widgets/thumb.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _BulkAction { archive, unarchive, delete }

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Product> _products = [];
  List<Category> _categories = [];
  String? _categoryId;
  bool _showArchived = false;
  SortOption _sort = SortOption.newest;
  bool _listView = false;
  final Set<String> _selectedIds = {};
  bool _bulkActionRunning = false;
  bool _loading = true;
  String? _error;
  int _seq = 0; // ignore out-of-date results when typing fast

  bool get _filtering =>
      _searchCtrl.text.trim().isNotEmpty ||
      _categoryId != null ||
      _showArchived;

  String? get _selectedCategoryName {
    for (final category in _categories) {
      if (category.id == _categoryId) return category.name;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_seq;
    try {
      final results = await Future.wait<Object>([
        Repository.instance.list(
          query: _searchCtrl.text,
          categoryId: _categoryId,
          archived: _showArchived,
          sort: _sort,
        ),
        Repository.instance.categories(),
      ]);
      if (!mounted || seq != _seq) return;
      setState(() {
        _products = results[0] as List<Product>;
        _categories = results[1] as List<Category>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        _error = 'Could not load products.\n$e';
      });
    }
  }

  void _onSearchChanged(String _) {
    setState(() {
      _selectedIds.clear();
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _load);
  }

  Future<void> _pickCategory() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryPickerSheet(
        categories: _categories,
        selectedCategoryId: _categoryId,
      ),
    );

    if (result == null || !mounted) return;
    setState(() {
      _categoryId = result.isEmpty ? null : result;
      _selectedIds.clear();
    });
    _load();
  }

  Future<void> _openForm() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    _load();
  }

  Future<void> _openDetail(Product product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.id),
      ),
    );
    _load();
  }

  void _handleProductTap(Product product) {
    if (_selectedIds.isNotEmpty) {
      _toggleSelection(product);
    } else {
      _openDetail(product);
    }
  }

  void _toggleSelection(Product product) {
    setState(() {
      if (!_selectedIds.add(product.id)) _selectedIds.remove(product.id);
    });
  }

  Future<void> _performBulkAction(_BulkAction action) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty || _bulkActionRunning) return;

    if (action == _BulkAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Delete ${ids.length} product${ids.length == 1 ? '' : 's'}?',
          ),
          content: const Text(
            'This removes the selected products and their photos and videos. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _bulkActionRunning = true);
    try {
      if (action == _BulkAction.delete) {
        for (final id in ids) {
          await Repository.instance.delete(id);
        }
      } else {
        await Repository.instance.setActive(
          ids,
          action == _BulkAction.unarchive,
        );
      }
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _bulkActionRunning = false;
      });
      await _load();
      if (mounted) {
        final message = switch (action) {
          _BulkAction.archive =>
            'Archived ${ids.length} product${ids.length == 1 ? '' : 's'}.',
          _BulkAction.unarchive =>
            'Unarchived ${ids.length} product${ids.length == 1 ? '' : 's'}.',
          _BulkAction.delete =>
            'Deleted ${ids.length} product${ids.length == 1 ? '' : 's'}.',
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _bulkActionRunning = false;
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete the selected action: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _categoryId == null && !_showArchived,
                      onSelected: (_) {
                        setState(() {
                          _categoryId = null;
                          _showArchived = false;
                          _selectedIds.clear();
                        });
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickCategory,
                        icon: const Icon(Icons.category_outlined, size: 18),
                        label: Text(
                          _selectedCategoryName ?? 'Category',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _categoryId != null
                              ? Theme.of(context).colorScheme.secondaryContainer
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Archived'),
                      selected: _showArchived,
                      onSelected: (selected) {
                        setState(() {
                          _showArchived = selected;
                          _selectedIds.clear();
                        });
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _selectedIds.isEmpty
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            )
          : null,
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<SortOption>(
      tooltip: 'Sort',
      initialValue: _sort,
      onSelected: (value) {
        if (value == _sort) return;
        setState(() => _sort = value);
        _load();
      },
      itemBuilder: (context) => [
        for (final option in SortOption.values)
          CheckedPopupMenuItem<SortOption>(
            value: option,
            checked: option == _sort,
            child: Text(option.label),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 20),
            const SizedBox(width: 4),
            Text(_sort.label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showArchived
                    ? Icons.archive_outlined
                    : _filtering
                    ? Icons.search_off
                    : Icons.inventory_2_outlined,
                size: 56,
                color: Colors.black38,
              ),
              const SizedBox(height: 12),
              Text(
                _showArchived
                    ? 'No archived products.'
                    : _filtering
                    ? 'No products match your search.'
                    : 'No products yet.\nTap "Add product" to save your first one.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectedIds.isNotEmpty
                      ? '${_selectedIds.length} selected'
                      : _filtering
                      ? '${_products.length} result${_products.length == 1 ? '' : 's'}'
                      : (_sort == SortOption.newest
                            ? 'Recently added'
                            : 'All products'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_selectedIds.isNotEmpty)
                PopupMenuButton<_BulkAction>(
                  tooltip: 'Actions',
                  enabled: !_bulkActionRunning,
                  icon: const Icon(Icons.more_vert),
                  onSelected: _performBulkAction,
                  itemBuilder: (context) => [
                    if (_showArchived)
                      const PopupMenuItem(
                        value: _BulkAction.unarchive,
                        child: Text('Unarchive'),
                      )
                    else
                      const PopupMenuItem(
                        value: _BulkAction.archive,
                        child: Text('Archive'),
                      ),
                    const PopupMenuItem(
                      value: _BulkAction.delete,
                      child: Text('Delete'),
                    ),
                  ],
                ),
              IconButton(
                tooltip: _listView
                    ? 'Switch to grid view'
                    : 'Switch to list view',
                icon: Icon(_listView ? Icons.grid_view : Icons.view_list),
                onPressed: () => setState(() => _listView = !_listView),
              ),
              _buildSortMenu(),
            ],
          ),
        ),
        Expanded(
          child: _listView
              ? ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: _products.length,
                  itemBuilder: (context, i) {
                    final product = _products[i];
                    return _ProductListTile(
                      product: product,
                      selected: _selectedIds.contains(product.id),
                      selectionMode: _selectedIds.isNotEmpty,
                      onTap: () => _handleProductTap(product),
                      onLongPress: () => _toggleSelection(product),
                    );
                  },
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, i) {
                    final product = _products[i];
                    return _ProductCard(
                      product: product,
                      selected: _selectedIds.contains(product.id),
                      selectionMode: _selectedIds.isNotEmpty,
                      onTap: () => _handleProductTap(product),
                      onLongPress: () => _toggleSelection(product),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<Category> categories;
  final String? selectedCategoryId;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedCategoryId,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = _searchController.text.trim().toLowerCase();
    final categories =
        widget.categories
            .where((category) => category.name.toLowerCase().contains(search))
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Choose category',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search categories',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: categories.isEmpty && search.isNotEmpty
                  ? const Center(child: Text('No categories found.'))
                  : ListView(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.apps),
                          title: const Text('All categories'),
                          trailing: widget.selectedCategoryId == null
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.pop(context, ''),
                        ),
                        for (final category in categories)
                          ListTile(
                            title: Text(category.name),
                            trailing: widget.selectedCategoryId == category.id
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.pop(context, category.id),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ProductCard({
    required this.product,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: selected ? theme.colorScheme.secondaryContainer : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: ProductThumb(relativePath: product.thumbPath)),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (product.plu.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'PLU: ${product.plu}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (product.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (product.price != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          formatRupiah(product.price!),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (selectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? theme.colorScheme.primary : Colors.white,
                  shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductListTile extends StatelessWidget {
  final Product product;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ProductListTile({
    required this.product,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ProductThumb(relativePath: product.thumbPath),
              if (selectionMode)
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? theme.colorScheme.primary : Colors.white,
                    shadows: const [
                      Shadow(blurRadius: 4, color: Colors.black54),
                    ],
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        selected: selected,
        selectedTileColor: theme.colorScheme.secondaryContainer,
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.plu.isNotEmpty)
                Text('PLU: ${product.plu}', style: theme.textTheme.bodySmall),
              if (product.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Category: ${product.categoryName ?? 'No category'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (product.price != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    formatRupiah(product.price!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Created ${formatDate(product.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
