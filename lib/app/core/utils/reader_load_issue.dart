import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

class ReaderLoadIssue {
  const ReaderLoadIssue({
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
  });

  final String titleKey;
  final String descriptionKey;
  final IconData icon;

  factory ReaderLoadIssue.from(Object error, {String fallbackTitle = 'تعذر تحميل الفصل'}) {
    final message = error.toString().toLowerCase();
    if (error is SocketException ||
        error is HandshakeException ||
        message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('network is unreachable') ||
        message.contains('network request failed') ||
        message.contains('xmlhttprequest error') ||
        message.contains('no address associated') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection closed')) {
      return const ReaderLoadIssue(
        titleKey: 'لا يوجد اتصال بالإنترنت',
        descriptionKey: 'تحقق من اتصال الإنترنت ثم حاول مجددًا.',
        icon: Icons.wifi_off_rounded,
      );
    }
    if (error is TimeoutException ||
        message.contains('timed out') ||
        message.contains('timeout')) {
      return const ReaderLoadIssue(
        titleKey: 'انتهت مهلة الاتصال',
        descriptionKey: 'استغرق تحميل المحتوى وقتًا أطول من المعتاد. حاول مجددًا.',
        icon: Icons.hourglass_disabled_rounded,
      );
    }
    if (message.contains('404') ||
        message.contains('not found') ||
        message.contains('غير متاح') ||
        message.contains('لم يتم العثور')) {
      return const ReaderLoadIssue(
        titleKey: 'المحتوى غير متاح',
        descriptionKey: 'قد يكون هذا الفصل محذوفًا أو غير متاح من المصدر.',
        icon: Icons.menu_book_outlined,
      );
    }
    return ReaderLoadIssue(
      titleKey: fallbackTitle,
      descriptionKey: 'تعذر تحميل المحتوى. حاول مجددًا.',
      icon: Icons.error_outline_rounded,
    );
  }
}
