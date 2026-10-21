import 'package:get/get.dart';
import '../controllers/local_library_controller.dart';

class LocalLibraryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LocalLibraryController>(() => LocalLibraryController());
  }
}
