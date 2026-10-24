import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/data/models/history.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/core/utils/reader_load_issue.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

List<String> _splitNovelParagraphs(String content) => content
    .split(RegExp(r'\n+'))
    .map((paragraph) => paragraph.trim())
    .where((paragraph) => paragraph.isNotEmpty)
    .toList(growable: false);

class ChapterController extends GetxController {
  final ComicService _comicService = ComicService();
  final FlutterTts _flutterTts = FlutterTts();
  final GetStorage _storage = GetStorage();
  final List<ChapterElement> _argumentChapterNavigation = [];
  final List<ChapterElement> _fallbackChapterNavigation = [];
  final Set<String> _prefetchingChapters = <String>{};
  final chapterNavigationRevision = 0.obs;
  List<ChapterElement>? _availableChaptersCache;
  List<ChapterElement>? _cachedLoadedChapterList;
  int _availableCacheRevision = -1;
  int _availableArgumentCount = -1;
  int _availableFallbackCount = -1;
  bool _availableCacheOffline = false;
  List<ChapterElement>? _adjacentCacheSource;
  int _adjacentCacheRevision = -1;
  String _adjacentCacheChapterId = '';
  String _adjacentCacheTitle = '';
  ChapterElement? _cachedNextAdjacentChapter;
  ChapterElement? _cachedPreviousAdjacentChapter;
  int _readChapterCacheRevision = -1;
  final Set<String> _readChapterIdentities = <String>{};

  PageController? _pageController;
  PageController get pageController => _pageController ??= PageController(
        initialPage: currentPage.value,
      );
  ScrollController? _scrollController;
  ScrollController get scrollController => _scrollController ??= ScrollController(
        initialScrollOffset: _restoredScrollOffset,
      );
  double _restoredScrollOffset = 0;
  double? _pendingScrollRestore;

  late final Map<String, dynamic> arguments =
      Map<String, dynamic>.from(Get.arguments as Map);
  late String chapterId = '${arguments['chapterId'] ?? ''}';
  late String currentChapterTitle = '${arguments['chapterTitle'] ?? ''}';
  bool get isNovel =>
      '${arguments['comicType'] ?? ''}'.trim().toLowerCase() == 'novel';
  bool get hasReadableContent => isNovel
      ? chapterData.value.chapter.content.trim().isNotEmpty
      : chapterData.value.chapter.images.isNotEmpty;

  Future<ChapterData?> prefetchChapter(String? id) async {
    final reference = _chapterReference(id);
    if (reference == null ||
        _sameChapterReference(reference, chapterId) ||
        isOffline.value ||
        !_prefetchingChapters.add(reference)) {
      return null;
    }
    try {
      return await _comicService.prefetchChapter(reference, isNovel: isNovel);
    } catch (error) {
      debugPrint('Unable to prefetch adjacent chapter: $error');
      return null;
    } finally {
      _prefetchingChapters.remove(reference);
    }
  }

  Future<void> _prefetchAdjacentChapters() async {
    if (!continuousNavigation.value || isOffline.value) return;
    final targets = <String>{
      if (nextChapterId != null) nextChapterId!,
      if (previousChapterId != null) previousChapterId!,
    };
    await Future.wait(targets.map(prefetchChapter));
  }
  String? _paragraphSource;
  Future<List<String>>? _paragraphsFuture;

  Future<List<String>> paragraphsFor(String content) {
    if (identical(_paragraphSource, content) && _paragraphsFuture != null) {
      return _paragraphsFuture!;
    }
    _paragraphSource = content;
    final computation = compute(_splitNovelParagraphs, content);
    late final Future<List<String>> cachedFuture;
    cachedFuture = computation.catchError((Object error) {
      if (identical(_paragraphsFuture, cachedFuture)) {
        _paragraphsFuture = null;
      }
      throw error;
    });
    _paragraphsFuture = cachedFuture;
    return cachedFuture;
  }

  final chapterData = ChapterData(
    chapter: DataChapter(
      chapterId: '',
      title: '',
      images: [],
      previousChapter: '',
      nextChapter: null,
      chapters: [],
    ),
    source: '',
  ).obs;

  final isLoading = false.obs;
  final isOffline = false.obs;
  final hasError = false.obs;
  final loadIssue = Rxn<ReaderLoadIssue>();
  final localImages = <String>[].obs;

  final showNavigation = false.obs;
  final showChapterList = false.obs;
  final currentPage = 0.obs;
  final readerFit = 'width'.obs;
  final readerMode = 'scroll'.obs;
  final readingDirection = 'rtl'.obs;
  final continuousNavigation = true.obs;
  final isNavigating = false.obs;
  final novelFontSize = 19.0.obs;
  final novelFontFamily = 'default'.obs;
  final novelBackground = 'app'.obs;
  final novelLineHeight = 1.85.obs;
  final novelParagraphSpacing = 18.0.obs;
  final novelProgress = 0.0.obs;
  final novelBookmarks = <Map<String, dynamic>>[].obs;
  final novelSpeechPlaying = false.obs;
  final novelSpeechPaused = false.obs;
  final novelSpeechRate = 0.42.obs;
  final novelSpeechLanguage = 'ar-SA'.obs;
  List<String> _speechChunks = [];
  int _speechChunkIndex = 0;
  bool _speechSessionActive = false;
  bool endNoticeShown = false;
  bool _isLoadingChapterNavigation = false;
  int _chapterLoadGeneration = 0;
  bool _suppressEndBoundaryOnce = false;
  Offset? _readerPointerDownPosition;
  Duration? _readerPointerDownTime;
  bool _readerPointerMoved = false;

  List<ChapterElement> get availableChapters {
    final revision = chapterNavigationRevision.value;
    final loadedChapters = chapterData.value.chapter.chapters;
    if (isOffline.value && loadedChapters.isNotEmpty) return loadedChapters;
    if (_availableChaptersCache != null &&
        identical(_cachedLoadedChapterList, loadedChapters) &&
        _availableCacheRevision == revision &&
        _availableArgumentCount == _argumentChapterNavigation.length &&
        _availableFallbackCount == _fallbackChapterNavigation.length &&
        _availableCacheOffline == isOffline.value) {
      return _availableChaptersCache!;
    }

    final candidates = <List<ChapterElement>>[
      loadedChapters,
      _argumentChapterNavigation,
      _fallbackChapterNavigation,
    ].where((items) => items.isNotEmpty).toList();
    if (candidates.isEmpty) return const [];
    candidates.sort((left, right) => right.length.compareTo(left.length));
    final merged = <ChapterElement>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      for (final chapter in candidate) {
        final identities = <String>{
          if (chapter.chapterId.isNotEmpty)
            _chapterIdentity(chapter.chapterId),
          if (chapter.url.isNotEmpty) _chapterIdentity(chapter.url),
        };
        if (identities.isEmpty || identities.any(seen.contains)) {
          continue;
        }
        seen.addAll(identities);
        merged.add(chapter);
      }
    }
    _cachedLoadedChapterList = loadedChapters;
    _availableCacheRevision = revision;
    _availableArgumentCount = _argumentChapterNavigation.length;
    _availableFallbackCount = _fallbackChapterNavigation.length;
    _availableCacheOffline = isOffline.value;
    _availableChaptersCache = List<ChapterElement>.unmodifiable(merged);
    return _availableChaptersCache!;
  }

  bool get canUseChapterList => availableChapters.isNotEmpty;

  bool isChapterRead(String id) {
    final revision = chapterNavigationRevision.value;
    if (_readChapterCacheRevision != revision) {
      _readChapterIdentities.clear();
      final readChapters = _storage.read('readChapters');
      if (readChapters is Map) {
        for (final key in readChapters.keys) {
          _readChapterIdentities.add(_chapterIdentity('$key'));
        }
      }
      final history = _storage.read('reading_history');
      if (history is Map) {
        for (final entry in history.values) {
          if (entry is Map) {
            final reference = entry['chapterId']?.toString() ?? '';
            if (reference.isNotEmpty) {
              _readChapterIdentities.add(_chapterIdentity(reference));
            }
          }
        }
      }
      _readChapterCacheRevision = revision;
    }
    return _readChapterIdentities.contains(_chapterIdentity(id));
  }

  List<ChapterElement> get _navigationChapters {
    final loadedChapters = chapterData.value.chapter.chapters;
    if (isOffline.value && loadedChapters.isNotEmpty) return loadedChapters;
    return availableChapters;
  }

  bool _sameChapterReference(String left, String right) {
    if (left == right) return true;
    final leftUri = Uri.tryParse(left);
    final rightUri = Uri.tryParse(right);
    if (leftUri == null || rightUri == null) return false;
    return leftUri.scheme == rightUri.scheme &&
        leftUri.host == rightUri.host &&
        leftUri.path == rightUri.path &&
        leftUri.query == rightUri.query;
  }

  String _chapterIdentity(String reference) {
    final value = reference.trim();
    final uri = Uri.tryParse(value);
    if (uri == null) return value.replaceFirst(RegExp(r'/+$'), '');
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return '${uri.scheme.toLowerCase()}|${uri.host.toLowerCase()}|$path|${uri.query}';
  }

  bool _containsCurrentChapter(List<ChapterElement> chapters) => chapters.any(
        (item) => _sameChapterReference(item.chapterId, chapterId) ||
            _sameChapterReference(item.url, chapterId),
      );

  bool isCurrentChapter(ChapterElement item) =>
      _sameChapterReference(item.chapterId, chapterId) ||
      _sameChapterReference(item.url, chapterId);

  Future<void> fetchChapter(
    String id, {
    bool keepCurrentContent = false,
    bool startAtEnd = false,
  }) async {
    final generation = ++_chapterLoadGeneration;
    try {
      isLoading(true);
      hasError(false);
      loadIssue.value = null;
      endNoticeShown = false;
      if (!keepCurrentContent || !hasReadableContent) {
        _restoreReaderPosition(id);
      }

      final downloadedChapters =
          _storage.read<List<dynamic>>('downloadedChapters') ?? [];
      final downloadedChapter = downloadedChapters.firstWhereOrNull(
        (json) => json is Map && json['chapterId'] == id,
      );

      if (downloadedChapter != null) {
        isOffline.value = true;
        final localChapterRecords = downloadedChapters
            .where((item) => item is Map && item['comicId'] == arguments['comicId'])
            .cast<Map>()
            .toList();
        localChapterRecords.sort((left, right) {
          final leftNumber = _chapterNumber('${left['chapterTitle'] ?? ''}');
          final rightNumber = _chapterNumber('${right['chapterTitle'] ?? ''}');
          if (leftNumber == null && rightNumber == null) return 0;
          if (leftNumber == null) return 1;
          if (rightNumber == null) return -1;
          return rightNumber.compareTo(leftNumber);
        });
        final localIndex = localChapterRecords.indexWhere(
          (item) => item['chapterId'] == id,
        );
        final localPrevious = localIndex >= 0 &&
                localIndex + 1 < localChapterRecords.length
            ? '${localChapterRecords[localIndex + 1]['chapterId']}'
            : '';
        final localNext = localIndex > 0
            ? '${localChapterRecords[localIndex - 1]['chapterId']}'
            : null;
        final localNavigation = localChapterRecords
            .map((item) => ChapterElement(
                  chapterId: '${item['chapterId'] ?? ''}',
                  title: '${item['chapterTitle'] ?? ''}',
                  url: '${item['chapterId'] ?? ''}',
                ))
            .where((item) => item.chapterId.isNotEmpty)
            .toList(growable: false);
        final savedContent = '${downloadedChapter['content'] ?? ''}';
        if (isNovel || savedContent.isNotEmpty) {
          if (savedContent.trim().isEmpty) {
            throw StateError('لا يوجد نص محلي صالح لهذا الفصل.');
          }
          chapterData.value = ChapterData(
            chapter: DataChapter(
              chapterId: id,
              title: '${downloadedChapter['chapterTitle'] ?? id}',
              images: const [],
              content: savedContent,
              previousChapter: localPrevious,
              nextChapter: localNext,
              chapters: localNavigation,
            ),
            source: 'local',
          );
        } else {
          final paths = List<String>.from(downloadedChapter['localImagePaths'] ?? const [])
              .where((path) => File(path).existsSync()).toList()
            ..sort((left, right) => _pageNumber(left).compareTo(_pageNumber(right)));
          if (paths.isEmpty) throw StateError('لا توجد صفحات محلية صالحة لهذا الفصل.');
          localImages.assignAll(paths);
          chapterData.value = ChapterData(
            chapter: DataChapter(
              chapterId: id,
              title: '${downloadedChapter['chapterTitle'] ?? id}',
              images: localImages.toList(growable: false),
              previousChapter: localPrevious,
              nextChapter: localNext,
              chapters: localNavigation,
            ),
            source: 'local',
          );
        }
      } else {
        final loaded = isNovel
            ? await _comicService.fetchNovelChapter(id)
            : await _comicService.fetchChapter(id);
        if (generation != _chapterLoadGeneration) return;
        isOffline.value = false;
        final fallbackTitle = currentChapterTitle.trim();
        final title = loaded.chapter.title.trim().isEmpty ||
                loaded.chapter.title.trim() == 'الفصل' ||
                loaded.chapter.title.trim().toLowerCase() == 'chapter'
            ? fallbackTitle
            : loaded.chapter.title;
        chapterData.value = ChapterData(
          chapter: DataChapter(
            chapterId: loaded.chapter.chapterId,
            title: title,
            images: loaded.chapter.images,
            content: loaded.chapter.content,
            previousChapter: loaded.chapter.previousChapter,
            nextChapter: loaded.chapter.nextChapter,
            chapters: loaded.chapter.chapters,
          ),
          source: loaded.source,
        );
      }

      if (keepCurrentContent) _restoreReaderPosition(id);
      final pageCount = chapterData.value.chapter.images.length;
      if (startAtEnd) _suppressEndBoundaryOnce = true;
      if (pageCount > 0) {
        currentPage.value = startAtEnd
            ? pageCount - 1
            : currentPage.value.clamp(0, pageCount - 1).toInt();
        if (startAtEnd) _restoredScrollOffset = 0;
        if (isNovel || readerMode.value == 'scroll') {
          _pendingScrollRestore = startAtEnd ? double.maxFinite : _restoredScrollOffset;
        }
        final loadedTitle = chapterData.value.chapter.title.trim();
        if (loadedTitle.isNotEmpty &&
            loadedTitle.toLowerCase() != 'chapter' &&
            loadedTitle != 'الفصل') {
          currentChapterTitle = loadedTitle;
        }
        if (_pageController?.hasClients == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController?.hasClients == true) {
              _pageController!.jumpToPage(currentPage.value);
            }
          });
        }
      } else if (isNovel && chapterData.value.chapter.content.isNotEmpty) {
        if (startAtEnd) _restoredScrollOffset = 0;
        _pendingScrollRestore = startAtEnd ? double.maxFinite : _restoredScrollOffset;
        currentPage.value = 0;
      }
    } catch (error) {
      if (generation != _chapterLoadGeneration) return;
      hasError(true);
      loadIssue.value = ReaderLoadIssue.from(error);
      debugPrint('Chapter request failed: $error');
    } finally {
      if (generation == _chapterLoadGeneration) isLoading(false);
    }
  }

  int _pageNumber(String path) {
    final match = RegExp(r'page_(\d+)', caseSensitive: false).firstMatch(path);
    return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
  }

  String? get nextChapterId {
    final direct = _chapterReference(chapterData.value.chapter.nextChapter);
    if (direct != null && !_sameChapterReference(direct, chapterId)) return direct;
    return _adjacentChapter(forward: true)?.chapterId;
  }

  String? get previousChapterId {
    final direct = _chapterReference(chapterData.value.chapter.previousChapter);
    if (direct != null && !_sameChapterReference(direct, chapterId)) return direct;
    final adjacent = _adjacentChapter(forward: false)?.chapterId;
    if (adjacent != null && !_sameChapterReference(adjacent, chapterId)) {
      return adjacent;
    }
    return null;
  }

  ChapterElement? _adjacentChapter({required bool forward}) {
    final chapters = _navigationChapters;
    final revision = chapterNavigationRevision.value;
    if (!identical(_adjacentCacheSource, chapters) ||
        _adjacentCacheRevision != revision ||
        _adjacentCacheChapterId != chapterId ||
        _adjacentCacheTitle != currentChapterTitle) {
      _adjacentCacheSource = chapters;
      _adjacentCacheRevision = revision;
      _adjacentCacheChapterId = chapterId;
      _adjacentCacheTitle = currentChapterTitle;
      _cachedNextAdjacentChapter = null;
      _cachedPreviousAdjacentChapter = null;

      final index = chapters.indexWhere(isCurrentChapter);
      final currentNumber =
          (index >= 0 ? _chapterNumber(chapters[index].title) : null) ??
              _chapterNumber(currentChapterTitle);
      final chapterNumbers = chapters.map((item) => _chapterNumber(item.title)).toList();
      final hasUnnumberedOrDuplicate = chapterNumbers.any((number) => number == null) ||
          chapterNumbers.toSet().length != chapterNumbers.length;
      if (currentNumber != null && !hasUnnumberedOrDuplicate) {
        double? nextNumber;
        double? previousNumber;
        for (final item in chapters) {
          final number = _chapterNumber(item.title);
          if (number == null) continue;
          if (number > currentNumber &&
              (nextNumber == null || number < nextNumber)) {
            nextNumber = number;
            _cachedNextAdjacentChapter = item;
          } else if (number < currentNumber &&
              (previousNumber == null || number > previousNumber)) {
            previousNumber = number;
            _cachedPreviousAdjacentChapter = item;
          }
        }
      }

      if (index >= 0) {
        _cachedNextAdjacentChapter ??=
            index > 0 ? chapters[index - 1] : null;
        _cachedPreviousAdjacentChapter ??=
            index + 1 < chapters.length ? chapters[index + 1] : null;
      }
    }
    return forward
        ? _cachedNextAdjacentChapter
        : _cachedPreviousAdjacentChapter;
  }

  double? _chapterNumber(String title) {
    final explicit = RegExp(
      r'(?:chapter|chap\.?|ch\.?|الفصل|فصل)\s*[-#:]?\s*(\d+(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(title);
    if (explicit != null) return double.tryParse(explicit.group(1)!);
    final numbers = RegExp(r'\d+(?:\.\d+)?').allMatches(title).toList();
    // Multiple numbers can denote a volume, season, or release date; let the
    // source chapter-list ordering decide rather than jumping to a false neighbor.
    if (numbers.length != 1) return null;
    return double.tryParse(numbers.single.group(0)!);
  }

  String? _chapterReference(dynamic value) {
    if (value is Map) {
      for (final key in const [
        'url',
        'chapterUrl',
        'chapter_url',
        'chapterId',
        'chapter_id',
        'id',
      ]) {
        final reference = _chapterReference(value[key]);
        if (reference != null) return reference;
      }
      return null;
    }
    final reference = value?.toString().trim() ?? '';
    if (reference.isEmpty ||
        const {'null', 'undefined', '0'}.contains(reference.toLowerCase())) {
      return null;
    }
    final uri = Uri.tryParse(reference);
    if (uri == null) return null;
    if (uri.hasScheme) return reference;
    final base = Uri.tryParse(chapterId);
    if (base == null || !base.hasScheme) return null;
    return base.resolveUri(uri).toString();
  }

  String _chapterTitleFor(String id) {
    final chapter = availableChapters.firstWhereOrNull(
      (item) => _sameChapterReference(item.chapterId, id) ||
          _sameChapterReference(item.url, id),
    );
    return chapter?.title ?? '';
  }

  Future<void> navigateToChapter(String? id, {bool reverse = false}) async {
    final reference = _chapterReference(id);
    if (reference == null ||
        _sameChapterReference(reference, chapterId) ||
        isNavigating.value) {
      return;
    }
    isNavigating.value = true;
    final previousId = chapterId;
    final previousTitle = currentChapterTitle;
    final previousData = chapterData.value;
    final previousOffline = isOffline.value;
    final previousImages = localImages.toList(growable: false);
    final previousPage = currentPage.value;
    final previousOffset = _scrollController?.hasClients == true
        ? _scrollController!.offset
        : _restoredScrollOffset;
    final nextTitle = _chapterTitleFor(reference);
    endNoticeShown = false;
    try {
      if (novelSpeechPlaying.value || novelSpeechPaused.value) {
        await stopNovelSpeech();
      }
      chapterId = reference;
      currentChapterTitle = nextTitle;
      await fetchChapter(
        reference,
        keepCurrentContent: true,
        startAtEnd: reverse,
      );
      if (hasError.value || !hasReadableContent) {
        final issue = loadIssue.value;
        chapterId = previousId;
        currentChapterTitle = previousTitle;
        chapterData.value = previousData;
        isOffline.value = previousOffline;
        localImages.assignAll(previousImages);
        currentPage.value = previousPage;
        _restoredScrollOffset = previousOffset;
        _pendingScrollRestore = readerMode.value == 'scroll' ? previousOffset : null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController?.hasClients == true) {
            _pageController!.jumpToPage(previousPage);
          }
          if (_scrollController?.hasClients == true) {
            _scrollController!.jumpTo(previousOffset);
          }
        });
        hasError(false);
        loadIssue.value = null;
        AppFeedback.show(
          title: (issue?.titleKey ?? 'تعذر فتح الفصل').tr,
          message: (issue?.descriptionKey ?? 'حاول مرة أخرى').tr,
        );
        return;
      }
      await _markAsRead(chapterId, currentChapterTitle);
      unawaited(_prefetchAdjacentChapters());
    } catch (error) {
      chapterId = previousId;
      currentChapterTitle = previousTitle;
      chapterData.value = previousData;
      isOffline.value = previousOffline;
      localImages.assignAll(previousImages);
      currentPage.value = previousPage;
      _restoredScrollOffset = previousOffset;
      _pendingScrollRestore = readerMode.value == 'scroll' ? previousOffset : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController?.hasClients == true) {
          _pageController!.jumpToPage(previousPage);
        }
        if (_scrollController?.hasClients == true) {
          _scrollController!.jumpTo(previousOffset);
        }
      });
      hasError(false);
      final issue = loadIssue.value;
      debugPrint('Unable to navigate to chapter: $error');
      AppFeedback.show(
        title: (issue?.titleKey ?? 'تعذر فتح الفصل').tr,
        message: (issue?.descriptionKey ?? 'حاول مرة أخرى').tr,
      );
    } finally {
      isNavigating.value = false;
    }
  }

  void _readChapterNavigationArguments() {
    final raw = arguments['chapterNavigation'];
    if (raw is! Iterable) return;
    for (final value in raw) {
      if (value is ChapterElement) {
        if (value.chapterId.isNotEmpty) _argumentChapterNavigation.add(value);
        continue;
      }
      if (value is! Map) continue;
      final reference = _chapterReference(value);
      if (reference == null) continue;
      _argumentChapterNavigation.add(ChapterElement(
        chapterId: reference,
        title: '${value['title'] ?? ''}',
        url: reference,
      ));
    }
  }

  Future<void> _loadChapterNavigationIfMissing({
    bool checkEndAfterLoad = true,
  }) async {
    if (_isLoadingChapterNavigation) return;
    if (availableChapters.length > 1 &&
        _containsCurrentChapter(availableChapters)) {
      return;
    }
    final comicId = '${arguments['comicId'] ?? ''}'.trim();
    if (comicId.isEmpty) return;
    _isLoadingChapterNavigation = true;
    try {
      final details = await _comicService.fetchComicDetail(comicId);
      _fallbackChapterNavigation
        ..clear()
        ..addAll(details.comicDetail.chapters.map((item) {
          final reference = _chapterReference(item.chapterId) ??
              _chapterReference(item.link);
          return ChapterElement(
            chapterId: reference ?? '',
            title: item.title,
            url: reference ?? '',
          );
        }).where((item) => item.chapterId.isNotEmpty));
      chapterNavigationRevision.value++;
    } catch (error) {
      debugPrint('Unable to load chapter navigation list: $error');
    } finally {
      _isLoadingChapterNavigation = false;
      if (checkEndAfterLoad) {
        if (readerMode.value == 'paged' &&
            currentPage.value >= chapterData.value.chapter.images.length - 1) {
          onPageChanged(currentPage.value);
        } else if (readerMode.value == 'scroll' &&
            _scrollController?.hasClients == true) {
          unawaited(handleScroll(_scrollController!.position));
        }
      }
    }
  }

  void _restoreReaderPosition(String id) {
    final positions = _storage.read('readerPositions');
    final key = _readerPositionKey(id);
    final saved = positions is Map ? positions[key] : null;
    final savedPage = saved is Map ? saved['page'] : saved;
    final parsed = savedPage is num
        ? savedPage.toInt()
        : int.tryParse('$savedPage') ?? 0;
    final savedOffset = saved is Map ? saved['offset'] : null;
    final offset = savedOffset is num ? savedOffset.toDouble() : 0.0;
    _restoredScrollOffset = offset.isFinite && offset > 0 ? offset : 0;
    currentPage.value = parsed < 0 ? 0 : parsed;
  }

  String _readerPositionKey(String id) =>
      '${arguments['comicId'] ?? ''}::$id';

  Future<void> _persistReaderPosition(int page, {double? scrollOffset}) async {
    final currentChapterId = chapterData.value.chapter.chapterId.isEmpty
        ? chapterId
        : chapterData.value.chapter.chapterId;
    final key = _readerPositionKey(currentChapterId);
    final stored = _storage.read('readerPositions');
    final positions = stored is Map
        ? Map<String, dynamic>.from(stored)
        : <String, dynamic>{};
    positions[key] = {
      'page': page,
      'offset': scrollOffset ?? _restoredScrollOffset,
    };
    await _storage.write('readerPositions', positions);
  }

  void setCurrentPage(int page) {
    final pageCount = chapterData.value.chapter.images.length;
    if (pageCount == 0) return;
    final safePage = page.clamp(0, pageCount - 1).toInt();
    if (currentPage.value == safePage) return;
    currentPage.value = safePage;
    unawaited(_persistReaderPosition(safePage));
  }

  Future<void> ensureChapterNavigation() =>
      _loadChapterNavigationIfMissing(checkEndAfterLoad: false);

  void persistScrollOffset(double offset) {
    if (!offset.isFinite || offset < 0) return;
    _restoredScrollOffset = offset;
    final scroll = _scrollController;
    if (isNovel && scroll?.hasClients == true) {
      final maxExtent = scroll!.position.maxScrollExtent;
      novelProgress.value = maxExtent <= 0
          ? 0
          : (offset / maxExtent).clamp(0.0, 1.0).toDouble();
    }
    unawaited(_persistReaderPosition(currentPage.value, scrollOffset: offset));
  }

  void updateNovelProgress(double offset, double maxExtent) {
    if (!isNovel) return;
    novelProgress.value = maxExtent <= 0
        ? 0
        : (offset / maxExtent).clamp(0.0, 1.0).toDouble();
  }

  void syncScrollController() {
    final scroll = _scrollController;
    final targetOffset = _pendingScrollRestore;
    if (scroll?.hasClients != true || targetOffset == null) return;
    final position = scroll!.position;
    final target = targetOffset.clamp(0.0, position.maxScrollExtent).toDouble();
    if ((position.pixels - target).abs() > 1) scroll.jumpTo(target);
    _restoredScrollOffset = target;
    if (isNovel) {
      novelProgress.value = position.maxScrollExtent <= 0
          ? 0
          : (target / position.maxScrollExtent).clamp(0.0, 1.0).toDouble();
    }
    _pendingScrollRestore = null;
  }

  void _loadReaderPreferences() {
    readerFit.value = _storage.read<String>('reader_fit') ?? 'width';
    readerMode.value = _storage.read<String>(_readerSettingKey('mode')) ??
        _storage.read<String>('reader_mode') ??
        'scroll';
    readingDirection.value =
        _storage.read<String>(_readerSettingKey('direction')) ??
            _storage.read<String>('reader_direction') ??
            'rtl';
    continuousNavigation.value =
        _storage.read<bool>('reader_continuous_navigation') ?? true;
    novelFontSize.value =
        (_storage.read<num>(_readerSettingKey('novel_font_size')) ?? 19).toDouble();
    novelFontFamily.value =
        _storage.read<String>(_readerSettingKey('novel_font_family')) ?? 'default';
    novelBackground.value =
        _storage.read<String>(_readerSettingKey('novel_background')) ?? 'app';
    novelLineHeight.value =
        (_storage.read<num>(_readerSettingKey('novel_line_height')) ?? 1.85)
            .toDouble()
            .clamp(1.4, 2.3)
            .toDouble();
    novelParagraphSpacing.value =
        (_storage.read<num>(_readerSettingKey('novel_paragraph_spacing')) ?? 18)
            .toDouble()
            .clamp(8.0, 36.0)
            .toDouble();
    novelSpeechRate.value =
        (_storage.read<num>(_readerSettingKey('novel_speech_rate')) ?? 0.42)
            .toDouble()
            .clamp(0.25, 0.75)
            .toDouble();
    novelSpeechLanguage.value =
        _storage.read<String>(_readerSettingKey('novel_speech_language')) ??
            'ar-SA';
    final storedBookmarks =
        _storage.read<List<dynamic>>(_readerSettingKey('novel_bookmarks')) ?? [];
    novelBookmarks.assignAll(
      storedBookmarks
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item)),
    );
  }

  Future<void> setNovelFontSize(double value) async {
    novelFontSize.value = value.clamp(14.0, 30.0).toDouble();
    await _storage.write(
      _readerSettingKey('novel_font_size'),
      novelFontSize.value,
    );
  }

  Future<void> setNovelFontFamily(String value) async {
    novelFontFamily.value = value;
    await _storage.write(_readerSettingKey('novel_font_family'), value);
  }

  Future<void> setNovelBackground(String value) async {
    novelBackground.value = value;
    await _storage.write(_readerSettingKey('novel_background'), value);
  }

  Future<void> setNovelLineHeight(double value) async {
    novelLineHeight.value = value.clamp(1.4, 2.3).toDouble();
    await _storage.write(
      _readerSettingKey('novel_line_height'),
      novelLineHeight.value,
    );
  }

  Future<void> setNovelParagraphSpacing(double value) async {
    novelParagraphSpacing.value = value.clamp(8.0, 36.0).toDouble();
    await _storage.write(
      _readerSettingKey('novel_paragraph_spacing'),
      novelParagraphSpacing.value,
    );
  }

  Future<void> setNovelSpeechRate(double value) async {
    novelSpeechRate.value = value.clamp(0.25, 0.75).toDouble();
    await _storage.write(
      _readerSettingKey('novel_speech_rate'),
      novelSpeechRate.value,
    );
    if (novelSpeechPlaying.value) {
      try {
        await _flutterTts.setSpeechRate(novelSpeechRate.value);
      } catch (error) {
        debugPrint('Unable to update TTS rate: $error');
        _failNovelSpeech();
      }
    }
  }

  Future<void> setNovelSpeechLanguage(String value) async {
    if (value != 'ar-SA' && value != 'en-US') return;
    novelSpeechLanguage.value = value;
    await _storage.write(_readerSettingKey('novel_speech_language'), value);
    if (novelSpeechPlaying.value) {
      try {
        await _flutterTts.setLanguage(await _resolvedSpeechLanguage());
      } catch (error) {
        debugPrint('Unable to update TTS language: $error');
        _failNovelSpeech();
      }
    }
  }

  Future<String> _resolvedSpeechLanguage() async {
    final preferred = novelSpeechLanguage.value;
    final dynamic rawLanguages = await _flutterTts.getLanguages;
    if (rawLanguages is! Iterable) return preferred;
    final available = rawLanguages.map((value) => '$value').toList();
    final exact = available.firstWhereOrNull(
      (value) => value.toLowerCase() == preferred.toLowerCase(),
    );
    if (exact != null) return exact;
    final languageCode = preferred.split('-').first.toLowerCase();
    final regional = available.firstWhereOrNull(
      (value) => value.toLowerCase().startsWith('$languageCode-'),
    );
    if (regional != null) return regional;
    final baseLanguage = available.firstWhereOrNull(
      (value) => value.toLowerCase() == languageCode,
    );
    if (baseLanguage != null) return baseLanguage;
    throw StateError('Selected TTS language is not installed.');
  }

  void _configureNovelSpeech() {
    _flutterTts.setStartHandler(() {
      if (!_speechSessionActive) return;
      novelSpeechPlaying.value = true;
      novelSpeechPaused.value = false;
    });
    _flutterTts.setPauseHandler(() {
      if (!_speechSessionActive) return;
      novelSpeechPlaying.value = false;
      novelSpeechPaused.value = true;
    });
    _flutterTts.setContinueHandler(() {
      if (!_speechSessionActive) return;
      novelSpeechPlaying.value = true;
      novelSpeechPaused.value = false;
    });
    _flutterTts.setCompletionHandler(_onSpeechChunkCompleted);
    _flutterTts.setCancelHandler(() {
      if (_speechSessionActive) return;
      novelSpeechPlaying.value = false;
      novelSpeechPaused.value = false;
    });
    _flutterTts.setErrorHandler((_) {
      if (_speechSessionActive) _failNovelSpeech();
    });
  }

  Future<void> toggleNovelSpeech() async {
    if (!isNovel || chapterData.value.chapter.content.trim().isEmpty) return;
    if (novelSpeechPlaying.value) {
      novelSpeechPlaying.value = false;
      novelSpeechPaused.value = true;
      try {
        await _flutterTts.pause();
      } catch (_) {
        await stopNovelSpeech();
      }
      return;
    }
    if (novelSpeechPaused.value && _speechChunkIndex < _speechChunks.length) {
      novelSpeechPaused.value = false;
      novelSpeechPlaying.value = true;
      await _playSpeechChunk();
      return;
    }
    await _startNovelSpeech();
  }

  Future<void> _startNovelSpeech() async {
    _speechChunks = _splitSpeechText(chapterData.value.chapter.content);
    if (_speechChunks.isEmpty) return;
    _speechChunkIndex = 0;
    _speechSessionActive = true;
    novelSpeechPlaying.value = true;
    novelSpeechPaused.value = false;
    try {
      await _flutterTts.setLanguage(await _resolvedSpeechLanguage());
      await _flutterTts.setSpeechRate(novelSpeechRate.value);
      await _playSpeechChunk();
    } catch (error) {
      debugPrint('Novel TTS failed: $error');
      _failNovelSpeech();
    }
  }

  Future<void> _playSpeechChunk() async {
    if (!_speechSessionActive || _speechChunkIndex >= _speechChunks.length) {
      return;
    }
    try {
      final result = await _flutterTts.speak(_speechChunks[_speechChunkIndex]);
      if ((result is num && result != 1) || result == false || result == '0') {
        _failNovelSpeech();
      }
    } catch (error) {
      debugPrint('Novel TTS playback failed: $error');
      _failNovelSpeech();
    }
  }

  void _failNovelSpeech() {
    _speechSessionActive = false;
    novelSpeechPlaying.value = false;
    novelSpeechPaused.value = false;
    AppFeedback.show(
      title: 'تعذر تشغيل القراءة الصوتية'.tr,
      message: 'تحقق من تثبيت صوت اللغة المختارة على الجهاز'.tr,
    );
  }

  List<String> _splitSpeechText(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final word in words) {
      if (word.isEmpty) continue;
      final extraLength = word.length + (buffer.isEmpty ? 0 : 1);
      if (buffer.length + extraLength > 2500 && buffer.isNotEmpty) {
        chunks.add(buffer.toString());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(word);
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString());
    return chunks;
  }

  void _onSpeechChunkCompleted() {
    if (!_speechSessionActive || novelSpeechPaused.value) return;
    if (_speechChunkIndex + 1 < _speechChunks.length) {
      _speechChunkIndex++;
      unawaited(_playSpeechChunk());
      return;
    }
    _speechSessionActive = false;
    novelSpeechPlaying.value = false;
    novelSpeechPaused.value = false;
  }

  Future<void> stopNovelSpeech() async {
    _speechSessionActive = false;
    novelSpeechPlaying.value = false;
    novelSpeechPaused.value = false;
    _speechChunks = [];
    _speechChunkIndex = 0;
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  Future<void> saveNovelBookmark() async {
    if (!isNovel || chapterData.value.chapter.content.isEmpty) return;
    final offset = _scrollController?.hasClients == true
        ? _scrollController!.offset
        : _restoredScrollOffset;
    final maxExtent = _scrollController?.hasClients == true
        ? _scrollController!.position.maxScrollExtent
        : 0.0;
    final bookmark = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'chapterId': chapterId,
      'chapterTitle': chapterData.value.chapter.title.isNotEmpty
          ? chapterData.value.chapter.title
          : currentChapterTitle,
      'offset': offset,
      'progress': maxExtent <= 0
          ? 0.0
          : (offset / maxExtent).clamp(0.0, 1.0).toDouble(),
      'createdAt': DateTime.now().toIso8601String(),
    };
    novelBookmarks.insert(0, bookmark);
    await _storage.write(
      _readerSettingKey('novel_bookmarks'),
      novelBookmarks.toList(growable: false),
    );
  }

  Future<void> removeNovelBookmark(String id) async {
    novelBookmarks.removeWhere((bookmark) => '${bookmark['id']}' == id);
    await _storage.write(
      _readerSettingKey('novel_bookmarks'),
      novelBookmarks.toList(growable: false),
    );
  }

  Future<void> openNovelBookmark(Map<String, dynamic> bookmark) async {
    final targetChapter = '${bookmark['chapterId'] ?? ''}';
    final targetOffsetValue = bookmark['offset'];
    final targetOffset = targetOffsetValue is num
        ? targetOffsetValue.toDouble()
        : double.tryParse('$targetOffsetValue') ?? 0.0;
    if (targetChapter.isEmpty) return;
    if (!_sameChapterReference(targetChapter, chapterId)) {
      await navigateToChapter(targetChapter);
      if (!_sameChapterReference(targetChapter, chapterId)) return;
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
    }
    final scroll = _scrollController;
    if (scroll?.hasClients != true) return;
    final offset = targetOffset
        .clamp(0.0, scroll!.position.maxScrollExtent)
        .toDouble();
    scroll.jumpTo(offset);
    _restoredScrollOffset = offset;
    _pendingScrollRestore = null;
    updateNovelProgress(offset, scroll.position.maxScrollExtent);
    persistScrollOffset(offset);
  }

  Future<void> setReaderFit(String value) async {
    readerFit.value = value;
    await _storage.write('reader_fit', value);
  }

  Future<void> setReaderMode(String value) async {
    if (value != 'scroll' && value != 'paged') return;
    readerMode.value = value;
    if (value == 'paged' && _pageController?.hasClients == true) {
      _pageController!.jumpToPage(currentPage.value);
    }
    await _storage.write(_readerSettingKey('mode'), value);
  }

  void syncPageController() {
    final pageController = _pageController;
    if (pageController?.hasClients != true) return;
    final page = pageController!.page;
    if (page == null || page.round() != currentPage.value) {
      pageController.jumpToPage(currentPage.value);
    }
  }

  Future<void> setReadingDirection(String value) async {
    if (value != 'rtl' && value != 'ltr') return;
    readingDirection.value = value;
    await _storage.write(_readerSettingKey('direction'), value);
  }

  Future<void> setContinuousNavigation(bool value) async {
    continuousNavigation.value = value;
    await _storage.write('reader_continuous_navigation', value);
    if (!value) return;
    if (readerMode.value == 'paged') {
      onPageChanged(currentPage.value);
    } else if (_scrollController?.hasClients == true) {
      unawaited(handleScroll(_scrollController!.position));
    }
  }

  String _readerSettingKey(String setting) {
    final comicId = '${arguments['comicId'] ?? ''}'.trim();
    if (comicId.isEmpty) return 'reader_$setting';
    return 'reader_${setting}_${Uri.encodeComponent(comicId)}';
  }

  void onPageChanged(int page) {
    if (chapterData.value.chapter.images.isEmpty) return;
    setCurrentPage(page);
    if (_suppressEndBoundaryOnce &&
        page >= chapterData.value.chapter.images.length - 1) {
      _suppressEndBoundaryOnce = false;
      return;
    }
    if (readerMode.value == 'paged' &&
        continuousNavigation.value &&
        page >= chapterData.value.chapter.images.length - 2) {
      unawaited(prefetchChapter(nextChapterId));
    }
    if (readerMode.value != 'paged' ||
        !continuousNavigation.value ||
        isNavigating.value ||
        page < chapterData.value.chapter.images.length - 1) {
      return;
    }
    final next = nextChapterId;
    if (next != null) {
      navigateToChapter(next);
    } else if (!_isLoadingChapterNavigation) {
      _showEndNoticeOnce();
    }
  }

  Future<void> handleScroll(
    ScrollMetrics metrics, {
    double? scrollDelta,
  }) async {
    if (readerMode.value != 'scroll' || !continuousNavigation.value) return;
    final threshold = metrics.viewportDimension * 0.04 > 28
        ? metrics.viewportDimension * 0.04
        : 28.0;
    if (_suppressEndBoundaryOnce && metrics.extentAfter <= threshold) {
      _suppressEndBoundaryOnce = false;
      return;
    }
    if (isNavigating.value) return;
    if (metrics.extentAfter <= metrics.viewportDimension * 2) {
      unawaited(prefetchChapter(nextChapterId));
    }
    if (metrics.pixels <= threshold && (scrollDelta ?? 0) < -1) {
      final previous = previousChapterId;
      if (previous != null) {
        await navigateToChapter(previous, reverse: true);
        return;
      }
    }
    if (metrics.extentAfter > threshold) return;
    final next = nextChapterId;
    if (next != null) {
      navigateToChapter(next);
    } else if (!_isLoadingChapterNavigation) {
      _showEndNoticeOnce();
    }
  }

  void _showEndNoticeOnce() {
    if (endNoticeShown) return;
    endNoticeShown = true;
    AppFeedback.show(
      title: 'نهاية الفصل'.tr,
      message: 'لا توجد فصول أخرى'.tr,
    );
  }

  void toggleNavigationVisibility() {
    showNavigation.toggle();
    if (!showNavigation.value) showChapterList.value = false;
  }

  void beginReaderPointer(Offset position, Duration timeStamp) {
    _readerPointerDownPosition = position;
    _readerPointerDownTime = timeStamp;
    _readerPointerMoved = false;
  }

  void updateReaderPointer(Offset position) {
    final start = _readerPointerDownPosition;
    if (start != null && (position - start).distance > 14) {
      _readerPointerMoved = true;
    }
  }

  void endReaderPointer(Duration timeStamp) {
    final startedAt = _readerPointerDownTime;
    final elapsed = startedAt == null ? null : timeStamp - startedAt;
    final isTap = !_readerPointerMoved &&
        elapsed != null &&
        elapsed >= Duration.zero &&
        elapsed <= const Duration(milliseconds: 450);
    _readerPointerDownPosition = null;
    _readerPointerDownTime = null;
    _readerPointerMoved = false;
    if (isTap) toggleNavigationVisibility();
  }

  void cancelReaderPointer() {
    _readerPointerDownPosition = null;
    _readerPointerDownTime = null;
    _readerPointerMoved = false;
  }

  void toggleChapterListVisibility() {
    showChapterList.toggle();
    if (showChapterList.value) showNavigation.value = true;
  }

  @override
  void onInit() {
    super.onInit();
    _storage.listenKey('readChapters', (_) => chapterNavigationRevision.value++);
    _storage.listenKey('reading_history', (_) => chapterNavigationRevision.value++);
    _readChapterNavigationArguments();
    _loadReaderPreferences();
    _configureNovelSpeech();
    if (isNovel) {
      readerMode.value = 'scroll';
      showNavigation.value = true;
    }
    unawaited(fetchChapter(chapterId).then((_) async {
      if (!hasError.value && hasReadableContent) {
        await _markAsRead(chapterId, currentChapterTitle);
      }
      await _loadChapterNavigationIfMissing();
      unawaited(_prefetchAdjacentChapters());
    }));
  }

  @override
  void onClose() {
    unawaited(stopNovelSpeech());
    _pageController?.dispose();
    _scrollController?.dispose();
    super.onClose();
  }

  Future<void> _markAsRead(String id, String title) async {
    final readChapters = Map<String, dynamic>.from(
      _storage.read('readChapters') ?? <String, dynamic>{},
    );
    readChapters[id] = DateTime.now().toIso8601String();
    await _storage.write('readChapters', readChapters);
    chapterNavigationRevision.value++;
    final comicId = '${arguments['comicId'] ?? ''}';
    if (comicId.isEmpty || !Get.isRegistered<AppDataService>()) return;
    try {
      await Get.find<AppDataService>().addHistory(HistoryItem(
            comicId: comicId,
            title: '${arguments['comicTitle'] ?? ''}',
            coverImage: '${arguments['coverImage'] ?? ''}',
            chapterId: id,
            chapterTitle: title.isNotEmpty ? title : id,
            lastRead: DateTime.now(),
            type: '${arguments['comicType'] ?? 'manga'}',
          ));
    } catch (error) {
      debugPrint('Unable to sync reader history: $error');
    }
  }
}
