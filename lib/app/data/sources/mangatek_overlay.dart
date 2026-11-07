import 'dart:convert';

import 'package:flutter/material.dart';

/// Paints MangaTek's JSON bubble overlays above the downloaded page image.
/// The official extension paints the same data in its HTTP interceptor; the
/// Flutter reader keeps it as a URL fragment so the image request stays clean.
class MangaTekOverlay extends StatelessWidget {
  const MangaTekOverlay({super.key, required this.imageUrl, required this.child});

  final String imageUrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final overlays = _parse(imageUrl);
    if (overlays.isEmpty) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(child: _BubbleLayer(overlays: overlays)),
      ],
    );
  }
}

class _BubbleLayer extends StatelessWidget {
  const _BubbleLayer({required this.overlays});

  final List<Map<String, dynamic>> overlays;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxRight = overlays.fold<double>(0, (value, bubble) {
          final right = _number(bubble['x']) + _number(bubble['w']);
          return right > value ? right : value;
        });
        final scale = constraints.hasBoundedWidth && maxRight > 0
            ? constraints.maxWidth / maxRight
            : 1.0;
        return Stack(
          children: overlays.map((bubble) {
            final width = _number(bubble['w']) * scale;
            final height = _number(bubble['h']) * scale;
            if (width <= 0 || height <= 0) return const SizedBox.shrink();
            final angle = _number(bubble['angle']);
            return Positioned(
              left: _number(bubble['x']) * scale,
              top: _number(bubble['y']) * scale,
              width: width,
              height: height,
              child: Transform.rotate(
                angle: angle * 3.141592653589793 / 180,
                child: Center(
                  child: Text(
                    '${bubble['text'] ?? ''}',
                    textAlign: _align(bubble['text_align']),
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      color: _color(bubble['color'], Colors.black),
                      fontSize: _number(bubble['font_size_px'], fallback: 16) * scale,
                      height: _number(bubble['line_height'], fallback: 1.2),
                      fontFamily: '${bubble['font_family'] ?? ''}'.trim().isEmpty
                          ? null
                          : '${bubble['font_family']}',
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

List<Map<String, dynamic>> _parse(String value) {
  final fragment = Uri.tryParse(value)?.fragment ?? '';
  if (!fragment.startsWith('[')) return const [];
  try {
    final decoded = jsonDecode(fragment);
    if (decoded is! List) return const [];
    return decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  } catch (_) {
    return const [];
  }
}

double _number(dynamic value, {double fallback = 0}) =>
    double.tryParse('$value') ?? fallback;

TextAlign _align(dynamic value) => switch ('$value') {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };

Color _color(dynamic value, Color fallback) {
  final raw = '$value'.trim();
  if (raw.isEmpty || raw == 'null') return fallback;
  final hex = raw.replaceFirst('#', '');
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  return Color(int.tryParse(normalized, radix: 16) ?? fallback.value);
}
