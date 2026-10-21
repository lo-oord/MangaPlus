import 'package:get/get.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';
import '../controllers/auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthService>()) Get.put<AuthService>(AuthService(), permanent: true);
    Get.lazyPut<AuthController>(() => AuthController());
  }
}
