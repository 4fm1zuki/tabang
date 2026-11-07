import 'package:flutter/material.dart';

/// Deterministic Code-128-style bar pattern. It is decorative but stable, so
/// staff can visually distinguish a bag number from the printed label without
/// pretending to encode a real symbology.
///
/// The barcode graphic belongs to the administrative inventory only. Public
/// screens identify a unit by its printed ID, which is what a donor can
/// actually read off the bag.
class BarcodePainter extends CustomPainter {
  const BarcodePainter({required this.data, required this.color});

  final String data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final barWidth = size.height < 26 ? 1.0 : 1.35;
    var x = 0.0;
    var index = 0;
    while (x < size.width - 2 && data.isNotEmpty) {
      final code = data.codeUnitAt(index % data.length);
      final bars = 2 + (code % 3);
      for (var j = 0; j < bars && x < size.width - 2; j++) {
        final on = ((code >> (j % 6)) & 1) == 1;
        final w = (j == 0 ? 1.8 : 1.0) * barWidth;
        if (on) {
          canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
        }
        x += w + barWidth * 0.7;
      }
      x += barWidth;
      index++;
    }
  }

  @override
  bool shouldRepaint(BarcodePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

/// A [BarcodePainter] with the unit ID printed underneath it.
class UnitBarcode extends StatelessWidget {
  const UnitBarcode(
    this.data, {
    super.key,
    this.width = 200,
    this.height = 34,
    this.captionSize = 12.5,
  });

  final String data;
  final double width;
  final double height;
  final double captionSize;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFBF5F2)
        : const Color(0xFF1E1715);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: BarcodePainter(data: data, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data,
          style: TextStyle(
            fontSize: captionSize,
            letterSpacing: 1.4,
            fontFamily: 'monospace',
            color: muted,
          ),
        ),
      ],
    );
  }
}
