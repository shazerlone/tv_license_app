import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import '../config.dart';
import '../models/trader.dart';
import '../services/backend_api.dart';
import '../widgets/verified_badge.dart';
import 'trader_profile_screen.dart';

/// Rankings page. Backend-driven (GET /traders?sort=return|copiers).
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _sort = 'return'; // 'return' | 'copiers'
  List<Trader> _traders = const [];
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (kUseBackend) {
      _loading = true;
      _load();
    } else {
      _traders = List<Trader>.from(mockTraders)..sort((a, b) => b.returnPercent.compareTo(a.returnPercent));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await BackendApi.traders(sort: _sort);
      if (!mounted) return;
      setState(() {
        _traders = page.items.map(Trader.fromApi).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _setSort(String s) {
    if (_sort == s) return;
    setState(() => _sort = s);
    if (kUseBackend) {
      _load();
    } else {
      setState(() {
        _traders = List<Trader>.from(mockTraders)
          ..sort((a, b) => s == 'return' ? b.returnPercent.compareTo(a.returnPercent) : b.copiers.compareTo(a.copiers));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Rankings', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ),
      body: Column(
        children: [
          // Sort toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Row(
              children: [
                _SortChip(label: 'Top return', active: _sort == 'return', onTap: () => _setSort('return')),
                const SizedBox(width: 10),
                _SortChip(label: 'Most copied', active: _sort == 'copiers', onTap: () => _setSort('copiers')),
              ],
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: [
                const SizedBox(width: 32),
                Expanded(child: Text('#  Trader', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted))),
                SizedBox(width: 72, child: Text('Return', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted))),
                SizedBox(width: 60, child: Text('Copiers', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const SkeletonList()
                : _traders.isEmpty
                    ? _RankEmpty(failed: _failed, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 32),
                          itemCount: _traders.length,
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: _traders[i]))),
                            child: _LeaderboardRow(trader: _traders[i], rank: i + 1),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SortChip({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _RankEmpty extends StatelessWidget {
  final bool failed;
  final VoidCallback onRetry;
  const _RankEmpty({required this.failed, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(failed ? Icons.wifi_off_rounded : Icons.leaderboard_outlined, size: 46, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text(failed ? 'Couldn\'t load rankings' : 'No traders ranked yet',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(failed ? 'Check your connection and try again.' : 'Rankings appear as creators start trading.',
                textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
            if (failed) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final Trader trader;
  final int rank;
  const _LeaderboardRow({required this.trader, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isPositive = trader.returnPercent >= 0;
    final isTop3 = rank <= 3;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isTop3 ? AppColors.primary.withOpacity(0.04) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop3 ? AppColors.primary.withOpacity(0.15) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '$rank',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: rank <= 3 ? 18 : 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: Center(
              child: Text(
                trader.name[0],
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        trader.name,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                    if (trader.isVerified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 13),
                    ],
                  ],
                ),
                Text(
                  trader.formattedAum + ' AUM',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              trader.formattedReturn,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isPositive ? AppColors.green : AppColors.red,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              trader.formattedFollowers,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
