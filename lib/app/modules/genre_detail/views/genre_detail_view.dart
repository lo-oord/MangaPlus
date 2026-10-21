import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/genre_detail/controllers/genre_detail_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';


class GenreDetailView extends GetView<GenreDetailController> {
  const GenreDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();

    // Deteksi akhir scroll untuk infinite scroll
    scrollController.addListener(() {
      if (scrollController.position.pixels >=
              scrollController.position.maxScrollExtent * 0.8 &&
          controller.hasMoreData.value &&
          !controller.isLoadingMore.value) {
        controller.fetchNextPage(Get.arguments as String);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          Get.arguments ?? 'التصنيف'.tr,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return BrandState(title: 'جارٍ تحميل التصنيف'.tr, loading: true);
        }
        if (controller.comicsList.isEmpty) {
          return BrandState(
            title: 'لا توجد قصص مصورة لهذا التصنيف'.tr,
            description: 'سيُضاف مصدر المانجا في مرحلة لاحقة.'.tr,
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: CustomScrollView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 8,
                  mainAxisExtent: 200,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final comic = controller.comicsList[index];
                    return GestureDetector(
                      onTap: () {
                        Get.toNamed(Routes.COMIC_DETAIL,
                            arguments: comic.comicId);
                      },
                      child: CustomCardNormal(
                        title: comic.title,
                        chapter: comic.chapter,
                        imageUrl: comic.image,
                      ),
                    );
                  },
                  childCount: controller.comicsList.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Obx(() => controller.isLoadingMore.value
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox.shrink()),
              ),
            ],
          ),
        );
      }),
    );
  }
}
