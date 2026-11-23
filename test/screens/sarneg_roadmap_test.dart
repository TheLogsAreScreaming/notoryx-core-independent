// SARNEG options: grid zone in clear, no marker, unmarked decode, expiry and
// burn, SARDOT, positions and the number of the day.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/l10n/l10n.dart';
import 'package:notoryx_core/screens/sarneg/sarneg.dart';
import 'package:notoryx_core/screens/sarneg/sarneg_ui.dart';

final DateTime t0 = DateTime(2026, 11, 23, 9);

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: home,
);

Widget _line(String text) => _app(
  Scaffold(
    body: Center(
      child: SarnegDecodeLine(text: text, at: t0),
    ),
  ),
);

void main() {
  final codec = SarnegCodec('BLACKHORSE');

  group('codec options', () {
    test('a grid zone can stay in clear and still decodes', () {
      expect(codec.encode('17S 4823', keepZone: true), '17s KSAC');
      expect(codec.encode('17SMV 4823', keepZone: true), '17smv KSAC');
      expect(codec.encode('17S 4823'), 'LRs KSAC');
      expect(codec.decode('17s KSAC'), '17s 4823');
      // Not zones: a frequency, a time, zone 0, zone 61, a word.
      expect(codec.encode('906.875', keepZone: true), 'EBO.SRH');
      expect(codec.encode('1430z', keepZone: true), 'LKCBz');
      expect(codec.encode('0S', keepZone: true), 'Bs');
      expect(codec.encode('61S', keepZone: true), 'OLs');
      expect(codec.encode('4 Sunday', keepZone: true), 'K sunday');
    });

    test('a message can go without the marker', () {
      expect(codec.encodeMessage('42', marker: false), 'KA');
      expect(codec.encodeMessage('42'), '[SARNEG] KA');
      expect(codec.decodeAny('KA'), '42');
      expect(codec.decodeAny('[SARNEG] KA'), '42');
    });

    test('unmarked text is offered only when it fits the word', () {
      expect(codec.mayBeUnmarked('eta KCB'), isTrue);
      expect(codec.mayBeUnmarked('17s KSAC'), isTrue);
      expect(codec.mayBeUnmarked('Hello World'), isFalse);
      expect(codec.mayBeUnmarked('OK'), isTrue);
      expect(codec.mayBeUnmarked('ok thanks'), isFalse);
      expect(codec.mayBeUnmarked('A'), isFalse);
      expect(codec.mayBeUnmarked('[SARNEG] KC'), isFalse);
    });
  });

  group('SARDOT and positions', () {
    test('bearing and distance there and back', () {
      const ref = (41.30, -73.10);
      const here = (41.33, -73.05);
      final dot = sardotFrom(ref, here);
      expect(dot.$1, inInclusiveRange(48, 52));
      expect(dot.$2, closeTo(5300, 200));
      final text = sardotText(dot.$1, dot.$2);
      expect(text, matches(RegExp(r'^sardot \d{3} \d+\.\d{2}km$')));
      final back = parseSardot(codec.decode(codec.encode(text)))!;
      final p = sardotTarget(ref, back.$1, back.$2);
      expect(p.$1, closeTo(here.$1, 0.002));
      expect(p.$2, closeTo(here.$2, 0.002));
    });

    test('positions are found in decoded text', () {
      expect(sarnegPositionIn('at 41.32800, -73.09400 ok'), (41.328, -73.094));
      expect(sarnegPositionIn('906.875'), isNull);
      expect(sarnegPositionIn('100.0, 10.0'), isNull);
      expect(sarnegPositionIn('sardot 090 1.00km'), isNull);
      final p = sarnegPositionIn('sardot 090 1.00km', reference: (0.0, 0.0))!;
      expect(p.$1, closeTo(0, 1e-6));
      expect(p.$2, closeTo(0.008993, 1e-5));
      expect(parseSardot('sardot 400 1km'), isNull);
    });

    test('number of the day reply', () {
      expect(sarnegReply(37, 12), 25);
      expect(sarnegReply(37, 37), 0);
      expect(sarnegReply(37, 40), isNull);
    });
  });

  group('options storage', () {
    test('saved with the words, not in the shared text', () async {
      final storage = MemorySarnegStorage();
      final keys = SarnegKeys(storage: storage, clock: () => t0);
      await keys.save(SarnegKeySet(word: 'BLACKHORSE'));
      await keys.saveOptions(
        const SarnegOptions(
          keepZone: true,
          noMarker: true,
          readUnmarked: true,
          wipeAfter: '2026-12-01',
          sardotLat: 41.3,
          sardotLon: -73.1,
          numberOfDay: 37,
          letterOfDay: 'K',
        ),
      );
      expect(keys.keys!.toShareText(), 'SARNEG1:BLACKHORSE');
      final again = SarnegKeys(storage: storage, clock: () => t0);
      await again.ensureLoaded();
      final o = again.options;
      expect(o.keepZone && o.noMarker && o.readUnmarked, isTrue);
      expect(o.wipeAfter, '2026-12-01');
      expect((o.sardotLat, o.sardotLon), (41.3, -73.1));
      expect((o.numberOfDay, o.letterOfDay), (37, 'K'));
      // Older builds still read the words.
      expect(
        SarnegKeySet.fromJson(jsonDecode(storage.value!)),
        SarnegKeySet(word: 'BLACKHORSE'),
      );
    });

    test('damaged options are dropped', () {
      final o = SarnegOptions.fromJson({
        'sardot': [91, 0],
        'nod': 120,
        'lod': 'kk',
        'wipeAfter': 'soon',
      });
      expect(o.hasSardot, isFalse);
      expect(o.numberOfDay, isNull);
      expect(o.letterOfDay, isNull);
      expect(o.wipeAfter, isNull);
    });

    test('past dated words are deleted from storage', () async {
      final storage = MemorySarnegStorage(
        jsonEncode(
          SarnegKeySet(
            word: 'BLACKHORSE',
            daily: {'2026-11-20': 'CUMBERLAND', '2026-11-24': 'DUMBWAITER'},
          ).toJson(),
        ),
      );
      final keys = SarnegKeys(storage: storage, clock: () => t0);
      await keys.ensureLoaded();
      expect(keys.keys!.daily.keys, ['2026-11-24']);
      expect(storage.value, isNot(contains('CUMBERLAND')));
    });

    test('every word is deleted after the wipe day', () async {
      final storage = MemorySarnegStorage(
        jsonEncode({
          ...SarnegKeySet(word: 'BLACKHORSE').toJson(),
          'options': {'wipeAfter': '2026-11-22', 'nod': 5},
        }),
      );
      final keys = SarnegKeys(storage: storage, clock: () => t0);
      await keys.ensureLoaded();
      expect(keys.keys, isNull);
      expect(keys.options.numberOfDay, isNull);
      expect(storage.value, isNull);
    });
  });

  group('screens', () {
    late MemorySarnegStorage storage;
    final clipboard = <String>[];

    setUp(() {
      clipboard.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboard.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
    });

    Future<void> useKeys(
      SarnegKeySet? keys, [
      SarnegOptions options = const SarnegOptions(),
    ]) async {
      storage = MemorySarnegStorage(
        keys == null
            ? null
            : jsonEncode({...keys.toJson(), 'options': options.toJson()}),
      );
      SarnegKeys.instance = SarnegKeys(storage: storage, clock: () => t0);
    }

    testWidgets('unmarked text decodes only when the option is on', (
      tester,
    ) async {
      await useKeys(SarnegKeySet(word: 'BLACKHORSE'));
      await tester.pumpWidget(_line('eta KCB'));
      await tester.pumpAndSettle();
      expect(find.text('Maybe SARNEG · tap to decode'), findsNothing);

      await useKeys(
        SarnegKeySet(word: 'BLACKHORSE'),
        const SarnegOptions(readUnmarked: true),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_line('eta KCB'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maybe SARNEG · tap to decode'));
      await tester.pump();
      expect(find.text('Decoded: eta 430'), findsOneWidget);
      await tester.pumpWidget(_line('Hello World'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SARNEG'), findsNothing);
    });

    testWidgets('a decoded position offers the map', (tester) async {
      await useKeys(SarnegKeySet(word: 'BLACKHORSE'));
      final msg = codec.encodeMessage('41.32800, -73.09400');
      await tester.pumpWidget(_line(msg));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show on map'), findsNothing);
      await tester.tap(find.text('SARNEG · tap to decode'));
      await tester.pump();
      expect(find.byTooltip('Show on map'), findsOneWidget);
    });

    testWidgets('SARDOT decodes to a position only with the reference', (
      tester,
    ) async {
      final msg = codec.encodeMessage('sardot 090 1.00km');
      await useKeys(SarnegKeySet(word: 'BLACKHORSE'));
      await tester.pumpWidget(_line(msg));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SARNEG · tap to decode'));
      await tester.pump();
      expect(find.text('Decoded: sardot 090 1.00km'), findsOneWidget);
      expect(find.byTooltip('Show on map'), findsNothing);

      await useKeys(
        SarnegKeySet(word: 'BLACKHORSE'),
        const SarnegOptions(sardotLat: 41.3, sardotLon: -73.1),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_line(msg));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SARNEG · tap to decode'));
      await tester.pump();
      expect(find.byTooltip('Show on map'), findsOneWidget);
    });

    testWidgets('options change what the hand box sends', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await useKeys(SarnegKeySet(word: 'BLACKHORSE'));
      await tester.pumpWidget(_app(const SarnegScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Numbers to encode'),
        '17S 4823',
      );
      await tester.pump();
      expect(find.text('[SARNEG] LRs KSAC'), findsOneWidget);
      await tester.tap(find.text('Keep grid zone in clear'));
      await tester.pumpAndSettle();
      expect(find.text('[SARNEG] 17s KSAC'), findsOneWidget);
      await tester.tap(find.text('Send without the [SARNEG] marker'));
      await tester.pumpAndSettle();
      expect(find.text('17s KSAC'), findsOneWidget);
      expect(SarnegKeys.instance.options.keepZone, isTrue);
      expect(SarnegKeys.instance.options.noMarker, isTrue);
      expect(storage.value, contains('"keepZone":true'));
    });

    testWidgets('number of the day gives the reply', (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await useKeys(
        SarnegKeySet(word: 'BLACKHORSE'),
        const SarnegOptions(numberOfDay: 37),
      );
      await tester.pumpWidget(_app(const SarnegScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Number they said'),
        '12',
      );
      await tester.pump();
      expect(find.text('Reply: 25'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Number they said'),
        '50',
      );
      await tester.pump();
      expect(find.textContaining('No valid reply'), findsOneWidget);
      await tester.pump(const Duration(seconds: 61));
      expect(find.textContaining('No valid reply'), findsNothing);
    });

    testWidgets('Forget burns words, options and the clipboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await useKeys(
        SarnegKeySet(word: 'BLACKHORSE'),
        const SarnegOptions(numberOfDay: 37, sardotLat: 1, sardotLon: 2),
      );
      await tester.pumpWidget(_app(const SarnegScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forget'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Forget').last);
      await tester.pumpAndSettle();
      expect(SarnegKeys.instance.keys, isNull);
      expect(SarnegKeys.instance.options.numberOfDay, isNull);
      expect(storage.value, isNull);
      expect(clipboard, ['']);
      expect(find.text('No code word on this phone yet.'), findsOneWidget);
    });
  });
}
