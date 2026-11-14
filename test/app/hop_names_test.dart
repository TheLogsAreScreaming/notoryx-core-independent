import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:notoryx_core/app/hop_names.dart';

const _you = LatLng(47.6, -122.3);
final _now = DateTime.utc(2026, 11, 13);

String _key(String first, String rest) => first + rest * 31;

final _north = (name: 'North', publicKey: _key('3d', 'aa'));
final _south = (name: 'South', publicKey: _key('3d', 'bb'));

HopHints _hints(
  HopNames names, {
  LatLng? you = _you,
  Map<String, LatLng>? positions,
  DateTime? now,
}) => HopHints(
  names: names,
  now: now ?? _now,
  you: you,
  positions:
      positions ??
      {
        _north.publicKey: const LatLng(47.7, -122.3),
        _south.publicKey: const LatLng(47.95, -122.3),
      },
  onlineLabel: (n) => '$n (online)',
);

void main() {
  test('one match is just its name', () {
    expect(hopName('3D', [_north]), 'North');
  });

  test('without hints, a shared ID lists every match', () {
    expect(hopName('3d', [_north, _south]), '3D (North or South)');
  });

  test('the nearer one wins and is remembered', () {
    final names = HopNames();
    expect(hopName('3d', [_north, _south], hints: _hints(names)), 'North');
    expect(names.remembered('3D', _now), _north.publicKey);
    // Later, with no position to go on, the same pick is used.
    expect(
      hopName('3d', [_north, _south], hints: _hints(names, you: null)),
      'North',
    );
  });

  test('picks expire', () {
    final names = HopNames(tieDays: 30);
    hopName('3d', [_north, _south], hints: _hints(names));
    expect(
      hopName(
        '3d',
        [_north, _south],
        hints: _hints(
          names,
          you: null,
          now: _now.add(const Duration(days: 31)),
        ),
      ),
      '3D (North or South)',
    );
  });

  test('a near tie goes to the remembered pick, a clear win does not', () {
    final names = HopNames(
      ties: {'3d': (key: _south.publicKey, at: _now.millisecondsSinceEpoch)},
    );
    // North is about 11 m nearer than South: a tie within 5 %.
    final tie = {
      _north.publicKey: const LatLng(47.6999, -122.3),
      _south.publicKey: const LatLng(47.5, -122.3),
    };
    expect(
      hopName('3d', [_north, _south], hints: _hints(names, positions: tie)),
      'South',
    );
    final clear = {
      _north.publicKey: const LatLng(47.61, -122.3),
      _south.publicKey: const LatLng(47.5, -122.3),
    };
    expect(
      hopName('3d', [_north, _south], hints: _hints(names, positions: clear)),
      'North',
    );
  });

  test('all out of range: no guess', () {
    final far = {
      _north.publicKey: const LatLng(40, -75),
      _south.publicKey: const LatLng(39, -105),
    };
    expect(
      hopName('3d', [
        _north,
        _south,
      ], hints: _hints(HopNames(), positions: far)),
      '3D (North or South)',
    );
  });

  test('unknown IDs use a name found online, marked', () {
    final names = HopNames(found: const {'7f': 'Ridge'});
    expect(hopName('7F', [_north], hints: _hints(names)), 'Ridge (online)');
    expect(hopName('80', [_north], hints: _hints(names)), '80');
  });

  group('online reply', () {
    final reply = {
      'resolved': {
        '3D': {
          'name': 'Far Away',
          'ambiguous': true,
          'candidates': [
            {'name': 'Far Away', 'lat': 51.4, 'lon': 6.9},
            {'name': 'Close By', 'lat': 47.62, 'lon': -122.31},
          ],
        },
        'AB': {'name': 'Only One', 'ambiguous': false},
      },
    };

    test('takes the nearest candidate in range of you', () {
      expect(onlineHopName(reply, '3d', you: _you), 'Close By');
      expect(onlineHopName(reply, 'ab', you: _you), isNull);
    });

    test('without a position, only a sure answer', () {
      expect(onlineHopName(reply, '3d'), isNull);
      expect(onlineHopName(reply, 'ab'), 'Only One');
      expect(onlineHopName(reply, 'cd'), isNull);
      expect(onlineHopName('junk', 'ab'), isNull);
    });
  });

  test('settings survive a round trip and are clamped', () {
    final names = HopNames(
      online: true,
      server: 'https://example.org',
      tieDays: 12,
      tieMargin: 7,
      ties: {'3d': (key: 'abc', at: _now.millisecondsSinceEpoch)},
    );
    final back = HopNames.fromJson(names.toJson(_now));
    expect(back.online, isTrue);
    expect(back.server, 'https://example.org');
    expect(back.tieDays, 12);
    expect(back.tieMargin, 7);
    expect(back.remembered('3d', _now), 'abc');
    final clamped = HopNames.fromJson({'tieDays': 999, 'tieMargin': -4});
    expect(clamped.tieDays, maxTieDays);
    expect(clamped.tieMargin, 0);
    expect(HopNames.fromJson('nope').online, isFalse);
  });
}
