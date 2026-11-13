import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:notoryx_core/radio/protocol/mesh_photo.dart';

void main() {
  Uint8List photo() {
    final big = img.Image(width: 640, height: 480);
    for (var y = 0; y < 480; y++) {
      for (var x = 0; x < 640; x++) {
        big.setPixelRgb(x, y, (x * 7) % 256, (y * 3) % 256, (x + y) % 256);
      }
    }
    return Uint8List.fromList(img.encodePng(big));
  }

  test('a big photo becomes a tiny greyscale JPEG', () {
    final jpg = encodeMeshPhoto(photo())!;
    expect(jpg.length, lessThanOrEqualTo(maxPhotoBytes));
    final back = img.decodeJpg(jpg)!;
    expect(back.width, photoSide);
    expect(back.height, 48);
  });

  test('not an image', () {
    expect(encodeMeshPhoto(Uint8List.fromList([1, 2, 3])), isNull);
  });

  test('chunks fit a datagram and reassemble in any order', () {
    final jpg = encodeMeshPhoto(photo())!;
    final chunks = photoChunks(0x01020304, jpg);
    for (final c in chunks) {
      expect(c.length, lessThanOrEqualTo(165));
    }
    final got = <int, Uint8List>{};
    for (final c in chunks.reversed) {
      final p = parsePhotoChunk(c)!;
      expect(p.id, 0x01020304);
      expect(p.count, chunks.length);
      got[p.index] = p.data;
    }
    expect(assemblePhoto(got, chunks.length), jpg);
    got.remove(0);
    expect(assemblePhoto(got, chunks.length), isNull);
  });

  test('captions carry the id; other text does not', () {
    expect(photoIdIn(photoCaption(0xabc)), 0xabc);
    expect(photoIdIn('📷 Photo of the summit'), isNull);
  });

  test('signature datagrams are not mistaken for photo chunks', () {
    expect(
      parsePhotoChunk(
        Uint8List.fromList([0x4E, 0x58, 0x01, ...List.filled(100, 0)]),
      ),
      isNull,
    );
    expect(parsePhotoChunk(Uint8List(5)), isNull);
  });
}
