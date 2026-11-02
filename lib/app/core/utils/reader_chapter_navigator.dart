import 'package:mangaplus/app/core/utils/chapter_reference_identity.dart';
import 'package:mangaplus/app/data/models/chapter.dart';

/// Resolves adjacent chapters from the chapter sequence rather than trusting
/// potentially stale or non-adjacent previous/next links from a source.
class ReaderChapterNavigator {
  const ReaderChapterNavigator._();

  static ChapterElement? adjacentChapter({
    required List<ChapterElement> chapters,
    required String currentChapterId,
    required String currentChapterTitle,
    required bool forward,
  }) {
    if (chapters.isEmpty) return null;

    var currentIndex = chapters.indexWhere((chapter) {
      final references = [chapter.chapterId, chapter.url]
          .where((reference) => reference.trim().isNotEmpty);
      return references.any((reference) =>
          ChapterReferenceIdentity.matches(
            reference,
            currentChapterId,
            baseReference: currentChapterId,
          ));
    });

    if (currentIndex < 0 && currentChapterTitle.trim().isNotEmpty) {
      final title = _normalizeTitle(currentChapterTitle);
      final titleMatches = chapters
          .where((chapter) => _normalizeTitle(chapter.title) == title)
          .toList(growable: false);
      if (titleMatches.length == 1) {
        currentIndex = chapters.indexOf(titleMatches.single);
      }
    }

    final currentNumber = _chapterNumber(
          currentIndex >= 0 ? chapters[currentIndex].title : '',
        ) ??
        _chapterNumber(currentChapterTitle) ??
        _chapterNumber(currentChapterId);
    final numbers = chapters.map((chapter) => _chapterNumber(chapter.title)).toList();
    final hasReliableNumbers = numbers.every((number) => number != null) &&
        numbers.toSet().length == numbers.length;

    if (currentNumber != null && hasReliableNumbers) {
      ChapterElement? adjacent;
      double? bestNumber;
      for (var index = 0; index < chapters.length; index++) {
        final number = numbers[index]!;
        if (forward && number > currentNumber &&
            (bestNumber == null || number < bestNumber)) {
          bestNumber = number;
          adjacent = chapters[index];
        } else if (!forward && number < currentNumber &&
            (bestNumber == null || number > bestNumber)) {
          bestNumber = number;
          adjacent = chapters[index];
        }
      }
      if (adjacent != null) return adjacent;
    }

    if (currentIndex < 0) return null;
    final adjacentIndex = forward ? currentIndex - 1 : currentIndex + 1;
    if (adjacentIndex < 0 || adjacentIndex >= chapters.length) return null;
    return chapters[adjacentIndex];
  }

  static String _normalizeTitle(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static double? _chapterNumber(String value) {
    final explicit = RegExp(
      r'(?:chapter|chap\.?|ch\.?|الفصل|فصل)\s*[-#:]?\s*(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(value);
    if (explicit != null) return double.tryParse(explicit.group(1)!);
    final numbers = RegExp(r'\d+(?:\.\d+)?').allMatches(value).toList();
    if (numbers.length != 1) return null;
    return double.tryParse(numbers.single.group(0)!);
  }
}
