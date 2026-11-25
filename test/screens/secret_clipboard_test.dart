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
}
