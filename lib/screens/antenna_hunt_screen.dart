import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/antenna_hunt.dart';
import '../app/connection.dart';
import '../radio/radio.dart';
import '../l10n/l10n.dart';

/// Move the antenna around and listen: faster clicks mean a louder repeater.
class AntennaHuntScreen extends ConsumerStatefulWidget {
  const AntennaHuntScreen({
    required this.publicKey,
    required this.name,
    super.key,
  });

  final String publicKey;
  final String name;

  @override
  ConsumerState<AntennaHuntScreen> createState() => _AntennaHuntScreenState();
}

class _AntennaHuntScreenState extends ConsumerState<AntennaHuntScreen> {
  late final AntennaHunt _hunt = AntennaHunt(ping: _ping, click: _click);

  Future<double?> _ping() async {
    final state = ref.read(connectionProvider);
    if (state is! Connected) return null;
    final reply = await state.sync.trace([
      fromHex(widget.publicKey).sublist(0, 1),
    ], hashBytes: 1);
    return reply?.finalSnr;
  }

  void _click() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _hunt.dispose();
    super.dispose();
  }

  String _db(double? v) => v == null ? '–' : '${v.toStringAsFixed(1)} dB';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.antennaHunt)),
      body: ListenableBuilder(
        listenable: _hunt,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(widget.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Move or turn the antenna slowly. Faster clicks mean this '
              'repeater is louder. It must be one hop away.',
            ),
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              child: Text(
                _hunt.lost ? 'No answer' : _db(_hunt.latest),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Best so far: ${_db(_hunt.best)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: Icon(_hunt.running ? Icons.stop : Icons.play_arrow),
              label: Text(_hunt.running ? 'Stop' : 'Start'),
              onPressed: _hunt.running ? _hunt.stop : _hunt.start,
            ),
            const SizedBox(height: 16),
            Text(
              _hunt.timedOut
                  ? 'Stopped after 5 minutes to keep the channel clear. '
                        'Start again if you need more time.'
                  : 'Pings every 5 seconds and stops by itself after 5 '
                        'minutes, because each ping uses airtime.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
