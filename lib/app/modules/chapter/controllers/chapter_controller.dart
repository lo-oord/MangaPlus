import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/core/utils/chapter_reference_identity.dart';
import 'package:mangaplus/app/core/utils/chapter_sequence.dart';
import 'package:mangaplus/app/core/utils/page_load_tracker.dart';
import 'package:mangaplus/app/core/utils/reader_boundary_guard.dart';
import 'package:mangaplus/app/core/utils/reader_chapter_anchors.dart';
import 'package:mangaplus/app/core/utils/reader_navigation_log.dart';
import 'package:mangaplus/app/core/utils/reader_progress.dart';
import 'package:mangaplus/app/core/utils/reader_chapter_navigator.dart';
import 'package:mangaplus/app/core/utils/reader_stream_merge.dart';
import 'package:mangaplus/app/data/models/history.dart';
import 'package:mangaplus/app/data/services/reading_stats_service.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';
import 'package:mangaplus/app/data/services/chapter_update_service.dart';
import 'package:mangaplus/app/data/services/comic_service.dart';
import 'package:mangaplus/app/core/utils/reader_load_issue.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

List<String> _splitNovelParagraphs(String content) => content
    .split(RegExp(r'\n+'))
    .map((paragraph) => paragraph.trim())
    .where((paragraph) => paragraph.isNotEmpty)
    .toList(growable: false);

class ChapterController extends GetxController with WidgetsBindingObserver {
  static const novelChapterDividerToken =
      '__MANGAPLUS_NOVEL_CHAPTER_DIVIDER__';

  static String novelChapterDividerMarker(String title) =>
      '$novelChapterDividerToken${Uri.encodeComponent(title.trim())}';

  static String titleFromNovelChapterDivider(String marker) {
    if (!marker.startsWith(novelChapterDividerToken)) return '';
    final encoded = marker.substring(novelChapterDividerToken.length);
    if (encoded.isEmpty) return '';
    try {
      return Uri.decodeComponent(encoded).trim();
    } on FormatException {
      return encoded.trim();
    }
  }

  final ComicService _comicService = ComicService();
  final FlutterTts _flutterTts = FlutterTts();
  final GetStorage _storage = GetStorage();
  final List<ChapterElement> _argumentChapterNavigation = [];
  final List<ChapterElement> _fallbackChapterNavigation = [];
  List<ReaderChapterPageRange> _readerChapterPageRanges = [];
  final Set<String> _prefetchingChapters = <String>{};
  final chapterNavigationRevision = 0.obs;
  List<ChapterElement>? _availableChaptersCache;
  List<ChapterElement>? _cachedLoadedChapterList;
  int _availableCacheRevision = -1;
  int _availableArgumentCount = -1;
  int _availableFallbackCount = -1;
  bool _availableCacheOffline = false;
  int _readChapterCacheRevision = -1;
  final Set<String> _readChapterIdentities = <String>{};
  ReadingSessionRef? _readingStatsSession;
  Timer? _readingStatsTimer;
  Stopwatch? _readingStatsIdleStopwatch;
  Stopwatch? _readingStatsClock;
  Future<void> _readingStatsQueue = Future<void>.value();
  bool _readingStatsEngaged = false;

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
  bool _continuousPrependPending = false;
  double _continuousPrependBaseExtent = 0;
  double _continuousPrependOffset = 0;

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
  final readerProgress = 0.0.obs;
  final readerFit = 'width'.obs;
  final readerMode = 'scroll'.obs;
  final readingDirection = 'rtl'.obs;
  final continuousNavigation = true.obs;
  final showChapterTitle = true.obs;
  final isNavigating = false.obs;
  final novelFontSize = 19.0.obs;
  final novelFontFamily = 'default'.obs;
  final novelBackground = 'app'.obs;
  final novelLineHeight = 1.85.obs;
  final novelParagraphSpacing = 18.0.obs;
  final novelProgress = 0.0.obs;
  final readerBookmarks = <Map<String, dynamic>>[].obs;
  RxList<Map<String, dynamic>> get novelBookmarks => readerBookmarks;
  final novelSpeechPlaying = false.obs;
  final novelSpeechPaused = false.obs;
  final novelSpeechRate = 0.42.obs;
  final novelSpeechLanguage = 'ar-SA'.obs;
  List<String> _speechChunks = [];
  int _speechChunkIndex = 0;
  bool _speechSessionActive = false;
  final novelSpeechCurrentParagraph = (-1).obs;
  final novelSpeechCurrentWord = ''.obs;
  final List<int> _speechChunkParagraphIndexes = <int>[];
  bool endNoticeShown = false;
  bool _isLoadingChapterNavigation = false;
  bool _novelStreamAppendOlder = false;
  int _chapterLoadGeneration = 0;
  bool _suppressEndBoundaryOnce = false;

  /// Guards automatic end-of-content transitions: one per reader motion, never
  /// for layout changes or for the frame a transition lands on.
  final ReaderBoundaryGuard _boundaryGuard = ReaderBoundaryGuard();

  /// Chapter boundaries inside a merged novel stream, so navigation follows
  /// the chapter the reader is looking at instead of the last merged one.
  ReaderChapterAnchors _novelAnchors = ReaderChapterAnchors.single('');
  String? _pendingPrependChapterId;

  /// Identifies the transition currently being applied. An older transition
  /// must never write reader state after a newer one started.
  int _transitionGeneration = 0;
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

  List<ReaderChapterPageRange> get readerChapterPageRanges =>
      List<ReaderChapterPageRange>.unmodifiable(_readerChapterPageRanges);

  ReaderChapterPageRange? get activeReaderPageRange =>
      _readerChapterPageRanges.firstWhereOrNull(
        (range) => range.contains(currentPage.value),
      );

  String get activeReaderChapterId {
    if (isNovel) {
      final anchored = _novelAnchors.activeChapterId(_currentScrollOffset);
      if (anchored != null && anchored.trim().isNotEmpty) return anchored;
      final id = chapterData.value.chapter.chapterId.trim();
      return id.isEmpty ? chapterId : id;
    }
    return activeReaderPageRange?.chapterId ?? chapterId;
  }

  double get _currentScrollOffset =>
      _scrollController?.hasClients == true
          ? _scrollController!.offset
          : _restoredScrollOffset;

  /// The chapter the reader is actually looking at.
  ///
  /// In continuous mode the merged stream keeps several chapters, and
  /// `chapterId` points at the newest one that was merged in. Adjacency must be
  /// resolved from this anchor: otherwise "next" starts from a chapter further
  /// ahead and skips everything in between, while "previous" re-merges content
  /// that is already on screen.
  String get _navigationAnchorId {
    final active = activeReaderChapterId.trim();
    return active.isEmpty ? chapterId : active;
  }

  List<Map<String, dynamic>> get activeChapterBookmarks =>
      readerBookmarks
          .where((bookmark) =>
              _sameChapterReference(
                '${bookmark['chapterId'] ?? ''}',
                activeReaderChapterId,
              ))
          .toList(growable: false);

  Map<String, dynamic>? bookmarkForChapter(String id) =>
      readerBookmarks.firstWhereOrNull((bookmark) =>
          _sameChapterReference('${bookmark['chapterId'] ?? ''}', id));

  String chapterDividerTitle(String reference) {
    final chapter = availableChapters.firstWhereOrNull(
      (item) => _sameChapterReference(item.chapterId, reference) ||
          _sameChapterReference(item.url, reference),
    );
    final title = chapter?.title.trim() ?? '';
    final number = _chapterNumber(title) ?? _chapterNumber(reference);
    if (number != null) {
      final formatted = number == number.roundToDouble()
          ? number.toInt().toString()
          : number.toString();
      return '${'الفصل'.tr} $formatted';
    }
    return title.isEmpty ? 'الفصل'.tr : title;
  }

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

  bool _sameChapterReference(String left, String right) =>
      ChapterReferenceIdentity.matches(
        left,
        right,
        baseReference: chapterId,
      );

  String _chapterIdentity(String reference) =>
      ChapterReferenceIdentity.identity(
        reference,
        baseReference: chapterId,
      );

  bool _containsCurrentChapter(List<ChapterElement> chapters) {
    final anchor = _navigationAnchorId;
    return chapters.any(
      (item) =>
          _sameChapterReference(item.chapterId, anchor) ||
          _sameChapterReference(item.url, anchor),
    );
  }

  /// Whether [item] is the chapter the reader is looking at right now.
  ///
  /// In a merged stream `chapterId` is the newest chapter that was merged in,
  /// which is not necessarily the one on screen; marking the wrong row as
  /// current also made the visible chapter look tappable while a tap on it did
  /// nothing.
  bool isCurrentChapter(ChapterElement item) {
    final anchor = _navigationAnchorId;
    return _sameChapterReference(item.chapterId, anchor) ||
        _sameChapterReference(item.url, anchor);
  }

  // ---------------------------------------------------------------------
  // Real page load progress
  // ---------------------------------------------------------------------

  final PageLoadTracker _pageLoads = PageLoadTracker();
  final Map<int, int> _pageRetryTokens = <int, int>{};
  Timer? _pageLoadHideTimer;

  /// Bumped whenever a page finishes, fails or is retried.
  final pageLoadRevision = 0.obs;

  /// Whether the small loading chip should be visible.
  final showPageLoadProgress = false.obs;

  int get totalPageCount => _pageLoads.total;
  int get loadedPageCount => _pageLoads.loadedCount;
  int get failedPageCount => _pageLoads.failedCount;
  double? get pageLoadProgress =>
      _pageLoads.hasPages ? _pageLoads.progress : null;

  bool isPageLoaded(int index) => _pageLoads.isLoaded(index);
  bool isPageFailed(int index) => _pageLoads.isFailed(index);
  int pageRetryToken(int index) => _pageRetryTokens[index] ?? 0;

  bool _isCurrentPageReference(int index, String? pageReference) {
    if (!_pageLoads.isValid(index)) return false;
    if (pageReference == null) return true;
    final images = chapterData.value.chapter.images;
    return index < images.length && images[index] == pageReference;
  }

  void markPageLoaded(int index, {String? pageReference}) {
    if (!_pageLoads.hasPages || _pageLoads.isLoaded(index)) return;
    if (!_isCurrentPageReference(index, pageReference)) return;
    _pageLoads.markLoaded(index);
    _pageRetryTokens.remove(index);
    pageLoadRevision.value++;
    if (_pageLoads.isComplete) {
      _schedulePageLoadHide(const Duration(milliseconds: 900));
    }
  }

  void markPageFailed(int index, {String? pageReference}) {
    if (!_pageLoads.hasPages || _pageLoads.isLoaded(index)) return;
    if (!_isCurrentPageReference(index, pageReference)) return;
    if (_pageLoads.isFailed(index)) return;
    _pageLoads.markFailed(index);
    pageLoadRevision.value++;
  }

  void retryPage(int index, {String? pageReference}) {
    if (!_pageLoads.hasPages || !_pageLoads.isValid(index)) return;
    if (!_isCurrentPageReference(index, pageReference)) return;
    _pageLoads.retry(index);
    _pageRetryTokens[index] = (_pageRetryTokens[index] ?? 0) + 1;
    pageLoadRevision.value++;
    showPageLoadProgress.value = true;
    _schedulePageLoadHide(const Duration(seconds: 6));
  }

  void _beginPageLoads(int total) {
    _pageLoadHideTimer?.cancel();
    _pageLoads.reset(total);
    _pageRetryTokens.clear();
    pageLoadRevision.value++;
    showPageLoadProgress.value = total > 0;
    if (total > 0) _schedulePageLoadHide(const Duration(seconds: 6));
  }

  void _expandPageLoads(int total) {
    if (total <= _pageLoads.total) return;
    _pageLoads.expandTo(total);
    pageLoadRevision.value++;
  }

  void _schedulePageLoadHide(Duration delay) {
    _pageLoadHideTimer?.cancel();
    _pageLoadHideTimer = Timer(delay, () {
      showPageLoadProgress.value = false;
    });
  }

  /// Loads [id] into the reader.
  ///
  /// Returns whether the data that is now in [chapterData] belongs to [id]. A
  /// superseded load (the reader moved on, or a retry started a newer request)
  /// returns false without touching the reader, so a caller can never merge a
  /// chapter it did not get.
  Future<bool> fetchChapter(
    String id, {
    bool keepCurrentContent = false,
    bool startAtEnd = false,
    bool restoreSavedPosition = true,
    bool resetStreamAnchors = true,
  }) async {
    final generation = ++_chapterLoadGeneration;
    ReaderNavigationLog.log('load', {
      'chapter': id,
      'request': generation,
      'keepContent': keepCurrentContent,
      'startAtEnd': startAtEnd,
    });
    try {
      isLoading(true);
      hasError(false);
      loadIssue.value = null;
      endNoticeShown = false;
      if (restoreSavedPosition && (!keepCurrentContent || !hasReadableContent)) {
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
        if (generation != _chapterLoadGeneration) return false;
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

      if (restoreSavedPosition && keepCurrentContent) _restoreReaderPosition(id);
      final pageCount = chapterData.value.chapter.images.length;
      if (!keepCurrentContent) _beginPageLoads(pageCount);
      if (startAtEnd) _suppressEndBoundaryOnce = true;
      if (pageCount > 0) {
        if (restoreSavedPosition) {
          _readerChapterPageRanges = [
            ReaderChapterPageRange(
              chapterId: chapterData.value.chapter.chapterId.isEmpty
                  ? id
                  : chapterData.value.chapter.chapterId,
              startIndex: 0,
              pageCount: pageCount,
            ),
          ];
        }
        currentPage.value = startAtEnd
            ? pageCount - 1
            : currentPage.value.clamp(0, pageCount - 1).toInt();
        final initialRange = _readerChapterPageRanges.firstWhereOrNull(
          (range) => range.contains(currentPage.value),
        );
        readerProgress.value = ReaderProgress.page(
          pageIndex: currentPage.value,
          pageCount: pageCount,
          range: initialRange,
        );
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
      final loadedChapterId = chapterData.value.chapter.chapterId.isEmpty
          ? id
          : chapterData.value.chapter.chapterId;
      if (!keepCurrentContent && resetStreamAnchors) {
        _novelAnchors.reset(loadedChapterId);
        _pendingPrependChapterId = null;
      }
      // The content that just arrived is a landing, not a reader motion: the
      // page/scroll notifications it causes must not start another transition.
      _boundaryGuard.onTransitionCompleted(
        landingPage: isNovel ? null : currentPage.value,
      );
      if (!hasError.value && hasReadableContent) {
        await _enqueueReadingStats(() async {
          final comicId = '${arguments['comicId'] ?? ''}'.trim();
          final currentSession = _readingStatsSession;
          if (comicId.isEmpty ||
              currentSession == null ||
              currentSession.comicId != comicId ||
              currentSession.chapterId != id) {
            await _replaceReadingStatsSession(id, currentChapterTitle);
          }
        });
      }
      return true;
    } catch (error) {
      if (generation != _chapterLoadGeneration) return false;
      hasError(true);
      loadIssue.value = ReaderLoadIssue.from(error);
      _beginPageLoads(0);
      debugPrint('Chapter request failed: $error');
      return false;
    } finally {
      if (generation == _chapterLoadGeneration) isLoading(false);
    }
  }

  int _pageNumber(String path) {
    final match = RegExp(r'page_(\d+)', caseSensitive: false).firstMatch(path);
    return match == null ? 0 : int.tryParse(match.group(1)!) ?? 0;
  }

  String? get nextChapterId => _adjacentChapterId(forward: true);

  String? get previousChapterId => _adjacentChapterId(forward: false);

  String? _adjacentChapterId({required bool forward}) {
    final anchor = _navigationAnchorId;
    final target = _adjacentChapter(forward: forward)?.chapterId;
    if (target != null && !_sameChapterReference(target, anchor)) {
      return target;
    }
    final chapters = _navigationChapters;
    // A source list that contains the current chapter is authoritative. Its
    // end is the end of the work; falling back to the source's own links there
    // used to send the reader to whatever chapter the source linked to (often
    // the newest one) instead of stopping.
    if (chapters.isNotEmpty && _containsCurrentChapter(chapters)) return null;
    final direct = _chapterReference(
      forward
          ? chapterData.value.chapter.nextChapter
          : chapterData.value.chapter.previousChapter,
    );
    if (direct != null && !_sameChapterReference(direct, anchor)) return direct;
    return null;
  }

  ChapterElement? _adjacentChapter({required bool forward}) {
    final anchor = _navigationAnchorId;
    final anchorTitle = _chapterTitleFor(anchor).trim();
    return ReaderChapterNavigator.adjacentChapter(
      chapters: _navigationChapters,
      currentChapterId: anchor,
      currentChapterTitle:
          anchorTitle.isNotEmpty ? anchorTitle : currentChapterTitle,
      forward: forward,
      declaredNextChapter: _chapterReference(
        chapterData.value.chapter.nextChapter,
      ),
      declaredPreviousChapter: _chapterReference(
        chapterData.value.chapter.previousChapter,
      ),
    );
  }

  double? _chapterNumber(String title) =>
      ChapterSequence.chapterNumber(title);

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

  String _chapterTitleForDivider({
    required String rawTitle,
    required String fallbackTitle,
    required String reference,
  }) {
    final raw = rawTitle.trim();
    if (raw.isNotEmpty && raw.toLowerCase() != 'chapter' && raw != 'الفصل') {
      return raw;
    }
    final listed = _chapterTitleFor(reference).trim();
    if (listed.isNotEmpty) return listed;
    if (fallbackTitle.trim().isNotEmpty) return fallbackTitle.trim();
    return chapterDividerTitle(reference);
  }

  /// Opens [id] as the next chapter the reader is on.
  ///
  /// The transition is atomic: the target is resolved once from the chapter the
  /// reader is looking at, a second transition cannot start while one is
  /// running, and a result that no longer belongs to the current transition is
  /// discarded instead of being written into the reader.
  Future<void> navigateToChapter(
    String? id, {
    bool reverse = false,
    bool joinContinuousStream = false,
  }) async {
    final reference = _chapterReference(id);
    final anchorId = _navigationAnchorId;
    if (reference == null || isNavigating.value) {
      ReaderNavigationLog.log('transition-ignored', {
        'target': id,
        'reason': reference == null
            ? 'invalid-reference'
            : 'transition-in-flight',
        'reader': isNovel ? 'novel' : 'manga',
      });
      return;
    }
    if (_sameChapterReference(reference, anchorId)) {
      ReaderNavigationLog.log('transition-ignored', {
        'target': reference,
        'reason': 'already-on-chapter',
      });
      return;
    }
    // The target can already be part of the merged stream (continuous reading
    // appended or prepended it). Moving there must not load or merge it again:
    // re-merging duplicated pages and skipped the chapters in between.
    final streamPosition = _streamPositionOf(reference);
    if (streamPosition != null) {
      ReaderNavigationLog.log('seek-within-stream', {
        'reader': isNovel ? 'novel' : 'manga',
        'target': reference,
        'page': streamPosition.pageIndex,
        'offset': streamPosition.offset,
      });
      await _seekWithinStream(streamPosition);
      return;
    }
    final transition = ++_transitionGeneration;
    isNavigating.value = true;
    final previousId = chapterId;
    final previousTitle = currentChapterTitle;
    final currentNextAdjacentId = nextChapterId;
    final previousAdjacentId = previousChapterId;
    final appendingOlderNovelChapter = isNovel &&
        !reverse &&
        (_novelStreamAppendOlder ||
            (currentNextAdjacentId == null &&
                previousAdjacentId != null &&
                _sameChapterReference(id?.toString() ?? '', previousAdjacentId)));
    if (!joinContinuousStream && isNovel) _novelStreamAppendOlder = false;
    if (!joinContinuousStream) _continuousPrependPending = false;
    final previousData = chapterData.value;
    final previousOffline = isOffline.value;
    final previousImages = localImages.toList(growable: false);
    final previousPageRanges = List<ReaderChapterPageRange>.of(
      _readerChapterPageRanges,
    );
    final previousPage = currentPage.value;
    final previousOffset = _scrollController?.hasClients == true
        ? _scrollController!.offset
        : _restoredScrollOffset;
    final previousScrollExtent = _scrollController?.hasClients == true
        ? _scrollController!.position.maxScrollExtent
        : 0.0;
    final previousAnchors = _novelAnchors.copy();
    final previousPendingPrepend = _pendingPrependChapterId;
    final previousPrependPending = _continuousPrependPending;
    final previousPrependBaseExtent = _continuousPrependBaseExtent;
    final previousPrependOffset = _continuousPrependOffset;

    // Every failure path (network, empty content, superseded load) must leave
    // the reader exactly as it was, never with a chapter title that does not
    // match the content below it.
    void restorePreviousState() {
      chapterId = previousId;
      currentChapterTitle = previousTitle;
      chapterData.value = previousData;
      isOffline.value = previousOffline;
      localImages.assignAll(previousImages);
      _readerChapterPageRanges =
          List<ReaderChapterPageRange>.of(previousPageRanges);
      _novelAnchors = previousAnchors;
      _pendingPrependChapterId = previousPendingPrepend;
      _continuousPrependPending = previousPrependPending;
      _continuousPrependBaseExtent = previousPrependBaseExtent;
      _continuousPrependOffset = previousPrependOffset;
      currentPage.value = previousPage;
      _restoredScrollOffset = previousOffset;
      _pendingScrollRestore =
          readerMode.value == 'scroll' ? previousOffset : null;
      hasError(false);
      loadIssue.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController?.hasClients == true) {
          _pageController!.jumpToPage(previousPage);
        }
        if (_scrollController?.hasClients == true) {
          _scrollController!.jumpTo(previousOffset);
        }
      });
    }

    // Merging a chapter that is already rendered would duplicate it, so a
    // rendered target always opens as a standalone chapter in that case.
    final targetAlreadyRendered = _chapterIsRendered(reference);
    final keepContinuousStream = joinContinuousStream &&
        !targetAlreadyRendered &&
        (readerMode.value == 'scroll' || readerMode.value == 'paged') &&
        continuousNavigation.value &&
        (isNovel
            ? previousData.chapter.content.trim().isNotEmpty
            : previousData.chapter.images.isNotEmpty);
    final listedTitle = _chapterTitleFor(reference).trim();
    final nextTitle = listedTitle.isEmpty
        ? chapterDividerTitle(reference)
        : listedTitle;
    endNoticeShown = false;
    try {
      if (novelSpeechPlaying.value || novelSpeechPaused.value) {
        await stopNovelSpeech();
      }
      chapterId = reference;
      currentChapterTitle = nextTitle;
      // Continuous scroll transitions keep already rendered pages in place.
      // The adjacent chapter is fetched first, then its pages are joined to the
      // same ListView so the boundary has no blank/loading frame.
      if (!keepContinuousStream) {
        chapterData.value = ChapterData(
          chapter: DataChapter(
            chapterId: reference,
            title: nextTitle,
            images: const [],
            content: '',
            previousChapter: '',
            nextChapter: null,
            chapters: const [],
          ),
          source: '',
        );
      }
      final loaded = await fetchChapter(
        reference,
        keepCurrentContent: false,
        startAtEnd: reverse && !keepContinuousStream,
        restoreSavedPosition: !keepContinuousStream,
        // A merged stream keeps the chapters already on screen, so their
        // boundaries must survive while the new one is recorded below.
        resetStreamAnchors: !keepContinuousStream,
      );
      if (transition != _transitionGeneration) {
        // A newer transition owns the reader now: this one must neither merge
        // its stale data nor roll the newer state back.
        ReaderNavigationLog.log('transition-stale', {
          'target': reference,
          'transition': transition,
          'latest': _transitionGeneration,
        });
        return;
      }
      if (!loaded) {
        final issue = loadIssue.value;
        // A superseded load is not an error: a newer request owns the reader,
        // so leave it untouched. A real failure restores the previous chapter.
        if (hasError.value) {
          restorePreviousState();
          AppFeedback.show(
            title: (issue?.titleKey ?? 'تعذر فتح الفصل').tr,
            message: (issue?.descriptionKey ?? 'حاول مرة أخرى').tr,
          );
        }
        return;
      }
      if (hasReadableContent && keepContinuousStream) {
        final adjacent = chapterData.value;
        final oldChapter = previousData.chapter;
        final newChapter = adjacent.chapter;
        if (isNovel) {
          final dividerTitle = reverse
              ? _chapterTitleForDivider(
                  rawTitle: oldChapter.title,
                  fallbackTitle: previousTitle,
                  reference: previousId,
                )
              : _chapterTitleForDivider(
                  rawTitle: newChapter.title,
                  fallbackTitle: nextTitle,
                  reference: reference,
                );
          final dividerMarker = novelChapterDividerMarker(dividerTitle);
          final separator = '\n\n$dividerMarker\n\n';
          final mergedContent = reverse
              ? '${newChapter.content}$separator${oldChapter.content}'
              : '${oldChapter.content}$separator${newChapter.content}';
          chapterData.value = previousData;
          final oldParagraphs = await paragraphsFor(oldChapter.content);
          final adjacentParagraphs =
              await compute(_splitNovelParagraphs, newChapter.content);
          final mergedParagraphs = reverse
              ? <String>[
                  ...adjacentParagraphs,
                  dividerMarker,
                  ...oldParagraphs,
                ]
              : <String>[
                  ...oldParagraphs,
                  dividerMarker,
                  ...adjacentParagraphs,
                ];
          _paragraphSource = mergedContent;
          _paragraphsFuture = Future<List<String>>.value(mergedParagraphs);
          if (!reverse) _novelStreamAppendOlder = appendingOlderNovelChapter;
          final mergedNovelChapterId =
              newChapter.chapterId.isEmpty ? reference : newChapter.chapterId;
          chapterData.value = ChapterData(
            chapter: DataChapter(
              chapterId: mergedNovelChapterId,
              title: newChapter.title.isEmpty ? nextTitle : newChapter.title,
              images: const [],
              content: mergedContent,
              previousChapter: reverse
                  ? newChapter.previousChapter
                  : appendingOlderNovelChapter
                      ? oldChapter.nextChapter ?? ''
                      : oldChapter.previousChapter,
              nextChapter: reverse
                  ? oldChapter.nextChapter
                  : appendingOlderNovelChapter
                      ? newChapter.previousChapter
                      : newChapter.nextChapter,
              chapters: newChapter.chapters.isNotEmpty
                  ? newChapter.chapters
                  : oldChapter.chapters,
            ),
            source: adjacent.source.isEmpty ? previousData.source : adjacent.source,
          );
          // Record where this chapter starts inside the merged text so the
          // navigation anchor follows the text the reader actually sees.
          if (reverse) {
            _pendingPrependChapterId = mergedNovelChapterId;
            if (_scrollController?.hasClients != true) {
              _novelAnchors.prepend(
                chapterId: mergedNovelChapterId,
                addedExtent: 0,
              );
              _pendingPrependChapterId = null;
            }
          } else {
            _novelAnchors.append(
              chapterId: mergedNovelChapterId,
              boundaryOffset:
                  previousScrollExtent > 0 ? previousScrollExtent : previousOffset,
            );
          }
        } else {
          final mergedStream = mergeReaderStreamPages(
            currentPages: oldChapter.images,
            adjacentPages: newChapter.images,
            currentRanges: previousPageRanges,
            adjacentChapterId: newChapter.chapterId.isEmpty
                ? reference
                : newChapter.chapterId,
            currentPage: previousPage,
            prepend: reverse,
            pagedReader: readerMode.value == 'paged',
          );
          _readerChapterPageRanges = mergedStream.chapterRanges;
          chapterData.value = ChapterData(
            chapter: DataChapter(
              chapterId: newChapter.chapterId.isEmpty ? reference : newChapter.chapterId,
              title: newChapter.title.isEmpty ? nextTitle : newChapter.title,
              images: mergedStream.pages,
              previousChapter: reverse
                  ? newChapter.previousChapter
                  : oldChapter.previousChapter,
              nextChapter: reverse
                  ? oldChapter.nextChapter
                  : newChapter.nextChapter,
              chapters: newChapter.chapters.isNotEmpty
                  ? newChapter.chapters
                  : oldChapter.chapters,
            ),
            source: adjacent.source.isEmpty ? previousData.source : adjacent.source,
          );
          currentPage.value = mergedStream.currentPage;
          // Appending keeps the pages already loaded; prepending inserts pages
          // above them, so the tracker is restarted for a truthful ratio.
          if (reverse) {
            _beginPageLoads(mergedStream.pages.length);
          } else {
            _expandPageLoads(mergedStream.pages.length);
          }
        }
        if (reverse && readerMode.value == 'scroll') {
          _continuousPrependPending = true;
          _continuousPrependBaseExtent = previousScrollExtent;
          _continuousPrependOffset = previousOffset;
          _pendingScrollRestore = null;
        } else if (readerMode.value == 'scroll') {
          _continuousPrependPending = false;
          _pendingScrollRestore = previousOffset;
        } else {
          _continuousPrependPending = false;
          _continuousPrependBaseExtent = 0;
          _continuousPrependOffset = 0;
          _pendingScrollRestore = null;
        }
      }
      if (!hasReadableContent) {
        final issue = loadIssue.value;
        restorePreviousState();
        AppFeedback.show(
          title: (issue?.titleKey ?? 'تعذر فتح الفصل').tr,
          message: (issue?.descriptionKey ?? 'حاول مرة أخرى').tr,
        );
        return;
      }
      _boundaryGuard.onTransitionCompleted(
        landingPage: isNovel ? null : currentPage.value,
      );
      await _markAsRead(chapterId, currentChapterTitle);
      unawaited(_prefetchAdjacentChapters());
      ReaderNavigationLog.log('transition-complete', {
        'reader': isNovel ? 'novel' : 'manga',
        'chapter': chapterId,
        'page': currentPage.value,
        'stream': _readerChapterPageRanges.length,
        'anchors': _novelAnchors.anchors.length,
      });
    } catch (error) {
      final issue = loadIssue.value;
      debugPrint('Unable to navigate to chapter: $error');
      restorePreviousState();
      AppFeedback.show(
        title: (issue?.titleKey ?? 'تعذر فتح الفصل').tr,
        message: (issue?.descriptionKey ?? 'حاول مرة أخرى').tr,
      );
    } finally {
      isNavigating.value = false;
    }
  }

  bool _chapterIsRendered(String reference) {
    if (isNovel) return _novelAnchors.contains(reference);
    return _readerChapterPageRanges
        .any((item) => _sameChapterReference(item.chapterId, reference));
  }

  /// Where [reference] already sits inside the merged reader stream, if it is
  /// there at all.
  _ReaderStreamPosition? _streamPositionOf(String reference) {
    if (isNovel) {
      final offset = _novelAnchors.offsetOf(reference);
      return offset == null ? null : _ReaderStreamPosition(offset: offset);
    }
    final range = _readerChapterPageRanges.firstWhereOrNull(
      (item) => _sameChapterReference(item.chapterId, reference),
    );
    if (range == null) return null;
    // A list of pages can only be addressed directly in the paged reader; in
    // scroll mode the pages are laid out by the view, so a fresh load is the
    // honest way to open the chapter.
    if (readerMode.value != 'paged') return null;
    return _ReaderStreamPosition(pageIndex: range.startIndex);
  }

  Future<void> _seekWithinStream(_ReaderStreamPosition position) async {
    isNavigating.value = true;
    try {
      final page = position.pageIndex;
      if (page != null && readerMode.value == 'paged') {
        setCurrentPage(page);
        if (_pageController?.hasClients == true) {
          _pageController!.jumpToPage(page);
        }
        _boundaryGuard.onTransitionCompleted(landingPage: page);
        return;
      }
      final scroll = _scrollController;
      final offset = position.offset;
      if (scroll?.hasClients == true && offset != null) {
        final target =
            offset.clamp(0.0, scroll!.position.maxScrollExtent).toDouble();
        scroll.jumpTo(target);
        _restoredScrollOffset = target;
        _pendingScrollRestore = null;
      }
      _boundaryGuard.onTransitionCompleted();
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

  Future<void> _loadChapterNavigationIfMissing() async {
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
      // The list finishing is not a reader action. Replaying the last page or
      // scroll position here used to open the next chapter by itself while the
      // reader was simply sitting at the end of the current one. Only re-arm
      // the end-of-chapter notice so the next real flip/scroll can move.
      endNoticeShown = false;
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
    final pageRange = _readerChapterPageRanges.firstWhereOrNull(
      (range) => range.contains(page),
    );
    final currentChapterId = pageRange?.chapterId ??
        (chapterData.value.chapter.chapterId.isEmpty
            ? chapterId
            : chapterData.value.chapter.chapterId);
    final chapterPage = pageRange == null ? page : page - pageRange.startIndex;
    final key = _readerPositionKey(currentChapterId);
    final stored = _storage.read('readerPositions');
    final positions = stored is Map
        ? Map<String, dynamic>.from(stored)
        : <String, dynamic>{};
    positions[key] = {
      'page': chapterPage,
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
    final range = _readerChapterPageRanges.firstWhereOrNull(
      (item) => item.contains(safePage),
    );
    readerProgress.value = ReaderProgress.page(
      pageIndex: safePage,
      pageCount: pageCount,
      range: range,
    );
    unawaited(_persistReaderPosition(safePage));
  }

  void updateImageScrollProgress(int page, double fractionWithinPage) {
    final pageCount = chapterData.value.chapter.images.length;
    if (pageCount == 0) return;
    final safePage = page.clamp(0, pageCount - 1).toInt();
    if (currentPage.value != safePage) setCurrentPage(safePage);
    final range = _readerChapterPageRanges.firstWhereOrNull(
      (item) => item.contains(safePage),
    );
    readerProgress.value = ReaderProgress.page(
      pageIndex: safePage,
      pageCount: pageCount,
      range: range,
      fractionWithinPage: fractionWithinPage,
    );
  }

  void seekReaderProgress(double value) {
    final progress = value.isFinite
        ? value.clamp(0.0, 1.0).toDouble()
        : 0.0;
    if (isNovel || readerMode.value == 'scroll') {
      final scroll = _scrollController;
      if (scroll?.hasClients != true) return;
      final position = scroll!.position;
      final target = (progress * position.maxScrollExtent)
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      scroll.jumpTo(target);
      if (isNovel) updateNovelProgress(target, position.maxScrollExtent);
      return;
    }

    final pageCount = chapterData.value.chapter.images.length;
    if (pageCount == 0) return;
    final range = activeReaderPageRange;
    final page = ReaderProgress.pageAt(
      progress: progress,
      pageCount: pageCount,
      range: range,
    );
    if (_pageController?.hasClients == true) {
      _pageController!.jumpToPage(page);
    }
    // A seek is not a reader flip: landing on the last page must not open the
    // next chapter by itself.
    _boundaryGuard.onTransitionCompleted(landingPage: page);
    onPageChanged(page);
  }

  void persistReaderProgress() {
    if (isNovel || readerMode.value == 'scroll') {
      final scroll = _scrollController;
      if (scroll?.hasClients == true) {
        persistScrollOffset(scroll!.position.pixels);
      }
      return;
    }
    unawaited(_persistReaderPosition(currentPage.value));
  }

  Future<void> ensureChapterNavigation() => _loadChapterNavigationIfMissing();

  void persistScrollOffset(double offset) {
    if (!offset.isFinite || offset < 0) return;
    _restoredScrollOffset = offset;
    final scroll = _scrollController;
    if (isNovel && scroll?.hasClients == true) {
      final maxExtent = scroll!.position.maxScrollExtent;
      updateNovelProgress(offset, maxExtent);
    }
    unawaited(_persistReaderPosition(currentPage.value, scrollOffset: offset));
  }

  void updateNovelProgress(double offset, double maxExtent) {
    if (!isNovel) return;
    novelProgress.value = ReaderProgress.scroll(
      offset: offset,
      maxExtent: maxExtent,
    );
    readerProgress.value = novelProgress.value;
  }

  void syncScrollController() {
    final scroll = _scrollController;
    if (scroll?.hasClients != true) return;
    final position = scroll!.position;
    if (_continuousPrependPending && readerMode.value == 'scroll') {
      final addedExtent =
          (position.maxScrollExtent - _continuousPrependBaseExtent).clamp(0.0, double.infinity);
      final target = (_continuousPrependOffset + addedExtent)
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      // Content was inserted above: every recorded chapter boundary moves down
      // by the same amount, and the newly merged chapter starts at the top.
      final prependedChapterId = _pendingPrependChapterId;
      if (prependedChapterId != null && prependedChapterId.isNotEmpty) {
        _novelAnchors.prepend(
          chapterId: prependedChapterId,
          addedExtent: addedExtent,
        );
        _pendingPrependChapterId = null;
      }
      if ((position.pixels - target).abs() > 1) scroll.jumpTo(target);
      _restoredScrollOffset = target;
      _continuousPrependPending = false;
      _continuousPrependBaseExtent = 0;
      _continuousPrependOffset = 0;
      return;
    }
    final targetOffset = _pendingScrollRestore;
    if (targetOffset == null) return;
    final target = targetOffset.clamp(0.0, position.maxScrollExtent).toDouble();
    if ((position.pixels - target).abs() > 1) scroll.jumpTo(target);
    _restoredScrollOffset = target;
    if (isNovel) {
      updateNovelProgress(target, position.maxScrollExtent);
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
        _storage.read<bool>(_readerSettingKey('continuous_navigation')) ??
            _storage.read<bool>('reader_continuous_navigation') ??
            true;
    showChapterTitle.value =
        _storage.read<bool>(_readerSettingKey('show_chapter_title')) ?? true;
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
    final storedBookmarks = _storage.read<List<dynamic>>(
          _readerSettingKey('bookmarks'),
        ) ??
        (isNovel
            ? _storage.read<List<dynamic>>(
                  _readerSettingKey('novel_bookmarks'),
                ) ??
                []
            : <dynamic>[]);
    readerBookmarks.assignAll(
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
    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      if (!_speechSessionActive || word.trim().isEmpty) return;
      novelSpeechCurrentWord.value = word.trim();
    });
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
      if (_speechChunkIndex < _speechChunkParagraphIndexes.length) {
        novelSpeechCurrentParagraph.value =
            _speechChunkParagraphIndexes[_speechChunkIndex];
      }
      novelSpeechCurrentWord.value = '';
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
    novelSpeechCurrentParagraph.value = -1;
    novelSpeechCurrentWord.value = '';
    AppFeedback.show(
      title: 'تعذر تشغيل القراءة الصوتية'.tr,
      message: 'تحقق من تثبيت صوت اللغة المختارة على الجهاز'.tr,
    );
  }

  List<String> _splitSpeechText(String value) {
    final chunks = <String>[];
    _speechChunkParagraphIndexes.clear();
    final paragraphs = _splitNovelParagraphs(value);
    for (var paragraphIndex = 0; paragraphIndex < paragraphs.length; paragraphIndex++) {
      if (paragraphs[paragraphIndex] == novelChapterDividerToken) continue;
      final buffer = StringBuffer();
      for (final word in paragraphs[paragraphIndex].split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        final extraLength = word.length + (buffer.isEmpty ? 0 : 1);
        if (buffer.length + extraLength > 2500 && buffer.isNotEmpty) {
          chunks.add(buffer.toString());
          _speechChunkParagraphIndexes.add(paragraphIndex);
          buffer.clear();
        }
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(word);
      }
      if (buffer.isNotEmpty) {
        chunks.add(buffer.toString());
        _speechChunkParagraphIndexes.add(paragraphIndex);
      }
    }
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
    novelSpeechCurrentParagraph.value = -1;
    novelSpeechCurrentWord.value = '';
  }

  Future<void> stopNovelSpeech() async {
    _speechSessionActive = false;
    novelSpeechPlaying.value = false;
    novelSpeechPaused.value = false;
    _speechChunks = [];
    _speechChunkParagraphIndexes.clear();
    _speechChunkIndex = 0;
    novelSpeechCurrentParagraph.value = -1;
    novelSpeechCurrentWord.value = '';
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  Future<void> saveReaderBookmark() async {
    if (!hasReadableContent) return;
    final offset = _scrollController?.hasClients == true
        ? _scrollController!.offset
        : _restoredScrollOffset;
    final range = activeReaderPageRange;
    final page = range == null
        ? currentPage.value
        : (currentPage.value - range.startIndex).clamp(0, range.pageCount - 1);
    final chapterReference = activeReaderChapterId;
    final progress = readerProgress.value.clamp(0.0, 1.0).toDouble();
    final chapter = availableChapters.firstWhereOrNull((item) =>
        _sameChapterReference(item.chapterId, chapterReference) ||
        _sameChapterReference(item.url, chapterReference));
    final bookmark = <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'chapterId': chapterReference,
      'chapterTitle': chapter?.title.isNotEmpty == true
          ? chapter!.title
          : chapterData.value.chapter.title.isNotEmpty
              ? chapterData.value.chapter.title
              : currentChapterTitle,
      'page': page,
      'offset': offset,
      'progress': progress,
      'readerMode': isNovel ? 'novel' : readerMode.value,
      'createdAt': DateTime.now().toIso8601String(),
    };
    readerBookmarks.insert(0, bookmark);
    await _persistReaderBookmarks();
  }

  Future<void> _persistReaderBookmarks() async {
    final saved = readerBookmarks.toList(growable: false);
    await _storage.write(_readerSettingKey('bookmarks'), saved);
    // Keep old novel bookmarks readable by previous app versions.
    if (isNovel) {
      await _storage.write(_readerSettingKey('novel_bookmarks'), saved);
    }
  }

  Future<void> removeReaderBookmark(String id) async {
    readerBookmarks.removeWhere((bookmark) => '${bookmark['id']}' == id);
    await _persistReaderBookmarks();
  }

  Future<void> openReaderBookmark(Map<String, dynamic> bookmark) async {
    final targetChapter = '${bookmark['chapterId'] ?? ''}';
    if (targetChapter.isEmpty) return;

    var targetRange = _readerChapterPageRanges.firstWhereOrNull((range) =>
        _sameChapterReference(range.chapterId, targetChapter));
    final isInLoadedStream = isNovel
        ? _sameChapterReference(targetChapter, activeReaderChapterId)
        : targetRange != null;
    if (!isInLoadedStream &&
        !_sameChapterReference(targetChapter, activeReaderChapterId)) {
      await navigateToChapter(targetChapter);
      if (!_sameChapterReference(targetChapter, chapterId)) return;
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;
      targetRange = _readerChapterPageRanges.firstWhereOrNull((range) =>
          _sameChapterReference(range.chapterId, targetChapter));
    }

    if (isNovel || readerMode.value == 'scroll') {
      final scroll = _scrollController;
      if (scroll?.hasClients != true) return;
      final savedProgressValue = bookmark['progress'];
      final savedProgress = savedProgressValue is num
          ? savedProgressValue.toDouble()
          : double.tryParse('$savedProgressValue') ?? 0.0;
      final savedOffsetValue = bookmark['offset'];
      final savedOffset = savedOffsetValue is num
          ? savedOffsetValue.toDouble()
          : double.tryParse('$savedOffsetValue') ?? 0.0;
      final preserveStreamOffset = isInLoadedStream &&
          savedOffset.isFinite &&
          savedOffset >= 0;
      final position = scroll!.position;
      final offset = (preserveStreamOffset
              ? savedOffset
              : savedProgress.clamp(0.0, 1.0) * position.maxScrollExtent)
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      scroll.jumpTo(offset);
      _restoredScrollOffset = offset;
      _pendingScrollRestore = null;
      if (isNovel) updateNovelProgress(offset, position.maxScrollExtent);
      readerProgress.value = savedProgress.clamp(0.0, 1.0).toDouble();
      persistScrollOffset(offset);
      return;
    }

    final pageValue = bookmark['page'];
    final localPage = pageValue is num
        ? pageValue.toInt()
        : int.tryParse('$pageValue') ?? 0;
    final targetPage = (targetRange == null
            ? localPage
            : targetRange.startIndex + localPage)
        .clamp(0, chapterData.value.chapter.images.length - 1)
        .toInt();
    if (_pageController?.hasClients == true) {
      _pageController!.jumpToPage(targetPage);
    }
    _boundaryGuard.onTransitionCompleted(landingPage: targetPage);
    onPageChanged(targetPage);
  }

  Future<void> saveNovelBookmark() => saveReaderBookmark();
  Future<void> removeNovelBookmark(String id) => removeReaderBookmark(id);
  Future<void> openNovelBookmark(Map<String, dynamic> bookmark) =>
      openReaderBookmark(bookmark);

  Future<void> setReaderFit(String value) async {
    readerFit.value = value;
    await _storage.write('reader_fit', value);
  }

  Future<void> setReaderMode(String value) async {
    if (value != 'scroll' && value != 'paged') return;
    if (readerMode.value != value) {
      _continuousPrependPending = false;
      _continuousPrependBaseExtent = 0;
      _continuousPrependOffset = 0;
      _pendingScrollRestore = null;
    }
    readerMode.value = value;
    if (value == 'paged' && _pageController?.hasClients == true) {
      _boundaryGuard.onTransitionCompleted(landingPage: currentPage.value);
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
    await _storage.write(_readerSettingKey('continuous_navigation'), value);
    await _storage.write('reader_continuous_navigation', value);
    if (!value) return;
    unawaited(_loadChapterNavigationIfMissing());
    if (readerMode.value == 'paged') {
      onPageChanged(currentPage.value);
    } else if (_scrollController?.hasClients == true) {
      unawaited(handleScroll(_scrollController!.position));
    }
  }

  Future<void> setShowChapterTitle(bool value) async {
    showChapterTitle.value = value;
    await _storage.write(_readerSettingKey('show_chapter_title'), value);
  }

  String _readerSettingKey(String setting) {
    final comicId = '${arguments['comicId'] ?? ''}'.trim();
    if (comicId.isEmpty) return 'reader_$setting';
    return 'reader_${setting}_${Uri.encodeComponent(comicId)}';
  }

  void onPageChanged(int page) {
    if (chapterData.value.chapter.images.isEmpty) return;
    if (page != currentPage.value) {
      final count = chapterData.value.chapter.images.length;
      final range = _readerChapterPageRanges.firstWhereOrNull(
        (item) => item.contains(page),
      );
      final progress = ReaderProgress.page(
        pageIndex: page,
        pageCount: count,
        range: range,
      );
      _recordReadingActivity(
        progress,
        chapterCompleted: progress >= .80,
      );
    }
    setCurrentPage(page);
    final range = _readerChapterPageRanges.firstWhereOrNull(
      (item) => item.contains(currentPage.value),
    );
    readerProgress.value = ReaderProgress.page(
      pageIndex: currentPage.value,
      pageCount: chapterData.value.chapter.images.length,
      range: range,
    );
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
        isNavigating.value) {
      return;
    }
    // Advancing needs an actual flip into the last page. Landing there after a
    // transition, a rebuild or a programmatic jump is not a reader action, and
    // re-reporting the same page must not consume another chapter.
    final move = _boundaryGuard.consumePageBoundary(
      page,
      chapterData.value.chapter.images.length,
    );
    if (move != ReaderBoundaryMove.forward) return;
    final next = nextChapterId;
    if (next != null) {
      ReaderNavigationLog.log('auto-next', {
        'reader': 'manga-paged',
        'from': _navigationAnchorId,
        'to': next,
        'page': page,
      });
      navigateToChapter(next, joinContinuousStream: true);
    } else if (!_isLoadingChapterNavigation) {
      _showEndNoticeOnce();
    }
  }

  Future<void> handleScroll(
    ScrollMetrics metrics, {
    double? scrollDelta,
    bool userInitiated = false,
    bool settled = false,
  }) async {
    if (userInitiated && scrollDelta != null && scrollDelta.abs() >= 2) {
      final progress = isNovel
          ? ReaderProgress.scroll(
              offset: metrics.pixels,
              maxExtent: metrics.maxScrollExtent,
            )
          : readerProgress.value;
      _recordReadingActivity(
        progress,
        chapterCompleted: progress >= .80,
      );
    }
    if (userInitiated) {
      // Only a reader gesture arms an automatic chapter change. Restoring an
      // offset, re-syncing a controller or laying out merged content does not.
      _boundaryGuard.onUserMotion();
    }
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
    if (settled) {
      _boundaryGuard.onScrollSettled(
        atEdge: metrics.extentAfter <= threshold || metrics.pixels <= threshold,
      );
    }
    final move = _boundaryGuard.consumeScrollEdge(
      atStart: metrics.pixels <= threshold && (scrollDelta ?? 0) < -1,
      atEnd: metrics.extentAfter <= threshold,
    );
    if (move == ReaderBoundaryMove.backward) {
      final previous = previousChapterId;
      if (previous != null) {
        ReaderNavigationLog.log('auto-previous', {
          'reader': isNovel ? 'novel' : 'manga-scroll',
          'from': _navigationAnchorId,
          'to': previous,
        });
        await navigateToChapter(
          previous,
          reverse: true,
          joinContinuousStream: true,
        );
        return;
      }
    }
    if (move != ReaderBoundaryMove.forward) return;
    final next = nextChapterId;
    if (next != null) {
      ReaderNavigationLog.log('auto-next', {
        'reader': isNovel ? 'novel' : 'manga-scroll',
        'from': _navigationAnchorId,
        'to': next,
      });
      navigateToChapter(next, joinContinuousStream: true);
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
    WidgetsBinding.instance.addObserver(this);
    _storage.listenKey('readChapters', (_) => chapterNavigationRevision.value++);
    _storage.listenKey('reading_history', (_) => chapterNavigationRevision.value++);
    _readChapterNavigationArguments();
    _loadReaderPreferences();
    _configureNovelSpeech();
    _novelAnchors = ReaderChapterAnchors.single(chapterId);
    if (isNovel) {
      readerMode.value = 'scroll';
      showNavigation.value = true;
    }
    unawaited(fetchChapter(chapterId).then((loaded) async {
      if (loaded && hasReadableContent) {
        await _markAsRead(chapterId, currentChapterTitle);
      }
      await _loadChapterNavigationIfMissing();
      unawaited(_prefetchAdjacentChapters());
    }));
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_enqueueReadingStats(_finishReadingStatsSession));
    unawaited(stopNovelSpeech());
    _pageLoadHideTimer?.cancel();
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
    final comicId = '${arguments['comicId'] ?? ''}';
    if (comicId.isNotEmpty && Get.isRegistered<ChapterUpdateService>()) {
      await Get.find<ChapterUpdateService>().markChapterRead(comicId, id);
    }
    chapterNavigationRevision.value++;
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

  Future<void> _replaceReadingStatsSession(String id, String title) async {
    if (!Get.isRegistered<ReadingStatsService>()) return;
    await _finishReadingStatsSession();
    final comicId = '${arguments['comicId'] ?? ''}'.trim();
    if (comicId.isEmpty) return;
    final uri = Uri.tryParse(comicId);
    final service = Get.find<ReadingStatsService>();
    _readingStatsSession = await service.beginSession(
      comicId: comicId,
      sourceId: uri?.host.isNotEmpty == true ? uri!.host : 'unknown',
      title: '${arguments['comicTitle'] ?? ''}',
      coverImage: '${arguments['coverImage'] ?? ''}',
      type: '${arguments['comicType'] ?? 'manga'}',
      chapterId: id,
      chapterTitle: title.isNotEmpty ? title : id,
    );
  }

  void _recordReadingActivity(
    double progress, {
    bool chapterCompleted = false,
  }) {
    unawaited(_enqueueReadingStats(
      () => _ensureReadingStatsSession(progress, chapterCompleted),
    ));
  }

  Future<void> _enqueueReadingStats(Future<void> Function() operation) {
    _readingStatsQueue = _readingStatsQueue.then((_) => operation()).catchError(
      (Object error) {
        debugPrint('Reading statistics operation failed: $error');
      },
    );
    return _readingStatsQueue;
  }

  Future<void> _ensureReadingStatsSession(
    double progress,
    bool chapterCompleted,
  ) async {
    if (!Get.isRegistered<ReadingStatsService>()) return;
    final idleBeforeActivity = _readingStatsIdleStopwatch;
    if (_readingStatsEngaged &&
        idleBeforeActivity != null &&
        idleBeforeActivity.elapsed >= const Duration(minutes: 2)) {
      await _finishReadingStatsSession();
    }
    if (_readingStatsSession == null) {
      await _replaceReadingStatsSession(chapterId, currentChapterTitle);
    }
    final session = _readingStatsSession;
    if (session == null) return;
    final service = Get.find<ReadingStatsService>();
    if (!_readingStatsEngaged) {
      _readingStatsEngaged = true;
      _readingStatsIdleStopwatch = Stopwatch()
        ..reset()
        ..start();
      _readingStatsClock = Stopwatch()..start();
      _readingStatsTimer?.cancel();
      _readingStatsTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        unawaited(_enqueueReadingStats(_tickReadingStats));
      });
    } else {
      await _flushReadingStatsSeconds();
      _readingStatsIdleStopwatch!
        ..reset()
        ..start();
      _readingStatsClock!
        ..reset()
        ..start();
    }
    await service.recordProgress(
      session,
      progress,
      chapterCompleted: chapterCompleted,
    );
  }

  Future<void> _tickReadingStats() async {
    final session = _readingStatsSession;
    final idle = _readingStatsIdleStopwatch;
    if (session == null || !_readingStatsEngaged || idle == null) return;
    await _flushReadingStatsSeconds();
    if (idle.elapsed >= const Duration(minutes: 2)) {
      await _finishReadingStatsSession();
    }
  }

  Future<void> _flushReadingStatsSeconds() async {
    final session = _readingStatsSession;
    final idle = _readingStatsIdleStopwatch;
    final clock = _readingStatsClock;
    if (session == null || idle == null || clock == null || !clock.isRunning) return;
    final elapsedMilliseconds = clock.elapsedMilliseconds;
    if (elapsedMilliseconds <= 0) return;
    final idleStartMilliseconds = idle.elapsedMilliseconds - elapsedMilliseconds;
    final remainingGraceMilliseconds =
        const Duration(minutes: 2).inMilliseconds - idleStartMilliseconds;
    var seconds = elapsedMilliseconds ~/ Duration.millisecondsPerSecond;
    final graceSeconds = remainingGraceMilliseconds <= 0
        ? 0
        : (remainingGraceMilliseconds + Duration.millisecondsPerSecond - 1) ~/
            Duration.millisecondsPerSecond;
    if (seconds > 30) seconds = 30;
    if (seconds > graceSeconds) seconds = graceSeconds;
    if (seconds > 0 && Get.isRegistered<ReadingStatsService>()) {
      await Get.find<ReadingStatsService>().addActiveSeconds(
        session,
        seconds,
        localTime: DateTime.now(),
      );
    }
    clock
      ..reset()
      ..start();
  }

  Future<void> _finishReadingStatsSession() async {
    await _flushReadingStatsSeconds();
    _readingStatsTimer?.cancel();
    _readingStatsTimer = null;
    _readingStatsIdleStopwatch?.stop();
    _readingStatsIdleStopwatch = null;
    _readingStatsClock?.stop();
    _readingStatsClock = null;
    _readingStatsEngaged = false;
    final session = _readingStatsSession;
    _readingStatsSession = null;
    if (session != null && Get.isRegistered<ReadingStatsService>()) {
      try {
        await Get.find<ReadingStatsService>().finishSession(session);
      } catch (error) {
        debugPrint('Unable to close reading session: $error');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_enqueueReadingStats(_finishReadingStatsSession));
    }
  }
}

/// A chapter that is already rendered inside the merged reader stream.
class _ReaderStreamPosition {
  const _ReaderStreamPosition({this.pageIndex, this.offset});

  /// First page of the chapter in the merged page list (paged manga reader).
  final int? pageIndex;

  /// Scroll offset where the chapter starts (merged novel stream).
  final double? offset;
}
