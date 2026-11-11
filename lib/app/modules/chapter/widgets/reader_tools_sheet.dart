import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/reader/novel_reader_model.dart';
import 'package:mangaplus/app/core/reader/reader_image_source.dart';
import 'package:mangaplus/app/data/models/chapter.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';

Future<void> openReaderTools(
  BuildContext context, {
  required Future<void> Function(int page) onJumpToPage,
  required Future<void> Function(int paragraph) onJumpToParagraph,
  required int Function() currentNovelParagraph,
}) {
  return Get.bottomSheet(
    _ReaderToolsSheet(
      onJumpToPage: onJumpToPage,
      onJumpToParagraph: onJumpToParagraph,
      currentNovelParagraph: currentNovelParagraph,
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _ReaderToolsSheet extends StatefulWidget {
  const _ReaderToolsSheet({
    required this.onJumpToPage,
    required this.onJumpToParagraph,
    required this.currentNovelParagraph,
  });

  final Future<void> Function(int page) onJumpToPage;
  final Future<void> Function(int paragraph) onJumpToParagraph;
  final int Function() currentNovelParagraph;

  @override
  State<_ReaderToolsSheet> createState() => _ReaderToolsSheetState();
}

class _ReaderToolsSheetState extends State<_ReaderToolsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);
  ChapterController get c => Get.find<ChapterController>();

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * .78;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: AppColors.divider.withValues(alpha: .6)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.isNovel ? 'أدوات الرواية' : 'أدوات المانجا',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Obx(() => Text(
                              '${c.currentChapterTitle} • ${(c.readerProgress.value * 100).round()}%',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            )),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: Get.back,
                    icon: Icon(Icons.close_rounded, color: AppColors.icon),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppColors.divider,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
              tabs: const [
                Tab(text: 'العرض'),
                Tab(text: 'التنقل'),
                Tab(text: 'المظهر'),
                Tab(text: 'الأداء'),
                Tab(text: 'المزيد'),
              ],
            ),
            Expanded(
              child: Obx(
                () => TabBarView(
                  controller: _tabs,
                  children: [
                    _displayTab(),
                    _navigationTab(),
                    _appearanceTab(),
                    _performanceTab(),
                    _moreTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------

  Widget _displayTab() {
    return _tabList([
      _section('وضع القراءة', Icons.menu_book_rounded),
      if (c.isNovel)
        _hint('قارئ الروايات يعرض النص في وضع تمرير مستمر مع تنسيق مستقل.')
      else ...[
        _choices([
          _chip('تمرير مستمر', c.readerMode.value == 'scroll',
              () => c.setReaderMode('scroll')),
          _chip('صفحة بصفحة', c.readerMode.value == 'paged',
              () => c.setReaderMode('paged')),
        ]),
        _section('ملاءمة الصفحات', Icons.aspect_ratio_rounded),
        _choices([
          _chip('عرض الشاشة', c.readerFit.value == 'width',
              () => c.setReaderFit('width')),
          _chip('ارتفاع الشاشة', c.readerFit.value == 'height',
              () => c.setReaderFit('height')),
          _chip('ملاءمة كاملة', c.readerFit.value == 'screen',
              () => c.setReaderFit('screen')),
          _chip('حجم الصورة', c.readerFit.value == 'natural',
              () => c.setReaderFit('natural')),
        ]),
        _slider(
          title: 'المسافة بين الصفحات',
          value: c.readerPageGap.value,
          min: 0,
          max: 24,
          divisions: 12,
          label: '${c.readerPageGap.value.round()} px',
          onChanged: c.setReaderPageGap,
        ),
        _switchTile(
          title: 'وضع الصفحتين',
          subtitle: 'صفحتان متجاورتان على الشاشات العريضة',
          value: c.readerDoublePage.value,
          onChanged: c.setReaderDoublePage,
        ),
      ],
      _switchTile(
        title: 'الانتقال التلقائي بين الفصول',
        subtitle: 'تحميل الفصل المجاور مسبقاً عند الاقتراب من النهاية',
        value: c.continuousNavigation.value,
        onChanged: c.setContinuousNavigation,
      ),
      _switchTile(
        title: 'إظهار اسم الفصل بين الفصول',
        subtitle: 'يبقى الفاصل ظاهراً عند إخفاء الاسم',
        value: c.showChapterTitle.value,
        onChanged: c.setShowChapterTitle,
      ),
    ]);
  }

  Widget _navigationTab() {
    final ranges = c.readerChapterPageRanges;
    return _tabList([
      _section('داخل الفصل', Icons.swap_vert_rounded),
      Row(
        children: [
          Expanded(
            child: _actionCard(
              icon: Icons.first_page_rounded,
              label: 'أول الفصل',
              onTap: () => widget.onJumpToPage(
                c.activeReaderPageRange?.startIndex ?? 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionCard(
              icon: Icons.last_page_rounded,
              label: 'آخر الفصل',
              onTap: () => widget.onJumpToPage(
                (c.activeReaderPageRange?.endIndex ??
                        c.chapterData.value.chapter.images.length) -
                    1,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _actionCard(
              icon: Icons.grid_view_rounded,
              label: 'مصغرات الصفحات',
              onTap: () => _openPageGrid(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionCard(
              icon: Icons.pin_rounded,
              label: 'صفحة محددة',
              onTap: _openPagePicker,
            ),
          ),
        ],
      ),
      _section('الفصول', Icons.layers_rounded),
      Row(
        children: [
          Expanded(
            child: _actionCard(
              icon: Icons.chevron_right_rounded,
              label: 'الفصل التالي',
              enabled: c.nextChapterId != null,
              onTap: () => _goChapter(c.nextChapterId, reverse: false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionCard(
              icon: Icons.chevron_left_rounded,
              label: 'الفصل السابق',
              enabled: c.previousChapterId != null,
              onTap: () => _goChapter(c.previousChapterId, reverse: true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _actionCard(
        icon: Icons.format_list_numbered_rounded,
        label: 'قائمة الفصول الكاملة',
        onTap: () => _openChapterList(context),
      ),
      if (ranges.length > 1) ...[
        _section('الفصول المدمجة في القارئ', Icons.link_rounded),
        for (final range in ranges)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.circle, size: 8, color: AppColors.primary),
            title: Text(
              c.chapterDividerTitle(range.chapterId),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            ),
            subtitle: Text(
              '${range.startIndex + 1} – ${range.endIndex}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            onTap: () => widget.onJumpToPage(range.startIndex),
          ),
      ],
    ]);
  }

  Widget _appearanceTab() {
    return _tabList([
      if (c.isNovel) ...[
        _section('ثيم القراءة', Icons.palette_outlined),
        _choices([
          _chip('حسب التطبيق', c.novelBackground.value == 'app',
              () => c.setNovelBackground('app')),
          _chip('فاتح', c.novelBackground.value == 'light',
              () => c.setNovelBackground('light')),
          _chip('ورقي', c.novelBackground.value == 'sepia',
              () => c.setNovelBackground('sepia')),
          _chip('داكن', c.novelBackground.value == 'dark',
              () => c.setNovelBackground('dark')),
          _chip('أسود', c.novelBackground.value == 'black',
              () => c.setNovelBackground('black')),
        ]),
        _slider(
          title: 'حجم الخط',
          value: c.novelFontSize.value,
          min: 14,
          max: 30,
          divisions: 16,
          label: '${c.novelFontSize.value.round()}',
          onChanged: c.setNovelFontSize,
        ),
        _slider(
          title: 'سماكة الخط',
          value: c.novelFontWeight.value.toDouble(),
          min: 300,
          max: 800,
          divisions: 5,
          label: '${c.novelFontWeight.value}',
          onChanged: (value) => c.setNovelFontWeight(value.round()),
        ),
        _section('نوع الخط', Icons.font_download_outlined),
        _choices([
          _chip('افتراضي', c.novelFontFamily.value == 'default',
              () => c.setNovelFontFamily('default')),
          _chip('نسخي', c.novelFontFamily.value == 'serif',
              () => c.setNovelFontFamily('serif')),
          _chip('بسيط', c.novelFontFamily.value == 'sans-serif',
              () => c.setNovelFontFamily('sans-serif')),
          _chip('أحادي', c.novelFontFamily.value == 'monospace',
              () => c.setNovelFontFamily('monospace')),
        ]),
        _slider(
          title: 'تباعد الأسطر',
          value: c.novelLineHeight.value,
          min: 1.4,
          max: 2.3,
          divisions: 9,
          label: c.novelLineHeight.value.toStringAsFixed(1),
          onChanged: c.setNovelLineHeight,
        ),
        _slider(
          title: 'المسافة بين الفقرات',
          value: c.novelParagraphSpacing.value,
          min: 8,
          max: 36,
          divisions: 14,
          label: '${c.novelParagraphSpacing.value.round()} px',
          onChanged: c.setNovelParagraphSpacing,
        ),
        _slider(
          title: 'هوامش القراءة',
          value: c.novelMargins.value,
          min: 12,
          max: 56,
          divisions: 11,
          label: '${c.novelMargins.value.round()} px',
          onChanged: c.setNovelMargins,
        ),
        _section('محاذاة النص', Icons.format_align_right_rounded),
        _choices([
          _chip('تلقائي', c.novelTextAlign.value == 'auto',
              () => c.setNovelTextAlign('auto')),
          _chip('بداية السطر', c.novelTextAlign.value == 'start',
              () => c.setNovelTextAlign('start')),
          _chip('ضبط', c.novelTextAlign.value == 'justify',
              () => c.setNovelTextAlign('justify')),
        ]),
        _section('اتجاه النص', Icons.text_fields_rounded),
        _choices([
          _chip('اكتشاف تلقائي', c.novelTextDirection.value == 'auto',
              () => c.setNovelTextDirection('auto')),
          _chip('من اليمين', c.novelTextDirection.value == 'rtl',
              () => c.setNovelTextDirection('rtl')),
          _chip('من اليسار', c.novelTextDirection.value == 'ltr',
              () => c.setNovelTextDirection('ltr')),
        ]),
      ] else ...[
        _section('خلفية القارئ', Icons.contrast_rounded),
        _choices([
          _chip('أسود', c.readerBackground.value == 'black',
              () => c.setReaderBackground('black')),
          _chip('رمادي', c.readerBackground.value == 'gray',
              () => c.setReaderBackground('gray')),
          _chip('أبيض', c.readerBackground.value == 'white',
              () => c.setReaderBackground('white')),
          _chip('حسب التطبيق', c.readerBackground.value == 'app',
              () => c.setReaderBackground('app')),
        ]),
      ],
      _slider(
        title: 'سطوع القارئ',
        value: c.readerBrightness.value,
        min: .35,
        max: 1,
        divisions: 13,
        label: '${(c.readerBrightness.value * 100).round()}%',
        onChanged: c.setReaderBrightness,
      ),
      _switchTile(
        title: 'ملء الشاشة',
        subtitle: 'إخفاء شريط النظام أثناء القراءة',
        value: c.readerFullscreen.value,
        onChanged: c.setReaderFullscreen,
      ),
      _switchTile(
        title: 'إبقاء الشاشة مضاءة',
        subtitle: 'يمنع إطفاء الشاشة أثناء القراءة',
        value: c.readerKeepScreenOn.value,
        onChanged: c.setReaderKeepScreenOn,
      ),
      _section('اتجاه الشاشة', Icons.screen_rotation_rounded),
      _choices([
        _chip('تلقائي', c.readerOrientation.value == 'auto',
            () => c.setReaderOrientation('auto')),
        _chip('عمودي', c.readerOrientation.value == 'portrait',
            () => c.setReaderOrientation('portrait')),
        _chip('أفقي', c.readerOrientation.value == 'landscape',
            () => c.setReaderOrientation('landscape')),
      ]),
    ]);
  }

  Widget _performanceTab() {
    final failed = c.failedPageCount;
    return _tabList([
      _section('جودة الصور', Icons.high_quality_rounded),
      _choices([
        _chip('توفير البيانات', c.readerImageQuality.value == 'low',
            () => c.setReaderImageQuality('low')),
        _chip('متوازنة', c.readerImageQuality.value == 'medium',
            () => c.setReaderImageQuality('medium')),
        _chip('عالية', c.readerImageQuality.value == 'high',
            () => c.setReaderImageQuality('high')),
      ]),
      _slider(
        title: 'عدد الصفحات المجهزة مسبقاً',
        value: c.readerPreloadDistance.value.toDouble(),
        min: 2,
        max: 12,
        divisions: 10,
        label: '${c.readerPreloadDistance.value}',
        onChanged: (value) => c.setReaderPreloadDistance(value.round()),
      ),
      _section('الحالة', Icons.speed_rounded),
      _infoRow(
        'مصدر الفصل',
        c.isOffline.value ? 'محتوى محلي (Offline)' : 'الشبكة',
      ),
      _infoRow(
        'تحميل الصفحات',
        '${c.loadedPageCount}/${c.totalPageCount}'
            '${failed > 0 ? ' • $failed فشل' : ''}',
      ),
      if (failed > 0)
        _actionCard(
          icon: Icons.refresh_rounded,
          label: 'إعادة محاولة الصفحات الفاشلة',
          onTap: () {
            for (var index = 0;
                index < c.chapterData.value.chapter.images.length;
                index++) {
              if (c.isPageFailed(index)) {
                c.retryPage(index,
                    pageReference: c.chapterData.value.chapter.images[index]);
              }
            }
          },
        ),
      _actionCard(
        icon: Icons.cleaning_services_rounded,
        label: 'تحرير ذاكرة الصور',
        onTap: () {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          AppFeedback.show(
              title: 'الذاكرة', message: 'تم تحرير ذاكرة الصور المؤقتة.');
        },
      ),
      _hint(
        'يتم تجهيز الصفحات القريبة فقط، وتُلغى الصفحات البعيدة عند مغادرتها، '
        'لذلك يبقى استهلاك الذاكرة ثابتاً في الفصول الطويلة.',
      ),
    ]);
  }

  Widget _moreTab() {
    return _tabList([
      _section('العلامات المرجعية', Icons.bookmarks_outlined),
      _actionCard(
        icon: Icons.bookmark_add_outlined,
        label: 'حفظ موضع القراءة الحالي',
        onTap: () async {
          await c.saveReaderBookmark();
          AppFeedback.show(title: 'العلامات', message: 'تم حفظ الموضع.');
        },
      ),
      _actionCard(
        icon: Icons.bookmarks_rounded,
        label: 'عرض العلامات (${c.readerBookmarks.length})',
        onTap: () => _openBookmarks(context),
      ),
      if (c.isNovel) ...[
        _section('الملاحظات والتظليل', Icons.edit_note_rounded),
        _actionCard(
          icon: Icons.add_comment_outlined,
          label: 'إضافة ملاحظة / تظليل',
          onTap: () => _addNovelNoteDialog(context),
        ),
        _actionCard(
          icon: Icons.notes_rounded,
          label: 'عرض الملاحظات (${c.activeChapterNotes.length})',
          onTap: () => _openNovelNotes(context),
        ),
        _section('البحث والقراءة الصوتية', Icons.search_rounded),
        _actionCard(
          icon: Icons.search_rounded,
          label: 'البحث داخل الفصل',
          onTap: () => _openNovelSearch(context),
        ),
        _switchTile(
          title: 'التمرير التلقائي',
          subtitle: 'تحريك النص تلقائياً أثناء القراءة',
          value: c.novelAutoScroll.value,
          onChanged: c.setNovelAutoScroll,
        ),
        _slider(
          title: 'سرعة التمرير التلقائي',
          value: c.novelAutoScrollSpeed.value,
          min: 8,
          max: 160,
          divisions: 19,
          label: '${c.novelAutoScrollSpeed.value.round()} px/s',
          onChanged: c.setNovelAutoScrollSpeed,
        ),
        _actionCard(
          icon: c.novelSpeechPlaying.value
              ? Icons.pause_rounded
              : Icons.volume_up_rounded,
          label: c.novelSpeechPlaying.value
              ? 'إيقاف القراءة الصوتية مؤقتاً'
              : 'القراءة الصوتية',
          onTap: c.toggleNovelSpeech,
        ),
      ],
      _section('أدوات إضافية', Icons.tune_rounded),
      _actionCard(
        icon: Icons.visibility_off_outlined,
        label: 'إخفاء أدوات القارئ',
        onTap: Get.back<void>,
      ),
      _actionCard(
        icon: Icons.restart_alt_rounded,
        label: 'إعادة ضبط إعدادات القارئ',
        onTap: _resetSettings,
      ),
    ]);
  }

  // ---------------------------------------------------------------------
  // Sub-sheets
  // ---------------------------------------------------------------------

  Future<void> _openPageGrid(BuildContext context) async {
    final pages = c.chapterData.value.chapter.images;
    if (pages.isEmpty) return;
    await Get.bottomSheet(
      SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الصفحات',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text('${pages.length}',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: Obx(
                  () => GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: .62,
                    ),
                    itemCount: pages.length,
                    itemBuilder: (context, index) {
                      final current = index == c.currentPage.value;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Get.back();
                          widget.onJumpToPage(index);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: current
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: current ? 2 : 1,
                            ),
                            color: AppColors.searchBar,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image(
                                image: readerImageProvider(
                                  pages[index],
                                  headers: isLocalReaderImage(pages[index])
                                      ? null
                                      : readerImageHeaders(pages[index]),
                                  maxWidth: 140,
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      size: 20),
                                ),
                                loadingBuilder: (_, child, progress) =>
                                    progress == null
                                        ? child
                                        : const Center(
                                            child: SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 1.5),
                                            ),
                                          ),
                              ),
                              PositionedDirectional(
                                bottom: 2,
                                start: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .6),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    );
  }

  Future<void> _openPagePicker() async {
    final controller =
        TextEditingController(text: '${c.currentPage.value + 1}');
    final total = c.chapterData.value.chapter.images.length;
    final page = await Get.dialog<int>(
      AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('الانتقال إلى صفحة',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(hintText: '1 - $total'),
          onSubmitted: (value) => Get.back(result: int.tryParse(value.trim())),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('إلغاء'.tr)),
          FilledButton(
            onPressed: () =>
                Get.back(result: int.tryParse(controller.text.trim())),
            child: Text('انتقال'.tr),
          ),
        ],
      ),
    );
    controller.dispose();
    if (page == null) return;
    final index = (page - 1).clamp(0, total - 1).toInt();
    await widget.onJumpToPage(index);
  }

  Future<void> _openChapterList(BuildContext context) async {
    await c.ensureChapterNavigation();
    final chapters = c.availableChapters;
    if (chapters.isEmpty) {
      AppFeedback.show(title: 'الفصول', message: 'لا توجد قائمة فصول متاحة');
      return;
    }
    await Get.bottomSheet(
      SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .8,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'الفصول',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text('${chapters.length}',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: Obx(
                  () => ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemCount: chapters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = chapters[index];
                      final current = c.isCurrentChapter(item);
                      final read = c.isChapterRead(item.chapterId);
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: current
                            ? AppColors.primary.withValues(alpha: .13)
                            : AppColors.searchBar,
                        leading: Icon(
                          current
                              ? Icons.play_circle_fill_rounded
                              : Icons.menu_book_rounded,
                          color: current ? AppColors.primary : AppColors.icon,
                          size: 21,
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight:
                                current ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                        trailing: read
                            ? Text('مقروء'.tr,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ))
                            : null,
                        onTap: current
                            ? null
                            : () {
                                Get.back();
                                c.navigateToChapter(item.chapterId);
                              },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    );
  }

  Future<void> _openBookmarks(BuildContext context) async {
    await Get.bottomSheet(
      SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'العلامات المرجعية',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: c.saveReaderBookmark,
                      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                      label: Text('إضافة'.tr),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Obx(() {
                  final bookmarks = c.readerBookmarks.toList(growable: false);
                  if (bookmarks.isEmpty) {
                    return Center(child: Text('لا توجد علامات مرجعية'.tr));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = bookmarks[index];
                      final progress = item['progress'] is num
                          ? (item['progress'] as num).toDouble()
                          : 0.0;
                      return ListTile(
                        dense: true,
                        tileColor: AppColors.searchBar,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: const Icon(Icons.bookmark_rounded,
                            color: Color(0xff31c46c), size: 20),
                        title: Text(
                          '${item['chapterTitle'] ?? ''}'.trim().isEmpty
                              ? 'الفصل'.tr
                              : '${item['chapterTitle']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 11),
                        ),
                        trailing: IconButton(
                          onPressed: () =>
                              c.removeReaderBookmark('${item['id'] ?? ''}'),
                          icon: Icon(Icons.delete_outline_rounded,
                              color: AppColors.icon, size: 19),
                        ),
                        onTap: () {
                          Get.back();
                          c.openReaderBookmark(item);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    );
  }

  Future<void> _addNovelNoteDialog(BuildContext context) async {
    final paragraph = widget.currentNovelParagraph();
    final paragraphs =
        await c.paragraphsFor(c.chapterData.value.chapter.content);
    final text = paragraph >= 0 && paragraph < paragraphs.length
        ? _plainParagraph(paragraphs[paragraph])
        : '';
    final quoteController = TextEditingController(
      text: text.length > 60 ? text.substring(0, 60) : text,
    );
    final noteController = TextEditingController();
    String color = '#ffd54f';
    final saved = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('إضافة ملاحظة',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quoteController,
                maxLines: 2,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'النص المظلل'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'ملاحظتك'),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setState) => Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in const {
                      '#ffd54f': 'أصفر',
                      '#81c784': 'أخضر',
                      '#64b5f6': 'أزرق',
                      '#e57373': 'أحمر',
                    }.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: color == entry.key,
                        onSelected: (_) => setState(() => color = entry.key),
                        selectedColor:
                            _hexColor(entry.key).withValues(alpha: .35),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('إلغاء'.tr)),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: Text('حفظ'.tr),
          ),
        ],
      ),
    );
    final quote = quoteController.text.trim();
    final note = noteController.text.trim();
    quoteController.dispose();
    noteController.dispose();
    if (saved != true || (quote.isEmpty && note.isEmpty)) return;
    final start = text.indexOf(quote);
    await c.saveNovelNote(
      paragraphIndex: paragraph < 0 ? 0 : paragraph,
      quote: quote,
      note: note,
      color: color,
      start: start < 0 ? 0 : start,
      end: start < 0 ? 0 : start + quote.length,
    );
    AppFeedback.show(title: 'الملاحظات', message: 'تم حفظ الملاحظة.');
  }

  Future<void> _openNovelNotes(BuildContext context) async {
    await Get.bottomSheet(
      SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'ملاحظات الفصل',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final notes = c.activeChapterNotes;
                  if (notes.isEmpty) {
                    return Center(child: Text('لا توجد ملاحظات'.tr));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return ListTile(
                        dense: true,
                        tileColor: AppColors.searchBar,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Container(
                          width: 8,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(novelNoteColorValue(note.color)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        title: Text(
                          note.note.isEmpty ? note.quote : note.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 13),
                        ),
                        subtitle: note.quote.isEmpty
                            ? null
                            : Text(
                                note.quote,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11),
                              ),
                        trailing: IconButton(
                          onPressed: () => c.removeNovelNote(note.id),
                          icon: Icon(Icons.delete_outline_rounded,
                              color: AppColors.icon, size: 19),
                        ),
                        onTap: () {
                          Get.back();
                          widget.onJumpToParagraph(note.paragraphIndex);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    );
  }

  Future<void> _openNovelSearch(BuildContext context) async {
    final searchController =
        TextEditingController(text: c.novelSearchQuery.value);
    await Get.bottomSheet(
      SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  onChanged: c.searchNovel,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'ابحث داخل الفصل…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: () {
                        searchController.clear();
                        c.clearNovelSearch();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  if (c.novelSearching.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final hits = c.novelSearchHits;
                  if (c.novelSearchQuery.value.isNotEmpty && hits.isEmpty) {
                    return Center(child: Text('لا توجد نتائج'.tr));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                    itemCount: hits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final hit = hits[index];
                      return ListTile(
                        dense: true,
                        tileColor: AppColors.searchBar,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: Icon(Icons.find_in_page_rounded,
                            color: AppColors.primary, size: 20),
                        title: Text(
                          hit.snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 12.5),
                        ),
                        subtitle: Text(
                          'الفقرة ${hit.paragraphIndex + 1}',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 10.5),
                        ),
                        onTap: () {
                          Get.back();
                          widget.onJumpToParagraph(hit.paragraphIndex);
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    );
    searchController.dispose();
  }

  // ---------------------------------------------------------------------
  // Building blocks
  // ---------------------------------------------------------------------

  Widget _tabList(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: children,
      );

  Widget _section(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 7),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  Widget _choices(List<Widget> children) => Wrap(
        spacing: 7,
        runSpacing: 6,
        children: children,
      );

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: .2),
        side:
            BorderSide(color: selected ? AppColors.primary : AppColors.divider),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
        visualDensity: VisualDensity.compact,
      );

  Widget _slider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ),
                Text(label,
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
        title: Text(title,
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      );

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: AppColors.searchBar,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Icon(icon,
                      size: 19,
                      color: enabled ? AppColors.primary : AppColors.icon),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded,
                      size: 17,
                      color: enabled ? AppColors.icon : Colors.transparent),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _hint(String message) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      );

  Widget _infoRow(String title, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
            Text(value,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );

  void _goChapter(String? id, {required bool reverse}) {
    if (id == null) return;
    Get.back();
    c.navigateToChapter(id, reverse: reverse, joinContinuousStream: true);
  }

  Future<void> _resetSettings() async {
    await c.setReaderFit('width');
    await c.setReaderPageGap(4);
    await c.setReaderBackground('black');
    await c.setReaderBrightness(1);
    await c.setReaderImageQuality('medium');
    await c.setReaderPreloadDistance(6);
    await c.setNovelFontSize(19);
    await c.setNovelFontFamily('default');
    await c.setNovelBackground('app');
    await c.setNovelLineHeight(1.85);
    await c.setNovelParagraphSpacing(18);
    await c.setNovelMargins(24);
    await c.setNovelFontWeight(400);
    AppFeedback.show(title: 'القارئ', message: 'تمت إعادة ضبط إعدادات القارئ.');
  }

  String _plainParagraph(String paragraph) => isNovelChapterDivider(paragraph)
      ? titleFromNovelChapterDivider(paragraph)
      : paragraph;

  Color _hexColor(String hex) => Color(novelNoteColorValue(hex));
}
