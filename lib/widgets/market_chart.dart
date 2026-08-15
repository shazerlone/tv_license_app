import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/pairs.dart';
import '../services/price_service.dart';

/// A clean, native line/area price chart (Exness/Robinhood style) — our own
/// rendering, no third-party chart chrome. Fetches a close series for the
/// given range/interval and draws a smooth area with min/max guides.
class MarketChart extends StatefulWidget {
  final TradingPair pair;
  final String range;
  final String interval;
  final double height;
  const MarketChart({super.key, required this.pair, required this.range, required this.interval, this.height = 260});

  @override
  State<MarketChart> createState() => _MarketChartState();
}

class _MarketChartState extends State<MarketChart> {
  List<double>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MarketChart old) {
    super.didUpdateWidget(old);
    if (old.range != widget.range || old.interval != widget.interval || old.pair.symbol != widget.pair.symbol) {
      setState(() => _loading = true);
      _load();
    }
  }

  Future<void> _load() async {
    final s = await PriceService.series(widget.pair, range: widget.range, interval: widget.interval);
    if (!mounted) return;
    setState(() {
      _data = s;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (_loading) {
      return SizedBox(height: widget.height, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)));
    }
    if (data == null || data.length < 2) {
      return SizedBox(height: widget.height, child: Center(child: Text('Chart unavailable', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))));
    }
    final up = data.last >= data.first;
    final color = up ? AppColors.green : AppColors.red;
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _ChartPainter(
          data: data,
          color: color,
          grid: AppColors.border,
          label: AppColors.textMuted,
          labelStyle: GoogleFonts.robotoMono(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Color grid;
  final Color label;
  final TextStyle labelStyle;
  _ChartPainter({required this.data, required this.color, required this.grid, required this.label, required this.labelStyle});

  @override
  void paint(Canvas canvas, Size size) {
    const rightPad = 52.0; // room for price labels
    final chartW = size.width - rightPad;
    double min = data.first, max = data.first;
    for (final v in data) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final range = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
    final pad = range * 0.08;
    final lo = min - pad, hi = max + pad;
    final span = hi - lo;

    double xAt(int i) => i * (chartW / (data.length - 1));
    double yAt(double v) => size.height - ((v - lo) / span) * size.height;

    // Horizontal grid + price labels (5 lines)
    final gridPaint = Paint()
      ..color = grid.withOpacity(0.6)
      ..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      final v = lo + span * (g / 4);
      final y = yAt(v);
      canvas.drawLine(Offset(0, y), Offset(chartW, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: v >= 100 ? v.toStringAsFixed(2) : v.toStringAsFixed(4), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(chartW + 8, y - tp.height / 2));
    }

    // Line path
    final line = Path();
    for (var i = 0; i < data.length; i++) {
      final x = xAt(i), y = yAt(data[i]);
      i == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
    }
    // Area fill under the line
    final fill = Path.from(line)
      ..lineTo(xAt(data.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.22), color.withOpacity(0.02)],
        ).createShader(Rect.fromLTWH(0, 0, chartW, size.height)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Last-price dot + dashed guide
    final lastX = xAt(data.length - 1), lastY = yAt(data.last);
    final dash = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1;
    for (double x = 0; x < chartW; x += 8) {
      canvas.drawLine(Offset(x, lastY), Offset(x + 4, lastY), dash);
    }
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = color);
    canvas.drawCircle(Offset(lastX, lastY), 4, Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.data != data || old.color != color;
}
