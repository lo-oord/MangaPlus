import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/data/services/account_gate_service.dart';
import 'package:mangaplus/app/modules/search/controllers/search_controller.dart'
    as search;

class MainController extends GetxController {
  final RxInt index = 0.obs;
  final PageController pageController = PageController();
  final AccountGateService _accountGate = AccountGateService();
  int _navigationRequest = 0;

  Future<void> changeIndex(int newIndex) async {
    final request = ++_navigationRequest;
    if (newIndex < 0 || newIndex > 3 || newIndex == index.value) return;

    if (newIndex == 2 && !await _accountGate.requireAccount()) return;
    if (request != _navigationRequest) return;

    index.value = newIndex;
    unawaited(HapticFeedback.selectionClick());
    if (newIndex == 1 && Get.isRegistered<search.SearchController>()) {
      Get.find<search.SearchController>().loadSuggestions();
    }

    if (!pageController.hasClients) return;
    try {
      await pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
      );
    } catch (_) {
      // A newer tap can cancel the current page animation; the latest request wins.
    }
  }

  @override
  void onClose() {
    _navigationRequest++;
    pageController.dispose();
    super.onClose();
  }
}
