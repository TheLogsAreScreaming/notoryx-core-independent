import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/connection.dart';
import 'package:notoryx_core/app/coverage_sharing.dart';
import 'package:notoryx_core/app/safety.dart';
import 'package:notoryx_core/data/data.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late MeshDatabase db;
  late List<({Uri url, String body, Map<String, String> headers})> posts;
  final now = DateTime.utc(2026, 11, 23, 12);

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        safetyClockProvider.overrideWithValue(() => now),
        coverageOnWifiProvider.overrideWithValue(() async => true),
        coveragePostProvider.overrideWithValue((url, body, headers) async {
          posts.add((url: url, body: body, headers: headers));
          return (status: 200, body: '{"erased":3}');
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    db = MeshDatabase.inMemory();
    posts = [];
  });
  tearDown(() => db.close());

  Future<CoverageShareState> loaded(ProviderContainer c) async {
    c.listen(coverageSharingProvider, (_, _) {});
    for (var i = 0; i < 50 && !c.read(coverageSharingProvider).loaded; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return c.read(coverageSharingProvider);
  }

  test('off by default, with delayed, Wi-Fi only and hidden ends', () async {
    final s = (await loaded(container())).settings;
    expect(s.enabled, isFalse);
    expect(s.privacy, CoveragePrivacy.delayed);
    expect(s.wifiOnly, isTrue);
    expect(s.hideEnds, isTrue);
    expect(s.mapper, '');
  });

  test('agreeing turns it on, makes a coverage key and is saved', () async {
    final c = container();
    await loaded(c);
    final sharing = c.read(coverageSharingProvider.notifier);
    expect(await sharing.publicKey(), isNull);
    await sharing.agreeAndStart();
    await sharing.setPrivacy(CoveragePrivacy.live);
    await sharing.setMapper('  Placeholder <Mapper>  ');
    final key = await sharing.publicKey();
    expect(base64.decode(key!), hasLength(32));

    final again = container();
    final s = (await loaded(again)).settings;
    expect(s.enabled, isTrue);
    expect(s.privacy, CoveragePrivacy.live);
    expect(s.mapper, 'Placeholder Mapper');
    expect(await again.read(coverageSharingProvider.notifier).publicKey(), key);
  });

  test('erase sends a signed request for this phone’s key', () async {
    final c = container();
    await loaded(c);
    final sharing = c.read(coverageSharingProvider.notifier);
    // Never shared: nothing to erase, nothing sent.
    expect(await sharing.eraseMyUploads(), 0);
    expect(posts, isEmpty);

    await sharing.agreeAndStart();
    expect(await sharing.eraseMyUploads(), 3);
    final erase = posts.singleWhere((p) => p.url.path == '/v1/erase');
    final body = jsonDecode(erase.body) as Map<String, Object?>;
    expect(body['format'], 'notoryx-coverage-erase/1');
    expect(body['key'], await sharing.publicKey());
    expect(body['time'], '2026-11-23T12:00:00.000Z');
    expect(
      ed.verify(
        ed.PublicKey(base64.decode(body['key']! as String)),
        Uint8List.fromList(utf8.encode(erase.body)),
        base64.decode(erase.headers['X-Notoryx-Signature']!),
      ),
      isTrue,
    );
  });

  test('stopping turns it off', () async {
    final c = container();
    await loaded(c);
    final sharing = c.read(coverageSharingProvider.notifier);
    await sharing.agreeAndStart();
    await sharing.stop();
    expect(c.read(coverageSharingProvider).settings.enabled, isFalse);
    expect(c.read(coverageSharingProvider).waiting, 0);
    final again = container();
    expect((await loaded(again)).settings.enabled, isFalse);
  });
}
