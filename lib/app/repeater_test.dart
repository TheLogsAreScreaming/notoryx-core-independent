/// Nearby repeater test: one tap asks every repeater within one hop to
/// answer, then lists who did and how well the signal gets through each
/// way. Uses the same zero-hop discover ping as wardriving, without
/// recording anything.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/data.dart' hide WardriveHit;
import 'connection.dart';
import 'safety.dart';
import 'wardrive.dart';

/// How a responder's signal rates, from the weaker of the two directions.
/// Above 0 dB is comfortable; below −10 dB is near the limit LoRa decodes.
enum ResponderSignal {
  strong,
  usable,
  weak;

  static ResponderSignal fromSnr(double snr) => switch (snr) {
    >= 0 => strong,
    >= -10 => usable,
    _ => weak,
  };
}

/// A repeater that answered.
typedef Responder = ({
  String publicKey,

  /// Its name from contacts or adverts heard nearby, or null if unknown.
  String? name,

  /// How well it heard this radio, in dB.
  double heardUs,

  /// How well this radio heard its answer, in dB.
  double weHeard,
  int rssi,
  bool isContact,
});

extension ResponderRating on Responder {
  /// The weaker direction: a link is only as good as its worse half.
  double get weakerSnr => heardUs < weHeard ? heardUs : weHeard;
  ResponderSignal get signal => ResponderSignal.fromSnr(weakerSnr);
}

/// Names [hits] from [contacts] and [discovered] and sorts them, best
/// two-way signal first.
List<Responder> responders(
  List<WardriveHit> hits, {
  List<Contact> contacts = const [],
  List<DiscoveredData> discovered = const [],
}) {
  final contactNames = {
    for (final c in contacts) c.publicKey.toLowerCase(): c.name,
  };
  final heardNames = {
    for (final d in discovered) d.publicKey.toLowerCase(): d.name,
  };
  final out = <Responder>[
    for (final h in hits)
      (
        publicKey: h.publicKey,
        name:
            contactNames[h.publicKey.toLowerCase()] ??
            heardNames[h.publicKey.toLowerCase()],
        heardUs: h.heardUs,
        weHeard: h.weHeard,
        rssi: h.rssi,
        isContact: contactNames.containsKey(h.publicKey.toLowerCase()),
      ),
  ];
  out.sort((a, b) => b.weakerSnr.compareTo(a.weakerSnr));
  return out;
}

/// Sends one ping and returns the answers, or null with no radio.
typedef RepeaterProbe = Future<List<WardriveHit>> Function();

final repeaterProbeProvider = Provider<RepeaterProbe?>((ref) {
  final connection = ref.watch(connectionProvider);
  if (connection is! Connected) return null;
  return () => pingRepeaters(connection.sync.session);
});

sealed class RepeaterTestState {
  const RepeaterTestState();
}

final class RepeaterTestIdle extends RepeaterTestState {
  const RepeaterTestIdle();
}

final class RepeaterTestRunning extends RepeaterTestState {
  const RepeaterTestRunning();
}

final class RepeaterTestDone extends RepeaterTestState {
  const RepeaterTestDone(this.hits, this.at);

  /// Raw answers; named at display time so new contacts show up.
  final List<WardriveHit> hits;
  final DateTime at;
}

final class RepeaterTestFailed extends RepeaterTestState {
  const RepeaterTestFailed();
}

final repeaterTestProvider = NotifierProvider<RepeaterTest, RepeaterTestState>(
  RepeaterTest.new,
);

class RepeaterTest extends Notifier<RepeaterTestState> {
  @override
  RepeaterTestState build() => const RepeaterTestIdle();

  /// Runs one test. Does nothing while one is running or with no radio.
  Future<void> run() async {
    if (state is RepeaterTestRunning) return;
    final probe = ref.read(repeaterProbeProvider);
    if (probe == null) return;
    state = const RepeaterTestRunning();
    try {
      final hits = await probe();
      if (!ref.mounted) return;
      state = RepeaterTestDone(hits, ref.read(safetyClockProvider)());
    } on Object catch (e) {
      if (!ref.mounted) return;
      ref.read(connectionLogProvider).add('repeater test: $e');
      state = const RepeaterTestFailed();
    }
  }
}
