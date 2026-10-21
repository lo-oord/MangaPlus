import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/bookmark/views/bookmark_view.dart';
import 'package:mangaplus/app/modules/home/views/home_view.dart';
import 'package:mangaplus/app/modules/main/controllers/main_controller.dart';
import 'package:mangaplus/app/modules/profile/views/profile_view.dart';
import 'package:mangaplus/app/modules/search/views/search_view.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: controller.pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (value) => controller.index.value = value,
        children: const [HomeView(), SearchView(), BookmarkView(), ProfileView()],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Obx(
          () => Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined),
                _navItem(1, Icons.search_rounded, Icons.search),
                _navItem(2, Icons.bookmark_rounded, Icons.bookmark_border_rounded),
                _navItem(3, Icons.settings_rounded, Icons.settings_outlined),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int itemIndex, IconData activeIcon, IconData inactiveIcon) {
    final selected = controller.index.value == itemIndex;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => controller.changeIndex(itemIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  child: Icon(
                    selected ? activeIcon : inactiveIcon,
                    key: ValueKey('$itemIndex-$selected'),
                    size: 29,
                    color: selected ? AppColors.primary : AppColors.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
