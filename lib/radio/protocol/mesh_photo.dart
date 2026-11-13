/// Tiny photos over the mesh: a greyscale JPEG of at most [maxPhotoBytes],
/// sent as numbered channel datagrams after a "📷 Photo #id" post, which
/// says who sent it. Apps that don't know the datagrams see only the post.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const maxPhotoBytes = 1500;

/// Longest side of a sent photo, in pixels.
const photoSide = 64;

const _magic = [0x4E, 0x58, 0x02]; // "NX", photo chunk
const _headerBytes = 3 + 4 + 1 + 1;

/// Payload room in one channel datagram.
const photoChunkBytes = 165 - _headerBytes;

/// [source] (any common image format) as a tiny greyscale JPEG, or null if
/// it can't be read or made small enough.
Uint8List? encodeMeshPhoto(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;
  final small = decoded.width >= decoded.height
      ? img.copyResize(decoded, width: photoSide)
      : img.copyResize(decoded, height: photoSide);
  final grey = img.grayscale(small);
  for (var quality = 60; quality >= 10; quality -= 10) {
    final jpg = Uint8List.fromList(img.encodeJpg(grey, quality: quality));
    if (jpg.length <= maxPhotoBytes) return jpg;
  }
  return null;
}

/// The post that goes before the chunks.
String photoCaption(int id) =>
    '📷 Photo #${id.toRadixString(16).padLeft(8, '0')}';

/// The photo id in a caption, or null.
int? photoIdIn(String text) {
  final m = RegExp(r'^📷 Photo #([0-9a-f]{8})$').firstMatch(text.trim());
  return m == null ? null : int.parse(m[1]!, radix: 16);
}

int newPhotoId([math.Random? random]) =>
    (random ?? math.Random.secure()).nextInt(0xFFFFFFFF) + 1;

/// [jpeg] split into datagram payloads.
List<Uint8List> photoChunks(int id, Uint8List jpeg) {
  final count = (jpeg.length / photoChunkBytes).ceil();
  return [
    for (var i = 0; i < count; i++)
      Uint8List.fromList([
        ..._magic,
        id & 0xFF,
        (id >> 8) & 0xFF,
        (id >> 16) & 0xFF,
        (id >> 24) & 0xFF,
        i,
        count,
        ...jpeg.sublist(
          i * photoChunkBytes,
          math.min((i + 1) * photoChunkBytes, jpeg.length),
        ),
      ]),
  ];
}

typedef PhotoPiece = ({int id, int index, int count, Uint8List data});

/// [payload] as a photo chunk, or null.
PhotoPiece? parsePhotoChunk(Uint8List payload) {
  if (payload.length <= _headerBytes) return null;
  for (var i = 0; i < 3; i++) {
    if (payload[i] != _magic[i]) return null;
  }
  final id = ByteData.sublistView(payload, 3, 7).getUint32(0, Endian.little);
  final index = payload[7];
  final count = payload[8];
  if (count == 0 || index >= count || count > 20) return null;
  return (
    id: id,
    index: index,
    count: count,
    data: Uint8List.sublistView(payload, _headerBytes),
  );
}

/// The whole photo from [chunks] (data by index), or null while any is
/// missing.
Uint8List? assemblePhoto(Map<int, Uint8List> chunks, int count) {
  if (chunks.length < count) return null;
  final out = BytesBuilder();
  for (var i = 0; i < count; i++) {
    final c = chunks[i];
    if (c == null) return null;
    out.add(c);
  }
  return out.toBytes();
}
