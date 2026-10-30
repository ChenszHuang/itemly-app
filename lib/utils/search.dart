import '../models/models.dart';

/// Search helpers.
///
/// Every product stores a normalized `search_text` (name + description +
/// notes + price + all specs). A query is split into words and EVERY word
/// must appear somewhere in that text (partial match), so "rel", "laci",
/// "soft closing" and "40cm" all find the same product.
class SearchUtil {
  /// Lowercase, treat punctuation as spaces and glue numbers to units so that
  /// "40 cm", "40cm" and "40-cm" all become "40cm".
  static String normalize(String input) {
    var t = input.toLowerCase();
    t = t.replaceAll(RegExp(r'[-_/,;:()]'), ' ');
    t = t.replaceAllMapped(
      RegExp(r'(\d)\s+([a-z])'),
      (m) => '${m[1]}${m[2]}',
    );
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static List<String> tokens(String query) {
    return normalize(query)
        .replaceAll('%', '')
        .replaceAll('_', '')
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Small Indonesian <-> English synonym map so "hitam" finds "black".
  /// Extend this list with words your client uses.
  static const Map<String, List<String>> _synonyms = {
    'hitam': ['black'],
    'black': ['hitam'],
    'putih': ['white'],
    'white': ['putih'],
    'merah': ['red'],
    'red': ['merah'],
    'biru': ['blue'],
    'blue': ['biru'],
    'kayu': ['wood'],
    'wood': ['kayu'],
    'besi': ['iron', 'steel'],
    'laci': ['drawer'],
    'drawer': ['laci'],
    'engsel': ['hinge'],
    'hinge': ['engsel'],
    'gagang': ['handle', 'pegangan'],
    'handle': ['gagang', 'pegangan'],
    'pegangan': ['handle', 'gagang'],
  };

  /// The word itself plus any synonyms (any one of them may match).
  static List<String> expand(String token) => [token, ...?_synonyms[token]];

  static String build(Product p) {
    return normalize([
      p.name,
      p.description,
      p.notes,
      if (p.price != null) p.price.toString(),
      for (final s in p.specs) '${s.name} ${s.value}',
    ].join(' '));
  }
}
