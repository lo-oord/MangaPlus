import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ProfileController extends GetxController {
  final GetStorage _storage = GetStorage();
  var selectedLanguage = 'ar_SA'.obs;

  final RxList<String> downloads = <String>[
    'سولو ليفلينغ - الفصول 210–215',
    'برج الإله - الفصول 120–123',
    'البداية بعد النهاية - الفصول 145–150',
    'القارئ العليم - الفصول 100–104',
  ].obs;

  @override
  void onInit() {
    super.onInit();
    selectedLanguage.value = 'ar_SA';
    _storage.write('language', 'ar_SA');
    Future.delayed(Duration.zero, () {
      Get.updateLocale(const Locale('ar', 'SA'));
    });
  }

  void changeLanguage(String languageCode) {
    selectedLanguage.value = 'ar_SA';
    _storage.write('language', 'ar_SA');
    Get.updateLocale(const Locale('ar', 'SA'));
  }
}
