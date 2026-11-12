import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/network_scan.dart';
import 'package:notoryx_core/app/wardrive.dart';
import 'package:notoryx_core/presets/area_preset.dart';

AreaPreset preset(String name, double f, {int sf = 7}) => AreaPreset(
  id: name,
  name: name,
  latitude: 0,
  longitude: 0,
  radiusKm: 0,
  frequencyMhz: f,
  bandwidthKhz: 62.5,
  spreadingFactor: sf,
  codingRate: 5,
  updated: '',
);

void main() {
  const current = (
    frequencyMhz: 910.525,
    bandwidthKhz: 62.5,
    spreadingFactor: 7,
    codingRate: 5,
  );

  test('candidates: own band only, each setting once, current first', () {
    final c = scanCandidates([
      preset('USA', 910.525),
      preset('Canada', 910.525),
      preset('SoCal', 927.875),
      preset('EU', 869.618),
      preset('Other SF', 910.525, sf: 8),
    ], current);
    expect(
      [for (final p in c) p.name],
      ['Your current settings', 'SoCal', 'Other SF'],
    );
  });

  test('settings survive saving', () {
    expect(decodeSettings(encodeSettings(current)), current);
    expect(decodeSettings('junk'), isNull);
  });

  test('the radio always goes back, even when a ping fails', () async {
    final applied = <String?>[];
    await expectLater(
      runScan(
        candidates: [preset('A', 910), preset('B', 911)],
        apply: (p) async => applied.add(p?.name),
        ping: () async {
          if (applied.last == 'B') throw StateError('radio gone');
          return const <WardriveHit>[];
        },
        settle: Duration.zero,
      ),
      throwsStateError,
    );
    expect(applied, ['A', 'B', null]);
  });

  test('cancelling stops early and still goes back', () async {
    final applied = <String?>[];
    var stop = false;
    final results = await runScan(
      candidates: [preset('A', 910), preset('B', 911), preset('C', 912)],
      apply: (p) async => applied.add(p?.name),
      ping: () async {
        stop = true;
        return const <WardriveHit>[];
      },
      cancelled: () => stop,
      settle: Duration.zero,
    );
    expect(results, hasLength(1));
    expect(applied, ['A', null]);
  });
}
