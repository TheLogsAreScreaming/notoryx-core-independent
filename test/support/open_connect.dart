import 'package:flutter_test/flutter_test.dart';

/// Opens the connect screen from the home screen, if it isn't already open.
Future<void> openConnect(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  final button = find.byTooltip('Connect a radio');
  if (button.evaluate().isEmpty) return;
  await tester.tap(button);
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
