import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/repository.dart';
import '../db/app_db.dart';
import '../models/models.dart';
import '../widgets/thumb.dart';
import 'media_viewer.dart';

class _SpecRow {
  final TextEditingController name;
  final TextEditingController value;

  _SpecRow([String n = '', String v = ''])
    : name = TextEditingController(text: n),
      value = TextEditingController(text: v);

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

/// Add a new product, or edit an existing one when [productId] is given.
class ProductFormScreen extends StatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  static const _quickSpecs = ['Colour', 'Size', 'Material', 'Feature'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _plu = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _notes = TextEditingController();
  final _specs = <_SpecRow>[];
  final _picker = ImagePicker();

  late Product _product;
  List<Category> _categories = [];
  List<MediaItem> _media = [];
  final Set<String> _originalPaths = {};
  String? _categoryId;

  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  String? _loadError;

  bool get _isEdit => widget.productId != null;

  String? get _categoryName {
    for (final c in _categories) {
      if (c.id == _categoryId) return c.name;
    }
    return null;
  }

  List<MediaItem> get _images =>
      _media.where((m) => m.type == MediaType.image).toList();
  List<MediaItem> get _videos =>
      _media.where((m) => m.type == MediaType.video).toList();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final categories = await Repository.instance.categories();
      Product product = Product.empty();
      if (widget.productId != null) {
        final existing = await Repository.instance.get(widget.productId!);
        if (existing == null) throw 'This product no longer exists.';
        product = existing;
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _product = product;
        _name.text = product.name;
        _plu.text = product.plu;
        _desc.text = product.description;
        _price.text = product.price?.toString() ?? '';
        _notes.text = product.notes;
        _categoryId = product.categoryId;
        _media = List.of(product.media);
        _originalPaths.addAll(product.media.map((m) => m.path));
        for (final s in product.specs) {
          _specs.add(_SpecRow(s.name, s.value));
        }
        if (_specs.isEmpty) _specs.add(_SpecRow());
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '$e';
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _plu.dispose();
    _desc.dispose();
    _price.dispose();
    _notes.dispose();
    for (final r in _specs) {
      r.dispose();
    }
    // Leaving without saving: remove files copied in during this session.
    if (!_saved) {
      for (final m in _media) {
        if (!_originalPaths.contains(m.path)) {
          Repository.instance.deleteFile(m.path);
        }
      }
    }
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // --------------------------------------------------------------------- media

  Future<ImageSource?> _chooseSource(String title) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Use camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  /// Copies a picked file into the app's private media folder.
  Future<MediaItem> _store(String sourcePath, MediaType type) async {
    var ext = p.extension(sourcePath);
    if (ext.isEmpty) ext = type == MediaType.image ? '.jpg' : '.mp4';
    final id = const Uuid().v4();
    final relative = p.join('media', '$id$ext');
    await File(sourcePath).copy(AppDb.instance.resolve(relative));
    return MediaItem(
      id: id,
      type: type,
      path: relative,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _addPhotos() async {
    final source = await _chooseSource('Add photo');
    if (source == null) return;
    try {
      final List<XFile> files;
      if (source == ImageSource.camera) {
        final f = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        files = f == null ? [] : [f];
      } else {
        files = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1600,
          maxHeight: 1600,
        );
      }
      final added = <MediaItem>[];
      for (final f in files) {
        added.add(await _store(f.path, MediaType.image));
      }
      if (!mounted) return;
      setState(() => _media.addAll(added));
    } catch (e) {
      _snack('Could not add photo: $e');
    }
  }

  Future<void> _addVideo() async {
    final source = await _chooseSource('Add video');
    if (source == null) return;
    try {
      final f = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );
      if (f == null) return;
      final item = await _store(f.path, MediaType.video);
      if (!mounted) return;
      setState(() => _media.add(item));
    } catch (e) {
      _snack('Could not add video: $e');
    }
  }

  void _removeMedia(MediaItem item) {
    setState(() => _media.remove(item));
  }

  void _openImage(int index) {
    final paths = _images.map((m) => AppDb.instance.resolve(m.path)).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(paths: paths, initialIndex: index),
      ),
    );
  }

  void _openVideo(MediaItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VideoPlayerScreen(path: AppDb.instance.resolve(item.path)),
      ),
    );
  }

  // ------------------------------------------------------------------ category

  Future<void> _pickCategory() async {
    const none = '';
    const create = '__new__';
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: const Text('No category'),
              trailing: _categoryId == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, none),
            ),
            for (final c in _categories)
              ListTile(
                title: Text(c.name),
                trailing: _categoryId == c.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New category…'),
              onTap: () => Navigator.pop(ctx, create),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    if (result == create) {
      await _createCategory();
    } else {
      setState(() => _categoryId = result.isEmpty ? null : result);
    }
  }

  Future<void> _createCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewCategoryDialog(),
    );
    if (name == null) return;
    try {
      final category = await Repository.instance.addCategory(name);
      final categories = await Repository.instance.categories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoryId = category.id;
      });
    } catch (e) {
      _snack('Could not create category: $e');
    }
  }

  // ---------------------------------------------------------------------- save

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      _product
        ..name = _name.text
        ..plu = _plu.text
        ..description = _desc.text
        ..categoryId = _categoryId
        ..price = _price.text.isEmpty ? null : int.parse(_price.text)
        ..notes = _notes.text
        ..specs = [for (final r in _specs) Spec(r.name.text, r.value.text)]
        ..media = List.of(_media);

      await Repository.instance.save(_product);

      // Delete files the user removed from this product.
      final current = _media.map((m) => m.path).toSet();
      for (final path in _originalPaths.difference(current)) {
        await Repository.instance.deleteFile(path);
      }

      _saved = true;
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save: $e');
    }
  }

  // --------------------------------------------------------------------- build

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit product' : 'Add product'),
        actions: [
          TextButton(
            onPressed: (_loading || _saving) ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Product name *'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Product name is required'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _plu,
            decoration: const InputDecoration(labelText: 'PLU'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _desc,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Description'),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickCategory,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              child: Text(_categoryName ?? 'No category'),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Price (IDR)',
              prefixText: 'Rp ',
            ),
            validator: (v) =>
                (v != null && v.length > 12) ? 'Price is too large' : null,
          ),

          // ---- specifications
          _header('Specifications'),
          for (var i = 0; i < _specs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _specs[i].name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Attribute',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _specs[i].value,
                      decoration: const InputDecoration(
                        labelText: 'Value',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _specs.removeAt(i).dispose();
                      if (_specs.isEmpty) _specs.add(_SpecRow());
                    }),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final label in _quickSpecs)
                ActionChip(
                  label: Text('+ $label'),
                  onPressed: () => setState(() {
                    // Fill the first empty row, otherwise add a new one.
                    final empty = _specs.where(
                      (r) => r.name.text.isEmpty && r.value.text.isEmpty,
                    );
                    if (empty.isNotEmpty) {
                      empty.first.name.text = label;
                    } else {
                      _specs.add(_SpecRow(label));
                    }
                  }),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Custom'),
                onPressed: () => setState(() => _specs.add(_SpecRow())),
              ),
            ],
          ),

          // ---- photos
          _header('Photos'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _images.length; i++)
                _MediaTile(
                  onTap: () => _openImage(i),
                  onRemove: () => _removeMedia(_images[i]),
                  child: ProductThumb(
                    relativePath: _images[i].path,
                    cacheWidth: 300,
                  ),
                ),
              _AddTile(
                icon: Icons.add_a_photo_outlined,
                label: 'Add photo',
                onTap: _addPhotos,
              ),
            ],
          ),

          // ---- videos
          _header('Videos'),
          for (var i = 0; i < _videos.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.play_circle_fill, size: 32),
                title: Text('Video ${i + 1}'),
                subtitle: const Text('Tap to preview'),
                onTap: () => _openVideo(_videos[i]),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeMedia(_videos[i]),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addVideo,
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Add video'),
          ),

          // ---- notes
          _header('Notes'),
          TextFormField(
            controller: _notes,
            minLines: 2,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Anything else worth saving',
            ),
          ),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save product'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _MediaTile({
    required this.child,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InkWell(onTap: onTap, child: child),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AddTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New category'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Category name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
