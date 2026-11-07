import 'package:get/get.dart';

String localizeContentType(String value) {
  switch (value.trim().toLowerCase().replaceAll('_', ' ')) {
    case 'manga':
    case 'مانجا':
    case 'مانجا ياباني':
      return 'مانجا'.tr;
    case 'novel':
    case 'light novel':
    case 'web novel':
    case 'رواية':
    case 'روايات':
      return 'رواية'.tr;
    case 'مانhwa':
    case 'manhwa':
    case 'مانهوا':
    case 'مانهوا كورية':
      return 'مانهوا'.tr;
    case 'manhua':
    case 'مانها صيني':
    case 'مانهوا صينية':
    case 'chinese comic':
      return 'مانهوا صينية'.tr;
    case 'oneshot':
    case 'one shot':
      return 'ون شوت'.tr;
    default:
      return value;
  }
}

String localizeContentStatus(String value) {
  switch (value.trim().toLowerCase().replaceAll('_', ' ')) {
    case 'ongoing':
    case 'on going':
    case 'publishing':
    case 'releasing':
    case 'مستمر':
    case 'مستمرة':
    case 'مستمره':
      return 'مستمر'.tr;
    case 'completed':
    case 'complete':
    case 'finished':
    case 'ended':
    case 'season ended':
    case 'مكتمل':
    case 'مكتملة':
    case 'مكتمله':
    case 'موسم منتهي':
      return 'مكتمل'.tr;
    case 'hiatus':
    case 'on hiatus':
    case 'paused':
    case 'on hold':
    case 'متوقف':
    case 'متوقفة':
    case 'متوقف مؤقتًا':
    case 'متوقف مؤقتا':
    case 'متروك':
      return 'متوقف مؤقتًا'.tr;
    case 'cancelled':
    case 'canceled':
    case 'dropped':
    case 'discontinued':
    case 'ملغي':
    case 'ملغى':
    case 'ملغاة':
      return 'ملغي'.tr;
    case 'upcoming':
    case 'not yet published':
    case 'tba':
    case 'قادم':
    case 'قادمة':
      return 'قادم'.tr;
    case 'unknown':
    case 'غير معروف':
    case 'غير معروفة':
      return 'غير معروف'.tr;
    default:
      return value;
  }
}

/// Localizes a status only when it resolves to a known state, otherwise
/// returns the supplied fallback so the UI never prints raw provider labels.
String localizeContentStatusOr(String value, String fallback) {
  final localized = localizeContentStatus(value);
  if (localized == value && fallback.trim().isNotEmpty) return fallback;
  return localized.trim().isEmpty ? fallback : localized;
}

String localizeContentGenre(String value) {
  final key = value.trim().toLowerCase().replaceAll('-', ' ');
  const genres = <String, String>{
    'action': 'أكشن',
    'adventure': 'مغامرة',
    'comedy': 'كوميديا',
    'كوميدي': 'كوميديا',
    'drama': 'دراما',
    'fantasy': 'فانتازيا',
    'horror': 'رعب',
    'mystery': 'غموض',
    'romance': 'رومانسية',
    'sci fi': 'خيال علمي',
    'science fiction': 'خيال علمي',
    'slice of life': 'حياة يومية',
    'sports': 'رياضة',
    'supernatural': 'ما وراء الطبيعة',
    'system': 'نظام',
    'نظام': 'نظام',
    'thriller': 'تشويق',
    'historical': 'تاريخي',
    'martial arts': 'فنون قتالية',
    'school life': 'حياة مدرسية',
    'reincarnation': 'تناسخ',
    'revenge': 'انتقام',
  };
  final arabic = genres[key] ?? (genres.containsValue(value) ? value : null);
  return arabic?.tr ?? value;
}
