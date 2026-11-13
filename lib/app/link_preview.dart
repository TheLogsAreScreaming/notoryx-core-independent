/// Link previews: the title and summary a web page gives about itself.
/// Loading one contacts that website, which then sees this device's
/// internet address, so previews load only when asked unless the person
/// turns automatic previews on.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';

const linkPreviewsAutoSetting = 'link_previews_auto';

/// Most of a page read, in bytes. The tags needed are near the top.
const _maxBytes = 256 * 1024;

/// The first web link in [text], without trailing punctuation.
String? firstWebLink(String text) {
  final m = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  return m[0]!.replaceFirst(RegExp(r'[.,;:!?)\]]+$'), '');
}

typedef LinkPreview = ({String title, String? description, String site});

String _decode(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#x27;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Reads the title and description from [html]. Null if it has no title.
LinkPreview? parseLinkPreview(String html, Uri url) {
  String? meta(String name) {
    for (final tag in RegExp(
      r'<meta\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final t = tag[0]!;
      final key = RegExp(
        '(?:property|name)\\s*=\\s*["\']$name["\']',
        caseSensitive: false,
      );
      if (!key.hasMatch(t)) continue;
      final content = RegExp(
        r'''content\s*=\s*["']([^"']*)["']''',
        caseSensitive: false,
      ).firstMatch(t);
      if (content != null && content[1]!.trim().isNotEmpty) {
        return _decode(content[1]!);
      }
    }
    return null;
  }

  final title =
      meta('og:title') ??
      meta('twitter:title') ??
      switch (RegExp(
        r'<title[^>]*>([^<]*)</title>',
        caseSensitive: false,
      ).firstMatch(html)) {
        final m? when m[1]!.trim().isNotEmpty => _decode(m[1]!),
        _ => null,
      };
  if (title == null) return null;
  final description = meta('og:description') ?? meta('description');
  return (
    title: title.length > 120 ? '${title.substring(0, 117)}…' : title,
    description: description == null
        ? null
        : description.length > 200
        ? '${description.substring(0, 197)}…'
        : description,
    site: meta('og:site_name') ?? url.host,
  );
}

/// Fetches a page and reads its preview. Null on any failure.
Future<LinkPreview?> fetchLinkPreview(Uri url) async {
  if (url.scheme != 'https' && url.scheme != 'http') return null;
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..userAgent = 'NOTORYX-Independent link preview';
  try {
    final request = await client
        .getUrl(url)
        .timeout(const Duration(seconds: 5));
    request.maxRedirects = 3;
    final response = await request.close().timeout(const Duration(seconds: 8));
    final type = response.headers.contentType;
    if (response.statusCode != 200 || type == null || type.subType != 'html') {
      return null;
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 8))) {
      bytes.addAll(chunk);
      if (bytes.length >= _maxBytes) break;
    }
    return parseLinkPreview(
      utf8.decode(bytes, allowMalformed: true),
      response.redirects.isEmpty ? url : response.redirects.last.location,
    );
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Loads previews. Tests replace it.
final linkPreviewFetcherProvider = Provider<Future<LinkPreview?> Function(Uri)>(
  (ref) => fetchLinkPreview,
);

final linkPreviewProvider = FutureProvider.family<LinkPreview?, String>(
  (ref, url) => ref.read(linkPreviewFetcherProvider)(Uri.parse(url)),
);

class LinkPreviewsAuto extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async =>
      await ref.read(storeProvider).setting(linkPreviewsAutoSetting) == '1';

  Future<void> set(bool on) async {
    await ref
        .read(storeProvider)
        .saveSetting(linkPreviewsAutoSetting, on ? '1' : '0');
    state = AsyncData(on);
  }
}

final linkPreviewsAutoProvider = AsyncNotifierProvider<LinkPreviewsAuto, bool>(
  LinkPreviewsAuto.new,
);
