import 'package:notoryx_core/app/notifications.dart';

/// Records notifications instead of showing them.
class FakeNotifier implements MessageNotifier {
  final shown = <({String title, String body, ChatLink chat})>[];
  void Function(ChatLink chat)? onOpen;

  @override
  Future<ChatLink?> init(void Function(ChatLink chat) onOpen) async {
    this.onOpen = onOpen;
    return null;
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required ChatLink chat,
  }) async => shown.add((title: title, body: body, chat: chat));
}
