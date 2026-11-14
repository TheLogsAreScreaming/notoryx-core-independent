import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';

/// The key in [text]: 128 hex digits, ignoring spaces, line breaks and a
/// leading 0x. Null when it isn't one.
Uint8List? parsePrivateKeyHex(String text) {
  var hex = text.replaceAll(RegExp(r'\s'), '').toLowerCase();
  if (hex.startsWith('0x')) hex = hex.substring(2);
  if (!RegExp(r'^[0-9a-f]{128}$').hasMatch(hex)) return null;
  return Uint8List.fromList([
    for (var i = 0; i < 128; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]);
}

/// Shows the connected radio's identity private key for a backup, or gives
/// the radio an identity from one.
class IdentityKeyScreen extends ConsumerStatefulWidget {
  const IdentityKeyScreen({super.key});

  @override
  ConsumerState<IdentityKeyScreen> createState() => _IdentityKeyScreenState();
}

class _IdentityKeyScreenState extends ConsumerState<IdentityKeyScreen> {
  final _pasted = TextEditingController();
  String? _key;
  bool _working = false;

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  String _problem(Object error) {
    final l = context.l10n;
    return switch (error) {
      RadioFeatureDisabled() ||
      RadioRejected(
        code: RadioErrorCode.unsupportedCommand,
      ) => l.keyBackupTurnedOff,
      RadioTimeout() => l.keyBackupNoAnswer,
      RadioRejected() => l.keyBackupRefused,
      _ => l.keyBackupNotConnected,
    };
  }

  void _tell(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<bool> _ask(String title, String body, String yes) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(yes),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Future<void> _reveal() async {
    final l = context.l10n;
    if (!await _ask(l.showPrivateKeyQ, l.showPrivateKeyWarning, l.show)) {
      return;
    }
    if (!mounted) return;
    setState(() => _working = true);
    try {
      final key = await ref
          .read(connectionProvider.notifier)
          .exportIdentityKey();
      if (mounted) {
        setState(
          () =>
              _key = [for (final b in key) b.toRadixString(16).padLeft(2, '0')]
                  .join(),
        );
      }
    } on Object catch (e) {
      if (mounted) _tell(_problem(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _replace() async {
    final key = parsePrivateKeyHex(_pasted.text);
    if (key == null) return;
    final l = context.l10n;
    if (!await _ask(l.replaceIdentityQ, l.replaceIdentityWarning, l.replace)) {
      return;
    }
    if (!mounted) return;
    setState(() => _working = true);
    try {
      await ref.read(connectionProvider.notifier).importIdentityKey(key);
      if (!mounted) return;
      _pasted.clear();
      setState(() => _key = null);
      _tell(l.identityReplaced);
    } on Object catch (e) {
      if (mounted) _tell(_problem(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final connected = ref.watch(connectionProvider) is Connected;
    final pasted = _pasted.text.trim();
    final valid = parsePrivateKeyHex(pasted) != null;
    final key = _key;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);
    return Scaffold(
      appBar: AppBar(title: Text(l.identityKey)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.identityKeyExplainer),
          const SizedBox(height: 16),
          if (!connected) ...[
            Text(l.keyBackupNotConnected),
            const SizedBox(height: 16),
          ],
          Text(l.backUp, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (key == null)
            FilledButton.icon(
              key: const ValueKey('key-reveal'),
              onPressed: connected && !_working ? _reveal : null,
              icon: const Icon(Icons.key),
              label: Text(l.showPrivateKey),
            )
          else ...[
            SelectableText(key, key: const ValueKey('key-hex'), style: mono),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: key));
                if (mounted) _tell(l.privateKeyCopied);
              },
              icon: const Icon(Icons.copy),
              label: Text(l.copyKey),
            ),
          ],
          const SizedBox(height: 24),
          Text(l.restore, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('key-paste'),
            controller: _pasted,
            minLines: 2,
            maxLines: 4,
            autocorrect: false,
            enableSuggestions: false,
            style: mono,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: l.pastePrivateKeyHint,
              errorText: pasted.isEmpty || valid ? null : l.privateKeyFormat,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            key: const ValueKey('key-replace'),
            onPressed: connected && valid && !_working ? _replace : null,
            icon: const Icon(Icons.restore),
            label: Text(l.replaceIdentity),
          ),
          const SizedBox(height: 24),
          Text(
            l.neverSharePrivateKey,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    );
  }
}
