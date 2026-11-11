import 'dart:convert';

import 'package:mangaplus/app/core/reader/reader_page_geometry.dart';
import 'package:mangaplus/app/data/models/chapter.dart';

/// Why an offline chapter could or could not be opened.
enum ReaderOfflineIssue {
  ready,
  notFound,
  incomplete,
  missingFiles,
  emptyContent,
  wrongType,
}

class ReaderOfflineChapter {
  ReaderOfflineChapter._({
    required this.record,
    required this.chapterId,
    required this.comicId,
    required this.title,
    required this.comicTitle,
    required this.content,
    required this.isNovel,
    required this.imagePaths,
    required this.imageSizes,
    required this.totalBytes,
    required this.downloadedAt,
  });

  factory ReaderOfflineChapter.fromRecord(Map<String, dynamic> record) {
    final paths = (record['localImagePaths'] is List
            ? record['localImagePaths'] as List
            : const [])
        .map((value) => '$value')
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    final rawSizes = record['imageSizes'];
    final sizes = <ReaderPageSize>[];
    if (rawSizes is List) {
      for (final raw in rawSizes) {
        final size = ReaderPageSize.tryParse(raw);
        if (size != null) sizes.add(size);
      }
    }
    final content = '${record['content'] ?? ''}'.trim();
    return ReaderOfflineChapter._(
      record: record,
      chapterId: '${record['chapterId'] ?? ''}'.trim(),
      comicId: '${record['comicId'] ?? ''}'.trim(),
      title: '${record['chapterTitle'] ?? ''}'.trim(),
      comicTitle: '${record['comicTitle'] ?? ''}'.trim(),
      content: content,
      isNovel: record['isNovel'] == true || content.isNotEmpty,
      imagePaths: paths,
      imageSizes: sizes,
      totalBytes: record['totalBytes'] is num
          ? (record['totalBytes'] as num).toInt()
          : 0,
      downloadedAt: DateTime.tryParse('${record['downloadedAt'] ?? ''}') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final Map<String, dynamic> record;
  final String chapterId;
  final String comicId;
  final String title;
  final String comicTitle;
  final String content;
  final bool isNovel;
  final List<String> imagePaths;
  final List<ReaderPageSize> imageSizes;
  final int totalBytes;
  final DateTime downloadedAt;

  bool get isDeclaredComplete => record['complete'] != false;

  int get declaredPageCount {
    final value = record['pageCount'];
    return value is num ? value.toInt() : imagePaths.length;
  }

  /// Page count as verified from the record, never from a loading estimate.
  int get pageCount => isNovel ? 0 : imagePaths.length;

  Map<String, ReaderPageSize> get sizeByPath {
    final map = <String, ReaderPageSize>{};
    final count = imageSizes.length < imagePaths.length
        ? imageSizes.length
        : imagePaths.length;
    for (var index = 0; index < count; index++) {
      map[imagePaths[index]] = imageSizes[index];
    }
    return map;
  }
}

class ReaderOfflineResolution {
  const ReaderOfflineResolution({
    required this.issue,
    this.chapter,
    this.imagePaths = const [],
    this.navigation = const [],
    this.previousChapterId = '',
    this.nextChapterId,
    this.imageSizes = const {},
  });

  final ReaderOfflineIssue issue;
  final ReaderOfflineChapter? chapter;
  final List<String> imagePaths;
  final List<ChapterElement> navigation;
  final String previousChapterId;
  final String? nextChapterId;
  final Map<String, ReaderPageSize> imageSizes;

  bool get isReady => issue == ReaderOfflineIssue.ready && chapter != null;

  String get issueMessage {
    switch (issue) {
      case ReaderOfflineIssue.ready:
        return '';
      case ReaderOfflineIssue.notFound:
        return 'هذا الفصل غير محمّل للقراءة دون اتصال.';
      case ReaderOfflineIssue.incomplete:
        return 'تنزيل هذا الفصل لم يكتمل بعد.';
      case ReaderOfflineIssue.missingFiles:
        return 'بعض ملفات هذا الفصل مفقودة أو تالفة.';
      case ReaderOfflineIssue.emptyContent:
        return 'لا يوجد محتوى محلي صالح لهذا الفصل.';
      case ReaderOfflineIssue.wrongType:
        return 'نوع المحتوى المحلي لا يطابق هذا القارئ.';
    }
  }

  ChapterData? toChapterData({required String fallbackTitle}) {
    final local = chapter;
    if (!isReady || local == null) return null;
    final title = local.title.isEmpty ? fallbackTitle : local.title;
    return ChapterData(
      chapter: DataChapter(
        chapterId: local.chapterId,
        title: title,
        images: local.isNovel ? const [] : imagePaths,
        content: local.isNovel ? local.content : '',
        previousChapter: previousChapterId,
        nextChapter: nextChapterId,
        chapters: navigation,
      ),
      source: 'local',
    );
  }
}

typedef ReaderFileExists = bool Function(String path);
typedef ReaderFileSize = int Function(String path);

/// Validates and resolves chapters that were downloaded for offline reading.
///
/// A record only counts as offline content when every required file is present
/// and non-empty. The old reader treated the presence of a record as proof that
/// the chapter was complete, which is why a half-finished download could open
/// as a broken chapter.
class ReaderOfflineLibrary {
  const ReaderOfflineLibrary._();

  static ReaderOfflineResolution resolve({
    required List<dynamic> records,
    required String chapterId,
    required String comicId,
    required bool isNovel,
    required ReaderFileExists fileExists,
    required ReaderFileSize fileSize,
  }) {
    final target = chapterId.trim();
    if (target.isEmpty) {
      return const ReaderOfflineResolution(issue: ReaderOfflineIssue.notFound);
    }
    final parsed = <ReaderOfflineChapter>[];
    for (final raw in records) {
      if (raw is! Map) continue;
      final record = ReaderOfflineChapter.fromRecord(
        Map<String, dynamic>.from(raw),
      );
      if (record.chapterId.isEmpty) continue;
      if (comicId.trim().isNotEmpty &&
          record.comicId.isNotEmpty &&
          record.comicId != comicId.trim()) {
        continue;
      }
      parsed.add(record);
    }
    ReaderOfflineChapter? local;
    for (final record in parsed) {
      if (_sameChapter(record.chapterId, target)) {
        local = record;
        break;
      }
    }
    if (local == null) {
      return const ReaderOfflineResolution(issue: ReaderOfflineIssue.notFound);
    }
    if (local.isNovel != isNovel) {
      return ReaderOfflineResolution(
        issue: ReaderOfflineIssue.wrongType,
        chapter: local,
      );
    }
    if (!local.isDeclaredComplete) {
      return ReaderOfflineResolution(
        issue: ReaderOfflineIssue.incomplete,
        chapter: local,
      );
    }
    if (isNovel) {
      if (local.content.isEmpty) {
        return ReaderOfflineResolution(
          issue: ReaderOfflineIssue.emptyContent,
          chapter: local,
        );
      }
      return _ready(local, parsed, comicId: comicId);
    }
    if (local.imagePaths.isEmpty) {
      return ReaderOfflineResolution(
        issue: ReaderOfflineIssue.emptyContent,
        chapter: local,
      );
    }
    final ordered = sortPagePaths(local.imagePaths);
    for (final path in ordered) {
      if (!fileExists(path) || fileSize(path) <= 0) {
        return ReaderOfflineResolution(
          issue: ReaderOfflineIssue.missingFiles,
          chapter: local,
        );
      }
    }
    if (local.declaredPageCount > 0 &&
        local.declaredPageCount != ordered.length) {
      return ReaderOfflineResolution(
        issue: ReaderOfflineIssue.incomplete,
        chapter: local,
      );
    }
    return _ready(
      local,
      parsed,
      comicId: comicId,
      orderedPages: ordered,
    );
  }

  static ReaderOfflineResolution _ready(
    ReaderOfflineChapter local,
    List<ReaderOfflineChapter> all, {
    required String comicId,
    List<String>? orderedPages,
  }) {
    final navigationRecords = all
        .where((record) =>
            record.comicId == local.comicId || comicId.trim().isEmpty)
        .where((record) => record.isNovel == local.isNovel)
        .toList(growable: false);
    navigationRecords.sort((left, right) {
      final leftNumber = chapterNumberFromTitle(left.title);
      final rightNumber = chapterNumberFromTitle(right.title);
      if (leftNumber == null && rightNumber == null) return 0;
      if (leftNumber == null) return 1;
      if (rightNumber == null) return -1;
      return rightNumber.compareTo(leftNumber);
    });
    final navigation = navigationRecords
        .map((record) => ChapterElement(
              chapterId: record.chapterId,
              title: record.title.isEmpty ? record.chapterId : record.title,
              url: record.chapterId,
            ))
        .toList(growable: false);
    final index = navigationRecords.indexWhere(
      (record) => _sameChapter(record.chapterId, local.chapterId),
    );
    final older = index >= 0 && index + 1 < navigationRecords.length
        ? navigationRecords[index + 1].chapterId
        : '';
    final newer = index > 0 ? navigationRecords[index - 1].chapterId : null;
    final paths = orderedPages ?? local.imagePaths;
    return ReaderOfflineResolution(
      issue: ReaderOfflineIssue.ready,
      chapter: local,
      imagePaths: paths,
      navigation: navigation,
      previousChapterId: older,
      nextChapterId: newer,
      imageSizes: {
        for (final entry in local.sizeByPath.entries) entry.key: entry.value,
      },
    );
  }

  static List<ReaderOfflineChapter> chaptersForComic(
    List<dynamic> records, {
    required String comicId,
  }) {
    final parsed = <ReaderOfflineChapter>[];
    for (final raw in records) {
      if (raw is! Map) continue;
      final record = ReaderOfflineChapter.fromRecord(
        Map<String, dynamic>.from(raw),
      );
      if (record.chapterId.isEmpty) continue;
      if (comicId.trim().isNotEmpty &&
          record.comicId.isNotEmpty &&
          record.comicId != comicId.trim()) {
        continue;
      }
      parsed.add(record);
    }
    return parsed;
  }

  /// Natural page order. `page_10` must come after `page_9`, which a plain
  /// string sort gets wrong.
  static List<String> sortPagePaths(List<String> paths) {
    final indexed = paths.asMap().entries.toList(growable: false);
    indexed.sort((left, right) {
      final leftNumber = pageNumberFromPath(left.value);
      final rightNumber = pageNumberFromPath(right.value);
      if (leftNumber == null && rightNumber == null) {
        return left.key.compareTo(right.key);
      }
      if (leftNumber == null) return 1;
      if (rightNumber == null) return -1;
      if (leftNumber != rightNumber) return leftNumber.compareTo(rightNumber);
      return left.key.compareTo(right.key);
    });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }

  static int? pageNumberFromPath(String path) {
    final match =
        RegExp(r'page[_-]?(\d+)', caseSensitive: false).firstMatch(path);
    if (match != null) return int.tryParse(match.group(1)!);
    final file = path.split('/').last.split('.').first;
    final digits = RegExp(r'(\d+)').firstMatch(file);
    return digits == null ? null : int.tryParse(digits.group(1)!);
  }

  static double? chapterNumberFromTitle(String title) {
    final normalized = title.replaceAllMapped(RegExp(r'[٠-٩]'), (Match match) {
      const arabic = '٠١٢٣٤٥٦٧٨٩';
      final index = arabic.indexOf(match.group(0)!);
      return index < 0 ? match.group(0)! : '$index';
    }).replaceAll('٫', '.');
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
    if (match == null) return null;
    return double.tryParse(match.group(1)!);
  }

  /// Total bytes used by offline chapters, including their covers.
  static int usedBytes(
    List<dynamic> records, {
    required ReaderFileSize fileSize,
  }) {
    var total = 0;
    for (final raw in records) {
      if (raw is! Map) continue;
      final record = ReaderOfflineChapter.fromRecord(
        Map<String, dynamic>.from(raw),
      );
      if (record.totalBytes > 0) {
        total += record.totalBytes;
        continue;
      }
      for (final path in record.imagePaths) {
        final size = fileSize(path);
        if (size > 0) total += size;
      }
      final cover = '${record.record['coverImage'] ?? ''}';
      if (cover.startsWith('/')) {
        final size = fileSize(cover);
        if (size > 0) total += size;
      }
    }
    return total;
  }

  static bool _sameChapter(String left, String right) {
    final a = left.trim();
    final b = right.trim();
    if (a == b) return true;
    if (a.isEmpty || b.isEmpty) return false;
    if (a == Uri.encodeComponent(b) || b == Uri.encodeComponent(a)) return true;
    final leftUri = Uri.tryParse(a);
    final rightUri = Uri.tryParse(b);
    if (leftUri == null || rightUri == null) return false;
    final leftPath = _normalizedPath(leftUri);
    final rightPath = _normalizedPath(rightUri);
    return leftPath.isNotEmpty && leftPath == rightPath;
  }

  static String _normalizedPath(Uri uri) {
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    try {
      return Uri.decodeComponent(path);
    } on ArgumentError {
      return path;
    }
  }

  static String encodeJson(Object value) => jsonEncode(value);
}
