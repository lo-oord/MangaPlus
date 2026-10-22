/// Small normalizers for values that provider APIs expose in inconsistent shapes.
class SourceValues {
  const SourceValues._();

  static String type(dynamic source, {String fallback = 'manga'}) {
    final value = _typeValue(source, 0);
    return value ?? fallback;
  }

  static String? _typeValue(dynamic value, int depth) {
    if (depth > 4 || value == null) return null;
    if (value is String) {
      final text = value.toString().trim();
      return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
    }
    if (value is List) {
      for (final entry in value) {
        final result = _typeValue(entry, depth + 1);
        if (result != null) return result;
      }
    }
    if (value is Map) {
      for (final key in const [
        'name', 'title', 'label', 'displayName', 'display_name', 'type',
        'seriesType', 'series_type', 'contentType', 'content_type', 'slug',
        'value', 'stringValue',
      ]) {
        if (!value.containsKey(key)) continue;
        final result = _typeValue(value[key], depth + 1);
        if (result != null) return result;
      }
    }
    return null;
  }

  static String rating(dynamic source) {
    final value = _ratingValue(source, 0);
    return value ?? '';
  }

  static String? _ratingValue(dynamic value, int depth) {
    if (depth > 4 || value == null) return null;
    if (value is num) {
      if (!value.isFinite || value <= 0) return null;
      return value.toString();
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(text);
      if (match == null) return null;
      final number = double.tryParse(match.group(0)!.replaceAll(',', '.'));
      if (number == null || !number.isFinite || number <= 0) return null;
      return number.toString();
    }
    if (value is List) {
      for (final entry in value) {
        final result = _ratingValue(entry, depth + 1);
        if (result != null) return result;
      }
      return null;
    }
    if (value is Map) {
      const ratingKeys = [
        'rating',
        'rate',
        'score',
        'average',
        'averageRating',
        'average_rating',
        'avg_rating',
        'vote_average',
        'mean',
        'value',
        'doubleValue',
        'integerValue',
        'stringValue',
        'ratingValue',
        'rating_value',
        'ratingScore',
        'rating_score',
        'voteAverage',
        'vote_average',
        'averageScore',
        'average_score',
        'scoreValue',
        'score_value',
      ];
      for (final key in ratingKeys) {
        if (!value.containsKey(key)) continue;
        final result = _ratingValue(value[key], depth + 1);
        if (result != null) return result;
      }
      const containers = ['stats', 'statistics', 'details', 'ratings', 'data'];
      for (final key in containers) {
        if (!value.containsKey(key)) continue;
        final result = _ratingValue(value[key], depth + 1);
        if (result != null) return result;
      }
    }
    return null;
  }
}
