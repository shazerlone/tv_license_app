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
  });
}

/// Fetches live market quotes directly from Yahoo Finance's public chart
/// endpoint. This runs on the user's device (no CORS), needs no API key, and
/// covers FX, metals, crypto and indices. It's a display/estimation source —
/// order execution still goes through the backend.
class PriceService {
  static final _client = http.Client();

  /// Live quote for a pair. Returns null on any failure (offline, bad symbol).
  static Future<Quote?> quote(TradingPair pair) async {
    final uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/${Uri.encodeComponent(pair.yahoo)}?interval=1d&range=1d');
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
      );
    } catch (_) {
      return null;
    }
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
