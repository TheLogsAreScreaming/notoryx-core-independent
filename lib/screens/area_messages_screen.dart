import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/area_messages.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';

/// Area-limited messages (experimental): on or off, the circle's size, and
/// whether the connected radio's firmware can do it.
class AreaMessagesScreen extends ConsumerWidget {
  const AreaMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(areaMessagesProvider);
    final notifier = ref.read(areaMessagesProvider.notifier);
    final support = settings.on ? ref.watch(areaSupportProvider) : null;
    final small = Theme.of(context).textTheme.bodySmall;
    final code = settings.radiusCode;
    final km = _km(settings.radiusKm);

    final (IconData icon, String status) = switch (support) {
      null => (Icons.info_outline, l.areaSupportOff),
      AsyncData(value: AreaSupport.supported) => (
        Icons.check_circle_outline,
        l.areaSupportYes,
      ),
      AsyncData(value: AreaSupport.unsupported) => (
        Icons.block,
        l.areaSupportNo,
      ),
      AsyncData() || AsyncError() => (Icons.help_outline, l.areaSupportUnknown),
      _ => (Icons.hourglass_empty, l.areaSupportChecking),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.areaMessages)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.areaMessagesExplainer, style: small),
          ),
          SwitchListTile(
            key: const ValueKey('area-on'),
            title: Text(l.areaMessagesSwitch),
            subtitle: Text(l.areaMessagesSwitchDetail),
            value: settings.on,
            onChanged: notifier.setOn,
          ),
          ListTile(
            key: const ValueKey('area-support'),
            leading: Icon(icon),
            title: Text(l.areaFirmwareSupport),
            subtitle: Semantics(liveRegion: true, child: Text(status)),
          ),
          ListTile(
            key: const ValueKey('area-radius'),
            leading: const Icon(Icons.radar),
            title: Text(l.areaRadius),
            subtitle: Text(l.areaRadiusValue(km)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l.areaSmaller,
                  onPressed: code > 0
                      ? () => notifier.setRadius(code - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: l.areaLarger,
                  onPressed: code < areaRadiusKm.length - 1
                      ? () => notifier.setRadius(code + 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.areaMessagesHowTo, style: small),
          ),
        ],
      ),
    );
  }
}

String _km(double km) => km.toStringAsFixed(0);

/// The radius as shown, e.g. "50".
String areaKmLabel(double km) => _km(km);
