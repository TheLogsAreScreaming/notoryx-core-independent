/// An optional short tag added to your channel posts, like "📍 ct", so
/// people on a wide channel can see roughly where a post came from.
library;

import 'dart:convert';

import '../data/data.dart';

const regionTagSetting = 'region_tag';

/// The longest tag allowed, in characters.
const regionTagMaxLength = 8;

/// [tag] tidied up, or null when there's nothing usable.
String? cleanRegionTag(String? tag) {
  final t = tag?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  if (t.isEmpty) return null;
  return t.length > regionTagMaxLength ? t.substring(0, regionTagMaxLength) : t;
}

/// [text] with [tag] on the end. If the tag wouldn't fit in one message the
/// text goes out without it, so a tag can never cost anyone their message.
String withRegionTag(String text, String? tag) {
  final clean = cleanRegionTag(tag);
  if (clean == null) return text;
  final tagged = '$text 📍 $clean';
  return utf8.encode(tagged).length <= maxDirectTextBytes ? tagged : text;
}
