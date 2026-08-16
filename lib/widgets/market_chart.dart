import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/pairs.dart';
import '../models/indicator_config.dart';
import '../services/price_service.dart';
import '../services/indicators.dart';

/// A clean, native price chart — our own rendering, no third-party chrome.
/// Line/area or candlesticks from one OHLC fetch, pinch-to-zoom + drag-to-pan,
/// with configurable indicators: MA/EMA overlays and RSI/MACD sub-panes.
class MarketChart extends StatefulWidget {
  final TradingPair pair;
  final String range;
  final String interval;
  final bool candle;
  final IndicatorConfig indicators;
  final double height;
  const MarketChart({
    super.key,
    required this.pair,
    required this.range,
    required this.interval,
    this.candle = false,
    required this.indicators,
    this.height = 260,
  });

  @override
  State<MarketChart> createState() => _MarketChartState();
}

class _MarketChartState extends State<MarketChart> {
  List<Candle>? _data;
  bool _loading = true;

  double _start = 0;
  double _count = 0;
  double _width = 0;

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

  List<double?> _slice(List<double?> full, int a, int b) => full.sublist(a, b);

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
    final cfg = widget.indicators;

    // Compute indicators on the FULL series (so warm-up is correct), then slice.
    final closes = [for (final c in data) c.close];
    List<double?>? maSeg, emaSeg, rsiSeg;
    (List<double?>, List<double?>, List<double?>)? macdSeg;
    if (cfg.maOn) maSeg = _slice(Indicators.sma(closes, cfg.maPeriod), startI, endI);
    if (cfg.emaOn) emaSeg = _slice(Indicators.ema(closes, cfg.emaPeriod), startI, endI);
    if (cfg.rsiOn) rsiSeg = _slice(Indicators.rsi(closes, cfg.rsiPeriod), startI, endI);
    if (cfg.macdOn) {
      final m = Indicators.macd(closes, cfg.macdFast, cfg.macdSlow, cfg.macdSignal);
      macdSeg = (_slice(m.$1, startI, endI), _slice(m.$2, startI, endI), _slice(m.$3, startI, endI));
    }

    // Visible-window readout.
    double vHi = -double.infinity, vLo = double.infinity;
    for (final c in visible) {
      if (c.high > vHi) vHi = c.high;
      if (c.low < vLo) vLo = c.low;
    }
    final last = visible.last.close, first = visible.first.close;
    final chg = first == 0 ? 0.0 : (last - first) / first * 100;
    final up = chg >= 0;
    String f(double v) => v >= 100 ? v.toStringAsFixed(2) : v.toStringAsFixed(4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    maSeg: maSeg,
                    emaSeg: emaSeg,
                    rsiSeg: rsiSeg,
                    rsiPeriod: cfg.rsiPeriod,
                    macdSeg: macdSeg,
                    up: AppColors.green,
                    down: AppColors.red,
                    grid: AppColors.border,
                    maColor: AppColors.primary,
                    emaColor: AppColors.purple,
                    labelStyle: GoogleFonts.robotoMono(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    tagStyle: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.textMuted),
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
  final List<double?>? maSeg, emaSeg, rsiSeg;
  final int rsiPeriod;
  final (List<double?>, List<double?>, List<double?>)? macdSeg;
  final Color up, down, grid, maColor, emaColor;
  final TextStyle labelStyle, tagStyle, lastPillStyle;
  _ChartPainter({
    required this.data,
    required this.candle,
    required this.maSeg,
    required this.emaSeg,
    required this.rsiSeg,
    required this.rsiPeriod,
    required this.macdSeg,
    required this.up,
    required this.down,
    required this.grid,
    required this.maColor,
    required this.emaColor,
    required this.labelStyle,
    required this.tagStyle,
    required this.lastPillStyle,
  });

  static const _rightPad = 52.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _rightPad;
    final subCount = (rsiSeg != null ? 1 : 0) + (macdSeg != null ? 1 : 0);
    const paneGap = 12.0;
    final subH = subCount > 0 ? 76.0 : 0.0;
    final priceH = (size.height - subCount * (subH + paneGap)).clamp(80.0, size.height);

    _paintPrice(canvas, chartW, priceH);

    double y = priceH + paneGap;
    if (rsiSeg != null) {
      _paintRsi(canvas, chartW, y, subH);
      y += subH + paneGap;
    }
    if (macdSeg != null) {
      _paintMacd(canvas, chartW, y, subH);
    }
  }

  void _dashedH(Canvas canvas, double x0, double x1, double y, Paint p) {
    for (double x = x0; x < x1; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), p);
    }
  }

  void _label(Canvas canvas, String text, double x, double y, {TextStyle? style}) {
    final tp = TextPainter(text: TextSpan(text: text, style: style ?? labelStyle), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, Offset(x, y));
  }

  void _line(Canvas canvas, List<double?> seg, double chartW, double top, double h, double lo, double span, Color color, double stroke) {
    if (seg.length < 2 || span <= 0) return;
    final dx = chartW / (seg.length - 1);
    final path = Path();
    var started = false;
    for (var i = 0; i < seg.length; i++) {
      final v = seg[i];
      if (v == null) continue;
      final x = i * dx;
      final yy = top + h - ((v - lo) / span) * h;
      if (!started) {
        path.moveTo(x, yy);
        started = true;
      } else {
        path.lineTo(x, yy);
      }
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeJoin = StrokeJoin.round);
  }

  void _paintPrice(Canvas canvas, double chartW, double h) {
    double min = double.infinity, max = -double.infinity;
    for (final c in data) {
      final lo = candle ? c.low : c.close;
      final hi = candle ? c.high : c.close;
      if (lo < min) min = lo;
      if (hi > max) max = hi;
    }
    // Include overlays in the scale so they never clip.
    for (final seg in [maSeg, emaSeg]) {
      if (seg == null) continue;
      for (final v in seg) {
        if (v == null) continue;
        if (v < min) min = v;
        if (v > max) max = v;
      }
    }
    final rng = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
    final pad = rng * 0.08;
    final lo = min - pad, hi = max + pad;
    final span = hi - lo;
    double yAt(double v) => h - ((v - lo) / span) * h;

    final gridPaint = Paint()..color = grid.withOpacity(0.6)..strokeWidth = 1;
    for (var g = 0; g <= 4; g++) {
      final v = lo + span * (g / 4);
      final yy = yAt(v);
      canvas.drawLine(Offset(0, yy), Offset(chartW, yy), gridPaint);
      _label(canvas, v >= 100 ? v.toStringAsFixed(2) : v.toStringAsFixed(4), chartW + 8, yy - 6);
    }

    if (candle) {
      final slot = chartW / data.length;
      final bodyW = (slot * 0.62).clamp(1.5, 14.0);
      for (var i = 0; i < data.length; i++) {
        final c = data[i];
        final cx = slot * i + slot / 2;
        final col = c.up ? up : down;
        canvas.drawLine(Offset(cx, yAt(c.high)), Offset(cx, yAt(c.low)), Paint()..color = col..strokeWidth = 1.2);
        final top = yAt(c.close > c.open ? c.close : c.open);
        final bot = yAt(c.close > c.open ? c.open : c.close);
        canvas.drawRect(Rect.fromLTRB(cx - bodyW / 2, top, cx + bodyW / 2, (bot - top).abs() < 1 ? top + 1 : bot), Paint()..color = col);
      }
    } else {
      final trendUp = data.last.close >= data.first.close;
      final color = trendUp ? up : down;
      final dx = chartW / (data.length - 1);
      final line = Path();
      for (var i = 0; i < data.length; i++) {
        final x = i * dx, yy = yAt(data[i].close);
        i == 0 ? line.moveTo(x, yy) : line.lineTo(x, yy);
      }
      final fill = Path.from(line)..lineTo((data.length - 1) * dx, h)..lineTo(0, h)..close();
      canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(0.22), color.withOpacity(0.02)]).createShader(Rect.fromLTWH(0, 0, chartW, h)));
      canvas.drawPath(line, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }

    // Overlays
    if (maSeg != null) _line(canvas, maSeg!, chartW, 0, h, lo, span, maColor.withOpacity(0.9), 1.6);
    if (emaSeg != null) _line(canvas, emaSeg!, chartW, 0, h, lo, span, emaColor.withOpacity(0.95), 1.6);
    // Overlay legend
    double lx = 2;
    if (maSeg != null) {
      _label(canvas, 'MA', lx, 2, style: tagStyle.copyWith(color: maColor));
      lx += 26;
    }
    if (emaSeg != null) {
      _label(canvas, 'EMA', lx, 2, style: tagStyle.copyWith(color: emaColor));
    }

    // Live price line + pill
    final lastV = data.last.close;
    final ly = yAt(lastV);
    final lineColor = data.last.close >= data.first.close ? up : down;
    _dashedH(canvas, 0, chartW, ly, Paint()..color = lineColor.withOpacity(0.7)..strokeWidth = 1);
    final pill = TextPainter(text: TextSpan(text: lastV >= 100 ? lastV.toStringAsFixed(2) : lastV.toStringAsFixed(4), style: lastPillStyle), textDirection: TextDirection.ltr)..layout();
    final pr = Rect.fromLTWH(chartW + 4, ly - pill.height / 2 - 3, _rightPad - 4, pill.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(pr, const Radius.circular(3)), Paint()..color = lineColor);
    pill.paint(canvas, Offset(chartW + 6, ly - pill.height / 2));
  }

  void _paintRsi(Canvas canvas, double chartW, double top, double h) {
    final seg = rsiSeg!;
    // Fixed 0–100 scale with 30/70 guide lines.
    final border = Paint()..color = grid.withOpacity(0.5)..strokeWidth = 1;
    canvas.drawLine(Offset(0, top), Offset(chartW, top), border);
    for (final lv in [30.0, 70.0]) {
      final yy = top + h - (lv / 100) * h;
      _dashedH(canvas, 0, chartW, yy, Paint()..color = grid.withOpacity(0.7)..strokeWidth = 1);
      _label(canvas, lv.toInt().toString(), chartW + 8, yy - 6);
    }
    _line(canvas, seg, chartW, top, h, 0, 100, maColor, 1.6);
    _label(canvas, 'RSI $rsiPeriod', 2, top + 2, style: tagStyle);
    final lastV = seg.lastWhere((e) => e != null, orElse: () => null);
    if (lastV != null) _label(canvas, lastV.toStringAsFixed(1), 40, top + 2, style: tagStyle.copyWith(color: lastV >= 70 ? down : (lastV <= 30 ? up : maColor)));
  }

  void _paintMacd(Canvas canvas, double chartW, double top, double h) {
    final (macdLine, signalLine, hist) = macdSeg!;
    final (mn, mx) = Indicators.extent([macdLine, signalLine, hist]);
    final bound = (mn.abs() > mx.abs() ? mn.abs() : mx.abs());
    final lo = -bound, span = (bound * 2).clamp(1e-9, double.infinity);
    double yAt(double v) => top + h - ((v - lo) / span) * h;

    canvas.drawLine(Offset(0, top), Offset(chartW, top), Paint()..color = grid.withOpacity(0.5)..strokeWidth = 1);
    final zeroY = yAt(0);
    _dashedH(canvas, 0, chartW, zeroY, Paint()..color = grid.withOpacity(0.6)..strokeWidth = 1);

    // Histogram
    final dx = chartW / (hist.length - 1).clamp(1, double.infinity);
    final barW = (dx * 0.5).clamp(1.0, 6.0);
    for (var i = 0; i < hist.length; i++) {
      final v = hist[i];
      if (v == null) continue;
      final x = i * dx;
      final yy = yAt(v);
      final col = (v >= 0 ? up : down).withOpacity(0.55);
      canvas.drawRect(Rect.fromLTRB(x - barW / 2, v >= 0 ? yy : zeroY, x + barW / 2, v >= 0 ? zeroY : yy), Paint()..color = col);
    }
    _line(canvas, macdLine, chartW, top, h, lo, span, maColor, 1.4);
    _line(canvas, signalLine, chartW, top, h, lo, span, emaColor, 1.4);
    _label(canvas, 'MACD', 2, top + 2, style: tagStyle);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.data != data ||
      old.candle != candle ||
      old.maSeg != maSeg ||
      old.emaSeg != emaSeg ||
      old.rsiSeg != rsiSeg ||
      old.macdSeg != macdSeg;
}
