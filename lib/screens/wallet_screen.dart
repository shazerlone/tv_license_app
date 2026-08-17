import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import '../config.dart';
import '../models/copy_models.dart';
import '../state/app_state.dart';
import '../services/backend_api.dart';
import 'payout_methods_screen.dart';
import 'kyc_screen.dart';
import 'deposit_flow_screen.dart';
import 'withdraw_screen.dart';

/// Wallet home — compact, exchange-grade: balance, margin, deposit / withdraw,
/// and a grouped transaction timeline. Rebuilt per APP_WALLET_GUIDE.md §2.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  String _currency = 'USD';
  PortfolioSummary? _summary;
  List<Map<String, dynamic>> _txns = const [];
  bool _loading = true;
  bool _depositsReady = false; // from GET /health deposits.gate == "ready"

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
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final w = await BackendApi.wallet();
      PortfolioSummary? summary;
      try {
        summary = await BackendApi.portfolioSummary();
      } catch (_) {}
      // Readiness signal: only enable the deposit funnel when the backend gate
      // is "ready" (real address provider live), per the deposit spec.
      bool ready = false;
      try {
        final h = await BackendApi.health();
        final dep = (h['deposits'] as Map?)?.cast<String, dynamic>();
        ready = (dep?['gate'] ?? '').toString() == 'ready';
      } catch (_) {}
      List<Map<String, dynamic>> l;
      try {
        l = await BackendApi.walletTransactions();
      } catch (_) {
        l = await BackendApi.walletLedger();
      }
      if (!mounted) return;
      setState(() {
        _balance = (w['balance'] as num?)?.toDouble() ?? 0;
        _currency = (w['currency'] ?? 'USD').toString();
        _summary = summary;
        _txns = l;
        _depositsReady = ready;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _money(double v) {
    final neg = v < 0;
    final s = v.abs().toStringAsFixed(2);
    final parts = s.split('.');
    final buf = StringBuffer();
    for (var i = 0; i < parts[0].length; i++) {
      if (i > 0 && (parts[0].length - i) % 3 == 0) buf.write(',');
      buf.write(parts[0][i]);
    }
    return '${neg ? '-' : ''}\$${buf.toString()}.${parts[1]}';
  }

  Future<void> _afterFlow() async {
    await _load();
    if (mounted) {
      final store = AppStateScope.of(context);
      store.loadWallet();
      store.loadCopyEngine();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Wallet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: _loading
          ? const SkeletonList()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _balanceCard(),
                  const SizedBox(height: 12),
                  _actions(),
                  const SizedBox(height: 18),
                  _quickLinks(),
                  const SizedBox(height: 22),
                  Text('Transactions', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  if (_txns.isEmpty) _empty() else ..._grouped(),
                ],
              ),
            ),
    );
  }

  Widget _balanceCard() {
    final s = _summary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF111C33)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [BoxShadow(color: const Color(0xFF1E3A8A).withOpacity(0.28), blurRadius: 22, offset: const Offset(0, 10), spreadRadius: -10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available balance', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withOpacity(0.62))),
          const SizedBox(height: 4),
          Text(_money(_balance), style: GoogleFonts.inter(fontSize: 27, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6)),
          if (s != null) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 10),
            Row(
              children: [
                _mini('Free margin', _money(s.freeMargin)),
                _miniDiv(),
                _mini('Used margin', _money(s.usedMargin)),
                _miniDiv(),
                _mini('Equity', _money(s.equity)),
              ],
            ),
            if (s.openPnl != 0) ...[
              const SizedBox(height: 8),
              Row(children: [
                Text('Open P/L  ', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white.withOpacity(0.55))),
                Text('${s.openPnl >= 0 ? '+' : ''}${_money(s.openPnl)}',
                    style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700, color: s.openPnl >= 0 ? const Color(0xFF4ADE80) : const Color(0xFFF87171))),
              ]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withOpacity(0.55))),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.robotoMono(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      );

  Widget _miniDiv() => Container(width: 1, height: 26, color: Colors.white.withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 10));

  Widget _actions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _depositsReady
                  ? () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const DepositFlowScreen()));
                      _afterFlow();
                    }
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Deposits are launching soon — check back shortly.')),
                      ),
              style: _depositsReady ? null : ElevatedButton.styleFrom(backgroundColor: AppColors.slate),
              icon: Icon(_depositsReady ? Icons.arrow_downward_rounded : Icons.lock_clock_outlined, size: 18),
              label: Text(_depositsReady ? 'Deposit' : 'Deposit soon', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => WithdrawScreen(balance: _balance)));
                _afterFlow();
              },
              icon: Icon(Icons.arrow_upward_rounded, size: 18, color: AppColors.primary),
              label: Text('Withdraw', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickLinks() {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          _linkRow(Icons.history_rounded, 'Deposit history', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepositHistoryScreen()))),
          Divider(height: 1, color: AppColors.border),
          _linkRow(Icons.account_balance_wallet_outlined, 'Payout methods', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutMethodsScreen()))),
          Divider(height: 1, color: AppColors.border),
          _linkRow(Icons.verified_user_outlined, 'Identity verification', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen())), last: true),
        ],
      ),
    );
  }

  Widget _linkRow(IconData icon, String label, VoidCallback onTap, {bool last = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(top: last ? Radius.zero : const Radius.circular(14), bottom: last ? const Radius.circular(14) : Radius.zero),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.textSecondary),
            const SizedBox(width: 13),
            Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            Icon(Icons.chevron_right_rounded, size: 19, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(children: [
        Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted.withOpacity(0.5)),
        const SizedBox(height: 12),
        Text('No transactions yet', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Deposit to start copying traders.', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
      ]),
    );
  }

  /// Group transactions by calendar day with a light header, exchange-style.
  List<Widget> _grouped() {
    final out = <Widget>[];
    String? lastDay;
    for (final e in _txns) {
      final when = (e['createdAt'] ?? '').toString();
      final day = _dayLabel(when);
      if (day != lastDay) {
        out.add(Padding(
          padding: EdgeInsets.only(top: lastDay == null ? 0 : 14, bottom: 6, left: 2),
          child: Text(day, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
        ));
        lastDay = day;
      }
      out.add(_txnRow(e));
    }
    return out;
  }

  String _dayLabel(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Earlier';
    final now = DateTime.now();
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}${dt.year == now.year ? '' : ', ${dt.year}'}';
  }

  Widget _txnRow(Map<String, dynamic> e) {
    final amount = (e['amount'] as num?)?.toDouble() ?? 0;
    final type = (e['type'] ?? e['kind'] ?? '').toString();
    final status = (e['status'] ?? 'completed').toString();
    final title = (e['title'] ?? '').toString();
    final when = (e['createdAt'] ?? '').toString();
    final positive = amount >= 0;
    final pending = status == 'pending';
    final rejected = status == 'rejected' || status == 'failed';
    final meta = _meta(type);
    final amountColor = rejected ? AppColors.textMuted : (positive ? AppColors.green : AppColors.red);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: meta.$2.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(meta.$1, size: 17, color: meta.$2),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.isNotEmpty ? title : _label(type, amount), style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Row(children: [
                  Text(_time(when), style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted)),
                  if (pending) ...[
                    const SizedBox(width: 6),
                    _tag('Pending', AppColors.primary),
                  ] else if (rejected) ...[
                    const SizedBox(width: 6),
                    _tag(status == 'failed' ? 'Failed' : 'Rejected', AppColors.red),
                  ],
                ]),
              ],
            ),
          ),
          Text('${positive ? '+' : ''}${_money(amount)}',
              style: GoogleFonts.robotoMono(fontSize: 13.5, fontWeight: FontWeight.w700, color: amountColor, decoration: rejected ? TextDecoration.lineThrough : null)),
        ],
      ),
    );
  }

  Widget _tag(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: c)),
      );

  String _time(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour < 12 ? 'AM' : 'PM'}';
  }

  /// (icon, color) per transaction type.
  (IconData, Color) _meta(String type) {
    switch (type) {
      case 'deposit':
        return (Icons.arrow_downward_rounded, AppColors.green);
      case 'withdrawal':
      case 'withdrawal_hold':
      case 'payout':
        return (Icons.arrow_upward_rounded, AppColors.red);
      case 'withdrawal_refund':
      case 'copy_return':
        return (Icons.undo_rounded, AppColors.primary);
      case 'commission':
      case 'commission_earned':
      case 'referral_commission':
        return (Icons.stars_rounded, AppColors.green);
      case 'copy_allocate':
        return (Icons.content_copy_rounded, AppColors.primary);
      case 'trade_pnl':
      case 'copy_pnl':
      case 'trade':
        return (Icons.show_chart_rounded, AppColors.primary);
      case 'platform_fee':
      case 'fee':
        return (Icons.receipt_rounded, AppColors.slate);
      default:
        return (Icons.swap_horiz_rounded, AppColors.slate);
    }
  }

  String _label(String type, double amount) {
    switch (type) {
      case 'deposit':
        return 'Deposit';
      case 'withdrawal':
      case 'withdrawal_hold':
      case 'payout':
        return 'Withdrawal';
      case 'withdrawal_refund':
        return 'Withdrawal refund';
      case 'commission':
      case 'commission_earned':
        return 'Commission earned';
      case 'referral_commission':
        return 'Referral earnings';
      case 'copy_allocate':
        return 'Copy opened';
      case 'copy_return':
        return 'Copy closed';
      case 'trade_pnl':
      case 'copy_pnl':
        return 'Trade P&L';
      case 'platform_fee':
        return 'Platform fee';
      case 'adjustment':
        return 'Adjustment';
      case '':
        return amount >= 0 ? 'Deposit' : 'Withdrawal';
      default:
        return type.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
  }
}
