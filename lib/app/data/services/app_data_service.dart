import 'dart:async';

import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/models/history.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/bookmark_state_service.dart';

/// Device-local reading data. No account or authentication is required.
class AppDataService {
  final GetStorage _storage = GetStorage();
  final AccountSyncService _sync = AccountSyncService();

  Future<void> addHistory(HistoryItem history) async {
    final entries = Map<String, dynamic>.from(
      _storage.read('reading_history') ?? <String, dynamic>{},
    );
    entries[history.comicId] = history.toMap();
    await _storage.write('reading_history', entries);
    unawaited(_sync.syncLocalData());
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
    entries[bookmark.comicId] = {
      ...bookmark.toJson(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _storage.write('bookmarks', entries);
    BookmarkStateService.instance.changed();
    unawaited(_sync.syncLocalData());
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
    BookmarkStateService.instance.changed();
    await _sync.removeBookmark(comicId);
  }
}
