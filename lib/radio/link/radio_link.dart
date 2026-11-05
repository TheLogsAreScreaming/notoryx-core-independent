import 'dart:typed_data';

/// A connection to a radio that moves whole protocol frames. BLE, USB and TCP
/// each implement this, so everything above it works with any of them.
abstract interface class RadioLink {
  /// Frames from the radio, one per event. Single-subscription; closes when
  /// the link drops or [close] is called.
  Stream<Uint8List> get frames;

  /// Sends one frame to the radio.
  Future<void> send(Uint8List frame);

  /// Completes once the link is closed, from either end.
  Future<void> get done;

  Future<void> close();
}

/// The link dropped or was closed while something was using it.
final class LinkClosedException implements Exception {
  const LinkClosedException([this.reason = 'link closed']);

  final String reason;

  @override
  String toString() => 'LinkClosedException: $reason';
}
