import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/trade.dart';
import '../models/post.dart';
import '../state/app_state.dart';
import '../widgets/verified_badge.dart';
import '../widgets/trade_card.dart';
import '../widgets/feed_post.dart';
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
    final store = AppStateScope.of(context);
    final subscribed = store.isSubscribed(trader.id);
    final traderTrades = mockTrades.where((t) => t.traderId == trader.id).toList();
    final traderPosts = mockPosts(mockTraders).where((p) => p.trader.id == trader.id).toList();

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
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveStreamScreen(trader: trader))),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.1),
                              border: trader.isLive ? Border.all(color: AppColors.red, width: 2.5) : null,
                            ),
                            child: Center(
                              child: Text(trader.name[0], style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ),
                          ),
                          if (trader.isLive)
                            Positioned(
                              bottom: -6, left: 0, right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4)),
                                  child: Text('LIVE', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      _SubscribeButton(
                        subscribed: subscribed,
                        notify: store.isNotifying(trader.id),
                        onSubscribe: () => store.subscribe(trader.id),
                        onUnsub: () => store.unsubscribe(trader.id),
                        onToggleNotify: () => store.toggleNotify(trader.id),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Flexible(child: Text(trader.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4))),
                      if (trader.isVerified) ...[
                        const SizedBox(width: 6),
                        const VerifiedBadge(size: 18),
                      ],
                    ],
                  ),
                  Text('@${trader.username}', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                  if (trader.bio != null) ...[
                    const SizedBox(height: 10),
                    Text(trader.bio!, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.55)),
                  ],
                  if (trader.tags.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: trader.tags.map((t) => _TagChip(label: t)).toList()),
                  ],
                  const SizedBox(height: 18),
                  _EquityCard(trader: trader),
                  const SizedBox(height: 14),
                  _StatsRow(trader: trader),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CopyTradingScreen(trader: trader))),
                      icon: const Icon(Icons.copy_all_rounded, size: 18, color: AppColors.primary),
                      label: Text('Copy this trader', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 18),
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
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                tabs: const [Tab(text: 'Posts'), Tab(text: 'Trades')],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _PostsList(posts: traderPosts),
            _TradesList(trades: traderTrades),
          ],
        ),
      ),
    );
  }
}

// ── Subscribe button (synced to AppState) ─────────────────────────────────────

class _SubscribeButton extends StatelessWidget {
  final bool subscribed;
  final bool notify;
  final VoidCallback onSubscribe;
  final VoidCallback onUnsub;
  final VoidCallback onToggleNotify;
  const _SubscribeButton({required this.subscribed, required this.notify, required this.onSubscribe, required this.onUnsub, required this.onToggleNotify});

  @override
  Widget build(BuildContext context) {
    if (!subscribed) {
      return ElevatedButton(
        onPressed: onSubscribe,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(112, 42),
          elevation: 0,
        ),
        child: Text('Subscribe', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton(
          onPressed: onUnsub,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(104, 42),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Text('Subscribed', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onToggleNotify,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: notify ? AppColors.primary : AppColors.border),
              color: notify ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
            ),
            child: Icon(notify ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                size: 19, color: notify ? AppColors.primary : AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

// ── Equity chart ──────────────────────────────────────────────────────────────

class _EquityCard extends StatelessWidget {
  final Trader trader;
  const _EquityCard({required this.trader});

  @override
  Widget build(BuildContext context) {
    final positive = trader.returnPercent >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Equity curve', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.6))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (positive ? AppColors.green : AppColors.red).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${trader.returnDays}D ${trader.formattedReturn}',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: positive ? AppColors.green : AppColors.red)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(painter: _EquityPainter(seed: trader.id.hashCode, positive: positive)),
          ),
        ],
      ),
    );
  }
}

class _EquityPainter extends CustomPainter {
  final int seed;
  final bool positive;
  _EquityPainter({required this.seed, required this.positive});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    const n = 24;
    final color = positive ? AppColors.green : AppColors.red;
    double v = size.height * 0.7;
    final pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final drift = positive ? -size.height * 0.018 : size.height * 0.012;
      v += drift + (rng.nextDouble() - 0.5) * size.height * 0.10;
      v = v.clamp(size.height * 0.12, size.height * 0.92);
      pts.add(Offset(size.width * i / (n - 1), v));
    }

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      path.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }

    final fill = Path.from(path)..lineTo(pts.last.dx, size.height)..lineTo(pts.first.dx, size.height)..close();
    canvas.drawPath(
      fill,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(0.25), Colors.transparent]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.drawCircle(pts.last, 4, Paint()..color = color);
    canvas.drawCircle(pts.last, 7, Paint()..color = color.withOpacity(0.25));
  }

  @override
  bool shouldRepaint(_EquityPainter old) => false;
}

// ── Tabs content ──────────────────────────────────────────────────────────────

class _PostsList extends StatelessWidget {
  final List<Post> posts;
  const _PostsList({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return _Empty(icon: Icons.dynamic_feed_rounded, text: 'No posts yet');
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: posts.length,
      itemBuilder: (_, i) => FeedPost(post: posts[i]),
    );
  }
}

class _TradesList extends StatelessWidget {
  final List<Trade> trades;
  const _TradesList({required this.trades});

  @override
  Widget build(BuildContext context) {
    if (trades.isEmpty) {
      return _Empty(icon: Icons.candlestick_chart_rounded, text: 'No trades shared yet');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: trades.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => TradeCard(trade: trades[i], showActions: true),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 42, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(text, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Trader trader;
  const _StatsRow({required this.trader});

  @override
  Widget build(BuildContext context) {
    final isPositive = trader.returnPercent >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          _StatCell(label: 'Return (${trader.returnDays}D)', value: trader.formattedReturn, valueColor: isPositive ? AppColors.green : AppColors.red),
          _VDivider(),
          _StatCell(label: 'Followers', value: trader.formattedFollowers),
          _VDivider(),
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
          Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 36, color: AppColors.border);
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.border)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate({required this.tabBar});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
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
