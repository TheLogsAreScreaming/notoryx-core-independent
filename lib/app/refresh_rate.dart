/// How often the app reads the radio's own battery and receiver figures
/// while connected. These go over the cable or Bluetooth, so slowing them
/// saves battery on the phone and the radio, not airtime.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection.dart';

const refreshRateSetting = 'refresh_rate';

enum RefreshRate {
  frequent(
    'Frequent',
    'Sensors every 10 min, noise floor every 5 min',
    Duration(minutes: 10),
    Duration(minutes: 5),
  ),
  normal(
    'Normal',
    'Sensors every 30 min, noise floor every 10 min',
    Duration(minutes: 30),
    Duration(minutes: 10),
  ),
  saver(
    'Battery saver',
    'Sensors every 2 hours, noise floor every hour',
    Duration(hours: 2),
    Duration(hours: 1),
  );

  const RefreshRate(this.label, this.detail, this.sensors, this.noiseFloor);

  final String label;
  final String detail;
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
      title: const Text('Refresh rate'),
      subtitle: Text('${rate.label}. ${rate.detail}.'),
      onTap: () async {
        final picked = await showDialog<RefreshRate>(
          context: context,
          builder: (dialog) => SimpleDialog(
            title: const Text('Refresh rate'),
            children: [
              for (final r in RefreshRate.values)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(dialog).pop(r),
                  child: Text('${r.label}\n${r.detail}'),
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
