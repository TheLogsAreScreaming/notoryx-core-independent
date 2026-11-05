import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

import 'radio_link.dart';
import 'serial_radio_link.dart';

/// The companion firmware's USB serial speed.
const meshCoreBaudRate = 115200;

/// A USB serial device that may be a radio.
final class UsbRadioPort {
  const UsbRadioPort._(this.id, this.label, this._open);

  /// Stable within a session: the Android USB device path.
  final String id;

  /// What to show the user, such as "RAK4631 (RAKwireless)".
  final String label;

  final Future<SerialByteChannel> Function() _open;
}

/// Lists and opens USB serial ports. Android only for now: iOS apps can't
/// open USB serial devices, and macOS needs its own serial backend (the
/// libserialport plugin doesn't build on current Android tooling and bundles
/// LGPL code).
abstract final class UsbRadioPorts {
  static bool get isSupported => Platform.isAndroid;

  static Future<List<UsbRadioPort>> list() async {
    if (Platform.isAndroid) return _androidPorts();
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

  static String _label(String? product, String? maker, String fallback) {
    if (product == null || product.isEmpty) return fallback;
    if (maker == null || maker.isEmpty) return product;
    return '$product ($maker)';
  }
}

// Line settings: DTR on so boards with native USB
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
