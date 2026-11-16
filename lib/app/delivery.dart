import '../data/data.dart';
import '../l10n/l10n.dart';
import '../radio/radio.dart';

/// A plain-language account of where a sent message got to, and why.
typedef DeliveryReport = ({String headline, List<String> details});

/// Explains [message]'s delivery from what the app recorded: its status,
/// how many tries it took or used, whether the last one flooded, and the
/// route the radio knows to [contact].
DeliveryReport deliveryReport(
  Message message, {
  required AppLocalizations l10n,
  required bool retrying,
  Contact? contact,
  RetryPolicy policy = const RetryPolicy(),
}) {
  if (message.kind == MessageKind.channel) {
    return (
      headline: switch (message.status) {
        MessageStatus.failed => l10n.deliveryRadioDidntSend,
        MessageStatus.pending => l10n.deliveryWaitingForRadio,
        _ => l10n.deliverySentToChannel,
      },
      details: [l10n.deliveryChannelNoConfirmation],
    );
  }

  final tries = message.attempts;
  final triesText = l10n.deliveryTries(tries);
  final name = contact?.name ?? l10n.deliveryThey;
  final route = switch (contact?.outPathLength) {
    null => null,
    pathUnknown => l10n.deliveryNoKnownRoute(name),
    final len => l10n.deliveryKnownRoute(contact!.name, len & 0x3F),
  };
  final total = policy.directAttempts + policy.floodAttempts;

  switch (message.status) {
    case MessageStatus.delivered:
      return (
        headline: l10n.deliveryDeliveredAfter(triesText),
        details: [
          if (message.flooded == true)
            l10n.deliveryLastTryFlooded
          else if (tries > 1)
            l10n.deliveryLaterTryGotThrough,
          ?route,
        ],
      );
    case MessageStatus.pending:
      return (headline: l10n.deliveryWaitingForRadio, details: [?route]);
    case MessageStatus.sent when retrying:
      return (
        headline: l10n.deliveryNotConfirmedYet(triesText, total),
        details: [
          message.flooded == true
              ? l10n.deliveryNowFlooding
              : l10n.deliveryTryingKnownRoute,
          ?route,
        ],
      );
    case MessageStatus.sent:
      return (
        headline: l10n.deliverySentNeverConfirmed,
        details: [l10n.deliveryStoppedWatching, ?route],
      );
    case MessageStatus.failed when tries == 0:
      return (
        headline: l10n.deliveryRadioDidntSend,
        details: [l10n.deliveryRefusedBeforeGoingOut],
      );
    case MessageStatus.failed:
      return (
        headline: l10n.deliveryNoConfirmationAfter(triesText),
        details: [
          l10n.deliveryCommonReasons,
          l10n.deliveryReasonNotAdded(name),
          l10n.deliveryReasonOffOrOutOfReach,
          l10n.deliveryReasonRouteChanged,
          ?route,
        ],
      );
    case MessageStatus.received:
      return (headline: l10n.receivedStatus, details: const []);
  }
}
