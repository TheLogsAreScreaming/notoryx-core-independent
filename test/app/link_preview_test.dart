import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/link_preview.dart';

void main() {
  test('finds the first web link, without trailing punctuation', () {
    expect(
      firstWebLink('See https://example.org/trail?id=4. Thanks'),
      'https://example.org/trail?id=4',
    );
    expect(firstWebLink('(http://a.b/c)'), 'http://a.b/c');
    expect(firstWebLink('no link here, meshcore://x'), isNull);
  });

  test('prefers Open Graph tags, decoding entities', () {
    const html = '''
<html><head>
<title>Fallback</title>
<meta property="og:title" content="Ridge &amp; Valley Trail">
<meta name="description" content="A 12 km loop with &quot;great&quot; views.">
<meta property="og:site_name" content="Trails Today">
</head></html>''';
    final p = parseLinkPreview(html, Uri.parse('https://t.example/x'))!;
    expect(p.title, 'Ridge & Valley Trail');
    expect(p.description, 'A 12 km loop with "great" views.');
    expect(p.site, 'Trails Today');
  });

  test('falls back to <title> and the host; no title means no preview', () {
    final p = parseLinkPreview(
      '<title>  Plain page </title>',
      Uri.parse('https://plain.example/'),
    )!;
    expect(p.title, 'Plain page');
    expect(p.description, isNull);
    expect(p.site, 'plain.example');
    expect(
      parseLinkPreview('<p>nothing</p>', Uri.parse('https://x.y')),
      isNull,
    );
  });

  test('long text is cut short', () {
    final p = parseLinkPreview(
      '<title>${'x' * 300}</title>',
      Uri.parse('https://x.y'),
    )!;
    expect(p.title.length, 118);
    expect(p.title, endsWith('…'));
  });

  test('only web addresses are fetched', () async {
    expect(await fetchLinkPreview(Uri.parse('file:///etc/passwd')), isNull);
  });
}
