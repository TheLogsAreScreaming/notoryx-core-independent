// SARNEG: the codec and code sets, the setup screen, the composer button and
// tap-to-decode.
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/l10n/l10n.dart';
import 'package:notoryx_core/screens/sarneg/sarneg.dart';
import 'package:notoryx_core/screens/sarneg/sarneg_ui.dart';

const String _wellKnown =
    'This word is printed in public guides, so anyone can try it. '
    'A random word is safer.';

final DateTime t0 = DateTime(2026, 11, 21, 9);

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: home,
);

/// A composer with the SARNEG button, and one received message.
class _Chat extends StatefulWidget {
  const _Chat({required this.received});

  final String received;

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Text(widget.received),
        SarnegDecodeLine(text: widget.received, at: t0),
        const Spacer(),
        Row(
          children: [
            SarnegComposeButton(controller: controller),
            Expanded(child: TextField(controller: controller)),
          ],
        ),
      ],
    ),
  );
}

void main() {
  group('codec', () {
    final c = SarnegCodec('BLACKHORSE');

    test('digits become code letters, plain letters stay apart', () {
      expect(c.encode('0123456789'), 'BLACKHORSE');
      expect(c.encode('17S 4823'), 'LRs KSAC');
      expect(c.decode('LRs KSAC'), '17s 4823');
      for (final plain in ['35.22710, -80.84310', '906.875', '']) {
        expect(c.decode(c.encode(plain)), plain);
      }
    });

    test('whole messages carry the marker', () {
      final msg = c.encodeMessage(' 906.875 ');
      expect(msg, '[SARNEG] EBO.SRH');
      expect(isSarnegMessage(msg), isTrue);
      expect(c.decodeMessage(msg), '906.875');
      expect(c.decodeMessage('plain 123'), isNull);
    });

    test('word checks', () {
      expect(normalizeSarnegWord(' black horse '), 'BLACKHORSE');
      expect(checkSarnegWord('BLACK'), SarnegWordProblem.length);
      expect(checkSarnegWord('BLACKHORS3'), SarnegWordProblem.letters);
      expect(checkSarnegWord('BLACKHORSB'), SarnegWordProblem.repeats);
    });
  });

  group('code sets', () {
    final set = SarnegKeySet(
      word: 'BLACKHORSE',
      daily: {'2026-11-22': 'DUMBWAITER', '2026-11-21': 'CUMBERLAND'},
    );

    test('day words, share text, saving', () {
      expect(set.wordFor(DateTime(2026, 11, 20, 23, 59)), 'BLACKHORSE');
      expect(set.wordFor(DateTime(2026, 11, 21, 0, 1)), 'CUMBERLAND');
      final text = set.toShareText();
      expect(
        text,
        'SARNEG1:BLACKHORSE;2026-11-21=CUMBERLAND;2026-11-22=DUMBWAITER',
      );
      expect(SarnegKeySet.parseShareText(text), set);
      expect(SarnegKeySet.fromJson(set.toJson()), set);
      expect(set.withoutDaysBefore('2026-11-22').daily.keys, ['2026-11-22']);
      for (final bad in [
        'hello',
        'SARNEG1:BLACK',
        'SARNEG1:BLACKHORSE;2026-13-40=CUMBERLAND',
      ]) {
        expect(
          () => SarnegKeySet.parseShareText(bad),
          throwsFormatException,
          reason: bad,
        );
      }
    });
  });

  group('key strength', () {
    test('random words are valid code words', () {
      for (var seed = 0; seed < 50; seed++) {
        expect(checkSarnegWord(randomSarnegWord(Random(seed))), isNull);
      }
      expect(checkSarnegWord(randomSarnegWord()), isNull);
    });

    test('well-known words are valid and recognised', () {
      for (final w in kSarnegWellKnownWords) {
        expect(checkSarnegWord(w), isNull, reason: w);
      }
      expect(isWellKnownSarnegWord(' black horse '), isTrue);
      expect(isWellKnownSarnegWord('QZXWVJKMPY'), isFalse);
    });
  });

  group('screens', () {
    late MemorySarnegStorage storage;

    void useKeys(SarnegKeySet? keys) {
      storage = MemorySarnegStorage(
        keys == null ? null : jsonEncode(keys.toJson()),
      );
      SarnegKeys.instance = SarnegKeys(storage: storage, clock: () => t0);
    }

    testWidgets('a bad word is refused, a good one is saved', (tester) async {
      useKeys(null);
      await tester.pumpWidget(_app(const SarnegScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Type a word'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'blackhorsb');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('No letter may appear twice'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'black horse');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(SarnegKeys.instance.keys?.word, 'BLACKHORSE');
      expect(storage.value, contains('BLACKHORSE'));
      expect(find.text('BLACKHORSE'), findsNothing);
      await tester.tap(find.byTooltip('Show the word'));
      await tester.pump();
      expect(find.text('BLACKHORSE'), findsOneWidget);
    });

    testWidgets('composer button and tap-to-decode', (tester) async {
      useKeys(
        SarnegKeySet(word: 'BLACKHORSE', daily: {'2026-11-21': 'CUMBERLAND'}),
      );
      final received =
          '[SARNEG] ${SarnegCodec('CUMBERLAND').encode('906.875')}';
      await tester.pumpWidget(_app(_Chat(received: received)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SARNEG · tap to decode'));
      await tester.pump();
      expect(find.text('Decoded: 906.875'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '17S 4823');
      await tester.tap(find.byTooltip('Send numbers in SARNEG'));
      await tester.pumpAndSettle();
      // today's (dated) word is CUMBERLAND
      final coded = SarnegCodec('CUMBERLAND').encodeMessage('17S 4823');
      expect(find.text(coded), findsOneWidget);
      await tester.tap(find.text('Put in message'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, coded);
    });

    testWidgets('a well-known word warns; Random word fills a valid one', (
      tester,
    ) async {
      useKeys(null);
      await tester.pumpWidget(_app(const SarnegScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Type a word'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'blackhorse');
      await tester.pump();
      expect(find.text(_wellKnown), findsOneWidget);

      await tester.tap(find.text('Random word'));
      await tester.pump();
      final word = tester
          .widget<TextField>(find.byType(TextField))
          .controller!
          .text;
      expect(checkSarnegWord(word), isNull);
      expect(find.text(_wellKnown), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(SarnegKeys.instance.keys!.word, word);
    });

    testWidgets('a saved well-known word shows the warning', (tester) async {
      useKeys(SarnegKeySet(word: 'BLACKHORSE'));
      await tester.pumpWidget(_app(const SarnegScreen()));
      await tester.pumpAndSettle();
      expect(find.text(_wellKnown), findsOneWidget);
    });

    testWidgets('typed numbers and the clipboard clear after a minute', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? clip;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map)['text'] as String?;
        } else if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clip};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      useKeys(SarnegKeySet(word: 'BLACKHORSE'));
      await tester.pumpWidget(_app(const SarnegScreen()));
      await tester.pumpAndSettle();
      final plain = find.widgetWithText(TextField, 'Numbers to encode');
      await tester.enterText(plain, '906.875');
      await tester.pump();
      await tester.tap(find.byTooltip('Copy').first);
      await tester.pump();
      expect(clip, '[SARNEG] EBO.SRH');

      await tester.pump(const Duration(seconds: 61));
      await tester.pump();
      expect(clip, '');
      expect(tester.widget<TextField>(plain).controller!.text, isEmpty);
    });

    testWidgets('an opened decode closes again after a minute', (tester) async {
      useKeys(SarnegKeySet(word: 'BLACKHORSE'));
      final received = SarnegCodec('BLACKHORSE').encodeMessage('906.875');
      await tester.pumpWidget(_app(_Chat(received: received)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SARNEG · tap to decode'));
      await tester.pump();
      expect(find.text('Decoded: 906.875'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Decoded: 906.875'), findsNothing);
      expect(find.text('SARNEG · tap to decode'), findsOneWidget);
    });

    testWidgets('without a word the sheet points to the setup', (tester) async {
      useKeys(null);
      await tester.pumpWidget(_app(const _Chat(received: 'hi')));
      await tester.pumpAndSettle();
      expect(find.text('SARNEG · tap to decode'), findsNothing);
      await tester.tap(find.byTooltip('Send numbers in SARNEG'));
      await tester.pumpAndSettle();
      expect(find.text('Set the code word'), findsOneWidget);
    });
  });
}
