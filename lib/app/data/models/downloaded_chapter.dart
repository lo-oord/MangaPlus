class DownloadedChapter {
  final String comicId;
  final String chapterId;
  final String comicTitle;
  final String chapterTitle;
  final String coverImage;
  final List<String> localImagePaths;
  final String content;
  final bool isNovel;
  final DateTime downloadedAt;

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
  });

  factory DownloadedChapter.fromJson(Map<String, dynamic> json) => DownloadedChapter(
        comicId: json['comicId'] ?? '',
        chapterId: json['chapterId'] ?? '',
        comicTitle: json['comicTitle'] ?? '',
        chapterTitle: json['chapterTitle'] ?? '',
        coverImage: json['coverImage'] ?? '',
        localImagePaths: List<String>.from(json['localImagePaths'] ?? []),
        content: json['content']?.toString() ?? '',
        isNovel: json['isNovel'] == true || (json['content']?.toString().isNotEmpty ?? false),
        downloadedAt: DateTime.parse(json['downloadedAt'] ?? DateTime.now().toIso8601String()),
      );

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
      };
}