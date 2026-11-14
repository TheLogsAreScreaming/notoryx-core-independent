import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:notoryx_core/screens/identity_key_screen.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';

final _key = List.generate(64, (i) => i);
final _hex = [for (final b in _key) b.toRadixString(16).padLeft(2, '0')].join();

void main() {
  late FakeRadioLink link;
  late RadioSession session;

  setUp(() {
    link = FakeRadioLink();
    session = RadioSession(link);
  });

  tearDown(() => session.close());

  test('export: one-byte command, 64-byte key back', () async {
    link.onSend = (frame) => [
      if (frame[0] == CommandCode.exportPrivateKey)
        [ResponseCode.privateKey, ..._key],
    ];
    final reply = await session.request<PrivateKeyReply>(
      const ExportPrivateKey(),
    );
    expect(reply.key, _key);
    expect(link.sent.single, [23]);
  });

  test('firmware with key export compiled out says disabled', () async {
    link.onSend = (_) => [
      [ResponseCode.disabled],
    ];
    await expectLater(
      session.request<PrivateKeyReply>(const ExportPrivateKey()),
      throwsA(isA<RadioFeatureDisabled>()),
    );
  });

  test('import sends the key and expects OK', () async {
    link.onSend = (_) => [okFrame()];
    await session.run(ImportPrivateKey(_key));
    expect(link.sent.single, [24, ..._key]);
    expect(() => ImportPrivateKey(List.filled(32, 0)), throwsArgumentError);
  });

  test('a refused key comes back as rejected', () async {
    link.onSend = (_) => [
      [ResponseCode.error, 6],
    ];
    await expectLater(
      session.run(ImportPrivateKey(_key)),
      throwsA(
        isA<RadioRejected>().having(
          (e) => e.code,
          'code',
          RadioErrorCode.illegalArgument,
        ),
      ),
    );
  });

  test('pasted keys: spaces, line breaks and 0x are fine', () {
    expect(parsePrivateKeyHex(_hex), _key);
    expect(parsePrivateKeyHex('0x${_hex.toUpperCase()}'), _key);
    expect(
      parsePrivateKeyHex('${_hex.substring(0, 64)}\n ${_hex.substring(64)}'),
      _key,
    );
    expect(parsePrivateKeyHex(_hex.substring(2)), isNull);
    expect(parsePrivateKeyHex('zz${_hex.substring(2)}'), isNull);
  });
}
