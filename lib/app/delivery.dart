import '../data/data.dart';
import '../radio/radio.dart';

/// A plain-language account of where a sent message got to, and why.
typedef DeliveryReport = ({String headline, List<String> details});

/// Explains [message]'s delivery from what the app recorded: its status,
/// how many tries it took or used, whether the last one flooded, and the
/// route the radio knows to [contact].
DeliveryReport deliveryReport(
  Message message, {
  required bool retrying,
  Contact? contact,
  RetryPolicy policy = const RetryPolicy(),
}) {
  if (message.kind == MessageKind.channel) {
    return (
      headline: switch (message.status) {
        MessageStatus.failed => 'The radio didn’t send it',
        MessageStatus.pending => 'Waiting for the radio',
        _ => 'Sent to the channel',
      },
      details: const [
        'Channel messages have no delivery confirmation. Anyone on the '
            'channel within reach of you or a repeater can read them.',
      ],
    );
  }

  final tries = message.attempts;
  final triesText = tries == 1 ? '1 try' : '$tries tries';
  final name = contact?.name ?? 'They';
  final route = switch (contact?.outPathLength) {
    null => null,
    pathUnknown => 'No known route to $name: messages flood the mesh.',
    final len =>
      'Known route to ${contact!.name}: '
          '${(len & 0x3F) == 0 ? 'direct' : '${len & 0x3F} hops'}.',
  };
  final total = policy.directAttempts + policy.floodAttempts;

  switch (message.status) {
    case MessageStatus.delivered:
      return (
        headline: 'Delivered after $triesText',
        details: [
          if (message.flooded == true)
            'The last try went by flood, so the route was found again.'
          else if (tries > 1)
            'Earlier tries weren’t confirmed; a later one got through.',
          ?route,
        ],
      );
    case MessageStatus.pending:
      return (headline: 'Waiting for the radio', details: [?route]);
    case MessageStatus.sent when retrying:
      return (
        headline: 'Not confirmed yet: $triesText so far, up to $total',
        details: [
          message.flooded == true
              ? 'Now flooding the mesh to find a way through.'
              : 'Trying the known route first, then flooding.',
          ?route,
        ],
      );
    case MessageStatus.sent:
      return (
        headline: 'Sent, never confirmed',
        details: [
          'The app stopped watching for a confirmation (it may have been '
              'closed). It may still have arrived.',
          ?route,
        ],
      );
    case MessageStatus.failed when tries == 0:
      return (
        headline: 'The radio didn’t send it',
        details: const [
          'It was refused before going out, usually because the radio was '
              'busy or disconnected. Sending again normally works.',
        ],
      );
    case MessageStatus.failed:
      return (
        headline: 'No confirmation after $triesText',
        details: [
          'Common reasons:',
          '• $name hasn’t added you as a contact. Their radio ignores '
              'direct messages from people it doesn’t know. Sending your '
              'advert across the mesh lets them add you.',
          '• Their radio is off or out of reach of every repeater.',
          '• The route changed. Resetting it makes the next try flood.',
          ?route,
        ],
      );
    case MessageStatus.received:
      return (headline: 'Received', details: const []);
  }
}
