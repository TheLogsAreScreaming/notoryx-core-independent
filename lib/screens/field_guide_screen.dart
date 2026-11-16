import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

typedef _Topic = ({IconData icon, String title, List<String> points});

List<_Topic> _topics(AppLocalizations l10n) => [
  (
    icon: Icons.bluetooth_connected,
    title: l10n.guideConnected,
    points: [l10n.guideConnected1, l10n.guideConnected2, l10n.guideConnected3],
  ),
  (
    icon: Icons.chat_bubble_outline,
    title: l10n.guideChannels,
    points: [l10n.guideChannels1, l10n.guideChannels2, l10n.guideChannels3],
  ),
  (
    icon: Icons.cell_tower,
    title: l10n.guideRepeaters,
    points: [
      l10n.guideRepeaters1,
      l10n.guideRepeaters2,
      l10n.guideRepeaters3,
      l10n.guideRepeaters4,
    ],
  ),
  (
    icon: Icons.health_and_safety_outlined,
    title: l10n.guideSos,
    points: [
      l10n.guideSos1,
      l10n.guideSos2,
      l10n.guideSos3,
      l10n.guideSos4,
      l10n.guideSos5,
    ],
  ),
  (
    icon: Icons.battery_charging_full,
    title: l10n.guideBattery,
    points: [l10n.guideBattery1, l10n.guideBattery2, l10n.guideBattery3],
  ),
  (
    icon: Icons.build_outlined,
    title: l10n.guideTrouble,
    points: [
      l10n.guideTrouble1,
      l10n.guideTrouble2,
      l10n.guideTrouble3,
      l10n.guideTrouble4,
    ],
  ),
];

/// Short offline help for using the mesh in the field.
class FieldGuideScreen extends StatelessWidget {
  const FieldGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.fieldGuide)),
    body: ListView(
      children: [
        for (final topic in _topics(context.l10n))
          ExpansionTile(
            leading: Icon(topic.icon),
            title: Text(topic.title),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final point in topic.points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(point),
                ),
            ],
          ),
      ],
    ),
  );
}
