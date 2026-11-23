import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps screenshots, screen recording and the recent-apps preview off while
/// a screen holding a secret is open. On Android this sets FLAG_SECURE on
/// the window; on macOS the window is left out of screenshots and screen
/// sharing. iOS has no supported way to block screenshots, so nothing
/// happens there (nor on the web, or in tests).
///
/// Screens [hold] it while open and [release] it when closed; it stays on
/// while any screen still holds it, so a sheet opened over a secure screen
/// can't switch it off underneath.
class ScreenPrivacy {
  ScreenPrivacy._();

  static const _channel = MethodChannel('notoryx/screen_privacy');
  static int _holders = 0;

  /// How many screens hold it now.
  @visibleForTesting
  static int get holders => _holders;

  /// The last state sent to the platform, for tests.
  @visibleForTesting
  static bool secure = false;

  static void hold() {
    _holders++;
    if (_holders == 1) _set(true);
  }

  static void release() {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) _set(false);
  }

  static void _set(bool on) {
    secure = on;
    if (kIsWeb) return;
    _channel.invokeMethod<void>('setSecure', on).catchError((Object _) {
      // No handler on this platform (iOS, tests): nothing to block with.
    });
  }
}
