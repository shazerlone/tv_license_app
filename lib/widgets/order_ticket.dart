import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/copy_models.dart';
import '../state/app_state.dart';

/// Compact MT-style order ticket: pick pair, Market/Limit tabs, SL/TP,
/// (limit price), lots. Shows the live price. Submits Buy or Sell.
class OrderTicket extends StatefulWidget {
  final String initialSymbol;
  const OrderTicket({super.key, this.initialSymbol = 'XAU/USD'});

  static Future<void> open(BuildContext context, {String symbol = 'XAU/USD'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderTicket(initialSymbol: symbol),
    );
  }

  @override
  State<OrderTicket> createState() => _OrderTicketState();
}

class _OrderTicketState extends State<OrderTicket> {
  late String _symbol = widget.initialSymbol;
  LiveOrderType _type = LiveOrderType.market;
  final _lots = TextEditingController(text: '0.10');
  final _sl = TextEditingController();
  final _tp = TextEditingController();
  final _limit = TextEditingController();

  @override
  void dispose() {
    _lots.dispose();
    _sl.dispose();
    _tp.dispose();
    _limit.dispose();
    super.dispose();
  }

  void _submit(AppState store, bool isBuy) {
    HapticFeedback.mediumImpact();
    final lots = double.tryParse(_lots.text) ?? 0.10;
    store.placeLiveOrder(
      symbol: _symbol,
      isBuy: isBuy,
      orderType: _type,
      lots: lots,
      sl: double.tryParse(_sl.text),
      tp: double.tryParse(_tp.text),
      limitPrice: _type == LiveOrderType.limit ? double.tryParse(_limit.text) : null,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${isBuy ? 'Buy' : 'Sell'} $_symbol placed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context); // rebuilds each price tick
    final price = store.priceOf(_symbol);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('New order', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 14),

            // Pair selector
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: store.symbols.map((s) {
                  final sel = s == _symbol;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _symbol = s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: sel ? AppColors.textPrimary : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? AppColors.textPrimary : AppColors.border),
                        ),
                        child: Text(s, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Live price
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Live price', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withOpacity(0.6))),
                      const SizedBox(height: 2),
                      Text(_fmtPrice(price), style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      Text('MT live', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Market / Limit tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  _tab('Market', _type == LiveOrderType.market, () => setState(() => _type = LiveOrderType.market)),
                  _tab('Limit', _type == LiveOrderType.limit, () => setState(() => _type = LiveOrderType.limit)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_type == LiveOrderType.limit) ...[
              _field('Limit price', _limit, hint: 'Price to execute at'),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(child: _field('Lots', _lots, hint: '0.10')),
                const SizedBox(width: 12),
                Expanded(child: _field('Stop loss', _sl, hint: 'optional')),
                const SizedBox(width: 12),
                Expanded(child: _field('Take profit', _tp, hint: 'optional')),
              ],
            ),
            const SizedBox(height: 20),

            // Buy / Sell
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _submit(store, false),
                    child: Container(
                      height: 52, alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(14)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('SELL', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(_fmtPrice(price), style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _submit(store, true),
                    child: Container(
                      height: 52, alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(14)),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('BUY', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(_fmtPrice(price), style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool sel, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: sel ? AppColors.background : Colors.transparent, borderRadius: BorderRadius.circular(9), border: sel ? Border.all(color: AppColors.border) : null),
          child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: sel ? AppColors.textPrimary : AppColors.textMuted)),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        ),
      ],
    );
  }

  String _fmtPrice(double p) {
    if (p >= 1000) return p.toStringAsFixed(2);
    if (p >= 100) return p.toStringAsFixed(3);
    return p.toStringAsFixed(5);
  }
}
