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
import 'login_screen.dart';

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
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 12, 0),
              child: Row(
                children: [
                  Text('Profile', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
                    onPressed: () => _openSettings(context, session),
                  ),
                ],
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                      image: user?.photoUrl != null ? DecorationImage(image: NetworkImage(user!.photoUrl!), fit: BoxFit.cover) : null,
                    ),
                    child: user?.photoUrl == null
                        ? Center(child: Text(name.isNotEmpty ? name[0] : '?', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isCreator ? AppColors.primary : AppColors.green).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(isCreator ? 'Creator' : 'Follower',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isCreator ? AppColors.primary : AppColors.green)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Stats
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  _Stat(value: '${store.subscriptionCount}', label: 'Subscriptions'),
                  const SizedBox(width: 28),
                  _Stat(value: '${store.savedCount}', label: 'Saved'),
                  if (isCreator) ...[
                    const SizedBox(width: 28),
                    _Stat(value: '0', label: 'Followers'),
                  ],
                ],
              ),
            ),
            // Tabs
            const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: 'Saved'),
                Tab(text: 'Subscriptions'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _SavedTab(posts: savedPosts),
                  _SubscriptionsTab(traders: subs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
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

class _SavedTab extends StatelessWidget {
  final List<Post> posts;
  const _SavedTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return _Empty(icon: Icons.bookmark_border_rounded, title: 'No saved posts yet', sub: 'Tap the bookmark on any post to save it here.');
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
      return _Empty(icon: Icons.group_outlined, title: 'No subscriptions yet', sub: 'Subscribe to traders in Discover to follow their trades.');
    }
    final store = AppStateScope.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: traders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final t = traders[i];
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
                      Row(
                        children: [
                          Flexible(child: Text(t.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                          if (t.isVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedBadge(size: 14),
                          ],
                        ],
                      ),
                      Text('${t.formattedFollowers} followers', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
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

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
      ],
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
  const _SettingsRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
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
