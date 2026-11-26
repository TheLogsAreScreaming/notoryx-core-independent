// The clipboard for SARNEG text: marked sensitive where the platform allows,
// and removed for real when it's cleared.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('notoryx/clipboard');

/// Tests set this to act as Android (true) or not (false).
@visibleForTesting
bool? debugActAsAndroid;

bool get _android => debugActAsAndroid ?? (!kIsWeb && Platform.isAndroid);

/// Copies [text]. On Android it is marked sensitive, so the system and
/// well-behaved keyboards don't show it in previews or keep it in history.
///
/// With [clearAfter], Android also schedules the clear itself, so it still
/// happens if the app is frozen or killed first (Samsung does both within a
/// minute of leaving the screen). Callers keep their own timer too, for
/// other platforms and older native builds.
Future<void> copySecretText(String text, {Duration? clearAfter}) async {
  if (_android) {
    try {
      await _channel.invokeMethod<void>('copySensitive', <String, Object>{
        'text': text,
        'clearAfterMs': clearAfter?.inMilliseconds ?? 0,
      });
      return;
    } on MissingPluginException {
      // Older native build: fall through to the plain copy.
    } on PlatformException catch (e) {
      debugPrint('SARNEG: sensitive copy failed (${e.code})');
    }
  }
  await Clipboard.setData(ClipboardData(text: text));
}

/// Empties the clipboard. On Android the clip is removed, so apps offer
/// nothing to paste.
Future<void> clearClipboard() async {
  if (_android) {
    try {
      await _channel.invokeMethod<void>('clear');
      return;
    } on MissingPluginException {
      // Older native build: fall through to the plain clear.
    } on PlatformException catch (e) {
      debugPrint('SARNEG: clipboard clear failed (${e.code})');
    }
  }
  await Clipboard.setData(const ClipboardData(text: ''));
}

/// Clears the clipboard if it still holds [value].
///
/// Android 10 and later won't let an app in the background read the
/// clipboard, and that's where SARNEG text usually is a minute later (the
/// person switched apps to paste it). When it can't be read, clear it
/// anyway: leaving a code word behind is worse than dropping something
/// copied in the last minute.
Future<void> clearClipboardIfStill(String value) async {
  try {
    final now = await Clipboard.getData(Clipboard.kTextPlain);
    if (now == null || now.text == null || now.text == value) {
      await clearClipboard();
    }
  } on Exception catch (e) {
    // Never log the text itself.
    debugPrint('SARNEG: clipboard not cleared (${e.runtimeType})');
  }
}

/// Whether Android can clear copied text right on time.
enum ExactClearStatus {
  /// Android before 12: always on time, nothing to allow.
  notNeeded,

  /// Allowed under "Alarms & reminders".
  allowed,

  /// Not allowed: the clear may run up to about a minute late.
  notAllowed,
}

/// The exact-clear status, or null off Android (other platforms clear with
/// the app's own timer).
Future<ExactClearStatus?> exactClearStatus() async {
  if (!_android) return null;
  try {
    final status = await _channel.invokeMethod<String>('exactClearStatus');
    return ExactClearStatus.values.asNameMap()[status];
  } on MissingPluginException {
    return null;
  } on PlatformException catch (e) {
    debugPrint('SARNEG: exact clear status failed (${e.code})');
    return null;
  }
}

/// Opens Android's "Alarms & reminders" page for this app.
Future<void> openExactClearSettings() async {
  if (!_android) return;
  try {
    await _channel.invokeMethod<void>('openExactClearSettings');
  } on MissingPluginException {
    // Older native build: nothing to open.
  } on PlatformException catch (e) {
    debugPrint('SARNEG: could not open alarm settings (${e.code})');
  }
}
