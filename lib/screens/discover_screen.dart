import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../state/app_state.dart';
import '../widgets/verified_badge.dart';
import 'trader_profile_screen.dart';

class DiscoverTab extends StatefulWidget {
  const DiscoverTab();

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';

  static const _categories = ['All', 'Forex', 'Crypto', 'Indices', 'Stocks'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Trader> get _filtered {
    return mockTraders.where((t) {
      final matchesCat = _category == 'All' || t.category == _category;
      final q = _query.toLowerCase();
      final matchesQuery = q.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.username.toLowerCase().contains(q) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
      return matchesCat && matchesQuery;
    }).toList();
  }

  bool get _isBrowsing => _query.isEmpty && _category == 'All';

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final trending = [...mockTraders]..sort((a, b) => b.copiers.compareTo(a.copiers));
    final live = mockTraders.where((t) => t.isLive).toList();

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
          title: Text('Discover', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
        ),
        // Search
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search traders, pairs, strategies...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        // Categories
        SliverToBoxAdapter(
          child: SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final c = _categories[i];
                final sel = c == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sel ? AppColors.textPrimary : AppColors.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: sel ? AppColors.textPrimary : AppColors.border),
                    ),
                    child: Text(c, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
                  ),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        if (_isBrowsing) ...[
          // Trending horizontal cards
          SliverToBoxAdapter(child: _Header(title: 'Trending creators')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 184,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemCount: trending.take(6).length,
                itemBuilder: (_, i) => _TrendingCard(trader: trending[i]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 22)),
          if (live.isNotEmpty) ...[
            SliverToBoxAdapter(child: _Header(title: 'Live now', dot: true)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemCount: live.length,
                  itemBuilder: (_, i) => _LiveAvatar(trader: live[i]),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 22)),
          ],
          SliverToBoxAdapter(child: _Header(title: 'Top performers')),
          _TraderSliverList(traders: trending),
        ] else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('${filtered.length} result${filtered.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
            ),
          ),
          if (filtered.isEmpty)
            SliverToBoxAdapter(child: _NoResults())
          else
            _TraderSliverList(traders: filtered),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final bool dot;
  const _Header({required this.title, this.dot = false});

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
          Text(title, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final Trader trader;
  const _TrendingCard({required this.trader});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final subscribed = store.isSubscribed(trader.id);
    final positive = trader.returnPercent >= 0;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: trader))),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(trader: trader, size: 44),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: (positive ? AppColors.green : AppColors.red).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(trader.formattedReturn, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: positive ? AppColors.green : AppColors.red)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Flexible(child: Text(trader.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                if (trader.isVerified) ...[
                  const SizedBox(width: 4),
                  const VerifiedBadge(size: 14),
                ],
              ],
            ),
            Text('${trader.formattedCopiers} copiers · ${trader.winRate.toStringAsFixed(0)}% win',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => store.toggleSubscribe(trader.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: subscribed ? Colors.transparent : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(20),
                    border: subscribed ? Border.all(color: AppColors.border) : null,
                  ),
                  child: Text(subscribed ? 'Subscribed' : 'Subscribe',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: subscribed ? AppColors.textSecondary : Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TraderSliverList extends StatelessWidget {
  final List<Trader> traders;
  const _TraderSliverList({required this.traders});

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => Padding(
          padding: EdgeInsets.fromLTRB(24, i == 0 ? 0 : 0, 24, 12),
          child: _TraderRow(trader: traders[i]),
        ),
        childCount: traders.length,
      ),
    );
  }
}

class _TraderRow extends StatelessWidget {
  final Trader trader;
  const _TraderRow({required this.trader});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final subscribed = store.isSubscribed(trader.id);
    final positive = trader.returnPercent >= 0;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: trader))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            Row(
              children: [
                _Avatar(trader: trader, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(trader.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                          if (trader.isVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedBadge(size: 14),
                          ],
                        ],
                      ),
                      Text('@${trader.username} · ${trader.category}', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => store.toggleSubscribe(trader.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: subscribed ? Colors.transparent : AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(20),
                      border: subscribed ? Border.all(color: AppColors.border) : null,
                    ),
                    child: Text(subscribed ? 'Subscribed' : 'Subscribe',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: subscribed ? AppColors.textSecondary : Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _MiniStat(label: '${trader.returnDays}D return', value: trader.formattedReturn, color: positive ? AppColors.green : AppColors.red),
                _MiniStat(label: 'Win rate', value: '${trader.winRate.toStringAsFixed(0)}%'),
                _MiniStat(label: 'Copiers', value: trader.formattedCopiers),
                _MiniStat(label: 'Risk', value: trader.riskLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _MiniStat({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary)),
          const SizedBox(height: 1),
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _LiveAvatar extends StatelessWidget {
  final Trader trader;
  const _LiveAvatar({required this.trader});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: trader))),
      child: Column(
        children: [
          Stack(
            children: [
              _Avatar(trader: trader, size: 64, ring: true),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4)),
                  child: Text('LIVE', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(width: 68, child: Text(trader.name.split(' ').first, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Trader trader;
  final double size;
  final bool ring;
  const _Avatar({required this.trader, required this.size, this.ring = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.1),
        border: ring ? Border.all(color: AppColors.red, width: 2.5) : null,
      ),
      child: Center(child: Text(trader.name[0], style: GoogleFonts.inter(fontSize: size * 0.4, fontWeight: FontWeight.w700, color: AppColors.primary))),
    );
  }
}

class _NoResults extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 44, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 14),
          Text('No traders found', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Try a different search or category.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
