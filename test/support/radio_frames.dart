import 'dart:convert';
import 'dart:typed_data';

import 'package:notoryx_core/radio/radio.dart';

/// Radio-side frames for tests, laid out the way the firmware writes them.
List<int> u32(int v) =>
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();

List<int> padded(String text, int width) {
  final encoded = utf8.encode(text);
  return [...encoded, ...List.filled(width - encoded.length, 0)];
}

final testKey = List.generate(32, (i) => i + 1);

List<int> okFrame() => [ResponseCode.ok];

List<int> errorFrame(RadioErrorCode code) => [ResponseCode.error, code.value];

List<int> selfInfoFrame({
  String name = 'Test Node',
  double? latitude,
  double? longitude,
  int frequencyKhz = 910525,
  int bandwidthHz = 62500,
  int spreadingFactor = 7,
  int codingRate = 5,
  int txPower = 22,
  int maxTxPower = 22,
  int multiAcks = 0,
  int locationPolicy = 0,
  int telemetry = 0,
  bool manualAdd = false,
}) => [
  ResponseCode.selfInfo,
  NodeType.chat.value,
  txPower & 0xFF,
  maxTxPower,
  ...testKey,
  ...i32(((latitude ?? 0) * 1e6).round()),
  ...i32(((longitude ?? 0) * 1e6).round()),
  multiAcks,
  locationPolicy,
  telemetry,
  manualAdd ? 1 : 0,
  ...u32(frequencyKhz),
  ...u32(bandwidthHz),
  spreadingFactor,
  codingRate,
  ...utf8.encode(name),
];

List<int> u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];

List<int> i32(int v) =>
    (ByteData(4)..setInt32(0, v, Endian.little)).buffer.asUint8List();

List<int> deviceInfoFrame({int versionCode = 14, int maxChannels = 8}) => [
  ResponseCode.deviceInfo,
  versionCode,
  50,
  maxChannels,
  ...u32(0),
  ...padded('', 12),
  ...padded('Test Board', 40),
  ...padded('v1.18.0', 20),
  0,
  0,
];

List<int> contactFrame(
  String name, {
  int keyByte = 1,
  int lastModified = 1,
  NodeType type = NodeType.chat,
  double? latitude,
  double? longitude,
  int lastAdvert = 0,
}) => [
  ResponseCode.contact,
  ...List.filled(32, keyByte),
  type.value,
  0,
  pathUnknown,
  ...List.filled(64, 0),
  ...padded(name, 32),
  ...u32(lastAdvert),
  ...i32(((latitude ?? 0) * 1e6).round()),
  ...i32(((longitude ?? 0) * 1e6).round()),
  ...u32(lastModified),
];

List<int> channelInfoFrame(int index, String name) => [
  ResponseCode.channelInfo,
  index,
  ...padded(name, 32),
  ...List.filled(16, name.isEmpty ? 0 : 7),
];

List<int> channelMessageFrame(String text, {int channel = 0}) => [
  ResponseCode.channelMessageV3,
  12,
  0,
  0,
  channel,
  pathUnknown,
  0,
  ...u32(1700000000),
  ...utf8.encode(text),
];
