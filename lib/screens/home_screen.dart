import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/post.dart';
import '../models/trade.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/verified_badge.dart';
import '../widgets/millimore_logo.dart';
import '../widgets/trade_card.dart';
import 'trader_profile_screen.dart';
import 'live_stream_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _HomeFeed(),
      const _DiscoverTab(),
      const LiveStreamScreen(),
      const LeaderboardScreen(),
      const _ProfileTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _navIndex, children: _pages),
      bottomNavigationBar: MillimoreBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }
}

class _HomeFeed extends StatelessWidget {
  const _HomeFeed();

  @override
  Widget build(BuildContext context) {
    final posts = mockPosts(mockTraders);
    final liveTraders = mockTraders.where((t) => t.isLive).toList();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (liveTraders.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Live Now',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemCount: liveTraders.length,
                    itemBuilder: (_, i) => _LiveTraderAvatar(
                      trader: liveTraders[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LiveStreamScreen(trader: liveTraders[i]),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(indent: 24, endIndent: 24),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: EdgeInsets.fromLTRB(24, i == 0 ? 0 : 8, 24, 8),
              child: _PostCard(post: posts[i]),
            ),
            childCount: posts.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
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
                  child: Text(
                    trader.name[0],
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'LIVE',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 68,
            child: Text(
              trader.name.split(' ')[0],
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TraderProfileScreen(trader: post.trader),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TraderAvatar(name: post.trader.name, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            post.trader.name,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (post.trader.isVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedBadge(size: 14),
                          ],
                        ],
                      ),
                      Text(
                        post.timeAgo,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (post.pair != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      post.pair!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _ActionButton(
                  icon: post.isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: '${post.likes}',
                  color: post.isLiked ? AppColors.red : AppColors.textMuted,
                ),
                const SizedBox(width: 20),
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: '${post.comments}',
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ActionButton({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _TraderAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _TraderAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.1),
      ),
      child: Center(
        child: Text(
          name[0],
          style: GoogleFonts.inter(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context) {
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
          title: Text('Discover', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          sliver: SliverToBoxAdapter(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search traders, pairs, markets...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Text('Top Traders', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: EdgeInsets.fromLTRB(24, i == 0 ? 12 : 0, 24, 12),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: mockTraders[i])),
                ),
                child: _TraderListItem(trader: mockTraders[i]),
              ),
            ),
            childCount: mockTraders.length,
          ),
        ),
      ],
    );
  }
}

class _TraderListItem extends StatelessWidget {
  final Trader trader;
  const _TraderListItem({required this.trader});

  @override
  Widget build(BuildContext context) {
    final isPositive = trader.returnPercent >= 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _TraderAvatar(name: trader.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(trader.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    if (trader.isVerified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 14),
                    ],
                  ],
                ),
                Text(trader.formattedFollowers + ' followers', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(
            trader.formattedReturn,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPositive ? AppColors.green : AppColors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Profile coming soon',
        style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary),
      ),
    );
  }
}
