import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/copy_models.dart';
import '../data/brokers.dart';
import '../state/app_state.dart';
import '../widgets/verified_badge.dart';
import '../widgets/add_account_sheet.dart';
import '../widgets/broker_logo.dart';

class CopyTradingScreen extends StatefulWidget {
  final Trader trader;
  const CopyTradingScreen({super.key, required this.trader});

  @override
  State<CopyTradingScreen> createState() => _CopyTradingScreenState();
}

class _CopyTradingScreenState extends State<CopyTradingScreen> {
  double _copyAmount = 500;
  double _risk = 1.0;
  bool _autoCopy = true;
  String? _accountId;

  @override
  Widget build(BuildContext context) {
    final trader = widget.trader;
    final store = AppStateScope.of(context);
    final accounts = store.accounts;
    final copying = store.isCopying(trader.id);

    // default selected account
    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    }
    TradingAccount? selected;
    for (final a in accounts) {
      if (a.id == _accountId) {
        selected = a;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Copy Trading', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TraderSummaryCard(trader: trader),
            const SizedBox(height: 24),

            // Account section
            Text('Trading account', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (accounts.isEmpty)
              _ConnectAccountCard(onAdd: () => _addAccount(store))
            else
              _AccountSelector(
                accounts: accounts,
                selectedId: _accountId,
                onSelect: (id) => setState(() => _accountId = id),
                onAdd: () => _addAccount(store),
              ),

            const SizedBox(height: 24),
            Text('Copy settings', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            _SettingCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Auto-copy new trades', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                        Text('Mirror every new trade automatically', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Switch(value: _autoCopy, onChanged: (v) => setState(() => _autoCopy = v), activeColor: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Copy amount', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('\$${_copyAmount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  Slider(value: _copyAmount, min: 100, max: 10000, divisions: 99, activeColor: AppColors.primary, inactiveColor: AppColors.border, onChanged: (v) => setState(() => _copyAmount = v)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('\$100', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    Text('\$10,000', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Risk multiplier', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('${_risk.toStringAsFixed(1)}x', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  Slider(value: _risk, min: 0.1, max: 3.0, divisions: 29, activeColor: AppColors.primary, inactiveColor: AppColors.border, onChanged: (v) => setState(() => _risk = v)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('0.1x', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    Text('3.0x', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (copying)
              OutlinedButton(
                onPressed: () {
                  store.stopCopy(trader.id);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stopped copying ${trader.name}')));
                },
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), side: BorderSide(color: AppColors.red.withOpacity(0.4))),
                child: Text('Stop copying', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.red)),
              )
            else
              ElevatedButton(
                onPressed: () => _startCopy(store, selected),
                child: const Text('Start copying'),
              ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                copying ? 'You are copying ${trader.name} on ${selected?.brokerName ?? ''}' : 'You will copy every verified trade from ${trader.name}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAccount(AppState store) async {
    final acc = await AddAccountSheet.open(context);
    if (acc != null && mounted) setState(() => _accountId = acc.id);
  }

  Future<void> _startCopy(AppState store, TradingAccount? account) async {
    var acc = account;
    if (acc == null) {
      acc = await AddAccountSheet.open(context);
      if (acc == null) return;
      _accountId = acc.id;
    }
    store.startCopy(widget.trader, accountId: acc.id, amount: _copyAmount, risk: _risk, autoCopy: _autoCopy);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now copying ${widget.trader.name}')));
    Navigator.pop(context);
  }
}

class _ConnectAccountCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _ConnectAccountCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('No trading account connected', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            ],
          ),
          const SizedBox(height: 6),
          Text('Connect a broker account to start copying trades.', style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: onAdd, child: const Text('Add trading account')),
          ),
        ],
      ),
    );
  }
}

class _AccountSelector extends StatelessWidget {
  final List<TradingAccount> accounts;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final VoidCallback onAdd;
  const _AccountSelector({required this.accounts, required this.selectedId, required this.onSelect, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...accounts.map((a) {
          final sel = a.id == selectedId;
          return GestureDetector(
            onTap: () => onSelect(a.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary.withOpacity(0.05) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  BrokerLogo(name: a.brokerName, logoUrl: brokerById(a.brokerId).logoUrl, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${a.brokerName} · ${a.masked}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text('${a.server} · \$${a.balance.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: sel ? AppColors.primary : AppColors.border),
                ],
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: onAdd,
          child: Row(
            children: [
              const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('Add another account', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TraderSummaryCard extends StatelessWidget {
  final Trader trader;
  const _TraderSummaryCard({required this.trader});

  @override
  Widget build(BuildContext context) {
    final isPositive = trader.returnPercent >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.1)),
            child: Center(child: Text(trader.name[0], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(trader.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                    if (trader.isVerified) ...[
                      const SizedBox(width: 4),
                      const VerifiedBadge(size: 14),
                    ],
                  ],
                ),
                Text('${trader.formattedFollowers} followers', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(trader.formattedReturn, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: isPositive ? AppColors.green : AppColors.red)),
              Text('30D return', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: child,
    );
  }
}
