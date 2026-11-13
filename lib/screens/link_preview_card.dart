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
    final image = isImageLink(widget.url);
    if (!auto && !_asked) {
      return ActionChip(
        avatar: Icon(image ? Icons.image_outlined : Icons.link, size: 18),
        label: Text(image ? context.l10n.showImage : context.l10n.showPreview),
        onPressed: () => setState(() => _asked = true),
      );
    }
    final theme = Theme.of(context);
    if (image) {
      return switch (ref.watch(linkImageProvider(widget.url))) {
        AsyncData(value: final bytes?) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 260),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                semanticLabel: context.l10n.photo,
                errorBuilder: (_, _, _) => Text(
                  context.l10n.imageUnavailable,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ),
        AsyncLoading() => Text(
          context.l10n.loadingPreview,
          style: theme.textTheme.bodySmall,
        ),
        _ => Text(
          context.l10n.imageUnavailable,
          style: theme.textTheme.bodySmall,
        ),
      };
    }
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
