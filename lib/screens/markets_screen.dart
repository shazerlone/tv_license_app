import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../data/pairs.dart';
import '../models/trader.dart';
import '../services/price_service.dart';
import '../services/backend_api.dart';
import '../widgets/pair_picker.dart';
import 'pair_detail_screen.dart';
import 'trader_profile_screen.dart';

/// A broker-style Markets hub: live watchlist (real prices), category filters,
/// tap-through to the chart + community chat, and top traders to copy.
class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  static const _popular = ['XAU/USD', 'EUR/USD', 'GBP/USD', 'BTC/USD', 'ETH/USD', 'NAS100'];
  final _cats = const ['Popular', 'Metals', 'Forex', 'Crypto', 'Indices'];
  String _cat = 'Popular';

  final Map<String, Quote> _quotes = {};
  Timer? _timer;
  List<Trader> _topTraders = const [];

  @override
  void initState() {
    super.initState();
    _loadQuotes();
    _loadTopTraders();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _loadQuotes());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<TradingPair> get _visible => _cat == 'Popular'
      ? _popular.map(pairBySymbol).whereType<TradingPair>().toList()
      : kPairs.where((p) => p.category == _cat).toList();

  Future<void> _loadQuotes() async {
    await Future.wait(_visible.map((p) async {
      final q = await PriceService.quote(p);
      if (q != null && mounted) setState(() => _quotes[p.symbol] = q);
    }));
  }

  Future<void> _loadTopTraders() async {
    if (!kUseBackend) return;
    try {
      final page = await BackendApi.traders(sort: 'copiers');
      if (!mounted) return;
      setState(() => _topTraders = page.items.take(10).map(Trader.fromApi).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async { await _loadQuotes(); await _loadTopTraders(); },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Text('Markets', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () async {
                          final p = await showPairPicker(context);
                          if (p != null && mounted) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PairDetailScreen(pair: p)));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                          child: Icon(Icons.search_rounded, size: 22, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Category chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = _cats[i];
                      final active = c == _cat;
                      return GestureDetector(
                        onTap: () { setState(() => _cat = c); _loadQuotes(); },
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: active ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: active ? AppColors.primary : AppColors.border),
                          ),
                          child: Text(c, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              // Watchlist
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _WatchRow(pair: _visible[i], quote: _quotes[_visible[i].symbol]),
                    childCount: _visible.length,
                  ),
                ),
              ),
              // Top traders to copy
              if (_topTraders.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Row(children: [
                      Text('Top traders to copy', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
                    ]),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _topTraders.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _TraderCopyCard(trader: _topTraders[i]),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchRow extends StatelessWidget {
  final TradingPair pair;
  final Quote? quote;
  const _WatchRow({required this.pair, required this.quote});

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final up = (q?.changePercent ?? 0) >= 0;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PairDetailScreen(pair: pair))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border), boxShadow: AppColors.softShadow),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(pair.symbol.substring(0, pair.symbol.length >= 2 ? 2 : 1), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pair.symbol, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text(pair.name, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (q == null)
              SizedBox(width: 46, child: Align(alignment: Alignment.centerRight, child: Text('—', style: GoogleFonts.robotoMono(fontSize: 14, color: AppColors.textMuted))))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(q.price.toStringAsFixed(q.price >= 100 ? 2 : 4), style: GoogleFonts.robotoMono(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  if (q.changePercent != null)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: (up ? AppColors.green : AppColors.red).withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
                      child: Text('${up ? '+' : ''}${q.changePercent!.toStringAsFixed(2)}%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: up ? AppColors.green : AppColors.red)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TraderCopyCard extends StatelessWidget {
  final Trader trader;
  const _TraderCopyCard({required this.trader});

  @override
  Widget build(BuildContext context) {
    final positive = trader.returnPercent >= 0;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: trader))),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border), boxShadow: AppColors.softShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withOpacity(0.12), child: Text(trader.name.isNotEmpty ? trader.name[0] : '?', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: AppColors.primary))),
              const SizedBox(width: 10),
              Expanded(child: Text(trader.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
            ]),
            const SizedBox(height: 12),
            Text('${positive ? '+' : ''}${trader.returnPercent.toStringAsFixed(1)}%', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: positive ? AppColors.green : AppColors.red, letterSpacing: -0.5)),
            Text('${trader.returnDays}d return', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted)),
            const Spacer(),
            Row(children: [
              Icon(Icons.people_alt_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('${trader.copiers} copiers', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted)),
            ]),
          ],
        ),
      ),
    );
  }
}
