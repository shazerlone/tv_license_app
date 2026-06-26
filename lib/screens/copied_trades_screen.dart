import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum CopyAction { copied, opposed }

/// A trade the user took *through millimore* (copied or opposed a creator).
/// Only these are shareable — external/manual trades never appear here.
class CopiedTrade {
  final String pair;
  final CopyAction action;
  final bool isBuy;
  final String fromTrader;
  final double pnlPercent;
  final bool open;

  const CopiedTrade({
    required this.pair,
    required this.action,
    required this.isBuy,
    required this.fromTrader,
    required this.pnlPercent,
    required this.open,
  });
}

final _copiedTrades = <CopiedTrade>[
  CopiedTrade(pair: 'EUR/USD', action: CopyAction.copied, isBuy: true, fromTrader: 'Marcus Sterling', pnlPercent: 0.47, open: true),
  CopiedTrade(pair: 'XAU/USD', action: CopyAction.copied, isBuy: false, fromTrader: 'Marcus Sterling', pnlPercent: 1.03, open: false),
  CopiedTrade(pair: 'BTC/USD', action: CopyAction.opposed, isBuy: false, fromTrader: 'Jade Capital', pnlPercent: -0.62, open: true),
];

class CopiedTradesScreen extends StatelessWidget {
  const CopiedTradesScreen({super.key});

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
          title: Text('Your trades', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: Text('Trades you copied or opposed on millimore. Only these can be shared.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.4)),
          ),
        ),
        if (_copiedTrades.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: _CopiedTradeCard(trade: _copiedTrades[i]),
              ),
              childCount: _copiedTrades.length,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _CopiedTradeCard extends StatelessWidget {
  final CopiedTrade trade;
  const _CopiedTradeCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    final positive = trade.pnlPercent >= 0;
    final actionColor = trade.action == CopyAction.copied ? AppColors.primary : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(trade.pair, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              _Tag(text: trade.isBuy ? 'BUY' : 'SELL', color: trade.isBuy ? AppColors.green : AppColors.red),
              const SizedBox(width: 6),
              _Tag(text: trade.action == CopyAction.copied ? 'COPIED' : 'OPPOSED', color: actionColor),
              const Spacer(),
              Text('${positive ? '+' : ''}${trade.pnlPercent.toStringAsFixed(2)}%',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: positive ? AppColors.green : AppColors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Text('From ${trade.fromTrader} · ${trade.open ? 'Open' : 'Closed'}',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _share(context, trade),
                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _share(BuildContext context, CopiedTrade t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(trade: t),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  final CopiedTrade trade;
  const _ShareSheet({required this.trade});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Text('Share this trade', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Post your verified ${trade.pair} result to your followers.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          _ShareOption(icon: Icons.dynamic_feed_rounded, label: 'Post to my feed'),
          _ShareOption(icon: Icons.link_rounded, label: 'Copy share link'),
          _ShareOption(icon: Icons.download_rounded, label: 'Save as image'),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shared to your feed')),
                );
              },
              child: const Text('Post'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ShareOption({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
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
            Text('No trades yet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Copy or oppose a trader to start building your shareable track record.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
