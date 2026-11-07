import 'package:mangaplus/app/core/utils/chapter_reference_identity.dart';
import 'package:mangaplus/app/data/models/chapter.dart';

/// Direction of the chapter list exactly as the source returned it.
enum ChapterOrder { ascending, descending, unknown }

/// A deduplicated, order-preserving view of a chapter list.
///
/// Adjacency is resolved from positions in the source list, not by turning a
/// title into a number: a source may list newest-first, oldest-first, mix
/// `Special`/`Extra` chapters and use Arabic or Arabic-Indic numerals. Numbers
/// are only used to learn the list direction and as a last-resort fallback.
class ChapterSequence {
  ChapterSequence._(this.chapters, this._keys, this.order);

  factory ChapterSequence.from(Iterable<ChapterElement> source) {
    final chapters = <ChapterElement>[];
    final keys = <Set<String>>[];
    final seen = <String>{};
    for (final chapter in source) {
      final chapterKeys = <String>{
        if (chapter.chapterId.trim().isNotEmpty)
          ChapterReferenceIdentity.identity(chapter.chapterId),
        if (chapter.url.trim().isNotEmpty)
          ChapterReferenceIdentity.identity(chapter.url),
      }..remove('');
      if (chapterKeys.isEmpty || chapterKeys.any(seen.contains)) continue;
      seen.addAll(chapterKeys);
      chapters.add(chapter);
      keys.add(chapterKeys);
    }
    return ChapterSequence._(
      List<ChapterElement>.unmodifiable(chapters),
      List<Set<String>>.unmodifiable(keys),
      _detectOrder(chapters),
    );
  }

  final List<ChapterElement> chapters;
  final List<Set<String>> _keys;
  final ChapterOrder order;

  int get length => chapters.length;
  bool get isEmpty => chapters.isEmpty;

  int indexOf(String reference, {String? baseReference}) {
    if (reference.trim().isEmpty || chapters.isEmpty) return -1;
    final identity = ChapterReferenceIdentity.identity(reference);
    if (identity.isNotEmpty) {
      for (var index = 0; index < _keys.length; index++) {
        if (_keys[index].contains(identity)) return index;
      }
    }
    if (baseReference != null && baseReference.trim().isNotEmpty) {
      for (var index = 0; index < chapters.length; index++) {
        if (_matches(chapters[index], reference, baseReference: baseReference)) {
          return index;
        }
      }
    }
    return -1;
  }

  /// The chapter one step away from [currentId] in reading order.
  ///
  /// [forward] means "the next chapter to read", which follows the source
  /// order: when the list is newest-first that is the previous row, and when it
  /// is oldest-first it is the next row. The result is always the immediate
  /// neighbour, so no chapter is skipped.
  ChapterElement? adjacent({
    required String currentId,
    required String currentTitle,
    required bool forward,
    String? declaredNextChapter,
    String? declaredPreviousChapter,
  }) {
    if (chapters.isEmpty) return null;
    var index = indexOf(currentId, baseReference: currentId);
    if (index < 0 && currentTitle.trim().isNotEmpty) {
      final matches = <int>[];
      for (var candidate = 0; candidate < chapters.length; candidate++) {
        if (_normalizeTitle(chapters[candidate].title) ==
            _normalizeTitle(currentTitle)) {
          matches.add(candidate);
        }
      }
      if (matches.length == 1) index = matches.single;
    }

    if (index >= 0) {
      return _neighbour(
        index,
        forward,
        declaredNextChapter: declaredNextChapter,
        declaredPreviousChapter: declaredPreviousChapter,
        currentId: currentId,
      );
    }

    // The current chapter is not part of the list (for example a chapter opened
    // from a notification). A source-declared neighbour that exists in the list
    // is authoritative, provided it is not the current chapter itself.
    final declared = forward ? declaredNextChapter : declaredPreviousChapter;
    if (declared != null && declared.trim().isNotEmpty) {
      final declaredIndex = indexOf(declared, baseReference: currentId);
      if (declaredIndex >= 0 &&
          !_matches(chapters[declaredIndex], currentId,
              baseReference: currentId)) {
        return chapters[declaredIndex];
      }
    }

    return _nearestNumbered(
      currentTitle: currentTitle,
      currentId: currentId,
      forward: forward,
    );
  }

  ChapterElement? _neighbour(
    int index,
    bool forward, {
    required String currentId,
    String? declaredNextChapter,
    String? declaredPreviousChapter,
  }) {
    // A list without usable numbers (special chapters, titled chapters, Arabic
    // names) has no direction of its own. The source-declared neighbours are
    // the only real evidence in that case; guessing "newest first" turned
    // "next" into "one row up", which opens an older chapter on lists that are
    // actually oldest-first.
    final direction = order == ChapterOrder.unknown
        ? _declaredDirection(
              index,
              currentId: currentId,
              declaredNextChapter: declaredNextChapter,
              declaredPreviousChapter: declaredPreviousChapter,
            ) ??
            ChapterOrder.descending
        : order;
    final step = direction == ChapterOrder.ascending
        ? (forward ? 1 : -1)
        : (forward ? -1 : 1);
    final target = index + step;
    if (target < 0 || target >= chapters.length) return null;
    return chapters[target];
  }

  /// Reads the list direction from the source's own next/previous links.
  ///
  /// When the declared next chapter sits below the current one, the list runs
  /// oldest-first; when it sits above, the list runs newest-first. Returns null
  /// when the links are missing or do not resolve inside the list.
  ChapterOrder? _declaredDirection(
    int index, {
    required String currentId,
    String? declaredNextChapter,
    String? declaredPreviousChapter,
  }) {
    ChapterOrder? fromLink(String? reference, {required bool forward}) {
      if (reference == null || reference.trim().isEmpty) return null;
      final target = indexOf(reference, baseReference: currentId);
      if (target < 0 || target == index) return null;
      final movesDown = target > index;
      final ascending = forward ? movesDown : !movesDown;
      return ascending ? ChapterOrder.ascending : ChapterOrder.descending;
    }

    return fromLink(declaredNextChapter, forward: true) ??
        fromLink(declaredPreviousChapter, forward: false);
  }

  ChapterElement? _nearestNumbered({
    required String currentTitle,
    required String currentId,
    required bool forward,
  }) {
    if (order == ChapterOrder.unknown) return null;
    final current = chapterNumber(currentTitle) ?? chapterNumber(currentId);
    if (current == null) return null;
    double? best;
    ChapterElement? match;
    for (final chapter in chapters) {
      final number = chapterNumber(chapter.title) ??
          chapterNumber(chapter.chapterId) ??
          chapterNumber(chapter.url);
      if (number == null) continue;
      final isForward = order == ChapterOrder.ascending
          ? number > current
          : number < current;
      if (!isForward) continue;
      final isCloser = best == null ||
          (order == ChapterOrder.ascending ? number < best : number > best);
      if (isCloser) {
        best = number;
        match = chapter;
      }
    }
    return match;
  }

  bool _matches(
    ChapterElement chapter,
    String reference, {
    String? baseReference,
  }) {
    if (reference.trim().isEmpty) return false;
    for (final candidate in [chapter.chapterId, chapter.url]) {
      if (candidate.trim().isEmpty) continue;
      if (ChapterReferenceIdentity.matches(
        candidate,
        reference,
        baseReference: baseReference,
      )) {
        return true;
      }
    }
    return false;
  }

  /// Learns the list direction from the numbered chapters only.
  ///
  /// Requiring every row to be numbered made a single `Special`, `Extra` or
  /// titled chapter erase the direction of a whole list, and one duplicated or
  /// out-of-order number did the same. Comparable neighbours now vote, so the
  /// majority decides and unnumbered rows are simply skipped.
  static ChapterOrder _detectOrder(List<ChapterElement> chapters) {
    if (chapters.length < 2) return ChapterOrder.unknown;
    var ascending = 0;
    var descending = 0;
    double? previous;
    for (final chapter in chapters) {
      final number =
          chapterNumber(chapter.title) ?? chapterNumber(chapter.chapterId);
      if (number == null) continue;
      if (previous != null) {
        if (number > previous) ascending++;
        if (number < previous) descending++;
      }
      previous = number;
    }
    if (ascending == 0 && descending == 0) return ChapterOrder.unknown;
    if (ascending > descending) return ChapterOrder.ascending;
    if (descending > ascending) return ChapterOrder.descending;
    return ChapterOrder.unknown;
  }

  static String _normalizeTitle(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static final RegExp _explicitNumber = RegExp(
    r'(?:chapter|chap\.?|ch\.?|special|extra|الفصل|فصل|الحلقة|حلقة|إضافي|خاص)'
    r'\s*[-#:]?\s*(\d+(?:[.,]\d+)?)',
    caseSensitive: false,
  );

  static const Map<String, double> _arabicOrdinals = {
    'الأول': 1,
    'الاول': 1,
    'الثاني': 2,
    'الثالث': 3,
    'الرابع': 4,
    'الخامس': 5,
    'السادس': 6,
    'السابع': 7,
    'الثامن': 8,
    'التاسع': 9,
    'العاشر': 10,
  };

  /// Reads a chapter number from a title or reference.
  ///
  /// Supports `Chapter 1`, `Chapter 1.5`, `Chapter 01`, `Special 1`,
  /// `Extra`, Arabic-Indic digits (`١٢`) and Arabic ordinals (`الفصل الأول`).
  /// Returns null when the value carries more than one unrelated number (for
  /// example a date or a volume plus chapter), so adjacency never guesses.
  static double? chapterNumber(String value) {
    final text = _normalizeDigits(value).replaceAll('ـ', '');
    if (text.trim().isEmpty) return null;
    final explicit = _explicitNumber.firstMatch(text);
    if (explicit != null) {
      return double.tryParse(explicit.group(1)!.replaceAll(',', '.'));
    }
    for (final entry in _arabicOrdinals.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    final numbers = RegExp(r'\d+(?:\.\d+)?').allMatches(text).toList();
    if (numbers.length != 1) return null;
    return double.tryParse(numbers.single.group(0)!);
  }

  static String _normalizeDigits(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + rune - 0x06F0);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
