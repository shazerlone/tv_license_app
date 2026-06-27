import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/post.dart';
import '../models/trade.dart';
import '../state/session.dart';
import '../state/app_state.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/millimore_logo.dart';
import '../widgets/feed_post.dart';
import 'trader_profile_screen.dart';
import 'live_stream_screen.dart';
import 'studio_screen.dart';
import 'copied_trades_screen.dart';
import 'profile_screen.dart';
import 'discover_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final isCreator = session.isCreator;

    final pages = isCreator
        ? const [
            CreatorHome(),
            DiscoverTab(),
            StudioScreen(),
            CopiedTradesScreen(),
            ProfileScreen(),
          ]
        : const [
            FollowerHome(),
            DiscoverTab(),
            CopiedTradesScreen(),
            ProfileScreen(),
          ];

    final items = isCreator
        ? const [
            NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
            NavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'Discover'),
            NavItem(icon: Icons.add_rounded, activeIcon: Icons.add_rounded, label: 'Studio', emphasized: true),
            NavItem(icon: Icons.swap_vert_rounded, activeIcon: Icons.swap_vert_rounded, label: 'Trades'),
            NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
          ]
        : const [
            NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
            NavItem(icon: Icons.explore_outlined, activeIcon: Icons.explore_rounded, label: 'Discover'),
            NavItem(icon: Icons.swap_vert_rounded, activeIcon: Icons.swap_vert_rounded, label: 'Trades'),
            NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _navIndex, children: pages),
      bottomNavigationBar: MillimoreBottomNav(
        items: items,
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// FOLLOWER HOME
// ════════════════════════════════════════════════════════════════════════════

class FollowerHome extends StatelessWidget {
  const FollowerHome();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final store = AppStateScope.of(context);
    final name = session.user?.name.split(' ').first ?? 'there';
    final subscribedIds = store.subscribedTraderIds;
    final posts = mockPosts(mockTraders).where((p) => subscribedIds.contains(p.trader.id)).toList();
    final liveTraders = mockTraders.where((t) => t.isLive && subscribedIds.contains(t.id)).toList();
    final openCopied = mockTrades.where((t) => t.status == TradeStatus.open).toList();
    final totalPnl = openCopied.fold<double>(0, (s, t) => s + t.pnlPercent);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 24,
          title: const MillimoreLogo(size: 24),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi $name 👋',
                    style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text('Here\'s how your traders are doing today.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
        // Portfolio summary
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: _PortfolioCard(totalPnl: totalPnl, openCount: openCopied.length, following: store.subscriptionCount),
          ),
        ),
        if (liveTraders.isNotEmpty) ...[
          SliverToBoxAdapter(child: _SectionHeader(dot: true, title: 'Live now')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemCount: liveTraders.length,
                itemBuilder: (_, i) => _LiveTraderAvatar(
                  trader: liveTraders[i],
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => LiveStreamScreen(trader: liveTraders[i]))),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
        SliverToBoxAdapter(child: _SectionHeader(title: 'From your subscriptions')),
        if (posts.isEmpty)
          SliverToBoxAdapter(child: _EmptyFeed())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => FeedPost(
                post: posts[i],
                onOpenProfile: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: posts[i].trader))),
              ),
              childCount: posts.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        children: [
          Icon(Icons.dynamic_feed_rounded, size: 44, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 14),
          Text('Your feed is quiet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Subscribe to traders in Discover to see their posts here.',
              textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final double totalPnl;
  final int openCount;
  final int following;
  const _PortfolioCard({required this.totalPnl, required this.openCount, required this.following});

  @override
  Widget build(BuildContext context) {
    final positive = totalPnl >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Open copied P&L',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${positive ? '+' : ''}${totalPnl.toStringAsFixed(2)}%',
                  style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: positive ? AppColors.green : AppColors.red, letterSpacing: -1)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Icon(positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: positive ? AppColors.green : AppColors.red, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(label: 'Open positions', value: '$openCount'),
              const SizedBox(width: 28),
              _MiniStat(label: 'Subscriptions', value: '$following'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.55))),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CREATOR HOME
// ════════════════════════════════════════════════════════════════════════════

class CreatorHome extends StatelessWidget {
  const CreatorHome();

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final name = session.user?.name.split(' ').first ?? 'Creator';
    final pending = session.user?.creatorStatus == CreatorStatus.pending;
    final posts = mockPosts(mockTraders).take(2).toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AppColors.background,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 24,
          title: const MillimoreLogo(size: 24),
          actions: [
            IconButton(icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary), onPressed: () {}),
            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: Text('Welcome back, $name',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
          ),
        ),
        if (pending)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: _PendingBanner(),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: _CreatorStatsCard(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                Expanded(child: _QuickAction(icon: Icons.podcasts_rounded, label: 'Go Live', color: AppColors.red, onTap: () => _openStudio(context))),
                const SizedBox(width: 12),
                Expanded(child: _QuickAction(icon: Icons.add_chart_rounded, label: 'Post Trade', color: AppColors.primary, onTap: () => _openStudio(context))),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _SectionHeader(title: 'Your recent posts')),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => FeedPost(
              post: posts[i],
              onOpenProfile: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: posts[i].trader))),
            ),
            childCount: posts.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  void _openStudio(BuildContext context) {
    final state = context.findAncestorStateOfType<_HomeScreenState>();
    state?.setState(() => state._navIndex = 2);
  }
}

class _PendingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verification in review',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                Text('You can go live & post once approved (24–48h).',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatorStatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _DarkStat(label: 'Followers', value: '0')),
              Expanded(child: _DarkStat(label: '30D return', value: '—')),
              Expanded(child: _DarkStat(label: 'Earnings', value: '\$0')),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: Colors.white38, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Your stats activate once your account is verified.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withOpacity(0.55))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DarkStat extends StatelessWidget {
  final String label;
  final String value;
  const _DarkStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withOpacity(0.55))),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED
// ════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool dot;
  const _SectionHeader({required this.title, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          if (dot) ...[
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _LiveTraderAvatar extends StatelessWidget {
  final Trader trader;
  final VoidCallback onTap;
  const _LiveTraderAvatar({required this.trader, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.red, width: 2.5),
                  color: AppColors.surface,
                ),
                child: Center(
                  child: Text(trader.name[0],
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4)),
                  child: Text('LIVE',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 68,
            child: Text(trader.name.split(' ')[0],
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

