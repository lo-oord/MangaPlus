import 'dart:math' as math;

/// Formats byte counts for storage screens without pretending to know more
/// precision than the filesystem gave us.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  final exponent = math.min(
    (math.log(bytes) / math.log(1024)).floor(),
    units.length - 1,
  );
  final value = bytes / math.pow(1024, exponent);
  final digits = exponent == 0 || value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[exponent]}';
}
