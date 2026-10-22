import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/bookmark/views/bookmark_view.dart';
import 'package:mangaplus/app/modules/home/views/home_view.dart';
import 'package:mangaplus/app/modules/main/controllers/main_controller.dart';
import 'package:mangaplus/app/modules/profile/views/profile_view.dart';
import 'package:mangaplus/app/modules/search/views/search_view.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class MainView extends GetView<MainController> {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeAwareBuilder(builder: (context) => Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: controller.pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (value) => controller.index.value = value,
        children: const [HomeView(), SearchView(), BookmarkView(), ProfileView()],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Obx(
            () => Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider.withValues(alpha: 0.75)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'home'.tr),
                _navItem(1, Icons.search_rounded, Icons.search, 'بحث'.tr),
                _navItem(2, Icons.bookmarks_rounded, Icons.bookmark_border_rounded, 'المفضلة'.tr),
                _navItem(3, Icons.account_circle_rounded, Icons.account_circle_outlined, 'profile'.tr),
              ],
            ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _navItem(int itemIndex, IconData activeIcon, IconData inactiveIcon, String label) {
    final selected = controller.index.value == itemIndex;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => controller.changeIndex(itemIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? activeIcon : inactiveIcon,
                    size: 22,
                    color: selected ? AppColors.primary : AppColors.icon,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 9,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
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
