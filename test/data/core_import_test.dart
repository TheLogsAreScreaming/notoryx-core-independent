import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/data/core_import.dart';
import 'package:notoryx_core/data/data.dart';
import 'package:notoryx_core/radio/radio.dart';
import 'package:pointycastle/export.dart';

import '../support/fake_radio_link.dart';
import '../support/radio_frames.dart';
import '../support/scripted_radio.dart';

/// A backup laid out the way NOTORYX Core writes one, with few key
/// stretching rounds so the test is quick.
Uint8List coreBackup(Map<String, Object> settings, String password) {
  final random = Random(7);
  List<int> bytes(int n) => [for (var i = 0; i < n; i++) random.nextInt(256)];
  final salt = Uint8List.fromList(bytes(32));
  final nonce = Uint8List.fromList(bytes(12));
  const iterations = 1000;
  final key =
      (PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
            ..init(Pbkdf2Parameters(salt, iterations, 32)))
          .process(Uint8List.fromList(utf8.encode(password)));
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(
        KeyParameter(key),
        128,
        nonce,
        Uint8List.fromList(utf8.encode('bastion-meshcore-backup-v1')),
      ),
    );
  final sealed = cipher.process(
    Uint8List.fromList(utf8.encode(jsonEncode(settings))),
  );
  final body = sealed.sublist(0, sealed.length - 16);
  final tag = sealed.sublist(sealed.length - 16);
  return Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': 'bastion-meshcore-backup',
        'version': 1,
        'iterations': iterations,
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
        'ciphertext': base64Encode(body),
        'tag': base64Encode(tag),
      }),
    ),
  );
}

final radioHex = toHex(testKey);
final aliceHex = '01' * 32;
const otherRadio =
    'ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00';

Map<String, Object> history() => {
  'some_setting': true,
  'notoryx_history_v1': jsonEncode({
    'direct': {
      radioHex.toUpperCase(): {
        aliceHex: [
          jsonEncode({
            'text': 'see you at the hut',
            'timestamp': 1_700_000_000_000,
            'isOutgoing': true,
            'status': 2,
            'messageId': 'm1',
          }),
          jsonEncode({
            'text': smazWrap('the weather is clear on the ridge tonight'),
            'timestamp': 1_700_000_060_000,
            'isOutgoing': false,
            'status': 0,
            'messageId': 'm2',
            'pathLength': 2,
          }),
        ],
      },
      otherRadio: {
        aliceHex: [
          jsonEncode({
            'text': 'from another radio',
            'timestamp': 1_700_000_000_000,
            'isOutgoing': false,
          }),
        ],
      },
    },
    'channel': {
      radioHex: {
        '1': [
          jsonEncode({
            'text': 'chains needed past the gate',
            'senderName': 'Maya',
            'timestamp': 1_700_000_120_000,
            'isOutgoing': false,
            'status': 1,
            'region': 'cascades',
          }),
          'not json',
        ],
      },
    },
  }),
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('opening', () {
    test('reads a Core backup with its password', () {
      final settings = openCoreBackup(
        coreBackup(history(), 'long password 1'),
        'long password 1',
      );
      expect(settings['some_setting'], isTrue);
      expect(coreHistory(settings), hasLength(4));
    });

    test('a wrong password says so', () {
      expect(
        () => openCoreBackup(coreBackup(history(), 'long password 1'), 'nope'),
        throwsA(
          isA<CoreImportException>().having(
            (e) => e.problem,
            'problem',
            CoreImportProblem.wrongPassword,
          ),
        ),
      );
    });

    test('other files are refused', () {
      for (final file in [
        utf8.encode('hello'),
        utf8.encode(jsonEncode({'format': 'something-else', 'version': 1})),
        [0x53, 0x51, 0x4c, 0xff],
      ]) {
        expect(
          () => openCoreBackup(file, 'x'),
          throwsA(
            isA<CoreImportException>().having(
              (e) => e.problem,
              'problem',
              CoreImportProblem.notCoreBackup,
            ),
          ),
        );
      }
    });

    test('a backup saved without chats says so', () {
      expect(
        () => coreHistory({'some_setting': true}),
        throwsA(
          isA<CoreImportException>().having(
            (e) => e.problem,
            'problem',
            CoreImportProblem.noHistory,
          ),
        ),
      );
    });
  });

  test('messages map onto this app', () {
    final messages = coreHistory(history());
    final sent = messages.firstWhere((m) => m.body == 'see you at the hut');
    expect(sent.radioKey, radioHex);
    expect(sent.thread, Threads.direct(aliceHex));
    expect(sent.outgoing, isTrue);
    expect(sent.status, MessageStatus.delivered);
    expect(sent.sentAt, 1_700_000_000);

    final received = messages.firstWhere((m) => m.pathLength == 2);
    expect(received.body, 'the weather is clear on the ridge tonight');
    expect(received.status, MessageStatus.received);

    final post = messages.firstWhere((m) => m.kind == MessageKind.channel);
    expect(post.thread, Threads.channel(1));
    expect(post.senderName, 'Maya');
    expect(post.region, 'cascades');
  });

  group('storing', () {
    late MeshDatabase db;
    late MeshStore store;
    late MeshSync sync;

    setUp(() async {
      db = MeshDatabase.inMemory();
      store = MeshStore(db);
      final link = FakeRadioLink();
      ScriptedRadio(link);
      sync = MeshSync(
        RadioSession(link),
        store,
        contactRefreshDelay: Duration.zero,
      );
      await sync.start();
    });

    tearDown(() async {
      await sync.stop();
      await db.close();
    });

    test(
      'adds history for known radios once, and skips unknown radios',
      () async {
        final messages = coreHistory(history());
        final first = await store.importCoreMessages(messages);
        expect(first.added, 3);
        expect(first.skippedRadios, 1);

        final again = await store.importCoreMessages(messages);
        expect(again.added, 0, reason: 'nothing is added twice');

        final direct = await store
            .watchThread(radioHex, Threads.direct(aliceHex))
            .first;
        expect(direct.map((m) => m.body), [
          'see you at the hut',
          'the weather is clear on the ridge tonight',
        ]);
        final channel = await store
            .watchThread(radioHex, Threads.channel(1))
            .first;
        expect(channel.single.senderName, 'Maya');
      },
    );
  });
}
