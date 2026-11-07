import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/keep_alive.dart';

/// Asks to be left alone by Android's battery saver, which otherwise can
/// drop the radio connection when the app is in the background.
class BatteryBanner extends ConsumerStatefulWidget {
  const BatteryBanner({super.key});

  @override
  ConsumerState<BatteryBanner> createState() => _BatteryBannerState();
}

class _BatteryBannerState extends ConsumerState<BatteryBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system dialog or settings: check again.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(batteryRestrictedProvider);
    }
  }

  Future<void> _notNow() async {
    await ref
        .read(storeProvider)
        .saveSetting(batteryPromptDismissedSetting, '1');
    if (mounted) ref.invalidate(batteryPromptProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(batteryPromptProvider).value != true) {
      return const SizedBox.shrink();
    }
    return MaterialBanner(
      leading: const Icon(Icons.battery_alert_outlined),
      content: const Text(
        'Battery saver can drop the radio while the app is in the '
        'background. Let it run to stay connected and get alerts.',
      ),
      actions: [
        TextButton(onPressed: _notNow, child: const Text('Not now')),
        TextButton(
          onPressed: () =>
              ref.read(keepAliveProvider).requestBatteryUnrestricted(),
          child: const Text('Allow'),
        ),
      ],
    );
  }
}
