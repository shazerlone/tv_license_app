import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/pairs.dart';
import '../services/price_service.dart';
import '../screens/pair_detail_screen.dart';

/// A slim live market ticker for the home header — a few key instruments with
/// price + day change, tap-through to the full chart. Self-contained and light
/// (a handful of quotes, refreshed once a minute).
class MarketTicker extends StatefulWidget {
  const MarketTicker({super.key});

  @override
  State<MarketTicker> createState() => _MarketTickerState();
}

class _MarketTickerState extends State<MarketTicker> {
  static const _symbols = ['XAU/USD', 'BTC/USD', 'EUR/USD', 'NAS100', 'ETH/USD', 'US500'];
  final Map<String, Quote> _quotes = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    for (final s in _symbols) {
      final p = pairBySymbol(s);
      if (p == null) continue;
      final q = await PriceService.quote(p);
      if (!mounted) break;
      if (q != null) setState(() => _quotes[s] = q);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_quotes.isEmpty) return const SizedBox(height: 0);
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _symbols.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final sym = _symbols[i];
          final q = _quotes[sym];
          if (q == null) return const SizedBox.shrink();
          final up = (q.changePercent ?? 0) >= 0;
          final pair = pairBySymbol(sym)!;
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PairDetailScreen(pair: pair))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sym, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(width: 8),
                  Text(q.price.toStringAsFixed(q.price >= 100 ? 2 : 4), style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  const SizedBox(width: 6),
                  Row(children: [
                    Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 16, color: up ? AppColors.green : AppColors.red),
                    Text('${q.changePercent?.abs().toStringAsFixed(2) ?? '0.00'}%', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: up ? AppColors.green : AppColors.red)),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
