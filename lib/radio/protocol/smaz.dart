/// SMAZ, the short-text compression some MeshCore apps use for messages,
/// written from Salvatore Sanfilippo's original C library
/// (https://github.com/antirez/smaz, BSD 3-clause, see
/// third_party/smaz/LICENSE). The codebook below is his, unchanged, so the
/// bytes match every other SMAZ implementation.
///
/// On the air a compressed message is `s:` followed by the compressed bytes
/// in base64.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Antirez's codebook: code n stands for entry n.
const _codebook = <String>[
  ' ',
  'the',
  'e',
  't',
  'a',
  'of',
  'o',
  'and',
  'i',
  'n',
  's',
  'e ',
  'r',
  ' th',
  ' t',
  'in',
  'he',
  'th',
  'h',
  'he ',
  'to',
  '\r\n',
  'l',
  's ',
  'd',
  ' a',
  'an',
  'er',
  'c',
  ' o',
  'd ',
  'on',
  ' of',
  're',
  'of ',
  't ',
  ', ',
  'is',
  'u',
  'at',
  '   ',
  'n ',
  'or',
  'which',
  'f',
  'm',
  'as',
  'it',
  'that',
  '\n',
  'was',
  'en',
  '  ',
  ' w',
  'es',
  ' an',
  ' i',
  '\r',
  'f ',
  'g',
  'p',
  'nd',
  ' s',
  'nd ',
  'ed ',
  'w',
  'ed',
  'http://',
  'for',
  'te',
  'ing',
  'y ',
  'The',
  ' c',
  'ti',
  'r ',
  'his',
  'st',
  ' in',
  'ar',
  'nt',
  ',',
  ' to',
  'y',
  'ng',
  ' h',
  'with',
  'le',
  'al',
  'to ',
  'b',
  'ou',
  'be',
  'were',
  ' b',
  'se',
  'o ',
  'ent',
  'ha',
  'ng ',
  'their',
  '"',
  'hi',
  'from',
  ' f',
  'in ',
  'de',
  'ion',
  'me',
  'v',
  '.',
  've',
  'all',
  're ',
  'ri',
  'ro',
  'is ',
  'co',
  'f t',
  'are',
  'ea',
  '. ',
  'her',
  ' m',
  'er ',
  ' p',
  'es ',
  'by',
  'they',
  'di',
  'ra',
  'ic',
  'not',
  's, ',
  'd t',
  'at ',
  'ce',
  'la',
  'h ',
  'ne',
  'as ',
  'tio',
  'on ',
  'n t',
  'io',
  'we',
  ' a ',
  'om',
  ', a',
  's o',
  'ur',
  'li',
  'll',
  'ch',
  'had',
  'this',
  'e t',
  'g ',
  'e\r\n',
  ' wh',
  'ere',
  ' co',
  'e o',
  'a ',
  'us',
  ' d',
  'ss',
  '\n\r\n',
  '\r\n\r',
  '="',
  ' be',
  ' e',
  's a',
  'ma',
  'one',
  't t',
  'or ',
  'but',
  'el',
  'so',
  'l ',
  'e s',
  's,',
  'no',
  'ter',
  ' wa',
  'iv',
  'ho',
  'e a',
  ' r',
  'hat',
  's t',
  'ns',
  'ch ',
  'wh',
  'tr',
  'ut',
  '/',
  'have',
  'ly ',
  'ta',
  ' ha',
  ' on',
  'tha',
  '-',
  ' l',
  'ati',
  'en ',
  'pe',
  ' re',
  'there',
  'ass',
  'si',
  ' fo',
  'wa',
  'ec',
  'our',
  'who',
  'its',
  'z',
  'fo',
  'rs',
  '>',
  'ot',
  'un',
  '<',
  'im',
  'th ',
  'nc',
  'ate',
  '><',
  'ver',
  'ad',
  ' we',
  'ly',
  'ee',
  ' n',
  'id',
  ' cl',
  'ac',
  'il',
  '</',
  'rt',
  ' wi',
  'div',
  'e, ',
  ' it',
  'whi',
  ' ma',
  'ge',
  'x',
  'e c',
  'men',
  '.com',
];

final List<Uint8List> _entries = [
  for (final e in _codebook) Uint8List.fromList(latin1.encode(e)),
];

/// Codes by entry, for the encoder.
final Map<String, int> _codes = {
  for (var i = 0; i < _codebook.length; i++) _codebook[i]: i,
};

const _longestEntry = 7;
const _oneLiteral = 254;
const _literalRun = 255;

/// The marker in front of a compressed message.
const smazMarker = 's:';

/// Compresses [input] bytes.
Uint8List smazCompress(List<int> input) {
  final out = BytesBuilder(copy: false);
  final pending = <int>[];
  void flush() {
    if (pending.isEmpty) return;
    if (pending.length == 1) {
      out.add([_oneLiteral, pending[0]]);
    } else {
      out.add([_literalRun, pending.length - 1, ...pending]);
    }
    pending.clear();
  }

  var at = 0;
  while (at < input.length) {
    int? code;
    var used = 0;
    final most = input.length - at < _longestEntry
        ? input.length - at
        : _longestEntry;
    for (var len = most; len > 0 && code == null; len--) {
      final slice = input.sublist(at, at + len);
      // Codebook entries are plain ASCII; anything else is sent as is.
      if (slice.any((b) => b > 127)) continue;
      code = _codes[latin1.decode(slice)];
      if (code != null) used = len;
    }
    if (code == null) {
      pending.add(input[at]);
      at++;
      if (pending.length == 256) flush();
    } else {
      flush();
      out.addByte(code);
      at += used;
    }
  }
  flush();
  return out.takeBytes();
}

/// Expands SMAZ [input] bytes, or null if they aren't valid SMAZ.
Uint8List? smazDecompress(List<int> input) {
  final out = BytesBuilder(copy: false);
  var at = 0;
  while (at < input.length) {
    final code = input[at];
    if (code == _oneLiteral) {
      if (at + 1 >= input.length) return null;
      out.addByte(input[at + 1]);
      at += 2;
    } else if (code == _literalRun) {
      if (at + 1 >= input.length) return null;
      final count = input[at + 1] + 1;
      if (at + 2 + count > input.length) return null;
      out.add(input.sublist(at + 2, at + 2 + count));
      at += 2 + count;
    } else {
      out.add(_entries[code]);
      at++;
    }
  }
  return out.takeBytes();
}

/// [text] as `s:` and compressed base64 when that is shorter on the air,
/// otherwise [text] unchanged.
String smazWrap(String text) {
  if (text.isEmpty || text.startsWith(smazMarker)) return text;
  final plain = utf8.encode(text);
  final wrapped = '$smazMarker${base64Encode(smazCompress(plain))}';
  return utf8.encode(wrapped).length < plain.length ? wrapped : text;
}

/// The plain text of a compressed message, or null when [text] isn't one.
///
/// Only well-formed base64 that expands to readable text counts, so an
/// ordinary message that happens to start with "s:" is left alone.
String? smazUnwrap(String text) {
  final trimmed = text.trimLeft();
  if (!trimmed.startsWith(smazMarker)) return null;
  var body = trimmed
      .substring(smazMarker.length)
      .trim()
      .replaceAll('-', '+')
      .replaceAll('_', '/');
  if (body.length < 2) return null;
  final unpadded = body.replaceAll('=', '');
  body = unpadded.padRight((unpadded.length + 3) ~/ 4 * 4, '=');
  final Uint8List packed;
  try {
    packed = base64Decode(body);
  } on FormatException {
    return null;
  }
  // Reject text that only decodes because of the padding we added.
  if (base64Encode(packed).replaceAll('=', '') != unpadded) return null;
  final expanded = smazDecompress(packed);
  if (expanded == null || expanded.isEmpty) return null;
  final String plain;
  try {
    plain = utf8.decode(expanded);
  } on FormatException {
    return null;
  }
  final control = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  return control.hasMatch(plain) ? null : plain;
}
