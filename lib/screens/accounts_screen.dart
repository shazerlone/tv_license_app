import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/copy_models.dart';
import '../data/brokers.dart';
import '../state/app_state.dart';
import '../widgets/add_account_sheet.dart';
import '../widgets/broker_logo.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final accounts = store.accounts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Trading accounts', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: accounts.isEmpty
          ? _Empty(onAdd: () => AddAccountSheet.open(context))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                ...accounts.map((a) => _AccountCard(account: a, store: store)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => AddAccountSheet.open(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add another account'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                ),
              ],
            ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final TradingAccount account;
  final AppState store;
  const _AccountCard({required this.account, required this.store});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BrokerLogo(name: account.brokerName, logoUrl: brokerById(account.brokerId).logoUrl, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.brokerName, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('${account.masked} · ${account.server}', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Connected', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.green)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Pill(label: 'Balance', value: '\$${account.balance.toStringAsFixed(0)}'),
              const SizedBox(width: 20),
              _Pill(label: 'Currency', value: account.currency),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _changePassword(context),
                  icon: const Icon(Icons.key_rounded, size: 17, color: AppColors.textSecondary),
                  label: Text('Change password', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
              ),
              Container(width: 1, height: 22, color: AppColors.border),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _remove(context),
                  icon: const Icon(Icons.link_off_rounded, size: 17, color: AppColors.red),
                  label: Text('Disconnect', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _changePassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(account: account),
    );
  }

  void _remove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Disconnect account?', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text('Copy trading on ${account.brokerName} (${account.masked}) will stop. You can reconnect anytime.',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              store.removeAccount(account.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${account.brokerName} disconnected')));
            },
            child: Text('Disconnect', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  final TradingAccount account;
  const _ChangePasswordSheet({required this.account});

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Change password', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('${widget.account.brokerName} · ${widget.account.masked}', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 18),
              TextFormField(
                controller: _current,
                obscureText: true,
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Current password'),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter current password' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _next,
                obscureText: true,
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'New password'),
                validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update password'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  const _Pill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 1),
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted)),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 46, color: AppColors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 14),
            Text('No accounts connected', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text('Connect a broker account to start copy trading.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted, height: 1.5)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onAdd, child: const Text('Connect account')),
          ],
        ),
      ),
    );
  }
}
