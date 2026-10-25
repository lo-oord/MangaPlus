import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:mangaplus/app/data/services/chapter_update_service.dart';

class ChapterUpdateCoordinator with WidgetsBindingObserver {
  ChapterUpdateCoordinator(this._service);

  static const EventChannel _connectivityChannel =
      EventChannel('com.mangaplus.app/connectivity');
  static const Duration _foregroundInterval = Duration(minutes: 10);

  final ChapterUpdateService _service;
  StreamSubscription<dynamic>? _connectivitySubscription;
  Timer? _foregroundTimer;
  bool _isResumed = true;
  bool? _wasOnline;
  bool _checkInProgress = false;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription = _connectivityChannel
        .receiveBroadcastStream()
        .listen(_onConnectivityChanged, onError: (_) {});
    _startForegroundTimer();
    unawaited(_checkNow());
  }

  void _onConnectivityChanged(dynamic value) {
    final isOnline = value == true;
    final returnedOnline = isOnline && _wasOnline == false;
    _wasOnline = isOnline;
    if (returnedOnline && _isResumed) unawaited(_checkNow());
  }

  void _startForegroundTimer() {
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(
      _foregroundInterval,
      (_) => unawaited(_checkNow()),
    );
  }

  Future<void> _checkNow() async {
    if (_checkInProgress || !_service.backgroundEnabled) return;
    _checkInProgress = true;
    try {
      await _service.checkOnAppOpen();
    } finally {
      _checkInProgress = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isResumed = true;
      _startForegroundTimer();
      unawaited(_checkNow());
    } else {
      _isResumed = false;
      _foregroundTimer?.cancel();
      _foregroundTimer = null;
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundTimer?.cancel();
    await _connectivitySubscription?.cancel();
  }
}
