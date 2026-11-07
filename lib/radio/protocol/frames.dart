import 'dart:typed_data';

import 'bytes.dart';
import 'codes.dart';
import 'contact.dart';
import 'public_key.dart';

/// A frame received from the radio: either a reply to the command in flight
/// or a push the radio sent on its own. Build one with [decodeFrame].
sealed class RadioFrame {
  const RadioFrame();
}

/// Marks frames the radio only sends as a reply to a command.
sealed class ReplyFrame extends RadioFrame {
  const ReplyFrame();
}

/// Marks frames the radio sends unprompted.
sealed class PushFrame extends RadioFrame {
  const PushFrame();
}

final class OkReply extends ReplyFrame {
  const OkReply([this.value]);

  /// Some commands return a number with OK; most return nothing.
  final int? value;
}

final class ErrorReply extends ReplyFrame {
  const ErrorReply(this.code);

  final RadioErrorCode code;
}

/// The radio was built without the feature the command asked for.
final class DisabledReply extends ReplyFrame {
  const DisabledReply();
}

final class ContactsStart extends ReplyFrame {
  const ContactsStart(this.total);

  /// Every contact on the radio, not just the ones about to be sent.
  final int total;
}

final class ContactEntry extends ReplyFrame {
  const ContactEntry(this.contact);

  final RadioContact contact;
}

final class ContactsEnd extends ReplyFrame {
  const ContactsEnd(this.newestModified);

  /// The newest [RadioContact.lastModified] sent, to use as the next `since`.
  final int newestModified;
}

/// This node's identity and radio settings, the reply to [CommandCode.appStart].
final class SelfInfo extends ReplyFrame {
  const SelfInfo({
    required this.nodeType,
    required this.txPowerDbm,
    required this.maxTxPowerDbm,
    required this.publicKey,
    required this.latitude,
    required this.longitude,
    required this.multiAcks,
    required this.advertLocationPolicy,
    required this.telemetryModes,
    required this.manualAddContacts,
    required this.frequencyMhz,
    required this.bandwidthKhz,
    required this.spreadingFactor,
    required this.codingRate,
    required this.name,
  });

  final NodeType nodeType;
  final int txPowerDbm;
  final int maxTxPowerDbm;
  final PublicKey publicKey;
  final double? latitude;
  final double? longitude;
  final int multiAcks;
  final int advertLocationPolicy;

  /// Telemetry sharing for base, location and environment data, two bits each.
  final ({int base, int location, int environment}) telemetryModes;

  final bool manualAddContacts;
  final double frequencyMhz;
  final double bandwidthKhz;
  final int spreadingFactor;
  final int codingRate;
  final String name;
}

/// Firmware details, the reply to [CommandCode.deviceQuery].
final class DeviceInfo extends ReplyFrame {
  const DeviceInfo({
    required this.firmwareVersionCode,
    this.maxContacts,
    this.maxChannels,
    this.blePin,
    this.buildDate,
    this.manufacturer,
    this.firmwareVersion,
    this.clientRepeat,
    this.pathHashMode,
  });

  /// Protocol level the firmware implements (14 for v1.18).
  final int firmwareVersionCode;

  // Present from version code 3.
  final int? maxContacts;
  final int? maxChannels;
  final int? blePin;
  final String? buildDate;
  final String? manufacturer;
  final String? firmwareVersion;

  /// Present from version code 9.
  final bool? clientRepeat;

  /// Present from version code 10.
  final int? pathHashMode;
}

/// A direct message or login request left the radio.
final class SentReply extends ReplyFrame {
  const SentReply({
    required this.flooded,
    required this.ackCode,
    required this.timeoutMs,
  });

  final bool flooded;

  /// Matches the [SendConfirmed.ackCode] that arrives on delivery. For logins
  /// and status requests this is a request tag instead, and 0 means no ack.
  final int ackCode;

  /// How long the radio expects delivery to take.
  final int timeoutMs;
}

final class CurrentTime extends ReplyFrame {
  const CurrentTime(this.unixSeconds);

  final int unixSeconds;
}

final class NoMoreMessages extends ReplyFrame {
  const NoMoreMessages();
}

final class BatteryAndStorage extends ReplyFrame {
  const BatteryAndStorage({
    required this.millivolts,
    this.usedKb,
    this.totalKb,
  });

  final int millivolts;
  final int? usedKb;
  final int? totalKb;
}

final class ChannelInfo extends ReplyFrame {
  ChannelInfo({
    required this.index,
    required this.name,
    required List<int> secret,
  }) : secret = Uint8List.fromList(secret);

  final int index;
  final String name;
  final Uint8List secret;

  /// Unused slots have no name and an all-zero secret.
  bool get isEmpty => name.isEmpty && secret.every((b) => b == 0);
}

/// The radio's auto-add settings, the reply to [CommandCode.getAutoAddConfig].
final class AutoAddConfigReply extends ReplyFrame {
  const AutoAddConfigReply({required this.flags, required this.maxHops});

  final int flags;
  final int maxHops;
}

/// A queued direct message, returned by [CommandCode.syncNextMessage].
final class ContactMessage extends ReplyFrame {
  ContactMessage({
    required this.senderPrefix,
    required this.pathLength,
    required this.type,
    required this.timestamp,
    required this.text,
    this.snr,
    this.signerPrefix,
  });

  /// First 6 bytes of the sender's public key.
  final Uint8List senderPrefix;

  /// Encoded path length if the message flooded, [pathUnknown] if it came
  /// direct.
  final int pathLength;

  final TextType type;

  /// Sender's clock, Unix seconds.
  final int timestamp;

  final String text;

  /// Signal-to-noise ratio in dB, on protocol v3+.
  final double? snr;

  /// For signed messages (room servers), the first 4 bytes of the key of the
  /// member who wrote it.
  final Uint8List? signerPrefix;

  bool get flooded => pathLength != pathUnknown;
}

/// A queued channel message, returned by [CommandCode.syncNextMessage].
final class ChannelMessage extends ReplyFrame {
  const ChannelMessage({
    required this.channel,
    required this.pathLength,
    required this.timestamp,
    required this.text,
    this.snr,
  });

  final int channel;
  final int pathLength;
  final int timestamp;

  /// The firmware sends "Sender name: message". See [senderAndBody].
  final String text;

  final double? snr;

  bool get flooded => pathLength != pathUnknown;

  /// Splits [text] at the first ": ". Returns a null sender when there is
  /// none, so a message containing a colon later on is never misread.
  ({String? sender, String body}) get senderAndBody {
    final split = text.indexOf(': ');
    if (split <= 0) return (sender: null, body: text);
    return (sender: text.substring(0, split), body: text.substring(split + 2));
  }
}

/// A binary datagram received on a channel.
final class ChannelData extends ReplyFrame {
  ChannelData({
    required this.channel,
    required this.pathLength,
    required this.dataType,
    required List<int> payload,
    required this.snr,
  }) : payload = Uint8List.fromList(payload);

  final int channel;

  /// Encoded path length if flooded, [pathUnknown] if it came direct.
  final int pathLength;

  final int dataType;
  final Uint8List payload;
  final double snr;
}

/// A known contact advertised again.
final class AdvertHeard extends PushFrame {
  const AdvertHeard(this.publicKey);

  final PublicKey publicKey;
}

/// A node the radio didn't know advertised (only sent when the radio adds
/// contacts manually, or auto-added it).
final class NewAdvert extends PushFrame {
  const NewAdvert(this.contact);

  final RadioContact contact;
}

final class PathUpdated extends PushFrame {
  const PathUpdated(this.publicKey);

  final PublicKey publicKey;
}

/// A direct message was delivered.
final class SendConfirmed extends PushFrame {
  const SendConfirmed({required this.ackCode, required this.roundTripMs});

  final int ackCode;
  final int roundTripMs;
}

/// New messages are queued; fetch them with [CommandCode.syncNextMessage].
final class MessagesWaiting extends PushFrame {
  const MessagesWaiting();
}

final class LoginSucceeded extends PushFrame {
  LoginSucceeded({
    required this.permissions,
    required List<int> serverPrefix,
    this.serverTime,
    this.aclPermissions,
    this.serverFirmwareLevel,
  }) : serverPrefix = Uint8List.fromList(serverPrefix);

  /// Bit 0 set means admin.
  final int permissions;
  final Uint8List serverPrefix;

  // Absent from legacy repeaters.
  final int? serverTime;
  final int? aclPermissions;
  final int? serverFirmwareLevel;

  bool get isAdmin => permissions & 1 == 1;
}

final class LoginFailed extends PushFrame {
  LoginFailed(List<int> serverPrefix)
    : serverPrefix = Uint8List.fromList(serverPrefix);

  final Uint8List serverPrefix;
}

/// A repeater or room server answered a status request. [data] is the
/// server's raw status block.
final class StatusResponse extends PushFrame {
  StatusResponse({required List<int> serverPrefix, required List<int> data})
    : serverPrefix = Uint8List.fromList(serverPrefix),
      data = Uint8List.fromList(data);

  final Uint8List serverPrefix;
  final Uint8List data;
}

/// A trace came back. [snrs] has one entry per hop: how well that hop
/// heard the trace. [finalSnr] is how well this radio heard the last hop.
final class TraceData extends PushFrame {
  TraceData({
    required this.tag,
    required this.authCode,
    required this.hashBytes,
    required List<int> hashes,
    required this.snrs,
    required this.finalSnr,
  }) : hashes = Uint8List.fromList(hashes);

  final int tag;
  final int authCode;

  /// Bytes in each hop's hash.
  final int hashBytes;
  final Uint8List hashes;
  final List<double> snrs;
  final double finalSnr;
}

/// A raw packet the radio heard, for packet logs.
final class RxLog extends PushFrame {
  RxLog({required this.snr, required this.rssi, required List<int> packet})
    : packet = Uint8List.fromList(packet);

  final double snr;
  final int rssi;
  final Uint8List packet;
}

/// The radio dropped a contact to make room for a new one.
final class ContactDeleted extends PushFrame {
  const ContactDeleted(this.publicKey);

  final PublicKey publicKey;
}

final class ContactsFull extends PushFrame {
  const ContactsFull();
}

/// A frame type this app doesn't handle yet.
final class UnknownFrame extends RadioFrame {
  UnknownFrame(List<int> bytes) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;

  int get code => bytes.isEmpty ? -1 : bytes[0];
}

/// A frame whose type is known but whose contents don't fit that type.
final class MalformedFrame extends RadioFrame {
  MalformedFrame(List<int> bytes, this.reason)
    : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final String reason;
}

/// Decodes one frame from the radio. Never throws: frames that don't parse
/// come back as [MalformedFrame] or [UnknownFrame].
RadioFrame decodeFrame(List<int> frame) {
  final bytes = frame is Uint8List ? frame : Uint8List.fromList(frame);
  if (bytes.isEmpty) return MalformedFrame(bytes, 'empty frame');
  final r = FrameReader(bytes)..skip(1);
  try {
    return switch (bytes[0]) {
      ResponseCode.ok => OkReply(r.remaining >= 4 ? r.u32() : null),
      ResponseCode.error => ErrorReply(
        r.remaining >= 1
            ? RadioErrorCode.fromByte(r.u8())
            : RadioErrorCode.unknown,
      ),
      ResponseCode.disabled => const DisabledReply(),
      ResponseCode.contactsStart => ContactsStart(r.u32()),
      ResponseCode.contact => ContactEntry(_contact(r)),
      ResponseCode.endOfContacts => ContactsEnd(r.u32()),
      ResponseCode.selfInfo => _selfInfo(r),
      ResponseCode.deviceInfo => _deviceInfo(r),
      ResponseCode.sent => SentReply(
        flooded: r.u8() == 1,
        ackCode: r.u32(),
        timeoutMs: r.u32(),
      ),
      ResponseCode.currentTime => CurrentTime(r.u32()),
      ResponseCode.noMoreMessages => const NoMoreMessages(),
      ResponseCode.batteryAndStorage => BatteryAndStorage(
        millivolts: r.u16(),
        usedKb: r.remaining >= 8 ? r.u32() : null,
        totalKb: r.remaining >= 4 ? r.u32() : null,
      ),
      ResponseCode.channelInfo => ChannelInfo(
        index: r.u8(),
        name: r.fixedString(32),
        secret: r.bytes(16),
      ),
      ResponseCode.autoAddConfig => AutoAddConfigReply(
        flags: r.u8(),
        maxHops: r.remaining >= 1 ? r.u8() : 0,
      ),
      ResponseCode.contactMessage => _contactMessage(r, snr: null),
      ResponseCode.contactMessageV3 => _contactMessage(r, snr: _snr(r)),
      ResponseCode.channelMessage => _channelMessage(r, snr: null),
      ResponseCode.channelMessageV3 => _channelMessage(r, snr: _snr(r)),
      ResponseCode.channelData => _channelData(r),
      PushCode.advert => AdvertHeard(PublicKey(r.bytes(publicKeySize))),
      PushCode.newAdvert => NewAdvert(_contact(r)),
      PushCode.pathUpdated => PathUpdated(PublicKey(r.bytes(publicKeySize))),
      PushCode.sendConfirmed => SendConfirmed(
        ackCode: r.u32(),
        roundTripMs: r.u32(),
      ),
      PushCode.messagesWaiting => const MessagesWaiting(),
      PushCode.loginSuccess => _loginSuccess(r),
      PushCode.loginFail => LoginFailed((r..skip(1)).bytes(6)),
      PushCode.statusResponse => StatusResponse(
        serverPrefix: (r..skip(1)).bytes(6),
        data: r.restBytes(),
      ),
      PushCode.rxLog => RxLog(
        snr: r.i8() / 4,
        rssi: r.i8(),
        packet: r.restBytes(),
      ),
      PushCode.traceData => _traceData(r),
      PushCode.contactDeleted => ContactDeleted(
        PublicKey(r.bytes(publicKeySize)),
      ),
      PushCode.contactsFull => const ContactsFull(),
      _ => UnknownFrame(bytes),
    };
  } on FormatException catch (e) {
    return MalformedFrame(bytes, e.message);
  }
}

/// Reads the SNR byte and the two reserved bytes that follow it in v3 frames.
double _snr(FrameReader r) {
  final snr = r.i8() / 4;
  r.skip(2);
  return snr;
}

RadioContact _contact(FrameReader r) {
  final key = PublicKey(r.bytes(publicKeySize));
  final type = NodeType.fromByte(r.u8());
  final flags = r.u8();
  final pathLength = r.u8();
  final path = r.bytes(maxPathSize);
  final name = r.fixedString(32);
  final lastAdvert = r.u32();
  final position = positionFromMicrodegrees(r.i32(), r.i32());
  return RadioContact(
    publicKey: key,
    type: type,
    flags: flags,
    outPathLength: pathLength,
    outPath: path,
    name: name,
    lastAdvert: lastAdvert,
    latitude: position.latitude,
    longitude: position.longitude,
    lastModified: r.u32(),
  );
}

SelfInfo _selfInfo(FrameReader r) {
  final nodeType = NodeType.fromByte(r.u8());
  final txPower = r.i8();
  final maxTxPower = r.i8();
  final key = PublicKey(r.bytes(publicKeySize));
  final position = positionFromMicrodegrees(r.i32(), r.i32());
  final multiAcks = r.u8();
  final locationPolicy = r.u8();
  final telemetry = r.u8();
  final manualAdd = r.u8();
  return SelfInfo(
    nodeType: nodeType,
    txPowerDbm: txPower,
    maxTxPowerDbm: maxTxPower,
    publicKey: key,
    latitude: position.latitude,
    longitude: position.longitude,
    multiAcks: multiAcks,
    advertLocationPolicy: locationPolicy,
    telemetryModes: (
      base: telemetry & 0x03,
      location: (telemetry >> 2) & 0x03,
      environment: (telemetry >> 4) & 0x03,
    ),
    manualAddContacts: manualAdd & 1 == 1,
    frequencyMhz: r.u32() / 1000,
    bandwidthKhz: r.u32() / 1000,
    spreadingFactor: r.u8(),
    codingRate: r.u8(),
    name: r.rest(),
  );
}

DeviceInfo _deviceInfo(FrameReader r) {
  final versionCode = r.u8();
  if (versionCode < 3 || r.remaining < 78) {
    return DeviceInfo(firmwareVersionCode: versionCode);
  }
  return DeviceInfo(
    firmwareVersionCode: versionCode,
    maxContacts: r.u8() * 2,
    maxChannels: r.u8(),
    blePin: r.u32(),
    buildDate: r.fixedString(12),
    manufacturer: r.fixedString(40),
    firmwareVersion: r.fixedString(20),
    clientRepeat: r.remaining >= 1 ? r.u8() == 1 : null,
    pathHashMode: r.remaining >= 1 ? r.u8() : null,
  );
}

ContactMessage _contactMessage(FrameReader r, {required double? snr}) {
  final prefix = r.bytes(6);
  final pathLength = r.u8();
  final type = TextType.fromByte(r.u8());
  final timestamp = r.u32();
  final signer = type == TextType.signedPlain ? r.bytes(4) : null;
  return ContactMessage(
    senderPrefix: prefix,
    pathLength: pathLength,
    type: type,
    timestamp: timestamp,
    text: r.rest(),
    snr: snr,
    signerPrefix: signer,
  );
}

ChannelMessage _channelMessage(FrameReader r, {required double? snr}) {
  final channel = r.u8();
  final pathLength = r.u8();
  r.skip(1); // text type, always plain for channels
  return ChannelMessage(
    channel: channel,
    pathLength: pathLength,
    timestamp: r.u32(),
    text: r.rest(),
    snr: snr,
  );
}

ChannelData _channelData(FrameReader r) {
  final snr = _snr(r);
  final channel = r.u8();
  final pathLength = r.u8();
  final dataType = r.u16();
  final length = r.u8();
  return ChannelData(
    channel: channel,
    pathLength: pathLength,
    dataType: dataType,
    payload: r.bytes(length),
    snr: snr,
  );
}

TraceData _traceData(FrameReader r) {
  r.skip(1); // reserved
  final pathLength = r.u8();
  final flags = r.u8();
  final tag = r.u32();
  final auth = r.u32();
  final hashes = r.bytes(pathLength);
  final hashBytes = 1 << (flags & 0x03);
  final snrs = [for (var i = 0; i < pathLength ~/ hashBytes; i++) r.i8() / 4];
  return TraceData(
    tag: tag,
    authCode: auth,
    hashBytes: hashBytes,
    hashes: hashes,
    snrs: snrs,
    finalSnr: r.i8() / 4,
  );
}

LoginSucceeded _loginSuccess(FrameReader r) {
  final permissions = r.u8();
  final prefix = r.bytes(6);
  if (r.remaining < 6) {
    return LoginSucceeded(permissions: permissions, serverPrefix: prefix);
  }
  return LoginSucceeded(
    permissions: permissions,
    serverPrefix: prefix,
    serverTime: r.u32(),
    aclPermissions: r.u8(),
    serverFirmwareLevel: r.u8(),
  );
}
