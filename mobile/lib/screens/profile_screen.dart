import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import '../config.dart';
import '../services/auth_api.dart';
import '../services/backend_api.dart';
import '../models/trader.dart';
import '../models/post.dart';
import '../state/session.dart';
import '../state/app_state.dart';
import '../state/theme_controller.dart';
import '../widgets/feed_post.dart';
import '../widgets/verified_badge.dart';
import 'trader_profile_screen.dart';
import 'login_screen.dart';
import 'accounts_screen.dart';
import 'copied_trades_screen.dart';
import 'support_chat_screen.dart';
import 'support_screen.dart';
import 'edit_profile_screen.dart';
import 'kyc_screen.dart';
import 'wallet_screen.dart';
import 'referrals_screen.dart';
import 'security_screen.dart';

/// One simple profile page: who you are, your copy performance, and clear
/// buttons out to everything else. No tabs, no nested navigation.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final store = AppStateScope.of(context);
    final user = session.user;
    final name = user?.name ?? 'Guest';
    final isCreator = user?.isCreator ?? false;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Text('Profile', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                const Spacer(),
                _CircleIcon(icon: Icons.ios_share_rounded, onTap: () => _push(context, const ReferralsScreen())),
              ],
            ),
            const SizedBox(height: 20),

            // Identity
            Row(
              children: [
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.1),
                    image: user?.photoUrl != null ? DecorationImage(image: NetworkImage(user!.photoUrl!), fit: BoxFit.cover) : null,
                  ),
                  child: user?.photoUrl == null
                      ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary)))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _Chip(label: isCreator ? 'Creator' : 'Follower', color: isCreator ? AppColors.primary : AppColors.green),
                          if (user != null && user.kycStatus != 'none') ...[
                            const SizedBox(width: 8),
                            _Chip(
                              label: user.kycStatus == 'verified'
                                  ? 'Verified'
                                  : user.kycStatus == 'pending'
                                      ? 'ID review'
                                      : 'ID rejected',
                              color: user.kycStatus == 'verified'
                                  ? AppColors.green
                                  : user.kycStatus == 'pending'
                                      ? AppColors.primary
                                      : AppColors.red,
                            ),
                          ],
                          if (user?.residenceCountry != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 2),
                            Flexible(child: Text(user!.residenceCountry!, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted))),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _push(context, const EditProfileScreen()),
                icon: Icon(Icons.edit_outlined, size: 18, color: AppColors.textPrimary),
                label: Text('Edit profile', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 16),

            // Phone-registered accounts have no email yet — nudge them to add one
            // (for receipts, password recovery & security alerts). Hidden once set.
            if (user != null && (user.email == null || user.email!.isEmpty)) ...[
              _AddEmailBanner(onTap: () => _push(context, const EditProfileScreen())),
              const SizedBox(height: 16),
            ],

            // Account / KYC status — informative, not nagging. Deposits &
            // withdrawals unlock once identity is verified.
            if (user != null) _AccountStatusCard(user: user, onVerify: () => _push(context, const KycScreen())),

            // Copy performance
            _CopyHero(store: store),
            const SizedBox(height: 24),

            // Menu — buttons out to pages
            Text('Your activity', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.2)),
            const SizedBox(height: 10),
            _MenuCard(children: [
              _MenuTile(icon: Icons.account_balance_wallet_rounded, color: AppColors.green, label: 'Wallet',
                  onTap: () => _push(context, const WalletScreen())),
              _MenuTile(icon: Icons.swap_vert_rounded, color: AppColors.primary, label: 'Copied trades', trailing: '${store.copyingCount}',
                  onTap: () => _push(context, const CopiedTradesScreen())),
              _MenuTile(icon: Icons.account_balance_wallet_outlined, color: AppColors.green, label: 'Trading accounts',
                  onTap: () => _push(context, const AccountsScreen())),
              _MenuTile(icon: Icons.bookmark_border_rounded, color: AppColors.purple, label: 'Saved posts', trailing: '${store.savedCount}',
                  onTap: () => _push(context, const SavedPostsScreen())),
              _MenuTile(icon: Icons.group_outlined, color: AppColors.primaryLight, label: 'Subscriptions', trailing: '${store.subscriptionCount}',
                  onTap: () => _push(context, const SubscriptionsScreen())),
              if (isCreator)
                _MenuTile(icon: Icons.article_outlined, color: AppColors.primary, label: 'My posts',
                    onTap: () => _openMyPosts(context)),
              _MenuTile(icon: Icons.card_giftcard_rounded, color: AppColors.purple, label: 'Invite & earn',
                  onTap: () => _push(context, const ReferralsScreen()), last: true),
            ]),
            const SizedBox(height: 20),

            Text('Preferences', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.2)),
            const SizedBox(height: 10),
            _MenuCard(children: const [_DarkModeTile()]),
            const SizedBox(height: 20),

            Text('Support', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.2)),
            const SizedBox(height: 10),
            _MenuCard(children: [
              _MenuTile(icon: Icons.shield_outlined, color: AppColors.slate, label: 'Security & 2FA', onTap: () => kUseBackend ? _push(context, const SecurityScreen()) : _toast(context, 'Privacy & security')),
              _MenuTile(icon: Icons.help_outline_rounded, color: AppColors.slate, label: 'Help & support', onTap: () => _push(context, kUseBackend ? const SupportScreen() : const SupportChatScreen()), last: true),
            ]),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  AuthApi.logout();
                  session.signOut();
                  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
                },
                icon: Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
                label: Text('Sign out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.red)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: AppColors.red.withOpacity(0.3))),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text('millimore · $kBuildLabel', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted.withOpacity(0.7)))),
          ],
        ),
      ),
    );
  }

  static void _push(BuildContext context, Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  static void _toast(BuildContext context, String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Opens the creator's own public profile (owner mode) so they can see and
  /// delete their posts. Resolves the trader id cached when they last posted.
  static Future<void> _openMyPosts(BuildContext context) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('creator_trader_id');
    if (id == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Publish a post first — it\'ll appear on your creator profile.')));
      return;
    }
    try {
      final t = Trader.fromApi(await BackendApi.trader(id));
      nav.push(MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: t, isOwner: true)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not load your profile — try again')));
    }
  }
}

// ── Copy performance card ─────────────────────────────────────────────────────

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

// ── Menu ──────────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  final bool last;
  const _MenuTile({required this.icon, required this.color, required this.label, this.trailing, required this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            if (trailing != null && trailing != '0') ...[
              Text(trailing!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
              const SizedBox(width: 6),
            ],
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DarkModeTile extends StatelessWidget {
  const _DarkModeTile();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final isDark = AppColors.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text('Dark mode', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          Switch(
            value: isDark,
            activeColor: AppColors.primary,
            onChanged: (v) => theme.toggleDark(v),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIcon({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
        child: Icon(icon, size: 19, color: AppColors.textPrimary),
      ),
    );
  }
}

/// Nudge shown to phone-registered accounts that have no email yet.
class _AddEmailBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AddEmailBanner({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.mark_email_unread_outlined, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add your email', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('For receipts, password recovery & security alerts.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// Account/KYC status with an unlock hint. Informative — the user is never
/// nagged; deposits & withdrawals are simply locked until verified.
class _AccountStatusCard extends StatelessWidget {
  final dynamic user; // UserProfile
  final VoidCallback onVerify;
  const _AccountStatusCard({required this.user, required this.onVerify});

  @override
  Widget build(BuildContext context) {
    final status = (user.kycStatus ?? 'none').toString();
    final verified = status == 'verified';
    final pending = status == 'pending';
    final rejected = status == 'rejected';

    final (IconData icon, Color color, String title, String sub) = verified
        ? (Icons.verified_user_rounded, AppColors.green, 'Identity verified', 'Deposits & withdrawals are enabled.')
        : pending
            ? (Icons.hourglass_top_rounded, AppColors.primary, 'Verification under review', 'We\'ll unlock deposits & withdrawals once approved.')
            : rejected
                ? (Icons.error_outline_rounded, AppColors.red, 'Verification needs attention', 'Please re-submit your ID to unlock deposits & withdrawals.')
                : (Icons.badge_outlined, AppColors.slate, 'Verify your identity', 'Unlock deposits & withdrawals with a quick ID check.');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: verified ? AppColors.green.withOpacity(0.35) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(sub, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted, height: 1.35)),
              ],
            ),
          ),
          if (!verified && !pending) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onVerify,
              style: TextButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
              child: Text('Verify', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}

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

// ── Sub-pages reached from the menu ───────────────────────────────────────────

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});
  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List<Post> _posts = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (kUseBackend) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final list = await BackendApi.saved();
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

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final posts = kUseBackend ? _posts : mockPosts(mockTraders).where((p) => store.isSaved(p.id)).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Saved posts', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: _loading && posts.isEmpty
          ? const AppLoader()
          : posts.isEmpty
              ? _Empty(icon: Icons.bookmark_border_rounded, title: 'No saved posts yet', sub: 'Tap the bookmark on any post to save it here for later.')
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: posts.length,
                  itemBuilder: (_, i) => FeedPost(
                    post: posts[i],
                    onOpenProfile: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: posts[i].trader))),
                  ),
                ),
    );
  }
}

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});
  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  List<Trader> _backendTraders = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (kUseBackend) {
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final list = await BackendApi.subscriptions();
      if (!mounted) return;
      setState(() {
        _backendTraders = list.map(Trader.fromApi).toList();
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
    final traders = kUseBackend ? _backendTraders : mockTraders.where((t) => store.isSubscribed(t.id)).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Subscriptions', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: _loading && traders.isEmpty
          ? const AppLoader()
          : traders.isEmpty
          ? _Empty(icon: Icons.group_outlined, title: 'No subscriptions yet', sub: 'Subscribe to traders to see their posts in your feed.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            ),
    );
  }
}
