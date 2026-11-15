/// A colour or photo the person picks for a node, kept on this phone only.
///
/// Looks live in the settings table under `nodeLook.<public key>`, so they
/// go into backups with everything else and never go over the air.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../data/data.dart';
import 'connection.dart';

/// Settings key prefix for node looks.
const nodeLookPrefix = 'nodeLook.';

/// Photos are cut to a square this many pixels across.
const nodePhotoSize = 192;

/// What a node looks like in its avatar.
sealed class NodeLook {
  const NodeLook();

  /// The stored form.
  String encode();

  /// The look stored as [raw], or null if it isn't one.
  static NodeLook? decode(String raw) {
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      if (map['colour'] case final int argb) return NodeColour(Color(argb));
      if (map['photo'] case final String data) {
        return NodePhoto(base64Decode(data));
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

/// A plain colour behind the initials or type icon.
final class NodeColour extends NodeLook {
  const NodeColour(this.colour);

  final Color colour;

  @override
  String encode() => jsonEncode({'colour': colour.toARGB32()});
}

/// A small square JPEG.
final class NodePhoto extends NodeLook {
  NodePhoto(this.jpeg) : image = MemoryImage(jpeg);

  final Uint8List jpeg;

  /// Made once, so lists don't flicker while it decodes again.
  final MemoryImage image;

  @override
  String encode() => jsonEncode({'photo': base64Encode(jpeg)});
}

/// The colours offered, in the order shown.
const nodeColours = <Color>[
  Color(0xFFC62828), // red
  Color(0xFFEF6C00), // orange
  Color(0xFFF9A825), // amber
  Color(0xFF2E7D32), // green
  Color(0xFF00897B), // teal
  Color(0xFF0097A7), // cyan
  Color(0xFF1565C0), // blue
  Color(0xFF3949AB), // indigo
  Color(0xFF7B1FA2), // purple
  Color(0xFFD81B60), // pink
  Color(0xFF6D4C41), // brown
  Color(0xFF546E7A), // grey
];

/// The settings key for [publicKey]'s look.
String nodeLookKey(String publicKey) =>
    '$nodeLookPrefix${publicKey.toLowerCase()}';

/// Every node look, by lower-case public key.
final nodeLooksProvider = StreamProvider<Map<String, NodeLook>>((ref) {
  final cache = <String, NodeLook>{};
  return ref
      .watch(storeProvider)
      .watchSettingsWithPrefix(nodeLookPrefix)
      .map(
        (raw) => {
          for (final MapEntry(:key, :value) in raw.entries)
            if (cache[value] ??= NodeLook.decode(value) ?? _none
                case final NodeLook look when look is! _NoLook)
              key: look,
        },
      );
});

final class _NoLook extends NodeLook {
  const _NoLook();

  @override
  String encode() => '';
}

const _none = _NoLook();

/// Saves [look] for [publicKey], or clears it when [look] is null.
Future<void> saveNodeLook(MeshStore store, String publicKey, NodeLook? look) =>
    look == null
    ? store.removeSetting(nodeLookKey(publicKey))
    : store.saveSetting(nodeLookKey(publicKey), look.encode());

/// [source] cut to a centred square [nodePhotoSize] across, as a JPEG, or
/// null if it isn't a picture.
Uint8List? squareAvatarJpeg(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;
  final upright = img.bakeOrientation(decoded);
  final side = upright.width < upright.height ? upright.width : upright.height;
  final square = img.copyCrop(
    upright,
    x: (upright.width - side) ~/ 2,
    y: (upright.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final small = img.copyResize(
    square,
    width: nodePhotoSize,
    height: nodePhotoSize,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(img.encodeJpg(small, quality: 80));
}

/// Asks for a picture from the gallery and returns it ready to store; null
/// if none was picked, empty if it couldn't be read. Tests replace this.
final nodePhotoPickerProvider = Provider<Future<Uint8List?> Function()>(
  (ref) => () async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return await Isolate.run(() => squareAvatarJpeg(bytes)) ?? Uint8List(0);
  },
);

/// Black or white, whichever reads better on [background].
Color onColour(Color background) => background.computeLuminance() > 0.4
    ? const Color(0xFF000000)
    : const Color(0xFFFFFFFF);

/// Up to two initials from [name], or empty if it has no letters.
String nodeInitials(String name) {
  final words = name
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  String first(String w) => String.fromCharCode(w.runes.first).toUpperCase();
  return words.length == 1
      ? first(words.first)
      : first(words.first) + first(words[1]);
}
