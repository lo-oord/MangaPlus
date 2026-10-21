import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../controllers/genre_controller.dart';

class GenreView extends GetView<GenreController> {
  const GenreView({super.key});
  @override
  Widget build(BuildContext context) {
    print('genraa ${controller.genreData.value.genres}');
    return Scaffold(
      appBar: AppBar(
        title: const Text('التصنيفات'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'واجهة التصنيفات تعمل',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
