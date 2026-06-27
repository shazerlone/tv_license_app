import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/post.dart';
import '../state/app_state.dart';
import '../widgets/verified_badge.dart';
import '../widgets/comments_sheet.dart';
import 'trader_profile_screen.dart';
import 'copy_trading_screen.dart';
import 'live_stream_screen.dart';

enum ReelKind { live, trade, education }

class ReelItem {
  final Trader trader;
  final ReelKind kind;
  final Post post;
  final String? title;
  final List<String> points;
  final int viewers;
  const ReelItem({required this.trader, required this.kind, required this.post, this.title, this.points = const [], this.viewers = 0});
}

/// Discover = an addictive full-screen reels feed mixing live streams,
/// trade results and educational lessons creators upload.
class DiscoverTab extends StatefulWidget {
  const DiscoverTab();

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final _controller = PageController();
  late final List<ReelItem> _reels;

  @override
  void initState() {
    super.initState();
    _reels = _buildReels();
  }

  Trader _byId(String id) => mockTraders.firstWhere((t) => t.id == id, orElse: () => mockTraders.first);

  Post _synthPost(Trader t, String kind, String content) => Post(
        id: 'reel_${kind}_${t.id}',
        trader: t,
        type: PostType.analysis,
        content: content,
        pair: t.tags.firstWhere((x) => x.contains('/'), orElse: () => ''),
        likes: (t.copiers / 3).round() + content.length,
        comments: (t.copiers / 14).round(),
        createdAt: DateTime.now().subtract(Duration(hours: t.id.hashCode % 18 + 1)),
      );

  List<ReelItem> _buildReels() {
    final rng = math.Random(11);

    final live = mockTraders.where((t) => t.isLive).map((t) {
      return ReelItem(
        trader: t,
        kind: ReelKind.live,
        viewers: 400 + rng.nextInt(12000),
        post: _synthPost(t, 'live', 'I\'m live now breaking down ${t.tags.isNotEmpty ? t.tags.first : "the markets"} — come trade with me.'),
      );
    }).toList();

    final lessons = <ReelItem>[
      ReelItem(trader: _byId('1'), kind: ReelKind.education, title: 'Risk management 101',
        points: ['Never risk more than 1–2% per trade', 'Set your stop before you enter', 'Size the position to the stop, not the target'],
        post: _synthPost(_byId('1'), 'edu', 'Risk management 101 — the habit that keeps you in the game.')),
      ReelItem(trader: _byId('6'), kind: ReelKind.education, title: 'Reading market structure',
        points: ['Higher highs + higher lows = uptrend', 'Wait for the break, then the retest', 'Trade with structure, not against it'],
        post: _synthPost(_byId('6'), 'edu', 'How I read market structure before every trade.')),
      ReelItem(trader: _byId('9'), kind: ReelKind.education, title: '3 mistakes new traders make',
        points: ['Overtrading out of boredom', 'Moving stops to dodge a loss', 'Risking big to recover fast'],
        post: _synthPost(_byId('9'), 'edu', 'Avoid these 3 and you\'re ahead of 90% of beginners.')),
      ReelItem(trader: _byId('10'), kind: ReelKind.education, title: 'Backtest before you go live',
        points: ['Test 100+ trades minimum', 'Track win rate AND risk-reward', 'Forward test on demo first'],
        post: _synthPost(_byId('10'), 'edu', 'Why I never trade a strategy I haven\'t backtested.')),
    ];

    final trades = mockTraders.map((t) {
      return ReelItem(
        trader: t,
        kind: ReelKind.trade,
        post: _synthPost(t, 'trade', t.bio ?? 'Verified results on millimore.'),
      );
    }).toList();

    // Round-robin interleave so the feed always feels varied & alive.
    final out = <ReelItem>[];
    int li = 0, ei = 0, ti = 0;
    while (li < live.length || ei < lessons.length || ti < trades.length) {
      if (li < live.length) out.add(live[li++]);
      if (ei < lessons.length) out.add(lessons[ei++]);
      if (ti < trades.length) out.add(trades[ti++]);
      if (ti < trades.length) out.add(trades[ti++]);
    }
    return out;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          itemCount: _reels.length,
          itemBuilder: (_, i) => _ReelPage(reel: _reels[i]),
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Text('Discover', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _openSearch(context),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openSearch(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => const _SearchSheet());
  }
}

// ── Reel page ─────────────────────────────────────────────────────────────────

class _ReelPage extends StatefulWidget {
  final ReelItem reel;
  const _ReelPage({required this.reel});

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reel = widget.reel;
    final trader = reel.trader;
    final post = reel.post;
    final store = AppStateScope.of(context);
    final positive = trader.returnPercent >= 0;
    final subscribed = store.isSubscribed(trader.id);
    final edu = reel.kind == ReelKind.education;
    final accent = edu ? AppColors.primary : (positive ? AppColors.green : AppColors.red);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: trader))),
      child: Container(
        color: const Color(0xFF0B1120),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => CustomPaint(painter: _ReelChartPainter(progress: _anim.value, accent: accent, dense: !edu)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.78)],
                  stops: const [0, 0.42, 1],
                ),
              ),
            ),

            // Centerpiece varies by kind
            Align(
              alignment: const Alignment(-0.85, -0.12),
              child: _Centerpiece(reel: reel, positive: positive),
            ),

            // Right rail
            Positioned(
              right: 12, bottom: 160,
              child: _ActionRail(
                reel: reel, store: store,
                onComment: () => CommentsSheet.open(context, post),
                onShare: () => _share(context, trader),
                onProfile: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: trader))),
              ),
            ),

            // Bottom info + actions
            Positioned(
              left: 20, right: 84, bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(trader.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))),
                      if (trader.isVerified) ...[const SizedBox(width: 5), const VerifiedBadge(size: 16)],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white.withOpacity(0.85), height: 1.45)),
                  const SizedBox(height: 14),
                  _BottomActions(reel: reel, subscribed: subscribed,
                    onSubscribe: () => store.toggleSubscribe(trader.id),
                    onCopy: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CopyTradingScreen(trader: trader))),
                    onWatch: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveStreamScreen(trader: trader))),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 6, left: 0, right: 0,
              child: Center(child: Text('swipe up for next', style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.4)))),
            ),
          ],
        ),
      ),
    );
  }

  void _share(BuildContext context, Trader t) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text('Share', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            for (final r in const [(Icons.link_rounded, 'Copy link'), (Icons.send_rounded, 'Send in DM'), (Icons.ios_share_rounded, 'Share to...')])
              InkWell(
                onTap: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.$2))); },
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(r.$1, size: 20, color: AppColors.textSecondary), const SizedBox(width: 14), Text(r.$2, style: GoogleFonts.inter(fontSize: 14.5, color: AppColors.textPrimary))])),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Centerpiece per kind ──────────────────────────────────────────────────────

class _Centerpiece extends StatelessWidget {
  final ReelItem reel;
  final bool positive;
  const _Centerpiece({required this.reel, required this.positive});

  @override
  Widget build(BuildContext context) {
    switch (reel.kind) {
      case ReelKind.live:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.podcasts_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 5),
                Text('LIVE NOW', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
              ]),
            ),
            const SizedBox(height: 12),
            Text('Trading\nlive', style: GoogleFonts.inter(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0, letterSpacing: -1.5)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.remove_red_eye_rounded, size: 15, color: Colors.white70),
              const SizedBox(width: 5),
              Text('${_fmt(reel.viewers)} watching', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
            ]),
          ],
        );
      case ReelKind.education:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.school_rounded, size: 13, color: Colors.white),
                const SizedBox(width: 5),
                Text('LESSON', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
              ]),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: 280,
              child: Text(reel.title ?? '', style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, letterSpacing: -0.8)),
            ),
            const SizedBox(height: 16),
            ...reel.points.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: 280,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 22, height: 22, alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                    child: Text('${e.key + 1}', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value, style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white.withOpacity(0.9), height: 1.35))),
                ]),
              ),
            )),
          ],
        );
      case ReelKind.trade:
        final t = reel.trader;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
              child: Text('${t.returnDays}-DAY RETURN', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.85), letterSpacing: 1)),
            ),
            const SizedBox(height: 10),
            Text(t.formattedReturn, style: GoogleFonts.inter(fontSize: 52, fontWeight: FontWeight.w800, color: positive ? AppColors.green : AppColors.red, letterSpacing: -2, height: 1)),
            const SizedBox(height: 8),
            Row(children: [
              _GlassPill(text: '${t.winRate.toStringAsFixed(0)}% win'),
              const SizedBox(width: 8),
              _GlassPill(text: '${t.formattedCopiers} copiers'),
              const SizedBox(width: 8),
              _GlassPill(text: '${t.riskLabel} risk'),
            ]),
          ],
        );
    }
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';
}

class _BottomActions extends StatelessWidget {
  final ReelItem reel;
  final bool subscribed;
  final VoidCallback onSubscribe;
  final VoidCallback onCopy;
  final VoidCallback onWatch;
  const _BottomActions({required this.reel, required this.subscribed, required this.onSubscribe, required this.onCopy, required this.onWatch});

  @override
  Widget build(BuildContext context) {
    Widget subBtn = Expanded(
      child: GestureDetector(
        onTap: onSubscribe,
        child: Container(
          height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(color: subscribed ? Colors.white.withOpacity(0.15) : Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Text(subscribed ? 'Subscribed' : 'Subscribe', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: subscribed ? Colors.white : const Color(0xFF0B1120))),
        ),
      ),
    );

    Widget secondary;
    switch (reel.kind) {
      case ReelKind.live:
        secondary = _filled(label: 'Watch live', color: AppColors.red, onTap: onWatch, icon: Icons.podcasts_rounded);
        break;
      case ReelKind.education:
        secondary = _filled(label: 'View profile', color: AppColors.primary, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: reel.trader))), icon: Icons.menu_book_rounded);
        break;
      case ReelKind.trade:
        secondary = _filled(label: 'Copy', color: AppColors.primary, onTap: onCopy, icon: Icons.copy_all_rounded);
        break;
    }

    return Row(children: [subBtn, const SizedBox(width: 10), Expanded(child: secondary)]);
  }

  Widget _filled({required String label, required Color color, required VoidCallback onTap, required IconData icon}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44, alignment: Alignment.center,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String text;
  const _GlassPill({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white)),
    );
  }
}

class _ActionRail extends StatelessWidget {
  final ReelItem reel;
  final AppState store;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onProfile;
  const _ActionRail({required this.reel, required this.store, required this.onComment, required this.onShare, required this.onProfile});

  @override
  Widget build(BuildContext context) {
    final post = reel.post;
    final liked = store.isLiked(post);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onProfile,
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15), border: Border.all(color: Colors.white, width: 2)),
            child: Center(child: Text(reel.trader.name[0], style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
          ),
        ),
        const SizedBox(height: 20),
        _RailButton(icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: _fmt(store.likeCount(post)), color: liked ? AppColors.red : Colors.white, onTap: () => store.toggleLike(post)),
        const SizedBox(height: 18),
        _RailButton(icon: Icons.mode_comment_outlined, label: _fmt(store.commentCount(post)), color: Colors.white, onTap: onComment),
        const SizedBox(height: 18),
        _RailButton(icon: Icons.ios_share_rounded, label: 'Share', color: Colors.white, onTap: onShare),
        const SizedBox(height: 18),
        _RailButton(icon: store.isSaved(post.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, label: 'Save', color: store.isSaved(post.id) ? AppColors.primary : Colors.white, onTap: () => store.toggleSave(post.id)),
      ],
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _RailButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Icon(icon, size: 30, color: color),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }
}

// ── Background chart ──────────────────────────────────────────────────────────

class _ReelChartPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final bool dense;
  _ReelChartPainter({required this.progress, required this.accent, required this.dense});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 1;
    for (int i = 1; i < 10; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final rng = math.Random(7);
    final n = dense ? 18 : 12;
    final w = size.width / n;
    double price = size.height * 0.55;
    for (int i = 0; i < n; i++) {
      final x = w * i + w / 2;
      final open = price;
      price = (price + (rng.nextDouble() - 0.5) * size.height * 0.06).clamp(size.height * 0.25, size.height * 0.75);
      final close = price;
      final bull = close <= open;
      final c = bull ? AppColors.green : AppColors.red;
      final bodyTop = math.min(open, close);
      final bodyH = (open - close).abs().clamp(2.0, double.infinity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - w * 0.28, bodyTop, w * 0.56, bodyH), const Radius.circular(2)),
        Paint()..color = c.withOpacity(dense ? 0.32 : 0.16),
      );
    }

    final pts = <Offset>[];
    double v = size.height * 0.6;
    for (int i = 0; i <= n; i++) {
      v += (rng.nextDouble() - 0.5) * size.height * 0.05;
      v = v.clamp(size.height * 0.2, size.height * 0.8);
      pts.add(Offset(size.width * i / n, v));
    }
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      path.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * (0.2 + 0.8 * progress), size.height));
    canvas.drawPath(path, Paint()..color = accent.withOpacity(0.6)..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReelChartPainter old) => old.progress != progress;
}

// ── Search sheet ──────────────────────────────────────────────────────────────

class _SearchSheet extends StatefulWidget {
  const _SearchSheet();

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final results = mockTraders.where((t) {
      final q = _q.toLowerCase();
      return q.isEmpty || t.name.toLowerCase().contains(q) || t.username.toLowerCase().contains(q) || t.tags.any((x) => x.toLowerCase().contains(q));
    }).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5, expand: false,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _q = v),
                  style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search traders, pairs, strategies',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                    filled: true, fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final t = results[i];
                    final positive = t.returnPercent >= 0;
                    return ListTile(
                      onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: t))); },
                      leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(t.name[0], style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary))),
                      title: Row(children: [
                        Flexible(child: Text(t.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                        if (t.isVerified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 13)],
                      ]),
                      subtitle: Text('@${t.username} · ${t.category}', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
                      trailing: Text(t.formattedReturn, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: positive ? AppColors.green : AppColors.red)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
