import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/trade.dart';
import '../theme/app_theme.dart';

class TradeCard extends StatelessWidget {
  final Trade trade;
  final bool showActions;
  const TradeCard({super.key, required this.trade, this.showActions = false});

  @override
  Widget build(BuildContext context) {
    final isProfit = trade.isProfit;
    final pnlColor = isProfit ? AppColors.green : AppColors.red;
    final dirColor = trade.direction == TradeDirection.buy ? AppColors.green : AppColors.red;

    return Container(
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
              Text(
                trade.pair,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              _DirectionChip(label: trade.directionLabel, color: dirColor),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: pnlColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trade.formattedPnl,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: pnlColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatItem(label: 'Entry', value: trade.entryPrice.toStringAsFixed(5)),
              if (trade.stopLoss != null) ...[
                const SizedBox(width: 20),
                _StatItem(label: 'SL', value: trade.stopLoss!.toStringAsFixed(5)),
              ],
              if (trade.takeProfit != null) ...[
                const SizedBox(width: 20),
                _StatItem(label: 'TP', value: trade.takeProfit!.toStringAsFixed(5)),
              ],
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text('Copy Trade', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Text('Oppose', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  final String label;
  final Color color;
  const _DirectionChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
