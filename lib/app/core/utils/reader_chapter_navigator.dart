import 'package:mangaplus/app/core/utils/chapter_sequence.dart';
import 'package:mangaplus/app/data/models/chapter.dart';

/// Resolves adjacent chapters from the chapter sequence rather than trusting
/// potentially stale or non-adjacent previous/next links from a source.
///
/// The sequence keeps the source order and only steps one row, so a missing
/// chapter number in the middle of a list can never make the reader jump over
/// the chapter that is actually next.
class ReaderChapterNavigator {
  const ReaderChapterNavigator._();

  static ChapterElement? adjacentChapter({
    required List<ChapterElement> chapters,
    required String currentChapterId,
    required String currentChapterTitle,
    required bool forward,
    String? declaredNextChapter,
    String? declaredPreviousChapter,
  }) {
    return ChapterSequence.from(chapters).adjacent(
      currentId: currentChapterId,
      currentTitle: currentChapterTitle,
      forward: forward,
      declaredNextChapter: declaredNextChapter,
      declaredPreviousChapter: declaredPreviousChapter,
    );
  }
}
