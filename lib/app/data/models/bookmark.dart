// ignore_for_file: public_member_api_docs, sort_constructors_first
class Bookmark {
  final Map<String, BookmarkItem> bookmarkItems;

  Bookmark({required this.bookmarkItems});

  factory Bookmark.fromFirestore(Map<String, dynamic> data) {
    final bookmarkMap = data['bookmark'] as Map<String, dynamic>? ?? {};

    final items = bookmarkMap.map((comicId, itemData) =>
        MapEntry(comicId, BookmarkItem.fromJson(comicId, itemData)));

    return Bookmark(bookmarkItems: items);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'bookmark': bookmarkItems
          .map((comicId, item) => MapEntry(comicId, item.toJson())),
    };
  }
}

class BookmarkItem {
  final String comicId;
  final String title;
  final String coverImage;
  final String type;
  final String status;
  final String rating;
  final String createdAt;

  BookmarkItem({
    required this.comicId,
    required this.title,
    required this.coverImage,
    required this.type,
    this.status = '',
    this.rating = '',
    this.createdAt = '',
  });

  factory BookmarkItem.fromJson(String comicId, Map<String, dynamic> json) {
    return BookmarkItem(
      comicId: comicId,
      title: json['title'] ?? '',
      coverImage: json['coverImage'] ?? '',
      type: json['type'] ?? '',
      status: json['status']?.toString() ?? '',
      rating: json['rating']?.toString() ?? '',
      createdAt: (json['createdAt'] ?? json['addedAt'] ?? json['updatedAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comicId': comicId,
      'title': title,
      'coverImage': coverImage,
      'type': type,
      'status': status,
      'rating': rating,
      'createdAt': createdAt,
    };
  }
}
