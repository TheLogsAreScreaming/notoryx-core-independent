import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/repeater_tools.dart';

void main() {
  test('reads a neighbors reply', () {
    final list = parseNeighbors('AABBCCDD:90:-22\n11223344:5:8\n')!;
    expect(list, hasLength(2));
    expect(list.first.prefix, 'aabbccdd');
    expect(list.first.secondsAgo, 90);
    expect(list.first.snr, -5.5);
  });

  test('none, and replies to other commands', () {
    expect(parseNeighbors('-none-'), isEmpty);
    expect(parseNeighbors('v1.18.0'), isNull);
    expect(parseNeighbors('OK'), isNull);
  });

  test('permission command', () {
    expect(
      setPermissionCommand('abcd', ServerPermission.admin),
      'setperm abcd 3',
    );
  });
}
