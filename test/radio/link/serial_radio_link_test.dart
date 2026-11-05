import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

import '../../support/radio_frames.dart';

/// A serial port whose far end is a radio answering through [respond].
class _FakePort implements SerialByteChannel {
  final _input = StreamController<Uint8List>();
  final written = <int>[];
  final _deframer = _Unwrapper();
  List<List<int>> Function(Uint8List frame) respond = (_) => [];
  bool closed = false;

  /// Delivers [bytes] as the radio would, one byte at a time, to prove the
  /// link copes with frames split anywhere.
  void trickle(List<int> bytes) {
    for (final b in bytes) {
      _input.add(Uint8List.fromList([b]));
    }
  }

  void unplug() => _input.close();

  @override
  Stream<Uint8List> get input => _input.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    written.addAll(bytes);
    for (final frame in _deframer.add(bytes)) {
      for (final reply in respond(frame)) {
        scheduleMicrotask(() => trickle([0x3E, reply.length, 0, ...reply]));
      }
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!_input.isClosed) await _input.close();
  }
}

/// Strips the app-to-radio header, the radio side of the framing.
class _Unwrapper {
  final _buf = <int>[];

  List<Uint8List> add(List<int> bytes) {
    _buf.addAll(bytes);
    final out = <Uint8List>[];
    while (_buf.length >= 3 && _buf[0] == 0x3C) {
      final len = _buf[1] | _buf[2] << 8;
      if (_buf.length < len + 3) break;
      out.add(Uint8List.fromList(_buf.sublist(3, len + 3)));
      _buf.removeRange(0, len + 3);
    }
    return out;
  }
}

void main() {
  test('a session runs over serial with byte-by-byte replies', () async {
    final port = _FakePort()
      ..respond = (frame) => frame[0] == CommandCode.deviceQuery
          ? [deviceInfoFrame(maxChannels: 8)]
          : [];
    final session = RadioSession(SerialRadioLink(port));

    final info = await session.request<DeviceInfo>(const DeviceQuery());
    expect(info.firmwareVersionCode, 14);
    expect(port.written, [0x3C, 2, 0, CommandCode.deviceQuery, 3]);

    await session.close();
    expect(port.closed, isTrue);
  });

  test('boot text on the port before the first frame is ignored', () async {
    final port = _FakePort();
    final link = SerialRadioLink(port);
    final frames = <Uint8List>[];
    link.frames.listen(frames.add);

    port.trickle([...'ESP-ROM:esp32s3\r\n'.codeUnits, 0x3E, 1, 0, 0x83]);
    await pumpEventQueue();
    expect(frames, [
      [0x83],
    ]);
    await link.close();
  });

  test(
    'unplugging the cable ends the link and fails pending commands',
    () async {
      final port = _FakePort();
      final link = SerialRadioLink(port);
      final session = RadioSession(link);
      final pending = session.run(const SendSelfAdvert());
      await pumpEventQueue();

      port.unplug();
      await link.done;
      await expectLater(pending, throwsA(isA<RadioDisconnected>()));
      await expectLater(
        link.send(const DeviceQuery().encode()),
        throwsA(isA<LinkClosedException>()),
      );
    },
  );
}
