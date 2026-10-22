import 'azora_api.dart';
import 'manga_html_utils.dart';
import 'source_base.dart';
import 'source_values.dart';

/// Read-only adapter for Azora manga and text novels.
class AzoraSource extends ContentSource {
  @override
  String get id => 'azora';
  @override
  String get name => 'Azora Manga';
  @override
  String get kind => 'manga';
  @override
  List<String> get hosts => const ['azorafly.com', 'azorafly.net', 'azoraworlds.net'];
  @override
  bool handles(String url) => url.startsWith('azora://');

  @override
  Future<List<Map<String, dynamic>>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    return _query(query: query.trim(), page: 1, includeNovels: true);
  }

  @override
  Future<List<Map<String, dynamic>>> latest({int page = 1}) =>
      _query(query: '', page: page < 1 ? 1 : page);

  @override
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) =>
      _query(
        query: query.trim(),
        page: page < 1 ? 1 : page,
        includeNovels: query.trim().isNotEmpty,
      );

  Future<List<Map<String, dynamic>>> _query({
    required String query,
    required int page,
    bool includeNovels = false,
  }) async {
    final response = await AzoraApi.getJson('query', {
      'page': '$page',
      'perPage': '18',
      'searchTerm': query,
      'orderBy': 'lastChapterAddedAt',
      'orderDirection': 'desc',
    });
    final rawPosts = response['posts'];
    if (rawPosts is! List) return const [];
    final posts = rawPosts
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
    if (!includeNovels) {
      return posts
          .where((raw) => !_isNovel(raw))
          .map(_series)
          .where((entry) => (entry['title'] as String).trim().isNotEmpty)
          .toList(growable: false);
    }

    final flags = List<bool>.filled(posts.length, false);
    var cursor = 0;
    Future<void> worker() async {
      while (true) {
        final index = cursor++;
        if (index >= posts.length) return;
        flags[index] = await AzoraApi.isNovelPost(posts[index]);
      }
    }

    final workerCount = posts.length < 4 ? posts.length : 4;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return posts
        .asMap()
        .entries
        .map((entry) => _series({...entry.value, 'isNovel': flags[entry.key]}))
        .where((entry) => (entry['title'] as String).trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<Map<String, dynamic>> details(String url) async {
    final uri = Uri.tryParse(url);
    final slug = uri?.scheme == 'azora'
        ? (uri!.queryParameters['slug'] ?? '')
        : (uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : '');
    if (slug.isEmpty) throw Exception('Azora: رابط المانجا غير صالح.');

    final response = await AzoraApi.getJson('post', {'postSlug': slug});
    final post = response['post'];
    if (post is! Map) throw Exception('Azora: لم يتم العثور على المانجا.');
    final raw = Map<String, dynamic>.from(post);
    final id = (raw['id'] ?? uri?.queryParameters['id'] ?? '').toString();
    if (id.isEmpty) throw Exception('Azora: لا يوجد معرّف للسلسلة.');
    final chapterResponse = await AzoraApi.getJson('chapters', {'postId': id});
    final chapterContainer = chapterResponse['post'];
    final rawChapters = chapterContainer is Map ? chapterContainer['chapters'] : null;
    final chapters = rawChapters is List
        ? rawChapters.whereType<Map>().map((entry) => Map<String, dynamic>.from(entry))
            .where((entry) => !_isLocked(entry))
            .map((entry) => _chapter(
                  entry,
                  seriesSlug: slug,
                  isNovel: _isNovel(raw),
                ))
            .where((entry) => (entry['url'] as String).isNotEmpty)
            .toList(growable: false)
        : <Map<String, dynamic>>[];

    final description = mangaHtmlToText((raw['postContent'] ?? '').toString());
    final genresRaw = raw['genres'];
    final genres = genresRaw is List
        ? genresRaw.map((entry) => entry is Map ? (entry['name'] ?? '').toString() : entry.toString())
            .where((entry) => entry.trim().isNotEmpty).toList()
        : <String>[];
    final result = _series(raw)
      ..addAll({
        'description': description,
        'synopsis': description,
        'genres': genres,
        'author': (raw['author'] ?? '').toString(),
        'artist': (raw['artist'] ?? '').toString(),
        'status': (raw['seriesStatus'] ?? '').toString(),
        'year': (raw['releaseDate'] ?? '').toString(),
        'total_chapters': response['totalChapterCount'] ?? chapters.length,
        'chapters': chapters,
      });
    return result;
  }

  @override
  Future<Map<String, dynamic>?> streams(String url) async => null;

  @override
  Future<Map<String, dynamic>?> chapterImages(String url) async {
    final uri = Uri.tryParse(url);
    final rawId = uri?.scheme == 'azora'
        ? (uri!.queryParameters['id'] ?? '')
        : (uri?.queryParameters['chapterId'] ?? '');
    if (rawId.isEmpty || int.tryParse(rawId) == null) return null;

    final response = await AzoraApi.getJson('chapter', {'chapterId': rawId});
    final chapter = response['chapter'];
    if (chapter is! Map) throw Exception('Azora: لم يُعثر على الفصل.');
    final raw = Map<String, dynamic>.from(chapter);
    if (_isLocked(raw)) throw Exception('Azora: هذا الفصل مقفول أو غير متاح من المصدر.');
    final images = raw['images'];
    if (images is! List) throw Exception('Azora: لم تُرجع واجهة الفصل صفحات صور.');
    final ordered = images.whereType<Map>().toList()
      ..sort((a, b) => ((a['order'] as num?) ?? 0).compareTo((b['order'] as num?) ?? 0));
    final pages = ordered
        .map((entry) => (entry['url'] ?? '').toString().trim())
        .where((value) => value.startsWith('https://') || value.startsWith('http://'))
        .toList(growable: false);
    if (pages.isEmpty) throw Exception('Azora: لا توجد صور متاحة لهذا الفصل.');
    return {
      'title': (raw['title'] ?? '').toString(),
      'chapter_number': raw['number'] ?? uri?.queryParameters['number'] ?? '',
      'pages': pages,
      'images': pages.map((image) => {'url': image}).toList(),
      'url': url,
    };
  }

  @override
  Future<Map<String, dynamic>?> chapterContent(String url) async {
    final uri = Uri.tryParse(url);
    final rawId = uri?.scheme == 'azora'
        ? (uri!.queryParameters['id'] ?? '')
        : (uri?.queryParameters['chapterId'] ?? '');
    if (rawId.isEmpty || int.tryParse(rawId) == null) return null;

    final response = await AzoraApi.getJson('chapter', {'chapterId': rawId});
    final chapter = response['chapter'];
    if (chapter is! Map) throw Exception('Azora: لم يُعثر على الفصل النصي.');
    final raw = Map<String, dynamic>.from(chapter);
    final mangaPost = raw['mangaPost'];
    final isNovelChapter = _isNovel(raw) ||
        (mangaPost is Map && _isNovel(mangaPost)) ||
        uri?.queryParameters['type'] == 'novel';
    if (!isNovelChapter) return null;
    if (_isLocked(raw)) throw Exception('Azora: هذا الفصل مقفول أو غير متاح من المصدر.');

    final postId =
        '${raw['mangaPostId'] ?? (mangaPost is Map ? mangaPost['id'] : '')}';
    final seriesSlug = mangaPost is Map
        ? '${mangaPost['slug'] ?? ''}'
        : (uri?.queryParameters['series'] ?? '');
    final chapterResponse = postId.isEmpty
        ? const <String, dynamic>{}
        : await AzoraApi.getJson('chapters', {'postId': postId});
    final chapterContainer = chapterResponse['post'];
    final rawChapters = chapterContainer is Map ? chapterContainer['chapters'] : null;
    final chapterRecords = rawChapters is List
        ? rawChapters
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .where((entry) => !_isLocked(entry))
            .toList(growable: false)
        : <Map<String, dynamic>>[];
    final chapterItems = chapterRecords
        .map((entry) => _chapter(entry, seriesSlug: seriesSlug, isNovel: true))
        .where((entry) => (entry['url'] as String).isNotEmpty)
        .toList(growable: false);
    final currentIndex = chapterRecords.indexWhere(
      (entry) => '${entry['id'] ?? ''}' == rawId,
    );
    final previous = currentIndex >= 0 && currentIndex + 1 < chapterItems.length
        ? chapterItems[currentIndex + 1]['url']
        : null;
    final next = currentIndex > 0 ? chapterItems[currentIndex - 1]['url'] : null;
    final chapterNumber = raw['number'] ?? uri?.queryParameters['number'] ?? '';
    final title = '${raw['title'] ?? ''}'.trim();
    return {
      'title': title.isEmpty ? 'الفصل $chapterNumber' : title,
      'chapter_number': chapterNumber,
      'content': mangaHtmlToReadableText('${raw['content'] ?? ''}'),
      'previousChapter': previous,
      'nextChapter': next,
      'chapters': chapterItems,
      'url': url,
    };
  }

  Map<String, dynamic> _series(Map<String, dynamic> raw) {
    final slug = (raw['slug'] ?? '').toString();
    final id = (raw['id'] ?? '').toString();
    final genresRaw = raw['genres'];
    final genres = genresRaw is List
        ? genresRaw.map((entry) => entry is Map ? (entry['name'] ?? '').toString() : entry.toString())
            .where((entry) => entry.trim().isNotEmpty).toList()
        : <String>[];
    final chapters = raw['chapters'];
    final latest = chapters is List && chapters.isNotEmpty && chapters.first is Map
        ? chapters.first['number'] ?? 0
        : 0;
    return item(
      title: (raw['postTitle'] ?? raw['title'] ?? '').toString(),
      url: _seriesUrl(slug, id),
      image: (raw['featuredImage'] ?? '').toString(),
      type: _isNovel(raw)
          ? 'novel'
          : SourceValues.type([
              raw['seriesType'],
              raw['type'],
              raw['postType'],
            ]),
      genres: genres,
      description: mangaHtmlToText((raw['postContent'] ?? '').toString()),
      rating: SourceValues.rating(raw),
    )..addAll({
        'manga_id': id,
        'series_id': id,
        'slug': slug,
        'status': (raw['seriesStatus'] ?? '').toString(),
        'total_chapters': raw['totalChapterCount'] ?? raw['chaptersCount'] ??
            (raw['_count'] is Map ? raw['_count']['chapters'] : 0),
        'latest_chapter_number': latest,
        if (chapters is List && chapters.isNotEmpty && chapters.first is Map) ...{
          'latest_chapter_date': (chapters.first['createdAt'] ?? chapters.first['created_at'] ?? chapters.first['release_date'] ?? '').toString(),
          'latest_chapter_name': (chapters.first['title'] ?? '').toString(),
        },
      });
  }

  Map<String, dynamic> _chapter(
    Map<String, dynamic> raw, {
    required String seriesSlug,
    bool isNovel = false,
  }) {
    final id = (raw['id'] ?? '').toString();
    final number = raw['number'] ?? mangaChapterNumber((raw['title'] ?? '').toString()) ?? 0;
    final slug = (raw['slug'] ?? '').toString();
    final title = (raw['title'] ?? '').toString().trim();
    final contentType = isNovel ? 'novel' : 'manga';
    final label = title.isEmpty ? 'الفصل $number' : 'الفصل $number - $title';
    final release = (raw['createdAt'] ?? '').toString();
    return {
      'id': int.tryParse(id) ?? 0,
      'chapter_id': int.tryParse(id) ?? 0,
      'number': number,
      'chapter_number': number,
      'title': label,
      'release_date': release,
      'date': release,
      'url': 'azora://chapter?id=${Uri.encodeQueryComponent(id)}'
          '&number=${Uri.encodeQueryComponent(number.toString())}'
          '&slug=${Uri.encodeQueryComponent(slug)}'
          '&type=$contentType'
          '&series=${Uri.encodeQueryComponent(seriesSlug)}',
    };
  }

  bool _isNovel(Map<dynamic, dynamic> raw) => AzoraApi.isNovel(raw);

  bool _isLocked(Map<dynamic, dynamic> raw) => AzoraApi.isLocked(raw);

  String _seriesUrl(String slug, String id) =>
      'azora://series?slug=${Uri.encodeQueryComponent(slug)}'
      '&id=${Uri.encodeQueryComponent(id)}';
}
