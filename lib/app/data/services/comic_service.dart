import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mangaplus/app/core/config/config.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/comic_detail.dart';
import 'package:mangaplus/app/data/models/popular_comic.dart';

class ComicService {
  Future<ComicData> fetchComics() async {
    try {
      final response =
          await http.get(Uri.parse('${AppConfig.baseUrl}/comics'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ComicData.fromJson(jsonData['data']);
      } else {
        throw Exception('تعذّر جلب القصص المصورة: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('تعذر جلب القصص المصورة. حاول مجددًا.');
    }
  }

  Future<ComicDetailData> fetchComicDetail(String comicId) async {
    print('comic id: $comicId');
    try {
      final response =
          await http.get(Uri.parse('${AppConfig.baseUrl}/comics/$comicId'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ComicDetailData.fromJson(jsonData['data']);
      } else {
        throw Exception(
            'تعذّر جلب تفاصيل القصة المصورة: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('تعذر جلب تفاصيل القصة المصورة. حاول مجددًا.');
    }
  }

  Future<ChapterData> fetchChapter(String chapterId) async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/chapters/$chapterId'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ChapterData.fromJson(jsonData['data']);
      } else {
        throw Exception('تعذّر جلب الفصل: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('تعذر جلب الفصل. حاول مجددًا.');
    }
  }

  Future<PopularKomikData> fetchPopularComics() async {
    try {
      final response =
          await http.get(Uri.parse('${AppConfig.baseUrl}/popular-manga'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('popular komik: ${jsonData['data']}');
        return PopularKomikData.fromJson(jsonData['data']);
      } else {
        throw Exception(
            'تعذّر جلب القصص المصورة الشائعة: ${response.statusCode}');
      }
    } catch (e) {
      print('popular komik: $e');
      throw Exception('تعذر جلب القصص المصورة الشائعة. حاول مجددًا.');
    }
  }

  Future<ComicData> searchComics(String query) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/search?query=$query'),
      );
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return ComicData.fromJson(jsonData['data']);
      } else {
        throw Exception(
            'تعذّر جلب نتائج البحث: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('تعذر جلب نتائج البحث. حاول مجددًا.');
    }
  }
}
