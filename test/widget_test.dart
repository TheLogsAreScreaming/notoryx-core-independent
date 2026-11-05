import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/main.dart';

void main() {
  testWidgets('shows the placeholder screen', (tester) async {
    await tester.pumpWidget(const NotoryxApp());
    expect(find.text('NOTORYX Core — in development'), findsOneWidget);
  });
}
