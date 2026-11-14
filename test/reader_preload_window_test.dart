import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/core/reader/reader_preload_window.dart';

void main() {
  group('readerPreloadWindow', () {
    test('warms ahead when reading forward', () {
      final window = readerPreloadWindow(
        firstVisible: 10,
        lastVisible: 12,
        total: 100,
        distance: 6,
        direction: 1,
      );
      expect(window.start, 9);
      expect(window.end, 18);
    });

    test('warms behind when reading backwards', () {
      final window = readerPreloadWindow(
        firstVisible: 10,
        lastVisible: 12,
        total: 100,
        distance: 6,
        direction: -1,
      );
      expect(window.start, 4);
      expect(window.end, 13);
    });

    test('stays symmetric when the direction is unknown', () {
      final window = readerPreloadWindow(
        firstVisible: 10,
        lastVisible: 12,
        total: 100,
        distance: 6,
      );
      expect(window.start, 9);
      expect(window.end, 13);
    });

    test('never runs past either end of the chapter', () {
      final start = readerPreloadWindow(
        firstVisible: 0,
        lastVisible: 1,
        total: 50,
        distance: 8,
        direction: -1,
      );
      expect(start.start, 0);
      expect(start.end, 2);

      final end = readerPreloadWindow(
        firstVisible: 46,
        lastVisible: 49,
        total: 50,
        distance: 8,
        direction: 1,
      );
      expect(end.start, 45);
      expect(end.end, 49);
    });

    test('an empty chapter has no window', () {
      final window = readerPreloadWindow(
        firstVisible: 0,
        lastVisible: 0,
        total: 0,
        distance: 6,
      );
      expect(window.length, 0);
    });

    test('clamps the configured distance to a sane range', () {
      final tiny = readerPreloadWindow(
        firstVisible: 20,
        lastVisible: 20,
        total: 100,
        distance: 0,
        direction: 1,
      );
      expect(tiny.end, 21);

      final huge = readerPreloadWindow(
        firstVisible: 20,
        lastVisible: 20,
        total: 100,
        distance: 99,
        direction: 1,
      );
      expect(huge.end, 32);
    });
  });
}
