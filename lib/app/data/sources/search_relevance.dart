import 'package:mangaplus/app/data/models/comic.dart';

class SearchRelevance {
  SearchRelevance._();

  static int score(String query, Map<String, dynamic> item) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return 0;
    final queryTokens = _tokens(normalizedQuery);
    if (queryTokens.isEmpty) return 0;

    final title = normalize('${item['title'] ?? ''}');
    final url = normalize(_urlPath('${item['url'] ?? item['link'] ?? ''}'));
    final nativeTitle = normalize('${item['native_title'] ?? ''}');
    final aliases = _flatten(item['alternate_titles'] ?? item['aliases']);
    final searchable = [title, url, nativeTitle, ...aliases]
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    var best = 0;
    var hasCompleteMatch = false;
    for (final field in searchable) {
      if (field == normalizedQuery) {
        best = best < 100 ? 100 : best;
      } else if (field.contains(normalizedQuery)) {
        best = best < 80 ? 80 : best;
      }
      final matched = queryTokens.where(field.contains).length;
      if (matched == queryTokens.length) {
        hasCompleteMatch = true;
        best = best < 60 ? 60 : best;
      } else if (matched > 0) {
        final partial = (matched * 40) ~/ queryTokens.length;
        best = best < partial ? partial : best;
      }
    }
    if (queryTokens.length > 1 && !hasCompleteMatch) return 0;
    return best;
  }

  static bool isRelevant(String query, Map<String, dynamic> item) =>
      score(query, item) > 0;

  static int comicScore(String query, ComicsList comic) => score(query, {
        'title': comic.title,
        'url': comic.comicId,
      });

  static String workKey(ComicsList comic) {
    final value = comic.comicId.trim();
    final uri = Uri.tryParse(value);
    if (uri != null) {
      final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
      final mangaIndex = segments.indexOf('manga');
      if (mangaIndex >= 0 && mangaIndex + 1 < segments.length) {
        return normalize(segments[mangaIndex + 1]);
      }
      if (segments.isNotEmpty) return normalize(segments.last);
    }
    return normalize(comic.title);
  }

  static String normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _tokens(String value) => value
      .split(' ')
      .where((token) => token.length >= 2)
      .toList(growable: false);

  static String _urlPath(String value) {
    final uri = Uri.tryParse(value);
    return uri?.path ?? value;
  }

  static List<String> _flatten(dynamic value) {
    if (value is String) return [normalize(value)];
    if (value is List) {
      return value
          .expand((entry) => _flatten(entry))
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    if (value is Map) {
      return _flatten(
        value['title'] ?? value['name'] ?? value['label'] ?? value['value'] ?? '',
      );
    }
    return const [];
  }
}
