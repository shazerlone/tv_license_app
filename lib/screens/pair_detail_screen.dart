import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../data/pairs.dart';
import '../models/trader.dart';
import '../services/price_service.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';
import '../widgets/market_chart.dart';
import 'trader_profile_screen.dart';
import 'copy_trading_screen.dart';

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
  int _tf = 0; // index into _timeframes
  bool _candle = true; // candlestick by default (line = false)
  // (range, interval, label) for our own chart.
  static const _timeframes = [
    ('1d', '5m', '1D'),
    ('5d', '30m', '1W'),
    ('1mo', '1d', '1M'),
    ('3mo', '1d', '3M'),
    ('1y', '1wk', '1Y'),
  ];
  List<Trader> _traders = const [];
  bool _tradersFiltered = false; // true when the list is specific to this pair

  @override
  void initState() {
    super.initState();
    _refreshPrice();
    _loadTraders();
    _priceTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshPrice());
  }

  /// Loads creators and keeps those who trade this pair (by tags/category);
  /// falls back to top traders so the section is never empty.
  Future<void> _loadTraders() async {
    if (!kUseBackend) return;
    try {
      final page = await BackendApi.traders(sort: 'copiers');
      final all = page.items.map(Trader.fromApi).toList();
      final matched = all.where(_matchesPair).toList();
      if (!mounted) return;
      setState(() {
        _tradersFiltered = matched.isNotEmpty;
        _traders = (matched.isNotEmpty ? matched : all).take(10).toList();
      });
    } catch (_) {}
  }

  bool _matchesPair(Trader t) {
    final sym = widget.pair.symbol.toUpperCase();
    final base = sym.split('/').first;
    final cat = widget.pair.category.toLowerCase();
    final tcat = t.category.toLowerCase();
    final tags = t.tags.map((e) => e.toUpperCase());
    if (tags.any((tg) => tg.contains(sym) || tg.contains(base))) return true;
    if (tcat == cat) return true;
    if (cat == 'metals' && (tcat.contains('gold') || tcat.contains('metal'))) return true;
    return false;
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
                for (var i = 0; i < _timeframes.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _tf = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _tf == i ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _tf == i ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(_timeframes[i].$3, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _tf == i ? Colors.white : AppColors.textSecondary)),
                      ),
                    ),
                  ),
                const Spacer(),
                // Line / candle toggle
                _ChartTypeButton(icon: Icons.show_chart_rounded, active: !_candle, onTap: () => setState(() => _candle = false)),
                const SizedBox(width: 6),
                _ChartTypeButton(icon: Icons.candlestick_chart_rounded, active: _candle, onTap: () => setState(() => _candle = true)),
              ],
            ),
          ),
          // Our own clean chart (no third-party chrome)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
            child: MarketChart(pair: widget.pair, range: _timeframes[_tf].$1, interval: _timeframes[_tf].$2, candle: _candle, height: 260),
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
          // Traders trading this pair → copy them right here.
          if (_traders.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _tradersFiltered ? 'Traders trading ${widget.pair.symbol}' : 'Top traders to copy',
                style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: 12),
            for (final t in _traders) _TraderPairCard(trader: t),
          ],
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

/// A trader row on the instrument page: profile + one-tap copy.
class _TraderPairCard extends StatelessWidget {
  final Trader trader;
  const _TraderPairCard({required this.trader});

  @override
  Widget build(BuildContext context) {
    final positive = trader.returnPercent >= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: trader))),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border), boxShadow: AppColors.softShadow),
          child: Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: AppColors.primary.withOpacity(0.12), child: Text(trader.name.isNotEmpty ? trader.name[0] : '?', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.primary))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trader.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text('${positive ? '+' : ''}${trader.returnPercent.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: positive ? AppColors.green : AppColors.red)),
                      const SizedBox(width: 8),
                      Text('· ${trader.copiers} copiers', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CopyTradingScreen(trader: trader))),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16), minimumSize: const Size(0, 36)),
                  child: Text('Copy', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small line/candle chart-type toggle button.
class _ChartTypeButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ChartTypeButton({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Icon(icon, size: 18, color: active ? AppColors.primary : AppColors.textMuted),
      ),
    );
  }
}
