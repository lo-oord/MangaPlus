import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/modules/chapter/controllers/chapter_controller.dart';

/// Top bar of the novel reader.
///
/// It only carries what a reader needs while reading: identity, position, TTS
/// and the tools entry. Everything else lives in the sheet so the text keeps
/// the screen.
class NovelReaderTopBar extends StatelessWidget {
  const NovelReaderTopBar({
    super.key,
    required this.comicTitle,
    required this.chapterTitle,
    required this.pageLabel,
    required this.progress,
    required this.onBack,
    required this.onTts,
    required this.onBookmark,
    required this.onTools,
    this.speaking = false,
    this.paused = false,
    this.onInteraction,
  });

  final String comicTitle;
  final String chapterTitle;
  final String pageLabel;
  final double progress;
  final VoidCallback onBack;
  final VoidCallback onTts;
  final VoidCallback onBookmark;
  final VoidCallback onTools;
  final bool speaking;
  final bool paused;
  final VoidCallback? onInteraction;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: onInteraction == null ? null : (_) => onInteraction!(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: .9),
              Colors.black.withValues(alpha: .48),
              Colors.transparent,
            ],
            stops: const [0, .72, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 6, 20),
            child: Row(
              children: [
                _NovelIcon(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'رجوع',
                  onTap: onBack,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (comicTitle.trim().isNotEmpty)
                        Text(
                          comicTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      Text(
                        chapterTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: comicTitle.isEmpty ? .92 : .62,
                          ),
                          fontSize: comicTitle.isEmpty ? 13.5 : 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _NovelPill(
                            label: pageLabel,
                            icon: Icons.menu_book_rounded,
                          ),
                          const SizedBox(width: 6),
                          _NovelPill(label: '$percent%'),
                        ],
                      ),
                    ],
                  ),
                ),
                _NovelIcon(
                  icon: speaking
                      ? Icons.pause_circle_filled_rounded
                      : paused
                          ? Icons.play_circle_fill_rounded
                          : Icons.volume_up_rounded,
                  tooltip: speaking ? 'إيقاف القراءة الصوتية مؤقتاً' : 'القراءة الصوتية',
                  onTap: onTts,
                  tint: speaking || paused ? AppColors.primary : null,
                ),
                _NovelIcon(
                  icon: Icons.bookmark_add_outlined,
                  tooltip: 'حفظ موضع القراءة',
                  onTap: onBookmark,
                ),
                _NovelIcon(
                  icon: Icons.more_horiz_rounded,
                  tooltip: 'أدوات الرواية',
                  onTap: onTools,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom bar of the novel reader: position, auto-scroll and chapter hopping.
class NovelReaderBottomBar extends StatelessWidget {
  const NovelReaderBottomBar({
    super.key,
    required this.pageLabel,
    required this.progress,
    required this.onSeek,
    required this.onSeekEnd,
    required this.onChapters,
    required this.onSettings,
    required this.autoScroll,
    required this.onToggleAutoScroll,
    this.chapterTitle,
    this.onPreviousChapter,
    this.onNextChapter,
    this.onInteraction,
  });

  final String pageLabel;
  final double progress;
  final ValueChanged<double> onSeek;
  final VoidCallback onSeekEnd;
  final VoidCallback onChapters;
  final VoidCallback onSettings;
  final bool autoScroll;
  final VoidCallback onToggleAutoScroll;
  final String? chapterTitle;
  final VoidCallback? onPreviousChapter;
  final VoidCallback? onNextChapter;
  final VoidCallback? onInteraction;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: onInteraction == null ? null : (_) => onInteraction!(),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xf2181b20),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0x14ffffff))),
          boxShadow: [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 22,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chapterTitle?.trim().isNotEmpty == true
                          ? chapterTitle!
                          : 'القراءة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pageLabel • $percent%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 32,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.5,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: .14),
                    thumbColor: AppColors.primary,
                    overlayColor: AppColors.primary.withValues(alpha: .12),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 15),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: onSeek,
                    onChangeStart: (_) => onInteraction?.call(),
                    onChangeEnd: (_) => onSeekEnd(),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NovelIcon(
                    icon: autoScroll
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    tooltip: autoScroll ? 'إيقاف التمرير التلقائي' : 'التمرير التلقائي',
                    onTap: onToggleAutoScroll,
                    tint: autoScroll ? AppColors.primary : null,
                  ),
                  _NovelIcon(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'الفصل السابق',
                    onTap: onPreviousChapter,
                  ),
                  _NovelIcon(
                    icon: Icons.format_list_numbered_rounded,
                    tooltip: 'قائمة الفصول',
                    onTap: onChapters,
                  ),
                  _NovelIcon(
                    icon: Icons.tune_rounded,
                    tooltip: 'إعدادات القراءة',
                    onTap: onSettings,
                  ),
                  _NovelIcon(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'الفصل التالي',
                    onTap: onNextChapter,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Playback panel: play/pause, sentence stepping, speed and language.
///
/// Every control here drives the existing FlutterTts session in
/// [ChapterController]; there are no decorative buttons.
Future<void> showNovelTtsPanel(
  BuildContext context,
  ChapterController controller,
) {
  return Get.bottomSheet(
    _NovelTtsPanel(controller: controller),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enterBottomSheetDuration: _duration(AppMotion.page),
    exitBottomSheetDuration: _duration(AppMotion.fast),
  );
}

Duration _duration(Duration duration) {
  final context = Get.context;
  return context == null ? duration : AppMotion.effective(context, duration);
}

class _NovelTtsPanel extends StatelessWidget {
  const _NovelTtsPanel({required this.controller});

  final ChapterController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: AppColors.divider.withValues(alpha: .6)),
      ),
      child: SafeArea(
        top: false,
        child: Obx(() {
          final c = controller;
          final playing = c.novelSpeechPlaying.value;
          final paused = c.novelSpeechPaused.value;
          final index = c.novelSpeechChunkIndex.value;
          final count = c.novelSpeechChunkCount.value;
          final sentence = c.novelSpeechSentence.value;
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.headphones_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'القراءة الصوتية',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            count == 0
                                ? 'جاهزة عند الضغط على تشغيل'
                                : 'الجملة ${index + 1} من $count',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
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
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 110),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.searchBar,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      sentence.trim().isEmpty
                          ? 'ابدأ التشغيل لقراءة الفصل بصوت مسموع.'
                          : sentence,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sentence.trim().isEmpty
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        fontSize: 13.5,
                        height: 1.7,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'الجملة السابقة',
                      onPressed: c.speakPreviousNovelSentence,
                      icon: const Icon(Icons.skip_previous_rounded, size: 28),
                      color: AppColors.textPrimary,
                    ),
                    IconButton.filled(
                      tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
                      onPressed: c.toggleNovelSpeech,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 30,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(58, 58),
                      ),
                    ),
                    IconButton(
                      tooltip: 'إيقاف',
                      onPressed: c.stopNovelSpeech,
                      icon: const Icon(Icons.stop_rounded, size: 28),
                      color: AppColors.textPrimary,
                    ),
                    IconButton(
                      tooltip: 'الجملة التالية',
                      onPressed: c.speakNextNovelSentence,
                      icon: const Icon(Icons.skip_next_rounded, size: 28),
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
                if (paused) ...[
                  const SizedBox(height: 6),
                  Text(
                    'متوقفة مؤقتاً — اضغط تشغيل للمتابعة من نفس الجملة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'السرعة',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: c.novelSpeechRate.value,
                        min: .25,
                        max: .75,
                        divisions: 10,
                        label:
                            '${(c.novelSpeechRate.value * 100).round()}%',
                        onChanged: c.setNovelSpeechRate,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      'اللغة',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text('العربية'),
                      selected: c.novelSpeechLanguage.value == 'ar-SA',
                      onSelected: (_) => c.setNovelSpeechLanguage('ar-SA'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('English'),
                      selected: c.novelSpeechLanguage.value == 'en-US',
                      onSelected: (_) => c.setNovelSpeechLanguage('en-US'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'تستخدم هذه اللوحة محرك الصوت المثبت على الجهاز. الأصوات '
                  'المتاحة تعتمد على ما هو منصّب في النظام، ويظهر تنبيه إن '
                  'تعذّر تشغيل الصوت.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _NovelIcon extends StatelessWidget {
  const _NovelIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.tint,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 21),
      color: onTap == null
          ? Colors.white.withValues(alpha: .26)
          : tint ?? Colors.white.withValues(alpha: .9),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 42, height: 40),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _NovelPill extends StatelessWidget {
  const _NovelPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white.withValues(alpha: .72)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .86),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
