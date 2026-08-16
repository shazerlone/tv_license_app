import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';
import '../services/realtime_service.dart';
import 'kyc_screen.dart';

/// The deposit funnel: gate → network → address + QR → live confirmation.
/// Crypto (USDT) only for now, per APP_WALLET_GUIDE.md §3.
class DepositFlowScreen extends StatefulWidget {
  const DepositFlowScreen({super.key});

  @override
  State<DepositFlowScreen> createState() => _DepositFlowScreenState();
}

enum _Gate { loading, ready, kyc, unavailable, error }

class _DepositFlowScreenState extends State<DepositFlowScreen> {
  _Gate _gate = _Gate.loading;
  String _gateMsg = '';
  List<_DepositAddress> _addresses = const [];

  @override
  void initState() {
    super.initState();
    _loadGate();
  }

  Future<void> _loadGate() async {
    setState(() => _gate = _Gate.loading);
    try {
      final raw = await BackendApi.depositAddresses();
      final list = raw.map(_DepositAddress.fromJson).toList();
      // Preferred network order: TRON, Ethereum, BSC.
      const order = {'tron': 0, 'ethereum': 1, 'bsc': 2};
      list.sort((a, b) => (order[a.network] ?? 9).compareTo(order[b.network] ?? 9));
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _gate = list.isEmpty ? _Gate.unavailable : _Gate.ready;
        if (list.isEmpty) _gateMsg = 'Crypto deposits are being set up — check back soon.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'kyc_required') {
          _gate = _Gate.kyc;
        } else if (e.code == 'deposits_unavailable') {
          _gate = _Gate.unavailable;
          _gateMsg = 'Crypto deposits are being set up — check back soon.';
        } else {
          _gate = _Gate.error;
          _gateMsg = e.message;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gate = _Gate.error;
        _gateMsg = 'Could not reach the server. Pull to retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Deposit', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: switch (_gate) {
        _Gate.loading => Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.6)),
        _Gate.kyc => _GateMessage(
            icon: Icons.verified_user_outlined,
            title: 'Verify your identity',
            body: 'Complete a quick identity check (KYC) to unlock crypto deposits and keep your funds secure.',
            actionLabel: 'Start verification',
            onAction: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const KycScreen())),
          ),
        _Gate.unavailable => _GateMessage(
            icon: Icons.hourglass_empty_rounded,
            title: 'Deposits coming soon',
            body: _gateMsg,
            actionLabel: 'Retry',
            onAction: _loadGate,
          ),
        _Gate.error => _GateMessage(
            icon: Icons.wifi_off_rounded,
            title: 'Something went wrong',
            body: _gateMsg,
            actionLabel: 'Retry',
            onAction: _loadGate,
          ),
        _Gate.ready => _NetworkPicker(addresses: _addresses),
      },
    );
  }
}

/// Step 1 — network chooser.
class _NetworkPicker extends StatelessWidget {
  final List<_DepositAddress> addresses;
  const _NetworkPicker({required this.addresses});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Text('Deposit USDT', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
        const SizedBox(height: 4),
        Text('Choose a network. Your address is permanent — reuse it anytime.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 16),
        for (final a in addresses)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NetworkCard(
              address: a,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _AddressScreen(address: a))),
            ),
          ),
        const SizedBox(height: 8),
        _WarnStrip(text: 'Only send USDT on the network you select. Sending any other coin or network can permanently lose your funds.'),
      ],
    );
  }
}

class _NetworkCard extends StatelessWidget {
  final _DepositAddress address;
  final VoidCallback onTap;
  const _NetworkCard({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border), boxShadow: AppColors.softShadow),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.hub_outlined, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(address.networkLabel, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(color: AppColors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
                      child: Text(address.asset, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.green)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Text(address.hint, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Step 2 — address + QR.
class _AddressScreen extends StatelessWidget {
  final _DepositAddress address;
  const _AddressScreen({required this.address});

  String get _truncated {
    final a = address.address;
    if (a.length <= 16) return a;
    return '${a.substring(0, 8)}…${a.substring(a.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Deposit USDT', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Center(
            child: Text('USDT · ${address.networkLabel}', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              child: QrImageView(
                data: address.address,
                size: 190,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0F172A)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0F172A)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Address + copy
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deposit address ($_truncated)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(address.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.robotoMono(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _CopyButton(value: address.address),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _WarnStrip(text: 'Send only USDT on ${address.networkLabel}. Other assets or networks will be lost.'),
          const SizedBox(height: 16),
          const _HowToDeposit(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _WaitingScreen(address: address))),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
              label: Text("I've sent the USDT", style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('You can leave — we\'ll notify you when it arrives.', style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String value;
  const _CopyButton({required this.value});
  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: widget.value));
        HapticFeedback.mediumImpact();
        if (!mounted) return;
        setState(() => _done = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied'), duration: Duration(seconds: 1)));
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _done = false);
        });
      },
      icon: Icon(_done ? Icons.check_rounded : Icons.copy_rounded, size: 16, color: _done ? AppColors.green : AppColors.primary),
      label: Text(_done ? 'Copied' : 'Copy', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: _done ? AppColors.green : AppColors.primary)),
    );
  }
}

class _HowToDeposit extends StatelessWidget {
  const _HowToDeposit();
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text('How to deposit', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          iconColor: AppColors.textSecondary,
          children: const [
            _Step(n: 1, text: 'Copy your deposit address above.'),
            _Step(n: 2, text: 'In your wallet or exchange, send USDT on this exact network.'),
            _Step(n: 3, text: 'Wait for on-chain confirmations — your balance updates automatically.'),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20, alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
            child: Text('$n', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35))),
        ],
      ),
    );
  }
}

/// Step 3 — waiting for on-chain confirmation (WS + poll).
class _WaitingScreen extends StatefulWidget {
  final _DepositAddress address;
  const _WaitingScreen({required this.address});
  @override
  State<_WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<_WaitingScreen> {
  Timer? _poll;
  StreamSubscription? _wsSub;
  Set<String> _knownConfirmed = {};
  bool _done = false;
  double? _amount;

  @override
  void initState() {
    super.initState();
    _seedKnown();
    // Realtime: instant credit.
    _wsSub = RealtimeService.current?.walletEvents.listen((e) {
      if (e['type'] == 'wallet.deposit') {
        final d = (e['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        _succeed((d['amount'] as num?)?.toDouble());
      }
    });
    // Poll fallback every 10s.
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  Future<void> _seedKnown() async {
    try {
      final list = await BackendApi.deposits();
      _knownConfirmed = {
        for (final d in list)
          if (d['status'] == 'confirmed') d['id'].toString(),
      };
    } catch (_) {}
  }

  Future<void> _check() async {
    try {
      final list = await BackendApi.deposits();
      for (final d in list) {
        if (d['status'] == 'confirmed' && !_knownConfirmed.contains(d['id'].toString())) {
          _succeed((d['amount'] as num?)?.toDouble());
          return;
        }
      }
    } catch (_) {}
  }

  void _succeed(double? amount) {
    if (_done || !mounted) return;
    setState(() {
      _done = true;
      _amount = amount;
    });
    HapticFeedback.heavyImpact();
    _poll?.cancel();
    // Refresh shared state so the whole app reflects the new balance.
    AppStateScope.of(context).loadWallet();
    AppStateScope.of(context).loadCopyEngine();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_done ? 'Deposit received' : 'Waiting for deposit', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _done ? _success() : _waiting(),
        ),
      ),
    );
  }

  Widget _waiting() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 62, height: 62, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary)),
        const SizedBox(height: 24),
        Text('Waiting for your deposit…', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('USDT · ${widget.address.networkLabel}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Text('Your balance updates automatically once the payment confirms on-chain. You can safely leave this screen.',
            textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          style: OutlinedButton.styleFrom(minimumSize: const Size(200, 48)),
          child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _success() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76, height: 76,
          decoration: BoxDecoration(color: AppColors.green.withOpacity(0.14), shape: BoxShape.circle),
          child: Icon(Icons.check_rounded, size: 42, color: AppColors.green),
        ),
        const SizedBox(height: 22),
        Text(_amount != null ? '+\$${_amount!.toStringAsFixed(2)} added' : 'Deposit received', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Your balance is ready to trade.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 26),
        SizedBox(
          width: 220, height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            child: Text('Back to wallet', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

// ── shared bits ──────────────────────────────────────────────────────────
class _GateMessage extends StatelessWidget {
  final IconData icon;
  final String title, body, actionLabel;
  final VoidCallback onAction;
  const _GateMessage({required this.icon, required this.title, required this.body, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68, height: 68,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textMuted, height: 1.45)),
            const SizedBox(height: 24),
            SizedBox(
              width: 240, height: 50,
              child: ElevatedButton(onPressed: onAction, child: Text(actionLabel, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white))),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarnStrip extends StatelessWidget {
  final String text;
  const _WarnStrip({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.red.withOpacity(0.07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.red.withOpacity(0.25))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 17, color: AppColors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.red, height: 1.4, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

/// A per-network deposit address from GET /deposits/addresses.
class _DepositAddress {
  final String network; // tron | ethereum | bsc
  final String asset; // USDT
  final String address;
  const _DepositAddress({required this.network, required this.asset, required this.address});

  factory _DepositAddress.fromJson(Map<String, dynamic> j) => _DepositAddress(
        network: (j['network'] ?? '').toString(),
        asset: (j['asset'] ?? 'USDT').toString(),
        address: (j['address'] ?? '').toString(),
      );

  String get networkLabel => switch (network) {
        'tron' => 'TRON (TRC-20)',
        'ethereum' => 'Ethereum (ERC-20)',
        'bsc' => 'BNB Smart Chain (BEP-20)',
        _ => network.toUpperCase(),
      };

  String get hint => switch (network) {
        'tron' => 'Lowest fees · fastest',
        'ethereum' => 'Higher network fees',
        'bsc' => 'Low fees',
        _ => 'USDT deposits',
      };
}
