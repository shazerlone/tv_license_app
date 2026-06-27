import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/copy_models.dart';
import '../state/app_state.dart';
import '../widgets/add_account_sheet.dart';
import 'trader_profile_screen.dart';

/// Full copy-trading dashboard: net P/L, booked profit/loss, who you're copying,
/// and every active / closed position.
class CopiedTradesScreen extends StatelessWidget {
  const CopiedTradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final hasData = store.hasAccount || store.positions.isNotEmpty;

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Row(
                children: [
                  Text('Copy trading', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_card_rounded, color: AppColors.textPrimary),
                    tooltip: 'Add account',
                    onPressed: () => AddAccountSheet.open(context),
                  ),
                ],
              ),
            ),
            if (!hasData)
              Expanded(child: _EmptyState(onAdd: () => AddAccountSheet.open(context)))
            else
              Expanded(
                child: Column(
                  children: [
                    _SummaryCard(store: store),
                    if (store.activeCopies.isNotEmpty) _CopyingStrip(store: store),
                    const SizedBox(height: 4),
                    const TabBar(
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textMuted,
                      indicatorColor: AppColors.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: [Tab(text: 'Active'), Tab(text: 'Closed')],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _PositionsList(positions: store.activePositions, active: true),
                          _PositionsList(positions: store.closedPositions, active: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AppState store;
  const _SummaryCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final net = store.netPnl;
    final positive = net >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net profit / loss', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.6))),
          const SizedBox(height: 6),
          Text('${positive ? '+' : '-'}\$${net.abs().toStringAsFixed(2)}',
              style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: positive ? AppColors.green : AppColors.red, letterSpacing: -1)),
          const SizedBox(height: 16),
          Row(
            children: [
              _Metric(label: 'Open P/L', value: store.openPnl, money: true),
              _Metric(label: 'Booked profit', value: store.bookedProfit, money: true),
              _Metric(label: 'Booked loss', value: store.bookedLoss, money: true),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _CountMetric(label: 'Copying', value: '${store.copyingCount}'),
              _CountMetric(label: 'Active', value: '${store.activePositions.length}'),
              _CountMetric(label: 'Closed', value: '${store.closedPositions.length}'),
              _CountMetric(label: 'Invested', value: '\$${store.totalInvested.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final double value;
  final bool money;
  const _Metric({required this.label, required this.value, this.money = false});

  @override
  Widget build(BuildContext context) {
    final positive = value >= 0;
    final color = value == 0 ? Colors.white : (positive ? AppColors.green : AppColors.red);
    final text = money ? '${positive ? '' : '-'}\$${value.abs().toStringAsFixed(2)}' : value.toString();
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.55))),
        ],
      ),
    );
  }
}

class _CountMetric extends StatelessWidget {
  final String label;
  final String value;
  const _CountMetric({required this.label, required this.value});

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

class _CopyingStrip extends StatelessWidget {
  final AppState store;
  const _CopyingStrip({required this.store});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: store.activeCopies.length,
        itemBuilder: (_, i) {
          final cfg = store.activeCopies[i];
          Trader? t;
          for (final x in mockTraders) {
            if (x.id == cfg.traderId) {
              t = x;
              break;
            }
          }
          final name = t?.name ?? 'Trader';
          return GestureDetector(
            onTap: t == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: t!))),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
                    child: Center(child: Text(name[0], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
                  ),
                  const SizedBox(width: 8),
                  Text(name.split(' ').first, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      store.stopCopy(cfg.traderId);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stopped copying $name')));
                    },
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
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

class _PositionsList extends StatelessWidget {
  final List<CopyPosition> positions;
  final bool active;
  const _PositionsList({required this.positions, required this.active});

  @override
  Widget build(BuildContext context) {
    if (positions.isEmpty) {
      return Center(
        child: Text(active ? 'No active positions' : 'No closed positions',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      itemCount: positions.length,
      itemBuilder: (_, i) => _PositionCard(p: positions[i]),
    );
  }
}

class _PositionCard extends StatelessWidget {
  final CopyPosition p;
  const _PositionCard({required this.p});

  @override
  Widget build(BuildContext context) {
    final profit = p.isProfit;
    final pnlColor = profit ? AppColors.green : AppColors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(p.pair, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              _Tag(text: p.isBuy ? 'BUY' : 'SELL', color: p.isBuy ? AppColors.green : AppColors.red),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${profit ? '+' : '-'}\$${p.pnlAmount.abs().toStringAsFixed(2)}',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: pnlColor)),
                  Text('${profit ? '+' : ''}${p.pnlPercent.toStringAsFixed(2)}%',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: pnlColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Field(label: 'Trader', value: p.traderName.split(' ').first),
              _Field(label: 'Lots', value: p.lots.toStringAsFixed(2)),
              _Field(label: 'Entry', value: p.entryPrice.toStringAsFixed(4)),
              if (p.exitPrice != null) _Field(label: 'Exit', value: p.exitPrice!.toStringAsFixed(4)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(p.status == PositionStatus.active ? Icons.circle : Icons.check_circle, size: 11, color: p.status == PositionStatus.active ? AppColors.green : AppColors.textMuted),
              const SizedBox(width: 5),
              Text(
                p.status == PositionStatus.active ? 'Active · opened ${_ago(p.openedAt)}' : 'Closed · ${_ago(p.closedAt!)}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 1),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_vert_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('Start copy trading', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Connect a broker account, then copy a trader to see all your positions, P/L and booked results here.',
                textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onAdd, child: const Text('Connect trading account')),
          ],
        ),
      ),
    );
  }
}
