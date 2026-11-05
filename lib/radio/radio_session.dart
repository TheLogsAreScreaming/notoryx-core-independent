import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'link/radio_link.dart';
import 'protocol/codes.dart';
import 'protocol/commands.dart';
import 'protocol/contact.dart';
import 'protocol/frames.dart';

/// Why a command didn't get the reply it wanted.
sealed class RadioRequestException implements Exception {
  const RadioRequestException();
}

/// The radio answered with an error frame.
final class RadioRejected extends RadioRequestException {
  const RadioRejected(this.code);

  final RadioErrorCode code;

  @override
  String toString() => 'RadioRejected: ${code.name}';
}

/// The radio firmware was built without this feature.
final class RadioFeatureDisabled extends RadioRequestException {
  const RadioFeatureDisabled();
}

/// No reply arrived in time.
final class RadioTimeout extends RadioRequestException {
  const RadioTimeout(this.command);

  final RadioCommand command;

  @override
  String toString() => 'RadioTimeout: ${command.runtimeType}';
}

/// The radio replied with a frame of the wrong type.
final class RadioUnexpectedReply extends RadioRequestException {
  const RadioUnexpectedReply(this.reply);

  final ReplyFrame reply;

  @override
  String toString() => 'RadioUnexpectedReply: ${reply.runtimeType}';
}

/// The link closed before the reply came.
final class RadioDisconnected extends RadioRequestException {
  const RadioDisconnected();
}

/// What the radio said about itself when the session started.
typedef SessionStart = ({SelfInfo self, DeviceInfo device});

/// The contact list and the value to pass as `since` next time.
typedef ContactSync = ({List<RadioContact> contacts, int newestModified});

/// Talks to one radio over a [RadioLink]. Commands go out one at a time, as
/// the firmware expects, and each reply is matched to the command in flight.
/// Pushes the radio sends on its own arrive on [pushes].
///
/// When the radio says messages are waiting, the session fetches them and
/// emits them on [messages], unless [autoSyncMessages] is false.
class RadioSession {
  RadioSession(
    this._link, {
    this.timeout = const Duration(seconds: 5),
    this.autoSyncMessages = true,
  }) {
    _subscription = _link.frames.listen(
      _onFrame,
      onDone: _onLinkClosed,
      onError: (Object _) => _onLinkClosed(),
    );
  }

  final RadioLink _link;
  final Duration timeout;
  final bool autoSyncMessages;

  late final StreamSubscription<Object> _subscription;
  final _queue = Queue<_Request>();
  _Request? _current;
  bool _closed = false;
  bool _syncing = false;

  final _pushes = StreamController<PushFrame>.broadcast();
  final _messages = StreamController<ReplyFrame>.broadcast();
  final _unhandled = StreamController<RadioFrame>.broadcast();

  /// Notifications the radio sends without being asked.
  Stream<PushFrame> get pushes => _pushes.stream;

  /// Incoming direct messages, channel messages and channel datagrams, as
  /// [ContactMessage], [ChannelMessage] and [ChannelData].
  Stream<ReplyFrame> get messages => _messages.stream;

  /// Frames that couldn't be decoded, or replies nobody was waiting for.
  Stream<RadioFrame> get unhandled => _unhandled.stream;

  bool get isClosed => _closed;

  /// Sends [command] and completes with its single reply, typed as [T].
  /// Throws a [RadioRequestException] for errors, timeouts and wrong replies.
  Future<T> request<T extends ReplyFrame>(
    RadioCommand command, {
    Duration? timeout,
  }) async {
    final reply = await _enqueue(command, timeout, (reply, _) => true);
    if (reply is! T) throw RadioUnexpectedReply(reply);
    return reply;
  }

  /// Sends a command that the radio answers with OK.
  Future<void> run(RadioCommand command, {Duration? timeout}) =>
      request<OkReply>(command, timeout: timeout);

  /// Sends a command that gets no reply at all, such as [Reboot].
  Future<void> sendOnly(RadioCommand command) {
    if (_closed) return Future.error(const RadioDisconnected());
    return _link.send(command.encode());
  }

  /// Opens the session: identifies the app, learns the firmware version, and
  /// sets the radio clock if it is behind [now].
  Future<SessionStart> start({
    String appName = 'NOTORYX Core',
    DateTime? now,
  }) async {
    final self = await request<SelfInfo>(AppStart(appName: appName));
    final device = await request<DeviceInfo>(const DeviceQuery());
    final seconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    try {
      await run(SetDeviceTime(seconds));
    } on RadioRejected catch (e) {
      // The radio refuses to move its clock backwards; an ahead clock is fine.
      if (e.code != RadioErrorCode.illegalArgument) rethrow;
    }
    return (self: self, device: device);
  }

  /// Downloads the contact table, or only entries changed after [since].
  /// The timeout applies to each frame, so large tables don't time out.
  Future<ContactSync> fetchContacts({int? since}) async {
    final contacts = <RadioContact>[];
    final end = await _enqueue(GetContacts(since: since), null, (reply, _) {
      if (reply is ContactEntry) contacts.add(reply.contact);
      return reply is! ContactsStart && reply is! ContactEntry;
    });
    if (end is! ContactsEnd) throw RadioUnexpectedReply(end);
    return (contacts: contacts, newestModified: end.newestModified);
  }

  /// Reads channel slots 0 to [count] - 1. Empty slots are included so slot
  /// numbers line up with list positions.
  Future<List<ChannelInfo>> fetchChannels(int count) async {
    final channels = <ChannelInfo>[];
    for (var i = 0; i < count; i++) {
      try {
        channels.add(await request<ChannelInfo>(GetChannel(i)));
      } on RadioRejected catch (e) {
        if (e.code == RadioErrorCode.notFound) break;
        rethrow;
      }
    }
    return channels;
  }

  /// Takes every queued message off the radio and emits each on [messages].
  /// Returns how many there were.
  Future<int> syncMessages() async {
    var count = 0;
    while (!_closed) {
      final reply = await request<ReplyFrame>(const SyncNextMessage());
      if (reply is NoMoreMessages) break;
      if (reply is ContactMessage ||
          reply is ChannelMessage ||
          reply is ChannelData) {
        _messages.add(reply);
        count++;
      } else {
        _unhandled.add(reply);
      }
    }
    return count;
  }

  Future<void> close() async {
    await _link.close();
    _onLinkClosed();
  }

  Future<ReplyFrame> _enqueue(
    RadioCommand command,
    Duration? timeout,
    bool Function(ReplyFrame reply, _Request request) isFinal,
  ) {
    if (_closed) return Future.error(const RadioDisconnected());
    // Encode now so an invalid command fails here instead of jamming the queue.
    final frame = command.encode();
    final request = _Request(command, frame, timeout ?? this.timeout, isFinal);
    _queue.add(request);
    _pump();
    return request.completer.future;
  }

  void _pump() {
    if (_current != null || _queue.isEmpty || _closed) return;
    final request = _current = _queue.removeFirst();
    request.restartTimer(() => _finish(error: RadioTimeout(request.command)));
    _link.send(request.frame).catchError((Object _) {
      _finish(error: const RadioDisconnected());
    });
  }

  void _onFrame(List<int> bytes) {
    final frame = decodeFrame(bytes);
    switch (frame) {
      case PushFrame():
        _pushes.add(frame);
        if (frame is MessagesWaiting && autoSyncMessages) _autoSync();
      case ReplyFrame():
        final request = _current;
        if (request == null) {
          _unhandled.add(frame);
        } else if (frame is ErrorReply) {
          _finish(error: RadioRejected(frame.code));
        } else if (frame is DisabledReply) {
          _finish(error: const RadioFeatureDisabled());
        } else if (request.isFinal(frame, request)) {
          _finish(reply: frame);
        } else {
          request.restartTimer(
            () => _finish(error: RadioTimeout(request.command)),
          );
        }
      case UnknownFrame() || MalformedFrame():
        _unhandled.add(frame);
    }
  }

  void _finish({ReplyFrame? reply, RadioRequestException? error}) {
    final request = _current;
    if (request == null) return;
    _current = null;
    request.cancelTimer();
    if (error != null) {
      request.completer.completeError(error);
    } else {
      request.completer.complete(reply);
    }
    _pump();
  }

  Future<void> _autoSync() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await syncMessages();
    } on RadioRequestException {
      // A later "messages waiting" push will try again.
    } finally {
      _syncing = false;
    }
  }

  void _onLinkClosed() {
    if (_closed) return;
    _closed = true;
    unawaited(_subscription.cancel());
    final waiting = [?_current, ..._queue];
    _current = null;
    _queue.clear();
    for (final request in waiting) {
      request.cancelTimer();
      request.completer.completeError(const RadioDisconnected());
    }
    unawaited(_pushes.close());
    unawaited(_messages.close());
    unawaited(_unhandled.close());
  }
}

class _Request {
  _Request(this.command, this.frame, this.timeout, this.isFinal);

  final RadioCommand command;
  final Uint8List frame;
  final Duration timeout;
  final bool Function(ReplyFrame reply, _Request request) isFinal;
  final completer = Completer<ReplyFrame>();
  Timer? _timer;

  void restartTimer(void Function() onTimeout) {
    _timer?.cancel();
    _timer = Timer(timeout, onTimeout);
  }

  void cancelTimer() => _timer?.cancel();
}
