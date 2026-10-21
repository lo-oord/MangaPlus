import 'package:get/get.dart';
import 'package:mangaplus/app/data/models/history.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';

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
      Get.snackbar('خطأ', 'تعذر تحميل سجل القراءة. حاول مجددًا.');
    }
  }

  Future<HistoryItem> addHistory(HistoryItem history) async {
    try {
      await _appDataService.addHistory(history);
      getHistory();
      return history;
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر حفظ سجل القراءة. حاول مجددًا.');
      rethrow;
    }
  }

  @override
  void onInit() {
    getHistory();
    super.onInit();
  }
}
