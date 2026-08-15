import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../data/pairs.dart';
import '../services/price_service.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';
import '../widgets/tradingview_chart.dart';

/// Broker-style instrument view: live pro chart with timeframes, live price,
/// market stats (open/high/low/prev close, 52-week range) and price alerts.
class PairDetailScreen extends StatefulWidget {
  final TradingPair pair;
  const PairDetailScreen({super.key, required this.pair});

  @override
  State<PairDetailScreen> createState() => _PairDetailScreenState();
}

class _PairDetailScreenState extends State<PairDetailScreen> {
  Quote? _quote;
  Timer? _priceTimer;
  String _interval = '60'; // 60=1H, D=1D, W=1W, M=1M
  static const _timeframes = [('60', '1H'), ('D', '1D'), ('W', '1W'), ('M', '1M')];

  @override
  void initState() {
    super.initState();
    _refreshPrice();
    _priceTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshPrice());
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPrice() async {
    final q = await PriceService.quote(widget.pair);
    if (mounted && q != null) setState(() => _quote = q);
  }

  String _fmt(double? v) => v == null ? '—' : (v >= 100 ? v.toStringAsFixed(2) : v.toStringAsFixed(4));

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    final up = (q?.changePercent ?? 0) >= 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.pair.symbol, style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(widget.pair.name, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          if (kUseBackend)
            IconButton(
              tooltip: 'Price alert',
              icon: Icon(Icons.notifications_active_outlined, color: AppColors.textPrimary),
              onPressed: _createAlert,
            ),
          if (q != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt(q.price), style: GoogleFonts.robotoMono(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  if (q.changePercent != null)
                    Text('${up ? '+' : ''}${q.changePercent!.toStringAsFixed(2)}%', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: up ? AppColors.green : AppColors.red)),
                ],
              ),
            ),
        ],
      ),
      body: ListView(
        children: [
          // Timeframe selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                for (final tf in _timeframes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _interval = tf.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _interval == tf.$1 ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _interval == tf.$1 ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(tf.$2, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _interval == tf.$1 ? Colors.white : AppColors.textSecondary)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Live pro chart (rebuilds when the timeframe changes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TradingViewChart(key: ValueKey(_interval), tvSymbol: widget.pair.tv, interval: _interval, height: 320),
          ),
          const SizedBox(height: 18),
          // Market stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Market stats', style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border), boxShadow: AppColors.softShadow),
              child: Column(
                children: [
                  Row(children: [
                    _stat('Open', _fmt(q?.open)),
                    _stat('Prev close', _fmt(q?.prevClose)),
                  ]),
                  Divider(height: 1, color: AppColors.border),
                  Row(children: [
                    _stat('Day high', _fmt(q?.dayHigh), color: AppColors.green),
                    _stat('Day low', _fmt(q?.dayLow), color: AppColors.red),
                  ]),
                  Divider(height: 1, color: AppColors.border),
                  Row(children: [
                    _stat('52W high', _fmt(q?.yearHigh)),
                    _stat('52W low', _fmt(q?.yearLow)),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (kUseBackend)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _createAlert,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
                  icon: Icon(Icons.notifications_active_outlined, size: 19, color: AppColors.primary),
                  label: Text('Set a price alert', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ),
            ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 3),
              Text(value, style: GoogleFonts.robotoMono(fontSize: 14.5, fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary)),
            ],
          ),
        ),
      );

  Future<void> _createAlert() async {
    final priceCtrl = TextEditingController(text: _quote != null ? _fmt(_quote!.price) : '');
    String direction = 'above';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 18),
                Text('Alert me on ${widget.pair.symbol}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                Row(children: [
                  for (final d in ['above', 'below'])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheet(() => direction = d),
                        child: Container(
                          margin: EdgeInsets.only(right: d == 'above' ? 10 : 0),
                          height: 46, alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: direction == d ? AppColors.primary.withOpacity(0.14) : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: direction == d ? AppColors.primary : AppColors.border),
                          ),
                          child: Text(d == 'above' ? 'Rises above' : 'Falls below',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: direction == d ? AppColors.primary : AppColors.textSecondary)),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Target price'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final target = double.tryParse(priceCtrl.text.trim());
                      if (target == null || target <= 0) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await BackendApi.createAlert(symbol: widget.pair.symbol, direction: direction, targetPrice: target);
                        Navigator.pop(ctx);
                        messenger.showSnackBar(const SnackBar(content: Text('Alert set — we\'ll notify you')));
                      } on ApiException catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(
                          e.code == 'alert_already_met' ? 'That target is already met — pick the other direction.' : e.message,
                        )));
                      } catch (_) {
                        messenger.showSnackBar(const SnackBar(content: Text('Could not reach the server')));
                      }
                    },
                    child: Text('Set alert', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
