import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_lock.dart';
import '../app/db_encryption_control.dart';
import '../data/data.dart';
import '../l10n/l10n.dart';
import 'safety_screen.dart';

/// Covers the app while it is locked, and asks to unlock at launch.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
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
    final lock = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        lock.left();
      case AppLifecycleState.resumed:
        lock.returned();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = ref.watch(appLockProvider);
    final covered = !lock.loaded || lock.locked;
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: covered, child: widget.child),
        if (!lock.loaded)
          ColoredBox(color: Theme.of(context).scaffoldBackgroundColor)
        else if (lock.locked)
          // Its own navigator, so SOS can open on top of the lock.
          HeroControllerScope.none(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => const _LockedScreen(),
              ),
            ),
          ),
      ],
    );
  }
}

class _LockedScreen extends ConsumerStatefulWidget {
  const _LockedScreen();

  @override
  ConsumerState<_LockedScreen> createState() => _LockedScreenState();
}

class _LockedScreenState extends ConsumerState<_LockedScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final ok = await ref.read(appLockProvider.notifier).unlock();
    if (mounted) setState(() => _failed = !ok);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 56),
              const SizedBox(height: 16),
              Text(
                context.l10n.appLocked,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (_failed) ...[
                const SizedBox(height: 8),
                const Text('That didn’t unlock it. Try again.'),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: Text(context.l10n.unlock),
                onPressed: _unlock,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.health_and_safety_outlined),
                label: Text(context.l10n.sosAndCheckIns),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SafetyScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _label(Duration d) => d == Duration.zero
    ? 'Right away'
    : d.inMinutes == 1
    ? 'After 1 minute'
    : 'After ${d.inMinutes} minutes';

/// The lock's on/off switch and timeout.
class AppLockSettingsScreen extends ConsumerWidget {
  const AppLockSettingsScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(appLockProvider.notifier).setEnabled(on);
    final message = switch (result) {
      AuthResult.success => null,
      AuthResult.failed => 'That didn’t work, so nothing changed.',
      AuthResult.unavailable =>
        on ? 'Set a screen lock on this device first.' : null,
    };
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('App lock')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Lock the app'),
            subtitle: const Text('Uses your fingerprint, face or screen lock'),
            value: lock.enabled,
            onChanged: (on) => _toggle(context, ref, on),
          ),
          if (lock.enabled)
            ListTile(
              title: const Text('Lock when away'),
              trailing: DropdownButton<Duration>(
                value: lock.timeout,
                items: [
                  for (final d in appLockChoices)
                    DropdownMenuItem(value: d, child: Text(_label(d))),
                ],
                onChanged: (d) {
                  if (d != null) {
                    ref.read(appLockProvider.notifier).setTimeout(d);
                  }
                },
              ),
            ),
          if (databaseSetAside)
            const ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('Earlier chat history couldn’t be opened'),
              subtitle: Text(
                'Its key is gone from this device. The file was kept, and '
                'a backup can bring your history back.',
              ),
            ),
          const _EncryptHistoryTile(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'While locked, the radio stays connected, SOS repeats keep '
              'going, and SOS and check-ins can still be opened without '
              'unlocking. Message notifications hide who and what.',
            ),
          ),
        ],
      ),
    );
  }
}

/// Encrypts chat history on this device, after saying what could go wrong.
class _EncryptHistoryTile extends ConsumerStatefulWidget {
  const _EncryptHistoryTile();

  @override
  ConsumerState<_EncryptHistoryTile> createState() =>
      _EncryptHistoryTileState();
}

class _EncryptHistoryTileState extends ConsumerState<_EncryptHistoryTile> {
  bool _working = false;

  Future<void> _change(bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Encrypt chat history?'),
          content: const Text(
            'The key stays in this device’s secure storage. If that is ever '
            'wiped, or the app’s data moves to another phone, this history '
            'can’t be read. Make a backup first: backups use your own '
            'password and still work.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Encrypt'),
            ),
          ],
        ),
      );
      if (sure != true || !mounted) return;
    }
    setState(() => _working = true);
    try {
      await ref.read(dbEncryptionProvider.notifier).set(on);
    } on DbEncryptionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final encrypted = ref.watch(dbEncryptionProvider).value;
    if (encrypted == null) return const SizedBox.shrink();
    return SwitchListTile(
      title: const Text('Encrypt chat history'),
      subtitle: const Text('Protects chats stored on this device'),
      value: encrypted,
      onChanged: _working ? null : _change,
    );
  }
}
