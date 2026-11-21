// SARNEG screens shared by the NOTORYX apps: the code-word setup, the chat
// composer button and sheet, and the tap-to-decode line under a message.
// The codec and wire format live in sarneg.dart.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import 'sarneg.dart';

AppLocalizations _t(BuildContext context) => context.l10n;

const TextStyle _mono = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: [FontFeature.tabularFigures()],
);

/// Where the code words are saved.
abstract interface class SarnegStorage {
  /// The saved JSON, or null.
  Future<String?> read();

  /// Saves [json]; null forgets it.
  Future<void> write(String? json);
}

/// [SarnegStorage] in memory (tests).
class MemorySarnegStorage implements SarnegStorage {
  /// Starts with [value].
  MemorySarnegStorage([this.value]);

  /// What is saved.
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? json) async => value = json;
}

/// [SarnegStorage] in the Android Keystore / Apple Keychain.
class SecureSarnegStorage implements SarnegStorage {
  /// Creates the storage.
  const SecureSarnegStorage();

  static const _storage = FlutterSecureStorage();
  static const _key = 'sarneg_keys';

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String? json) async {
    if (json == null) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: json);
    }
  }
}

/// The team's code words on this phone. Load once with [ensureLoaded].
class SarnegKeys extends ChangeNotifier {
  /// Uses [storage] and [clock] (tests pass their own).
  SarnegKeys({SarnegStorage? storage, DateTime Function()? clock})
    : _storage = storage ?? const SecureSarnegStorage(),
      clock = clock ?? DateTime.now;

  /// The one the app uses.
  static SarnegKeys instance = SarnegKeys();

  final SarnegStorage _storage;

  /// Picks the day's word.
  final DateTime Function() clock;

  SarnegKeySet? _keys;
  bool _loaded = false;
  Future<void>? _loading;

  /// The code words; null when none are set.
  SarnegKeySet? get keys => _keys;

  /// Whether the saved words have been read.
  bool get loaded => _loaded;

  /// Reads the saved words (once).
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final raw = await _storage.read();
    SarnegKeySet? keys;
    if (raw != null) {
      try {
        keys = SarnegKeySet.fromJson(jsonDecode(raw));
      } on FormatException {
        keys = null;
      }
    }
    _keys = keys?.withoutDaysBefore(sarnegDay(clock()));
    _loaded = true;
    notifyListeners();
  }

  /// Saves [keys] (null forgets them).
  Future<void> save(SarnegKeySet? keys) async {
    await _storage.write(keys == null ? null : jsonEncode(keys.toJson()));
    _keys = keys;
    _loaded = true;
    notifyListeners();
  }

  /// The codec for [at] (today when null), or null when no word is set.
  SarnegCodec? codecFor([DateTime? at]) => _keys?.codecFor(at ?? clock());
}

String _problemText(BuildContext context, SarnegWordProblem p) {
  final t = _t(context);
  return switch (p) {
    SarnegWordProblem.length => t.sarneg_problemLength,
    SarnegWordProblem.letters => t.sarneg_problemLetters,
    SarnegWordProblem.repeats => t.sarneg_problemRepeats,
  };
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Widget _keysBuilder(Widget Function(BuildContext, SarnegKeys) builder) {
  final keys = SarnegKeys.instance;
  unawaited(keys.ensureLoaded());
  return ListenableBuilder(
    listenable: keys,
    builder: (context, _) => builder(context, keys),
  );
}

/// Sets the team's SARNEG code words, shares them, and encodes or decodes by
/// hand.
class SarnegScreen extends StatelessWidget {
  /// Creates the screen.
  const SarnegScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_t(context).sarneg_title)),
    body: _keysBuilder(
      (context, store) => !store.loaded
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _Body(store: store),
              ),
            ),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.store});

  final SarnegKeys store;

  Future<void> _setWord(BuildContext context) async {
    final t = _t(context);
    final k = store.keys;
    final word = await showDialog<String>(
      context: context,
      builder: (_) => _WordDialog(
        title: k == null ? t.sarneg_setTitle : t.sarneg_changeTitle,
      ),
    );
    if (word == null) return;
    await store.save(SarnegKeySet(word: word, daily: k?.daily ?? const {}));
  }

  Future<void> _addDay(BuildContext context, SarnegKeySet k) async {
    final t = _t(context);
    final now = store.clock();
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 366)),
      helpText: t.sarneg_dayPickerHelp,
    );
    if (day == null || !context.mounted) return;
    final key = sarnegDay(day);
    if (k.daily.length >= kSarnegMaxDailyWords && !k.daily.containsKey(key)) {
      _snack(context, t.sarneg_maxDated(kSarnegMaxDailyWords));
      return;
    }
    final word = await showDialog<String>(
      context: context,
      builder: (_) => _WordDialog(title: t.sarneg_wordForDay(key)),
    );
    if (word == null) return;
    await store.save(k.withDay(key, word));
  }

  Future<void> _import(BuildContext context) async {
    final t = _t(context);
    final keys = await Navigator.push<SarnegKeySet>(
      context,
      MaterialPageRoute(builder: (_) => const SarnegImportScreen()),
    );
    if (keys == null) return;
    await store.save(keys);
    if (context.mounted) _snack(context, t.sarneg_saved);
  }

  Future<void> _forget(BuildContext context) async {
    final t = _t(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t.sarneg_forgetTitle),
        content: Text(t.sarneg_forgetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(t.sarneg_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(t.sarneg_forget),
          ),
        ],
      ),
    );
    if (ok == true) await store.save(null);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final k = store.keys;
    final today = store.clock();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(t.sarneg_intro),
        const SizedBox(height: 8),
        _Warning(t.sarneg_notEncryption),
        const SizedBox(height: 16),
        if (k == null) ...[
          Text(t.sarneg_noWord),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _setWord(context),
                icon: const Icon(Icons.edit),
                label: Text(t.sarneg_typeWord),
              ),
              OutlinedButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(t.sarneg_scanOrPaste),
              ),
            ],
          ),
        ] else ...[
          _WordCard(keys: k, today: today),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _setWord(context),
                icon: const Icon(Icons.edit),
                label: Text(t.sarneg_change),
              ),
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ShareDialog(keys: k),
                ),
                icon: const Icon(Icons.qr_code_2),
                label: Text(t.sarneg_share),
              ),
              OutlinedButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(t.sarneg_scanOrPaste),
              ),
              TextButton.icon(
                onPressed: () => _forget(context),
                icon: const Icon(Icons.delete_outline),
                label: Text(t.sarneg_forget),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            t.sarneg_datedTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(t.sarneg_datedHint),
          for (final e in k.daily.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(e.key),
              subtitle: Text(e.value, style: _mono),
              trailing: IconButton(
                tooltip: t.sarneg_removeDay(e.key),
                icon: const Icon(Icons.close),
                onPressed: () => store.save(k.withDay(e.key, null)),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _addDay(context, k),
              icon: const Icon(Icons.add),
              label: Text(t.sarneg_addDay),
            ),
          ),
          const SizedBox(height: 16),
          _TryIt(codec: k.codecFor(today)),
        ],
      ],
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Today's word, hidden until asked for.
class _WordCard extends StatefulWidget {
  const _WordCard({required this.keys, required this.today});

  final SarnegKeySet keys;
  final DateTime today;

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final word = widget.keys.wordFor(widget.today);
    final dated = widget.keys.daily.containsKey(sarnegDay(widget.today));
    final digits = [for (var i = 0; i < 10; i++) '${word[i]}=$i'].join('  ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dated ? t.sarneg_todayWordDated : t.sarneg_todayWord,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: _shown ? t.sarneg_hide : t.sarneg_show,
                  icon: Icon(_shown ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _shown = !_shown),
                ),
              ],
            ),
            Text(
              _shown ? word : '••••••••••',
              style: _mono.copyWith(fontSize: 24, letterSpacing: 4),
              semanticsLabel: _shown ? word.split('').join(' ') : t.sarneg_hide,
            ),
            if (_shown) ...[
              const SizedBox(height: 6),
              Text(digits, style: _mono),
            ],
          ],
        ),
      ),
    );
  }
}

/// Encode and decode by hand with today's word.
class _TryIt extends StatefulWidget {
  const _TryIt({required this.codec});

  final SarnegCodec codec;

  @override
  State<_TryIt> createState() => _TryItState();
}

class _TryItState extends State<_TryIt> {
  final _plain = TextEditingController();
  final _coded = TextEditingController();

  @override
  void dispose() {
    _plain.dispose();
    _coded.dispose();
    super.dispose();
  }

  Widget _result(BuildContext context, String value) {
    final t = _t(context);
    return Row(
      children: [
        Expanded(
          child: SelectableText(value.isEmpty ? '–' : value, style: _mono),
        ),
        IconButton(
          tooltip: t.sarneg_copy,
          icon: const Icon(Icons.copy),
          onPressed: value.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted) _snack(context, t.sarneg_copied);
                },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final c = widget.codec;
    final body = sarnegBody(_coded.text) ?? _coded.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.sarneg_tryTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _plain,
          decoration: InputDecoration(
            labelText: t.sarneg_numbersToEncode,
            hintText: '17S 4823',
          ),
          onChanged: (_) => setState(() {}),
        ),
        _result(
          context,
          _plain.text.trim().isEmpty ? '' : c.encodeMessage(_plain.text),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _coded,
          decoration: InputDecoration(
            labelText: t.sarneg_lettersToDecode,
            hintText: 'LRs KSAC',
          ),
          onChanged: (_) => setState(() {}),
        ),
        _result(context, body.trim().isEmpty ? '' : c.decode(body)),
      ],
    );
  }
}

/// Types and checks one code word.
class _WordDialog extends StatefulWidget {
  const _WordDialog({required this.title});

  final String title;

  @override
  State<_WordDialog> createState() => _WordDialogState();
}

class _WordDialogState extends State<_WordDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() {
    final w = normalizeSarnegWord(_text.text);
    final p = checkSarnegWord(w);
    if (p != null) {
      setState(() => _error = _problemText(context, p));
      return;
    }
    Navigator.pop(context, w);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.characters,
        maxLength: 12,
        style: _mono,
        decoration: InputDecoration(hintText: 'BLACKHORSE', errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.sarneg_cancel),
        ),
        TextButton(onPressed: _done, child: Text(t.sarneg_save)),
      ],
    );
  }
}

/// The code words as a QR code and as text.
class _ShareDialog extends StatelessWidget {
  const _ShareDialog({required this.keys});

  final SarnegKeySet keys;

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final text = keys.toShareText();
    return AlertDialog(
      title: Text(t.sarneg_shareTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.sarneg_shareBody),
            const SizedBox(height: 12),
            SizedBox(
              width: 220,
              height: 220,
              child: QrImageView(
                data: text,
                size: 220,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
                semanticsLabel: t.sarneg_shareTitle,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) _snack(context, t.sarneg_copiedPrivate);
          },
          child: Text(t.sarneg_copyText),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.sarneg_done),
        ),
      ],
    );
  }
}

bool get _canScan =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Scans or pastes a shared code word; pops with the code words.
class SarnegImportScreen extends StatefulWidget {
  /// Creates the screen.
  const SarnegImportScreen({super.key});

  @override
  State<SarnegImportScreen> createState() => _SarnegImportScreenState();
}

class _SarnegImportScreenState extends State<SarnegImportScreen> {
  final _paste = TextEditingController();
  bool _scanning = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _use(String text) {
    if (_done) return;
    try {
      final keys = SarnegKeySet.parseShareText(text);
      _done = true;
      Navigator.pop(context, keys);
    } on FormatException {
      setState(() => _error = _t(context).sarneg_badShare);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.sarneg_importTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_scanning)
            SizedBox(
              height: 320,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  onDetect: (capture) {
                    for (final b in capture.barcodes) {
                      final raw = b.rawValue ?? '';
                      if (raw.trim().toUpperCase().startsWith(
                        kSarnegSharePrefix,
                      )) {
                        setState(() => _scanning = false);
                        _use(raw);
                        return;
                      }
                    }
                  },
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(t.sarneg_cameraOff),
                    ),
                  ),
                ),
              ),
            )
          else if (_canScan)
            FilledButton.icon(
              onPressed: () => setState(() => _scanning = true),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(t.sarneg_scanQr),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _paste,
            autocorrect: false,
            enableSuggestions: false,
            minLines: 1,
            maxLines: 4,
            style: _mono,
            decoration: InputDecoration(
              labelText: t.sarneg_pasteLabel,
              hintText: 'SARNEG1:BLACKHORSE',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: () => _use(_paste.text),
              child: Text(t.sarneg_useWord),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where "Add my position" gets a fix; tests replace it.
Future<(double, double)?> Function() sarnegPositionSource = _phonePosition;

Future<(double, double)?> _phonePosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p != LocationPermission.whileInUse && p != LocationPermission.always) {
    return null;
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(timeLimit: Duration(seconds: 20)),
  );
  return (pos.latitude, pos.longitude);
}

/// Asks for the numbers to send, encodes them with today's word, and returns
/// the whole message ([kSarnegMarker] and the code letters), or null.
Future<String?> showSarnegComposeSheet(
  BuildContext context, {
  String initial = '',
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ComposeSheet(initial: initial),
);

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.initial});

  final String initial;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  bool _locating = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _myPosition() async {
    final t = _t(context);
    setState(() => _locating = true);
    try {
      final p = await sarnegPositionSource();
      if (!mounted) return;
      if (p == null) {
        _snack(context, t.sarneg_locationOff);
        return;
      }
      final pos = '${p.$1.toStringAsFixed(5)}, ${p.$2.toStringAsFixed(5)}';
      final s = _text.text.trim();
      _text.text = s.isEmpty ? pos : '$s $pos';
    } on TimeoutException {
      if (mounted) _snack(context, t.sarneg_noFix);
    } catch (_) {
      if (mounted) _snack(context, t.sarneg_noFix);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => _keysBuilder((context, store) {
    final t = _t(context);
    final keys = store.keys;
    final pad = EdgeInsets.fromLTRB(
      16,
      0,
      16,
      16 + MediaQuery.viewInsetsOf(context).bottom,
    );
    if (keys == null) {
      return SafeArea(
        child: Padding(
          padding: pad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SARNEG', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(store.loaded ? t.sarneg_needWord : ''),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  unawaited(
                    nav.push<void>(
                      MaterialPageRoute(builder: (_) => const SarnegScreen()),
                    ),
                  );
                },
                child: Text(t.sarneg_setTitle),
              ),
            ],
          ),
        ),
      );
    }
    final codec = keys.codecFor(store.clock());
    final plain = _text.text.trim();
    final coded = plain.isEmpty ? '' : codec.encodeMessage(plain);
    return SafeArea(
      child: Padding(
        padding: pad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.sarneg_composeTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(t.sarneg_composeHint),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: widget.initial.isEmpty,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t.sarneg_numbersToSend,
                hintText: '17S 4823',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _locating ? null : _myPosition,
              icon: _locating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(t.sarneg_addPosition),
            ),
            const SizedBox(height: 4),
            Text(
              t.sarneg_goesOutAs,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(coded.isEmpty ? '–' : coded, style: _mono),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: coded.isEmpty
                    ? null
                    : () => Navigator.pop(context, coded),
                child: Text(t.sarneg_putInMessage),
              ),
            ),
          ],
        ),
      ),
    );
  });
}

/// The composer's SARNEG button: encodes the typed numbers (or new ones) and
/// puts the coded message in [controller].
class SarnegComposeButton extends StatelessWidget {
  /// Creates the button for [controller].
  const SarnegComposeButton({
    required this.controller,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  /// The composer's text.
  final TextEditingController controller;

  /// False while the composer is disabled.
  final bool enabled;

  /// Called after the coded message is put in [controller] (to save a draft).
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _t(context).sarneg_composeTooltip,
    icon: const Icon(Icons.pin_outlined),
    onPressed: !enabled
        ? null
        : () async {
            final current = controller.text.trim();
            final coded = await showSarnegComposeSheet(
              context,
              initial: isSarnegMessage(current) ? '' : current,
            );
            if (coded == null) return;
            controller.text = coded;
            controller.selection = TextSelection.collapsed(
              offset: coded.length,
            );
            onChanged?.call();
          },
  );
}

/// Under a SARNEG message: tap to show its numbers, decoded with the word for
/// the day it was sent or received. Shows nothing for other messages.
class SarnegDecodeLine extends StatefulWidget {
  /// Creates the line for [text], sent or received at [at].
  const SarnegDecodeLine({
    required this.text,
    required this.at,
    this.color,
    super.key,
  });

  /// The whole message, marker included.
  final String text;

  /// When it was sent or received.
  final DateTime at;

  /// Text and icon colour (default: the theme's primary).
  final Color? color;

  @override
  State<SarnegDecodeLine> createState() => _SarnegDecodeLineState();
}

class _SarnegDecodeLineState extends State<SarnegDecodeLine> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!isSarnegMessage(widget.text)) return const SizedBox.shrink();
    return _keysBuilder((context, store) {
      final t = _t(context);
      final decoded = store.keys
          ?.codecFor(widget.at)
          .decodeMessage(widget.text);
      final label = !_open
          ? t.sarneg_tapToDecode
          : decoded == null
          ? t.sarneg_noWordSet
          : t.sarneg_decoded(decoded);
      final color = widget.color ?? Theme.of(context).colorScheme.primary;
      return Semantics(
        button: true,
        label: _open ? label : t.sarneg_decodeA11y,
        excludeSemantics: true,
        child: InkWell(
          onTap: () {
            if (_open && decoded == null) {
              unawaited(
                Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const SarnegScreen()),
                ),
              );
              return;
            }
            setState(() => _open = !_open);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _open ? Icons.lock_open : Icons.pin_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontFamily: _open && decoded != null ? 'monospace' : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
