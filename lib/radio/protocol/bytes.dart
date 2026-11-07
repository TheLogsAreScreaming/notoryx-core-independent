import 'dart:convert';
import 'dart:typed_data';

/// Builds a little-endian frame one field at a time.
class FrameWriter {
  final BytesBuilder _out = BytesBuilder(copy: false);

  void u8(int value) => _out.addByte(value & 0xFF);

  void i8(int value) => _out.addByte(value & 0xFF);

  void u32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    _out.add(data.buffer.asUint8List());
  }

  void i32(int value) {
    final data = ByteData(4)..setInt32(0, value, Endian.little);
    _out.add(data.buffer.asUint8List());
  }

  void bytes(List<int> value) => _out.add(value);

  /// Writes [text] as UTF-8 into exactly [width] bytes, zero-padded. Text that
  /// doesn't fit is cut at a character boundary, leaving room for a final zero.
  void fixedString(String text, int width) {
    final encoded = utf8Prefix(text, width - 1);
    _out.add(encoded);
    _out.add(Uint8List(width - encoded.length));
  }

  /// Writes [text] as UTF-8 with no terminator.
  void string(String text) => _out.add(utf8.encode(text));

  Uint8List toBytes() => _out.toBytes();
}

/// Reads little-endian fields from a frame. Every read checks bounds first, so
/// a short frame raises [FormatException] instead of returning garbage.
class FrameReader {
  FrameReader(this._data) : _view = ByteData.sublistView(_data);

  final Uint8List _data;
  final ByteData _view;
  int _offset = 0;

  int get remaining => _data.length - _offset;

  void _need(int count) {
    if (remaining < count) {
      throw FormatException('frame too short: need $count, have $remaining');
    }
  }

  int u8() {
    _need(1);
    return _data[_offset++];
  }

  int i8() {
    _need(1);
    return _view.getInt8(_offset++);
  }

  int u16() {
    _need(2);
    final value = _view.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int i16() {
    _need(2);
    final value = _view.getInt16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int u32() {
    _need(4);
    final value = _view.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int i32() {
    _need(4);
    final value = _view.getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  Uint8List bytes(int count) {
    _need(count);
    final value = Uint8List.fromList(_data.sublist(_offset, _offset + count));
    _offset += count;
    return value;
  }

  void skip(int count) {
    _need(count);
    _offset += count;
  }

  /// Reads a [width]-byte zero-padded UTF-8 field.
  String fixedString(int width) => decodeText(bytes(width));

  /// Reads everything left as UTF-8 text.
  String rest() => decodeText(bytes(remaining));

  Uint8List restBytes() => bytes(remaining);
}

/// Decodes UTF-8 up to the first zero byte. The firmware can cut text
/// mid-character when a frame is full, so bad sequences become U+FFFD instead
/// of failing.
String decodeText(List<int> raw) {
  final end = raw.indexOf(0);
  return utf8.decode(end < 0 ? raw : raw.sublist(0, end), allowMalformed: true);
}

/// The longest UTF-8 encoding of [text] that fits in [maxBytes] without
/// splitting a character.
Uint8List utf8Prefix(String text, int maxBytes) {
  final out = BytesBuilder(copy: false);
  for (final rune in text.runes) {
    final encoded = utf8.encode(String.fromCharCode(rune));
    if (out.length + encoded.length > maxBytes) break;
    out.add(encoded);
  }
  return out.toBytes();
}

/// Lowercase hex of [bytes], two characters per byte.
String toHex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Parses lowercase or uppercase hex with no separators.
Uint8List fromHex(String hex) {
  if (hex.length.isOdd) throw FormatException('odd-length hex: $hex');
  return Uint8List.fromList([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}
