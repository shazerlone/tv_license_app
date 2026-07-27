import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../models/trader.dart';
import '../models/post.dart';
import '../models/trade.dart';
import '../models/app_notification.dart';
import '../services/backend_api.dart';
import '../state/session.dart';
import '../state/app_state.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/millimore_logo.dart';
import '../widgets/verified_badge.dart';
import '../widgets/avatar.dart';
import '../widgets/feed_post.dart';
import 'trader_profile_screen.dart';
import 'live_stream_screen.dart';
import 'studio_screen.dart';
import 'copied_trades_screen.dart';
import 'profile_screen.dart';
import 'discover_screen.dart';
import 'leaderboard_screen.dart';
import 'compose_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  void goToTab(int i) => setState(() => _navIndex = i);

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

class FollowerHome extends StatefulWidget {
  const FollowerHome();

  @override
  State<FollowerHome> createState() => _FollowerHomeState();
}

class _FollowerHomeState extends State<FollowerHome> {
  List<Trader> _topCreators = const [];
  List<Trader> _liveTraders = const [];
  List<Post> _feed = const [];
  bool _loading = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    if (kUseBackend) {
      _loading = true;
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!kUseBackend && !_seeded) {
      _seeded = true;
      final store = AppStateScope.of(context);
      final subscribedIds = store.subscribedTraderIds;
      _topCreators = ([...mockTraders]..sort((a, b) => b.copiers.compareTo(a.copiers))).take(8).toList();
      _feed = mockPosts(mockTraders).where((p) => subscribedIds.contains(p.trader.id)).toList();
      _liveTraders = mockTraders.where((t) => t.isLive && subscribedIds.contains(t.id)).toList();
    }
  }

  /// Live data: top creators (GET /traders?sort=copiers) + subscription feed
  /// (GET /feed). No demo content when useBackend.
  Future<void> _load() async {
    final store = AppStateScope.of(context);
    await store.loadSocial(); // refresh real follow graph first
    store.loadNotifications(); // server notifications (if endpoint exists)
    try {
      final page = await BackendApi.traders(sort: 'copiers');
      final feed = await BackendApi.feed();
      if (!mounted) return;
      final traders = page.items.map(Trader.fromApi).toList();
      // Alert for followed traders that are currently live.
      store.notifyLiveTraders(traders.where((t) => t.isLive && store.isSubscribed(t.id)));
      setState(() {
        _topCreators = traders.take(8).toList();
        _liveTraders = traders.where((t) => t.isLive).toList();
        _feed = feed.map(Post.fromApi).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final openCopied = mockTrades.where((t) => t.status == TradeStatus.open).toList();
    final totalPnl = openCopied.fold<double>(0, (s, t) => s + t.pnlPercent);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => kUseBackend ? _load() : Future.delayed(const Duration(milliseconds: 700)),
      child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
            _AppBarIcon(
                icon: Icons.search_rounded,
                onTap: () => context.findAncestorStateOfType<_HomeScreenState>()?.goToTab(1)),
            _AppBarIcon(
                icon: Icons.notifications_none_rounded,
                onTap: () => showNotificationsSheet(context),
                dot: store.unreadNotifications > 0),
            const SizedBox(width: 16),
          ],
        ),
        // Portfolio summary (copy engine — demo until milestone 4)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: _PortfolioCard(totalPnl: totalPnl, openCount: openCopied.length, following: store.subscriptionCount),
          ),
        ),
        if (_liveTraders.isNotEmpty) ...[
          SliverToBoxAdapter(child: _SectionHeader(dot: true, title: 'Live now')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemCount: _liveTraders.length,
                itemBuilder: (_, i) => _LiveTraderAvatar(
                  trader: _liveTraders[i],
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => LiveStreamScreen(trader: _liveTraders[i]))),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
        // Top creators to copy
        if (_topCreators.isNotEmpty) ...[
          SliverToBoxAdapter(
              child: _SectionHeader(
                  title: 'Top creators to copy',
                  onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaderboardScreen())))),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemCount: _topCreators.length,
                itemBuilder: (_, i) => _CreatorMiniCard(trader: _topCreators[i]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
        ],
        SliverToBoxAdapter(child: _SectionHeader(title: 'From your subscriptions')),
        if (_loading)
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())),
          )
        else if (_feed.isEmpty)
          SliverToBoxAdapter(child: _EmptyFeed())
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => FeedPost(
                post: _feed[i],
                onOpenProfile: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: _feed[i].trader))),
              ),
              childCount: _feed.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dot;
  const _AppBarIcon({required this.icon, required this.onTap, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 24),
            if (dot)
              Positioned(
                right: -1, top: -1,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 1.5)),
                ),
              ),
          ],
        ),
      ),
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

class CreatorHome extends StatefulWidget {
  const CreatorHome();

  @override
  State<CreatorHome> createState() => _CreatorHomeState();
}

class _CreatorHomeState extends State<CreatorHome> {
  List<Post> _posts = const [];
  bool _loading = false;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final id = SessionScope.of(context).user?.id;
    if (kUseBackend && id != null) {
      _loading = true;
      _loadPosts(id);
    } else if (!kUseBackend) {
      _posts = mockPosts(mockTraders).take(2).toList();
    }
  }

  Future<void> _loadPosts(String id) async {
    try {
      final list = await BackendApi.traderPosts(id);
      if (!mounted) return;
      setState(() {
        _posts = list.map(Post.fromApi).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _compose() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const ComposePostScreen()));
    final id = SessionScope.of(context).user?.id;
    if (ok == true && id != null) _loadPosts(id);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final pending = session.user?.creatorStatus == CreatorStatus.pending;
    final posts = _posts;

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
            _AppBarIcon(
                icon: Icons.insights_rounded,
                onTap: () => context.findAncestorStateOfType<_HomeScreenState>()?.goToTab(3)),
            _AppBarIcon(
                icon: Icons.notifications_none_rounded,
                onTap: () => showNotificationsSheet(context),
                dot: AppStateScope.of(context).unreadNotifications > 0),
            const SizedBox(width: 16),
          ],
        ),
        if (pending)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: _PendingBanner(),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, pending ? 0 : 8, 24, 20),
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
                Expanded(child: _QuickAction(icon: Icons.add_chart_rounded, label: 'Post Trade', color: AppColors.primary, onTap: pending ? () => _openStudio(context) : _compose)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _SectionHeader(title: 'Your recent posts')),
        if (_loading)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator())))
        else if (posts.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  Icon(Icons.post_add_rounded, size: 42, color: AppColors.textMuted.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text('No posts yet', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Share a trade idea or lesson to grow your following.',
                      textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
          )
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
          Icon(Icons.hourglass_top_rounded, color: AppColors.primary, size: 20),
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
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.dot = false, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          if (dot) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.red, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              behavior: HitTestBehavior.opaque,
              child: Text('See all', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
        ],
      ),
    );
  }
}

class _CreatorMiniCard extends StatelessWidget {
  final Trader trader;
  const _CreatorMiniCard({required this.trader});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final subscribed = store.isSubscribed(trader.id);
    final positive = trader.returnPercent >= 0;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: trader))),
      child: Container(
        width: 158,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(name: trader.name, photoUrl: trader.avatarUrl, size: 40),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: (positive ? AppColors.green : AppColors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(trader.formattedReturn, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: positive ? AppColors.green : AppColors.red)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(child: Text(trader.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                if (trader.isVerified) ...[const SizedBox(width: 3), const VerifiedBadge(size: 13)],
              ],
            ),
            Text('${trader.formattedCopiers} copiers · ${trader.winRate.toStringAsFixed(0)}% win', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => store.toggleSubscribe(trader.id),
                child: Container(
                  height: 34, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: subscribed ? Colors.transparent : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(20),
                    border: subscribed ? Border.all(color: AppColors.border) : null,
                  ),
                  child: Text(subscribed ? 'Subscribed' : 'Subscribe', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: subscribed ? AppColors.textSecondary : Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notifications ───────────────────────────────────────────────────────────

void showNotificationsSheet(BuildContext context) {
  final store = AppStateScope.of(context);
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (sheetContext, controller) {
        final items = store.notifications;
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(
                children: [
                  Text('Notifications', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                  const Spacer(),
                  if (store.unreadNotifications > 0)
                    GestureDetector(
                      onTap: () => store.markNotificationsRead(),
                      child: Text('Mark all read', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 46, color: AppColors.textMuted.withOpacity(0.5)),
                            const SizedBox(height: 14),
                            Text('You\'re all caught up', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            Text('Live alerts and trade updates from traders you follow will show up here.',
                                textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) => _NotifRow(items[i]),
                    ),
            ),
          ],
        );
      },
    ),
  ).whenComplete(() => store.markNotificationsRead());
}

class _NotifRow extends StatelessWidget {
  final AppNotification n;
  const _NotifRow(this.n);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: !n.read ? AppColors.primary.withOpacity(0.04) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: n.color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(n.icon, color: n.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(n.body, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(n.timeAgo, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted)),
              if (!n.read) ...[
                const SizedBox(height: 6),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
              ],
            ],
          ),
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
              Avatar(name: trader.name, photoUrl: trader.avatarUrl, size: 64, ringColor: AppColors.red),
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

