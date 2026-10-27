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
    return ThemeAwareBuilder(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.background,
        body: PageView(
          controller: controller.pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [HomeView(), SearchView(), BookmarkView(), ProfileView()],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Obx(() => _buildNavigationBar()),
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    const duration = Duration(milliseconds: 360);
    final selectedIndex = controller.index.value.clamp(0, 3);
    return Container(
      height: 72,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 24,
            spreadRadius: -3,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: Get.isDarkMode ? 0.12 : 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: AnimatedAlign(
              alignment: Alignment(-1 + (selectedIndex * 2 / 3), 0),
              duration: duration,
              curve: Curves.easeInOutCubic,
              child: FractionallySizedBox(
                widthFactor: 0.25,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _navItem(
                0,
                activeIcon: Icons.home_rounded,
                inactiveIcon: Icons.home_outlined,
                label: 'home'.tr,
              ),
              _navItem(
                1,
                activeIcon: Icons.manage_search_rounded,
                inactiveIcon: Icons.search_rounded,
                label: 'بحث'.tr,
              ),
              _navItem(
                2,
                activeIcon: Icons.bookmarks_rounded,
                inactiveIcon: Icons.bookmarks_outlined,
                label: 'bookmark_title'.tr,
              ),
              _navItem(
                3,
                activeIcon: Icons.account_circle_rounded,
                inactiveIcon: Icons.person_outline_rounded,
                label: 'profile'.tr,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    int itemIndex, {
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
  }) {
    final selected = controller.index.value == itemIndex;
    final icon = selected ? activeIcon : inactiveIcon;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            splashColor: AppColors.primary.withValues(alpha: 0.08),
            highlightColor: AppColors.primary.withValues(alpha: 0.04),
            onTap: () => controller.changeIndex(itemIndex),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.78, end: 1).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: Icon(
                        icon,
                        key: ValueKey('${itemIndex}_${selected ? 'active' : 'idle'}'),
                        size: 23,
                        color: selected ? AppColors.primary : AppColors.icon,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 10.5,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
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
