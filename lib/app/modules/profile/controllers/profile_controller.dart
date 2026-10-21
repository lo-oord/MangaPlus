import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ProfileController extends GetxController {
  final GetStorage _storage = GetStorage();
  var selectedLanguage = 'en_US'.obs;

  final RxList<String> downloads = <String>[
    'Solo Leveling Chapter 210-215',
    'Tower of God Chapter 120-123',
    'The Beginning After The End Chapter 145-150',
    'Omniscient Reader Chapter 100-104',
  ].obs;

  @override
  void onInit() {
    super.onInit();
    selectedLanguage.value = _storage.read('language') ?? 'en_US';
    Future.delayed(Duration.zero, () {
      final parts = selectedLanguage.value.split('_');
      Get.updateLocale(Locale(parts[0], parts[1]));
    });
  }

  void changeLanguage(String languageCode) {
    selectedLanguage.value = languageCode;
    _storage.write('language', languageCode);
    Get.updateLocale(
        Locale(languageCode.split('_')[0], languageCode.split('_')[1]));
    print('Language changed to: $languageCode');
  }
}
