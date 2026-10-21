import 'package:get_storage/get_storage.dart';
import 'package:komikaze/app/data/models/bookmark.dart';
import 'package:komikaze/app/data/models/history.dart';

/// Device-local reading data. No account or authentication is required.
class AppDataService {
  final GetStorage _storage = GetStorage();

  Future<void> addHistory(HistoryItem history) async {
    final entries = Map<String, dynamic>.from(
      _storage.read('reading_history') ?? <String, dynamic>{},
    );
    entries[history.comicId] = history.toMap();
    await _storage.write('reading_history', entries);
  }

  Future<List<HistoryItem>?> getHistory() async {
    final entries = Map<String, dynamic>.from(
      _storage.read('reading_history') ?? <String, dynamic>{},
    );
    final items = entries.entries
        .map((entry) => HistoryItem.fromMap(
              entry.key,
              Map<String, dynamic>.from(entry.value as Map),
            ))
        .toList()
      ..sort((a, b) => b.lastRead.compareTo(a.lastRead));
    return items;
  }

  Future<void> addBookmark(BookmarkItem bookmark) async {
    final entries = Map<String, dynamic>.from(
      _storage.read('bookmarks') ?? <String, dynamic>{},
    );
    entries[bookmark.comicId] = bookmark.toJson();
    await _storage.write('bookmarks', entries);
  }

  Future<List<BookmarkItem>?> getBookmarks() async {
    final entries = Map<String, dynamic>.from(
      _storage.read('bookmarks') ?? <String, dynamic>{},
    );
    return entries.entries
        .map((entry) => BookmarkItem.fromJson(
              entry.key,
              Map<String, dynamic>.from(entry.value as Map),
            ))
        .toList();
  }

  Future<void> deleteBookmark(String comicId) async {
    final entries = Map<String, dynamic>.from(
      _storage.read('bookmarks') ?? <String, dynamic>{},
    );
    entries.remove(comicId);
    await _storage.write('bookmarks', entries);
  }
}
