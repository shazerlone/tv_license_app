import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/pairs.dart';

/// Opens a bottom sheet to choose a trading pair (Metals / Forex / Crypto /
/// Indices) or type a custom symbol. Returns the chosen [TradingPair] or null.
Future<TradingPair?> showPairPicker(BuildContext context) {
  return showModalBottomSheet<TradingPair>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PairPickerSheet(),
  );
}

class _PairPickerSheet extends StatefulWidget {
  const _PairPickerSheet();
  @override
  State<_PairPickerSheet> createState() => _PairPickerSheetState();
}

class _PairPickerSheetState extends State<_PairPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toUpperCase();
    final matches = q.isEmpty
        ? kPairs
        : kPairs.where((p) => p.symbol.toUpperCase().contains(q) || p.name.toUpperCase().contains(q)).toList();
    final canAddCustom = q.isNotEmpty && pairBySymbol(q) == null;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select a pair', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: false,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (v) => setState(() => _query = v),
                    style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search or type a symbol (e.g. XAU/USD)',
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            if (canAddCustom)
              ListTile(
                leading: Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                title: Text('Use "$q"', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary)),
                subtitle: Text('Custom pair', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                onTap: () => Navigator.pop(context, customPair(q)),
              ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  for (final cat in kPairCategories)
                    if (matches.any((p) => p.category == cat)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                        child: Text(cat.toUpperCase(), style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.6)),
                      ),
                      ...matches.where((p) => p.category == cat).map((p) => ListTile(
                            onTap: () => Navigator.pop(context, p),
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Center(child: Text(p.symbol.split('/').first.substring(0, p.symbol.length >= 2 ? 2 : 1),
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary))),
                            ),
                            title: Text(p.symbol, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            subtitle: Text(p.name, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
                          )),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
