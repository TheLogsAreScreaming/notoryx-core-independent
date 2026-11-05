import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:usb_serial/usb_serial.dart';

import 'radio_link.dart';
import 'serial_radio_link.dart';

/// The companion firmware's USB serial speed.
const meshCoreBaudRate = 115200;

/// A USB serial device that may be a radio.
final class UsbRadioPort {
  const UsbRadioPort._(this.id, this.label, this._open);

  /// Stable within a session: the device path on Android and macOS.
  final String id;

  /// What to show the user, such as "RAK4631 (RAKwireless)".
  final String label;

  final Future<SerialByteChannel> Function() _open;
}

/// Lists and opens USB serial ports. Supported on Android (USB host) and
/// macOS; iOS apps can't open USB serial devices.
abstract final class UsbRadioPorts {
  static bool get isSupported => Platform.isAndroid || Platform.isMacOS;

  static Future<List<UsbRadioPort>> list() async {
    if (Platform.isAndroid) return _androidPorts();
    if (Platform.isMacOS) return _macPorts();
    return const [];
  }

  /// Opens [port] at the MeshCore baud rate and returns a link over it.
  static Future<SerialRadioLink> connect(UsbRadioPort port) async {
    final channel = await port._open();
    return SerialRadioLink(channel);
  }

  static Future<List<UsbRadioPort>> _androidPorts() async {
    final devices = await UsbSerial.listDevices();
    return [
      for (final device in devices)
        UsbRadioPort._(
          device.deviceName,
          _label(
            device.productName,
            device.manufacturerName,
            device.deviceName,
          ),
          () => _AndroidUsbChannel.open(device),
        ),
    ];
  }

  static List<UsbRadioPort> _macPorts() {
    final ports = <UsbRadioPort>[];
    for (final name in SerialPort.availablePorts) {
      // macOS lists each device twice; the call-out (cu.) side is the one to
      // open, since the tty. side waits for carrier detect.
      if (!name.startsWith('/dev/cu.')) continue;
      final port = SerialPort(name);
      try {
        if (port.transport != SerialPortTransport.usb) continue;
        ports.add(
          UsbRadioPort._(
            name,
            _label(port.productName, port.manufacturer, name),
            () async => _DesktopSerialChannel.open(name),
          ),
        );
      } finally {
        port.dispose();
      }
    }
    return ports;
  }

  static String _label(String? product, String? maker, String fallback) {
    if (product == null || product.isEmpty) return fallback;
    if (maker == null || maker.isEmpty) return product;
    return '$product ($maker)';
  }
}

// Line settings shared by both platforms: DTR on so boards with native USB
// (nRF52, ESP32-S3) start sending, RTS off so boards with an auto-reset
// circuit (classic ESP32) aren't held in reset.

final class _AndroidUsbChannel implements SerialByteChannel {
  _AndroidUsbChannel(this._port, this._device) {
    _detach = UsbSerial.usbEventStream?.listen((event) {
      if (event.event == UsbEvent.ACTION_USB_DETACHED &&
          event.device?.deviceName == _device.deviceName) {
        unawaited(close());
      }
    });
    _input = _port.inputStream!.listen(
      _bytes.add,
      onError: _bytes.addError,
      onDone: close,
    );
  }

  static Future<_AndroidUsbChannel> open(UsbDevice device) async {
    final port = await device.create();
    if (port == null || !await port.open()) {
      throw const LinkClosedException('could not open the USB device');
    }
    await port.setPortParameters(
      meshCoreBaudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );
    await port.setFlowControl(UsbPort.FLOW_CONTROL_OFF);
    await port.setDTR(true);
    await port.setRTS(false);
    return _AndroidUsbChannel(port, device);
  }

  final UsbPort _port;
  final UsbDevice _device;
  final _bytes = StreamController<Uint8List>();
  StreamSubscription<UsbEvent>? _detach;
  late final StreamSubscription<Uint8List> _input;
  bool _closed = false;

  @override
  Stream<Uint8List> get input => _bytes.stream;

  @override
  Future<void> write(Uint8List bytes) => _port.write(bytes);

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _detach?.cancel();
    await _input.cancel();
    await _port.close();
    await _bytes.close();
  }
}

final class _DesktopSerialChannel implements SerialByteChannel {
  _DesktopSerialChannel(this._port) : _reader = SerialPortReader(_port);

  static _DesktopSerialChannel open(String name) {
    final port = SerialPort(name);
    if (!port.openReadWrite()) {
      final error = SerialPort.lastError;
      port.dispose();
      throw LinkClosedException('could not open $name: $error');
    }
    final config = SerialPortConfig()
      ..baudRate = meshCoreBaudRate
      ..bits = 8
      ..stopBits = 1
      ..parity = SerialPortParity.none
      ..setFlowControl(SerialPortFlowControl.none)
      ..dtr = SerialPortDtr.on
      ..rts = SerialPortRts.off;
    port.config = config;
    config.dispose();
    return _DesktopSerialChannel(port);
  }

  final SerialPort _port;
  final SerialPortReader _reader;
  bool _closed = false;

  @override
  Stream<Uint8List> get input => _reader.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    var sent = 0;
    while (sent < bytes.length) {
      final n = _port.write(Uint8List.sublistView(bytes, sent), timeout: 1000);
      if (n <= 0) throw const LinkClosedException('USB write failed');
      sent += n;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reader.close();
    _port.close();
    _port.dispose();
  }
}
