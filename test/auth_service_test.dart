import 'package:flutter_test/flutter_test.dart';
import 'package:mangaplus/app/data/models/user_profile.dart';
import 'package:mangaplus/app/data/services/auth_service.dart';

void main() {
  test('normalizes and validates supported usernames', () {
    expect(AuthService.normalizeUsername('  Reader_01 '), 'reader_01');
    expect(() => AuthService.validateUsername('reader_01'), returnsNormally);
    expect(() => AuthService.validateUsername('ab'), throwsA(isA<AuthException>()));
    expect(() => AuthService.validateUsername('اسم'), throwsA(isA<AuthException>()));
  });

  test('privacy defaults are conservative', () {
    const privacy = UserPrivacy();
    expect(privacy.bio, isTrue);
    expect(privacy.country, isFalse);
    expect(privacy.statistics, isFalse);
    expect(privacy.bookmarks, isFalse);
    expect(privacy.activity, isFalse);
  });
}
