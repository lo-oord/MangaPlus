import 'package:get/get.dart';
import '../controllers/account_security_controller.dart';

/// Binds the security focused screens: password change and permanent deletion.
class AccountSecurityBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AccountSecurityController>()) {
      Get.lazyPut<AccountSecurityController>(() => AccountSecurityController());
    }
  }
}
