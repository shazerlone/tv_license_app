import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';
import 'payout_methods_screen.dart';
import 'kyc_screen.dart';

/// Wallet: balance, transaction ledger, and add-funds (milestone 6).
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  double _leverage = 1;
  String _currency = 'USD';
  List<Map<String, dynamic>> _ledger = const [];
  bool _loading = true;

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
      // Unified transactions (deposits, trades, fees, commissions, withdrawals).
      List<Map<String, dynamic>> l;
      try {
        l = await BackendApi.walletTransactions();
      } catch (_) {
        l = await BackendApi.walletLedger();
      }
      if (!mounted) return;
      setState(() {
        _balance = (w['balance'] as num?)?.toDouble() ?? 0;
        _leverage = (w['leverage'] as num?)?.toDouble() ?? 1;
        _currency = (w['currency'] ?? 'USD').toString();
        _ledger = l;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Wallet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF0B1120)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Wallet balance', style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.65))),
                        const SizedBox(height: 8),
                        Text(_money(_balance), style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(_currency, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withOpacity(0.55))),
                            if (_leverage > 1) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                                child: Text('${_leverage.toStringAsFixed(0)}x leverage', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.85))),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openDeposit(),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add funds'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _walletRow(Icons.account_balance_rounded, 'Payout methods', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutMethodsScreen()))),
                        const Divider(height: 1),
                        _walletRow(Icons.verified_user_outlined, 'Identity verification', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen())), last: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text('Transactions', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 10),
                  if (_ledger.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Column(children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 42, color: AppColors.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        Text('No transactions yet', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('Add funds to start copying traders.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      ]),
                    )
                  else
                    ..._ledger.map(_ledgerRow),
                ],
              ),
            ),
    );
  }

  Widget _walletRow(IconData icon, String label, VoidCallback onTap, {bool last = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _ledgerRow(Map<String, dynamic> e) {
    final amount = (e['amount'] as num?)?.toDouble() ?? 0;
    final type = (e['type'] ?? 'transaction').toString();
    final note = (e['note'] ?? '').toString();
    final when = (e['createdAt'] ?? '').toString();
    final positive = amount >= 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: (positive ? AppColors.green : AppColors.red).withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(positive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18, color: positive ? AppColors.green : AppColors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_label(type), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (note.isNotEmpty || when.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(note.isNotEmpty ? note : (when.length > 10 ? when.substring(0, 10) : when),
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          Text('${positive ? '+' : ''}${_money(amount)}', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: positive ? AppColors.green : AppColors.red)),
        ],
      ),
    );
  }

  String _label(String type) {
    switch (type) {
      case 'deposit':
        return 'Deposit';
      case 'payout':
        return 'Payout';
      case 'commission':
        return 'Commission';
      case 'copy_pnl':
        return 'Copy P&L';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  Future<void> _openDeposit() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DepositSheet(),
    );
    if (done == true) _load();
  }
}

class _DepositSheet extends StatefulWidget {
  const _DepositSheet();
  @override
  State<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<_DepositSheet> {
  final _amount = TextEditingController();
  List<Map<String, dynamic>> _methods = const [];
  String? _method;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadMethods();
  }

  Future<void> _loadMethods() async {
    try {
      final m = await BackendApi.depositMethods();
      if (!mounted) return;
      setState(() {
        _methods = m.where((x) => x['comingSoon'] != true).toList();
        _method = _methods.isNotEmpty ? _methods.first['id'].toString() : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _submitting = true);
    try {
      await BackendApi.createDeposit(amount: amount, method: _method);
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deposit initiated')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text('Add funds', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: '0.00', prefixText: '\$ '),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()))
            else if (_methods.isNotEmpty) ...[
              Text('Method', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _methods.map((m) {
                  final id = m['id'].toString();
                  final active = _method == id;
                  return GestureDetector(
                    onTap: () => setState(() => _method = id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: active ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(m['label'].toString(), style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textPrimary)),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
