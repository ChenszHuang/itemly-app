import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../db/app_db.dart';

/// Small image from a stored relative path. Decodes at reduced size so
/// scrolling stays smooth even with many large photos.
class ProductThumb extends StatelessWidget {
  final String? relativePath;
  final int cacheWidth;

  const ProductThumb({
    super.key,
    required this.relativePath,
    this.cacheWidth = 400,
  });

  Widget _placeholder(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Icon(Icons.image_outlined, size: 40, color: Colors.black38),
  );

  @override
  Widget build(BuildContext context) {
    final path = relativePath;
    if (path == null) return _placeholder(context);
    final resolvedPath = AppDb.instance.resolve(path);
    if (kIsWeb) {
      return Image.network(
        resolvedPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => _placeholder(context),
      );
    }
    return Image.file(
      File(resolvedPath),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => _placeholder(context),
    );
  }
}
