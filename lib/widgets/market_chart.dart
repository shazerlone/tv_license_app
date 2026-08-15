import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/pairs.dart';
import '../services/price_service.dart';

/// A clean, native price chart — our own rendering, no third-party chrome.
/// Supports a line/area view and a candlestick view from one OHLC fetch.
class MarketChart extends StatefulWidget {
  final TradingPair pair;
  final String range;
  final String interval;
  final bool candle; // false = line/area, true = candlesticks
  final double height;
  const MarketChart({super.key, required this.pair, required this.range, required this.interval, this.candle = false, this.height = 260});

  @override
  State<MarketChart> createState() => _MarketChartState();
}

class _MarketChartState extends State<MarketChart> {
  List<Candle>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MarketChart old) {
    super.didUpdateWidget(old);
    // Only refetch when the data set changes (not on a mode toggle).
    if (old.range != widget.range || old.interval != widget.interval || old.pair.symbol != widget.pair.symbol) {
      setState(() => _loading = true);
      _load();
    }
  }

  Future<void> _load() async {
    final s = await PriceService.candles(widget.pair, range: widget.range, interval: widget.interval);
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
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _ChartPainter(
          data: data,
          candle: widget.candle,
          up: AppColors.green,
          down: AppColors.red,
          grid: AppColors.border,
          labelStyle: GoogleFonts.robotoMono(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<Candle> data;
  final bool candle;
  final Color up, down, grid;
  final TextStyle labelStyle;
  _ChartPainter({required this.data, required this.candle, required this.up, required this.down, required this.grid, required this.labelStyle});

  @override
  void paint(Canvas canvas, Size size) {
    const rightPad = 52.0;
    final chartW = size.width - rightPad;

    // Scale: candles use high/low extremes, line uses closes.
    double min = double.infinity, max = -double.infinity;
    for (final c in data) {
      final lo = candle ? c.low : c.close;
      final hi = candle ? c.high : c.close;
      if (lo < min) min = lo;
      if (hi > max) max = hi;
    }
    final range = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
    final pad = range * 0.08;
    final lo = min - pad, hi = max + pad;
    final span = hi - lo;
    double yAt(double v) => size.height - ((v - lo) / span) * size.height;

    // Grid + price labels
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

    if (candle) {
      final slot = chartW / data.length;
      final bodyW = (slot * 0.62).clamp(1.5, 14.0);
      for (var i = 0; i < data.length; i++) {
        final c = data[i];
        final cx = slot * i + slot / 2;
        final col = c.up ? up : down;
        final wick = Paint()
          ..color = col
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(cx, yAt(c.high)), Offset(cx, yAt(c.low)), wick);
        final top = yAt(c.close > c.open ? c.close : c.open);
        final bot = yAt(c.close > c.open ? c.open : c.close);
        final r = Rect.fromLTRB(cx - bodyW / 2, top, cx + bodyW / 2, (bot - top).abs() < 1 ? top + 1 : bot);
        canvas.drawRect(r, Paint()..color = col);
      }
    } else {
      final trendUp = data.last.close >= data.first.close;
      final color = trendUp ? up : down;
      final dx = chartW / (data.length - 1);
      final line = Path();
      for (var i = 0; i < data.length; i++) {
        final x = i * dx, y = yAt(data[i].close);
        i == 0 ? line.moveTo(x, y) : line.lineTo(x, y);
      }
      final fill = Path.from(line)
        ..lineTo((data.length - 1) * dx, size.height)
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
      final lastY = yAt(data.last.close);
      canvas.drawCircle(Offset((data.length - 1) * dx, lastY), 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.data != data || old.candle != candle;
}
