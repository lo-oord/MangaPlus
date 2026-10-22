import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mangaplus/app/core/constants/colors.dart';
import 'package:mangaplus/app/modules/genre/controllers/genre_controller.dart';
import 'package:mangaplus/app/routes/app_pages.dart';
import 'package:mangaplus/app/widgets/brand_state.dart';

class GenreView extends GetView<GenreController> {
  const GenreView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('التصنيفات'.tr),
        centerTitle: true,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return BrandState(title: 'جارٍ تحميل التصنيفات'.tr, loading: true);
        }
        final genres = controller.genreData.value.genres;
        if (genres.isEmpty) {
          return BrandState(
            title: 'تعذر تحميل التصنيفات'.tr,
            actionLabel: 'إعادة المحاولة'.tr,
            onAction: controller.fetchGenres,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          itemCount: genres.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final genre = genres[index];
            return Card(
              color: AppColors.card,
              child: ListTile(
                leading: Icon(Icons.category_outlined, color: AppColors.icon),
                title: Text(
                  genre.name,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                trailing: Icon(Icons.chevron_right, color: AppColors.icon),
                onTap: () => Get.toNamed(
                  Routes.GENRE_DETAIL,
                  arguments: {
                    'value': genre.link.isNotEmpty ? genre.link : genre.name,
                    'name': genre.name,
                  },
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
