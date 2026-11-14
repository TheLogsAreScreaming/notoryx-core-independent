import 'package:flutter/material.dart';

import '../app/node_journal.dart';

/// A node's generated mark, drawn from its key. Decorative: screen
/// readers skip it, since the node's name is always next to it.
class NodeMarkView extends StatelessWidget {
  const NodeMarkView({required this.publicKey, this.size = 40, super.key});

  final String publicKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = nodeMark(publicKey);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _MarkPainter(mark, dark)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.mark, this.dark);

  final NodeMark mark;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final background = HSLColor.fromAHSL(
      1,
      mark.accentHue,
      0.35,
      dark ? 0.22 : 0.9,
    ).toColor();
    final fill = HSLColor.fromAHSL(
      1,
      mark.hue,
      0.6,
      dark ? 0.65 : 0.38,
    ).toColor();
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * 0.22),
    );
    canvas.drawRRect(r, Paint()..color = background);
    final pad = size.width * 0.14;
    final cell = (size.width - 2 * pad) / 5;
    final paint = Paint()..color = fill;
    for (var i = 0; i < 25; i++) {
      if (!mark.cells[i]) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          pad + (i % 5) * cell,
          pad + (i ~/ 5) * cell,
          cell + 0.5,
          cell + 0.5,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.mark != mark || old.dark != dark;
}
