/// Chapter-divider marker used when several novel chapters are merged into one
/// continuous reading stream.
const String kNovelChapterDividerToken = '__MANGAPLUS_NOVEL_CHAPTER_DIVIDER__';

String novelChapterDividerMarker(String title) =>
    '$kNovelChapterDividerToken${Uri.encodeComponent(title.trim())}';

String titleFromNovelChapterDivider(String marker) {
  if (!marker.startsWith(kNovelChapterDividerToken)) return '';
  final encoded = marker.substring(kNovelChapterDividerToken.length);
  if (encoded.isEmpty) return '';
  try {
    return Uri.decodeComponent(encoded).trim();
  } on FormatException {
    return encoded.trim();
  }
}

/// Splits chapter text into display paragraphs without losing the divider
/// markers that separate merged chapters.
List<String> splitNovelParagraphs(String content) => content
    .split(RegExp(r'\n+'))
    .map((paragraph) => paragraph.trim())
    .where((paragraph) => paragraph.isNotEmpty)
    .toList(growable: false);

bool isNovelChapterDivider(String paragraph) =>
    paragraph.startsWith(kNovelChapterDividerToken);

/// A text search result inside the currently open novel chapter.
class NovelSearchHit {
  const NovelSearchHit({
    required this.paragraphIndex,
    required this.start,
    required this.end,
    required this.snippet,
  });

  final int paragraphIndex;
  final int start;
  final int end;
  final String snippet;

  String get matchedText => snippet.substring(
        start.clamp(0, snippet.length),
        end.clamp(0, snippet.length),
      );
}

/// Case-insensitive chapter search, bounded so a common word in a huge chapter
/// cannot produce thousands of widgets.
List<NovelSearchHit> searchNovelParagraphs(
  List<String> paragraphs,
  String query, {
  int limit = 60,
  int snippetRadius = 34,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty || paragraphs.isEmpty || limit <= 0) return const [];
  final hits = <NovelSearchHit>[];
  for (var index = 0; index < paragraphs.length; index++) {
    final paragraph = paragraphs[index];
    if (isNovelChapterDivider(paragraph)) continue;
    final lower = paragraph.toLowerCase();
    var from = 0;
    while (hits.length < limit) {
      final match = lower.indexOf(needle, from);
      if (match < 0) break;
      final snippetStart = (match - snippetRadius).clamp(0, paragraph.length);
      final snippetEnd =
          (match + needle.length + snippetRadius).clamp(0, paragraph.length);
      hits.add(NovelSearchHit(
        paragraphIndex: index,
        start: match - snippetStart,
        end: match - snippetStart + needle.length,
        snippet: paragraph.substring(snippetStart, snippetEnd),
      ));
      from = match + needle.length;
    }
    if (hits.length >= limit) break;
  }
  return List<NovelSearchHit>.unmodifiable(hits);
}

/// A bookmark note or text highlight attached to one paragraph of a novel.
class NovelNote {
  const NovelNote({
    required this.id,
    required this.chapterId,
    required this.paragraphIndex,
    required this.note,
    required this.quote,
    required this.color,
    required this.createdAt,
    this.start = 0,
    this.end = 0,
  });

  final String id;
  final String chapterId;
  final int paragraphIndex;
  final String note;
  final String quote;
  final String color;
  final DateTime createdAt;

  /// Character range of [quote] inside the paragraph. Zero end means the whole
  /// paragraph is highlighted.
  final int start;
  final int end;

  bool get isHighlightOnly => note.trim().isEmpty;

  bool get hasRange => end > start;

  NovelNote copyWith({String? note, String? color}) => NovelNote(
        id: id,
        chapterId: chapterId,
        paragraphIndex: paragraphIndex,
        note: note ?? this.note,
        quote: quote,
        color: color ?? this.color,
        createdAt: createdAt,
        start: start,
        end: end,
      );

  factory NovelNote.fromJson(Map<String, dynamic> json) => NovelNote(
        id: '${json['id'] ?? ''}',
        chapterId: '${json['chapterId'] ?? ''}',
        paragraphIndex: json['paragraphIndex'] is num
            ? (json['paragraphIndex'] as num).toInt()
            : int.tryParse('${json['paragraphIndex']}') ?? 0,
        note: '${json['note'] ?? ''}',
        quote: '${json['quote'] ?? ''}',
        color: '${json['color'] ?? '#ffd54f'}',
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        start: json['start'] is num ? (json['start'] as num).toInt() : 0,
        end: json['end'] is num ? (json['end'] as num).toInt() : 0,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'chapterId': chapterId,
        'paragraphIndex': paragraphIndex,
        'note': note,
        'quote': quote,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
        'start': start,
        'end': end,
      };

  /// Resolves the stored quote to a range inside [paragraph], tolerating text
  /// that moved slightly between versions.
  ({int start, int end}) resolveRange(String paragraph) {
    if (hasRange && end <= paragraph.length) {
      final slice = paragraph.substring(start, end);
      if (slice == quote) return (start: start, end: end);
    }
    final quoteValue = quote.trim();
    if (quoteValue.isEmpty) return (start: 0, end: 0);
    final index = paragraph.indexOf(quoteValue);
    if (index < 0) return (start: 0, end: 0);
    return (start: index, end: index + quoteValue.length);
  }
}

/// Builds the highlight colour for a note hex string (e.g. `#ffd54f`).
int novelNoteColorValue(String hex, {int fallback = 0xffffd54f}) {
  final normalized = hex.trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) return fallback;
  final parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) return fallback;
  return normalized.length == 6 ? (0xff000000 | parsed) : parsed;
}
