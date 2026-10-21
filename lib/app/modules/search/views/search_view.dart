import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/search/controllers/search_controller.dart'
    as search_controller;
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';

class SearchView extends GetView<search_controller.SearchController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('بحث'.tr),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: controller.textController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'ابحث عن الكوميكس (مثال: ناروتو)'.tr,
                hintStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.searchBar,
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.icon),
                suffixIcon: Obx(() => controller.query.value.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.icon),
                        onPressed: controller.clearSearch,
                      )
                    : const SizedBox.shrink()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: controller.searchComics,
              onSubmitted: controller.searchComics,
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return BrandState(title: 'جارٍ البحث'.tr, loading: true);
              }
              if (controller.query.value.isEmpty) {
                return BrandState(
                  title: 'أدخل عبارة بحث للعثور على الكوميكس'.tr,
                  description: 'سيُضاف مصدر المانجا في مرحلة لاحقة.'.tr,
                );
              }
              if (controller.comicsList.isEmpty) {
                return BrandState(
                  title: 'لم يتم العثور على كوميكس لهذه العبارة'.tr,
                  description: 'سيُضاف مصدر المانجا في مرحلة لاحقة.'.tr,
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 8,
                    mainAxisExtent: 200,
                  ),
                  itemCount: controller.comicsList.length,
                  itemBuilder: (context, index) {
                    final comic = controller.comicsList[index];
                    return GestureDetector(
                      onTap: () => Get.toNamed(
                        Routes.COMIC_DETAIL,
                        arguments: comic.comicId,
                      ),
                      child: CustomCardNormal(
                        title: comic.title,
                        chapter: comic.chapter,
                        imageUrl: comic.image,
                        type: comic.type,
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
