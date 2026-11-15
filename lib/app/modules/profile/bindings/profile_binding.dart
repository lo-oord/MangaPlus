import 'package:get/get.dart';

import '../../../data/services/reading_stats_service.dart';
import '../controllers/account_security_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/reader_preferences_controller.dart';
import '../controllers/reading_stats_controller.dart';
import '../controllers/storage_usage_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ReadingStatsService>()) {
      Get.put<ReadingStatsService>(ReadingStatsService(), permanent: true);
    }
    if (!Get.isRegistered<ReadingStatsController>()) {
      Get.lazyPut<ReadingStatsController>(() => ReadingStatsController());
    }
    if (!Get.isRegistered<ReaderPreferencesController>()) {
      Get.lazyPut<ReaderPreferencesController>(() => ReaderPreferencesController());
    }
    if (!Get.isRegistered<StorageUsageController>()) {
      Get.lazyPut<StorageUsageController>(() => StorageUsageController());
    }
    if (!Get.isRegistered<AccountSecurityController>()) {
      Get.lazyPut<AccountSecurityController>(() => AccountSecurityController());
    }
    Get.lazyPut<ProfileController>(
      () => ProfileController(),
    );
  }
}
