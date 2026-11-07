import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/quick_messages.dart';

/// What the person picked in the quick message sheet.
typedef QuickPick = ({String text, bool edit});

/// Lists the quick messages. Tapping one sends it; the pencil puts it in
/// the box to change first. Null if nothing was picked.
Future<QuickPick?> showQuickMessagePicker(BuildContext context) =>
    showModalBottomSheet<QuickPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _Picker(),
    );

class _Picker extends ConsumerWidget {
  const _Picker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(quickMessagesProvider).value ?? const <String>[];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick messages',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const QuickMessagesScreen(),
                        ),
                      );
                    },
                    child: const Text('Edit list'),
                  ),
                ],
              ),
            ),
            if (items.isEmpty)
              const ListTile(title: Text('No quick messages. Tap Edit list.')),
            for (final text in items)
              ListTile(
                title: Text(text),
                onTap: () => Navigator.pop<QuickPick>(context, (
                  text: text,
                  edit: false,
                )),
                trailing: IconButton(
                  tooltip: 'Change before sending',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.pop<QuickPick>(context, (
                    text: text,
                    edit: true,
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Add, change, reorder and remove quick messages.
class QuickMessagesScreen extends ConsumerWidget {
  const QuickMessagesScreen({super.key});

  Future<String?> _ask(BuildContext context, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial.isEmpty ? 'New quick message' : 'Change message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(quickMessagesProvider).value ?? const <String>[];
    final quick = ref.read(quickMessagesProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick messages'),
        actions: [
          PopupMenuButton<void>(
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: quick.reset,
                child: const Text('Reset to the starting list'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () async {
          final text = await _ask(context);
          if (text != null) await quick.add(text);
        },
      ),
      body: items.isEmpty
          ? const Center(child: Text('No quick messages yet.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: items.length,
              buildDefaultDragHandles: false,
              onReorderItem: quick.move,
              itemBuilder: (context, i) => ListTile(
                key: ValueKey(items[i]),
                title: Text(items[i]),
                onTap: () async {
                  final text = await _ask(context, initial: items[i]);
                  if (text != null) await quick.edit(i, text);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Remove ${items[i]}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => quick.remove(i),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle, semanticLabel: 'Move'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
