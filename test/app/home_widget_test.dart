import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/home_widget.dart';

void main() {
  test('no radio', () {
    expect(widgetLines(const Disconnected()).status, 'No radio connected');
    expect(
      widgetLines(const ViewingSaved(radioKey: 'k', radioName: 'Base')).status,
      'No radio connected',
    );
  });

  test('last check-in shows, and SOS takes priority', () {
    final at = DateTime(2026, 11, 9, 7, 5);
    expect(
      widgetLines(const Disconnected(), lastCheckIn: at).detail,
      'Last check-in 07:05',
    );
    expect(
      widgetLines(
        const Disconnected(),
        lastCheckIn: at,
        sosActive: true,
      ).detail,
      'SOS is active',
    );
  });

  test('with the app lock on, details stay off the home screen', () {
    final at = DateTime(2026, 11, 9, 7, 5);
    expect(
      widgetLines(const Disconnected(), lastCheckIn: at, private: true).detail,
      '',
    );
  });
}
