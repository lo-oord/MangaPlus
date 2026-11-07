import 'dart:collection';

import 'package:mangaplus/app/core/utils/chapter_reference_identity.dart';

/// The single source of truth for chapter selection on a work's details page.
///
/// Selection is keyed by a stable chapter identity instead of a list index, so
/// scrolling, re-sorting, filtering or rebuilding the list cannot change what is
/// selected. Repeated identifiers collapse into one entry, so the visible
/// counter always equals the number of unique chapters that will be queued.
class ChapterSelection {
  ChapterSelection({String? scope}) : _scope = scope?.trim() ?? '';

  /// Optional work/source identity. Chapters with the same id coming from two
  /// different sources (or two different works) never share a selection.
  final String _scope;
  final LinkedHashMap<String, String> _selected = LinkedHashMap<String, String>();

  String get scope => _scope;
  int get count => _selected.length;
  bool get isEmpty => _selected.isEmpty;
  bool get isNotEmpty => _selected.isNotEmpty;

  /// Selected references in the order they were first selected.
  List<String> get ids => List<String>.unmodifiable(_selected.values);

  String _keyFor(String reference) {
    final trimmed = reference.trim();
    if (trimmed.isEmpty ||
        const {'null', 'undefined', '0', '#', 'javascript:void(0)'}
            .contains(trimmed.toLowerCase())) {
      return '';
    }
    final identity = ChapterReferenceIdentity.identity(reference);
    if (identity.isEmpty) return '';
    return _scope.isEmpty ? identity : '$_scope|$identity';
  }

  bool contains(String reference) {
    final key = _keyFor(reference);
    return key.isNotEmpty && _selected.containsKey(key);
  }

  /// Adds [reference] and returns whether it is selected afterwards.
  bool add(String reference) {
    final key = _keyFor(reference);
    if (key.isEmpty) return false;
    _selected[key] = reference.trim();
    return true;
  }

  /// Removes [reference] and returns whether it is selected afterwards.
  bool remove(String reference) {
    final key = _keyFor(reference);
    if (key.isEmpty) return false;
    _selected.remove(key);
    return false;
  }

  /// Flips [reference] and returns its new state.
  bool toggle(String reference) {
    if (contains(reference)) return remove(reference);
    return add(reference);
  }

  /// Selects every unique reference passed in. Already selected chapters stay.
  void selectAll(Iterable<String> references) {
    for (final reference in references) {
      add(reference);
    }
  }

  /// Removes every reference passed in, leaving other selections untouched.
  void deselectAll(Iterable<String> references) {
    for (final reference in references) {
      remove(reference);
    }
  }

  /// Drops selections that are no longer part of the work's chapter list.
  void retainOnly(Iterable<String> references) {
    final allowed = references.map(_keyFor).where((key) => key.isNotEmpty).toSet();
    _selected.removeWhere((key, _) => !allowed.contains(key));
  }

  /// Returns how many of [references] are currently selected.
  int selectedCountOf(Iterable<String> references) =>
      references.where(contains).length;

  /// True when every non-empty reference is selected and the list is not empty.
  bool coversAll(Iterable<String> references) {
    var any = false;
    for (final reference in references) {
      if (_keyFor(reference).isEmpty) continue;
      any = true;
      if (!contains(reference)) return false;
    }
    return any;
  }

  void clear() => _selected.clear();
}
