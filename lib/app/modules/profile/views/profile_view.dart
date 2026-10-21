import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text('الملف الشخصي'.tr), centerTitle: true,
            backgroundColor: AppColors.background, foregroundColor: AppColors.textPrimary, elevation: 0),
        body: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
              _profileHeader(),
              const SizedBox(height: 22),
              if (controller.accountProfile.value != null) ...[
                _sectionTitle('نبذة'.tr), const SizedBox(height: 10),
                _bioCard(controller.accountProfile.value!),
                const SizedBox(height: 22),
                _sectionTitle('معلومات الحساب'.tr), const SizedBox(height: 10),
                _accountInfoCard(controller.accountProfile.value!),
                const SizedBox(height: 22), _sectionTitle('الأمان والمزامنة'.tr), const SizedBox(height: 10),
                _settingsCard([
                  _infoRow(Icons.mail_outline_rounded, 'البريد الإلكتروني'.tr, controller.accountProfile.value!.email),
                  Divider(height: 1, color: AppColors.divider),
                  ListTile(leading: Icon(Icons.key_rounded, color: AppColors.primary),
                    title: Text('تغيير كلمة المرور'.tr, style: TextStyle(color: AppColors.textPrimary)),
                    subtitle: Text('تأكيد كلمة المرور الحالية مطلوب'.tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon),
                    onTap: controller.accountProfile.value!.isGuest ? null : _changePassword),
                  Divider(height: 1, color: AppColors.divider),
                  SwitchListTile.adaptive(value: controller.accountProfile.value!.syncFavorites,
                    onChanged: controller.savingAccount.value ? null : controller.setFavoritesSync,
                    secondary: Icon(Icons.sync_rounded, color: AppColors.primary),
                    title: Text('مزامنة المفضلة'.tr, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(controller.accountProfile.value!.syncFavorites
                        ? 'يتم حفظ المفضلة وسجل القراءة سحابيًا'.tr : 'المفضلة محفوظة على هذا الجهاز فقط'.tr,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12)), activeColor: AppColors.primary),
                ]),
                const SizedBox(height: 22), _sectionTitle('التفضيلات'.tr), const SizedBox(height: 10),
              ],
              _settingsCard([
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 4), child: Row(children: [
                  Icon(Icons.language_rounded, color: AppColors.primary), const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('اللغة'.tr, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                    DropdownButtonHideUnderline(child: DropdownButton<String>(value: controller.selectedLanguage.value, isExpanded: true,
                      dropdownColor: AppColors.card, style: TextStyle(color: AppColors.textPrimary),
                      items: [DropdownMenuItem(value: 'ar_SA', child: Text('العربية'.tr)), DropdownMenuItem(value: 'en_US', child: Text('الإنجليزية'.tr))],
                      onChanged: (value) { if (value != null) controller.changeLanguage(value); })),
                  ])),
                ])),
                Divider(height: 1, color: AppColors.divider),
                SwitchListTile.adaptive(value: controller.isDarkMode.value, onChanged: controller.changeTheme,
                  secondary: Icon(controller.isDarkMode.value ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: AppColors.primary),
                  title: Text('المظهر'.tr, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text(controller.isDarkMode.value ? 'داكن'.tr : 'فاتح'.tr, style: TextStyle(color: AppColors.textSecondary)), activeColor: AppColors.primary),
              ]),
              const SizedBox(height: 22), _sectionTitle('مكتبتي'.tr), const SizedBox(height: 10),
              _settingsCard([
                _navigationRow(Icons.history_rounded, 'سجل القراءة'.tr, () => Get.toNamed(Routes.HISTORY)),
                Divider(height: 1, color: AppColors.divider),
                _navigationRow(Icons.download_outlined, 'التحميلات'.tr, () => Get.toNamed(Routes.DOWNLOAD)),
                Divider(height: 1, color: AppColors.divider),
                _navigationRow(Icons.storage_rounded, 'التخزين المحلي'.tr, () => Get.toNamed(Routes.LOCAL_LIBRARY)),
              ]),
              if (controller.accountProfile.value != null) ...[
                const SizedBox(height: 22),
                _settingsCard([ListTile(leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: Text('تسجيل الخروج'.tr, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)), onTap: _confirmSignOut)]),
              ],
              const SizedBox(height: 22), _sectionTitle('حول التطبيق'.tr), const SizedBox(height: 10),
              _settingsCard([_navigationRow(Icons.info_outline_rounded, 'حول التطبيق'.tr, _showAboutDialog)]),
            ])),
      );

  Widget _profileHeader() {
    if (controller.accountLoading.value) return Container(height: 150, decoration: _boxDecoration(), alignment: Alignment.center,
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2));
    final account = controller.accountProfile.value;
    if (account == null) return Container(padding: const EdgeInsets.all(20), decoration: _boxDecoration(), child: Row(children: [
      const CircleAvatar(radius: 38, child: Icon(Icons.person_outline_rounded, size: 36)), const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('حسابك في MangaPlus'.tr, style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5), Text('سجّل الدخول لمزامنة القراءة والمفضلة'.tr, style: TextStyle(color: AppColors.textSecondary)),
        TextButton(onPressed: controller.openAuth, child: Text('تسجيل الدخول'.tr)),
      ])),
    ]));
    return Container(padding: const EdgeInsets.all(20), decoration: _boxDecoration(), child: Row(children: [
      GestureDetector(onTap: controller.savingAccount.value ? null : controller.changeAvatar,
        child: Stack(alignment: Alignment.bottomRight, children: [
          Container(padding: EdgeInsets.all(account.isVerified ? 3 : 0), decoration: BoxDecoration(shape: BoxShape.circle,
            border: account.isVerified ? Border.all(color: const Color(0xffD4A72C), width: 2.5) : null),
            child: CircleAvatar(radius: 43, backgroundColor: AppColors.primary.withValues(alpha: .15),
              backgroundImage: _avatarProvider(account),
              child: account.photoData.isEmpty && account.photoUrl.isEmpty
                  ? Icon(Icons.person_rounded, size: 42, color: AppColors.primary) : null)),
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.card, width: 2)),
            child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white)),
        ])),
      const SizedBox(width: 17),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Flexible(child: Text('@${account.username}', overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w700))),
          if (account.isVerified) ...[const SizedBox(width: 5), _verifiedBadge()]]),
        const SizedBox(height: 5), InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: controller.savingAccount.value ? null : () => _editDisplayName(account.displayName),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
            Expanded(child: Text(account.displayName, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 21, height: 1.15, fontWeight: FontWeight.w800))),
            const SizedBox(width: 5), Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
          ])),
        ),
        if (account.isOfficialDeveloper) ...[const SizedBox(height: 8), _officialBadge()],
        const SizedBox(height: 7), Text('اضغط على الصورة لتغييرها'.tr, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ])),
    ]));
  }

  Widget _accountInfoCard(UserProfile account) => _settingsCard([
    _infoRow(Icons.alternate_email_rounded, 'اسم المستخدم'.tr, '@${account.username}'),
    Divider(height: 1, color: AppColors.divider),
    _infoRow(Icons.badge_outlined, 'الاسم الظاهر'.tr, account.displayName),
    Divider(height: 1, color: AppColors.divider),
    _infoRow(Icons.wc_rounded, 'الجنس'.tr, _genderLabel(account.gender)),
    Divider(height: 1, color: AppColors.divider),
    _infoRow(Icons.public_rounded, 'الدولة'.tr, account.countryName.isEmpty ? 'غير محدد'.tr : account.countryName),
    Divider(height: 1, color: AppColors.divider),
    _infoRow(account.emailVerified ? Icons.mark_email_read_outlined : Icons.mark_email_unread_outlined, 'حالة البريد'.tr,
      account.emailVerified ? 'البريد موثق'.tr : 'البريد غير موثق'.tr,
      trailing: account.emailVerified ? const Icon(Icons.verified_rounded, color: Color(0xff2EAD68), size: 19) : null),
    if (account.isVerified) ...[Divider(height: 1, color: AppColors.divider), _infoRow(Icons.verified_rounded, 'حالة التوثيق'.tr, 'حساب موثق رسميًا'.tr, trailing: _verifiedBadge())],
  ]);

  Widget _bioCard(UserProfile account) => _settingsCard([
    ListTile(
      leading: Icon(Icons.notes_rounded, color: AppColors.primary),
      title: Text('نبذة'.tr, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(
        account.bio.trim().isEmpty ? 'أضف نبذة قصيرة عن نفسك'.tr : account.bio,
        maxLines: 5, overflow: TextOverflow.ellipsis,
        style: TextStyle(color: account.bio.trim().isEmpty ? AppColors.textSecondary : AppColors.textPrimary, height: 1.4),
      )),
      trailing: IconButton(tooltip: 'تعديل النبذة'.tr, onPressed: controller.savingAccount.value ? null : () => _editBio(account.bio),
        icon: Icon(Icons.edit_outlined, color: AppColors.primary)),
      onTap: controller.savingAccount.value ? null : () => _editBio(account.bio),
    ),
  ]);

  Widget _infoRow(IconData icon, String title, String value, {Widget? trailing}) => ListTile(
    leading: Icon(icon, color: AppColors.primary), title: Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
  BoxDecoration _boxDecoration() => BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.primary.withValues(alpha: .18)));
  Widget _settingsCard(List<Widget> children) => Container(decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.divider.withValues(alpha: .72))), child: Column(mainAxisSize: MainAxisSize.min, children: children));
  Widget _navigationRow(IconData icon, String label, VoidCallback onTap) => ListTile(leading: Icon(icon, color: AppColors.primary), title: Text(label, style: TextStyle(color: AppColors.textPrimary)), trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon), onTap: onTap);
}
