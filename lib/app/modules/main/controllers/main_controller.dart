import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/services/account_gate_service.dart';
import 'package:mangaplus/app/modules/search/controllers/search_controller.dart'
    as search;

class MainController extends GetxController {
  final RxInt index = 0.obs;
  final PageController pageController = PageController();
  final AccountGateService _accountGate = AccountGateService();

  Future<void> changeIndex(int newIndex) async {
    if (newIndex == index.value) return;
    if (newIndex == 2 && !await _accountGate.requireAccount()) return;
    index.value = newIndex;
    if (newIndex == 1 && Get.isRegistered<search.SearchController>()) {
      Get.find<search.SearchController>().loadSuggestions();
    }
    if (pageController.hasClients) {
      pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
