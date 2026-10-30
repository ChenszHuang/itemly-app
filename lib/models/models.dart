import 'package:uuid/uuid.dart';

class Category {
  final String id;
  final String name;
  const Category(this.id, this.name);
}

class Spec {
  String name;
  String value;
  Spec(this.name, this.value);
}

enum MediaType { image, video }

class MediaItem {
  final String id;
  final MediaType type;

  /// Path relative to the app documents directory (e.g. media/abc.jpg).
  final String path;
  final int createdAt;

  const MediaItem({
    required this.id,
    required this.type,
    required this.path,
    required this.createdAt,
  });
}

class Product {
  final String id;
  String name;
  String plu;
  bool active;
  String description;
  String? categoryId;
  String? categoryName;
  int? price; // Indonesian Rupiah, whole numbers
  String notes;
  final int createdAt;
  int updatedAt;
  List<Spec> specs;
  List<MediaItem> media;

  /// First photo, only filled by list queries (for fast thumbnails).
  String? thumbPath;

  Product({
    required this.id,
    required this.name,
    this.plu = '',
    this.active = true,
    this.description = '',
    this.categoryId,
    this.categoryName,
    this.price,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    List<Spec>? specs,
    List<MediaItem>? media,
    this.thumbPath,
  }) : specs = specs ?? [],
       media = media ?? [];

  factory Product.empty() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Product(
      id: const Uuid().v4(),
      name: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Product.fromRow(Map<String, Object?> r) => Product(
    id: r['id'] as String,
    name: r['name'] as String,
    plu: (r['plu'] as String?) ?? '',
    active: (r['active'] as int? ?? 1) == 1,
    description: (r['description'] as String?) ?? '',
    categoryId: r['category_id'] as String?,
    categoryName: r['category_name'] as String?,
    price: r['price'] as int?,
    notes: (r['notes'] as String?) ?? '',
    createdAt: r['created_at'] as int,
    updatedAt: r['updated_at'] as int,
    thumbPath: r['thumb'] as String?,
  );
}
