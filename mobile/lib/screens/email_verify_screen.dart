import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/session.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';

/// Enter the 6-digit code emailed by the backend to verify the address.
class EmailVerifyScreen extends StatefulWidget {
  final String email;
  final String? devCode; // shown in dev when mail is off
  const EmailVerifyScreen({super.key, required this.email, this.devCode});

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  int _resendIn = 0;

  @override
  void initState() {
    super.initState();
    if (widget.devCode != null && widget.devCode!.isNotEmpty) _code.text = widget.devCode!;
    _startCooldown();
  }

  void _startCooldown() {
    setState(() => _resendIn = 45);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendIn = (_resendIn - 1).clamp(0, 45));
      return _resendIn > 0;
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await AuthApi.verifyEmail(code);
      if (ok) {
        // Refresh the session so the verified badge updates everywhere.
        try {
          final me = await AuthApi.me();
          if (mounted) SessionScope.of(context).applyBackendSession(me);
        } catch (_) {}
        if (!mounted) return;
        Navigator.pop(context, true);
        messenger.showSnackBar(const SnackBar(content: Text('Email verified ✓')));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(_msg(e.code))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  String _msg(String code) {
    switch (code) {
      case 'code_mismatch':
        return 'That code is incorrect — try again.';
      case 'code_expired':
        return 'That code expired — resend a new one.';
      case 'too_many_attempts':
        return 'Too many attempts — resend a new code.';
      case 'code_invalid':
        return 'Enter the 6-digit code.';
      default:
        return 'Verification failed — try again.';
    }
  }

  Future<void> _resend() async {
    if (_resendIn > 0) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dev = await AuthApi.sendEmailCode();
      if (dev != null && dev.isNotEmpty && mounted) _code.text = dev;
      _startCooldown();
      messenger.showSnackBar(const SnackBar(content: Text('Code sent — check your inbox')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not resend the code')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Verify email', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.mark_email_read_outlined, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text('Enter the code we emailed', style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('We sent a 6-digit code to ${widget.email}.', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 22),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.robotoMono(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 8, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(counterText: '', hintText: '––––––'),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _busy ? null : _verify,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Verify', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: _resendIn > 0 ? null : _resend,
              child: Text(_resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code',
                  style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: _resendIn > 0 ? AppColors.textMuted : AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
