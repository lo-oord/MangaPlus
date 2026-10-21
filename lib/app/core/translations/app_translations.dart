import 'package:get/get.dart';
import 'package:mangaplus/app/core/translations/ar_SA.dart';
import 'package:mangaplus/app/core/translations/en_US.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'ar_SA': arSA,
        'en_US': enUS,
      };
}
