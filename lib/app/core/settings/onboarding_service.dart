import 'package:get_storage/get_storage.dart';
import 'package:mangaplus/app/core/settings/reading_preferences.dart';

/// First-launch setup state.
///
/// The flag is intentionally independent from the reader/appearance values, so
/// replaying onboarding never destroys a user's saved preferences: the screen
/// only writes the values the user confirms.
class OnboardingService {
  const OnboardingService._();

  static const String _completedKey = 'onboarding_completed';

  static bool get isComplete => GetStorage().read<bool>(_completedKey) == true;

  static Future<void> complete() =>
      GetStorage().write(_completedKey, true);

  static Future<void> restart() =>
      GetStorage().remove(_completedKey);

  /// Seeds the reader defaults that the onboarding screen exposes.
  ///
  /// Only mentioned settings are written; the rest of the reader state stays
  /// exactly as it was.
  static Future<void> saveReadingDefaults({
    required String mode,
    required String direction,
  }) async {
    final storage = GetStorage();
    await storage.write(
      ReadingPreferences.modeKey,
      ReadingPreferences.normalizeMode(mode),
    );
    await storage.write(
      ReadingPreferences.directionKey,
      ReadingPreferences.normalizeDirection(direction),
    );
  }
}
