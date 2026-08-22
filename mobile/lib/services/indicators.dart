import 'dart:math' as math;

/// Technical-indicator math. All functions take a full close series and return
/// a same-length list where the warm-up period is filled with null, so values
/// line up 1:1 with the candles and can be sliced to any visible window.
class Indicators {
  /// Simple moving average.
  static List<double?> sma(List<double> c, int period) {
    final out = List<double?>.filled(c.length, null);
    if (period < 1) return out;
    double sum = 0;
    for (var i = 0; i < c.length; i++) {
      sum += c[i];
      if (i >= period) sum -= c[i - period];
      if (i >= period - 1) out[i] = sum / period;
    }
    return out;
  }

  /// Exponential moving average.
  static List<double?> ema(List<double> c, int period) {
    final out = List<double?>.filled(c.length, null);
    if (period < 1 || c.isEmpty) return out;
    final k = 2 / (period + 1);
    double? prev;
    double seed = 0;
    for (var i = 0; i < c.length; i++) {
      if (i < period) {
        seed += c[i];
        if (i == period - 1) {
          prev = seed / period;
          out[i] = prev;
        }
        continue;
      }
      prev = (c[i] - prev!) * k + prev;
      out[i] = prev;
    }
    return out;
  }

  /// Relative Strength Index (Wilder's smoothing), 0–100.
  static List<double?> rsi(List<double> c, int period) {
    final out = List<double?>.filled(c.length, null);
    if (c.length <= period || period < 1) return out;
    double gain = 0, loss = 0;
    for (var i = 1; i <= period; i++) {
      final d = c[i] - c[i - 1];
      if (d >= 0) {
        gain += d;
      } else {
        loss -= d;
      }
    }
    double avgGain = gain / period, avgLoss = loss / period;
    out[period] = _rsiFrom(avgGain, avgLoss);
    for (var i = period + 1; i < c.length; i++) {
      final d = c[i] - c[i - 1];
      final g = d >= 0 ? d : 0.0;
      final l = d < 0 ? -d : 0.0;
      avgGain = (avgGain * (period - 1) + g) / period;
      avgLoss = (avgLoss * (period - 1) + l) / period;
      out[i] = _rsiFrom(avgGain, avgLoss);
    }
    return out;
  }

  static double _rsiFrom(double avgGain, double avgLoss) {
    if (avgLoss == 0) return 100;
    final rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  /// MACD: returns (macdLine, signalLine, histogram), each same-length.
  static (List<double?>, List<double?>, List<double?>) macd(
      List<double> c, int fast, int slow, int signal) {
    final emaFast = ema(c, fast);
    final emaSlow = ema(c, slow);
    final macdLine = List<double?>.filled(c.length, null);
    for (var i = 0; i < c.length; i++) {
      if (emaFast[i] != null && emaSlow[i] != null) {
        macdLine[i] = emaFast[i]! - emaSlow[i]!;
      }
    }
    // Signal = EMA of the MACD line over its non-null tail.
    final signalLine = List<double?>.filled(c.length, null);
    final firstIdx = macdLine.indexWhere((e) => e != null);
    if (firstIdx >= 0) {
      final tail = [for (var i = firstIdx; i < c.length; i++) macdLine[i] ?? 0.0];
      final sig = ema(tail, signal);
      for (var i = 0; i < sig.length; i++) {
        signalLine[firstIdx + i] = sig[i];
      }
    }
    final hist = List<double?>.filled(c.length, null);
    for (var i = 0; i < c.length; i++) {
      if (macdLine[i] != null && signalLine[i] != null) {
        hist[i] = macdLine[i]! - signalLine[i]!;
      }
    }
    return (macdLine, signalLine, hist);
  }

  /// Min/max over the non-null values of one or more aligned series.
  static (double, double) extent(List<List<double?>> series) {
    double mn = double.infinity, mx = -double.infinity;
    for (final s in series) {
      for (final v in s) {
        if (v == null) continue;
        mn = math.min(mn, v);
        mx = math.max(mx, v);
      }
    }
    if (mn == double.infinity) return (0, 1);
    return (mn, mx);
  }
}
