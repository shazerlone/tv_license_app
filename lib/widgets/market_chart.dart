import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/pairs.dart';
import '../services/price_service.dart';

/// A clean, native price chart — our own rendering, no third-party chrome.
/// Supports a line/area view and a candlestick view from one OHLC fetch, is
/// pinch-to-zoom + drag-to-pan (like a real broker terminal), and can overlay a
/// moving average plus a live price line.
class MarketChart extends StatefulWidget {
  final TradingPair pair;
  final String range;
  final String interval;
  final bool candle; // false = line/area, true = candlesticks
  final bool showMa; // overlay a 20-period moving average
  final double height;
  const MarketChart({
    super.key,
    required this.pair,
    required this.range,
    required this.interval,
    this.candle = false,
    this.showMa = false,
    this.height = 260,
  });

  @override
  State<MarketChart> createState() => _MarketChartState();
}

class _MarketChartState extends State<MarketChart> {
  List<Candle>? _data;
  bool _loading = true;

  // Viewport into the data: _count candles starting at _start are visible.
  // _count shrinks on zoom-in; _start slides on pan. Both re-derive on new data.
  double _start = 0;
  double _count = 0;
  double _width = 0; // plot width captured at layout, for px->candle math

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MarketChart old) {
    super.didUpdateWidget(old);
    // Only refetch when the data set changes (not on a mode/overlay toggle).
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
      _count = (s?.length ?? 0).toDouble();
      _start = 0;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails d, int total) {
    final slot = _width <= 0 || _count <= 0 ? 1.0 : _width / _count;
    setState(() {
      if (d.pointerCount <= 1) {
        _start = (_start - d.focalPointDelta.dx / slot);
      }
      if (d.scale != 1.0 && _width > 0) {
        final focalCandle = _start + (d.localFocalPoint.dx / _width) * _count;
        final newCount = (_count / d.scale).clamp(12.0, total.toDouble());
        _start = focalCandle - (d.localFocalPoint.dx / _width) * newCount;
        _count = newCount;
      }
      _start = _start.clamp(0.0, (total - _count).clamp(0.0, total.toDouble()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (_loading) {
      return SizedBox(height: widget.height, child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary)));
    }
    if (data == null || data.length < 2) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.show_chart_rounded, size: 30, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text('Chart data unavailable', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text('Try another timeframe', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ]),
        ),
      );
    }
    final total = data.length;
    if (_count <= 0) _count = total.toDouble();
    final startI = _start.floor().clamp(0, total - 2);
    final endI = (_start + _count).ceil().clamp(startI + 2, total);
    final visible = data.sublist(startI, endI);

    // Readout for the visible window (updates as you zoom/pan).
    double vHi = -double.infinity, vLo = double.infinity;
    for (final c in visible) {
      if (c.high > vHi) vHi = c.high;
      if (c.low < vLo) vLo = c.low;
    }
    final last = visible.last.close;
    final first = visible.first.close;
    final chg = first == 0 ? 0.0 : (last - first) / first * 100;
    final up = chg >= 0;
    String f(double v) => v >= 100 ? v.toStringAsFixed(2) : v.toStringAsFixed(4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live readout strip
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Row(
            children: [
              Text(f(last), style: GoogleFonts.robotoMono(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: (up ? AppColors.green : AppColors.red).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text('${up ? '+' : ''}${chg.toStringAsFixed(2)}%',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: up ? AppColors.green : AppColors.red)),
              ),
              const Spacer(),
              _miniStat('H', f(vHi)),
              const SizedBox(width: 12),
              _miniStat('L', f(vLo)),
            ],
          ),
        ),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, c) {
              const rightPad = 52.0;
              _width = c.maxWidth - rightPad;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleUpdate: (d) => _onScaleUpdate(d, total),
                onDoubleTap: () => setState(() {
                  _count = total.toDouble();
                  _start = 0;
                }),
                child: CustomPaint(
                  painter: _ChartPainter(
                    data: visible,
                    candle: widget.candle,
                    showMa: widget.showMa,
                    up: AppColors.green,
                    down: AppColors.red,
                    grid: AppColors.border,
                    maColor: AppColors.primary,
                    labelStyle: GoogleFonts.robotoMono(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    lastPillStyle: GoogleFonts.robotoMono(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String k, String v) => Row(children: [
        Text('$k ', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
        Text(v, style: GoogleFonts.robotoMono(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ]);
}

class _ChartPainter extends CustomPainter {
  final List<Candle> data;
  final bool candle;
  final bool showMa;
  final Color up, down, grid, maColor;
  final TextStyle labelStyle;
  final TextStyle lastPillStyle;
  _ChartPainter({
    required this.data,
    required this.candle,
    required this.showMa,
    required this.up,
    required this.down,
    required this.grid,
    required this.maColor,
    required this.labelStyle,
    required this.lastPillStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const rightPad = 52.0;
    final chartW = size.width - rightPad;

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
    }

    // Moving-average overlay (20-period simple MA on closes).
    if (showMa && data.length >= 5) {
      const period = 20;
      final dx = chartW / (data.length - 1);
      final maPath = Path();
      var started = false;
      double sum = 0;
      for (var i = 0; i < data.length; i++) {
        sum += data[i].close;
        if (i >= period) sum -= data[i - period].close;
        final w = i < period ? i + 1 : period;
        final ma = sum / w;
        final x = i * dx, y = yAt(ma);
        if (!started) {
          maPath.moveTo(x, y);
          started = true;
        } else {
          maPath.lineTo(x, y);
        }
      }
      canvas.drawPath(
        maPath,
        Paint()
          ..color = maColor.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // Live price line + pill at the last close.
    final lastV = data.last.close;
    final ly = yAt(lastV);
    final lineColor = data.last.close >= data.first.close ? up : down;
    final dashPaint = Paint()
      ..color = lineColor.withOpacity(0.7)
      ..strokeWidth = 1;
    for (double x = 0; x < chartW; x += 8) {
      canvas.drawLine(Offset(x, ly), Offset(x + 4, ly), dashPaint);
    }
    final pill = TextPainter(
      text: TextSpan(text: lastV >= 100 ? lastV.toStringAsFixed(2) : lastV.toStringAsFixed(4), style: lastPillStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final pillRect = Rect.fromLTWH(chartW + 4, ly - pill.height / 2 - 3, rightPad - 4, pill.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(pillRect, const Radius.circular(3)), Paint()..color = lineColor);
    pill.paint(canvas, Offset(chartW + 6, ly - pill.height / 2));
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.data != data || old.candle != candle || old.showMa != showMa;
}
