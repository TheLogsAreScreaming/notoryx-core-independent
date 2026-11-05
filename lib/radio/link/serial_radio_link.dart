import 'dart:async';
import 'dart:typed_data';

import '../protocol/stream_framing.dart';
import 'radio_link.dart';

/// A raw two-way byte pipe, such as an open USB serial port. Keeps
/// [SerialRadioLink] independent of any one serial plugin.
abstract interface class SerialByteChannel {
  /// Bytes from the radio, in arbitrary chunks. Closes when the port does.
  Stream<Uint8List> get input;

  Future<void> write(Uint8List bytes);

  Future<void> close();
}

/// A radio on a serial byte stream. Adds the length header to outgoing frames
/// and reassembles incoming ones, exactly as over TCP.
final class SerialRadioLink implements RadioLink {
  SerialRadioLink(this._channel) {
    _subscription = _channel.input.listen(
      (chunk) => _deframer.add(chunk).forEach(_frames.add),
      onError: (Object _) => _shutDown(),
      onDone: _shutDown,
      cancelOnError: true,
    );
  }

  final SerialByteChannel _channel;
  final _deframer = StreamDeframer();
  final _frames = StreamController<Uint8List>();
  final _done = Completer<void>();
  late final StreamSubscription<Uint8List> _subscription;

  @override
  Stream<Uint8List> get frames => _frames.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> send(Uint8List frame) async {
    if (_done.isCompleted) throw const LinkClosedException();
    await _channel.write(StreamFraming.wrap(frame));
  }

  @override
  Future<void> close() async {
    if (_done.isCompleted) return;
    await _subscription.cancel();
    _shutDown();
    await _channel.close();
  }

  /// Call when the port goes away underneath the link (cable pulled).
  void markDisconnected() => _shutDown();

  void _shutDown() {
    if (_done.isCompleted) return;
    _deframer.reset();
    unawaited(_frames.close());
    _done.complete();
  }
}
