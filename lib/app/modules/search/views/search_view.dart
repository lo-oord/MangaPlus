import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/search/controllers/search_controller.dart'
    as search_controller;
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/custom_card_normal.dart';

class SearchView extends GetView<search_controller.SearchController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController textController = TextEditingController();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'بحث',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ابحث عن الكوميكس (مثال: ناروتو)',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppColors.searchBar,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: Obx(() => controller.query.value.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          textController.clear();
                          controller.clearSearch();
                        },
                      )
                    : const SizedBox.shrink()),
              ),
              onSubmitted: (value) {
                controller.searchComics(value.trim());
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.query.value.isEmpty) {
                return const Center(
                  child: Text(
                    'أدخل عبارة بحث للعثور على الكوميكس',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }
              if (controller.comicsList.isEmpty) {
                return const Center(
                  child: Text(
                    'لم يتم العثور على كوميكس لهذه العبارة',
                    style: TextStyle(color: Colors.white),
                  ),
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
                      onTap: () {
                        Get.toNamed(Routes.COMIC_DETAIL,
                            arguments: comic.comicId);
                      },
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
