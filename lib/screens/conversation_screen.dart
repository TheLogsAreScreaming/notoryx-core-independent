import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/blocking.dart';
import '../app/chat_send.dart';
import '../app/post_signing.dart';
import '../app/safety.dart';
import '../app/scheduled_messages.dart';
import '../app/region_tag.dart';
import '../radio/protocol/region_scope.dart';
import '../app/spam_filter.dart';
import '../app/appearance.dart';
import '../app/connection.dart';
import '../app/delivery.dart';
import '../app/notifications.dart';
import '../app/link_preview.dart';
import '../app/mesh_links.dart';
import '../app/position.dart';
import '../app/read_aloud.dart';
import '../app/reactions.dart';
import '../app/translate.dart';
import '../app/shared_items.dart';
import '../data/data.dart';
import '../radio/protocol/mesh_photo.dart';
import '../radio/radio.dart';
import 'manage_actions.dart';
import 'position_map_screen.dart';
import 'quick_messages_screen.dart';
import 'scheduled_screen.dart';
import '../l10n/l10n.dart';
import 'link_preview_card.dart';
import 'mesh_photo_view.dart';

/// One direct or channel conversation with a box to reply.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    required this.thread,
    required this.title,
    this.isChannel = false,
    super.key,
  });

  final String thread;
  final String title;
  final bool isChannel;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  bool _sending = false;
  late final OpenThread _openThread;
  late final MeshStore _store;

  /// The radio the draft in the box belongs to, once it has been loaded.
  String? _draftRadio;
  Timer? _draftSave;

  /// Newest message id already marked read.
  int? _readUpTo;

  /// The message being replied to, and who sent it.
  ({Message message, String name})? _replyTo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openThread = ref.read(openThreadProvider.notifier);
    _store = ref.read(storeProvider);
    _text.addListener(_draftChanged);
    unawaited(_loadDraft());
    // After this frame: providers can't change while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openThread.open(widget.thread);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Providers can't change while the tree is being torn down.
    final openThread = _openThread, thread = widget.thread;
    Future(() => openThread.close(thread));
    _flushDraft();
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Messages that arrived while the app was in the background are read
    // once it's back in front with this chat open.
    if (state == AppLifecycleState.resumed) _markRead();
  }

  Future<void> _loadDraft() async {
    final radioKey = ref.read(radioKeyProvider);
    if (radioKey == null) return;
    final draft = await _store.draft(radioKey, widget.thread);
    if (!mounted) return;
    _draftRadio = radioKey;
    if (draft != null && _text.text.isEmpty) {
      _text.value = TextEditingValue(
        text: draft,
        selection: TextSelection.collapsed(offset: draft.length),
      );
    }
  }

  /// Saves what's in the box shortly after typing stops.
  void _draftChanged() {
    if (_draftRadio == null) return;
    _draftSave?.cancel();
    _draftSave = Timer(const Duration(milliseconds: 600), _flushDraft);
  }

  void _flushDraft() {
    _draftSave?.cancel();
    _draftSave = null;
    final radioKey = _draftRadio;
    if (radioKey == null) return;
    unawaited(_store.saveDraft(radioKey, widget.thread, _text.text));
  }

  /// Puts [text] in the box, after anything already typed, to check
  /// before sending.
  void _insert(String text) {
    final current = _text.text.trimRight();
    final next = current.isEmpty ? text : '$current $text';
    _text.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _share(List<Contact> contacts) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text(context.l10n.myPosition),
              subtitle: Text(context.l10n.fromThePhoneOrElseThe),
              onTap: () => Navigator.pop(context, 'position'),
            ),
            if (widget.isChannel)
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: Text(context.l10n.photo),
                subtitle: Text(context.l10n.photoSubtitle),
                onTap: () => Navigator.pop(context, 'photo'),
              ),
            ListTile(
              leading: const Icon(Icons.contact_page_outlined),
              title: Text(context.l10n.aContact),
              subtitle: Text(context.l10n.theyCanAddItInOne),
              onTap: () => Navigator.pop(context, 'contact'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (choice == 'photo') {
      await _sendPhoto();
      return;
    }
    if (choice == 'position') {
      LatLng? here;
      try {
        here = await ref
            .read(phonePositionProvider)()
            .timeout(const Duration(seconds: 15));
      } on Object {
        here = null;
      }
      final state = ref.read(connectionProvider);
      if (here == null && state is Connected) {
        final self = state.radio.self;
        if (self.latitude case final lat? when self.longitude != null) {
          here = LatLng(lat, self.longitude!);
        }
      }
      if (!mounted) return;
      if (here == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.noPositionTurnOnLocationOr)),
        );
        return;
      }
      _insert(positionText(here));
      return;
    }
    final picked = await showDialog<Contact>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.shareAContact),
        children: [
          if (contacts.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(context.l10n.noContactsOnThisRadioYet),
            ),
          for (final c in contacts)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Text(c.name),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    _insert(
      ContactLink(
        name: picked.name,
        publicKey: PublicKey.fromHex(picked.publicKey),
        type: NodeType.fromByte(picked.type),
      ).url,
    );
  }

  Future<void> _pickQuick() async {
    final pick = await showQuickMessagePicker(context);
    if (pick == null || !mounted) return;
    if (pick.edit) {
      _text.value = TextEditingValue(
        text: pick.text,
        selection: TextSelection.collapsed(offset: pick.text.length),
      );
    } else {
      await _send(pick.text);
    }
  }

  void _markRead() {
    final radioKey = ref.read(radioKeyProvider);
    if (radioKey == null || !ref.read(foregroundCheckProvider)()) return;
    ref.read(storeProvider).markRead(radioKey, widget.thread);
  }

  /// Sends what's in the box (as a reply, when one is chosen), or [quick]
  /// as it is, leaving the box alone.
  Future<void> _send([String? quick]) async {
    final typed = quick == null;
    final typedText = (quick ?? _text.text).trim();
    final state = ref.read(connectionProvider);
    if (typedText.isEmpty || state is! Connected || _sending) return;
    final replyTo = typed ? _replyTo : null;
    final text = replyTo == null
        ? typedText
        : replyText(replyTo.name, typedText);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _sending = true);
    try {
      final target = widget.thread.substring(2);
      if (widget.isChannel) {
        final tag = await ref.read(storeProvider).setting(regionSendSetting);
        await state.sync.sendChannel(
          int.parse(target),
          text,
          region: cleanRegionName(tag),
          signed: (await ref.read(postSigningProvider.future)).all,
        );
      } else {
        await state.sync.sendDirect(PublicKey.fromHex(target), text);
      }
      if (typed) _clearBox();
      if (replyTo != null && mounted) setState(() => _replyTo = null);
    } on ArgumentError {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.thatMessageIsTooLongTo)),
      );
    } on RadioRequestException {
      // The message is stored as failed with a resend option, so don't
      // leave a second copy in the box.
      if (typed) _clearBox();
      if (replyTo != null && mounted) setState(() => _replyTo = null);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotSendIt2)),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Translates [text] into the app's language on the phone, downloading
  /// models first if the person agrees.
  Future<void> _translate(String text) async {
    final translator = ref.read(translatorProvider);
    if (translator == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final to = Localizations.localeOf(context).languageCode;
    try {
      final from = await translator.detect(text);
      var plan = await planTranslation(translator, from: from, to: to);
      if (!mounted) return;
      if (plan is NeedsModels) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.downloadModelsTitle),
            content: Text(
              l10n.downloadModelsBody(
                plan is NeedsModels
                    ? plan.codes.map((c) => c.toUpperCase()).join(', ')
                    : '',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.download),
              ),
            ],
          ),
        );
        if (ok != true) return;
        messenger.showSnackBar(SnackBar(content: Text(l10n.translating)));
        for (final code in plan.codes) {
          if (!await translator.download(code)) throw StateError('download');
        }
        plan = const Ready();
      }
      switch (plan) {
        case AlreadyInLanguage():
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.alreadyInLanguage)),
          );
        case Unsupported():
          messenger.showSnackBar(SnackBar(content: Text(l10n.cantTranslate)));
        case NeedsModels():
          break;
        case Ready():
          final result = await translator.translate(text, from: from!, to: to);
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                l10n.translationTitle(from.toUpperCase(), to.toUpperCase()),
              ),
              content: SelectableText(result),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.close),
                ),
              ],
            ),
          );
      }
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.translationFailed)));
    }
  }

  /// When this app last sent a photo, to keep to one every 5 minutes.
  static DateTime? _lastPhoto;

  /// Picks a picture, shrinks it for the mesh, shows what it costs, and
  /// sends it on this channel if the person agrees.
  Future<void> _sendPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (!widget.isChannel) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoChannelsOnly)));
      return;
    }
    final last = _lastPhoto;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(minutes: 5)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoWait)));
      return;
    }
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null || !mounted) return;
    final source = await file.readAsBytes();
    final jpg = encodeMeshPhoto(source);
    if (!mounted) return;
    if (jpg == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoNotImage)));
      return;
    }
    final packets = photoChunks(0, jpg).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sendPhotoTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.memory(jpg, width: 192, filterQuality: FilterQuality.medium),
            const SizedBox(height: 12),
            Text(l10n.sendPhotoBody(jpg.length, packets)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.send),
          ),
        ],
      ),
    );
    final state = ref.read(connectionProvider);
    if (ok != true || state is! Connected) return;
    _lastPhoto = DateTime.now();
    messenger.showSnackBar(SnackBar(content: Text(l10n.sendingPhoto)));
    try {
      await state.sync.sendPhoto(int.parse(widget.thread.substring(2)), jpg);
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotSendIt)),
      );
    }
  }

  /// Asks which chat, then sends [message] there.
  Future<void> _forward(Message message, String sender) async {
    final state = ref.read(connectionProvider);
    if (state is! Connected) return;
    final store = ref.read(storeProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final key = state.radio.key;
    final channels = ref.read(channelsProvider(key)).value ?? const [];
    final contacts = ref.read(contactsProvider(key)).value ?? const [];
    final picked = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(context.l10n.forwardTo)),
            for (final c in channels)
              if (c.name.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(c.name),
                  onTap: () =>
                      Navigator.pop(context, (Threads.channel(c.slot), c.name)),
                ),
            for (final c in contacts)
              if (c.type == NodeType.chat.value)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(c.name),
                  onTap: () => Navigator.pop(context, (
                    Threads.direct(c.publicKey),
                    c.name,
                  )),
                ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await sendToThread(
        state,
        store,
        picked.$1,
        forwardText(sender, message.body),
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.forwardedTo(picked.$2))),
      );
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotSendIt)),
      );
    }
  }

  /// Takes what's in the box and sets it to go out later.
  Future<void> _schedule() async {
    final text = _text.text.trim();
    final radioKey = ref.read(radioKeyProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    if (radioKey == null || radioKey.isEmpty) return;
    if (text.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.typeTheMessageFirst)),
      );
      return;
    }
    if (utf8.encode(text).length > maxDirectTextBytes) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.thatMessageIsTooLongTo)),
      );
      return;
    }
    final at = await pickSendTime(context, ref.read(safetyClockProvider)());
    if (at == null || !mounted) return;
    await ref
        .read(scheduledMessagesProvider.notifier)
        .add(
          radioKey: radioKey,
          thread: widget.thread,
          title: widget.title,
          text: text,
          at: at,
        );
    _clearBox();
    messenger.showSnackBar(SnackBar(content: Text(l10n.scheduled)));
  }

  /// How a post's signature reads: who signed it, or a warning.
  String? _signerLabel(
    BuildContext context,
    Message message,
    List<Contact> contacts,
  ) {
    final signer = message.signer;
    if (signer == null) return null;
    if (message.signatureValid != true) return context.l10n.signatureBad;
    if (message.outgoing) return null;
    for (final c in contacts) {
      if (c.publicKey == signer) return context.l10n.signedBy(c.name);
    }
    return context.l10n.signedByKey(signer.substring(0, 8).toUpperCase());
  }

  void _clearBox() {
    _text.clear();
    _flushDraft();
  }

  /// The contact this direct chat is with, when the radio knows them.
  Contact? _contact(List<Contact> contacts) {
    if (widget.isChannel) return null;
    final key = widget.thread.substring(2);
    for (final c in contacts) {
      if (c.publicKey == key) return c;
    }
    return null;
  }

  Future<void> _showActions(
    Message message,
    String sender, {
    required bool retrying,
    required bool canReply,
    Contact? contact,
  }) async {
    final state = ref.read(connectionProvider);
    final connected = state is Connected;
    final failed = message.status == MessageStatus.failed;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        // Scrolls, because it can hold more rows than fit on a small phone.
        child: ListView(
          shrinkWrap: true,
          children: [
            if (canReply) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  children: [
                    for (final emoji in quickReactions)
                      IconButton(
                        tooltip: context.l10n.react(emoji),
                        onPressed: () => Navigator.pop(context, 'react:$emoji'),
                        icon: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text(context.l10n.reply),
                onTap: () => Navigator.pop(context, 'reply'),
              ),
            ],
            if (ref.read(translatorProvider) != null)
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(context.l10n.translate),
                onTap: () => Navigator.pop(context, 'translate'),
              ),
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: Text(context.l10n.readAloud),
              onTap: () => Navigator.pop(context, 'read'),
            ),
            if (connected)
              ListTile(
                leading: const Icon(Icons.forward),
                title: Text(context.l10n.forward),
                onTap: () => Navigator.pop(context, 'forward'),
              ),
            if (!message.outgoing)
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(context.l10n.block(sender)),
                subtitle: Text(
                  message.kind == MessageKind.channel
                      ? 'Hides messages posted under this name, on every '
                            'channel.'
                      : 'Hides their direct messages.',
                ),
                onTap: () => Navigator.pop(context, 'block'),
              ),
            if (message.outgoing)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.l10n.deliveryDetails),
                onTap: () => Navigator.pop(context, 'details'),
              ),
            if (failed && connected)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(context.l10n.sendAgain),
                onTap: () => Navigator.pop(context, 'resend'),
              ),
            if (retrying && connected)
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: Text(context.l10n.stopTrying),
                onTap: () => Navigator.pop(context, 'stop'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action.startsWith('react:')) {
      await _send(reactionText(action.substring(6), message.body));
      return;
    }
    if (action == 'translate') {
      await _translate(message.body);
      return;
    }
    if (action == 'read') {
      try {
        await ref.read(speakerProvider)(
          readAloudText(sender, message.body, mine: message.outgoing),
        );
      } on Object {
        messenger.showSnackBar(
          const SnackBar(content: Text('This device can’t read aloud.')),
        );
      }
      return;
    }
    if (action == 'forward') {
      await _forward(message, sender);
      return;
    }
    if (action == 'reply') {
      setState(() => _replyTo = (message: message, name: sender));
      return;
    }
    if (action == 'block') {
      final blocking = ref.read(blockingProvider);
      if (message.kind == MessageKind.channel) {
        final name = message.senderName;
        if (name != null) await blocking.blockName(name);
      } else {
        await blocking.blockKey(message.thread.substring(2));
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.blocked2(sender)),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (message.kind == MessageKind.channel) {
                final name = message.senderName;
                if (name != null) unawaited(blocking.unblockName(name));
              } else {
                unawaited(blocking.unblockKey(message.thread.substring(2)));
              }
            },
          ),
        ),
      );
      return;
    }
    if (action == 'details') {
      await _showDelivery(message, retrying, contact);
      return;
    }
    if (state is! Connected) return;
    try {
      switch (action) {
        case 'resend':
          await state.sync.resend(message.id);
        case 'stop':
          await state.sync.stopTrying(message.id);
      }
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotSendIt)),
      );
    }
  }

  Future<void> _showDelivery(
    Message message,
    bool retrying,
    Contact? contact,
  ) async {
    final report = deliveryReport(
      message,
      retrying: retrying,
      contact: contact,
    );
    final sent = DateTime.fromMillisecondsSinceEpoch(message.sentAt * 1000);
    final canReset =
        contact != null &&
        contact.outPathLength != pathUnknown &&
        ref.read(connectionProvider) is Connected;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final reset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.headline),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.sent(
                  MaterialLocalizations.of(context).formatShortDate(sent),
                  TimeOfDay.fromDateTime(sent).format(context),
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              for (final line in report.details)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(line),
                ),
            ],
          ),
        ),
        actions: [
          if (canReset)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.resetRoute),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.close),
          ),
        ],
      ),
    );
    final state = ref.read(connectionProvider);
    if (reset != true || contact == null || state is! Connected) return;
    try {
      await state.sync.resetRoute(PublicKey.fromHex(contact.publicKey));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.routeResetTheNextMessageFloods)),
      );
    } on RadioRequestException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.theRadioCouldNotResetThe)),
      );
    }
  }

  /// A room post's writer: the contact whose key starts with [prefix], or
  /// the prefix itself for someone not in contacts.
  static String? _authorName(String? prefix, List<Contact> contacts) {
    if (prefix == null) return null;
    for (final c in contacts) {
      if (c.publicKey.startsWith(prefix)) return c.name;
    }
    return 'Member $prefix';
  }

  @override
  Widget build(BuildContext context) {
    final radioKey = ref.watch(radioKeyProvider);
    final chatScale = ref.watch(appearanceProvider.select((a) => a.chatScale));
    final connected = ref.watch(connectionProvider) is Connected;
    final messages = radioKey == null
        ? const <Message>[]
        : ref
                  .watch(
                    threadProvider((radioKey: radioKey, thread: widget.thread)),
                  )
                  .value ??
              const <Message>[];
    final retrying = ref.watch(retryingProvider).value ?? const <int>{};
    final contacts = radioKey == null
        ? const <Contact>[]
        : ref.watch(contactsProvider(radioKey)).value ?? const <Contact>[];
    final muted =
        radioKey != null &&
        (ref.watch(mutedThreadsProvider(radioKey)).value ?? const {}).contains(
          widget.thread,
        );
    // Everything on screen is read, including messages that land while the
    // chat is open.
    final newest = messages.isEmpty ? null : messages.last.id;
    if (newest != null && newest != _readUpTo) {
      _readUpTo = newest;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _markRead();
      });
    }
    // A direct thread keyed by prefix means the sender isn't a contact yet,
    // so there is no full key to reply to.
    final canReply =
        connected && (widget.isChannel || widget.thread.length == 2 + 64);
    final connection = ref.watch(connectionProvider);
    final selfName = connection is Connected
        ? connection.radio.self.name
        : 'Me';
    String senderOf(Message m) {
      if (m.outgoing) return selfName;
      return _authorName(m.authorPrefix, contacts) ??
          (widget.isChannel ? m.senderName ?? 'Someone' : widget.title);
    }

    final blocked = ref.watch(blockListProvider).value ?? const BlockList();
    final directKey = widget.isChannel ? null : widget.thread.substring(2);
    final threadBlocked = directKey != null && blocked.keys.contains(directKey);
    final repeats = ref.watch(spamFilterProvider).value == true
        ? spamRepeats(messages, myName: selfName)
        : const <int>{};
    final items = chatItems([
      for (final m in messages)
        if (!blocked.blocks(m) && !repeats.contains(m.id)) m,
    ], senderOf: senderOf);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: context.l10n.scheduleMessage,
            icon: const Icon(Icons.schedule_send),
            onPressed: _schedule,
          ),
          if (radioKey != null)
            IconButton(
              tooltip: muted ? 'Unmute' : 'Mute notifications',
              icon: Icon(
                muted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_active_outlined,
              ),
              onPressed: () => ref
                  .read(storeProvider)
                  .setMuted(radioKey, widget.thread, !muted),
            ),
        ],
      ),
      body: Column(
        children: [
          if (threadBlocked)
            MaterialBanner(
              content: Text(
                context.l10n.youBlockedTheirMessagesAreHidden(widget.title),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(blockingProvider).unblockKey(directKey),
                  child: Text(context.l10n.unblock),
                ),
              ],
            ),
          if (!widget.isChannel)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                context.l10n.directMessagesOnlyArriveIfHas(widget.title),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(child: Text(context.l10n.noMessagesYet))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[items.length - 1 - i];
                      final message = item.message;
                      final replyTo = item.replyTo;
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(
                            MediaQuery.textScalerOf(context).scale(1) *
                                chatScale,
                          ),
                        ),
                        child: _Bubble(
                          message: message,
                          body: item.replyText ?? message.body,
                          showSender: widget.isChannel,
                          author: _authorName(message.authorPrefix, contacts),
                          signedBy: _signerLabel(context, message, contacts),
                          replyTo: replyTo == null
                              ? null
                              : (name: senderOf(replyTo), body: replyTo.body),
                          reactions: item.reactions,
                          mentionsMe:
                              !message.outgoing &&
                              mentions(
                                message.body,
                                connection is Connected
                                    ? connection.radio.self.name
                                    : null,
                              ),
                          onShowPosition: switch (sharedPosition(
                            message.body,
                          )) {
                            final p? => () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PositionMapScreen(
                                  position: p,
                                  label: senderOf(message),
                                ),
                              ),
                            ),
                            null => null,
                          },
                          link: message.outgoing
                              ? null
                              : sharedLink(message.body),
                          onAddLink: (link) => addLink(context, ref, link),
                          retrying: retrying.contains(message.id),
                          onReact: canReply && !_sending
                              ? (emoji) =>
                                    _send(reactionText(emoji, message.body))
                              : null,
                          onLongPress: message.outgoing || canReply || connected
                              ? () => _showActions(
                                  message,
                                  senderOf(message),
                                  retrying: retrying.contains(message.id),
                                  canReply: canReply,
                                  contact: _contact(contacts),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          if (_replyTo case final reply? when canReply)
            _ReplyBanner(
              name: reply.name,
              body: reply.message.body,
              onCancel: () => setState(() => _replyTo = null),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.quickMessages,
                    onPressed: canReply && !_sending ? _pickQuick : null,
                    icon: const Icon(Icons.bolt),
                  ),
                  IconButton(
                    tooltip: context.l10n.sharePositionOrContact,
                    onPressed: canReply && !_sending
                        ? () => _share(contacts)
                        : null,
                    icon: const Icon(Icons.add_location_alt_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled: canReply,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: canReply
                            ? 'Message'
                            : connected
                            ? 'Add this sender as a contact to reply'
                            : radioKey != null
                            ? 'Waiting for the radio to reconnect'
                            : 'Not connected',
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: context.l10n.send,
                    onPressed: canReply && !_sending ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    this.signedBy,
    required this.body,
    required this.showSender,
    this.retrying = false,
    this.onLongPress,
    this.onReact,
    this.author,
    this.replyTo,
    this.reactions = const [],
    this.mentionsMe = false,
    this.onShowPosition,
    this.link,
    this.onAddLink,
  });

  /// Whether this mentions you; such messages stand out.
  final bool mentionsMe;

  /// Opens the position this message shares; null when it shares none.
  final VoidCallback? onShowPosition;

  /// A contact or channel this message shares, and how to add it.
  final MeshLink? link;
  final void Function(MeshLink link)? onAddLink;

  final Message message;

  /// "✓ Name" for a signed post, or a warning when it doesn't check out.
  final String? signedBy;

  /// The text shown: a reply's leading mention is left off.
  final String body;
  final bool showSender;
  final bool retrying;
  final VoidCallback? onLongPress;

  /// Adds the same reaction; null when sending isn't possible.
  final void Function(String emoji)? onReact;

  /// The message this one replies to.
  final ({String name, String body})? replyTo;
  final List<ReactionCount> reactions;

  /// Room posts: who wrote it.
  final String? author;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.outgoing;
    final shownName = mine
        ? null
        : author ?? (showSender ? message.senderName : null);
    final time = TimeOfDay.fromDateTime(
      DateTime.fromMillisecondsSinceEpoch(message.sentAt * 1000),
    ).format(context);

    final details = [
      time,
      if (message.region case final region?) '📍 $region',
      ?signedBy,
      if (!mine && message.kind == MessageKind.channel)
        ?_hops(message.pathLength),
      if (mine && retrying) 'try ${message.attempts}',
      if (mine && message.status == MessageStatus.failed) 'hold for details',
    ].join(' · ');

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        onLongPressHint: onLongPress == null ? null : 'show options',
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: mine
                    ? scheme.primaryContainer
                    : mentionsMe
                    ? scheme.tertiaryContainer
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: mentionsMe
                    ? Border.all(color: scheme.tertiary, width: 2)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mentionsMe)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.alternate_email,
                          size: 14,
                          color: scheme.onTertiaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.mentionsYou,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onTertiaryContainer),
                        ),
                      ],
                    ),
                  if (shownName case final name?)
                    Text(
                      name,
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (replyTo case final quoted?)
                    _Quote(name: quoted.name, body: quoted.body),
                  if (photoIdIn(body) case final id?)
                    MeshPhotoView(id: id)
                  else
                    Text(body),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Wraps rather than overflowing a narrow bubble.
                      Flexible(
                        child: Text(
                          details,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 4),
                        _StatusIcon(message.status),
                      ],
                    ],
                  ),
                  if (firstWebLink(body) case final url?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: LinkPreviewCard(url: url),
                    ),
                  if (onShowPosition != null || link != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (onShowPosition case final show?)
                            ActionChip(
                              avatar: const Icon(Icons.map_outlined, size: 18),
                              label: Text(context.l10n.showOnMap),
                              onPressed: show,
                            ),
                          if (link case final link?)
                            ActionChip(
                              avatar: Icon(
                                link is ChannelLink
                                    ? Icons.tag
                                    : Icons.person_add_alt,
                                size: 18,
                              ),
                              label: Text(switch (link) {
                                ChannelLink(:final name) => 'Join $name',
                                ContactLink(:final name) => 'Add $name',
                                AdvertLink() => 'Add contact',
                              }),
                              onPressed: onAddLink == null
                                  ? null
                                  : () => onAddLink!(link),
                            ),
                        ],
                      ),
                    ),
                  if (reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final r in reactions)
                            _ReactionChip(
                              reaction: r,
                              onTap: r.mine || onReact == null
                                  ? null
                                  : () => onReact!(r.emoji),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "direct", "1 hop", "3 hops" for a channel message's path.
  static String? _hops(int? pathLength) {
    if (pathLength == null) return null;
    if (pathLength == 0xFF) return 'direct';
    final hops = pathLength & 0x3F;
    return switch (hops) {
      0 => 'direct',
      1 => '1 hop',
      _ => '$hops hops',
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.status);

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (status) {
      MessageStatus.pending => (Icons.schedule, 'Sending'),
      MessageStatus.sent => (Icons.check, 'Sent'),
      MessageStatus.delivered => (Icons.done_all, 'Delivered'),
      MessageStatus.failed => (Icons.error_outline, 'Not sent'),
      MessageStatus.received => (Icons.check, 'Received'),
    };
    return Semantics(
      label: label,
      child: Icon(
        icon,
        size: 14,
        color: status == MessageStatus.failed
            ? Theme.of(context).colorScheme.error
            : null,
      ),
    );
  }
}

/// The message a reply answers, shown small above the reply.
class _Quote extends StatelessWidget {
  const _Quote({required this.name, required this.body});

  final String name;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'In reply to $name: $body',
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: scheme.primary, width: 3)),
          color: scheme.surface.withValues(alpha: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.reply, size: 14, color: scheme.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.primary),
                  ),
                ),
              ],
            ),
            Text(
              body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reaction, this.onTap});

  final ReactionCount reaction;

  /// Adds this reaction too; null when it's already yours or can't be sent.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = reaction.who.join(', ');
    final yours = reaction.mine ? ', including you' : '';
    return Semantics(
      button: onTap != null,
      label: '${reaction.emoji} ${reaction.count}: $names$yours',
      excludeSemantics: true,
      child: Tooltip(
        message: names,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 28, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: reaction.mine ? scheme.primary : scheme.outlineVariant,
                width: reaction.mine ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reaction.emoji),
                if (reaction.count > 1) ...[
                  const SizedBox(width: 4),
                  Text('${reaction.count}'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown above the box while a reply is being written.
class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({
    required this.name,
    required this.body,
    required this.onCancel,
  });

  final String name;
  final String body;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Icon(Icons.reply, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.replyingTo(name),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.cancelReply,
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
