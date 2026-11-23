import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/screen_privacy.dart';
import 'package:notoryx_core/app/no_screenshots.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <bool>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('notoryx/screen_privacy'),
          (call) async {
            if (call.method == 'setSecure') calls.add(call.arguments as bool);
            return null;
          },
        );
  });

  testWidgets('on while any secure screen is open, off after the last', (
    tester,
  ) async {
    var sheet = true;
    late StateSetter setOuter;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return Column(
            textDirection: TextDirection.ltr,
            children: [
              const NoScreenshots(child: SizedBox()),
              if (sheet) const NoScreenshots(child: SizedBox()),
            ],
          );
        },
      ),
    );
    expect(ScreenPrivacy.holders, 2);
    expect(calls, [true], reason: 'switched on once');

    setOuter(() => sheet = false);
    await tester.pump();
    expect(ScreenPrivacy.holders, 1);
    expect(calls, [true], reason: 'a closing sheet leaves it on');

    await tester.pumpWidget(const SizedBox());
    expect(ScreenPrivacy.holders, 0);
    expect(calls, [true, false]);
    expect(ScreenPrivacy.secure, isFalse);
  });

  test('a platform without the channel is fine', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('notoryx/screen_privacy'),
          null,
        );
    ScreenPrivacy.hold();
    ScreenPrivacy.release();
    ScreenPrivacy.release(); // an extra release is ignored
    expect(ScreenPrivacy.holders, 0);
  });
}
