import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../data/countries.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import '../widgets/phone_field.dart';
import 'otp_screen.dart';

/// Sign in with a phone number. Requests an OTP, then hands off to [OtpScreen],
/// which verifies and signs the existing account in (the backend logs in the
/// phone's owner, or creates a minimal account if it's new).
class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  Country _country = countryByIso('IN');
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = '${_country.dialCode} ${_phoneController.text.trim()}';
    setState(() => _loading = true);
    try {
      final req = await AuthApi.requestOtp(phone);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(
          phoneNumber: phone,
          name: '',
          residenceIso: _country.iso,
          residenceCountry: _country.name,
          requestId: req.requestId,
        ),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server — try again in a moment')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Sign in with phone', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What\'s your number?', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text('We\'ll text you a 6-digit code to sign in. No password needed.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                const SizedBox(height: 28),
                PhoneField(
                  controller: _phoneController,
                  country: _country,
                  onCountryChanged: (c) => setState(() => _country = c),
                  onSubmitted: _sendCode,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendCode,
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Send code'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
