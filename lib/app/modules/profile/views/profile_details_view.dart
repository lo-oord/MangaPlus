import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/modules/profile/controllers/profile_controller.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/theme_aware_builder.dart';

class ProfileDetailsView extends GetView<ProfileController> {
  const ProfileDetailsView({super.key});

  @override
  Widget build(BuildContext context) => ThemeAwareBuilder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('الملف الشخصي'.tr),
            centerTitle: true,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
          ),
          body: Obx(() {
            final account = controller.accountProfile.value;
            final registered = account != null && !account.isGuest;
            if (controller.accountLoading.value) {
              return const Center(child: MangaPlusLoader(size: 68));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (!registered) ...[
                  _guestCard(account),
                  if (account != null) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => _confirmSignOut(context),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text('تسجيل الخروج'.tr),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: .55)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _section('الأمان والمزامنة'.tr, [
                    ListTile(
                      leading: Icon(Icons.sync_rounded, color: AppColors.icon),
                      title: Text('الأمان والمزامنة'.tr,
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                      subtitle: Text('سجّل الدخول لمزامنة القراءة والمفضلة'.tr,
                          style: TextStyle(color: AppColors.textSecondary)),
                      trailing: Icon(Icons.lock_outline_rounded, color: AppColors.icon),
                    ),
                  ]),
                ] else ...[
                  _identityCard(account!),
                  const SizedBox(height: 20),
                  _section('نبذة'.tr, [
                    ListTile(
                      leading: Icon(Icons.notes_rounded, color: AppColors.icon),
                      title: Text('نبذة'.tr,
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          account.bio.trim().isEmpty ? 'أضف نبذة قصيرة عن نفسك'.tr : account.bio,
                          style: TextStyle(color: AppColors.textSecondary, height: 1.45),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'تعديل النبذة'.tr,
                        onPressed: controller.savingAccount.value ? null : () => _editBio(context, account.bio),
                        icon: Icon(Icons.edit_outlined, color: AppColors.icon),
                      ),
                      onTap: controller.savingAccount.value ? null : () => _editBio(context, account.bio),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  _section('معلومات الحساب'.tr, [
                    _info(Icons.alternate_email_rounded, 'اسم المستخدم'.tr, '@${account.username}'),
                    Divider(height: 1, color: AppColors.divider),
                    _info(Icons.mail_outline_rounded, 'البريد الإلكتروني'.tr,
                        account.email.isEmpty ? 'غير محدد'.tr : account.email),
                    Divider(height: 1, color: AppColors.divider),
                    _info(Icons.wc_rounded, 'الجنس'.tr, account.gender.isEmpty ? 'غير محدد'.tr : account.gender),
                    Divider(height: 1, color: AppColors.divider),
                    _info(Icons.public_rounded, 'الدولة'.tr,
                        account.countryName.isEmpty ? 'غير محدد'.tr : account.countryName),
                  ]),
                  const SizedBox(height: 18),
                  _section('الأمان والمزامنة'.tr, [
                    ListTile(
                      leading: Icon(Icons.verified_user_outlined, color: AppColors.icon),
                      title: Text('البريد الإلكتروني'.tr, style: TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(
                        account.email.isEmpty ? 'لا يوجد بريد إلكتروني مرتبط'.tr :
                        (account.emailVerified ? 'البريد موثق'.tr : 'البريد غير موثق'.tr),
                        style: TextStyle(color: account.emailVerified ? AppColors.success : AppColors.textSecondary),
                      ),
                    ),
                    if (controller.canChangePassword) ...[
                      Divider(height: 1, color: AppColors.divider),
                      ListTile(
                        leading: Icon(Icons.key_rounded, color: AppColors.icon),
                        title: Text('تغيير كلمة المرور'.tr, style: TextStyle(color: AppColors.textPrimary)),
                        subtitle: Text('تأكيد كلمة المرور الحالية مطلوب'.tr,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.icon),
                        onTap: controller.savingAccount.value ? null : () => _changePassword(context),
                      ),
                    ],
                    Divider(height: 1, color: AppColors.divider),
                    SwitchListTile.adaptive(
                      value: account.syncFavorites,
                      onChanged: controller.savingAccount.value ? null : controller.setFavoritesSync,
                      activeColor: AppColors.primary,
                      secondary: Icon(Icons.sync_rounded, color: AppColors.icon),
                      title: Text('مزامنة المفضلة'.tr,
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text(account.syncFavorites
                          ? 'يتم حفظ المفضلة وسجل القراءة سحابيًا'.tr
                          : 'المفضلة محفوظة على هذا الجهاز فقط'.tr,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    onPressed: () => _confirmSignOut(context),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text('تسجيل الخروج'.tr),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withValues(alpha: .55)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      );

  Widget _guestCard(UserProfile? account) => Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 30, backgroundColor: AppColors.searchBar,
              child: Icon(Icons.person_outline_rounded, size: 32, color: AppColors.icon)),
          const SizedBox(height: 16),
          Text(account?.displayName.trim().isNotEmpty == true ? account!.displayName : 'حسابك في MangaPlus'.tr,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(account == null ? 'سجّل الدخول لمزامنة القراءة والمفضلة'.tr : 'أنت تستخدم التطبيق كزائر'.tr,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: controller.openAuth,
              icon: const Icon(Icons.login_rounded, size: 18), label: Text('تسجيل الدخول'.tr)),
        ]),
      );

  Widget _identityCard(UserProfile account) => Container(
        padding: const EdgeInsets.all(20),
        decoration: _decoration(),
        child: Row(children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.searchBar,
            backgroundImage: _avatarProvider(account),
            child: _avatarProvider(account) == null
                ? Icon(Icons.person_rounded, size: 38, color: AppColors.icon)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(account.displayName, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [
              Flexible(child: _GoldShimmerText('@${account.username}', verified: account.isVerified)),
              if (account.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, color: Color(0xffD4A72C), size: 17),
              ],
            ]),
          ])),
        ]),
      );


  ImageProvider? _avatarProvider(UserProfile account) {
    if (account.photoData.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(account.photoData));
      } catch (_) {
        // Fall through to the network photo if stored image data is invalid.
      }
    }
    return account.photoUrl.isEmpty ? null : CachedNetworkImageProvider(account.photoUrl);
  }

  Widget _section(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsetsDirectional.only(start: 4, bottom: 9),
              child: Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800))),
          Container(decoration: _decoration(), child: Column(children: children)),
        ],
      );

  Widget _info(IconData icon, String title, String value) => ListTile(
        leading: Icon(icon, color: AppColors.icon),
        title: Text(title, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        subtitle: Text(value, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      );

  BoxDecoration _decoration() => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: .7)),
      );

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('تسجيل الخروج'.tr, style: TextStyle(color: AppColors.textPrimary)),
        content: Text('هل تريد تسجيل الخروج من هذا الحساب؟'.tr,
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء'.tr)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('تسجيل الخروج'.tr)),
        ],
      ),
    );
    if (confirm == true) await controller.signOut();
  }

  Future<void> _editBio(BuildContext context, String current) async {
    final bio = TextEditingController(text: current);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('تعديل النبذة'.tr),
        content: TextField(controller: bio, minLines: 3, maxLines: 5, maxLength: 300,
            autofocus: true, decoration: InputDecoration(labelText: 'نبذة'.tr, hintText: 'اكتب نبذة قصيرة عن نفسك'.tr)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء'.tr)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('حفظ'.tr)),
        ],
      ),
    );
    if (save == true) await controller.updateBio(bio.text);
    bio.dispose();
  }

  Future<void> _changePassword(BuildContext context) async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('تغيير كلمة المرور'.tr),
        content: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: oldPassword, obscureText: true,
              decoration: InputDecoration(labelText: 'كلمة المرور الحالية'.tr),
              validator: (value) => (value?.isEmpty ?? true) ? 'هذا الحقل مطلوب'.tr : null),
          const SizedBox(height: 12),
          TextFormField(controller: newPassword, obscureText: true,
              decoration: InputDecoration(labelText: 'كلمة المرور الجديدة'.tr),
              validator: (value) => (value == null || value.length < 6)
                  ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'.tr : null),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء'.tr)),
          FilledButton(onPressed: () {
            if (formKey.currentState?.validate() == true) Navigator.pop(context, true);
          }, child: Text('حفظ'.tr)),
        ],
      ),
    );
    if (save == true) await controller.changePassword(oldPassword.text, newPassword.text);
    oldPassword.dispose();
    newPassword.dispose();
  }
}


class _GoldShimmerText extends StatefulWidget {
  const _GoldShimmerText(this.text, {required this.verified});
  final String text;
  final bool verified;

  @override
  State<_GoldShimmerText> createState() => _GoldShimmerTextState();
}

class _GoldShimmerTextState extends State<_GoldShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(widget.text, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13));
    if (!widget.verified) {
      return Text(widget.text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13));
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          final shift = _animation.value * 2 - 1;
          return LinearGradient(
            begin: Alignment(shift - 1, 0),
            end: Alignment(shift + 1, 0),
            colors: const [Color(0xff8C6915), Color(0xffD4A72C), Color(0xffffef9a), Color(0xffD4A72C)],
            stops: const [0.0, 0.38, 0.52, 1.0],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: text,
    );
  }
}
