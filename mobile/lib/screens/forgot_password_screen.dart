import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';

/// Two-step password reset (backend M17): request a code by email, then set a
/// new password with the code.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _snack('Enter your account email');
      return;
    }
    setState(() => _busy = true);
    try {
      final devToken = await BackendApi.forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _busy = false;
        if (devToken != null) _token.text = devToken; // dev convenience
      });
      _snack('If that email exists, a reset code is on its way.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not reach the server — try again');
    }
  }

  Future<void> _reset() async {
    final token = _token.text.trim();
    final pw = _password.text;
    if (token.isEmpty) {
      _snack('Enter the reset code from your email');
      return;
    }
    if (pw.length < 8) {
      _snack('Password must be at least 8 characters');
      return;
    }
    setState(() => _busy = true);
    try {
      await BackendApi.resetPassword(token, pw);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated — sign in with your new password')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.code == 'reset_token_invalid' ? 'That code is invalid or expired.' : e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Could not reach the server — try again');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Reset password', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(_sent ? 'Enter your code' : 'Forgot your password?', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(_sent
                ? 'We sent a reset code to ${_email.text.trim()}. Enter it below with your new password.'
                : 'Enter your account email and we\'ll send you a code to reset it.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 24),
            TextField(
              controller: _email,
              enabled: !_sent,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
              decoration: InputDecoration(hintText: 'you@email.com', prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: AppColors.textMuted)),
            ),
            if (_sent) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _token,
                style: GoogleFonts.robotoMono(fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(hintText: 'Reset code', prefixIcon: Icon(Icons.key_rounded, size: 20, color: AppColors.textMuted)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: true,
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(hintText: 'New password (min 8 chars)', prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textMuted)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _busy ? null : (_sent ? _reset : _send),
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_sent ? 'Reset password' : 'Send reset code', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            if (_sent) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _send,
                  child: Text('Resend code', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
