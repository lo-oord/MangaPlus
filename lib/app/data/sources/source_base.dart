abstract class ContentSource {
  String get id;
  String get name;
  String get kind;
  List<String> get hosts;
  bool get supportsLatestPagination => true;
  bool handles(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase().replaceFirst('www.', '') ?? '';
    return hosts.any((item) => host == item || host.endsWith('.$item'));
  }
  Future<List<Map<String, dynamic>>> search(String query);
  Future<List<Map<String, dynamic>>> latest({int page = 1});
  Future<List<Map<String, dynamic>>> catalog({int page = 1}) => latest(page: page);
  Future<List<Map<String, dynamic>>> nextPage({String query = '', int page = 2}) => query.trim().isEmpty ? latest(page: page) : search(query);
  Future<Map<String, dynamic>> details(String url);
  Future<Map<String, dynamic>?> streams(String url);
  /// Supplies manga page images.
  Future<Map<String, dynamic>?> chapterImages(String url) async => null;
  /// Supplies the readable text/html body of a novel chapter.
  Future<Map<String, dynamic>?> chapterContent(String url) async => null;
  Map<String, dynamic> item({required String title, required String url, String image = '', String type = '', List<dynamic> genres = const [], String description = '', String rating = ''}) => {
    'title': title, 'url': url, 'image_url': image, 'type': type.isEmpty ? kind : type,
    'category': kind, 'source': name, 'source_id': id, 'genres': genres,
    'description': description, 'rating': rating,
  };
}
