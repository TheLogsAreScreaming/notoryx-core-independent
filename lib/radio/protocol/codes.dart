/// Byte values of the MeshCore companion protocol, as defined by the
/// companion firmware (`examples/companion_radio/MyMesh.cpp`, v1.18).
library;

/// First byte of a frame the app sends to the radio.
abstract final class CommandCode {
  static const appStart = 1;
  static const sendTextMessage = 2;
  static const sendChannelText = 3;
  static const getContacts = 4;
  static const getDeviceTime = 5;
  static const setDeviceTime = 6;
  static const sendSelfAdvert = 7;
  static const setAdvertName = 8;
  static const addUpdateContact = 9;
  static const syncNextMessage = 10;
  static const setRadioParams = 11;
  static const setTxPower = 12;
  static const resetPath = 13;
  static const setAdvertLatLon = 14;
  static const removeContact = 15;
  static const reboot = 19;
  static const getBatteryAndStorage = 20;
  static const deviceQuery = 22;
  static const sendLogin = 26;
  static const sendStatusRequest = 27;
  static const hasConnection = 28;
  static const logout = 29;
  static const getChannel = 31;
  static const setChannel = 32;
  static const sendTracePath = 36;
  static const setOtherParams = 38;
  static const sendTelemetryRequest = 39;
  static const getStats = 56;
  static const runCliCommand = 66;
  static const setAutoAddConfig = 58;
  static const getAutoAddConfig = 59;
}

/// First byte of a direct reply to a command.
/// Groups of figures [CommandCode.getStats] can ask for.
abstract final class StatsGroup {
  static const core = 0;
  static const radio = 1;
  static const packets = 2;
}

abstract final class ResponseCode {
  static const ok = 0;
  static const error = 1;
  static const contactsStart = 2;
  static const contact = 3;
  static const endOfContacts = 4;
  static const selfInfo = 5;
  static const sent = 6;
  static const contactMessage = 7;
  static const channelMessage = 8;
  static const currentTime = 9;
  static const noMoreMessages = 10;
  static const batteryAndStorage = 12;
  static const deviceInfo = 13;
  static const disabled = 15;
  static const contactMessageV3 = 16;
  static const channelMessageV3 = 17;
  static const channelInfo = 18;
  static const stats = 24;
  static const autoAddConfig = 25;
  static const channelData = 27;
  static const cliReply = 29;
}

/// First byte of a notification the radio sends on its own.
abstract final class PushCode {
  static const advert = 0x80;
  static const pathUpdated = 0x81;
  static const sendConfirmed = 0x82;
  static const messagesWaiting = 0x83;
  static const loginSuccess = 0x85;
  static const loginFail = 0x86;
  static const statusResponse = 0x87;
  static const rxLog = 0x88;
  static const traceData = 0x89;
  static const newAdvert = 0x8A;
  static const telemetryResponse = 0x8B;
  static const contactDeleted = 0x8F;
  static const contactsFull = 0x90;
}

/// Reasons carried by a [ResponseCode.error] frame.
enum RadioErrorCode {
  unsupportedCommand(1),
  notFound(2),
  tableFull(3),
  badState(4),
  fileIo(5),
  illegalArgument(6),
  unknown(-1);

  const RadioErrorCode(this.value);

  final int value;

  static RadioErrorCode fromByte(int byte) => values.firstWhere(
    (code) => code.value == byte,
    orElse: () => RadioErrorCode.unknown,
  );
}

/// The kind of text in a direct message.
enum TextType {
  plain(0),
  cliData(1),
  signedPlain(2),
  cliCommand(3),
  unknown(-1);

  const TextType(this.value);

  final int value;

  static TextType fromByte(int byte) => values.firstWhere(
    (type) => type.value == byte,
    orElse: () => TextType.unknown,
  );
}

/// What a node announces itself as in its advert.
enum NodeType {
  none(0),
  chat(1),
  repeater(2),
  room(3),
  sensor(4),
  unknown(-1);

  const NodeType(this.value);

  final int value;

  static NodeType fromByte(int byte) => values.firstWhere(
    (type) => type.value == byte,
    orElse: () => NodeType.unknown,
  );
}

/// Protocol version this app understands, sent in [CommandCode.deviceQuery].
/// Version 3 and later get message frames that include SNR.
const appProtocolVersion = 3;

/// Largest frame either side will send.
const maxFrameSize = 176;

/// Size of a node's Ed25519 public key.
const publicKeySize = 32;

/// Size of a contact's stored route.
const maxPathSize = 64;

/// Path length byte meaning "no known route" (or "arrived direct" on receive).
const pathUnknown = 0xFF;
