enum DownloadTaskStatus {
  queued,
  downloading,
  paused,
  completed,
  partiallyCompleted,
  failed,
  cancelled,
}

DownloadTaskStatus downloadTaskStatusFromJson(String? value) {
  return DownloadTaskStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => DownloadTaskStatus.queued,
  );
}

class DownloadTask {
  final String id;
  final String comicId;
  final String comicTitle;
  final String coverImage;
  final List<Map<String, String>> chapters;
  final List<String> completedChapterIds;
  final List<String> failedChapterIds;
  final Map<String, double> chapterProgress;
  final DownloadTaskStatus status;
  final String? currentChapterId;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DownloadTask({
    required this.id,
    required this.comicId,
    required this.comicTitle,
    required this.coverImage,
    required this.chapters,
    this.completedChapterIds = const [],
    this.failedChapterIds = const [],
    this.chapterProgress = const {},
    this.status = DownloadTaskStatus.queued,
    this.currentChapterId,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  int get totalChapters => chapters.length;
  int get completedCount => completedChapterIds.length;
  double get progress {
    if (chapters.isEmpty) return 0;
    final sum = chapters.fold<double>(0, (total, chapter) {
      return total + (chapterProgress[chapter['id']] ?? 0);
    });
    return sum / chapters.length;
  }

  DownloadTask copyWith({
    DownloadTaskStatus? status,
    List<String>? completedChapterIds,
    List<String>? failedChapterIds,
    Map<String, double>? chapterProgress,
    String? currentChapterId,
    bool clearCurrentChapter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadTask(
      id: id,
      comicId: comicId,
      comicTitle: comicTitle,
      coverImage: coverImage,
      chapters: chapters,
      completedChapterIds: completedChapterIds ?? this.completedChapterIds,
      failedChapterIds: failedChapterIds ?? this.failedChapterIds,
      chapterProgress: chapterProgress ?? this.chapterProgress,
      status: status ?? this.status,
      currentChapterId: clearCurrentChapter
          ? null
          : currentChapterId ?? this.currentChapterId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    final rawChapters = json['chapters'] as List? ?? const [];
    final rawProgress = json['chapterProgress'] as Map? ?? const {};
    return DownloadTask(
      id: '${json['id'] ?? ''}',
      comicId: '${json['comicId'] ?? ''}',
      comicTitle: '${json['comicTitle'] ?? ''}',
      coverImage: '${json['coverImage'] ?? ''}',
      chapters: rawChapters.whereType<Map>().map((item) => {
        'id': '${item['id'] ?? ''}',
        'title': '${item['title'] ?? ''}',
      }).where((item) => item['id']!.isNotEmpty).toList(growable: false),
      completedChapterIds:
          List<String>.from(json['completedChapterIds'] ?? const []),
      failedChapterIds: List<String>.from(json['failedChapterIds'] ?? const []),
      chapterProgress: rawProgress.map(
        (key, value) => MapEntry('$key', value is num ? value.toDouble() : 0.0),
      ),
      status: downloadTaskStatusFromJson('${json['status'] ?? ''}'),
      currentChapterId: json['currentChapterId']?.toString(),
      errorMessage: json['errorMessage']?.toString(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'comicId': comicId,
        'comicTitle': comicTitle,
        'coverImage': coverImage,
        'chapters': chapters,
        'completedChapterIds': completedChapterIds,
        'failedChapterIds': failedChapterIds,
        'chapterProgress': chapterProgress,
        'status': status.name,
        'currentChapterId': currentChapterId,
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
