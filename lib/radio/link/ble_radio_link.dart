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

/// Bluetooth can't scan right now, and why.
final class BluetoothUnavailable implements Exception {
  const BluetoothUnavailable(this.state);

  final AvailabilityState state;

  /// What the person can do about it.
  String get message => switch (state) {
    AvailabilityState.unauthorized =>
      'NOTORYX Independent isn\u2019t allowed to use Bluetooth. Turn it on in '
          'System Settings \u2192 Privacy & Security \u2192 Bluetooth (on a '
          'phone: Settings \u2192 Apps \u2192 NOTORYX Independent \u2192 '
          'Permissions), then scan again.',
    AvailabilityState.poweredOff => 'Bluetooth is turned off.',
    AvailabilityState.unsupported => 'This device has no Bluetooth LE.',
    _ => 'Bluetooth isn\u2019t ready yet. Scan again in a moment.',
  };

  @override
  String toString() => message;
}

/// A device seen while scanning. [isMeshCore] is true when it advertises the
/// MeshCore service or a MeshCore name.
typedef BleRadioCandidate = ({
  String deviceId,
  String name,
  int? rssi,
  bool isMeshCore,
});

/// Finds MeshCore radios over Bluetooth.
abstract final class BleRadioScanner {
  /// Names MeshCore companion firmware gives its Bluetooth radio.
  static const namePrefixes = ['MeshCore'];

  /// Scans for [duration] and emits each device the first time it's seen.
  /// Asks for Bluetooth permission if needed.
  ///
  /// By default only MeshCore radios are reported: those advertising the
  /// companion service, or named like one (some boards leave the service out
  /// of their advert when the name is long). With [all], every device is
  /// reported, for finding a radio with an unusual name.
  static Stream<BleRadioCandidate> scan({
    Duration duration = const Duration(seconds: 15),
    bool all = false,
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
          final isMeshCore = isMeshCoreAdvert(device.name, device.services);
          if (!all && !isMeshCore) return;
          if (!seen.add(device.deviceId)) return;
          final name = device.name;
          out.add((
            deviceId: device.deviceId,
            name: name == null || name.isEmpty ? device.deviceId : name,
            rssi: device.rssi,
            isMeshCore: isMeshCore,
          ));
        });
        try {
          final state = await _readyState();
          if (state != AvailabilityState.poweredOn) {
            out.addError(BluetoothUnavailable(state));
            await stop();
            return;
          }
          stopTimer = Timer(duration, stop);
          await UniversalBle.startScan(
            scanFilter: all
                ? null
                : ScanFilter(
                    withServices: [MeshCoreBle.service],
                    withNamePrefix: namePrefixes,
                  ),
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

/// Bluetooth's state once it has settled. Right after launch it reads
/// unknown until the system has asked for permission, so wait a little.
Future<AvailabilityState> _readyState() async {
  var state = await UniversalBle.getBluetoothAvailabilityState();
  if (state != AvailabilityState.unknown &&
      state != AvailabilityState.resetting) {
    return state;
  }
  await UniversalBle.requestPermissions();
  try {
    state = await UniversalBle.availabilityStream
        .firstWhere(
          (s) =>
              s != AvailabilityState.unknown &&
              s != AvailabilityState.resetting,
        )
        .timeout(const Duration(seconds: 30));
  } on TimeoutException {
    state = await UniversalBle.getBluetoothAvailabilityState();
  }
  return state;
}

/// Whether an advert with [name] and [services] looks like a MeshCore radio.
bool isMeshCoreAdvert(String? name, List<String> services) =>
    services.any((s) => BleUuidParser.compareStrings(s, MeshCoreBle.service)) ||
    BleRadioScanner.namePrefixes.any((p) => name?.startsWith(p) ?? false);

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
