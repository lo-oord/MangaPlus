import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(builder: (context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('الإعدادات'.tr),
          centerTitle: true,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Obx(() {
          final account = controller.accountProfile.value;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => Get.toNamed(Routes.PROFILE_DETAILS),
                child: _profileHeader(),
              ),
              const SizedBox(height: 24),
              _sectionTitle('التفضيلات'.tr),
              const SizedBox(height: 9),
              _settingsCard([
                _languageSetting(),
                Divider(height: 1, color: AppColors.divider),
                Obx(() => SwitchListTile.adaptive(
                  value: controller.isDarkMode.value,
                  onChanged: controller.changeTheme,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: Icon(
                    controller.isDarkMode.value
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.icon,
                  ),
                  title: Text(
                    'المظهر'.tr,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    controller.isDarkMode.value ? 'داكن'.tr : 'فاتح'.tr,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  activeColor: AppColors.primary,
                )),
              ]),
              const SizedBox(height: 24),
              _sectionTitle('مكتبتي'.tr),
              const SizedBox(height: 9),
              _settingsCard([
                _navigationRow(
                  Icons.notifications_none_rounded,
                  'الإشعارات'.tr,
                  () => Get.toNamed(Routes.NOTIFICATIONS),
                ),
                Divider(height: 1, color: AppColors.divider),
                _navigationRow(
                  Icons.history_rounded,
                  'سجل القراءة'.tr,
                  () => Get.toNamed(Routes.HISTORY),
                ),
                Divider(height: 1, color: AppColors.divider),
                _navigationRow(
                  Icons.download_outlined,
                  'التحميلات'.tr,
                  () => Get.toNamed(Routes.DOWNLOAD),
                ),
                Divider(height: 1, color: AppColors.divider),
                _navigationRow(
                  Icons.storage_rounded,
                  'التخزين المحلي'.tr,
                  () => Get.toNamed(Routes.LOCAL_LIBRARY),
                ),
              ]),
              const SizedBox(height: 24),
              _sectionTitle('الإشعارات'.tr),
              const SizedBox(height: 9),
              _settingsCard([
                Obx(() => SwitchListTile.adaptive(
                  value: controller.favoritesNotificationsEnabled.value,
                  onChanged: controller.setFavoritesNotifications,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: Icon(Icons.favorite_border_rounded, color: AppColors.icon),
                  title: Text('إشعارات المفضلات'.tr, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('تنبيه عند توفر فصل جديد في أعمالك المحفوظة'.tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  activeColor: AppColors.primary,
                )),
                Divider(height: 1, color: AppColors.divider),
                Obx(() => SwitchListTile.adaptive(
                  value: controller.mangaNotificationsEnabled.value,
                  onChanged: controller.setMangaNotifications,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: Icon(Icons.menu_book_rounded, color: AppColors.icon),
                  title: Text('إشعارات المانجا'.tr, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  activeColor: AppColors.primary,
                )),
                Divider(height: 1, color: AppColors.divider),
                Obx(() => SwitchListTile.adaptive(
                  value: controller.novelNotificationsEnabled.value,
                  onChanged: controller.setNovelNotifications,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  secondary: Icon(Icons.auto_stories_rounded, color: AppColors.icon),
                  title: Text('إشعارات الروايات'.tr, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  activeColor: AppColors.primary,
                )),
              ]),
              const SizedBox(height: 24),
              _sectionTitle('حول التطبيق'.tr),
              const SizedBox(height: 9),
              _settingsCard([
                _navigationRow(
                  Icons.info_outline_rounded,
                  'حول التطبيق'.tr,
                  _showAboutDialog,
                ),
              ]),
            ],
          );
        }),
      ));

  Widget _profileHeader() {
    if (controller.accountLoading.value) {
      return Container(
        height: 142,
        decoration: _boxDecoration(),
        alignment: Alignment.center,
        child: const MangaPlusLoader(size: 42),
      );
    }
    final account = controller.accountProfile.value;
    if (account == null || account.isGuest) {
      final guestName = account?.displayName.trim() ?? '';
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _boxDecoration(),
        child: Row(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.searchBar,
              backgroundImage: account == null ? null : _avatarProvider(account),
              child: account == null ||
                      (account.photoData.isEmpty && account.photoUrl.isEmpty)
                  ? Icon(Icons.person_outline_rounded, size: 34, color: AppColors.icon)
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guestName.isEmpty ? 'حسابك في MangaPlus'.tr : guestName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سجّل الدخول لمزامنة القراءة والمفضلة'.tr,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: controller.openAuth,
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: Text('تسجيل الدخول'.tr),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _boxDecoration(),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(account.isVerified ? 3 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: account.isVerified
                  ? Border.all(color: const Color(0xffD4A72C), width: 2.5)
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 39,
                  backgroundColor: AppColors.searchBar,
                  backgroundImage: _avatarProvider(account),
                  child: account.photoData.isEmpty && account.photoUrl.isEmpty
                      ? Icon(Icons.person_rounded, size: 39, color: AppColors.icon)
                      : null,
                ),
                PositionedDirectional(
                  bottom: -3,
                  end: -3,
                  child: IconButton(
                    tooltip: 'تغيير الصورة'.tr,
                    onPressed: controller.savingAccount.value
                        ? null
                        : controller.changeAvatar,
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      fixedSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primary,
                      shape: const CircleBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${account.username}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (account.isVerified) ...[
                      const SizedBox(width: 5),
                      _verifiedBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تعديل الاسم الظاهر'.tr,
                      onPressed: controller.savingAccount.value
                          ? null
                          : () => _editDisplayName(account.displayName),
                      icon: Icon(Icons.edit_outlined, color: AppColors.icon, size: 19),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (account.isOfficialDeveloper) ...[
                  const SizedBox(height: 6),
                  _officialBadge(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountInfoCard(UserProfile account) => _settingsCard([
        _infoRow(Icons.wc_rounded, 'الجنس'.tr, _genderLabel(account.gender)),
        Divider(height: 1, color: AppColors.divider),
        _infoRow(
          Icons.public_rounded,
          'الدولة'.tr,
          account.countryName.isEmpty ? 'غير محدد'.tr : account.countryName,
        ),
      ]);

  Widget _securityCard(UserProfile account) {
    final canChangePassword = controller.canChangePassword;
    return _settingsCard([
      if (account.email.isNotEmpty) ...[
        ListTile(
          leading: Icon(Icons.mail_outline_rounded, color: AppColors.icon),
          title: Text(
            'البريد الإلكتروني'.tr,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.email,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  account.emailVerified
                      ? 'البريد موثق'.tr
                      : 'البريد غير موثق'.tr,
                  style: TextStyle(
                    color: account.emailVerified
                        ? AppColors.success
                        : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          trailing: Icon(
            account.emailVerified
                ? Icons.verified_rounded
                : Icons.error_outline_rounded,
            color: account.emailVerified ? AppColors.success : AppColors.warning,
            size: 20,
          ),
        ),
        if (canChangePassword) Divider(height: 1, color: AppColors.divider),
      ],
      if (canChangePassword) ...[
        ListTile(
          leading: Icon(Icons.key_rounded, color: AppColors.icon),
          title: Text(
            'تغيير كلمة المرور'.tr,
            style: TextStyle(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            'تأكيد كلمة المرور الحالية مطلوب'.tr,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon),
          onTap: controller.savingAccount.value ? null : _changePassword,
        ),
        Divider(height: 1, color: AppColors.divider),
      ],
      SwitchListTile.adaptive(
        value: account.syncFavorites,
        onChanged: controller.savingAccount.value
            ? null
            : controller.setFavoritesSync,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: Icon(Icons.sync_rounded, color: AppColors.icon),
        title: Text(
          'مزامنة المفضلة'.tr,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          account.syncFavorites
              ? 'يتم حفظ المفضلة وسجل القراءة سحابيًا'.tr
              : 'المفضلة محفوظة على هذا الجهاز فقط'.tr,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        activeColor: AppColors.primary,
      ),
    ]);
  }

  Widget _languageSetting() => PopupMenuButton<String>(
        tooltip: 'اللغة'.tr,
        onSelected: controller.changeLanguage,
        itemBuilder: (_) => [
          PopupMenuItem(value: 'ar_SA', child: Text('العربية'.tr)),
          PopupMenuItem(value: 'en_US', child: Text('الإنجليزية'.tr)),
        ],
        child: ListTile(
          leading: Icon(Icons.language_rounded, color: AppColors.icon),
          title: Text(
            'اللغة'.tr,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            controller.selectedLanguage.value == 'ar_SA'
                ? 'العربية'.tr
                : 'الإنجليزية'.tr,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          trailing: Icon(Icons.expand_more_rounded, color: AppColors.icon),
        ),
      );

  Widget _bioCard(UserProfile account) => _settingsCard([
    ListTile(
      leading: Icon(Icons.notes_rounded, color: AppColors.icon),
      title: Text('نبذة'.tr, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(
        account.bio.trim().isEmpty ? 'أضف نبذة قصيرة عن نفسك'.tr : account.bio,
        maxLines: 5, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: account.bio.trim().isEmpty ? AppColors.textSecondary : AppColors.textPrimary, height: 1.4),
      )),
      trailing: IconButton(tooltip: 'تعديل النبذة'.tr, onPressed: controller.savingAccount.value ? null : () => _editBio(account.bio),
        icon: Icon(Icons.edit_outlined, color: AppColors.icon)),
      onTap: controller.savingAccount.value ? null : () => _editBio(account.bio),
    ),
  ]);

  Widget _infoRow(IconData icon, String title, String value, {Widget? trailing}) => ListTile(
    leading: Icon(icon, color: AppColors.icon), title: Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    subtitle: Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)), trailing: trailing);

  ImageProvider? _avatarProvider(UserProfile account) {
    if (account.photoData.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(account.photoData));
      } catch (_) {
        // بيانات الصورة القديمة أو غير الصالحة لا تمنع عرض رابط صورة احتياطي.
      }
    }
    return account.photoUrl.isEmpty ? null : CachedNetworkImageProvider(account.photoUrl);
  }

  Future<void> _changePassword() async {
    final oldPassword = TextEditingController(); final newPassword = TextEditingController(); final formKey = GlobalKey<FormState>();
    final result = await Get.dialog<bool>(AlertDialog(backgroundColor: AppColors.card,
      title: Text('تغيير كلمة المرور'.tr, style: TextStyle(color: AppColors.textPrimary)),
      content: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: oldPassword, obscureText: true, decoration: InputDecoration(labelText: 'كلمة المرور الحالية'.tr),
          validator: (v) => (v?.isEmpty ?? true) ? 'هذا الحقل مطلوب'.tr : null),
        const SizedBox(height: 12), TextFormField(controller: newPassword, obscureText: true, decoration: InputDecoration(labelText: 'كلمة المرور الجديدة'.tr),
          validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'.tr : null),
      ])), actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('إلغاء'.tr)),
        FilledButton(onPressed: () { if (formKey.currentState!.validate()) Get.back(result: true); }, child: Text('حفظ'.tr)),
      ]));
    if (result == true) await controller.changePassword(oldPassword.text, newPassword.text);
    oldPassword.dispose(); newPassword.dispose();
  }

  Future<void> _editDisplayName(String current) async {
    final name = TextEditingController(text: current);
    final result = await Get.dialog<bool>(AlertDialog(backgroundColor: AppColors.card,
      title: Text('الاسم الظاهر'.tr),
      content: TextField(controller: name, maxLength: 40, autofocus: true,
        decoration: InputDecoration(labelText: 'الاسم الظاهر'.tr)),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('إلغاء'.tr)),
        FilledButton(onPressed: () {
          if (name.text.trim().isNotEmpty && name.text.trim().length <= 40) Get.back(result: true);
        }, child: Text('حفظ'.tr)),
      ]));
    if (result == true) await controller.updateDisplayName(name.text);
    name.dispose();
  }

  Future<void> _editBio(String current) async {
    final bio = TextEditingController(text: current);
    final result = await Get.dialog<bool>(AlertDialog(backgroundColor: AppColors.card,
      title: Text('تعديل النبذة'.tr),
      content: TextField(controller: bio, minLines: 3, maxLines: 5, maxLength: 300, autofocus: true,
        decoration: InputDecoration(labelText: 'نبذة'.tr, hintText: 'اكتب نبذة قصيرة عن نفسك'.tr)),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text('إلغاء'.tr)),
        FilledButton(onPressed: () => Get.back(result: true), child: Text('حفظ'.tr)),
      ]));
    if (result == true) await controller.updateBio(bio.text);
    bio.dispose();
  }

  void _confirmSignOut() => Get.dialog(AlertDialog(backgroundColor: AppColors.card,
    title: Text('تسجيل الخروج'.tr), content: Text('هل تريد تسجيل الخروج من هذا الحساب؟'.tr), actions: [
      TextButton(onPressed: Get.back, child: Text('إلغاء'.tr)),
      FilledButton(onPressed: () async { Get.back(); await controller.signOut(); }, child: Text('تسجيل الخروج'.tr)),
    ]));

  void _showAboutDialog() => Get.dialog(AlertDialog(backgroundColor: AppColors.card,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    title: Row(children: [const MangaPlusLogo(size: 34), const SizedBox(width: 12), Text('حول التطبيق'.tr)]),
    content: Text('${'app_name'.tr}\n${'قارئ مانجا ومانهوا'.tr}\n\n${'الإصدار'.tr}: 1.1', style: TextStyle(color: AppColors.textSecondary, height: 1.6)),
    actions: [TextButton(onPressed: Get.back, child: Text('حسنًا'.tr))]));

  Widget _verifiedBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xffD4A72C).withValues(alpha: .13),
      borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xffD4A72C).withValues(alpha: .45))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.verified_rounded, size: 13, color: Color(0xffD4A72C)),
      const SizedBox(width: 3),
      Text('موثق'.tr, style: const TextStyle(color: Color(0xffD4A72C), fontSize: 10, height: 1.1, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _officialBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: const Color(0xffD4A72C).withValues(alpha: .10),
      borderRadius: BorderRadius.circular(9), border: Border.all(color: const Color(0xffD4A72C).withValues(alpha: .42))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.shield_rounded, size: 13, color: Color(0xffD4A72C)),
      const SizedBox(width: 5),
      Flexible(child: Text('حساب رسمي للمطور'.tr, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xffD4A72C), fontSize: 10, height: 1.1, fontWeight: FontWeight.w700))),
    ]),
  );
  String _genderLabel(String gender) => gender == 'female' ? 'أنثى'.tr : gender == 'male' ? 'ذكر'.tr : 'غير محدد'.tr;
  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)));
  BoxDecoration _boxDecoration() => BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.divider));
  Widget _settingsCard(List<Widget> children) => Container(decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.divider.withValues(alpha: .72))), child: Column(mainAxisSize: MainAxisSize.min, children: children));
  Widget _navigationRow(IconData icon, String label, VoidCallback onTap) => ListTile(leading: Icon(icon, color: AppColors.icon), title: Text(label, style: TextStyle(color: AppColors.textPrimary)), trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon), onTap: onTap);
}
