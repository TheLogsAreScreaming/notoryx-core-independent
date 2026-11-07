import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../app/packet_log.dart';
import '../data/data.dart';
import '../radio/radio.dart';

/// Every packet the radio has heard over the air while connected: what it
/// was, how it travelled, who passed it on, and how strong it was.
class PacketLogScreen extends ConsumerWidget {
  const PacketLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packets = ref.watch(packetLogProvider);
    final log = ref.read(packetLogProvider.notifier);
    final radioKey = ref.watch(radioKeyProvider);
    final contacts = radioKey == null
        ? const <Contact>[]
        : ref.watch(contactsProvider(radioKey)).value ?? const <Contact>[];
    return Scaffold(
      appBar: AppBar(
        title: Text('Packets heard (${packets.length})'),
        actions: [
          IconButton(
            tooltip: log.paused ? 'Resume' : 'Pause',
            icon: Icon(log.paused ? Icons.play_arrow : Icons.pause),
            onPressed: () => log.setPaused(!log.paused),
          ),
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: log.clear,
          ),
        ],
      ),
      body: packets.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing heard yet. Packets show here as the radio hears '
                  'them, while the app is connected.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              itemCount: packets.length,
              itemBuilder: (context, i) => _PacketTile(
                packet: packets[packets.length - 1 - i],
                contacts: contacts,
              ),
            ),
    );
  }
}

class _PacketTile extends StatelessWidget {
  const _PacketTile({required this.packet, required this.contacts});

  final HeardPacket packet;
  final List<Contact> contacts;

  String _name(String hex) {
    for (final c in contacts) {
      if (c.publicKey.startsWith(hex)) return c.name;
    }
    return hex.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final h = packet.header;
    final time = TimeOfDay.fromDateTime(packet.at).format(context);
    final seconds = packet.at.second.toString().padLeft(2, '0');
    final signal =
        'SNR ${packet.snr.toStringAsFixed(1)} dB · RSSI ${packet.rssi} dBm';
    if (h == null) {
      return ListTile(
        dense: true,
        leading: const Icon(Icons.help_outline),
        title: Text('Unreadable packet (${packet.length} bytes)'),
        subtitle: Text('$time:$seconds · $signal'),
      );
    }
    final hops = h.hops;
    final via = switch ((h.route, hops.isEmpty)) {
      (RouteKind.flood || RouteKind.transportFlood, true) => 'heard directly',
      (RouteKind.flood || RouteKind.transportFlood, false) =>
        'via ${hops.map(_name).join(' → ')}',
      (_, true) => 'direct, last hop',
      (_, false) => 'direct, next ${hops.map(_name).join(' → ')}',
    };
    final title = switch (h.advertKey) {
      final key? => 'Advert from ${_fullName(key)}',
      null => h.payload.label,
    };
    return ListTile(
      dense: true,
      leading: Icon(_icon(h.payload)),
      title: Text(title),
      subtitle: Text(
        '$time:$seconds · ${h.route.label}, $via\n'
        '$signal · ${packet.length} bytes',
      ),
      isThreeLine: true,
    );
  }

  String _fullName(String key) {
    for (final c in contacts) {
      if (c.publicKey == key) return c.name;
    }
    return '${key.substring(0, 8).toUpperCase()}…';
  }

  static IconData _icon(PayloadKind kind) => switch (kind) {
    PayloadKind.advert => Icons.campaign_outlined,
    PayloadKind.text => Icons.chat_bubble_outline,
    PayloadKind.groupText || PayloadKind.groupData => Icons.forum_outlined,
    PayloadKind.ack => Icons.done_all,
    PayloadKind.trace => Icons.route,
    PayloadKind.path => Icons.alt_route,
    PayloadKind.request ||
    PayloadKind.response ||
    PayloadKind.anonRequest => Icons.swap_horiz,
    _ => Icons.radio,
  };
}
