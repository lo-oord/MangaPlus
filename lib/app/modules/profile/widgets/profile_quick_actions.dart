import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/navigation/app_navigation.dart';
import 'package:mangaplus/app/core/theme/app_palette.dart';
import 'package:mangaplus/app/core/theme/design_tokens.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';

/// Shortcuts to the destinations the profile screen owns.
///
/// Every entry opens an existing route; the notifications entry carries the real
/// unread count read from the inbox service.
class ProfileQuickActions extends StatelessWidget {
  const ProfileQuickActions({super.key, required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const spacing = AppSpacing.xs;
          final columns = constraints.maxWidth < 340 ? 2 : 3;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Obx(() {
            final unread = controller.unreadNotifications.value;
            final actions = <_Action>[
              _Action(
                icon: Icons.collections_bookmark_rounded,
                label: 'مكتبتي'.tr,
                route: Routes.BOOKMARK,
              ),
              _Action(
                icon: Icons.history_rounded,
                label: 'سجل القراءة'.tr,
                route: Routes.HISTORY,
              ),
              _Action(
                icon: Icons.download_outlined,
                label: 'التحميلات'.tr,
                route: Routes.DOWNLOAD,
              ),
              _Action(
                icon: Icons.storage_rounded,
                label: 'المكتبة المحلية'.tr,
                route: Routes.LOCAL_LIBRARY,
              ),
              _Action(
                icon: Icons.notifications_none_rounded,
                label: 'الإشعارات'.tr,
                route: Routes.NOTIFICATIONS,
                badge: unread,
              ),
              _Action(
                icon: Icons.manage_accounts_outlined,
                label: 'إدارة الحساب'.tr,
                route: Routes.ACCOUNT_SETTINGS,
              ),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final action in actions)
                  SizedBox(
                    width: width,
                    child: _QuickActionTile(action: action),
                  ),
              ],
            );
          });
        },
      );
}

class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.route,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final String route;
  final int badge;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _Action action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Material(
      color: p.card,
      borderRadius: AppRadii.mdAll,
      child: InkWell(
        borderRadius: AppRadii.mdAll,
        onTap: () => AppNavigation.toNamed(action.route),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.mdAll,
            border: Border.all(color: p.border.withValues(alpha: .9)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: .12),
                      borderRadius: AppRadii.smAll,
                    ),
                    alignment: Alignment.center,
                    child: Icon(action.icon, size: 20, color: p.primary),
                  ),
                  if (action.badge > 0)
                    PositionedDirectional(
                      top: -4,
                      end: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(
                          color: p.error,
                          borderRadius: AppRadii.pillAll,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          action.badge > 99 ? '99+' : '${action.badge}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
