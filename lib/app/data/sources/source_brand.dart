import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

/// Resolves each provider's own site icon so provider branding stays tied to
/// the source website rather than an unrelated third-party logo service.
class SourceBrand {
  SourceBrand._();

  static final Map<String, Future<Uri?>> _iconRequests = {};

  static const Map<String, String> _siteBySource = {
    'team x': 'https://olympustaff.com',
    'team_x_manga': 'https://olympustaff.com',
    'team_x': 'https://olympustaff.com',
    'teamx': 'https://olympustaff.com',
    'manga swat': 'https://appswat.com',
    'manga_swat': 'https://appswat.com',
    'azora': 'https://azorafly.com',
    'azora manga': 'https://azorafly.com',
    'azora novels': 'https://azorafly.com',
    'manga time': 'https://mangatime.org',
    'mangatime': 'https://mangatime.org',
    'manga online': 'https://manonga.online',
    'manga_online': 'https://manonga.online',
    'lava scans': 'https://lavascans.com',
    'lava_scans': 'https://lavascans.com',
    'mangatek': 'https://mangatek.com',
    'manga sid': 'https://mangasid.com',
    'mangasid': 'https://mangasid.com',
    'mknov': 'https://mknov.com',
    'kawaii manga': 'https://kawaiimanga.org',
    'kawaii_manga': 'https://kawaiimanga.org',
    'kawaii novels': 'https://kawaiimanga.org',
    'kawaii_novels': 'https://kawaiimanga.org',
    'cenele': 'https://cenele.com',
    'cenele_manga': 'https://cenele.com',
    'cenele_novels': 'https://cenele.com',
    'cenele manga': 'https://cenele.com',
    'cenele novels': 'https://cenele.com',
    'mangadar': 'https://mangadar.com',
    'kolnovel': 'https://kolnovel.com',
    'galaxynovels': 'https://galaxynovels.com',
    'galaxy novels': 'https://galaxynovels.com',
    'procomic': 'https://procomic.pro',
    'despair manga': 'https://despair-world.com',
    'despair_manga': 'https://despair-world.com',
    'despair novels': 'https://despair-world.com',
    'despair_novels': 'https://despair-world.com',
    'hizo manga': 'https://hizomanga.net',
    'hizomanga': 'https://hizomanga.net',
    'mangatik': 'https://mangatik.com',
    'manga tik': 'https://mangatik.com',
    'sea novel': 'https://seanovel.org',
    'seanovel': 'https://seanovel.org',
  };

  static Uri? siteFor(String source, String workUrl) {
    final workUri = Uri.tryParse(workUrl.trim());
    if (workUri != null &&
        (workUri.scheme == 'http' || workUri.scheme == 'https') &&
        workUri.host.isNotEmpty) {
      return Uri(scheme: 'https', host: workUri.host);
    }
    final normalized = source.trim().toLowerCase();
    final mapped = _siteBySource[normalized];
    return mapped == null ? null : Uri.tryParse(mapped);
  }

  static Future<Uri?> iconFor(String source, String workUrl) {
    final site = siteFor(source, workUrl);
    if (site == null) return Future.value(null);
    final key = site.host.toLowerCase();
    return _iconRequests.putIfAbsent(key, () => _loadIcon(site));
  }

  static Future<Uri?> _loadIcon(Uri site) async {
    try {
      final response = await http
          .get(site, headers: const {'User-Agent': 'Mozilla/5.0 MangaPlus'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        final document = html_parser.parse(response.body);
        final links = document.querySelectorAll('link[rel][href]');
        final icon = links.cast<dynamic>().firstWhere(
          (element) {
            final rel = (element.attributes['rel'] ?? '').toLowerCase();
            return rel.split(RegExp(r'\s+')).any(
              (value) => value == 'icon' || value == 'shortcut',
            );
          },
          orElse: () => null,
        );
        if (icon != null) {
          final href = icon.attributes['href']?.trim() ?? '';
          final resolved = site.resolve(href);
          if ((resolved.scheme == 'http' || resolved.scheme == 'https') &&
              resolved.host == site.host) {
            return resolved;
          }
        }
      }
    } catch (_) {
      // Use the conventional same-site favicon when the homepage is offline.
    }
    return site.resolve('/favicon.ico');
  }
}

/// Compact source name + the source website's own icon, shared across screens.
class SourceBrandMark extends StatelessWidget {
  const SourceBrandMark({
    super.key,
    required this.source,
    required this.workUrl,
    required this.nameColor,
    this.fontSize = 10,
    this.iconSize = 14,
  });

  final String source;
  final String workUrl;
  final Color nameColor;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final label = source.trim().isEmpty ? 'غير معروف' : source.trim();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SourceBrandIcon(
          source: source,
          workUrl: workUrl,
          size: iconSize,
          color: nameColor,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: nameColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Renders the source website icon in a fixed box so varying favicon ratios
/// cannot shift or resize source controls.
class SourceBrandIcon extends StatelessWidget {
  const SourceBrandIcon({
    super.key,
    required this.source,
    required this.workUrl,
    this.size = 28,
    this.color,
    this.fallback = Icons.language_rounded,
  });

  final String source;
  final String workUrl;
  final double size;
  final Color? color;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<Uri?>(
        future: SourceBrand.iconFor(source, workUrl),
        builder: (context, snapshot) {
          final iconUri = snapshot.data;
          if (iconUri == null) {
            return Icon(fallback, size: size * 0.78, color: color);
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.2),
            child: Image.network(
              iconUri.toString(),
              width: size,
              height: size,
              fit: BoxFit.contain,
              headers: const {'User-Agent': 'Mozilla/5.0 MangaPlus'},
              errorBuilder: (_, __, ___) => Icon(
                fallback,
                size: size * 0.78,
                color: color,
              ),
            ),
          );
        },
      ),
    );
  }
}
