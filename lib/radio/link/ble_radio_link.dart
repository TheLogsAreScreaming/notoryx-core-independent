import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'radio_link.dart';

/// UUIDs of the MeshCore companion BLE service (Nordic UART layout).
abstract final class MeshCoreBle {
  static const service = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';

  /// The app writes commands here.
  static const rx = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

  /// The radio notifies frames here.
  static const tx = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
}

/// A MeshCore radio seen while scanning.
typedef BleRadioCandidate = ({String deviceId, String name, int? rssi});

/// Finds radios advertising the MeshCore companion service.
abstract final class BleRadioScanner {
  /// Scans for [duration] and emits each radio the first time it's seen.
  /// Asks for Bluetooth permission if needed.
  static Stream<BleRadioCandidate> scan({
    Duration duration = const Duration(seconds: 10),
  }) {
    late final StreamController<BleRadioCandidate> out;
    StreamSubscription<BleDevice>? results;
    Timer? stopTimer;
    final seen = <String>{};

    Future<void> stop() async {
      stopTimer?.cancel();
      await results?.cancel();
      try {
        await UniversalBle.stopScan();
      } on Object {
        // Bluetooth may already be off; nothing left to stop.
      }
      if (!out.isClosed) await out.close();
    }

    out = StreamController<BleRadioCandidate>(
      onListen: () async {
        results = UniversalBle.scanStream.listen((device) {
          if (!seen.add(device.deviceId)) return;
          out.add((
            deviceId: device.deviceId,
            name: device.name ?? device.deviceId,
            rssi: device.rssi,
          ));
        });
        stopTimer = Timer(duration, stop);
        try {
          await UniversalBle.startScan(
            scanFilter: ScanFilter(withServices: [MeshCoreBle.service]),
            // MeshCore radios send legacy (BLE 4) adverts.
            platformConfig: PlatformConfig(
              android: AndroidOptions(legacy: true),
            ),
          );
        } on Object catch (error, stack) {
          out.addError(error, stack);
          await stop();
        }
      },
      onCancel: stop,
    );
    return out.stream;
  }
}

/// A radio connected over Bluetooth LE. Each notification on the TX
/// characteristic is one frame, and each write to RX is one frame, so no
/// extra framing is needed.
final class BleRadioLink implements RadioLink {
  BleRadioLink._(this.deviceId);

  /// Connects, finds the MeshCore service, raises the MTU so full frames fit
  /// in one write, and subscribes to the radio's notifications.
  static Future<BleRadioLink> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final link = BleRadioLink._(deviceId);
    try {
      await link._open(timeout);
    } on Object {
      await link.close();
      rethrow;
    }
    return link;
  }

  final String deviceId;
  final _frames = StreamController<Uint8List>();
  final _done = Completer<void>();
  StreamSubscription<Uint8List>? _values;
  StreamSubscription<bool>? _connection;

  @override
  Stream<Uint8List> get frames => _frames.stream;

  @override
  Future<void> get done => _done.future;

  Future<void> _open(Duration timeout) async {
    await UniversalBle.connect(deviceId, timeout: timeout);
    _connection = UniversalBle.connectionStream(deviceId).listen((connected) {
      if (!connected) _shutDown();
    });

    final services = await UniversalBle.discoverServices(deviceId);
    final service = services.where(
      (s) => BleUuidParser.compareStrings(s.uuid, MeshCoreBle.service),
    );
    if (service.isEmpty) {
      throw const LinkClosedException('not a MeshCore companion radio');
    }

    try {
      await UniversalBle.requestMtu(deviceId, 512);
    } on Object {
      // iOS and macOS pick the MTU themselves; a failed request is harmless.
    }

    _values = UniversalBle.characteristicValueStream(
      deviceId,
      MeshCoreBle.tx,
    ).listen(_frames.add);
    await UniversalBle.subscribeNotifications(
      deviceId,
      MeshCoreBle.service,
      MeshCoreBle.tx,
    );
  }

  @override
  Future<void> send(Uint8List frame) async {
    if (_done.isCompleted) throw const LinkClosedException();
    await UniversalBle.write(
      deviceId,
      MeshCoreBle.service,
      MeshCoreBle.rx,
      frame,
    );
  }

  @override
  Future<void> close() async {
    if (_done.isCompleted) return;
    _shutDown();
    try {
      await UniversalBle.disconnect(deviceId);
    } on Object {
      // Already gone.
    }
  }

  void _shutDown() {
    if (_done.isCompleted) return;
    unawaited(_values?.cancel());
    unawaited(_connection?.cancel());
    unawaited(_frames.close());
    _done.complete();
  }
}
