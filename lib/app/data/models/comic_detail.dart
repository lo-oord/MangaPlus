class ComicDetailData {
  final ComicDetail comicDetail;
  final String source;

  ComicDetailData({
    required this.comicDetail,
    required this.source,
  });

  factory ComicDetailData.fromJson(Map<String, dynamic> json) =>
      ComicDetailData(
        comicDetail: ComicDetail.fromJson(json["comicDetail"] ?? {}),
        source: json["source"] ?? "",
      );

  Map<String, dynamic> toJson() => {
        "comicDetail": comicDetail.toJson(),
        "source": source,
      };
}

class ComicDetail {
  final String comicId;
  final String coverImage;
  final String title;

  /// Original (usually Japanese/Korean/Chinese) title, when the source exposes
  /// one that differs from the display title.
  final String nativeTitle;

  /// Other titles the source lists, de-duplicated and never repeating [title].
  final List<String> alternativeTitles;
  final List<String> genres;
  final String releaseYear;
  final String author;
  final String artist;
  final String translator;
  final String status;
  final String type;
  final String totalChapters;
  final String updatedOn;
  final String rating;
  final String synopsis;
  final List<Chapter> chapters;

  ComicDetail({
    required this.comicId,
    required this.coverImage,
    required this.title,
    required this.nativeTitle,
    this.alternativeTitles = const [],
    required this.genres,
    required this.releaseYear,
    required this.author,
    this.artist = '',
    this.translator = '',
    required this.status,
    required this.type,
    required this.totalChapters,
    required this.updatedOn,
    required this.rating,
    required this.synopsis,
    required this.chapters,
  });

  factory ComicDetail.fromJson(Map<String, dynamic> json) => ComicDetail(
        comicId: '${json["comicId"] ?? ""}',
        coverImage: '${json["coverImage"] ?? ""}',
        title: '${json["title"] ?? ""}',
        nativeTitle: '${json["nativeTitle"] ?? ""}',
        alternativeTitles: json["alternativeTitles"] is List
            ? (json["alternativeTitles"] as List)
                .map((value) => '$value')
                .where((value) => value.trim().isNotEmpty)
                .toList(growable: false)
            : const [],
        genres: json["genres"] is List
            ? List<String>.from(
                (json["genres"] as List).map((x) => '$x'),
              )
            : const [],
        releaseYear: '${json["releaseYear"] ?? ""}',
        author: '${json["author"] ?? ""}',
        artist: '${json["artist"] ?? ""}',
        translator: '${json["translator"] ?? ""}',
        status: '${json["status"] ?? ""}',
        type: '${json["type"] ?? ""}',
        totalChapters: '${json["totalChapters"] ?? ""}',
        updatedOn: '${json["updatedOn"] ?? ""}',
        rating: '${json["rating"] ?? ""}',
        synopsis: '${json["synopsis"] ?? ""}',
        chapters: json["chapters"] is List
            ? List<Chapter>.from(
                (json["chapters"] as List).map(
                  (x) => Chapter.fromJson(Map<String, dynamic>.from(x as Map)),
                ),
              )
            : const [],
      );

  Map<String, dynamic> toJson() => {
        "comicId": comicId,
        "coverImage": coverImage,
        "title": title,
        "nativeTitle": nativeTitle,
        "alternativeTitles": List<dynamic>.from(alternativeTitles),
        "genres": List<dynamic>.from(genres),
        "releaseYear": releaseYear,
        "author": author,
        "artist": artist,
        "translator": translator,
        "status": status,
        "type": type,
        "totalChapters": totalChapters,
        "updatedOn": updatedOn,
        "rating": rating,
        "synopsis": synopsis,
        "chapters": List<dynamic>.from(chapters.map((x) => x.toJson())),
      };

  ComicDetail copyWith({
    String? comicId,
    String? coverImage,
    String? title,
    String? nativeTitle,
    List<String>? alternativeTitles,
    List<String>? genres,
    String? releaseYear,
    String? author,
    String? artist,
    String? translator,
    String? status,
    String? type,
    String? totalChapters,
    String? updatedOn,
    String? rating,
    String? synopsis,
    List<Chapter>? chapters,
  }) =>
      ComicDetail(
        comicId: comicId ?? this.comicId,
        coverImage: coverImage ?? this.coverImage,
        title: title ?? this.title,
        nativeTitle: nativeTitle ?? this.nativeTitle,
        alternativeTitles: alternativeTitles ?? this.alternativeTitles,
        genres: genres ?? this.genres,
        releaseYear: releaseYear ?? this.releaseYear,
        author: author ?? this.author,
        artist: artist ?? this.artist,
        translator: translator ?? this.translator,
        status: status ?? this.status,
        type: type ?? this.type,
        totalChapters: totalChapters ?? this.totalChapters,
        updatedOn: updatedOn ?? this.updatedOn,
        rating: rating ?? this.rating,
        synopsis: synopsis ?? this.synopsis,
        chapters: chapters ?? this.chapters,
      );

  /// Keeps already-known values when a later fetch comes back partial.
  ///
  /// A source that suddenly returns an empty metadata field (or an empty
  /// chapter list because of a parsing hiccup) must not wipe the data we
  /// already showed the user.
  ComicDetail mergedWith(ComicDetail previous) {
    String keep(String next, String old) =>
        next.trim().isNotEmpty ? next : old;
    final resolvedChapters = chapters.isNotEmpty ? chapters : previous.chapters;
    return copyWith(
      comicId: keep(comicId, previous.comicId),
      coverImage: keep(coverImage, previous.coverImage),
      title: keep(title, previous.title),
      nativeTitle: keep(nativeTitle, previous.nativeTitle),
      alternativeTitles: alternativeTitles.isNotEmpty
          ? alternativeTitles
          : previous.alternativeTitles,
      genres: genres.isNotEmpty ? genres : previous.genres,
      releaseYear: keep(releaseYear, previous.releaseYear),
      author: keep(author, previous.author),
      artist: keep(artist, previous.artist),
      translator: keep(translator, previous.translator),
      status: keep(status, previous.status),
      type: keep(type, previous.type),
      totalChapters: resolvedChapters.isNotEmpty
          ? '${resolvedChapters.length}'
          : keep(totalChapters, previous.totalChapters),
      updatedOn: keep(updatedOn, previous.updatedOn),
      rating: keep(rating, previous.rating),
      synopsis: keep(synopsis, previous.synopsis),
      chapters: resolvedChapters,
    );
  }
}

class Chapter {
  String chapterId;
  final String title;
  final String link;
  final String releaseTime;

  Chapter({
    required this.chapterId,
    required this.title,
    required this.link,
    required this.releaseTime,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
        chapterId: '${json["chapterId"] ?? ""}',
        title: '${json["title"] ?? ""}',
        link: '${json["link"] ?? ""}',
        releaseTime: '${json["releaseTime"] ?? ""}',
      );

  Map<String, dynamic> toJson() => {
        "chapterId": chapterId,
        "title": title,
        "link": link,
        "releaseTime": releaseTime,
      };
}
