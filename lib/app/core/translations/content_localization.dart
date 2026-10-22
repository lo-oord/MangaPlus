import 'package:get/get.dart';

String localizeContentType(String value) {
  switch (value.trim().toLowerCase()) {
    case 'manga':
    case 'مانجا':
      return 'مانجا'.tr;
    case 'novel':
    case 'light novel':
    case 'رواية':
      return 'رواية'.tr;
    case 'مانhwa':
    case 'manhwa':
    case 'مانهوا':
      return 'مانهوا'.tr;
    case 'manhua':
    case 'مانها صيني':
    case 'مانهوا صينية':
    case 'chinese comic':
      return 'مانهوا صينية'.tr;
    case 'مانجا ياباني':
      return 'مانجا'.tr;
    case 'مانهوا كورية':
      return 'مانهوا'.tr;
    default:
      return value;
  }
}

String localizeContentStatus(String value) {
  switch (value.trim().toLowerCase().replaceAll('_', ' ')) {
    case 'ongoing':
    case 'on going':
    case 'publishing':
    case 'مستمر':
    case 'مستمرة':
      return 'مستمر'.tr;
    case 'completed':
    case 'complete':
    case 'finished':
    case 'season ended':
    case 'مكتمل':
    case 'مكتملة':
    case 'موسم منتهي':
      return 'مكتمل'.tr;
    case 'متوقف':
    case 'متروك':
      return 'متوقف مؤقتًا'.tr;
    case 'hiatus':
    case 'paused':
    case 'متوقف مؤقتًا':
      return 'متوقف مؤقتًا'.tr;
    case 'cancelled':
    case 'canceled':
    case 'ملغي':
      return 'ملغي'.tr;
    case 'upcoming':
    case 'قادم':
      return 'قادم'.tr;
    default:
      return value;
  }
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
