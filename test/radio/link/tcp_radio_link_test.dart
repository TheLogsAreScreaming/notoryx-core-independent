import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../../support/radio_frames.dart';

void main() {
  late ServerSocket server;

  setUp(() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() => server.close());

  test('runs a session over TCP with the firmware framing', () async {
    final received = <List<int>>[];
    server.listen((client) {
      client.listen((bytes) {
        received.add(bytes);
        // Answer the app start split across two writes, as TCP may deliver.
        final frame = selfInfoFrame(name: 'WiFi Node');
        final wrapped = [0x3E, frame.length, 0, ...frame];
        client.add(wrapped.sublist(0, 10));
        Timer(
          const Duration(milliseconds: 5),
          () => client.add(wrapped.sublist(10)),
        );
      });
    });

    final link = await TcpRadioLink.connect('127.0.0.1', port: server.port);
    final session = RadioSession(link);
    final self = await session.request<SelfInfo>(const AppStart(appName: 'x'));

    expect(self.name, 'WiFi Node');
    expect(received.expand((b) => b).take(3), [0x3C, 9, 0]);
    await session.close();
    await link.done;
  });

  test('the link reports when the radio hangs up', () async {
    server.listen((client) => client.destroy());
    final link = await TcpRadioLink.connect('127.0.0.1', port: server.port);
    final session = RadioSession(link);
    await link.done;
    expect(session.isClosed, isTrue);
    await expectLater(
      link.send(const DeviceQuery().encode()),
      throwsA(isA<LinkClosedException>()),
    );
  });
}
