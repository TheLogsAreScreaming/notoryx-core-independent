import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

void main() {
  test('wrap adds the to-radio marker and little-endian length', () {
    expect(StreamFraming.wrap([0x16, 0x03]), [0x3C, 2, 0, 0x16, 0x03]);
  });

  test('wrap refuses empty and oversized frames', () {
    expect(() => StreamFraming.wrap([]), throwsArgumentError);
    expect(
      () => StreamFraming.wrap(List.filled(maxFrameSize + 1, 0)),
      throwsArgumentError,
    );
  });

  test('frames split across chunks are reassembled', () {
    final deframer = StreamDeframer();
    expect(deframer.add([0x3E, 3]), isEmpty);
    expect(deframer.add([0, 0x00, 0x01]), isEmpty);
    expect(deframer.add([0x02]), [
      [0x00, 0x01, 0x02],
    ]);
  });

  test('several frames in one chunk come out in order', () {
    final deframer = StreamDeframer();
    final frames = deframer.add([0x3E, 1, 0, 0x0A, 0x3E, 1, 0, 0x83]);
    expect(frames, [
      [0x0A],
      [0x83],
    ]);
  });

  test('noise before a header is skipped', () {
    final deframer = StreamDeframer();
    final frames = deframer.add([...'boot ok\r\n'.codeUnits, 0x3E, 1, 0, 0]);
    expect(frames, [
      [0],
    ]);
  });

  test('a marker with an impossible length is not taken as a header', () {
    final deframer = StreamDeframer();
    final frames = deframer.add([0x3E, 0xFF, 0xFF, 0x3E, 1, 0, 0x0A]);
    expect(frames, [
      [0x0A],
    ]);
  });
}
