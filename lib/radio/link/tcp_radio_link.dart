import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../protocol/stream_framing.dart';
import 'radio_link.dart';

/// A radio reached over TCP, such as a WiFi companion or a simulator. Uses
/// the same length-prefixed framing as USB serial.
final class TcpRadioLink implements RadioLink {
  TcpRadioLink._(this._socket) {
    _subscription = _socket.listen(
      (chunk) => _deframer.add(chunk).forEach(_frames.add),
      onError: (Object error) => _shutDown(),
      onDone: _shutDown,
      cancelOnError: true,
    );
  }

  /// Opens a connection. MeshCore WiFi companions listen on port 5000.
  static Future<TcpRadioLink> connect(
    String host, {
    int port = 5000,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    socket.setOption(SocketOption.tcpNoDelay, true);
    return TcpRadioLink._(socket);
  }

  final Socket _socket;
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
    _socket.add(StreamFraming.wrap(frame));
    await _socket.flush();
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    _socket.destroy();
    _shutDown();
  }

  void _shutDown() {
    if (_done.isCompleted) return;
    _deframer.reset();
    unawaited(_frames.close());
    _done.complete();
  }
}
