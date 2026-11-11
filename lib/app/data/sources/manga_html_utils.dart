import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

String mangaHtmlText(Element? element) =>
    element?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';

String mangaHtmlToText(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  final document = html_parser.parse(html);
  return (document.body?.text ?? html).replaceAll(RegExp(r'\s+'), ' ').trim();
}

String mangaHtmlToReadableText(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  final document = html_parser.parse(html);
  const blockElements = {
    'p',
    'div',
    'blockquote',
    'h1',
    'h2',
    'h3',
    'h4',
    'li',
  };
  String readNode(Node node) {
    if (node is Text) return node.data;
    if (node is! Element) return '';
    final name = node.localName;
    if (name == 'script' || name == 'style' || name == 'noscript') return '';
    if (name == 'br') return '\n';
    final content = node.nodes.map(readNode).join();
    return blockElements.contains(name) ? '$content\n' : content;
  }

  return readNode(document.body ?? document.documentElement ?? document)
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'[\t\r ]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String mangaAbsoluteUrl(String baseUrl, String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty ||
      value.startsWith('data:') ||
      value.startsWith('javascript:')) {
    return '';
  }
  final parsed = Uri.tryParse(value);
  if (parsed == null) return '';
  if (parsed.hasScheme) {
    return parsed.scheme == 'http' || parsed.scheme == 'https'
        ? parsed.toString()
        : '';
  }
  return Uri.parse(baseUrl).resolveUri(parsed).toString();
}

String mangaImageUrl(Element? element, String baseUrl) {
  if (element == null) return '';
  for (final attribute in const [
    'data-src',
    'data-url',
    'data-zoom-src',
    'data-lazy-src',
    'data-cfsrc',
    'data-original',
    'data-background-image',
    'data-srcset',
    'data-lazy-srcset',
    'srcset',
    'src',
  ]) {
    final raw = element.attributes[attribute] ?? '';
    final value = attribute.endsWith('srcset')
        ? raw.split(',').first.trim().split(RegExp(r'\s+')).first
        : raw;
    final candidate = mangaAbsoluteUrl(baseUrl, value);
    if (candidate.isNotEmpty) return candidate;
  }
  return '';
}

num? mangaChapterNumber(String value) {
  final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(value);
  return match == null ? null : num.tryParse(match.group(0)!);
}

String mangaDateFromUnixSeconds(String raw) {
  final value = raw.trim();
  final epoch = num.tryParse(value);
  if (epoch != null && epoch > 0) {
    try {
      final milliseconds =
          epoch >= 1000000000000 ? epoch.round() : (epoch * 1000).round();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
          .toIso8601String();
    } on RangeError {
      return '';
    }
  }
  return DateTime.tryParse(value)?.toUtc().toIso8601String() ?? '';
}
