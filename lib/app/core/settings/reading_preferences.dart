import 'package:get_storage/get_storage.dart';

/// Defaults shared by the novel and manga readers.
///
/// The reader itself reads these keys in `ChapterController`, so the settings
/// screen and the reader never keep two copies of the same value. Only the keys
/// that the reader already supports are exposed here; anything else would be a
/// decorative control.
class ReadingPreferences {
  const ReadingPreferences._();

  static const String modeKey = 'reader_mode';
  static const String directionKey = 'reader_direction';
  static const String continuousNavigationKey = 'reader_continuous_navigation';

  static const String defaultMode = 'scroll';
  static const String defaultDirection = 'rtl';

  static String normalizeMode(String? value) =>
      value == 'paged' ? 'paged' : defaultMode;

  static String normalizeDirection(String? value) =>
      value == 'ltr' ? 'ltr' : defaultDirection;

  static String get mode =>
      normalizeMode(GetStorage().read<String>(modeKey));

  static String get direction =>
      normalizeDirection(GetStorage().read<String>(directionKey));

  static bool get continuousNavigation =>
      GetStorage().read<bool>(continuousNavigationKey) ?? true;

  static Future<void> saveMode(String value) =>
      GetStorage().write(modeKey, normalizeMode(value));

  static Future<void> saveDirection(String value) =>
      GetStorage().write(directionKey, normalizeDirection(value));

  static Future<void> saveContinuousNavigation(bool value) =>
      GetStorage().write(continuousNavigationKey, value);

  static String modeLabel(String value) =>
      normalizeMode(value) == 'paged' ? 'صفحات' : 'تمرير متصل';

  static String directionLabel(String value) =>
      normalizeDirection(value) == 'ltr' ? 'يسار إلى يمين' : 'يمين إلى يسار';
}
