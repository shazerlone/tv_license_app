import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';

/// Manage withdrawal destinations (GET/POST/DELETE /wallet/payout-methods).
class PayoutMethodsScreen extends StatefulWidget {
  const PayoutMethodsScreen({super.key});

  @override
  State<PayoutMethodsScreen> createState() => _PayoutMethodsScreenState();
}

class _PayoutMethodsScreenState extends State<PayoutMethodsScreen> {
  List<Map<String, dynamic>> _methods = const [];
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
      final m = await BackendApi.payoutMethods();
      if (!mounted) return;
      setState(() {
        _methods = m;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddMethodSheet(),
    );
    if (added == true) _load();
  }

  Future<void> _delete(String id) async {
    setState(() => _methods = _methods.where((m) => m['id'].toString() != id).toList());
    try {
      await BackendApi.deletePayoutMethod(id);
    } catch (_) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Payout methods', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _methods.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_rounded, size: 46, color: AppColors.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 14),
                        Text('No payout methods', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        Text('Add a crypto wallet or bank account to withdraw.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                  itemCount: _methods.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final m = _methods[i];
                    final type = (m['type'] ?? 'crypto').toString();
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: Icon(type == 'bank' ? Icons.account_balance_rounded : Icons.currency_bitcoin_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m['label'].toString(), style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(m['masked'].toString(), style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textMuted),
                            onPressed: () => _delete(m['id'].toString()),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class _AddMethodSheet extends StatefulWidget {
  const _AddMethodSheet();
  @override
  State<_AddMethodSheet> createState() => _AddMethodSheetState();
}

class _AddMethodSheetState extends State<_AddMethodSheet> {
  String _type = 'crypto';
  final _label = TextEditingController();
  final _asset = TextEditingController(text: 'USDT');
  final _address = TextEditingController();
  final _bankName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _iban = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_label, _asset, _address, _bankName, _accountNumber, _iban]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a label')));
      return;
    }
    final body = <String, dynamic>{
      'type': _type,
      'label': _label.text.trim(),
      if (_type == 'crypto') ...{
        'asset': _asset.text.trim(),
        'address': _address.text.trim(),
      } else ...{
        'bankName': _bankName.text.trim(),
        'accountNumber': _accountNumber.text.trim(),
        'iban': _iban.text.trim(),
      },
    };
    setState(() => _saving = true);
    try {
      await BackendApi.addPayoutMethod(body);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crypto = _type == 'crypto';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Add payout method', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _typeChip('crypto', 'Crypto', Icons.currency_bitcoin_rounded),
                  const SizedBox(width: 10),
                  _typeChip('bank', 'Bank', Icons.account_balance_rounded),
                ],
              ),
              const SizedBox(height: 16),
              _field(_label, 'Label (e.g. My USDT wallet)'),
              if (crypto) ...[
                _field(_asset, 'Asset (e.g. USDT, BTC)'),
                _field(_address, 'Wallet address'),
              ] else ...[
                _field(_bankName, 'Bank name'),
                _field(_accountNumber, 'Account number'),
                _field(_iban, 'IBAN / routing'),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save method'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String id, String label, IconData icon) {
    final active = _type == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primary.withOpacity(0.06) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? AppColors.primary : AppColors.border, width: active ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: active ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: active ? AppColors.primary : AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: hint),
        ),
      );
}
