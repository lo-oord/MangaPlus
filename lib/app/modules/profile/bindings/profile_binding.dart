import 'package:get/get.dart';

import '../../../data/services/reading_stats_service.dart';
import '../controllers/profile_controller.dart';
import '../controllers/reading_stats_controller.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ReadingStatsService>()) {
      Get.put<ReadingStatsService>(ReadingStatsService(), permanent: true);
    }
    if (!Get.isRegistered<ReadingStatsController>()) {
      Get.lazyPut<ReadingStatsController>(() => ReadingStatsController());
    }
    Get.lazyPut<ProfileController>(
      () => ProfileController(),
    );
  }
}
