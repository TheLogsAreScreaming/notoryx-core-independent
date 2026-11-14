import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';

int _u32(List<int> b, int at) =>
    ByteData.sublistView(Uint8List.fromList(b)).getUint32(at, Endian.little);

void main() {
  group('a circle on the wire', () {
    test('packs 14-bit latitude, 14-bit longitude and 4-bit radius', () {
      // The corners of the range land on the ends of each field.
      expect(
        const AreaCircle(
          latitude: -90,
          longitude: -180,
          radiusCode: 0,
        ).encode(),
        0,
      );
      expect(
        const AreaCircle(latitude: 90, longitude: 180, radiusCode: 14).encode(),
        (16383 << 18) | (16383 << 4) | 14,
      );
      // The middle of the world is half-way along each field.
      expect(
        const AreaCircle(latitude: 0, longitude: 0, radiusCode: 8).encode(),
        (8192 << 18) | (8192 << 4) | 8,
      );
    });

    test('reads back within about a kilometre', () {
      const at = AreaCircle(
        latitude: 47.6062,
        longitude: -122.3321,
        radiusCode: 5,
      );
      final back = AreaCircle.decode(at.encode());
      expect(back.latitude, closeTo(at.latitude, 0.011));
      expect(back.longitude, closeTo(at.longitude, 0.022));
      expect(back.radiusCode, 5);
      expect(back.radiusKm, 12);
    });

    test('out-of-range values are clamped, never spill into other bits', () {
      final word = const AreaCircle(
        latitude: 95,
        longitude: -200,
        radiusCode: 15,
      ).encode();
      expect(word >> 18, 16383);
      expect((word >> 4) & 0x3FFF, 0);
      expect(word & 0x0F, 14); // "no limit" is never sent
    });
  });

  group('the area post command', () {
    test('lays out text, circles, count and flags', () {
      const c1 = AreaCircle(latitude: 10, longitude: 20, radiusCode: 3);
      const c2 = AreaCircle(latitude: 11, longitude: 21, radiusCode: 8);
      final frame = SendChannelTextInArea(
        channel: 2,
        text: 'hi',
        timestamp: 0x01020304,
        circles: const [c1, c2],
        flags: areaFlagDestination | 0x02, // 0x02 is the firmware's own
      ).encode();
      expect(frame.sublist(0, 3), [53, 0, 2]);
      expect(_u32(frame, 3), 0x01020304);
      expect(utf8.decode(frame.sublist(7, 9)), 'hi');
      expect(_u32(frame, 9), c1.encode());
      expect(_u32(frame, 13), c2.encode());
      expect(frame.sublist(17), [2, areaFlagDestination]);
    });

    test('needs one to eight circles', () {
      SendChannelTextInArea area(int n) => SendChannelTextInArea(
        channel: 0,
        text: 'x',
        timestamp: 1,
        circles: List.filled(n, const AreaCircle(latitude: 1, longitude: 1)),
      );
      expect(() => area(0), throwsArgumentError);
      expect(() => area(9), throwsArgumentError);
      expect(area(8).encode().length, 7 + 1 + 32 + 2);
    });

    test('asking for the region is one byte; the reply is read', () {
      expect(const GetAreaRegion().encode(), [69]);
      final reply = decodeFrame([31, ...utf8.encode('valley'), 0, 0, 0]);
      expect(reply, isA<AreaRegionReply>());
      expect((reply as AreaRegionReply).name, 'valley');
    });
  });
}
