import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import '../config.dart';
import '../state/session.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';
import '../services/app_config.dart';
import 'kyc_screen.dart';
import 'payout_methods_screen.dart';

/// Withdraw flow (POST /creator/payouts). Gated on KYC (when required) and a
/// saved payout method; handles the milestone-7 withdrawal error codes.
class WithdrawScreen extends StatefulWidget {
  final double balance;
  const WithdrawScreen({super.key, required this.balance});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

String friendlyWithdrawError(String code, String fallback) {
  switch (code) {
    case 'kyc_required':
      return 'Verify your identity before withdrawing.';
    case 'invalid_payout_method':
      return 'That payout method is invalid — add a new one.';
    case 'below_min_withdrawal':
      return 'Amount is below the minimum withdrawal.';
    case 'above_max_withdrawal':
      return 'Amount is above the maximum withdrawal.';
    case 'daily_limit_exceeded':
      return 'You\'ve reached today\'s withdrawal limit. Try again tomorrow.';
    case 'insufficient_balance':
      return 'Insufficient balance for this withdrawal.';
    case 'withdrawal_method_mismatch':
      return 'You can withdraw only to the method you deposited from.';
    case 'account_restricted':
      return 'Withdrawals are paused on your account — contact support.';
    default:
      return fallback;
  }
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _amount = TextEditingController();
  List<Map<String, dynamic>> _methods = const [];
  Set<String> _fundedTypes = {}; // AML: method types the user deposited from
  String? _methodId;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.balance.toStringAsFixed(2);
    if (kUseBackend) {
      _load();
    } else {
      _loading = false;
    }
  }

  bool _allowed(Map<String, dynamic> m) => _fundedTypes.isEmpty || _fundedTypes.contains(m['type']?.toString());

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        BackendApi.payoutMethods(),
        BackendApi.deposits().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final m = results[0];
      final deposits = results[1];
      // AML same-source: funded method types = types of confirmed deposits.
      final funded = <String>{
        for (final d in deposits)
          if (d['status'] == 'confirmed') (d['method'] ?? 'crypto').toString(),
      };
      if (!mounted) return;
      setState(() {
        _methods = m;
        _fundedTypes = funded;
        // Default to the first *allowed* method.
        final firstAllowed = m.where(_allowed).toList();
        _methodId = firstAllowed.isNotEmpty ? firstAllowed.first['id'].toString() : null;
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
    final cfg = AppConfig.instance;
    if (amount == null || amount <= 0) {
      _toast('Enter a valid amount');
      return;
    }
    if (amount > widget.balance) {
      _toast('Amount exceeds your balance');
      return;
    }
    if (cfg.minWithdrawal > 0 && amount < cfg.minWithdrawal) {
      _toast('Minimum withdrawal is \$${cfg.minWithdrawal.toStringAsFixed(2)}');
      return;
    }
    if (cfg.maxWithdrawalPerTx > 0 && amount > cfg.maxWithdrawalPerTx) {
      _toast('Maximum per withdrawal is \$${cfg.maxWithdrawalPerTx.toStringAsFixed(2)}');
      return;
    }
    if (_methodId == null) {
      _toast('Add a payout method first');
      return;
    }
    setState(() => _submitting = true);
    try {
      await BackendApi.requestPayout(amount: amount, methodId: _methodId);
      if (!mounted) return;
      Navigator.pop(context, true);
      _toast('Payout requested — pending approval');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast(friendlyWithdrawError(e.code, e.message));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Could not reach the server');
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final cfg = AppConfig.instance;
    final user = SessionScope.of(context).user;
    final kycNeeded = cfg.kycRequiredForWithdrawal && !(user?.kycVerified ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Withdraw', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: _loading
          ? const AppLoader()
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                Text('Available: \$${widget.balance.toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  decoration: const InputDecoration(prefixText: '\$ ', hintText: '0.00'),
                ),
                const SizedBox(height: 24),

                if (kycNeeded)
                  _GateCard(
                    icon: Icons.badge_outlined,
                    title: 'Identity verification required',
                    body: 'Verify your identity to enable withdrawals.',
                    cta: 'Verify now',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycScreen())),
                  )
                else if (_methods.isEmpty)
                  _GateCard(
                    icon: Icons.account_balance_rounded,
                    title: 'Add a payout method',
                    body: 'You need a crypto wallet or bank account to withdraw.',
                    cta: 'Add method',
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutMethodsScreen()));
                      _load();
                    },
                  )
                else ...[
                  Text('Send to', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  ..._methods.map((m) {
                    final id = m['id'].toString();
                    final active = _methodId == id;
                    final allowed = _allowed(m);
                    return Opacity(
                      opacity: allowed ? 1 : 0.5,
                      child: GestureDetector(
                        onTap: allowed
                            ? () => setState(() => _methodId = id)
                            : () => _toast('You can withdraw only to the method you deposited from (${_fundedTypes.join(', ')}).'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: active ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: active ? AppColors.primary : AppColors.border, width: active ? 1.5 : 1),
                          ),
                          child: Row(
                            children: [
                              Icon(m['type'] == 'bank' ? Icons.account_balance_rounded : Icons.currency_bitcoin_rounded, size: 20, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m['label'].toString(), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                    Text(allowed ? m['masked'].toString() : 'Locked — not your deposit source', style: GoogleFonts.inter(fontSize: 12, color: allowed ? AppColors.textMuted : AppColors.red)),
                                  ],
                                ),
                              ),
                              Icon(!allowed ? Icons.lock_outline_rounded : (active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded), size: 20, color: active ? AppColors.primary : AppColors.border),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.shield_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(child: Text('For your security, funds can only be withdrawn to the same method they were deposited from.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted, height: 1.35))),
                  ]),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Request withdrawal'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _GateCard extends StatelessWidget {
  final IconData icon;
  final String title, body, cta;
  final VoidCallback onTap;
  const _GateCard({required this.icon, required this.title, required this.body, required this.cta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 26),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(body, style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textSecondary, height: 1.45)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onTap, child: Text(cta)),
          ),
        ],
      ),
    );
  }
}
