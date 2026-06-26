import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../widgets/verified_badge.dart';
import 'trader_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedPeriod = 0;
  static const List<String> _periods = ['7D', '30D', '90D', 'All Time'];

  List<Trader> get _sorted {
    final list = List<Trader>.from(mockTraders);
    list.sort((a, b) => b.returnPercent.compareTo(a.returnPercent));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sorted;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: false,
          floating: true,
          snap: true,
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 24,
          title: Text('Rankings', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_periods.length, (i) {
                  final active = i == _selectedPeriod;
                  return Padding(
                    padding: EdgeInsets.only(right: i < _periods.length - 1 ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: active ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(
                          _periods[i],
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: active ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                const SizedBox(width: 32),
                Expanded(
                  child: Text('#  Trader', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                ),
                SizedBox(
                  width: 72,
                  child: Text('Return', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                ),
                SizedBox(
                  width: 60,
                  child: Text('Followers', textAlign: TextAlign.right, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: sorted[i])),
              ),
              child: _LeaderboardRow(trader: sorted[i], rank: i + 1),
            ),
            childCount: sorted.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
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
