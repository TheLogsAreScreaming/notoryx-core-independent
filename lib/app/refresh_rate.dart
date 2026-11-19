/// How often the app reads the radio's own battery and receiver figures
/// while connected. These go over the cable or Bluetooth, so slowing them
/// saves battery on the phone and the radio, not airtime.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import 'connection.dart';

const refreshRateSetting = 'refresh_rate';

enum RefreshRate {
  frequent(Duration(minutes: 10), Duration(minutes: 5)),
  normal(Duration(minutes: 30), Duration(minutes: 10)),
  saver(Duration(hours: 2), Duration(hours: 1));

  const RefreshRate(this.sensors, this.noiseFloor);

  /// The rate's name in the app's language.
  String label(AppLocalizations l10n) => switch (this) {
    frequent => l10n.rateFrequent,
    normal => l10n.rateNormal,
    saver => l10n.rateSaver,
  };

  /// What the rate means, in the app's language.
  String detail(AppLocalizations l10n) => switch (this) {
    frequent => l10n.rateFrequentDetail,
    normal => l10n.rateNormalDetail,
    saver => l10n.rateSaverDetail,
  };

  final Duration sensors;
  final Duration noiseFloor;
}

final refreshRateProvider = NotifierProvider<RefreshRateNotifier, RefreshRate>(
  RefreshRateNotifier.new,
);

class RefreshRateNotifier extends Notifier<RefreshRate> {
  @override
  RefreshRate build() {
    unawaited(_load());
    return RefreshRate.normal;
  }

  Future<void> _load() async {
    final raw = await ref.read(storeProvider).setting(refreshRateSetting);
    if (!ref.mounted) return;
    state = RefreshRate.values.asNameMap()[raw] ?? RefreshRate.normal;
  }

  Future<void> set(RefreshRate rate) async {
    state = rate;
    await ref.read(storeProvider).saveSetting(refreshRateSetting, rate.name);
  }
}

/// The setting's row in Radio settings.
class RefreshRateTile extends ConsumerWidget {
  const RefreshRateTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rate = ref.watch(refreshRateProvider);
    return ListTile(
      leading: const Icon(Icons.speed),
      title: Text(context.l10n.refreshRate),
      subtitle: Text(
        context.l10n.rateSummary(
          rate.label(context.l10n),
          rate.detail(context.l10n),
        ),
      ),
      onTap: () async {
        final picked = await showDialog<RefreshRate>(
          context: context,
          builder: (dialog) => SimpleDialog(
            title: Text(context.l10n.refreshRate),
            children: [
              for (final r in RefreshRate.values)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(dialog).pop(r),
                  child: Text(
                    '${r.label(context.l10n)}\n${r.detail(context.l10n)}',
                  ),
                ),
            ],
          ),
        );
        if (picked != null) {
          await ref.read(refreshRateProvider.notifier).set(picked);
        }
      },
    );
  }
}
