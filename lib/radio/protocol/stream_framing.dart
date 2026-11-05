import 'dart:typed_data';

import 'codes.dart';

/// USB serial and TCP carry frames on a byte stream, so each frame gets a
/// 3-byte header: a direction marker and a little-endian length. BLE doesn't
/// need this; each notification is already one frame.
abstract final class StreamFraming {
  /// Marks a frame going from the app to the radio.
  static const toRadio = 0x3C; // '<'

  /// Marks a frame coming from the radio.
  static const fromRadio = 0x3E; // '>'

  /// Wraps [frame] with the app-to-radio header.
  static Uint8List wrap(List<int> frame) {
    if (frame.isEmpty || frame.length > maxFrameSize) {
      throw ArgumentError.value(frame.length, 'frame', 'bad frame length');
    }
    return Uint8List(frame.length + 3)
      ..[0] = toRadio
      ..[1] = frame.length & 0xFF
      ..[2] = frame.length >> 8
      ..setRange(3, frame.length + 3, frame);
  }
}

/// Reassembles radio frames from stream chunks that can split or merge
/// frames anywhere. Bytes before a header (boot logs, noise) are skipped.
class StreamDeframer {
  final List<int> _buffer = [];

  /// Adds [chunk] and returns every frame it completes, in order.
  List<Uint8List> add(List<int> chunk) {
    _buffer.addAll(chunk);
    final frames = <Uint8List>[];
    while (true) {
      final start = _buffer.indexOf(StreamFraming.fromRadio);
      if (start < 0) {
        _buffer.clear();
        break;
      }
      if (start > 0) _buffer.removeRange(0, start);
      if (_buffer.length < 3) break;
      final length = _buffer[1] | (_buffer[2] << 8);
      if (length == 0 || length > maxFrameSize) {
        // Not a real header; drop the marker and look for the next one.
        _buffer.removeAt(0);
        continue;
      }
      if (_buffer.length < length + 3) break;
      frames.add(Uint8List.fromList(_buffer.sublist(3, length + 3)));
      _buffer.removeRange(0, length + 3);
    }
    return frames;
  }

  void reset() => _buffer.clear();
}
