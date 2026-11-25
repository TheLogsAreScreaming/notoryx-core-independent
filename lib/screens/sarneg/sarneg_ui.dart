// SARNEG screens shared by the NOTORYX apps: the code-word setup, the chat
// composer button and sheet, and the tap-to-decode line under a message.
// The codec and wire format live in sarneg.dart.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../app/no_screenshots.dart';
import 'sarneg.dart';
import 'secret_clipboard.dart';

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
  SarnegOptions _options = const SarnegOptions();
  bool _loaded = false;
  Future<void>? _loading;

  /// The code words; null when none are set.
  SarnegKeySet? get keys => _keys;

  /// Settings kept with the words on this phone.
  SarnegOptions get options => _options;

  /// Whether the saved words have been read.
  bool get loaded => _loaded;

  /// Reads the saved words (once).
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final raw = await _storage.read();
    SarnegKeySet? keys;
    var options = const SarnegOptions();
    if (raw != null) {
      try {
        final json = jsonDecode(raw);
        keys = SarnegKeySet.fromJson(json);
        if (json is Map) options = SarnegOptions.fromJson(json['options']);
      } on FormatException {
        keys = null;
      }
    }
    _keys = keys;
    _options = keys == null ? const SarnegOptions() : options;
    _loaded = true;
    await expire();
    notifyListeners();
  }

  /// Deletes dated words for past days, and every word once the wipe day
  /// has passed. Saves only when something changed.
  Future<void> expire() async {
    final k = _keys;
    if (k == null) return;
    final today = sarnegDay(clock());
    final wipe = _options.wipeAfter;
    if (wipe != null && today.compareTo(wipe) > 0) {
      await save(null);
      return;
    }
    final kept = k.withoutDaysBefore(today);
    if (kept.daily.length != k.daily.length) await save(kept);
  }

  Future<void> _write() => _storage.write(
    _keys == null
        ? null
        : jsonEncode({..._keys!.toJson(), 'options': _options.toJson()}),
  );

  /// Saves [keys] (null forgets them, with every option).
  Future<void> save(SarnegKeySet? keys) async {
    _keys = keys;
    if (keys == null) _options = const SarnegOptions();
    await _write();
    _loaded = true;
    notifyListeners();
  }

  /// Saves [options] next to the words.
  Future<void> saveOptions(SarnegOptions options) async {
    _options = options;
    await _write();
    notifyListeners();
  }

  /// Forgets every word and option and clears the clipboard now.
  Future<void> burn() async {
    _clipboardTimer?.cancel();
    try {
      await clearClipboard();
    } on Exception catch (e) {
      debugPrint('SARNEG: clipboard not cleared (${e.runtimeType})');
    }
    await save(null);
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

Timer? _clipboardTimer;

/// Copies [value] and shows [message]. After [kSarnegClipboardFor] the
/// clipboard is cleared, but only if it still holds [value].
Future<void> _copySecret(
  BuildContext context,
  String value,
  String message,
) async {
  final t = _t(context);
  await copySecretText(value);
  _clipboardTimer?.cancel();
  _clipboardTimer = Timer(
    kSarnegClipboardFor,
    () => unawaited(clearClipboardIfStill(value)),
  );
  if (context.mounted) _snack(context, '$message ${t.sarneg_clipboardClears}');
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
  Widget build(BuildContext context) =>
      NoScreenshots(child: Builder(builder: _buildScreen));

  // The screen itself; [build] keeps screenshots off around it.
  Widget _buildScreen(BuildContext context) => Scaffold(
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
    if (ok == true) await store.burn();
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
          const SizedBox(height: 16),
          const _Guide(),
        ] else ...[
          _WordCard(keys: k, today: today),
          if (isWellKnownSarnegWord(k.wordFor(today))) ...[
            const SizedBox(height: 8),
            _Warning(t.sarneg_wellKnownWord),
          ],
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
          _TryIt(codec: k.codecFor(today), options: store.options),
          const SizedBox(height: 24),
          _Options(store: store),
          const SizedBox(height: 16),
          _Sardot(store: store),
          const SizedBox(height: 24),
          _Auth(store: store),
          const SizedBox(height: 16),
          const _Guide(),
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
  Timer? _hide;

  void _toggle() {
    _hide?.cancel();
    setState(() => _shown = !_shown);
    if (_shown) {
      _hide = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _shown = false);
      });
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

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
                  onPressed: _toggle,
                ),
              ],
            ),
            Text(
              _shown ? word : '••••••••••',
              style: _mono.copyWith(fontSize: 24, letterSpacing: 4),
              semanticsLabel: _shown
                  ? word.split('').join(' ')
                  : t.sarneg_wordHidden,
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
  const _TryIt({required this.codec, required this.options});

  final SarnegCodec codec;

  /// How text is encoded.
  final SarnegOptions options;

  @override
  State<_TryIt> createState() => _TryItState();
}

class _TryItState extends State<_TryIt> {
  final _plain = TextEditingController();
  final _coded = TextEditingController();
  Timer? _idle;

  /// Restarts the countdown that clears both fields.
  void _touched() {
    _idle?.cancel();
    setState(() {});
    if (_plain.text.isEmpty && _coded.text.isEmpty) return;
    _idle = Timer(kSarnegShowFor, () {
      if (!mounted) return;
      _plain.clear();
      _coded.clear();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
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
              : () => _copySecret(context, value, t.sarneg_copied),
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
        Text(t.sarneg_autoClear, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        TextField(
          controller: _plain,
          decoration: InputDecoration(
            labelText: t.sarneg_numbersToEncode,
            hintText: '17S 4823',
          ),
          onChanged: (_) => _touched(),
        ),
        _result(
          context,
          _plain.text.trim().isEmpty
              ? ''
              : c.encodeMessage(
                  _plain.text,
                  keepZone: widget.options.keepZone,
                  marker: !widget.options.noMarker,
                ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _coded,
          decoration: InputDecoration(
            labelText: t.sarneg_lettersToDecode,
            hintText: 'LRs KSAC',
          ),
          onChanged: (_) => _touched(),
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
  bool _wellKnown = false;

  void _random() {
    final w = randomSarnegWord();
    _text.value = TextEditingValue(
      text: w,
      selection: TextSelection.collapsed(offset: w.length),
    );
    setState(() {
      _error = null;
      _wellKnown = false;
    });
  }

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
        decoration: InputDecoration(
          hintText: 'BLACKHORSE',
          errorText: _error,
          helperText: _wellKnown ? t.sarneg_wellKnownWord : null,
          helperMaxLines: 4,
        ),
        onChanged: (v) => setState(() {
          _error = null;
          _wellKnown = isWellKnownSarnegWord(v);
        }),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(onPressed: _random, child: Text(t.sarneg_randomWord)),
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
          onPressed: () => _copySecret(context, text, t.sarneg_copiedPrivate),
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
  Widget build(BuildContext context) =>
      NoScreenshots(child: Builder(builder: _buildScreen));

  // The screen itself; [build] keeps screenshots off around it.
  Widget _buildScreen(BuildContext context) {
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

  Future<void> _sardot(SarnegOptions o) async {
    final t = _t(context);
    setState(() => _locating = true);
    try {
      final p = await sarnegPositionSource();
      if (!mounted) return;
      if (p == null) {
        _snack(context, t.sarneg_locationOff);
        return;
      }
      final dot = sardotFrom((o.sardotLat!, o.sardotLon!), p);
      final text = sardotText(dot.$1, dot.$2);
      final s = _text.text.trim();
      _text.text = s.isEmpty ? text : '$s $text';
    } on TimeoutException {
      if (mounted) _snack(context, t.sarneg_noFix);
    } catch (_) {
      if (mounted) _snack(context, t.sarneg_noFix);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      NoScreenshots(child: Builder(builder: _buildScreen));

  // The screen itself; [build] keeps screenshots off around it.
  Widget _buildScreen(BuildContext context) => _keysBuilder((context, store) {
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
    final o = store.options;
    final coded = plain.isEmpty
        ? ''
        : codec.encodeMessage(plain, keepZone: o.keepZone, marker: !o.noMarker);
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
            if (o.hasSardot)
              TextButton.icon(
                onPressed: _locating ? null : () => _sardot(o),
                icon: const Icon(Icons.explore_outlined),
                label: Text(t.sarneg_addSardot),
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
              initial:
                  isSarnegMessage(current) ||
                      (SarnegKeys.instance.codecFor()?.mayBeUnmarked(current) ??
                          false)
                  ? ''
                  : current,
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
  Timer? _close;

  void _toggle() {
    _close?.cancel();
    setState(() => _open = !_open);
    if (_open) {
      _close = Timer(kSarnegShowFor, () {
        if (mounted) setState(() => _open = false);
      });
    }
  }

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Decoded numbers on screen: no screenshots until it closes again.
    final child = _buildScreen(context);
    return _open ? NoScreenshots(child: child) : child;
  }

  // The screen itself; [build] keeps screenshots off around it.
  Widget _buildScreen(BuildContext context) => _keysBuilder((context, store) {
    final marked = isSarnegMessage(widget.text);
    final codec = store.keys?.codecFor(widget.at);
    final unmarked =
        !marked &&
        store.options.readUnmarked &&
        (codec?.mayBeUnmarked(widget.text) ?? false);
    if (!marked && !unmarked) return const SizedBox.shrink();
    final t = _t(context);
    final o = store.options;
    final decoded = codec?.decodeAny(widget.text);
    final at = decoded == null
        ? null
        : sarnegPositionIn(
            decoded,
            reference: o.hasSardot ? (o.sardotLat!, o.sardotLon!) : null,
          );
    final label = !_open
        ? (marked ? t.sarneg_tapToDecode : t.sarneg_maybeUnmarked)
        : decoded == null
        ? t.sarneg_noWordSet
        : t.sarneg_decoded(decoded);
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Semantics(
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
                _toggle();
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
                          fontFamily: _open && decoded != null
                              ? 'monospace'
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_open && at != null)
          IconButton(
            tooltip: t.sarneg_showOnMap,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.map_outlined, size: 20, color: color),
            onPressed: () => showSarnegMap(context, at),
          ),
      ],
    );
  });
}

/// Package name sent with map tile requests.
const String _tileAgent = 'com.bastionmesh.notoryx_core';

/// Shows [point] on a small map, with its coordinates and a copy button.
Future<void> showSarnegMap(BuildContext context, (double, double) point) {
  final t = _t(context);
  final text = '${point.$1.toStringAsFixed(5)}, ${point.$2.toStringAsFixed(5)}';
  final at = LatLng(point.$1, point.$2);
  return showDialog<void>(
    context: context,
    builder: (d) => NoScreenshots(
      child: AlertDialog(
        title: Text(t.sarneg_mapTitle),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    options: MapOptions(initialCenter: at, initialZoom: 14),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: _tileAgent,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: at,
                            width: 40,
                            height: 40,
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Theme.of(d).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(text, style: _mono),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copySecret(d, text, t.sarneg_copied),
            child: Text(t.sarneg_copy),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(t.sarneg_done),
          ),
        ],
      ),
    ),
  );
}

/// Asks for one value; [check] returns an error text or null when it's fine.
class _AskDialog extends StatefulWidget {
  const _AskDialog({
    required this.title,
    required this.label,
    required this.check,
    this.number = false,
  });

  final String title;
  final String label;
  final String? Function(String) check;
  final bool number;

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() {
    final v = _text.text.trim();
    final e = widget.check(v);
    if (e != null) {
      setState(() => _error = e);
      return;
    }
    Navigator.pop(context, v);
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
        keyboardType: widget.number
            ? const TextInputType.numberWithOptions(signed: true, decimal: true)
            : TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(labelText: widget.label, errorText: _error),
        onChanged: (_) => setState(() => _error = null),
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

Future<String?> _ask(
  BuildContext context, {
  required String title,
  required String label,
  required String? Function(String) check,
  bool number = false,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _AskDialog(title: title, label: label, check: check, number: number),
);

Widget _heading(BuildContext context, String text) =>
    Text(text, style: Theme.of(context).textTheme.titleMedium);

/// How messages are written and read, and when words are deleted.
class _Options extends StatelessWidget {
  const _Options({required this.store});

  final SarnegKeys store;

  Future<void> _pickWipe(BuildContext context) async {
    final now = store.clock();
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 366)),
      helpText: _t(context).sarneg_wipeAfter,
    );
    if (day == null) return;
    await store.saveOptions(store.options.copyWith(wipeAfter: sarnegDay(day)));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final o = store.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, t.sarneg_optionsTitle),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.sarneg_keepZone),
          subtitle: Text(t.sarneg_keepZoneHint),
          value: o.keepZone,
          onChanged: (v) => store.saveOptions(o.copyWith(keepZone: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.sarneg_noMarker),
          subtitle: Text(t.sarneg_noMarkerHint),
          value: o.noMarker,
          onChanged: (v) => store.saveOptions(o.copyWith(noMarker: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.sarneg_readUnmarked),
          subtitle: Text(t.sarneg_readUnmarkedHint),
          value: o.readUnmarked,
          onChanged: (v) => store.saveOptions(o.copyWith(readUnmarked: v)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_delete_outlined),
          title: Text(t.sarneg_wipeAfter),
          subtitle: Text(
            o.wipeAfter == null
                ? t.sarneg_wipeAfterOff
                : t.sarneg_wipeAfterSet(o.wipeAfter!),
          ),
          onTap: () => _pickWipe(context),
          trailing: o.wipeAfter == null
              ? null
              : IconButton(
                  tooltip: t.sarneg_remove,
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      store.saveOptions(o.copyWith(clearWipe: true)),
                ),
        ),
      ],
    );
  }
}

String? _pointError(BuildContext context, String v) =>
    parseSarnegPoint(v) == null ? _t(context).sarneg_pointInvalid : null;

/// The secret SARDOT reference point.
class _Sardot extends StatefulWidget {
  const _Sardot({required this.store});

  final SarnegKeys store;

  @override
  State<_Sardot> createState() => _SardotState();
}

class _SardotState extends State<_Sardot> {
  bool _locating = false;

  Future<void> _here() async {
    final t = _t(context);
    final store = widget.store;
    setState(() => _locating = true);
    try {
      final p = await sarnegPositionSource();
      if (!mounted) return;
      if (p == null) {
        _snack(context, t.sarneg_locationOff);
        return;
      }
      await store.saveOptions(
        store.options.copyWith(sardotLat: p.$1, sardotLon: p.$2),
      );
    } catch (_) {
      if (mounted) _snack(context, t.sarneg_noFix);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _type() async {
    final t = _t(context);
    final v = await _ask(
      context,
      title: t.sarneg_sardotTitle,
      label: t.sarneg_pointLabel,
      number: true,
      check: (v) => _pointError(context, v),
    );
    final p = v == null ? null : parseSarnegPoint(v);
    if (p == null) return;
    final store = widget.store;
    await store.saveOptions(
      store.options.copyWith(sardotLat: p.$1, sardotLon: p.$2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final store = widget.store;
    final o = store.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, t.sarneg_sardotTitle),
        const SizedBox(height: 4),
        Text(t.sarneg_sardotHint),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(o.hasSardot ? Icons.place : Icons.place_outlined, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                o.hasSardot ? t.sarneg_sardotSet : t.sarneg_sardotNone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _locating ? null : _here,
              icon: const Icon(Icons.my_location),
              label: Text(t.sarneg_useMyPosition),
            ),
            OutlinedButton.icon(
              onPressed: _type,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: Text(t.sarneg_typePoint),
            ),
            if (o.hasSardot)
              TextButton.icon(
                onPressed: () =>
                    store.saveOptions(o.copyWith(clearSardot: true)),
                icon: const Icon(Icons.close),
                label: Text(t.sarneg_remove),
              ),
          ],
        ),
      ],
    );
  }
}

/// Number and letter of the day, with the reply to a challenge.
class _Auth extends StatefulWidget {
  const _Auth({required this.store});

  final SarnegKeys store;

  @override
  State<_Auth> createState() => _AuthState();
}

class _AuthState extends State<_Auth> {
  final _challenge = TextEditingController();
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    _challenge.dispose();
    super.dispose();
  }

  void _touched() {
    _idle?.cancel();
    setState(() {});
    _idle = Timer(kSarnegShowFor, () {
      if (!mounted) return;
      _challenge.clear();
      setState(() {});
    });
  }

  Future<void> _setNumber() async {
    final t = _t(context);
    final v = await _ask(
      context,
      title: t.sarneg_numberOfDay,
      label: t.sarneg_numberOfDay,
      number: true,
      check: (v) {
        final n = int.tryParse(v);
        return n == null || n < 0 || n > 99 ? t.sarneg_numberInvalid : null;
      },
    );
    if (v == null) return;
    final store = widget.store;
    await store.saveOptions(store.options.copyWith(numberOfDay: int.parse(v)));
  }

  Future<void> _setLetter() async {
    final t = _t(context);
    final v = await _ask(
      context,
      title: t.sarneg_letterOfDay,
      label: t.sarneg_letterOfDay,
      check: (v) =>
          RegExp(r'^[A-Za-z]$').hasMatch(v) ? null : t.sarneg_letterInvalid,
    );
    if (v == null) return;
    final store = widget.store;
    await store.saveOptions(
      store.options.copyWith(letterOfDay: v.toUpperCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    final o = widget.store.options;
    final nod = o.numberOfDay;
    final asked = int.tryParse(_challenge.text.trim());
    final reply = nod == null || asked == null ? null : sarnegReply(nod, asked);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(context, t.sarneg_authTitle),
        const SizedBox(height: 4),
        Text(t.sarneg_authHint),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tag),
          title: Text(t.sarneg_numberOfDay),
          subtitle: Text(nod == null ? t.sarneg_notSet : '$nod', style: _mono),
          onTap: _setNumber,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.abc),
          title: Text(t.sarneg_letterOfDay),
          subtitle: Text(o.letterOfDay ?? t.sarneg_notSet, style: _mono),
          onTap: _setLetter,
        ),
        if (nod != null) ...[
          TextField(
            controller: _challenge,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: t.sarneg_challenge),
            onChanged: (_) => _touched(),
          ),
          const SizedBox(height: 4),
          if (asked != null)
            Text(
              reply == null ? t.sarneg_noReply : t.sarneg_reply(reply),
              style: reply == null ? null : _mono,
            ),
        ],
        if (nod != null || o.letterOfDay != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                _challenge.clear();
                unawaited(
                  widget.store.saveOptions(o.copyWith(clearAuth: true)),
                );
              },
              icon: const Icon(Icons.close),
              label: Text(t.sarneg_remove),
            ),
          ),
      ],
    );
  }
}

/// What SARNEG does and doesn't protect, next to real encryption.
class _Guide extends StatelessWidget {
  const _Guide();

  @override
  Widget build(BuildContext context) {
    final t = _t(context);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: const Icon(Icons.shield_outlined),
      title: Text(t.sarneg_guideTitle),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(t.sarneg_guideBody)],
    );
  }
}
