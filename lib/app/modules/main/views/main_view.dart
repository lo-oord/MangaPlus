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
                _navItem(0, Icons.home_rounded, 'home'.tr),
                _navItem(1, Icons.search_rounded, 'بحث'.tr),
                _navItem(2, Icons.bookmark_rounded, 'المفضلة'.tr),
                _navItem(3, Icons.settings_rounded, 'الإعدادات'.tr),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int itemIndex, IconData icon, String label) {
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
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 21,
                      color: selected ? AppColors.primary : AppColors.icon),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: selected
                        ? Padding(
                            key: ValueKey('label-$itemIndex'),
                            padding: const EdgeInsets.only(left: 5),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 56),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty-label')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
