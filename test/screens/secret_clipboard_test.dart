// The SARNEG clipboard is cleared after a minute even when the app can't
// read it, but text the person copied since is left alone.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/screens/sarneg/secret_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// What the fake clipboard holds; [readable] false acts like Android 10+
  /// with the app in the background, where reads come back empty.
  String? clip;
  var readable = true;

  setUp(() {
    clip = null;
    readable = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clip = (call.arguments as Map)['text'] as String?;
          } else if (call.method == 'Clipboard.getData') {
            return readable ? <String, dynamic>{'text': clip} : null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('our text still on the clipboard is cleared', () async {
    await copySecretText('[SARNEG] LRs KSAC');
    await clearClipboardIfStill('[SARNEG] LRs KSAC');
    expect(clip, '');
  });

  test('text copied since is left alone', () async {
    await copySecretText('[SARNEG] LRs KSAC');
    clip = 'meet at the trailhead';
    await clearClipboardIfStill('[SARNEG] LRs KSAC');
    expect(clip, 'meet at the trailhead');
  });

  test('a clipboard the app cannot read is cleared anyway', () async {
    await copySecretText('[SARNEG] LRs KSAC');
    readable = false;
    await clearClipboardIfStill('[SARNEG] LRs KSAC');
    expect(clip, '');
  });

  group('on Android', () {
    final calls = <MethodCall>[];
    const channel = MethodChannel('notoryx/clipboard');

    setUp(() {
      calls.clear();
      debugActAsAndroid = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      debugActAsAndroid = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('copying hands Android the text and when to clear it', () async {
      await copySecretText(
        '[SARNEG] LRs KSAC',
        clearAfter: const Duration(seconds: 60),
      );
      expect(calls.single.method, 'copySensitive');
      expect(calls.single.arguments, {
        'text': '[SARNEG] LRs KSAC',
        'clearAfterMs': 60000,
      });
      expect(clip, isNull, reason: 'Android copies it, not Flutter');
    });

    test('clearing goes through Android', () async {
      await clearClipboard();
      expect(calls.single.method, 'clear');
    });
  });
}
