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
      return Uri(
        scheme: 'teamx',
        host: 'series',
        queryParameters: {'url': url},
      ).toString();
    }
    return url;
  }
}

class DropsauceImportService {
  DropsauceImportService._();

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

  static String _rating(dynamic value) {
    if (value is num && value < 0) return '';
    final text = _string(value);
    return text == '-1' || text == '-1.0' ? '' : text;
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';
}
