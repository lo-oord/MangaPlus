/// Small normalizers for values that provider APIs expose in inconsistent shapes.
///
/// Every source funnels its raw payload through these helpers so the rest of
/// the app only has to deal with one canonical shape.
class SourceValues {
  const SourceValues._();

  /// Canonical work statuses. Sources map their own vocabulary onto these keys;
  /// an unrecognised value is kept verbatim so no information is invented.
  static const String statusOngoing = 'ongoing';
  static const String statusCompleted = 'completed';
  static const String statusHiatus = 'hiatus';
  static const String statusCancelled = 'cancelled';
  static const String statusUpcoming = 'upcoming';
  static const String statusUnknown = 'unknown';

  static const List<String> _imageKeys = [
    'image_url',
    'imageUrl',
    'cover_image',
    'coverImage',
    'cover_url',
    'coverUrl',
    'cover',
    'featuredImage',
    'featured_image',
    'poster',
    'poster_image',
    'posterImage',
    'thumbnail',
    'thumbnail_url',
    'thumbnailUrl',
    'image',
  ];

  static const List<String> _imageContainerKeys = [
    'desktop',
    'large',
    'medium',
    'mobile',
    'original',
    'card',
    'small',
    'source',
    'url',
    'src',
    'href',
    'image',
    'cover',
    'path',
  ];

  /// Returns a clean scalar string. Maps are unwrapped through their usual
  /// display keys, lists yield their first non-empty value, and provider
  /// placeholders such as `null`/`undefined` become an empty string.
  static String text(dynamic source) {
    if (source == null) return '';
    if (source is String) {
      final value = source.trim();
      if (value.isEmpty) return '';
      final lower = value.toLowerCase();
      if (lower == 'null' || lower == 'undefined' || lower == 'n/a') return '';
      return value;
    }
    if (source is num || source is bool) return source.toString();
    if (source is List) {
      for (final entry in source) {
        final value = text(entry);
        if (value.isNotEmpty) return value;
      }
      return '';
    }
    if (source is Map) {
      for (final key in const [
        'name',
        'title',
        'label',
        'displayName',
        'display_name',
        'value',
        'text',
        'shortTitle',
      ]) {
        if (!source.containsKey(key)) continue;
        final value = text(source[key]);
        if (value.isNotEmpty) return value;
      }
      return '';
    }
    return source.toString().trim();
  }

  /// First non-empty scalar among [values].
  static String firstText(Iterable<dynamic> values) {
    for (final value in values) {
      final text = SourceValues.text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// Canonical work status: `ongoing`, `completed`, `hiatus`, `cancelled`,
  /// `upcoming` or `unknown`. Unrecognised labels are returned trimmed so the
  /// UI can still show what the source actually said.
  static String status(dynamic source) {
    final value = text(source);
    if (value.isEmpty) return '';
    // A bare number is a progress percentage or a chapter index, never a work
    // status, so it must not be shown in the status slot.
    if (RegExp(r'^[\d.,%\s]+$').hasMatch(value)) return '';
    final key = _key(value);
    if (key.isEmpty) return value;

    const exact = <String, String>{
      'ongoing': statusOngoing,
      'on going': statusOngoing,
      'on air': statusOngoing,
      'airing': statusOngoing,
      'publishing': statusOngoing,
      'releasing': statusOngoing,
      'serialization': statusOngoing,
      'مستمر': statusOngoing,
      'مستمرة': statusOngoing,
      'مستمره': statusOngoing,
      'يعرض حاليا': statusOngoing,
      'completed': statusCompleted,
      'complete': statusCompleted,
      'finished': statusCompleted,
      'ended': statusCompleted,
      'season ended': statusCompleted,
      'مكتمل': statusCompleted,
      'مكتملة': statusCompleted,
      'مكتمله': statusCompleted,
      'منتهي': statusCompleted,
      'منتهية': statusCompleted,
      'موسم منتهي': statusCompleted,
      'hiatus': statusHiatus,
      'on hiatus': statusHiatus,
      'on hold': statusHiatus,
      'paused': statusHiatus,
      'stalled': statusHiatus,
      'متوقف': statusHiatus,
      'متوقفة': statusHiatus,
      'متوقف مؤقتا': statusHiatus,
      'متوقف مؤقتًا': statusHiatus,
      'متروك': statusHiatus,
      'معلقة': statusHiatus,
      'معلق': statusHiatus,
      'cancelled': statusCancelled,
      'canceled': statusCancelled,
      'dropped': statusCancelled,
      'discontinued': statusCancelled,
      'axed': statusCancelled,
      'ملغي': statusCancelled,
      'ملغى': statusCancelled,
      'ملغاة': statusCancelled,
      'upcoming': statusUpcoming,
      'not yet published': statusUpcoming,
      'tba': statusUpcoming,
      'قادم': statusUpcoming,
      'قادمة': statusUpcoming,
      'قريبا': statusUpcoming,
      'unknown': statusUnknown,
      'غير معروف': statusUnknown,
      'غير معروفة': statusUnknown,
    };
    final direct = exact[key];
    if (direct != null) return direct;

    // Labels are often decorated, e.g. "Ongoing (مستمرة)" or "حالة: مكتملة".
    if (key.contains('مستمر')) return statusOngoing;
    if (key.contains('مكتمل') || key.contains('منته')) return statusCompleted;
    if (key.contains('متوقف') || key.contains('معلق') || key.contains('متروك')) {
      return statusHiatus;
    }
    if (key.contains('ملغ')) return statusCancelled;
    if (key.contains('قادم') || key.contains('قريبا')) return statusUpcoming;
    if (key.contains('ongoing') ||
        key.contains('publishing') ||
        key.contains('releasing')) {
      return statusOngoing;
    }
    if (key.contains('complete') ||
        key.contains('finished') ||
        key.contains('ended')) {
      return statusCompleted;
    }
    if (key.contains('hiatus') ||
        key.contains('paused') ||
        key.contains('on hold')) {
      return statusHiatus;
    }
    if (key.contains('cancel') ||
        key.contains('dropped') ||
        key.contains('discontinu')) {
      return statusCancelled;
    }
    if (key.contains('upcoming') || key.contains('not yet')) {
      return statusUpcoming;
    }
    if (key.contains('unknown')) return statusUnknown;
    return value;
  }

  /// Number of chapters as a display string. Lists are counted by unique
  /// chapter identity so a duplicated entry never inflates the total, and an
  /// absent or non-positive count is reported as unknown (`''`) instead of a
  /// misleading zero.
  static String chapterCount(dynamic source) =>
      _chapterCount(source, 0);

  static String _chapterCount(dynamic source, int depth) {
    if (depth > 4) return '';
    if (source is List) {
      if (source.isEmpty) return '';
      final seen = <String>{};
      var total = 0;
      for (final entry in source) {
        if (entry is Map) {
          final identity = firstText([
            entry['url'],
            entry['chapter_url'],
            entry['chapterUrl'],
            entry['chapter_id'],
            entry['chapterId'],
            entry['id'],
            entry['number'],
            entry['chapter_number'],
            entry['chapterNumber'],
          ]);
          if (identity.isEmpty || !const {'0', 'null'}.contains(identity)) {
            if (identity.isEmpty) {
              total++;
            } else if (seen.add(identity)) {
              total++;
            }
            continue;
          }
          continue;
        }
        final identity = text(entry);
        if (identity.isEmpty) continue;
        if (seen.add(identity)) total++;
      }        return total > 0 ? '$total' : '';
    }
    if (source is Map) {
      for (final key in const [
        'total_chapters',
        'totalChapters',
        'totalChapterCount',
        'chapter_count',
        'chapterCount',
        'chapters_count',
        'chaptersCount',
        'number_of_chapters',
        'numberOfChapters',
        'chapterTotal',
        'totalChapter',
        'count',
      ]) {
        if (!source.containsKey(key)) continue;
        final value = _chapterCount(source[key], depth + 1);
        if (value.isNotEmpty) return value;
      }
      for (final container in const [
        'data',
        'details',
        'stats',
        'statistics',
        'metadata',
        'attributes',
        '_count',
      ]) {
        if (!source.containsKey(container)) continue;
        final value = _chapterCount(source[container], depth + 1);
        if (value.isNotEmpty) return value;
      }
      return '';
    }
    if (source is num) {
      if (!source.isFinite || source <= 0) return '';
      return '${source.round()}';
    }
    if (source is String) {
      final digits = _digits(source);
      if (digits == null || digits <= 0) return '';
      return '$digits';
    }
    return '';
  }

  /// Finds the first present key inside a raw payload, descending into the
  /// containers providers commonly wrap their data in.
  static dynamic lookup(
    dynamic source,
    List<String> keys, {
    int depth = 0,
  }) {
    if (depth > 3 || source is! Map) return null;
    for (final key in keys) {
      if (!source.containsKey(key)) continue;
      final value = source[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      return value;
    }
    for (final container in const [
      'data',
      'details',
      'series',
      'stats',
      'statistics',
      'metadata',
      'attributes',
    ]) {
      if (!source.containsKey(container)) continue;
      final found = lookup(source[container], keys, depth: depth + 1);
      if (found != null) return found;
    }
    return null;
  }

  /// Release year extracted from a plain year, a date or an epoch timestamp.
  static String year(dynamic source) {
    final value = text(source);
    if (value.isEmpty) return '';
    if (RegExp(r'^\d{9,}$').hasMatch(value)) {
      final epoch = int.tryParse(value);
      if (epoch != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          value.length >= 13 ? epoch : epoch * 1000,
          isUtc: true,
        );
        return '${date.year}';
      }
    }
    final match = RegExp(r'(?<!\d)((?:19|20)\d{2})(?!\d)').firstMatch(value);
    if (match != null) return match.group(1)!;
    return '';
  }

  /// Resolves a cover URL from any of the shapes providers use: plain strings,
  /// nested maps, lists, `srcset` strings, relative paths and protocol-relative
  /// URLs. Site chrome (logos, placeholders) is rejected instead of being shown
  /// as a cover.
  static String image(dynamic source, {String? baseUrl}) {
    final candidate = _imageCandidate(source, 0);
    if (candidate == null) return '';
    return imageUrl(candidate, baseUrl: baseUrl);
  }

  static String? _imageCandidate(dynamic source, int depth) {
    if (depth > 5 || source == null) return null;
    if (source is String) {
      final value = _firstSrcSetEntry(source);
      return value.isEmpty ? null : value;
    }
    if (source is num) return null;
    if (source is List) {
      for (final entry in source) {
        final value = _imageCandidate(entry, depth + 1);
        if (value != null) return value;
      }
      return null;
    }
    if (source is Map) {
      for (final key in _imageKeys) {
        if (!source.containsKey(key)) continue;
        final value = _imageCandidate(source[key], depth + 1);
        if (value != null) return value;
      }
      for (final key in _imageContainerKeys) {
        if (!source.containsKey(key)) continue;
        final value = _imageCandidate(source[key], depth + 1);
        if (value != null) return value;
      }
    }
    return null;
  }

  /// Normalizes one image reference into an absolute http(s) URL, or `''`.
  static String imageUrl(dynamic source, {String? baseUrl}) {
    var value = _firstSrcSetEntry(text(source));
    if (value.isEmpty) return '';
    if (value.startsWith('//')) value = 'https:$value';
    final lower = value.toLowerCase();
    if (lower.startsWith('data:') ||
        lower.startsWith('javascript:') ||
        lower == 'null' ||
        lower == 'undefined' ||
        lower == '0') {
      return '';
    }
    var uri = Uri.tryParse(value);
    if (uri == null) return '';
    if (!uri.hasScheme) {
      final base = Uri.tryParse(baseUrl?.trim() ?? '');
      if (base == null || !base.hasScheme) return '';
      uri = base.resolveUri(uri);
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') return '';
    if (uri.host.isEmpty) return '';
    final path = uri.path.toLowerCase();
    if (RegExp(
      r'(logo|placeholder|placeholders|no[-_]?image|noimage|default[-_]?cover|default[-_]?image|avatar|spinner|loading)',
    ).hasMatch(path)) {
      return '';
    }
    return uri.toString();
  }

  /// Canonical content type: `manga`, `manhwa`, `manhua`, `novel` or the
  /// provider's own label when it is something else (e.g. `oneshot`).
  static String canonicalType(dynamic source, {String fallback = 'manga'}) {
    final raw = type(source, fallback: '');
    if (raw.isEmpty) return fallback;
    final key = _key(raw);
    if (key.isEmpty) return fallback;
    if (key.contains('novel') ||
        key.contains('text') ||
        key.contains('رواي')) {
      return 'novel';
    }
    // "صيني/صينية" (Chinese) wins over a "مانهوا" label, e.g. "مانهوا صينية".
    if (key.contains('manhua') || key.contains('مانها') || key.contains('صيني')) {
      return 'manhua';
    }
    if (key.contains('manhwa') || key.contains('مانهوا') || key.contains('مانهو')) {
      return 'manhwa';
    }
    if (key.contains('manga') || key.contains('مانجا')) return 'manga';
    if (key.contains('oneshot') || key.contains('one shot')) return 'oneshot';
    return raw.trim();
  }

  /// True when a label describes textual content (novels, web novels, ...).
  static bool isNovelType(dynamic source) =>
      canonicalType(source, fallback: '') == 'novel';

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

  static String _key(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0640\u064B-\u0652]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[_\u2010-\u2015-]+'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]+', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _firstSrcSetEntry(String value) {
    final text = value.trim();
    if (text.isEmpty) return '';
    final comma = text.indexOf(',');
    if (comma < 0) {
      final space = text.indexOf(' ');
      return (space < 0 ? text : text.substring(0, space)).trim();
    }
    final first = text.substring(0, comma).trim();
    final space = first.indexOf(' ');
    return (space < 0 ? first : first.substring(0, space)).trim();
  }

  static int? _digits(String value) {
    final normalized = value
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    final match = RegExp(r'\d[\d,]*').firstMatch(normalized);
    if (match == null) return null;
    return int.tryParse(match.group(0)!.replaceAll(',', ''));
  }
}
