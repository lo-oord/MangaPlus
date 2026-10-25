import 'dart:async';

import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/data/models/bookmark.dart';
import 'package:mangaplus/app/data/models/history.dart';
import 'package:mangaplus/app/data/services/account_sync_service.dart';
import 'package:mangaplus/app/data/services/bookmark_state_service.dart';

/// Device-local reading data. No account or authentication is required.
class AppDataService {
  static Timer? _syncDebounce;
  final GetStorage _storage = GetStorage();
  final AccountSyncService _sync = AccountSyncService();

  void _scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_sync.syncLocalData());
    });
  }

  Future<void> addHistory(HistoryItem history) async {
    final entries = Map<String, dynamic>.from(
      _storage.read('reading_history') ?? <String, dynamic>{},
    );
    entries[history.comicId] = history.toMap();
    await _storage.write('reading_history', entries);
    _scheduleSync();
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

  Future<void> addBookmark(BookmarkItem bookmark, {bool sync = true}) async {
    final entries = Map<String, dynamic>.from(
      _storage.read('bookmarks') ?? <String, dynamic>{},
    );
    final existing = entries[bookmark.comicId];
    final existingData = existing is Map
        ? Map<String, dynamic>.from(existing)
        : <String, dynamic>{};
    final now = DateTime.now().toUtc().toIso8601String();
    final createdAt = bookmark.createdAt.trim().isNotEmpty
        ? bookmark.createdAt
        : '${existingData['createdAt'] ?? existingData['updatedAt'] ?? now}';
    entries[bookmark.comicId] = {
      ...bookmark.toJson(),
      'createdAt': createdAt,
      'updatedAt': now,
    };
    await _storage.write('bookmarks', entries);
    BookmarkStateService.instance.changed();
    if (sync) _scheduleSync();
  }

  Future<void> syncNow() async {
    _syncDebounce?.cancel();
    _syncDebounce = null;
    await _sync.syncLocalData();
  }

  Future<void> addBookmarks(List<BookmarkItem> bookmarks, {bool sync = true}) async {
    if (bookmarks.isEmpty) return;
    final entries = Map<String, dynamic>.from(
      _storage.read('bookmarks') ?? <String, dynamic>{},
    );
    final now = DateTime.now().toUtc().toIso8601String();
    for (final bookmark in bookmarks) {
      final existing = entries[bookmark.comicId];
      final existingData = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      entries[bookmark.comicId] = {
        ...bookmark.toJson(),
        'createdAt': bookmark.createdAt.trim().isNotEmpty
            ? bookmark.createdAt
            : '${existingData['createdAt'] ?? existingData['updatedAt'] ?? now}',
        'updatedAt': now,
      };
    }
    await _storage.write('bookmarks', entries);
    BookmarkStateService.instance.changed();
    if (sync) _scheduleSync();
  }

  Future<List<BookmarkItem>?> getBookmarks() async {
    // Favorites require a verified, non-anonymous account. Do not expose
    // stale device data to signed-out users or merge it into a new account.
    if (!BookmarkStateService.instance.hasEligibleAccount) return const [];
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
    // Keep the UI responsive; the persisted tombstone is synced in the background.
    unawaited(_sync.removeBookmark(comicId));
  }
}
