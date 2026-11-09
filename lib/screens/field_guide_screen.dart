import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

typedef _Topic = ({IconData icon, String title, List<String> points});

const List<_Topic> _topics = [
  (
    icon: Icons.bluetooth_connected,
    title: 'Getting connected',
    points: [
      'Your phone talks to your radio over Bluetooth or USB. The radio does '
          'the talking over the air.',
      'On Android, allow the app to run in the background, or the system can '
          'drop the radio while your screen is off.',
      'Everyone in a mesh needs the same frequency settings. Check Local mesh '
          'settings (the globe icon) when you travel.',
    ],
  ),
  (
    icon: Icons.chat_bubble_outline,
    title: 'Channels and direct messages',
    points: [
      'A channel is a shared room: anyone with its key can read it. Channels '
          'don’t confirm delivery.',
      'A direct message is encrypted to one person, and can show when it was '
          'delivered.',
      'A message can take minutes across several hops, or not arrive at all. '
          'Keep it short and don’t count on it.',
    ],
  ),
  (
    icon: Icons.cell_tower,
    title: 'Repeaters and range',
    points: [
      'Height beats power. A radio on a ridge or roof reaches far further '
          'than one in a pocket.',
      'Repeaters pass messages along. Open one from Contacts to log in, see '
          'its status, or ping it.',
      'To place an antenna, open a repeater that’s one hop away and use '
          'Antenna hunt.',
      'Every message uses shared airtime. Avoid sending the same thing '
          'repeatedly.',
    ],
  ),
  (
    icon: Icons.health_and_safety_outlined,
    title: 'SOS and check-ins',
    points: [
      'This mesh is not an emergency service. Nobody is guaranteed to be '
          'listening. Carry another way to call for help.',
      'Choose a main chat and trip contacts before you leave, then test them.',
      'Hold the SOS button for 2 seconds. It repeats every 5 minutes until '
          'someone answers. Send I’m safe to end it.',
      'SOS repeats and reminders only run while the app runs. They stop if '
          'you close it.',
      'Send a trip brief before you go, so people know where to look.',
    ],
  ),
  (
    icon: Icons.battery_charging_full,
    title: 'Battery',
    points: [
      'Your radio’s battery shows on the Chats tab. Tap it for the history.',
      'Battery saver under Refresh rate reads the radio less often.',
      'Cold drains batteries quickly. Keep spares warm and close to you.',
    ],
  ),
  (
    icon: Icons.build_outlined,
    title: 'When something’s wrong',
    points: [
      'Not connecting: turn the radio off and on, then check the Connection '
          'log.',
      'Messages not arriving: reset the route in the chat, then send an '
          'advert so others can find you.',
      'A contact’s adverts stopped updating after its clock was reset: use '
          'Forget last advert time in its More menu.',
      'Hearing nobody: make sure your frequency settings match the local '
          'mesh.',
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
        for (final topic in _topics)
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
