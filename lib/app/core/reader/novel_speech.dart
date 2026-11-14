import 'package:mangaplus/app/core/reader/novel_reader_model.dart';

/// One spoken unit of a novel chapter.
///
/// TTS used to speak 2500-character paragraph blocks, which meant "next
/// sentence" could not exist and a chapter change had to restart a huge chunk.
/// Sentences are now the unit: the engine still receives a plain string, but the
/// reader can move one sentence forward or back and can show exactly what is
/// being read.
class NovelSpeechChunk {
  const NovelSpeechChunk({
    required this.paragraphIndex,
    required this.sentenceIndex,
    required this.text,
  });

  /// Index in the displayed paragraph list (dividers are skipped).
  final int paragraphIndex;

  /// Zero-based sentence ordinal inside [paragraphIndex].
  final int sentenceIndex;

  final String text;

  @override
  String toString() =>
      'NovelSpeechChunk(p:$paragraphIndex s:$sentenceIndex "$text")';
}

/// Sentence terminators for Arabic and Latin text.
const String _sentenceTerminators = '.!?؟…۔。！？';

/// Splits one paragraph into sentences without breaking Arabic shaping or the
/// order of the text. A sentence keeps its terminating punctuation.
List<String> splitNovelSentences(String paragraph, {int maxChars = 600}) {
  final trimmed = paragraph.trim();
  if (trimmed.isEmpty) return const <String>[];
  final sentences = <String>[];
  final buffer = StringBuffer();
  for (var index = 0; index < trimmed.length; index++) {
    final char = trimmed[index];
    buffer.write(char);
    final isTerminator = _sentenceTerminators.contains(char);
    final nextIsSpace =
        index + 1 >= trimmed.length || trimmed[index + 1].trim().isEmpty;
    if (isTerminator && nextIsSpace) {
      _appendBounded(sentences, buffer.toString(), maxChars);
      buffer.clear();
      // Skip the whitespace run that belonged to the sentence break.
      while (index + 1 < trimmed.length && trimmed[index + 1].trim().isEmpty) {
        index++;
      }
    }
  }
  final rest = buffer.toString().trim();
  if (rest.isNotEmpty) _appendBounded(sentences, rest, maxChars);
  return List<String>.unmodifiable(sentences);
}

/// Splits an over-long sentence by words so no single TTS call is enormous.
void _appendBounded(List<String> target, String sentence, int maxChars) {
  final value = sentence.trim();
  if (value.isEmpty) return;
  if (value.length <= maxChars) {
    target.add(value);
    return;
  }
  final buffer = StringBuffer();
  for (final word in value.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final extra = word.length + (buffer.isEmpty ? 0 : 1);
    if (buffer.length + extra > maxChars && buffer.isNotEmpty) {
      target.add(buffer.toString());
      buffer.clear();
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(word);
  }
  if (buffer.isNotEmpty) target.add(buffer.toString());
}

/// Builds the complete spoken sequence of a chapter, skipping chapter dividers
/// and empty paragraphs while keeping their original paragraph indexes.
List<NovelSpeechChunk> splitNovelSpeech(String content, {int maxChars = 600}) {
  final paragraphs = splitNovelParagraphs(content);
  final chunks = <NovelSpeechChunk>[];
  for (var paragraphIndex = 0;
      paragraphIndex < paragraphs.length;
      paragraphIndex++) {
    final paragraph = paragraphs[paragraphIndex];
    if (isNovelChapterDivider(paragraph)) continue;
    final sentences = splitNovelSentences(paragraph, maxChars: maxChars);
    for (var sentenceIndex = 0;
        sentenceIndex < sentences.length;
        sentenceIndex++) {
      chunks.add(NovelSpeechChunk(
        paragraphIndex: paragraphIndex,
        sentenceIndex: sentenceIndex,
        text: sentences[sentenceIndex],
      ));
    }
  }
  return List<NovelSpeechChunk>.unmodifiable(chunks);
}
