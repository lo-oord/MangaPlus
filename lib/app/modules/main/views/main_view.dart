import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/theme/app_motion.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
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
      builder: (context) {
        final palette = context.palette;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                palette.isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: palette.background,
            systemNavigationBarIconBrightness:
                palette.isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
          child: Scaffold(
            backgroundColor: palette.background,
            body: PageView(
              controller: controller.pageController,
              physics: const NeverScrollableScrollPhysics(),
              // Every destination keeps its state. A tab that is not kept alive is
              // disposed when the PageView scrolls it out, which dropped the search
              // query, the bookmark filters and every scroll offset on each switch.
              children: const [
                _KeepAlivePage(child: HomeView()),
                _KeepAlivePage(child: SearchView()),
                _KeepAlivePage(child: BookmarkView()),
                _KeepAlivePage(child: ProfileView()),
              ],
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Obx(() => _buildNavigationBar(context)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationBar(BuildContext context) {
    final p = context.palette;
    final selectedIndex = controller.index.value.clamp(0, 3);
    return Container(
      height: AppSizes.navBarHeight,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: AppRadii.pillAll,
        border: Border.all(color: p.border.withValues(alpha: .85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? .22 : .05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: AnimatedAlign(
              alignment: Alignment(-1 + (selectedIndex * 2 / 3), 0),
              duration: AppMotion.effective(context, AppMotion.slow),
              curve: AppMotion.standard,
              child: FractionallySizedBox(
                widthFactor: 0.25,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: .13),
                      borderRadius: AppRadii.pillAll,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _NavItem(
                itemIndex: 0,
                activeIcon: Icons.home_rounded,
                inactiveIcon: Icons.home_outlined,
                label: 'home'.tr,
                selected: selectedIndex == 0,
                onTap: () => controller.changeIndex(0),
              ),
              _NavItem(
                itemIndex: 1,
                activeIcon: Icons.manage_search_rounded,
                inactiveIcon: Icons.search_rounded,
                label: 'بحث'.tr,
                selected: selectedIndex == 1,
                onTap: () => controller.changeIndex(1),
              ),
              _NavItem(
                itemIndex: 2,
                activeIcon: Icons.bookmarks_rounded,
                inactiveIcon: Icons.bookmarks_outlined,
                label: 'bookmark_title'.tr,
                selected: selectedIndex == 2,
                onTap: () => controller.changeIndex(2),
              ),
              _NavItem(
                itemIndex: 3,
                activeIcon: Icons.account_circle_rounded,
                inactiveIcon: Icons.person_outline_rounded,
                label: 'profile'.tr,
                selected: selectedIndex == 3,
                onTap: () => controller.changeIndex(3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One destination of the floating navigation bar.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.itemIndex,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int itemIndex;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final icon = selected ? activeIcon : inactiveIcon;
    final tint = selected ? p.primary : p.icon;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadii.pillAll,
            splashColor: p.primary.withValues(alpha: .08),
            highlightColor: p.primary.withValues(alpha: .04),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: AppSpacing.xxs,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.08 : 1,
                    duration: AppMotion.effective(context, AppMotion.normal),
                    curve: AppMotion.enter,
                    child: AnimatedSwitcher(
                      duration: AppMotion.effective(context, AppMotion.fast),
                      switchInCurve: AppMotion.enter,
                      switchOutCurve: AppMotion.exit,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: .82, end: 1).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: Icon(
                        icon,
                        key: ValueKey(
                          '${itemIndex}_${selected ? 'active' : 'idle'}',
                        ),
                        size: AppSizes.iconMd,
                        color: tint,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.effective(context, AppMotion.fast),
                    curve: AppMotion.enter,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: selected ? p.primary : p.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          height: 1.1,
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

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
