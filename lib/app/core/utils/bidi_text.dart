import 'package:flutter/widgets.dart';

/// Returns the writing direction of the first strong character in [text].
///
/// MangaPlus keeps an LTR application shell, but Arabic labels must still be
/// laid out RTL so punctuation, ellipses and mixed Arabic/Latin titles keep the
/// correct base direction. Digits and punctuation are neutral and fall back to
/// [fallback] (LTR by default).
TextDirection bidiTextDirection(
  String? text, {
  TextDirection fallback = TextDirection.ltr,
}) {
  final value = text ?? '';
  for (final rune in value.runes) {
    if (_isArabicOrHebrew(rune)) return TextDirection.rtl;
    if (_isLatin(rune)) return TextDirection.ltr;
  }
  return fallback;
}

bool _isArabicOrHebrew(int rune) =>
    (rune >= 0x0590 && rune <= 0x05FF) || // Hebrew
    (rune >= 0x0600 && rune <= 0x06FF) || // Arabic
    (rune >= 0x0750 && rune <= 0x077F) || // Arabic supplement
    (rune >= 0x08A0 && rune <= 0x08FF) || // Arabic extended-A
    (rune >= 0xFB50 && rune <= 0xFDFF) || // Arabic presentation forms-A
    (rune >= 0xFE70 && rune <= 0xFEFF); // Arabic presentation forms-B

bool _isLatin(int rune) =>
    (rune >= 0x0041 && rune <= 0x005A) ||
    (rune >= 0x0061 && rune <= 0x007A) ||
    (rune >= 0x00C0 && rune <= 0x024F);
