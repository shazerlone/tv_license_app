import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/post.dart';
import '../state/app_state.dart';
import 'verified_badge.dart';
import 'comments_sheet.dart';

/// A premium X / Threads-style feed post, fully wired to [AppState]:
/// subscribe→bell, like, repost, comment (opens thread), share, bookmark.
class FeedPost extends StatelessWidget {
  final Post post;
  final VoidCallback? onOpenProfile;
  final bool showDivider;

  const FeedPost({
    super.key,
    required this.post,
    this.onOpenProfile,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final traderId = post.trader.id;
    final subscribed = store.isSubscribed(traderId);

    return Container(
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: AppColors.border)) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(name: post.trader.name, photoUrl: post.trader.avatarUrl, live: post.trader.isLive, onTap: onOpenProfile),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onOpenProfile,
                          child: _IdentityLine(
                            name: post.trader.name,
                            username: post.trader.username,
                            verified: post.trader.isVerified,
                            time: post.timeAgo.replaceAll(' ago', ''),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SubscribeControl(
                        subscribed: subscribed,
                        notify: store.isNotifying(traderId),
                        onSubscribe: () {
                          store.subscribe(traderId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Subscribed to ${post.trader.name}')),
                          );
                        },
                        onToggleNotify: () => store.toggleNotify(traderId),
                      ),
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () => _moreSheet(context),
                        child: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(post.content, style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary, height: 1.5)),
                  if (post.pair != null) ...[
                    const SizedBox(height: 12),
                    _TradeChip(pair: post.pair!, type: post.type),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _ActionIcon(
                        icon: Icons.mode_comment_outlined,
                        count: store.commentCount(post),
                        onTap: () => CommentsSheet.open(context, post),
                      ),
                      _ActionIcon(
                        icon: Icons.repeat_rounded,
                        count: (post.likes / 6).round(),
                        onTap: () => _repostSheet(context),
                      ),
                      _ActionIcon(
                        icon: store.isLiked(post) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        count: store.likeCount(post),
                        active: store.isLiked(post),
                        activeColor: AppColors.red,
                        onTap: () => store.toggleLike(post),
                      ),
                      _ActionIcon(
                        icon: Icons.ios_share_rounded,
                        onTap: () => _shareSheet(context),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          store.toggleSave(post.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(store.isSaved(post.id) ? 'Saved to your profile' : 'Removed from saved')),
                          );
                        },
                        child: Icon(
                          store.isSaved(post.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 19,
                          color: store.isSaved(post.id) ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _shareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimpleSheet(
        title: 'Share post',
        rows: const [
          (Icons.link_rounded, 'Copy link'),
          (Icons.send_rounded, 'Send via direct message'),
          (Icons.repeat_rounded, 'Repost to your followers'),
        ],
      ),
    );
  }

  void _repostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimpleSheet(
        title: 'Repost',
        rows: const [
          (Icons.repeat_rounded, 'Repost'),
          (Icons.format_quote_rounded, 'Quote post'),
        ],
      ),
    );
  }

  void _moreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimpleSheet(
        title: post.trader.name,
        rows: const [
          (Icons.volume_off_rounded, 'Mute this trader'),
          (Icons.flag_outlined, 'Report post'),
          (Icons.visibility_off_outlined, 'Not interested'),
        ],
      ),
    );
  }
}

// ── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool live;
  final VoidCallback? onTap;
  const _Avatar({required this.name, this.photoUrl, this.live = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
              border: live ? Border.all(color: AppColors.red, width: 2) : null,
              image: photoUrl != null ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover) : null,
            ),
            child: photoUrl == null
                ? Center(
                    child: Text(name.isNotEmpty ? name[0] : '?',
                        style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  )
                : null,
          ),
          if (live)
            Positioned(
              bottom: -4,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4)),
                  child: Text('LIVE',
                      style: GoogleFonts.inter(fontSize: 7.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IdentityLine extends StatelessWidget {
  final String name;
  final String username;
  final bool verified;
  final String time;
  const _IdentityLine({required this.name, required this.username, required this.verified, required this.time});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(name, overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        if (verified) ...[
          const SizedBox(width: 4),
          const VerifiedBadge(size: 15),
        ],
        const SizedBox(width: 5),
        Flexible(
          child: Text('@$username · $time', overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textMuted)),
        ),
      ],
    );
  }
}

class _SubscribeControl extends StatelessWidget {
  final bool subscribed;
  final bool notify;
  final VoidCallback onSubscribe;
  final VoidCallback onToggleNotify;
  const _SubscribeControl({required this.subscribed, required this.notify, required this.onSubscribe, required this.onToggleNotify});

  @override
  Widget build(BuildContext context) {
    if (!subscribed) {
      return GestureDetector(
        onTap: onSubscribe,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: AppColors.textPrimary, borderRadius: BorderRadius.circular(20)),
          child: Text('Subscribe', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      );
    }
    return GestureDetector(
      onTap: onToggleNotify,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: notify ? AppColors.primary : AppColors.border),
          color: notify ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
        ),
        child: Icon(
          notify ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          size: 18,
          color: notify ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _TradeChip extends StatelessWidget {
  final String pair;
  final PostType type;
  const _TradeChip({required this.pair, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.candlestick_chart_rounded, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Text(pair, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          Text(type == PostType.trade ? 'Trade' : 'Analysis', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final int? count;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _ActionIcon({required this.icon, this.count, this.active = false, this.activeColor = AppColors.textMuted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : AppColors.textMuted;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Text(_fmt(count!), style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';
}

// ── Generic action sheet ──────────────────────────────────────────────────────

class _SimpleSheet extends StatelessWidget {
  final String title;
  final List<(IconData, String)> rows;
  const _SimpleSheet({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          ...rows.map((r) => InkWell(
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.$2)));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(r.$1, size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 14),
                      Text(r.$2, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
