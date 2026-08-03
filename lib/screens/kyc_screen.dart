import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../state/session.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';

/// Identity verification (KYC). Starts the flow via POST /kyc/start. When the
/// backend runs in manual mode it just marks the user pending; a real Sumsub
/// SDK token would be launched here once the native SDK is added.
class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  String _status = 'none';
  bool _loading = true;
  bool _starting = false;

  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _status = SessionScope.of(context).user?.kycStatus ?? 'none';
    if (kUseBackend) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    try {
      final r = await BackendApi.kycStatus();
      if (!mounted) return;
      setState(() {
        _status = (r['status'] ?? r['kycStatus'] ?? _status).toString();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final r = await BackendApi.startKyc();
      if (!mounted) return;
      final manual = r['manual'] == true || r['accessToken'] == null;
      setState(() {
        _starting = false;
        _status = 'pending';
      });
      // Refresh the session's kycStatus.
      final u = SessionScope.of(context).user;
      if (u != null) SessionScope.of(context).applyBackendSession(u.copyWith(kycStatus: 'pending'));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(manual
            ? 'Submitted — your identity is pending review.'
            : 'Verification started. Complete the steps to finish.'),
      ));
      // NOTE: when the Sumsub native SDK is added, launch it with r['accessToken'] here.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  ({Color color, IconData icon, String label, String body}) get _view {
    switch (_status) {
      case 'verified':
        return (color: AppColors.green, icon: Icons.verified_user_rounded, label: 'Verified', body: 'Your identity is verified. You can withdraw funds.');
      case 'pending':
        return (color: AppColors.primary, icon: Icons.hourglass_top_rounded, label: 'Under review', body: 'We\'re reviewing your documents. This usually takes a few minutes to a few hours.');
      case 'rejected':
        return (color: AppColors.red, icon: Icons.error_outline_rounded, label: 'Rejected', body: 'We couldn\'t verify your identity. Please try again with clearer documents.');
      default:
        return (color: AppColors.slate, icon: Icons.badge_outlined, label: 'Not started', body: 'Verify your identity to enable withdrawals. You\'ll need a government ID.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _view;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Identity verification', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: v.color.withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(v.icon, color: v.color, size: 34),
                  ),
                  const SizedBox(height: 20),
                  Text(v.label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                  const SizedBox(height: 8),
                  Text(v.body, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                  const Spacer(),
                  if (_status != 'verified' && _status != 'pending')
                    ElevatedButton(
                      onPressed: _starting ? null : _start,
                      child: _starting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_status == 'rejected' ? 'Try again' : 'Start verification'),
                    ),
                ],
              ),
            ),
    );
  }
}
