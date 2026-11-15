import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Global reader defaults, stored under the same `reader_*` keys the reader
/// itself reads when a work has no per-comic override.
///
/// The chapter controller resolves a setting as `reader_<name>` when the reader
/// is opened without a comic id, so writing those keys here changes the real
/// behaviour of every work that never customised the option. Works that already
/// saved their own value keep it, which is the documented rule shown in the UI.
class ReaderPreferencesController extends GetxController {
  final GetStorage _storage = GetStorage();

  final RxString readingMode = 'scroll'.obs;
  final RxString direction = 'rtl'.obs;
  final RxDouble pageGap = 4.0.obs;
  final RxString background = 'black'.obs;
  final RxString imageQuality = 'medium'.obs;
  final RxInt preloadDistance = 6.obs;
  final RxBool continuousNavigation = true.obs;
  final RxBool autoHideChrome = true.obs;
  final RxBool fullscreen = false.obs;
  final RxBool keepScreenOn = true.obs;
  final RxString orientation = 'auto'.obs;
  final RxBool doublePage = false.obs;
  final RxString fit = 'width'.obs;

  final RxDouble novelFontSize = 19.0.obs;
  final RxString novelBackground = 'app'.obs;
  final RxDouble novelLineHeight = 1.85.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void load() {
    readingMode.value = _readString('reader_mode', 'scroll');
    direction.value = _readString('reader_direction', 'rtl');
    pageGap.value = _readNum('reader_page_gap', 4).clamp(0, 24).toDouble();
    background.value = _readString('reader_background', 'black');
    imageQuality.value = _readString('reader_image_quality', 'medium');
    preloadDistance.value =
        _readNum('reader_preload_distance', 6).clamp(2, 12).toInt();
    continuousNavigation.value = _readBool('reader_continuous_navigation', true);
    autoHideChrome.value = _readBool('reader_auto_hide_chrome', true);
    fullscreen.value = _readBool('reader_fullscreen', false);
    keepScreenOn.value = _readBool('reader_keep_screen_on', true);
    orientation.value = _readString('reader_orientation', 'auto');
    doublePage.value = _readBool('reader_double_page', false);
    fit.value = _readString('reader_fit', 'width');

    novelFontSize.value = _readNum('reader_novel_font_size', 19).clamp(14, 30).toDouble();
    novelBackground.value = _readString('reader_novel_background', 'app');
    novelLineHeight.value = _readNum('reader_novel_line_height', 1.85).clamp(1.4, 2.3).toDouble();
  }

  Future<void> setReadingMode(String value) async {
    if (!const {'scroll', 'paged'}.contains(value)) return;
    readingMode.value = value;
    await _storage.write('reader_mode', value);
  }

  Future<void> setDirection(String value) async {
    if (!const {'rtl', 'ltr'}.contains(value)) return;
    direction.value = value;
    await _storage.write('reader_direction', value);
  }

  Future<void> setPageGap(double value) async {
    final clamped = value.clamp(0, 24).toDouble();
    pageGap.value = clamped;
    await _storage.write('reader_page_gap', clamped);
  }

  Future<void> setBackground(String value) async {
    if (!const {'black', 'white', 'gray', 'app'}.contains(value)) return;
    background.value = value;
    await _storage.write('reader_background', value);
  }

  Future<void> setImageQuality(String value) async {
    if (!const {'low', 'medium', 'high'}.contains(value)) return;
    imageQuality.value = value;
    await _storage.write('reader_image_quality', value);
  }

  Future<void> setPreloadDistance(int value) async {
    final clamped = value.clamp(2, 12).toInt();
    preloadDistance.value = clamped;
    await _storage.write('reader_preload_distance', clamped);
  }

  Future<void> setContinuousNavigation(bool value) async {
    continuousNavigation.value = value;
    await _storage.write('reader_continuous_navigation', value);
  }

  Future<void> setAutoHideChrome(bool value) async {
    autoHideChrome.value = value;
    await _storage.write('reader_auto_hide_chrome', value);
  }

  Future<void> setFullscreen(bool value) async {
    fullscreen.value = value;
    await _storage.write('reader_fullscreen', value);
  }

  Future<void> setKeepScreenOn(bool value) async {
    keepScreenOn.value = value;
    await _storage.write('reader_keep_screen_on', value);
  }

  Future<void> setOrientation(String value) async {
    if (!const {'auto', 'portrait', 'landscape'}.contains(value)) return;
    orientation.value = value;
    await _storage.write('reader_orientation', value);
  }

  Future<void> setDoublePage(bool value) async {
    doublePage.value = value;
    await _storage.write('reader_double_page', value);
  }

  Future<void> setFit(String value) async {
    if (!const {'width', 'height', 'screen', 'natural'}.contains(value)) return;
    fit.value = value;
    await _storage.write('reader_fit', value);
  }

  Future<void> setNovelFontSize(double value) async {
    final clamped = value.clamp(14, 30).toDouble();
    novelFontSize.value = clamped;
    await _storage.write('reader_novel_font_size', clamped);
  }

  Future<void> setNovelBackground(String value) async {
    if (!const {'app', 'light', 'sepia', 'dark', 'black'}.contains(value)) return;
    novelBackground.value = value;
    await _storage.write('reader_novel_background', value);
  }

  Future<void> setNovelLineHeight(double value) async {
    final clamped = value.clamp(1.4, 2.3).toDouble();
    novelLineHeight.value = clamped;
    await _storage.write('reader_novel_line_height', clamped);
  }

  /// Restores the same defaults the reader falls back to.
  Future<void> resetToDefaults() async {
    await setReadingMode('scroll');
    await setDirection('rtl');
    await setPageGap(4);
    await setBackground('black');
    await setImageQuality('medium');
    await setPreloadDistance(6);
    await setContinuousNavigation(true);
    await setAutoHideChrome(true);
    await setFullscreen(false);
    await setKeepScreenOn(true);
    await setOrientation('auto');
    await setDoublePage(false);
    await setFit('width');
    await setNovelFontSize(19);
    await setNovelBackground('app');
    await setNovelLineHeight(1.85);
  }

  String _readString(String key, String fallback) {
    final value = _storage.read<String>(key);
    return value == null || value.isEmpty ? fallback : value;
  }

  bool _readBool(String key, bool fallback) =>
      _storage.read<bool>(key) ?? fallback;

  num _readNum(String key, num fallback) =>
      _storage.read<num>(key) ?? fallback;
}
