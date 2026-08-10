import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import '../config.dart';
import '../services/backend_api.dart';
import 'withdraw_screen.dart';

/// Creator earnings & payouts (GET /creator/earnings).
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  double _balance = 0, _pending = 0;
  String _currency = 'USD';
  List<Map<String, dynamic>> _history = const [];
  List<Map<String, dynamic>> _payouts = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (kUseBackend) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final e = await BackendApi.creatorEarnings();
      List<Map<String, dynamic>> payouts = const [];
      try {
        payouts = await BackendApi.creatorPayouts();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _balance = (e['balance'] as num?)?.toDouble() ?? 0;
        _pending = (e['pending'] as num?)?.toDouble() ?? 0;
        _currency = (e['currency'] ?? 'USD').toString();
        _history = ((e['history'] as List?) ?? const [])
            .map((x) => (x as Map).cast<String, dynamic>())
            .toList();
        _payouts = payouts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  Future<void> _requestPayout() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => WithdrawScreen(balance: _balance)));
    if (ok == true) _load();
  }

  Widget _payoutRow(Map<String, dynamic> p) {
    final amount = (p['amount'] as num?)?.toDouble() ?? 0;
    final status = (p['status'] ?? 'pending').toString();
    final when = (p['createdAt'] ?? '').toString();
    final colors = {
      'pending': AppColors.slate,
      'approved': AppColors.primary,
      'paid': AppColors.green,
      'rejected': AppColors.red,
    };
    final c = colors[status] ?? AppColors.slate;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_money(amount), style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(when.length > 10 ? when.substring(0, 10) : when, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(status[0].toUpperCase() + status.substring(1), style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: c)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Earnings & payouts', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: _loading
          ? const AppLoader()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available balance', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.6))),
                        const SizedBox(height: 8),
                        Text(_money(_balance), style: GoogleFonts.inter(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 15, color: Colors.white.withOpacity(0.55)),
                            const SizedBox(width: 6),
                            Text('${_money(_pending)} pending · $_currency', style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withOpacity(0.6))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _balance > 0 ? _requestPayout : null,
                      child: const Text('Request payout'),
                    ),
                  ),
                  if (_payouts.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Payouts', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    ..._payouts.map(_payoutRow),
                  ],
                  const SizedBox(height: 24),
                  Text('Earnings history', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  if (_failed)
                    _empty(Icons.wifi_off_rounded, 'Couldn\'t load earnings', 'Pull to retry.')
                  else if (_history.isEmpty)
                    _empty(Icons.receipt_long_rounded, 'No earnings yet', 'Your revenue from copiers will appear here.')
                  else
                    ..._history.map(_historyRow),
                ],
              ),
            ),
    );
  }

  Widget _historyRow(Map<String, dynamic> h) {
    final amount = (h['amount'] as num?)?.toDouble() ?? 0;
    final label = (h['description'] ?? h['label'] ?? h['type'] ?? 'Earning').toString();
    final when = (h['createdAt'] ?? h['date'] ?? '').toString();
    final positive = amount >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (when.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(when.length > 10 ? when.substring(0, 10) : when, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          Text('${positive ? '+' : ''}${_money(amount)}', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: positive ? AppColors.green : AppColors.red)),
        ],
      ),
    );
  }

  Widget _empty(IconData icon, String title, String sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(icon, size: 42, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(sub, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      );
}
