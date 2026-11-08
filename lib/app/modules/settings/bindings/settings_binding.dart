import 'package:get/get.dart';
import 'package:mangaplus/app/modules/settings/controllers/settings_controller.dart';

class SettingsBinding extends Bindings {
  SettingsBinding();

  @override
  void dependencies() {
    Get.put(SettingsController(), permanent: true);
  }
}
