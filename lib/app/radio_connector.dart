import '../radio/radio.dart';

/// A way to reach a radio, as listed on the connect screen.
sealed class RadioTarget {
  const RadioTarget();

  String get label;
}

final class BleTarget extends RadioTarget {
  const BleTarget({
    required this.deviceId,
    required this.label,
    this.rssi,
    this.isMeshCore = true,
  });

  final String deviceId;
  @override
  final String label;
  final int? rssi;
  final bool isMeshCore;
}

final class UsbTarget extends RadioTarget {
  const UsbTarget(this.port);

  final UsbRadioPort port;

  @override
  String get label => port.label;
}

final class TcpTarget extends RadioTarget {
  const TcpTarget({required this.host, this.port = 5000});

  final String host;
  final int port;

  @override
  String get label => '$host:$port';
}

/// Finds radios and opens links to them. The app uses [DeviceRadioConnector];
/// tests swap in a fake.
abstract interface class RadioConnector {
  bool get supportsUsb;

  /// With [all], every Bluetooth device nearby, not just MeshCore radios.
  Stream<BleTarget> scanBluetooth({bool all = false});

  Future<List<UsbTarget>> listUsb();

  Future<RadioLink> open(RadioTarget target);
}

final class DeviceRadioConnector implements RadioConnector {
  const DeviceRadioConnector();

  @override
  bool get supportsUsb => UsbRadioPorts.isSupported;

  @override
  Stream<BleTarget> scanBluetooth({bool all = false}) =>
      BleRadioScanner.scan(all: all).map(
        (r) => BleTarget(
          deviceId: r.deviceId,
          label: r.name,
          rssi: r.rssi,
          isMeshCore: r.isMeshCore,
        ),
      );

  @override
  Future<List<UsbTarget>> listUsb() async => [
    for (final port in await UsbRadioPorts.list()) UsbTarget(port),
  ];

  @override
  Future<RadioLink> open(RadioTarget target) => switch (target) {
    BleTarget(:final deviceId) => BleRadioLink.connect(deviceId),
    UsbTarget(:final port) => UsbRadioPorts.connect(port),
    TcpTarget(:final host, :final port) => TcpRadioLink.connect(
      host,
      port: port,
    ),
  };
}
