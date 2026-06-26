import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/trade.dart';
import '../widgets/verified_badge.dart';
import '../widgets/trade_card.dart';
import 'copy_trading_screen.dart';
import 'live_stream_screen.dart';

class TraderProfileScreen extends StatefulWidget {
  final Trader trader;
  const TraderProfileScreen({super.key, required this.trader});

  @override
  State<TraderProfileScreen> createState() => _TraderProfileScreenState();
}

class _TraderProfileScreenState extends State<TraderProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _isFollowing = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trader = widget.trader;
    final traderTrades = mockTrades.where((t) => t.traderId == trader.id).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (trader.isLive)
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LiveStreamScreen(trader: trader)),
                  ),
                  icon: const Icon(Icons.radio_button_checked_rounded, size: 14, color: AppColors.red),
                  label: Text('Watch Live', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red)),
                ),
              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                        child: Center(
                          child: Text(
                            trader.name[0],
                            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () => setState(() => _isFollowing = !_isFollowing),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isFollowing ? AppColors.surface : AppColors.primary,
                          foregroundColor: _isFollowing ? AppColors.textPrimary : Colors.white,
                          minimumSize: const Size(100, 40),
                          side: _isFollowing ? const BorderSide(color: AppColors.border) : null,
                          elevation: 0,
                        ),
                        child: Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CopyTradingScreen(trader: trader)),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(80, 40),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        child: Text('Copy', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        trader.name,
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      if (trader.isVerified) ...[
                        const SizedBox(width: 6),
                        const VerifiedBadge(size: 18),
                      ],
                    ],
                  ),
                  Text(
                    '@${trader.username}',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                  ),
                  if (trader.bio != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      trader.bio!,
                      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.55),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: trader.tags.map((tag) => _TagChip(label: tag)).toList(),
                  ),
                  const SizedBox(height: 20),
                  _StatsRow(trader: trader),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                indicatorWeight: 2,
                labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
                tabs: const [Tab(text: 'Open Trades'), Tab(text: 'History')],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _TradesList(trades: traderTrades.where((t) => t.status == TradeStatus.open).toList()),
            _TradesList(trades: traderTrades.where((t) => t.status == TradeStatus.closed).toList()),
          ],
        ),
      ),
    );
  }
}

class _TradesList extends StatelessWidget {
  final List<Trade> trades;
  const _TradesList({required this.trades});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return Center(
        child: Text('No trades', style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: trades.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => TradeCard(trade: trades[i], showActions: true),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final Trader trader;
  const _StatsRow({required this.trader});

  @override
  Widget build(BuildContext context) {
    final isPositive = trader.returnPercent >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _StatCell(
            label: 'Return (${trader.returnDays}D)',
            value: trader.formattedReturn,
            valueColor: isPositive ? AppColors.green : AppColors.red,
          ),
          _VerticalDivider(),
          _StatCell(label: 'Followers', value: trader.formattedFollowers),
          _VerticalDivider(),
          _StatCell(label: 'AUM', value: trader.formattedAum),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatCell({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.border);
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate({required this.tabBar});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabBarDelegate old) => old.tabBar != tabBar;
}
