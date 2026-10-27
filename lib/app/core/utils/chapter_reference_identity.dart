class ChapterReferenceIdentity {
  const ChapterReferenceIdentity._();

  static String identity(String reference, {String? baseReference}) {
    final value = reference.trim();
    if (value.isEmpty) return '';
    final parsed = Uri.tryParse(value);
    if (parsed == null) return _trimTrailingSlashes(value);

    final base = Uri.tryParse(baseReference?.trim() ?? '');
    final resolved = !parsed.hasScheme && base?.hasScheme == true
        ? base!.resolveUri(parsed)
        : parsed;

    if (!resolved.hasScheme || resolved.host.isEmpty) {
      return _trimTrailingSlashes(value);
    }
    final path = _trimTrailingSlashes(resolved.path);
    return '${resolved.scheme.toLowerCase()}|${resolved.host.toLowerCase()}|$path|${resolved.query}';
  }

  static bool matches(
    String left,
    String right, {
    String? baseReference,
  }) =>
      identity(left, baseReference: baseReference) ==
      identity(right, baseReference: baseReference);

  static String _trimTrailingSlashes(String value) =>
      value.replaceFirst(RegExp(r'/+$'), '');
}
