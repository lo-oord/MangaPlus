class DownloadedChapter {
  static const int currentFormatVersion = 2;

  final String comicId;
  final String chapterId;
  final String comicTitle;
  final String chapterTitle;
  final String coverImage;
  final List<String> localImagePaths;
  final String content;
  final bool isNovel;
  final DateTime downloadedAt;

  /// Integrity metadata written by the download manager.
  ///
  /// [imageSizes] mirrors [localImagePaths], so an offline chapter can reserve
  /// the exact page heights on its first frame instead of re-measuring pages
  /// while the user is already scrolling.
  final List<List<int>> imageSizes;
  final int pageCount;
  final int totalBytes;
  final bool complete;
  final int formatVersion;

  DownloadedChapter({
    required this.comicId,
    required this.chapterId,
    required this.comicTitle,
    required this.chapterTitle,
    required this.coverImage,
    required this.localImagePaths,
    this.content = '',
    this.isNovel = false,
    required this.downloadedAt,
    this.imageSizes = const [],
    int? pageCount,
    this.totalBytes = 0,
    this.complete = true,
    this.formatVersion = currentFormatVersion,
  }) : pageCount = pageCount ?? localImagePaths.length;

  factory DownloadedChapter.fromJson(Map<String, dynamic> json) {
    final paths = List<String>.from(json['localImagePaths'] ?? const []);
    final rawSizes = json['imageSizes'];
    final sizes = <List<int>>[];
    if (rawSizes is List) {
      for (final entry in rawSizes) {
        if (entry is List && entry.length >= 2) {
          final width = entry[0];
          final height = entry[1];
          if (width is num && height is num && width > 0 && height > 0) {
            sizes.add(<int>[width.round(), height.round()]);
          }
        }
      }
    }
    return DownloadedChapter(
      comicId: json['comicId'] ?? '',
      chapterId: json['chapterId'] ?? '',
      comicTitle: json['comicTitle'] ?? '',
      chapterTitle: json['chapterTitle'] ?? '',
      coverImage: json['coverImage'] ?? '',
      localImagePaths: paths,
      content: json['content']?.toString() ?? '',
      isNovel: json['isNovel'] == true ||
          (json['content']?.toString().isNotEmpty ?? false),
      downloadedAt:
          DateTime.tryParse(json['downloadedAt'] ?? '') ?? DateTime.now(),
      imageSizes: sizes,
      pageCount: json['pageCount'] is num
          ? (json['pageCount'] as num).toInt()
          : paths.length,
      totalBytes:
          json['totalBytes'] is num ? (json['totalBytes'] as num).toInt() : 0,
      complete: json['complete'] != false,
      formatVersion: json['formatVersion'] is num
          ? (json['formatVersion'] as num).toInt()
          : 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'comicId': comicId,
        'chapterId': chapterId,
        'comicTitle': comicTitle,
        'chapterTitle': chapterTitle,
        'coverImage': coverImage,
        'localImagePaths': localImagePaths,
        'content': content,
        'isNovel': isNovel,
        'downloadedAt': downloadedAt.toIso8601String(),
        'imageSizes': imageSizes,
        'pageCount': pageCount,
        'totalBytes': totalBytes,
        'complete': complete,
        'formatVersion': formatVersion,
      };
}
