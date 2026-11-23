import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/coverage_share.dart';

/// A fixed test seed (bytes 3, 10, 17, ... stepping by 7), not a real key.
final _seed = base64.decode('AwoRGB8mLTQ7QklQV15lbHN6gYiPlp2kq7K5wMfO1dw=');

bool _verifies(CoverageKey key, List<int> message, String sig) => ed.verify(
  ed.PublicKey(key.publicKey),
  Uint8List.fromList(message),
  base64.decode(sig),
);

/// Placeholder resolution-8 H3 cells.
const _cells = [
  '8844d98061fffff',
  '8844d98139fffff',
  '8844d98063fffff',
  '8844d98065fffff',
  '8844d98067fffff',
];

void main() {
  group('canonical JSON', () {
    test('sorts keys, no spaces, whole numbers without a decimal point', () {
      expect(
        canonicalJson({
          'b': 7.0,
          'a': [
            1,
            -3.75,
            {'z': null, 'y': true},
          ],
          'c': 'x"y\n',
          'd': -0.0,
          'e': 5.25,
        }),
        '{"a":[1,-3.75,{"y":true,"z":null}],"b":7,"c":"x\\"y\\n","d":0,'
        '"e":5.25}',
      );
    });

    test('keeps non-ASCII text as is', () {
      expect(canonicalJson({'n': 'Gipfel ä 山'}), '{"n":"Gipfel ä 山"}');
    });

    test('a cell signs its repeaters sorted by id, without sig', () {
      final bytes = cellSigningBytes({
        'cell': '8844d98139fffff',
        'time': '2026-11-22T09:30:00.000Z',
        'count': 2,
        'best_snr': -3.75,
        'best_rssi': -110,
        'repeaters': [
          {'id': 'A1', 'snr': -3.75},
          {'id': '0F', 'snr': -12.5},
        ],
        'sig': 'ignored',
      });
      expect(
        utf8.decode(bytes),
        'notoryx-coverage-signed/1\n'
        '{"best_rssi":-110,"best_snr":-3.75,"cell":"8844d98139fffff",'
        '"count":2,"repeaters":[{"id":"0F","snr":-12.5},'
        '{"id":"A1","snr":-3.75}],"time":"2026-11-22T09:30:00.000Z"}',
      );
    });
  });

  group('signature vectors', () {
    // The same seed and cells the coverage server checks itself against,
    // so these prove the bytes match what it verifies.
    final key = CoverageKey.fromSeed(Uint8List.fromList(_seed));

    test('public key from the seed', () {
      expect(key.publicBase64, 'dVxMuSVsp83ErP3Gz+7ahJAX5bn5UU6ZGRvWfgsNQnY=');
    });

    test('cell signatures', () {
      expect(
        key.sign(
          cellSigningBytes({
            'cell': '8844d98061fffff',
            'time': '2026-11-22T09:00:00.000Z',
            'count': 2,
            'best_snr': 7.0,
            'best_rssi': -90,
            'repeaters': [
              {'id': 'A1', 'snr': 7.0},
              {'id': 'B2C3', 'snr': 5.25},
            ],
          }),
        ),
        'ru25BJExqAeYdEd/YkdpTx2yO408m2luWaUWOvka4Pkn0zQYyKffJZqotIV95L2R0lWbjv7oYukRFHRaZM2eDA==',
      );
      expect(
        key.sign(
          cellSigningBytes({
            'cell': '8844d98139fffff',
            'time': '2026-11-22T09:30:00.000Z',
            'count': 2,
            'best_snr': -3.75,
            'best_rssi': -110,
            'repeaters': [
              {'id': 'A1', 'snr': -3.75},
              {'id': '0F', 'snr': -12.5},
            ],
          }),
        ),
        'Bis4Vpk3dvOT4KU5trVL1X+jSYBdWaE+qi5/aEgDw+I8pD49FBJSekPV32UDoO79UX9DntnwvMDDrVmkTzvGBw==',
      );
    });

    test('a generated key is a fresh 32-byte seed', () {
      final a = CoverageKey.generate();
      final b = CoverageKey.generate();
      expect(a.seed, hasLength(32));
      expect(a.publicBase64, isNot(b.publicBase64));
      expect(a.publicKey, hasLength(32));
    });
  });

  group('time', () {
    test('15-minute UTC buckets', () {
      expect(
        isoUtc(bucketStart(DateTime.utc(2026, 11, 22, 9, 29, 59, 999))),
        '2026-11-22T09:15:00.000Z',
      );
      expect(
        isoUtc(bucketStart(DateTime.utc(2026, 11, 22, 9, 30))),
        '2026-11-22T09:30:00.000Z',
      );
      expect(
        isoUtc(dayStart(DateTime.utc(2026, 11, 22, 23, 59))),
        '2026-11-22T00:00:00.000Z',
      );
    });
  });

  group('log', () {
    final t0 = DateTime.utc(2026, 11, 22, 9, 1);

    CoverageLog drive({bool hideEnds = true, bool close = true}) {
      final log = CoverageLog();
      for (var i = 0; i < _cells.length; i++) {
        log.hear(
          cell: _cells[i],
          at: t0.add(Duration(minutes: i)),
          session: 1,
          hideEnds: hideEnds,
          snr: i.toDouble(),
          rssi: -100 + i,
          repeater: 'A$i',
        );
      }
      if (close) log.closeSession(1);
      return log;
    }

    test('records count, best signal and repeaters per bucket', () {
      final log = CoverageLog()
        ..hear(
          cell: _cells[0],
          at: t0,
          session: 1,
          hideEnds: false,
          snr: -4,
          rssi: -110,
          repeater: 'AB',
        )
        ..hear(
          cell: _cells[0],
          at: t0.add(const Duration(minutes: 3)),
          session: 1,
          hideEnds: false,
          snr: 6.5,
          rssi: -95,
          repeater: 'ab',
        )
        ..hear(
          cell: _cells[0],
          at: t0.add(const Duration(minutes: 4)),
          session: 1,
          hideEnds: false,
          snr: 1,
          rssi: -99,
          repeater: 'cd',
          packet: false,
        );
      expect(log.buckets, hasLength(1));
      final b = log.buckets.single;
      expect(b.count, 2);
      expect(b.bestSnr, 6.5);
      expect(b.bestRssi, -95);
      expect(b.repeaters, {'ab': 6.5, 'cd': 1.0});
      expect(isoUtc(b.start), '2026-11-22T09:00:00.000Z');
    });

    test('the first 2 and last 2 hexagons of a drive stay private', () {
      final open = drive(close: false);
      final now = t0.add(const Duration(days: 1));
      // While driving: the first two are private, the last two held.
      expect(open.due(now, CoveragePrivacy.live).map((b) => b.cell), [
        _cells[2],
      ]);
      open.closeSession(1);
      expect(open.due(now, CoveragePrivacy.live).map((b) => b.cell), [
        _cells[2],
      ]);
      expect(open.waiting, 1);
      // Going back to the start later in the drive stays private too.
      final back = drive(close: false)
        ..hear(
          cell: _cells[0],
          at: t0.add(const Duration(minutes: 20)),
          session: 1,
          hideEnds: true,
          snr: 0,
          rssi: -100,
        )
        ..closeSession(1);
      // The last two are now _cells[4] and the start, so _cells[3] goes.
      expect(back.due(now, CoveragePrivacy.live).map((b) => b.cell).toSet(), {
        _cells[2],
        _cells[3],
      });
    });

    test('with hiding off every hexagon goes', () {
      final log = drive(hideEnds: false);
      expect(
        log.due(t0.add(const Duration(days: 1)), CoveragePrivacy.live),
        hasLength(_cells.length),
      );
    });

    test('a drive left open by the app closing is ended as it was', () {
      final log = CoverageLog.fromJson(
        jsonDecode(jsonEncode(drive(close: false).toJson()))
            as Map<String, Object?>,
      )..closeOpenSessions();
      expect(log.sessions[1]!.open, isFalse);
      expect(
        log.due(t0.add(const Duration(days: 1)), CoveragePrivacy.live),
        hasLength(1),
      );
    });

    test('release times per privacy', () {
      final log = drive(hideEnds: false);
      final b = log.buckets.first; // 09:00 to 09:15
      expect(CoverageLog.releaseAt(b, CoveragePrivacy.live), b.end);
      expect(
        CoverageLog.releaseAt(b, CoveragePrivacy.delayed),
        DateTime.utc(2026, 11, 22, 12, 15),
      );
      expect(
        CoverageLog.releaseAt(b, CoveragePrivacy.anonymous),
        DateTime.utc(2026, 11, 24),
      );
      expect(
        log.due(DateTime.utc(2026, 11, 22, 9, 14), CoveragePrivacy.live),
        isEmpty,
      );
      expect(
        log.due(DateTime.utc(2026, 11, 22, 9, 15), CoveragePrivacy.live),
        hasLength(_cells.length),
      );
      expect(
        log.due(DateTime.utc(2026, 11, 22, 12, 14), CoveragePrivacy.delayed),
        isEmpty,
      );
      expect(
        log.due(DateTime.utc(2026, 11, 23, 23), CoveragePrivacy.anonymous),
        isEmpty,
      );
      expect(
        log.due(DateTime.utc(2026, 11, 24), CoveragePrivacy.anonymous),
        hasLength(_cells.length),
      );
    });

    test('trims readings older than 7 days and finished drives', () {
      final log = drive(hideEnds: false)
        ..hear(
          cell: _cells[0],
          at: t0.add(const Duration(days: 6)),
          session: 2,
          hideEnds: false,
          snr: 0,
          rssi: -100,
        )
        ..closeSession(2);
      log.trim(t0.add(const Duration(days: 7, minutes: 1)));
      expect(log.buckets.map((b) => b.session), [2]);
      expect(log.sessions.keys, [2]);
    });

    test('survives a round trip through JSON', () {
      final log = drive(close: false);
      final back = CoverageLog.fromJson(
        jsonDecode(jsonEncode(log.toJson())) as Map<String, Object?>,
      );
      expect(jsonEncode(back.toJson()), jsonEncode(log.toJson()));
    });
  });

  group('uploads', () {
    final key = CoverageKey.fromSeed(Uint8List.fromList(_seed));
    final created = DateTime.utc(2026, 11, 23, 12);

    CoverageLog many(int n) {
      final log = CoverageLog();
      for (var i = 0; i < n; i++) {
        // n distinct cells, made up from a counter.
        log.hear(
          cell: '88${i.toRadixString(16).padLeft(5, '0')}fffffff',
          at: DateTime.utc(2026, 11, 23, 9, i % 15),
          session: 1,
          hideEnds: false,
          snr: 3.456,
          rssi: -101,
          repeater: 'a1',
        );
      }
      return log..closeSession(1);
    }

    test('signed, at most 50 hexagons per request, all verifiable', () async {
      final log = many(120);
      final requests =
          <({Uri url, String body, Map<String, String> headers})>[];
      final sent = await uploadDue(
        log: log,
        privacy: CoveragePrivacy.live,
        key: key,
        now: created,
        mapper: 'Placeholder Mapper',
        repeaters: [
          {
            'key': 'ab' * 32,
            'name': 'Test Repeater',
            'lat': 0.5,
            'lon': -30.25,
            'advert': '2026-11-23T08:00:00.000Z',
          },
        ],
        post: (url, body, headers) async {
          requests.add((url: url, body: body, headers: headers));
          return (status: 200, body: '{"stored":50}');
        },
      );
      expect(sent, 120);
      expect(requests.map((r) => r.url.toString()).toSet(), {
        'https://coverage.meshmayhem.org/v1/reports',
      });
      expect(requests, hasLength(3));
      var total = 0;
      for (final (i, r) in requests.indexed) {
        final j = jsonDecode(r.body) as Map<String, Object?>;
        expect(j['format'], 'notoryx-coverage-hex/1');
        expect(j['resolution'], 8);
        expect(j['key'], key.publicBase64);
        expect(j['mapper'], 'Placeholder Mapper');
        expect(j.containsKey('repeaters'), i == 0);
        expect(r.headers['X-Notoryx-Key'], key.publicBase64);
        expect(
          _verifies(
            key,
            utf8.encode(r.body),
            r.headers['X-Notoryx-Signature']!,
          ),
          isTrue,
        );
        final cells = (j['cells']! as List).cast<Map<String, Object?>>();
        expect(cells.length, lessThanOrEqualTo(50));
        total += cells.length;
        for (final c in cells) {
          expect(c['best_snr'], 3.46);
          expect(c['repeaters'], [
            {'id': 'a1', 'snr': 3.46},
          ]);
          expect(
            _verifies(key, cellSigningBytes(c), c['sig']! as String),
            isTrue,
          );
        }
      }
      expect(total, 120);
      expect(log.buckets.every((b) => b.sent), isTrue);
      expect(log.due(created, CoveragePrivacy.live), isEmpty);
    });

    test('anonymous: no key, no signatures, day times, merged', () async {
      final log = CoverageLog();
      for (final (i, minute) in [0, 20, 50].indexed) {
        log.hear(
          cell: _cells[0],
          at: DateTime.utc(2026, 11, 20, 9, minute),
          session: 1,
          hideEnds: false,
          snr: i.toDouble(),
          rssi: -110 + i,
          repeater: 'a$i',
        );
      }
      log.closeSession(1);
      final bodies = <String>[];
      Map<String, String>? headersSeen;
      await uploadDue(
        log: log,
        privacy: CoveragePrivacy.anonymous,
        key: key,
        now: created,
        mapper: 'Placeholder Mapper',
        repeaters: [
          {'key': 'ab' * 32},
        ],
        post: (url, body, headers) async {
          bodies.add(body);
          headersSeen = headers;
          return (status: 200, body: '{}');
        },
      );
      expect(headersSeen!.keys, ['Content-Type']);
      final j = jsonDecode(bodies.single) as Map<String, Object?>;
      expect(j.keys.toSet(), {'format', 'resolution', 'created', 'cells'});
      final cell = (j['cells']! as List).single as Map<String, Object?>;
      expect(cell, {
        'cell': _cells[0],
        'time': '2026-11-20T00:00:00.000Z',
        'count': 3,
        'best_snr': 2.0,
        'best_rssi': -108,
        'repeaters': [
          {'id': 'a0', 'snr': 0.0},
          {'id': 'a1', 'snr': 1.0},
          {'id': 'a2', 'snr': 2.0},
        ],
      });
    });

    test('a refused upload marks nothing sent and says why', () async {
      final log = many(3);
      await expectLater(
        uploadDue(
          log: log,
          privacy: CoveragePrivacy.live,
          key: key,
          now: created,
          post: (url, body, headers) async => (
            status: 401,
            body: '{"error":"report signature does not verify"}',
          ),
        ),
        throwsA(
          isA<CoverageServerException>()
              .having((e) => e.status, 'status', 401)
              .having((e) => e.message, 'message', contains('signature')),
        ),
      );
      expect(log.buckets.any((b) => b.sent), isFalse);
    });

    test('repeater list: placed ones only, newest first, at most 500', () {
      final list = repeaterDirectory([
        for (var i = 0; i < 600; i++)
          (
            publicKey: i.toRadixString(16).padLeft(64, '0'),
            name: 'R$i',
            latitude: i == 0 ? null : 1.0 + i / 1000,
            longitude: i == 1 ? 0.0 : 2.0,
            advert: DateTime.utc(2026, 11, 1).add(Duration(minutes: i)),
          ),
        (
          publicKey: 'cd' * 32,
          name: 'No place',
          latitude: 0.0,
          longitude: 0.0,
          advert: DateTime.utc(2026, 12),
        ),
      ]);
      expect(list, hasLength(500));
      expect(list.first['name'], 'R599');
      expect(list.first['advert'], '2026-11-01T09:59:00.000Z');
      expect(list.any((r) => r['name'] == 'No place'), isFalse);
      expect(list.any((r) => r['name'] == 'R0'), isFalse);
    });
  });

  group('erase', () {
    final key = CoverageKey.fromSeed(Uint8List.fromList(_seed));
    final now = DateTime.utc(2026, 11, 23, 12, 0, 5);

    test('signed request, returns how many were erased', () async {
      late String sentBody;
      late Map<String, String> sentHeaders;
      late Uri sentUrl;
      final n = await eraseUploads(
        key: key,
        now: now,
        post: (url, body, headers) async {
          sentUrl = url;
          sentBody = body;
          sentHeaders = headers;
          return (status: 200, body: '{"erased":7}');
        },
      );
      expect(n, 7);
      expect(sentUrl.toString(), 'https://coverage.meshmayhem.org/v1/erase');
      expect(jsonDecode(sentBody), {
        'format': 'notoryx-coverage-erase/1',
        'key': key.publicBase64,
        'time': '2026-11-23T12:00:05.000Z',
      });
      expect(
        _verifies(
          key,
          utf8.encode(sentBody),
          sentHeaders['X-Notoryx-Signature']!,
        ),
        isTrue,
      );
    });

    test('a refusal throws', () {
      expect(
        eraseUploads(
          key: key,
          now: now,
          post: (url, body, headers) async => (
            status: 400,
            body: '{"error":"request time is too far from now"}',
          ),
        ),
        throwsA(isA<CoverageServerException>()),
      );
    });
  });

  test('last hop hash of a flood path', () {
    expect(lastHopHash([0x12, 0xAB], 1), 'ab');
    expect(lastHopHash([0x12, 0x34, 0x0A, 0xBC], 2), '0abc');
    expect(lastHopHash([], 1), isNull);
    expect(lastHopHash([0x01], 2), isNull);
  });
}
