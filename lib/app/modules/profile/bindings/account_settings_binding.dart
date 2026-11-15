import 'package:get/get.dart';
import '../controllers/account_security_controller.dart';
import '../controllers/profile_controller.dart';

/// Binds the read-mostly account management screen.
///
/// The full account lifecycle actions live here because the same controller
/// drives the deletion progress and the security tiles.
class AccountSettingsBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<ProfileController>()) {
      Get.lazyPut<ProfileController>(() => ProfileController());
    }
    if (!Get.isRegistered<AccountSecurityController>()) {
      Get.lazyPut<AccountSecurityController>(() => AccountSecurityController());
    }
  }
}
