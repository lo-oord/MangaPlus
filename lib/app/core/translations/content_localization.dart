import 'package:get/get.dart';

String localizeContentType(String value) {
  switch (value.trim().toLowerCase()) {
    case 'manga':
    case 'مانجا':
      return 'مانجا'.tr;
    case 'manhwa':
    case 'مانهوا':
      return 'مانهوا'.tr;
    case 'manhua':
    case 'chinese comic':
      return 'مانهوا صينية'.tr;
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
      return 'مستمر'.tr;
    case 'completed':
    case 'complete':
    case 'finished':
    case 'مكتمل':
      return 'مكتمل'.tr;
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
