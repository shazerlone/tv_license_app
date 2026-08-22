import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../data/pairs.dart';
import '../models/trader.dart';
import '../models/indicator_config.dart';
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
  int _tf = 5; // index into _timeframes (default 1D)
  bool _candle = true; // candlestick by default (line = false)
  final IndicatorConfig _ind = IndicatorConfig(); // active indicators + inputs
  bool _chartLock = false; // freeze page scroll while touching the chart
  // (range, interval, label) for our own chart — proper trading timeframes.
  static const _timeframes = [
    ('1d', '1m', '1m'),
    ('5d', '5m', '5m'),
    ('5d', '15m', '15m'),
    ('1mo', '30m', '30m'),
    ('1mo', '60m', '1H'),
    ('6mo', '1d', '1D'),
    ('2y', '1wk', '1W'),
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

  String _tfLabel(String short) => switch (short) {
        '1m' => '1 Minute',
        '5m' => '5 Minutes',
        '15m' => '15 Minutes',
        '30m' => '30 Minutes',
        '1H' => '1 Hour',
        '1D' => '1 Day',
        '1W' => '1 Week',
        _ => short,
      };

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
        // While the finger is on the chart, freeze page scroll so pinch/pan only
        // move the chart — the page no longer jumps around.
        physics: _chartLock ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
        children: [
          // Chart toolbar: timeframe dropdown + tools + line/candle toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
            child: Row(
              children: [
                // Timeframe dropdown
                PopupMenuButton<int>(
                  initialValue: _tf,
                  onSelected: (i) => setState(() => _tf = i),
                  color: AppColors.surfaceHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  itemBuilder: (_) => [
                    for (var i = 0; i < _timeframes.length; i++)
                      PopupMenuItem(
                        value: i,
                        child: Text(_tfLabel(_timeframes[i].$3),
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: _tf == i ? AppColors.primary : AppColors.textPrimary)),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.access_time_rounded, size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(_tfLabel(_timeframes[_tf].$3), style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
                    ]),
                  ),
                ),
                const Spacer(),
                // Indicators panel
                _IndicatorButton(count: _ind.activeCount, onTap: _openIndicators),
                const SizedBox(width: 6),
                // Line / candle toggle
                _ChartTypeButton(icon: Icons.show_chart_rounded, active: !_candle, onTap: () => setState(() => _candle = false)),
                const SizedBox(width: 6),
                _ChartTypeButton(icon: Icons.candlestick_chart_rounded, active: _candle, onTap: () => setState(() => _candle = true)),
              ],
            ),
          ),
          // Our own clean chart (no third-party chrome) — pinch to zoom, drag to pan.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 12, 2),
            child: Listener(
              onPointerDown: (_) { if (!_chartLock) setState(() => _chartLock = true); },
              onPointerUp: (_) { if (_chartLock) setState(() => _chartLock = false); },
              onPointerCancel: (_) { if (_chartLock) setState(() => _chartLock = false); },
              child: MarketChart(
                pair: widget.pair,
                range: _timeframes[_tf].$1,
                interval: _timeframes[_tf].$2,
                candle: _candle,
                indicators: _ind,
                height: 340 + _ind.subPaneCount * 88.0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('Pinch to zoom · drag to pan · double-tap to reset',
                  style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
            ),
          ),
          const SizedBox(height: 14),
          // Market stats — compact single card, secondary to the chart.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  Row(children: [
                    _stat('Open', _fmt(q?.open)),
                    _stat('Prev', _fmt(q?.prevClose)),
                    _stat('Day H', _fmt(q?.dayHigh), color: AppColors.green),
                    _stat('Day L', _fmt(q?.dayLow), color: AppColors.red),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _stat('52W H', _fmt(q?.yearHigh)),
                    _stat('52W L', _fmt(q?.yearLow)),
                    const Spacer(),
                    const Spacer(),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary)),
          ],
        ),
      );

  /// Compact indicators panel: toggle MA / EMA / RSI / MACD and edit inputs.
  Future<void> _openIndicators() async {
    final draft = _ind.copy();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text('Indicators', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Overlay moving averages, or add RSI / MACD panes.', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
                const SizedBox(height: 14),
                _IndicatorRow(
                  name: 'Moving Average (SMA)', color: AppColors.primary,
                  on: draft.maOn, onToggle: (v) => setSheet(() => draft.maOn = v),
                  inputs: [_IndInput('Period', draft.maPeriod, (v) => setSheet(() => draft.maPeriod = v))],
                ),
                _IndicatorRow(
                  name: 'Exponential MA (EMA)', color: AppColors.purple,
                  on: draft.emaOn, onToggle: (v) => setSheet(() => draft.emaOn = v),
                  inputs: [_IndInput('Period', draft.emaPeriod, (v) => setSheet(() => draft.emaPeriod = v))],
                ),
                _IndicatorRow(
                  name: 'RSI', color: AppColors.primary,
                  on: draft.rsiOn, onToggle: (v) => setSheet(() => draft.rsiOn = v),
                  inputs: [_IndInput('Length', draft.rsiPeriod, (v) => setSheet(() => draft.rsiPeriod = v))],
                ),
                _IndicatorRow(
                  name: 'MACD', color: AppColors.purple,
                  on: draft.macdOn, onToggle: (v) => setSheet(() => draft.macdOn = v),
                  inputs: [
                    _IndInput('Fast', draft.macdFast, (v) => setSheet(() => draft.macdFast = v)),
                    _IndInput('Slow', draft.macdSlow, (v) => setSheet(() => draft.macdSlow = v)),
                    _IndInput('Signal', draft.macdSignal, (v) => setSheet(() => draft.macdSignal = v)),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _ind.maOn = draft.maOn; _ind.maPeriod = draft.maPeriod;
                        _ind.emaOn = draft.emaOn; _ind.emaPeriod = draft.emaPeriod;
                        _ind.rsiOn = draft.rsiOn; _ind.rsiPeriod = draft.rsiPeriod;
                        _ind.macdOn = draft.macdOn; _ind.macdFast = draft.macdFast;
                        _ind.macdSlow = draft.macdSlow; _ind.macdSignal = draft.macdSignal;
                      });
                    },
                    child: Text('Apply', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

/// Toolbar button that opens the indicators panel, with an active-count badge.
class _IndicatorButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _IndicatorButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.14) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tune_rounded, size: 16, color: active ? AppColors.primary : AppColors.textMuted),
          const SizedBox(width: 5),
          Text(active ? 'Indicators · $count' : 'Indicators',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: active ? AppColors.primary : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

/// One indicator row in the panel: a switch + inline numeric inputs.
class _IndicatorRow extends StatelessWidget {
  final String name;
  final Color color;
  final bool on;
  final ValueChanged<bool> onToggle;
  final List<_IndInput> inputs;
  const _IndicatorRow({required this.name, required this.color, required this.on, required this.onToggle, required this.inputs});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? color.withOpacity(0.5) : AppColors.border)),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(name, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
          if (on)
            for (final inp in inputs)
              Padding(padding: const EdgeInsets.only(left: 6), child: inp),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.82,
            child: Switch(
              value: on,
              activeColor: color,
              onChanged: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tiny labelled +/- numeric stepper for an indicator input.
class _IndInput extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _IndInput(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 8.5, color: AppColors.textMuted)),
        const SizedBox(height: 1),
        Container(
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _stepBtn(Icons.remove, () => onChanged((value - 1).clamp(1, 400))),
            SizedBox(width: 22, child: Text('$value', textAlign: TextAlign.center, style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            _stepBtn(Icons.add, () => onChanged((value + 1).clamp(1, 400))),
          ]),
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 13, color: AppColors.textSecondary)),
      );
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
