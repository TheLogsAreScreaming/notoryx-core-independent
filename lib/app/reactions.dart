/// Reactions and replies, carried as ordinary text so every MeshCore app
/// shows something sensible and nothing new goes over the air.
///
/// - A **reply** starts with a mention, `@[Name] `, the form chat apps
///   already use to address someone. It is shown under the newest earlier
///   message from that person.
/// - A **reaction** is `<emoji> re "<start of the message>"`. It is shown
///   as a count on the message whose text starts that way, instead of as a
///   message of its own.
///
/// Both are worked out from the stored text when a chat is shown, so older
/// history and messages from other apps are understood too.
library;

// Flutter re-exports package:characters.
import 'package:flutter/widgets.dart' show StringCharacters;

import '../data/data.dart';

/// The reactions offered when holding a message.
const quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// How many characters of the original a reaction quotes.
const reactionQuoteLength = 24;

/// The text sent to react with [emoji] to a message reading [body].
String reactionText(String emoji, String body) {
  final flat = _flatten(body);
  final chars = flat.characters;
  final quote = chars.length > reactionQuoteLength
      ? '${chars.take(reactionQuoteLength)}…'
      : flat;
  return '$emoji re "$quote"';
}

/// The text sent to reply to [name] with [text].
String replyText(String name, String text) => '${mention(name)} $text';

/// How a name is written in a mention.
String mention(String name) => '@[$name]';

/// A reaction found in a message's text.
final class ParsedReaction {
  const ParsedReaction(this.emoji, this.quote, {required this.cut});

  final String emoji;

  /// The start of the message it reacts to.
  final String quote;

  /// Whether [quote] is only the start of a longer text.
  final bool cut;

  /// Whether [body] is the message this reacts to.
  bool matches(String body) {
    final flat = _flatten(body);
    return cut ? flat.startsWith(quote) : flat == quote;
  }
}

final _reaction = RegExp(r'^(\S{1,16}) re "(.*)"$', dotAll: true);
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The reaction [body] carries, or null when it is an ordinary message.
ParsedReaction? parseReaction(String body) {
  final match = _reaction.firstMatch(body.trim());
  if (match == null) return null;
  final emoji = match.group(1)!;
  // A word such as `ok re "…"` is a message, not a reaction.
  if (emoji.characters.length > 2 || _letterOrDigit.hasMatch(emoji)) {
    return null;
  }
  var quote = match.group(2)!;
  final cut = quote.endsWith('…');
  if (cut) quote = quote.substring(0, quote.length - 1);
  if (quote.isEmpty) return null;
  return ParsedReaction(emoji, quote, cut: cut);
}

final _mentionStart = RegExp(r'^@\[([^\]]{1,32})\]\s+(.*)$', dotAll: true);

/// The name [body] starts by mentioning, and the rest of the text.
({String name, String text})? parseReply(String body) {
  final match = _mentionStart.firstMatch(body);
  if (match == null) return null;
  final text = match.group(2)!.trim();
  if (text.isEmpty) return null;
  return (name: match.group(1)!, text: text);
}

String _flatten(String body) => body.replaceAll(RegExp(r'\s+'), ' ').trim();

/// How many people reacted with one emoji, and whether this phone did.
final class ReactionCount {
  ReactionCount(this.emoji);

  final String emoji;
  final List<String> who = [];
  bool mine = false;

  int get count => who.length;
}

/// One message as a chat shows it.
final class ChatItem {
  ChatItem(this.message, {this.replyTo, this.replyText});

  final Message message;

  /// The earlier message this one answers, when it is a reply.
  final Message? replyTo;

  /// A reply's text without the leading mention.
  final String? replyText;

  /// Reactions to this message, in the order they first arrived.
  final List<ReactionCount> reactions = [];
}

/// Groups a conversation (oldest first) for display: reactions are folded
/// into the message they react to, and replies are linked to what they
/// answer. [senderOf] names who sent a message, as mentions would.
List<ChatItem> chatItems(
  List<Message> messages, {
  required String Function(Message) senderOf,
}) {
  final items = <ChatItem>[];
  for (final message in messages) {
    final reaction = parseReaction(message.body);
    if (reaction != null) {
      final target = _reactionTarget(items, reaction);
      if (target != null) {
        final counts = target.reactions;
        var entry = counts.where((r) => r.emoji == reaction.emoji).firstOrNull;
        if (entry == null) counts.add(entry = ReactionCount(reaction.emoji));
        entry.who.add(senderOf(message));
        if (message.outgoing) entry.mine = true;
        continue;
      }
    }
    final reply = parseReply(message.body);
    Message? answered;
    if (reply != null) {
      for (final earlier in items.reversed) {
        if (senderOf(earlier.message) == reply.name) {
          answered = earlier.message;
          break;
        }
      }
    }
    items.add(
      ChatItem(
        message,
        replyTo: answered,
        replyText: answered == null ? null : reply!.text,
      ),
    );
  }
  return items;
}

/// Reactions only reach back this far, so a short quote such as "OK" lands
/// on a recent message rather than one from last week.
const _reactionReach = 200;

ChatItem? _reactionTarget(List<ChatItem> items, ParsedReaction reaction) {
  final start = items.length > _reactionReach
      ? items.length - _reactionReach
      : 0;
  for (var i = items.length - 1; i >= start; i--) {
    final body = items[i].replyText ?? items[i].message.body;
    if (reaction.matches(body) || reaction.matches(items[i].message.body)) {
      return items[i];
    }
  }
  return null;
}
