import 'package:get/get.dart';
import '../controllers/reading_stats_controller.dart';
import '../../../data/services/reading_stats_service.dart';

class ReadingStatsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ReadingStatsService>()) {
      Get.put<ReadingStatsService>(ReadingStatsService(), permanent: true);
    }
    if (!Get.isRegistered<ReadingStatsController>()) {
      Get.lazyPut<ReadingStatsController>(() => ReadingStatsController());
    }
  }
}
