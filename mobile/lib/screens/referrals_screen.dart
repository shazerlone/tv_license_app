import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/skeletons.dart';
import '../config.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';

/// Invite & earn (GET /referrals/me, POST /referrals/apply).
class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  Map<String, dynamic>? _data;
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
    try {
      final d = await BackendApi.referralMe();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final stats = (d?['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
    final code = d?['code']?.toString() ?? '';
    final link = d?['link']?.toString() ?? '';
    final revShare = (d?['revenueSharePercent'] as num?)?.toDouble() ?? 0;
    final bonus = (d?['signupBonus'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Invite & earn', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: _loading
          ? const AppLoader()
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1E1B4B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 28),
                      const SizedBox(height: 14),
                      Text(
                        revShare > 0
                            ? 'Earn ${revShare.toStringAsFixed(0)}% of what your invites pay in fees'
                            : 'Invite friends to Millimore',
                        style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25, letterSpacing: -0.3),
                      ),
                      if (bonus > 0) ...[
                        const SizedBox(height: 6),
                        Text('They get \$${bonus.toStringAsFixed(0)} to start.', style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white.withOpacity(0.75))),
                      ],
                      const SizedBox(height: 18),
                      // Code
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(child: Text(code.isEmpty ? '—' : code, style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2))),
                            GestureDetector(
                              onTap: () => _copy(code, 'Code copied'),
                              child: const Icon(Icons.copy_rounded, size: 20, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: link.isEmpty ? null : () => _copy(link, 'Invite link copied'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          label: Text('Copy invite link', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _stat('Invited', '${(stats['referred'] as num?)?.toInt() ?? 0}'),
                    const SizedBox(width: 12),
                    _stat('Active', '${(stats['activeReferred'] as num?)?.toInt() ?? 0}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('Earned', '\$${((stats['totalEarned'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}'),
                    const SizedBox(width: 12),
                    _stat('Last 30d', '\$${((stats['earned30d'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}'),
                  ],
                ),
                const SizedBox(height: 26),
                Text('Have a referral code?', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                _ApplyCode(onApplied: _load),
              ],
            ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      );

  void _copy(String text, String msg) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ApplyCode extends StatefulWidget {
  final VoidCallback onApplied;
  const _ApplyCode({required this.onApplied});
  @override
  State<_ApplyCode> createState() => _ApplyCodeState();
}

class _ApplyCodeState extends State<_ApplyCode> {
  final _c = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _c.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await BackendApi.applyReferral(code);
      if (!mounted) return;
      _c.clear();
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Referral applied 🎉')));
      widget.onApplied();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            decoration: const InputDecoration(hintText: 'Enter code'),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _busy ? null : _apply,
            child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Apply'),
          ),
        ),
      ],
    );
  }
}
