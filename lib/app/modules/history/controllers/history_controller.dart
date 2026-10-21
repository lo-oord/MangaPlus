import 'package:get/get.dart';
import 'package:mangaplus/app/widgets/app_feedback.dart';
import 'package:mangaplus/app/data/models/history.dart';
import 'package:mangaplus/app/data/services/app_data_service.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';

class HistoryController extends GetxController {
  final _appDataService = AppDataService();
  final RxBool isLoading = true.obs;
  final RxList<HistoryItem> histories = <HistoryItem>[].obs;

  Future<void> getHistory({bool syncCloud = true}) async {
    try {
      if (syncCloud) await AccountSyncService().syncLocalData();
      final history = await _appDataService.getHistory();
      if (history != null) {
        histories.value = history;
      }
    } catch (e) {
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر تحميل سجل القراءة. حاول مجددًا.'.tr, type: AppNoticeType.error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<HistoryItem> addHistory(HistoryItem history) async {
    try {
      await _appDataService.addHistory(history);
      getHistory(syncCloud: false);
      return history;
    } catch (e) {
      AppFeedback.show(title: 'خطأ'.tr, message: 'تعذر حفظ سجل القراءة. حاول مجددًا.'.tr, type: AppNoticeType.error);
      rethrow;
    }
  }

  @override
  void onInit() {
    getHistory();
    super.onInit();
  }
}
