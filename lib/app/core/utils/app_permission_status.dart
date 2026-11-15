import 'package:permission_handler/permission_handler.dart';

/// Platform-agnostic view of a permission state.
///
/// `permission_handler` exposes six booleans on [PermissionStatus]; mapping them
/// once keeps the UI from re-deriving them at each call site and lets the
/// settings screen decide between "ask again" and "open system settings".
enum AppPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
  unknown;

  static AppPermissionStatus fromPermissionStatus(PermissionStatus status) {
    if (status.isGranted || status.isProvisional) {
      return AppPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return AppPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) return AppPermissionStatus.restricted;
    if (status.isLimited) return AppPermissionStatus.limited;
    if (status.isDenied) return AppPermissionStatus.denied;
    return AppPermissionStatus.unknown;
  }

  bool get isGranted => this == AppPermissionStatus.granted;

  /// Android only shows the system dialog once; afterwards the app can only
  /// send the user to the system settings page.
  bool get mustOpenSettings =>
      this == AppPermissionStatus.permanentlyDenied ||
      this == AppPermissionStatus.restricted;

  bool get canRequest => this == AppPermissionStatus.denied;
}
