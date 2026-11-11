import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/core/reader/reader_image_source.dart';
import 'package:mangaplus/app/core/reader/reader_page_geometry.dart';

/// One manga page in the reader.
///
/// The widget is given the *exact* extent the list reserved for it, so the
/// image, its placeholder and its error state all occupy the same space. That
/// is what makes the list immune to the "page grows after decoding and pushes
/// everything down" jump.
class ReaderMangaPage extends StatefulWidget {
  const ReaderMangaPage({
    super.key,
    required this.reference,
    required this.pageIndex,
    required this.extent,
    required this.gap,
    required this.fitValue,
    required this.imageQuality,
    required this.retryToken,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.onLoaded,
    required this.onFailed,
    required this.onRetry,
    this.chapterDividerHeight = 0,
    this.chapterDividerTitle,
    this.zoomEnabled = false,
    this.backgroundColor = Colors.black,
  });

  final String reference;
  final int pageIndex;

  /// Total height reserved for this list item, divider and gap included.
  final double extent;
  final double gap;
  final String fitValue;
  final String imageQuality;
  final int retryToken;
  final double viewportWidth;
  final double viewportHeight;
  final VoidCallback onLoaded;
  final VoidCallback onFailed;
  final VoidCallback onRetry;
  final double chapterDividerHeight;
  final String? chapterDividerTitle;
  final bool zoomEnabled;
  final Color backgroundColor;

  @override
  State<ReaderMangaPage> createState() => _ReaderMangaPageState();
}

class _ReaderMangaPageState extends State<ReaderMangaPage>
    with SingleTickerProviderStateMixin {
  final TransformationController _zoom = TransformationController();
  AnimationController? _zoomAnimation;
  Animation<Matrix4>? _zoomTween;
  bool _loadedReported = false;
  bool _failedReported = false;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoomChanged);
  }

  @override
  void didUpdateWidget(ReaderMangaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference ||
        oldWidget.retryToken != widget.retryToken) {
      _loadedReported = false;
      _failedReported = false;
      _resetZoom(animate: false);
    }
  }

  @override
  void dispose() {
    _zoomAnimation?.dispose();
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed && mounted) setState(() => _zoomed = zoomed);
  }

  void _resetZoom({bool animate = true}) {
    _zoomAnimation?.dispose();
    _zoomAnimation = null;
    if (!animate) {
      _zoom.value = Matrix4.identity();
      return;
    }
    final tween = Matrix4Tween(begin: _zoom.value, end: Matrix4.identity())
        .animate(CurvedAnimation(
      parent: _zoomAnimation = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..forward(),
      curve: Curves.easeOutCubic,
    ));
    _zoomTween = tween;
    _zoomAnimation!.addListener(() {
      _zoom.value = _zoomTween!.value;
    });
  }

  void _handleDoubleTap() {
    if (!widget.zoomEnabled) return;
    if (_zoom.value.getMaxScaleOnAxis() > 1.01) {
      _resetZoom();
      return;
    }
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _zoomAnimation?.dispose();
    _zoomAnimation = controller;
    final animation = Matrix4Tween(
      begin: Matrix4.identity(),
      end: Matrix4.identity()..scaleByDouble(2.4, 2.4, 2.4, 1),
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
    _zoomTween = animation;
    controller.addListener(() => _zoom.value = animation.value);
    controller.forward();
  }

  void _reportLoaded() {
    if (_loadedReported) return;
    _loadedReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoaded();
    });
  }

  void _reportFailed() {
    if (_failedReported) return;
    _failedReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFailed();
    });
  }

  BoxFit get _boxFit {
    switch (widget.fitValue) {
      case 'height':
        return BoxFit.fitHeight;
      case 'screen':
        return BoxFit.contain;
      case 'natural':
        return BoxFit.scaleDown;
      default:
        return BoxFit.fitWidth;
    }
  }

  int? get _decodeWidth {
    if (widget.fitValue == 'natural') return null;
    final factor = widget.imageQuality == 'high'
        ? 1.3
        : widget.imageQuality == 'low'
            ? .75
            : 1.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return (widget.viewportWidth * dpr * factor).round().clamp(320, 2400);
  }

  @override
  Widget build(BuildContext context) {
    final imageHeight =
        (widget.extent - widget.gap - widget.chapterDividerHeight)
            .clamp(1.0, kReaderMaximumPageHeight)
            .toDouble();
    final isLocal = isLocalReaderImage(widget.reference);
    final provider = readerImageProvider(
      widget.reference,
      headers: isLocal ? null : readerImageHeaders(widget.reference),
      maxWidth: _decodeWidth,
    );
    final image = Image(
      key: ValueKey('${widget.reference}#${widget.retryToken}'),
      image: provider,
      width: double.infinity,
      height: imageHeight,
      fit: _boxFit,
      alignment: Alignment.topCenter,
      gaplessPlayback: true,
      filterQuality: widget.imageQuality == 'low'
          ? FilterQuality.low
          : FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) {
          _reportLoaded();
          return child;
        }
        return _placeholder();
      },
      errorBuilder: (context, error, stackTrace) {
        _reportFailed();
        return _errorState();
      },
    );

    return RepaintBoundary(
      child: SizedBox(
        height: widget.extent,
        width: double.infinity,
        child: ColoredBox(
          color: widget.backgroundColor,
          child: Column(
            children: [
              if (widget.chapterDividerHeight > 0)
                SizedBox(
                  height: widget.chapterDividerHeight,
                  child: _chapterDivider(),
                ),
              SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: widget.zoomEnabled
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onDoubleTap: _handleDoubleTap,
                            child: InteractiveViewer(
                              transformationController: _zoom,
                              minScale: 1,
                              maxScale: 4,
                              panEnabled: _zoomed,
                              scaleEnabled: true,
                              clipBehavior: Clip.hardEdge,
                              child: image,
                            ),
                          ),
                          if (_zoomed)
                            PositionedDirectional(
                              top: 10,
                              end: 10,
                              child: _zoomResetButton(),
                            ),
                        ],
                      )
                    : image,
              ),
              SizedBox(height: widget.gap),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.primary.withValues(alpha: .85),
            ),
            backgroundColor: Colors.white.withValues(alpha: .12),
          ),
        ),
      ),
    );
  }

  Widget _zoomResetButton() {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _resetZoom,
        child: const Padding(
          padding: EdgeInsets.all(7),
          child:
              Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 19),
        ),
      ),
    );
  }

  Widget _chapterDivider() {
    final title = widget.chapterDividerTitle?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: Colors.white.withValues(alpha: .18),
              thickness: 1,
              height: 1,
            ),
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Divider(
                color: Colors.white.withValues(alpha: .18),
                thickness: 1,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorState() {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined,
                color: Colors.white.withValues(alpha: .65), size: 34),
            const SizedBox(height: 8),
            Text(
              widget.pageIndex >= 0 ? 'تعذر تحميل الصفحة' : 'تعذر التحميل',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .82),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _loadedReported = false;
                  _failedReported = false;
                });
                widget.onRetry();
              },
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tiny helper so a local file check can be used in tests without a widget.
bool readerFileExists(String path) => File(path).existsSync();
