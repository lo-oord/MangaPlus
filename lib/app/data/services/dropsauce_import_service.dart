import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:mangaplus/app/data/sources/manga_source_registry.dart';
import 'package:mangaplus/app/data/sources/source_base.dart';

class DropsauceFavoriteRecord {
  const DropsauceFavoriteRecord({
    required this.title,
    required this.url,
    required this.coverImage,
    required this.type,
    required this.status,
    required this.rating,
    required this.sourceTitle,
    required this.source,
    this.failureReason,
  });

  final String title;
  final String url;
  final String coverImage;
  final String type;
  final String status;
  final String rating;
  final String sourceTitle;
  final ContentSource? source;
  final String? failureReason;

  bool get isImportable => failureReason == null;

  String get comicId {
    if (source?.id == 'team_x_manga') {
      final parsed = Uri.tryParse(url);
      final publicUrl = parsed?.scheme == 'teamx'
          ? (parsed?.queryParameters['url'] ?? url)
          : url;
      return Uri(
        scheme: 'teamx',
        host: 'series',
        queryParameters: {'url': publicUrl},
      ).toString();
    }
    return url;
  }
}

class DropsauceImportService {
  DropsauceImportService._();

  static const Map<String, int> _sourceStability = {
    'team_x_manga': 5,
    'azora': 5,
    'manga_swat': 4,
    'mangatime': 4,
    'mknov': 4,
    'kawaii_manga': 3,
    'kawaii_novels': 3,
  };

  static List<DropsauceFavoriteRecord> parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final favouritesFile = archive.findFile('favourites');
    if (favouritesFile == null) {
      throw const FormatException('لم يتم العثور على ملف favourites داخل النسخة الاحتياطية.');
    }

    final content = utf8.decode(favouritesFile.content as List<int>);
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const FormatException('صيغة ملف المفضلة غير صالحة.');
    }

    return decoded
        .whereType<Map>()
        .map((entry) => _record(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
  }

  static DropsauceFavoriteRecord _record(Map<String, dynamic> entry) {
    final manga = entry['manga'] is Map
        ? Map<String, dynamic>.from(entry['manga'] as Map)
        : <String, dynamic>{};
    final title = _string(manga['title']);
    final url = _string(manga['public_url']);
    final sourceTitle = _string(manga['source_title']);
    final source = url.isEmpty ? null : MangaSourceRegistry.forUrl(url);

    String? failureReason;
    if (manga.isEmpty) {
      failureReason = 'بيانات العمل غير موجودة داخل السجل.';
    } else if (title.isEmpty) {
      failureReason = 'اسم العمل غير موجود.';
    } else if (url.isEmpty) {
      failureReason = 'رابط العمل غير موجود.';
    } else if (source == null) {
      failureReason = sourceTitle.isEmpty
          ? 'مصدر العمل غير مدعوم حاليًا.'
          : 'المصدر $sourceTitle غير مدعوم حاليًا.';
    }

    final sourceType = source?.kind ?? '';
    return DropsauceFavoriteRecord(
      title: title.isEmpty ? 'عمل بدون اسم' : title,
      url: url,
      coverImage: _string(manga['large_cover_url']).isNotEmpty
          ? _string(manga['large_cover_url'])
          : _string(manga['cover_url']),
      type: sourceType.isNotEmpty ? sourceType : _string(manga['type']),
      status: _string(manga['state']),
      rating: _rating(manga['rating']),
      sourceTitle: sourceTitle,
      source: source,
      failureReason: failureReason,
    );
  }

  /// Tries to recover records whose original source is not installed or whose
  /// backup only contains a public URL that the app cannot identify.
  static Future<DropsauceFavoriteRecord?> resolveMissingSource(
    DropsauceFavoriteRecord record,
  ) async {
    if (record.title.trim().isEmpty) return null;
    final candidates = <_ImportCandidate>[];
    await Future.wait(MangaSourceRegistry.searchableSources.map((source) async {
      try {
        final results = await source.search(record.title).timeout(const Duration(seconds: 12));
        var accepted = 0;
        for (final item in results.take(8)) {
          final url = _string(item['url']);
          final title = _string(item['title']);
          final score = _titleScore(record.title, title);
          if (url.isEmpty || score < 0.35) continue;
          candidates.add(_ImportCandidate(source: source, item: item, score: score));
          if (++accepted >= 2) break;
        }
      } catch (_) {
        // One unavailable source must not prevent checking the others.
      }
    }));
    if (candidates.isEmpty) return null;

    await Future.wait(candidates.map((candidate) async {
      try {
        final details = await candidate.source.details(_string(candidate.item['url']))
            .timeout(const Duration(seconds: 15));
        candidate.chapterCount = details['chapters'] is List
            ? (details['chapters'] as List).length
            : int.tryParse(_string(details['total_chapters'])) ?? 0;
        candidate.details = details;
      } catch (_) {
        candidate.chapterCount = 0;
      }
    }));

    candidates.sort((left, right) {
      final scoreDifference = right.score.compareTo(left.score);
      if (scoreDifference.abs() > 0.15) return scoreDifference;
      final chapters = right.chapterCount.compareTo(left.chapterCount);
      if (chapters != 0) return chapters;
      return (_sourceStability[right.source.id] ?? 1)
          .compareTo(_sourceStability[left.source.id] ?? 1);
    });
    final selected = candidates.first;
    final details = selected.details ?? const <String, dynamic>{};
    final itemUrl = _string(selected.item['url']);
    final resolvedUrl = _string(details['url']).isNotEmpty ? _string(details['url']) : itemUrl;
    return DropsauceFavoriteRecord(
      title: _string(details['title']).isNotEmpty ? _string(details['title']) : record.title,
      url: resolvedUrl,
      coverImage: _string(details['image_url']).isNotEmpty
          ? _string(details['image_url'])
          : (_string(selected.item['image_url']).isNotEmpty || _string(selected.item['image']).isNotEmpty
              ? (_string(selected.item['image_url']).isNotEmpty ? _string(selected.item['image_url']) : _string(selected.item['image']))
              : record.coverImage),
      type: _string(details['type']).isNotEmpty ? _string(details['type']) : selected.source.kind,
      status: _string(details['status']).isNotEmpty ? _string(details['status']) : record.status,
      rating: _string(details['rating']).isNotEmpty ? _string(details['rating']) : record.rating,
      sourceTitle: selected.source.name,
      source: selected.source,
    );
  }

  static double _titleScore(String expected, String actual) {
    final left = _titleTokens(expected);
    final right = _titleTokens(actual);
    if (left.isEmpty || right.isEmpty) return 0;
    final leftText = left.join(' ');
    final rightText = right.join(' ');
    if (leftText == rightText) return 1;
    if (leftText.contains(rightText) || rightText.contains(leftText)) return 0.92;
    final shared = left.where(right.contains).length;
    return shared / (left.length > right.length ? left.length : right.length);
  }

  static List<String> _titleTokens(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.length > 1)
      .toSet()
      .toList(growable: false);

  static String _rating(dynamic value) {
    if (value is num && value < 0) return '';
    final text = _string(value);
    return text == '-1' || text == '-1.0' ? '' : text;
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';
}

class _ImportCandidate {
  _ImportCandidate({required this.source, required this.item, required this.score});

  final ContentSource source;
  final Map<String, dynamic> item;
  final double score;
  int chapterCount = 0;
  Map<String, dynamic>? details;
}
