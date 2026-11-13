import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/link_preview.dart';
import '../l10n/l10n.dart';

/// A web link's title and summary, loaded only when asked unless
/// automatic previews are on.
class LinkPreviewCard extends ConsumerStatefulWidget {
  const LinkPreviewCard({required this.url, super.key});

  final String url;

  @override
  ConsumerState<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends ConsumerState<LinkPreviewCard> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final auto = ref.watch(linkPreviewsAutoProvider).value ?? false;
    if (!auto && !_asked) {
      return ActionChip(
        avatar: const Icon(Icons.link, size: 18),
        label: Text(context.l10n.showPreview),
        onPressed: () => setState(() => _asked = true),
      );
    }
    final theme = Theme.of(context);
    return switch (ref.watch(linkPreviewProvider(widget.url))) {
      AsyncData(value: final p?) => Card(
        margin: const EdgeInsets.only(top: 4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.site, style: theme.textTheme.labelSmall),
              Text(p.title, style: theme.textTheme.titleSmall),
              if (p.description case final d?)
                Text(d, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
      AsyncLoading() => Text(
        context.l10n.loadingPreview,
        style: theme.textTheme.bodySmall,
      ),
      _ => Text(context.l10n.noPreview, style: theme.textTheme.bodySmall),
    };
  }
}
