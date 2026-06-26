import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/trade.dart';
import '../widgets/verified_badge.dart';
import '../widgets/trade_card.dart';

class CopyTradingScreen extends StatefulWidget {
  final Trader trader;
  const CopyTradingScreen({super.key, required this.trader});

  @override
  State<CopyTradingScreen> createState() => _CopyTradingScreenState();
}

class _CopyTradingScreenState extends State<CopyTradingScreen> {
  double _copyAmount = 500;
  double _riskMultiplier = 1.0;
  bool _autoCopy = true;
  bool _copyActive = false;

  @override
  Widget build(BuildContext context) {
    final trader = widget.trader;
    final openTrades = mockTrades.where((t) => t.traderId == trader.id && t.status == TradeStatus.open).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Copy Trading', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TraderSummaryCard(trader: trader),
            const SizedBox(height: 24),
            Text('Copy Settings', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Auto-copy new trades', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                      const Spacer(),
                      Switch(
                        value: _autoCopy,
                        onChanged: (v) => setState(() => _autoCopy = v),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  Text('Automatically copy every new trade opened by this trader', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Copy Amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Amount allocated to copy this trader', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '\$${_copyAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Slider(
                    value: _copyAmount,
                    min: 100,
                    max: 10000,
                    divisions: 99,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: (v) => setState(() => _copyAmount = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$100', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      Text('\$10,000', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Risk Multiplier', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('Scale position sizes relative to trader', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        '${_riskMultiplier.toStringAsFixed(1)}x',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  Slider(
                    value: _riskMultiplier,
                    min: 0.1,
                    max: 3.0,
                    divisions: 29,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.border,
                    onChanged: (v) => setState(() => _riskMultiplier = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0.1x', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      Text('3.0x', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
            if (openTrades.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Current Open Trades', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ...openTrades.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TradeCard(trade: t, showActions: true),
              )),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => setState(() => _copyActive = !_copyActive),
              style: ElevatedButton.styleFrom(
                backgroundColor: _copyActive ? AppColors.surface : AppColors.primary,
                foregroundColor: _copyActive ? AppColors.textPrimary : Colors.white,
                side: _copyActive ? const BorderSide(color: AppColors.border) : null,
              ),
              child: Text(
                _copyActive ? 'Stop Copying' : 'Start Copying  ✶',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            if (!_copyActive)
              Center(
                child: Text(
                  'You will copy every verified trade from ${trader.name}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TraderSummaryCard extends StatelessWidget {
  final Trader trader;
  const _TraderSummaryCard({required this.trader});

  @override
  Widget build(BuildContext context) {
    final isPositive = trader.returnPercent >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: Center(
              child: Text(trader.name[0], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(trader.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trader.formattedReturn,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: isPositive ? AppColors.green : AppColors.red),
              ),
              Text('30D return', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
