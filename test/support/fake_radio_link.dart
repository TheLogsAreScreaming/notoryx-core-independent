import 'dart:async';
import 'dart:typed_data';

import 'package:notoryx_core/radio/radio.dart';

/// An in-memory radio. Tests answer commands by setting [onSend], or push
/// frames at any time with [emit].
class FakeRadioLink implements RadioLink {
  final _frames = StreamController<Uint8List>();
  final _done = Completer<void>();

  /// Every frame the session sent, decoded back to its first byte.
  final sent = <Uint8List>[];

  /// Called for each frame sent; return the frames the radio answers with.
  List<List<int>> Function(Uint8List frame)? onSend;

  List<int> get sentCodes => [for (final f in sent) f[0]];

  void emit(List<int> frame) => _frames.add(Uint8List.fromList(frame));

  /// Simulates the radio dropping the connection.
  void drop() {
    if (_done.isCompleted) return;
    _frames.close();
    _done.complete();
  }

  @override
  Stream<Uint8List> get frames => _frames.stream;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> send(Uint8List frame) async {
    if (_done.isCompleted) throw const LinkClosedException();
    sent.add(frame);
    final replies = onSend?.call(frame) ?? const [];
    // Answer asynchronously, like a real radio.
    scheduleMicrotask(() {
      if (_done.isCompleted) return;
      for (final reply in replies) {
        emit(reply);
      }
    });
  }

  @override
  Future<void> close() async => drop();
}
