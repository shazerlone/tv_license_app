import 'package:flutter/material.dart';

/// A tiny, axis-less trend line (intraday closes). Green when the last point is
/// above the first, red otherwise — the classic terminal watchlist mini-chart.
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double width;
  final double height;
  const Sparkline({super.key, required this.data, required this.color, this.width = 64, this.height = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(data, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    double min = data.first, max = data.first;
    for (final v in data) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final range = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
    final dx = size.width / (data.length - 1);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - ((data[i] - min) / range) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    // Soft gradient fill under the line.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.22), color.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.data != data || old.color != color;
}
