/// Formats provider release timestamps for chapter and episode lists.
class EpisodeDateFormatter {
  const EpisodeDateFormatter._();

  static String? format(dynamic raw, {DateTime? now}) {
    final date = parse(raw);
    if (date == null) return _relativeLabel(raw);

    final current = now ?? DateTime.now();
    final localDate = date.toLocal();
    final age = current.difference(localDate);
    if (age.isNegative) return _calendarDate(localDate);
    if (age.inDays >= 2) return _calendarDate(localDate);
    if (age.inDays == 1) return 'منذ يوم';
    if (age.inHours >= 1) {
      return 'منذ ${_arabicCount(age.inHours, 'ساعة', 'ساعتين', 'ساعات', 'ساعة')}';
    }
    if (age.inMinutes >= 1) {
      return 'منذ ${_arabicCount(age.inMinutes, 'دقيقة', 'دقيقتين', 'دقائق', 'دقيقة')}';
    }
    return 'الآن';
  }

  /// Normalizes Firestore timestamps, epoch values and ISO strings into a
  /// serializable value understood by [format].
  static String normalize(dynamic raw) {
    if (raw == null) return '';
    if (raw is DateTime) return raw.toIso8601String();
    if (raw is num) {
      final date = _fromEpoch(raw);
      return date?.toIso8601String() ?? '';
    }
    if (raw is Map) {
      for (final key in const [
        'timestampValue',
        'dateValue',
        'stringValue',
        'publishedAt',
        'createdAt',
        'date',
      ]) {
        if (raw[key] != null) {
          final value = normalize(raw[key]);
          if (value.isNotEmpty) return value;
        }
      }
      final seconds = raw['_seconds'] ?? raw['seconds'] ?? raw['epochSeconds'];
      if (seconds is num) {
        final nanos = raw['_nanoseconds'] ?? raw['nanoseconds'] ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(
          seconds.toInt() * 1000 + (nanos is num ? nanos ~/ 1000000 : 0),
          isUtc: true,
        );
        return date.toIso8601String();
      }
      return '';
    }
    return raw.toString().trim();
  }

  static DateTime? parse(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is num) return _fromEpoch(raw);
    if (raw is Map) return parse(normalize(raw));
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final numeric = num.tryParse(value);
    if (numeric != null) {
      // Ignore a bare year rather than interpreting it as seconds after epoch.
      if (value.length < 9) return null;
      return _fromEpoch(numeric);
    }
    return DateTime.tryParse(value);
  }

  static String? _relativeLabel(dynamic raw) {
    if (raw is! String) return null;
    final label = raw.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (label.isEmpty) return null;
    if (RegExp(r'(?:منذ|قبل|ago\b|just now|yesterday|أمس|اليوم|الآن)', caseSensitive: false).hasMatch(label)) return label;
    return null;
  }
  static DateTime? _fromEpoch(num value) {
    try {
      final milliseconds = value.abs() >= 1000000000000
          ? value.round()
          : (value * 1000).round();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    } on RangeError {
      return null;
    }
  }

  static String _calendarDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year.toString().padLeft(4, '0')}';

  static String _arabicCount(
    int value,
    String one,
    String two,
    String few,
    String many,
  ) {
    if (value == 1) return one;
    if (value == 2) return two;
    if (value <= 10) return '$value $few';
    return '$value $many';
  }
}
