import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:mangaplus/app/core/config/config.dart';
import 'package:mangaplus/app/data/models/comic.dart';
import 'package:mangaplus/app/data/models/genre.dart';

class GenreService extends GetxService {
  Future<GenreData> fetchGenres() async {
    try {
      final response =
          await http.get(Uri.parse('${AppConfig.baseUrl}/genres'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return GenreData.fromJson(jsonData['data']);
      } else {
        throw Exception('تعذّر جلب الأنواع: ${response.statusCode}');
      }
    } catch (e) {
      print('errorrr$e');

      throw Exception('تعذر جلب التصنيفات. حاول مجددًا.');
    }
  }

  Future<ComicData> fetchGenreDetail(String genre, {int page = 1}) async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.baseUrl}/genres/$genre?page=$page'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print('genre rororo:${jsonData['data']}');
        return ComicData.fromJson(jsonData['data']);
      } else {
        throw Exception('تعذّر جلب القصص المصورة: ${response.statusCode}');
      }
    } catch (e) {
      print('errorrr$e');
      throw Exception('تعذر جلب القصص المصورة. حاول مجددًا.');
    }
  }
}
