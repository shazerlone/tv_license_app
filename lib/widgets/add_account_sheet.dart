import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/brokers.dart';
import '../models/copy_models.dart';
import '../state/session.dart';
import '../state/app_state.dart';
import 'broker_logo.dart';

/// Connect a broker account for copy trading. Brokers shown depend on the
/// user's country of residence.
class AddAccountSheet extends StatefulWidget {
  const AddAccountSheet({super.key});

  static Future<TradingAccount?> open(BuildContext context) {
    return showModalBottomSheet<TradingAccount>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddAccountSheet(),
    );
  }

  @override
  State<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _serverController = TextEditingController();
  final _passwordController = TextEditingController();
  Broker? _broker;
  bool _loading = false;

  @override
  void dispose() {
    _accountController.dispose();
    _serverController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect(AppState store) async {
    if (_broker == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a broker')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final acc = store.addAccount(
      brokerId: _broker!.id,
      brokerName: _broker!.name,
      accountNumber: _accountController.text.trim(),
      server: _serverController.text.trim(),
    );
    Navigator.pop(context, acc);
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final store = AppStateScope.of(context);
    final iso = session.user?.residenceIso;
    final country = session.user?.residenceCountry ?? 'your region';
    final brokers = brokersForCountry(iso);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hero header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(18)),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.link_rounded, color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Connect a trading account', style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
                                      const SizedBox(height: 3),
                                      Text('Read-only mirror · disconnect anytime', style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white.withOpacity(0.6))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Text('Available in $country', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...brokers.map((b) => _BrokerTile(
                                broker: b,
                                selected: _broker?.id == b.id,
                                onTap: () => setState(() => _broker = b),
                              )),
                          if (_broker != null) ...[
                            const SizedBox(height: 20),
                            _Label('Account / Login number'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _accountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                              decoration: const InputDecoration(hintText: 'e.g. 50231487'),
                              validator: (v) => (v == null || v.isEmpty) ? 'Enter account number' : null,
                            ),
                            const SizedBox(height: 14),
                            _Label('Server'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _serverController,
                              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                              decoration: InputDecoration(hintText: 'e.g. ${_broker!.name}-Live'),
                              validator: (v) => (v == null || v.isEmpty) ? 'Enter server' : null,
                            ),
                            const SizedBox(height: 14),
                            _Label('Trading password'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                              decoration: const InputDecoration(hintText: 'Account password'),
                              validator: (v) => (v == null || v.isEmpty) ? 'Enter password' : null,
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text('Credentials are encrypted and used only to mirror trades on your account. You can disconnect anytime.',
                                        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            ElevatedButton(
                              onPressed: _loading ? null : () => _connect(store),
                              child: _loading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Connect account'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BrokerTile extends StatelessWidget {
  final Broker broker;
  final bool selected;
  final VoidCallback onTap;
  const _BrokerTile({required this.broker, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            BrokerLogo(name: broker.name, logoUrl: broker.logoUrl, size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(broker.name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      if (broker.recommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                          child: Text('Recommended', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(broker.blurb, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: selected ? AppColors.primary : AppColors.border),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary));
}
