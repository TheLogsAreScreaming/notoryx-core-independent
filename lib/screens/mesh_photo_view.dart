import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/connection.dart';
import '../data/data.dart';
import '../l10n/l10n.dart';
import '../radio/protocol/mesh_photo.dart';

final _photoProvider =
    StreamProvider.family<List<PhotoChunk>, ({String radioKey, int id})>(
      (ref, p) => ref.watch(storeProvider).watchPhoto(p.radioKey, p.id),
    );

/// A mesh photo, or how many of its pieces have arrived.
class MeshPhotoView extends ConsumerWidget {
  const MeshPhotoView({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radioKey = ref.watch(radioKeyProvider) ?? '';
    final chunks =
        ref.watch(_photoProvider((radioKey: radioKey, id: id))).value ??
        const <PhotoChunk>[];
    final style = Theme.of(context).textTheme.bodySmall;
    if (chunks.isEmpty) return Text(context.l10n.photoWaiting, style: style);
    final count = chunks.first.count;
    final photo = assemblePhoto({for (final c in chunks) c.idx: c.data}, count);
    if (photo == null) {
      return Text(
        context.l10n.photoArriving(chunks.length, count),
        style: style,
      );
    }
    return Semantics(
      image: true,
      label: context.l10n.photo,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          photo,
          width: 192,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) =>
              Text(context.l10n.photoWaiting, style: style),
        ),
      ),
    );
  }
}
