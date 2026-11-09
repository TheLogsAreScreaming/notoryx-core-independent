import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notoryx_core/app/antenna_hunt.dart';

void main() {
  group('clicks', () {
    test('get faster as the signal gets louder', () {
      expect(clickInterval(-20), const Duration(milliseconds: 1500));
      expect(clickInterval(12), const Duration(milliseconds: 120));
      expect(clickInterval(0) < clickInterval(-10), isTrue);
    });

    test('stay within range beyond the scale', () {
      expect(clickInterval(-60), clickInterval(-20));
      expect(clickInterval(40), clickInterval(12));
    });
  });

  group('hunt', () {
    test('tracks the best, clicks, and stops when asked', () {
      fakeAsync((async) {
        final answers = <double?>[-5, 6, null];
        var pings = 0;
        var clicks = 0;
        final hunt = AntennaHunt(
          ping: () async => answers[pings++ % 3],
          click: () => clicks++,
        )..start();
        async.flushMicrotasks();
        expect(hunt.latest, -5);
        expect(hunt.best, -5);
        async.elapse(const Duration(seconds: 5));
        expect(hunt.latest, 6);
        expect(hunt.best, 6);
        expect(clicks, greaterThan(0));

        async.elapse(const Duration(seconds: 5));
        expect(hunt.lost, isTrue);
        expect(hunt.best, 6);
        final silent = clicks;
        async.elapse(const Duration(seconds: 4));
        expect(clicks, silent, reason: 'no answer, no clicks');

        hunt.stop();
        final sent = pings;
        async.elapse(const Duration(minutes: 1));
        expect(pings, sent);
        hunt.dispose();
      });
    });

    test('stops by itself at the time limit', () {
      fakeAsync((async) {
        var pings = 0;
        final hunt = AntennaHunt(
          ping: () async {
            pings++;
            return 1;
          },
          click: () {},
        )..start();
        async.elapse(const Duration(minutes: 5, seconds: 1));
        expect(hunt.running, isFalse);
        expect(hunt.timedOut, isTrue);
        final sent = pings;
        expect(sent, lessThanOrEqualTo(61));
        async.elapse(const Duration(minutes: 5));
        expect(pings, sent);
        hunt.dispose();
      });
    });

    test('a failing ping counts as no answer', () {
      fakeAsync((async) {
        final hunt = AntennaHunt(
          ping: () async => throw StateError('radio gone'),
          click: () {},
        )..start();
        async.flushMicrotasks();
        expect(hunt.lost, isTrue);
        expect(hunt.running, isTrue);
        hunt
          ..stop()
          ..dispose();
      });
    });
  });
}
