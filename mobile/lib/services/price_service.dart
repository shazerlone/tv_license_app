import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/pairs.dart';

/// A single live quote for an instrument, plus the day/52-week stats a broker
/// terminal shows.
class Quote {
  final double price;
  final double? changePercent; // day change %, when available
  final String currency;
  final double? open;
  final double? dayHigh;
  final double? dayLow;
  final double? prevClose;
  final double? yearHigh;
  final double? yearLow;
  final List<double>? spark; // intraday close series for a sparkline
  const Quote({
    required this.price,
    this.changePercent,
    this.currency = 'USD',
    this.open,
    this.dayHigh,
    this.dayLow,
    this.prevClose,
    this.yearHigh,
    this.yearLow,
    this.spark,
  });
}

/// Fetches live market quotes directly from Yahoo Finance's public chart
/// endpoint. This runs on the user's device (no CORS), needs no API key, and
/// covers FX, metals, crypto and indices. It's a display/estimation source —
/// order execution still goes through the backend.
class PriceService {
  static final _client = http.Client();

  /// Live quote + intraday trend for a pair. One call returns both the current
  /// price/stats (meta) and the intraday close series (for a sparkline).
  static Future<Quote?> quote(TradingPair pair) async {
    final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(pair.yahoo)}?interval=15m&range=1d');
    try {
      final r = await _client
          .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final json = jsonDecode(r.body);
      final result = (json['chart']?['result'] as List?)?.firstOrNull;
      final meta = result?['meta'] as Map?;
      if (meta == null) return null;
      final price = (meta['regularMarketPrice'] as num?)?.toDouble();
      if (price == null) return null;
      final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble() ??
          (meta['previousClose'] as num?)?.toDouble();
      double? d(String k) => (meta[k] as num?)?.toDouble();
      double? changePct;
      if (prevClose != null && prevClose != 0) {
        changePct = (price - prevClose) / prevClose * 100;
      }
      // Intraday close series → sparkline (skip nulls, cap at ~40 points).
      List<double>? spark;
      final closes = ((result?['indicators']?['quote'] as List?)?.firstOrNull?['close'] as List?)
          ?.whereType<num>()
          .map((e) => e.toDouble())
          .toList();
      if (closes != null && closes.length >= 2) {
        final step = (closes.length / 40).ceil();
        spark = [for (var i = 0; i < closes.length; i += step) closes[i]];
        if (spark.last != closes.last) spark.add(closes.last);
      }
      return Quote(
        price: price,
        changePercent: changePct,
        currency: (meta['currency'] ?? 'USD').toString(),
        open: d('regularMarketOpen') ?? d('open'),
        dayHigh: d('regularMarketDayHigh'),
        dayLow: d('regularMarketDayLow'),
        prevClose: prevClose,
        yearHigh: d('fiftyTwoWeekHigh'),
        yearLow: d('fiftyTwoWeekLow'),
        spark: spark,
      );
    } catch (_) {
      return null;
    }
  }

  /// OHLC candles for a range/interval — powers both our line and candlestick
  /// charts (one fetch serves both). Returns null on failure.
  static Future<List<Candle>?> candles(TradingPair pair, {required String range, required String interval}) async {
    final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(pair.yahoo)}?interval=$interval&range=$range');
    try {
      final r = await _client
          .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final json = jsonDecode(r.body);
      final result = (json['chart']?['result'] as List?)?.firstOrNull;
      final q = (result?['indicators']?['quote'] as List?)?.firstOrNull as Map?;
      if (q == null) return null;
      List<double?> col(String k) => (q[k] as List?)?.map((e) => (e as num?)?.toDouble()).toList() ?? const [];
      final o = col('open'), h = col('high'), l = col('low'), c = col('close');
      final n = c.length;
      final out = <Candle>[];
      for (var i = 0; i < n; i++) {
        final cc = c[i];
        if (cc == null) continue; // skip gaps
        out.add(Candle(
          open: o.length > i ? (o[i] ?? cc) : cc,
          high: h.length > i ? (h[i] ?? cc) : cc,
          low: l.length > i ? (l[i] ?? cc) : cc,
          close: cc,
        ));
      }
      return out.length >= 2 ? out : null;
    } catch (_) {
      return null;
    }
  }
}

/// One OHLC candle.
class Candle {
  final double open, high, low, close;
  const Candle({required this.open, required this.high, required this.low, required this.close});
  bool get up => close >= open;
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
