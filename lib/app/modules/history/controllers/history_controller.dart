import 'package:get/get.dart';
import 'package:komikaze/app/data/models/history.dart';
import 'package:komikaze/app/data/services/app_data_service.dart';

class HistoryController extends GetxController {
  final _appDataService = AppDataService();
  final RxList<HistoryItem> histories = <HistoryItem>[].obs;

  Future<void> getHistory() async {
    try {
      final history = await _appDataService.getHistory();
      if (history != null) {
        histories.value = history;
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    }
  }

  Future<HistoryItem> addHistory(HistoryItem history) async {
    try {
      await _appDataService.addHistory(history);
      getHistory();
      return history;
    } catch (e) {
      Get.snackbar('Error', e.toString());
      rethrow;
    }
  }

  @override
  void onInit() {
    getHistory();
    super.onInit();
  }
}
