import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/keep_alive.dart';
import 'package:notoryx_core/app/radio_connector.dart';

void main() {
  const target = TcpTarget(host: 'radio.local', port: 5000);

  test('reconnecting keeps the app alive with the radio name', () {
    expect(
      keepAliveText(
        const Reconnecting(target: target, radioKey: 'aa', radioName: 'Base'),
      ),
      'Reconnecting to Base',
    );
  });

  test('nothing is kept alive while disconnected or first connecting', () {
    expect(keepAliveText(const Disconnected()), isNull);
    expect(keepAliveText(const Connecting(target)), isNull);
  });
}
