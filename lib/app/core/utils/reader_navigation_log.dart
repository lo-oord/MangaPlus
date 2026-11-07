import 'package:flutter/foundation.dart';

/// Structured diagnostics for chapter transitions.
///
/// A skipped or unexpected chapter is hard to reproduce, so every transition
/// records what asked for it, which chapter was current and which was
/// requested, the request number, and whether the result still belonged to the
/// latest request. Silent in release builds.
class ReaderNavigationLog {
  const ReaderNavigationLog._();

  /// Disabled in tests and release builds; debug builds print.
  static bool enabled = kDebugMode && !kReleaseMode;

  static void log(String event, [Map<String, Object?> fields = const {}]) {
    if (!enabled) return;
    final details = fields.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    debugPrint('[reader-nav] $event${details.isEmpty ? '' : ' $details'}');
  }
}
