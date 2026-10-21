import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('الإعدادات'.tr),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Obx(_accountCard),
          const SizedBox(height: 24),
          Obx(_privacyCard),
          const SizedBox(height: 24),
          _sectionTitle('التفضيلات'.tr),
          const SizedBox(height: 10),
          _settingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.language_rounded, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اللغة'.tr,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Obx(
                            () => DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: controller.selectedLanguage.value,
                                isExpanded: true,
                                dropdownColor: AppColors.card,
                                iconEnabledColor: AppColors.icon,
                                style: TextStyle(color: AppColors.textPrimary),
                                items: [
                                  DropdownMenuItem(
                                    value: 'ar_SA',
                                    child: Text('العربية'.tr),
                                  ),
                                  DropdownMenuItem(
                                    value: 'en_US',
                                    child: Text('الإنجليزية'.tr),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    controller.changeLanguage(value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.divider),
              Obx(
                () => SwitchListTile.adaptive(
                  value: controller.isDarkMode.value,
                  onChanged: controller.changeTheme,
                  secondary: Icon(
                    controller.isDarkMode.value
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: AppColors.primary,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('مكتبتي'.tr),
          const SizedBox(height: 10),
          _settingsCard(
            children: [
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
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('حول التطبيق'.tr),
          const SizedBox(height: 10),
          _settingsCard(
            children: [
              _navigationRow(
                Icons.info_outline_rounded,
                'حول التطبيق'.tr,
                _showAboutDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const MangaPlusLogo(size: 34),
            const SizedBox(width: 12),
            Text('حول التطبيق'.tr),
          ],
        ),
        content: Text(
          '${'app_name'.tr}\n${'قارئ مانجا ومانهوا'.tr}\n\n${'الإصدار'.tr}: 1.1',
          style: TextStyle(color: AppColors.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: Text('حسنًا'.tr)),
        ],
      ),
    );
  }

  Widget _accountCard() {
    if (controller.accountLoading.value) {
      return Container(
        height: 96,
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      );
    }
    final service = Get.isRegistered<AuthService>() ? Get.find<AuthService>() : null;
    final user = service?.currentUser;
    final account = controller.accountProfile.value;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: EdgeInsets.all(account?.isVerified == true ? 3 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: account?.isVerified == true ? Border.all(color: const Color(0xffD4A72C), width: 2.5) : null,
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                  backgroundImage: account?.photoUrl.isNotEmpty == true ? NetworkImage(account!.photoUrl) : null,
                  child: account?.photoUrl.isNotEmpty == true ? null : Icon(user == null ? Icons.person_outline_rounded : Icons.person_rounded, color: AppColors.primary),
                ),
              ),
              if (account?.isVerified == true) Positioned(right: -3, bottom: -3, child: _verifiedBadge()),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(account?.displayName ?? (user == null ? 'حسابك وبياناتك' : (user.isAnonymous ? 'قارئ MangaPlus' : (user.email ?? 'حساب MangaPlus'))), overflow: TextOverflow.ellipsis, style: TextStyle(color: account?.isVerified == true ? const Color(0xffD4A72C) : AppColors.textPrimary, fontWeight: FontWeight.w800))),
                    if (account?.isVerified == true) ...[
                      const SizedBox(width: 5),
                      _verifiedBadge(),
                    ],
                    if (account?.isOfficialDeveloper == true) ...[
                      const SizedBox(width: 6),
                      _officialBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(account?.username.isNotEmpty == true ? '@${account!.username}' : (user == null ? 'سجّل الدخول لمزامنة القراءة والمفضلة' : 'إدارة الحساب والمزامنة'), style: TextStyle(color: account?.isVerified == true ? const Color(0xffD4A72C) : AppColors.textSecondary, fontSize: 12, fontWeight: account?.isVerified == true ? FontWeight.w700 : FontWeight.normal)),
                if (account?.isOfficialDeveloper == true) ...[
                  const SizedBox(height: 4),
                  _officialBadge(),
                ],
                if (account != null && !account.isGuest) ...[
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: controller.savingAccount.value ? null : () => _showGenderDialog(account!.gender),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(account!.gender.isEmpty ? 'اختيار الجنس' : _genderLabel(account.gender), style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 5),
                        Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (user != null && !user.isAnonymous)
            TextButton(onPressed: controller.signOut, child: const Text('خروج'))
          else
            TextButton(onPressed: controller.openAuth, child: Text(user == null ? 'دخول' : 'ترقية')),
        ],
      ),
    );
  }

  Widget _verifiedBadge() => const Icon(Icons.verified_rounded, size: 17, color: Color(0xffD4A72C));

  Widget _officialBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xffD4A72C).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(7), border: Border.all(color: const Color(0xffD4A72C).withValues(alpha: 0.55))),
        child: const Text('حساب رسمي للمطور', style: TextStyle(color: Color(0xffD4A72C), fontSize: 10, fontWeight: FontWeight.w800)),
      );

  String _genderLabel(String gender) => gender == 'female' ? '♀️ أنثى' : '♂️ ذكر';

  void _showGenderDialog(String current) {
    var selected = current;
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('الجنس'),
        content: StatefulBuilder(builder: (context, setState) => DropdownButtonFormField<String>(
              value: selected.isEmpty ? null : selected,
              decoration: const InputDecoration(labelText: 'اختر الجنس'),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('♂️ ذكر')),
                DropdownMenuItem(value: 'female', child: Text('♀️ أنثى')),
              ],
              onChanged: (value) => setState(() => selected = value ?? selected),
            )),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('إلغاء')),
          FilledButton(onPressed: () async { if (selected.isNotEmpty) { Get.back(); await controller.updateGender(selected); } }, child: const Text('حفظ')),
        ],
      ),
    );
  }

  Widget _privacyCard() {
    final privacy = controller.accountProfile.value?.privacy;
    if (privacy == null) return const SizedBox.shrink();
    return _settingsCard(children: [
      ListTile(
        leading: Icon(Icons.shield_outlined, color: AppColors.primary),
        title: Text('الخصوصية', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        subtitle: Text('تحكم فيما يظهر في ملفك العام', style: TextStyle(color: AppColors.textSecondary)),
      ),
      _privacySwitch('إظهار النبذة', privacy.bio, (value) => controller.updatePrivacy(_privacyWith(privacy, bio: value))),
      _privacySwitch('إظهار الدولة', privacy.country, (value) => controller.updatePrivacy(_privacyWith(privacy, country: value))),
      _privacySwitch('إظهار إحصائيات القراءة', privacy.statistics, (value) => controller.updatePrivacy(_privacyWith(privacy, statistics: value))),
      _privacySwitch('إظهار المفضلة', privacy.bookmarks, (value) => controller.updatePrivacy(_privacyWith(privacy, bookmarks: value))),
      _privacySwitch('إظهار النشاط الأخير', privacy.activity, (value) => controller.updatePrivacy(_privacyWith(privacy, activity: value))),
    ]);
  }

  Widget _privacySwitch(String title, bool value, ValueChanged<bool> onChanged) => SwitchListTile.adaptive(
        value: value,
        onChanged: controller.savingAccount.value ? null : onChanged,
        title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
        activeColor: AppColors.primary,
      );

  UserPrivacy _privacyWith(UserPrivacy source, {
    bool? bio, bool? country, bool? statistics, bool? bookmarks, bool? activity,
  }) => UserPrivacy(
        bio: bio ?? source.bio,
        country: country ?? source.country,
        statistics: statistics ?? source.statistics,
        lists: source.lists,
        bookmarks: bookmarks ?? source.bookmarks,
        completed: source.completed,
        activity: activity ?? source.activity,
        achievements: source.achievements,
        customLists: source.customLists,
      );
  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Text(
          title,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _settingsCard({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.72)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      );

  Widget _navigationRow(IconData icon, String label, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(label, style: TextStyle(color: AppColors.textPrimary)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon),
        onTap: onTap,
      );
}
