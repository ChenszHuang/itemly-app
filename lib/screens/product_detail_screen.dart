import 'dart:io';

import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../db/app_db.dart';
import '../models/models.dart';
import '../utils/format.dart';
import 'media_viewer.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final product = await Repository.instance.get(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _loading = false;
        _error = product == null ? 'This product no longer exists.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load product.\n$e';
      });
    }
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(productId: widget.productId),
      ),
    );
    _page = 0;
    _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text(
          'This removes the product and its photos and videos. This cannot be undone.',
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
    try {
      await Repository.instance.delete(widget.productId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product'),
        actions: [
          if (product != null) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || product == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error ?? 'Not found', textAlign: TextAlign.center),
              ),
            )
          : _buildContent(context, product),
    );
  }

  Widget _buildContent(BuildContext context, Product product) {
    final theme = Theme.of(context);
    final images = product.media
        .where((m) => m.type == MediaType.image)
        .toList();
    final videos = product.media
        .where((m) => m.type == MediaType.video)
        .toList();
    final imagePaths = images
        .map((m) => AppDb.instance.resolve(m.path))
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _buildGallery(context, imagePaths),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (product.plu.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('PLU: ${product.plu}', style: theme.textTheme.bodyMedium),
              ],
              if (product.price != null) ...[
                const SizedBox(height: 4),
                Text(
                  formatRupiah(product.price!),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (product.categoryName != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(label: Text(product.categoryName!)),
                ),
              ],
              if (product.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(product.description, style: theme.textTheme.bodyLarge),
              ],
              if (product.specs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Specifications', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < product.specs.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(
                                  product.specs[i].name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  product.specs[i].value,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (videos.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Videos', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < videos.length; i++)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_fill, size: 36),
                      title: Text('Video ${i + 1}'),
                      trailing: const Icon(Icons.fullscreen),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            path: AppDb.instance.resolve(videos[i].path),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              if (product.notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Notes', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(product.notes, style: theme.textTheme.bodyMedium),
              ],
              const SizedBox(height: 24),
              Text(
                'Created ${formatDate(product.createdAt)}\n'
                'Updated ${formatDate(product.updatedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(BuildContext context, List<String> imagePaths) {
    if (imagePaths.isEmpty) {
      return Container(
        height: 200,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 56,
          color: Colors.black38,
        ),
      );
    }
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: imagePaths.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ImageViewerScreen(paths: imagePaths, initialIndex: i),
                ),
              ),
              child: Image.file(
                File(imagePaths[i]),
                fit: BoxFit.cover,
                width: double.infinity,
                cacheWidth: 1000,
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
          ),
          if (imagePaths.length > 1)
            Positioned(
              bottom: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_page + 1}/${imagePaths.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
