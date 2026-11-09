import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/repeater_regions.dart';

void main() {
  test('IDs group by first key byte, and shared ones show', () {
    final used = repeaterIdUsage([
      (name: 'A', publicKey: 'a7${'0' * 62}'),
      (name: 'B', publicKey: 'A7${'1' * 62}'),
      (name: 'C', publicKey: '10${'2' * 62}'),
    ]);
    expect(used[0xA7], hasLength(2));
    expect(used[0x10]!.single.name, 'C');
    final free = freeRepeaterIds(used);
    expect(free, isNot(contains(0xA7)));
    expect(free, isNot(contains(0)));
    expect(free, isNot(contains(0xFF)));
    expect(free, hasLength(252));
    expect(idLabel(0xA), '0A');
  });

  test('commands add under the parent, set home, then save', () {
    expect(
      regionSetupCommands(
        regions: ['CT', '#ny', 'ct'],
        parent: 'usa',
        home: 'ct',
      ),
      [
        'region put usa',
        'region put ct usa',
        'region put ny usa',
        'region home ct',
        'region save',
      ],
    );
  });

  test('a flat list, no home, and nothing picked', () {
    expect(regionSetupCommands(regions: ['hudson']), [
      'region put hudson',
      'region save',
    ]);
    expect(regionSetupCommands(regions: const [], parent: 'usa'), isEmpty);
    expect(
      regionSetupCommands(regions: ['ct'], home: 'ny'),
      isNot(contains('region home ny')),
    );
  });

  test('no region names collide between the US and Canada lists', () {
    expect(usRegions.toSet().intersection(canadaRegions.toSet()), isEmpty);
    expect(usRegions, hasLength(51));
  });

  test('every command fits a console message', () {
    for (final c in regionSetupCommands(
      regions: usRegions,
      parent: 'usa',
      home: 'ct',
    )) {
      expect(c.length, lessThan(160));
    }
  });
}
