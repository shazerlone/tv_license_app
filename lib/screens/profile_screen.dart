import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/post.dart';
import '../state/session.dart';
import '../state/app_state.dart';
import '../widgets/feed_post.dart';
import '../widgets/verified_badge.dart';
import 'trader_profile_screen.dart';
import 'copy_trading_screen.dart';
import 'login_screen.dart';
import 'accounts_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final store = AppStateScope.of(context);
    final user = session.user;
    final name = user?.name ?? 'Guest';
    final isCreator = user?.isCreator ?? false;

    final savedPosts = mockPosts(mockTraders).where((p) => store.isSaved(p.id)).toList();
    final subs = mockTraders.where((t) => store.isSubscribed(t.id)).toList();

    return DefaultTabController(
      length: 3,
      child: SafeArea(
        bottom: false,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 12, 0),
                    child: Row(
                      children: [
                        Text('Profile', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.share_outlined, color: AppColors.textPrimary, size: 22), onPressed: () => _toast(context, 'Share profile')),
                        IconButton(icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary), onPressed: () => _openSettings(context, session)),
                      ],
                    ),
                  ),
                  // Identity
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.1),
                            image: user?.photoUrl != null ? DecorationImage(image: NetworkImage(user!.photoUrl!), fit: BoxFit.cover) : null,
                          ),
                          child: user?.photoUrl == null
                              ? Center(child: Text(name.isNotEmpty ? name[0] : '?', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primary)))
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.inter(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  _Chip(
                                    label: isCreator ? 'Creator' : 'Follower',
                                    color: isCreator ? AppColors.primary : AppColors.green,
                                  ),
                                  if (user?.residenceCountry != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 2),
                                    Text(user!.residenceCountry!, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Hero copy card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                    child: _CopyHero(store: store),
                  ),
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      children: [
                        Expanded(child: _OutlineBtn(icon: Icons.edit_outlined, label: 'Edit profile', onTap: () => _toast(context, 'Edit profile'))),
                        const SizedBox(width: 12),
                        Expanded(child: _OutlineBtn(icon: Icons.account_balance_wallet_outlined, label: 'Accounts', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen())))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                  unselectedLabelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                  tabs: [
                    Tab(text: 'Copying (${store.copyingCount})'),
                    Tab(text: 'Saved (${store.savedCount})'),
                    Tab(text: 'Subscriptions (${subs.length})'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _CopyingTab(store: store),
              _SavedTab(posts: savedPosts),
              _SubscriptionsTab(traders: subs),
            ],
          ),
        ),
      ),
    );
  }

  void _toast(BuildContext context, String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _openSettings(BuildContext context, SessionController session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            _SettingsRow(icon: Icons.account_balance_wallet_outlined, label: 'Trading accounts', onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountsScreen()));
            }),
            _SettingsRow(icon: Icons.person_outline_rounded, label: 'Edit profile'),
            _SettingsRow(icon: Icons.notifications_none_rounded, label: 'Notifications'),
            _SettingsRow(icon: Icons.shield_outlined, label: 'Privacy & security'),
            _SettingsRow(icon: Icons.help_outline_rounded, label: 'Help & support'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  session.signOut();
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
                label: Text('Sign out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.red)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: AppColors.red.withOpacity(0.3))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero copy card ────────────────────────────────────────────────────────────

class _CopyHero extends StatelessWidget {
  final AppState store;
  const _CopyHero({required this.store});

  @override
  Widget build(BuildContext context) {
    final net = store.netPnl;
    final positive = net >= 0;
    final hasData = store.positions.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Copy performance', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.6))),
              const Spacer(),
              Icon(positive ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 18, color: positive ? AppColors.green : AppColors.red),
            ],
          ),
          const SizedBox(height: 8),
          Text(hasData ? '${positive ? '+' : '-'}\$${net.abs().toStringAsFixed(2)}' : '\$0.00',
              style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: hasData ? (positive ? AppColors.green : AppColors.red) : Colors.white, letterSpacing: -1)),
          const SizedBox(height: 16),
          Row(
            children: [
              _HeroStat(label: 'Copying', value: '${store.copyingCount}'),
              _HeroStat(label: 'Active', value: '${store.activePositions.length}'),
              _HeroStat(label: 'Booked', value: '\$${store.bookedProfit.toStringAsFixed(0)}'),
              _HeroStat(label: 'Invested', value: '\$${store.totalInvested.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.55))),
        ],
      ),
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────

class _CopyingTab extends StatelessWidget {
  final AppState store;
  const _CopyingTab({required this.store});

  @override
  Widget build(BuildContext context) {
    final copies = store.activeCopies;
    if (copies.isEmpty) {
      return _Empty(
        icon: Icons.copy_all_rounded,
        title: 'You\'re not copying anyone yet',
        sub: 'Find a trader in Discover and tap Copy to mirror their trades automatically.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: copies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final cfg = copies[i];
        Trader? t;
        for (final x in mockTraders) {
          if (x.id == cfg.traderId) { t = x; break; }
        }
        if (t == null) return const SizedBox();
        final pnl = store.positions.where((p) => p.traderId == t!.id).fold<double>(0, (s, p) => s + p.pnlAmount);
        final positive = pnl >= 0;
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: t!))),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
                      child: Center(child: Text(t.name[0], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(child: Text(t.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                            if (t.isVerified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 14)],
                          ]),
                          Text('\$${cfg.amount.toStringAsFixed(0)} · ${cfg.risk.toStringAsFixed(1)}x risk', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${positive ? '+' : '-'}\$${pnl.abs().toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: positive ? AppColors.green : AppColors.red)),
                        Text('P/L', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CopyTradingScreen(trader: t!))),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), side: const BorderSide(color: AppColors.border)),
                        child: Text('Manage', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          store.stopCopy(t!.id);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stopped copying ${t.name}')));
                        },
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10), side: BorderSide(color: AppColors.red.withOpacity(0.4))),
                        child: Text('Stop', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.red)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SavedTab extends StatelessWidget {
  final List<Post> posts;
  const _SavedTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return _Empty(icon: Icons.bookmark_border_rounded, title: 'No saved posts yet', sub: 'Tap the bookmark on any post to save it here for later.');
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: posts.length,
      itemBuilder: (_, i) => FeedPost(
        post: posts[i],
        onOpenProfile: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: posts[i].trader))),
      ),
    );
  }
}

class _SubscriptionsTab extends StatelessWidget {
  final List<Trader> traders;
  const _SubscriptionsTab({required this.traders});

  @override
  Widget build(BuildContext context) {
    if (traders.isEmpty) {
      return _Empty(icon: Icons.group_outlined, title: 'No subscriptions yet', sub: 'Subscribe to traders to see their posts in your feed.');
    }
    final store = AppStateScope.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: traders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final t = traders[i];
        final positive = t.returnPercent >= 0;
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: t))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
                  child: Center(child: Text(t.name[0], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(t.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                        if (t.isVerified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 14)],
                      ]),
                      Text('${t.formattedCopiers} copiers · ${t.formattedReturn}', style: GoogleFonts.inter(fontSize: 12, color: positive ? AppColors.green : AppColors.red, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => store.unsubscribe(t.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                    child: Text('Subscribed', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Bits ──────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlineBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: AppColors.textPrimary),
      label: Text(label, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: AppColors.border)),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  const _Empty({required this.icon, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 46, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(sub, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SettingsRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () => Navigator.pop(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            Text(label, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.background, border: Border(bottom: BorderSide(color: AppColors.border))),
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(_TabBarDelegate old) => true;
}
