import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/countries.dart';
import '../widgets/phone_field.dart';
import '../services/phone_auth_service.dart';
import '../state/session.dart';
import 'home_screen.dart';

/// Phone sign-in / sign-up via Firebase Phone Auth (SMS OTP, works in India +
/// US with no DLT). Two steps: enter number → enter the 6-digit code.
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _svc = PhoneAuthService();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  Country _country = countryByIso('IN');

  bool _codeSent = false;
  bool _loading = false;
  String? _error;
  int _resendIn = 0;
  String get _e164 => '${_country.dialCode}${_phoneController.text.replaceAll(RegExp(r'\D'), '')}';

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    if (_phoneController.text.replaceAll(RegExp(r'\D'), '').length < 6) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await _svc.start(
      _e164,
      resend: resend,
      onCodeSent: () {
        if (!mounted) return;
        setState(() { _loading = false; _codeSent = true; });
        _startResendCountdown();
      },
      onAutoSignedIn: (profile) {
        if (!mounted) return;
        SessionScope.of(context).applyBackendSession(profile);
        _goHome();
      },
      onError: (m) {
        if (!mounted) return;
        setState(() { _loading = false; _error = m; });
      },
    );
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length < 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final profile = await _svc.confirm(_codeController.text.trim());
      if (!mounted) return;
      SessionScope.of(context).applyBackendSession(profile);
      _goHome();
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (r) => false,
    );
  }

  void _startResendCountdown() {
    setState(() => _resendIn = 45);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendIn--);
      return _resendIn > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_codeSent) {
              setState(() { _codeSent = false; _error = null; _codeController.clear(); });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _codeSent ? 'Enter the code' : 'Continue with phone',
                style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.8),
              ),
              const SizedBox(height: 6),
              Text(
                _codeSent ? 'We sent a 6-digit code to $_e164.' : 'We\'ll text you a verification code.',
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 28),
              if (!_codeSent) ...[
                PhoneField(
                  controller: _phoneController,
                  country: _country,
                  onCountryChanged: (c) => setState(() => _country = c),
                  onSubmitted: _sendCode,
                ),
              ] else ...[
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  autofocus: true,
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 8, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(hintText: '••••••'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: _resendIn > 0
                      ? Text('Resend code in ${_resendIn}s', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted))
                      : TextButton(onPressed: _loading ? null : () => _sendCode(resend: true), child: const Text('Resend code')),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.red)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : (_codeSent ? _verify : _sendCode),
                child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_codeSent ? 'Verify' : 'Send code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
