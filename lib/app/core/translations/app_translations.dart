import 'package:get/get.dart';
import 'package:mangaplus/app/core/translations/ar_sa.dart';
import 'package:mangaplus/app/core/translations/en_us.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'ar_SA': arSA,
        'en_US': enUS,
      };
}
