import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../state/session.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import '../widgets/millimore_logo.dart';
import 'account_type_screen.dart';
import 'phone_login_screen.dart';
import 'home_screen.dart';

/// Clean, modern sign-in. A soft brand header (no chart animation) over a
/// scrollable form that adapts to any phone size.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    final session = SessionScope.of(context);
    final email = _emailController.text.trim().toLowerCase();

    setState(() => _isLoading = true);

    // ── Live backend ──────────────────────────────────────────────────────────
    // Seeded accounts (password: "password"): priya@millimore.app (follower),
    // trader@millimore.app (creator), admin@millimore.app (admin).
    if (kUseBackend) {
      // The free-tier server may be asleep; let the user know the wait is normal.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            duration: Duration(seconds: 30),
            content: Text('Waking up the server — this can take up to a minute on first launch…'),
          ));
        }
      });
      try {
        String? twofaCode;
        // Retry loop for 2FA: first attempt with no code; if the account has 2FA
        // the server returns twofa_required, so we prompt and resubmit.
        while (true) {
          try {
            final user = await AuthApi.login(
              email: email,
              password: _passwordController.text,
              twofaCode: twofaCode,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            session.applyBackendSession(user);
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
            return;
          } on ApiException catch (e) {
            if (e.code == 'twofa_required' || e.code == 'twofa_invalid') {
              if (!mounted) return;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              final entered = await _promptTwofa(invalid: e.code == 'twofa_invalid');
              if (entered == null || entered.isEmpty) {
                if (mounted) setState(() => _isLoading = false);
                return; // user cancelled
              }
              twofaCode = entered;
              continue; // resubmit with the code
            }
            rethrow;
          }
        }
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        // Network error / cold start. Fall through to the demo safety net below
        // for the demo trader so you can always get in to review the UI.
        if (email != 'trader@millimore.app') {
          if (!mounted) return;
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not reach the server — try again in a moment')));
          return;
        }
      }
    }

    // ── Demo (no backend) ─────────────────────────────────────────────────────
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isLoading = false);
    final nameFromEmail = email.contains('@') ? email.split('@').first : 'Trader';
    if (email == 'trader@millimore.app') {
      session.signInAsCreator(
        name: 'Demo Trader',
        market: 'Forex',
        platform: 'MetaTrader 5',
        residenceIso: 'IN',
        residenceCountry: 'India',
        status: CreatorStatus.approved,
      );
    } else {
      session.signInAsFollower(name: nameFromEmail);
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  /// Prompts for a 2FA code (TOTP or backup code). Returns null if cancelled.
  Future<String?> _promptTwofa({bool invalid = false}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Two-factor authentication', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invalid ? 'That code was incorrect. Try again.' : 'Enter the 6-digit code from your authenticator app.',
              style: GoogleFonts.inter(fontSize: 13.5, color: invalid ? AppColors.red : AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
              style: GoogleFonts.robotoMono(fontSize: 20, letterSpacing: 4, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: '000000'),
            ),
            const SizedBox(height: 6),
            Text('You can also use a backup code.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Verify')),
        ],
      ),
    );
  }

  void _showForgotPassword() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Reset your password', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Text(
          'Reach out to support@millimore.app from your registered email and we\'ll help you reset your password.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Got it', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    const MillimoreLogo(size: 26),
                    const SizedBox(height: 40),

                    // Headline
                    Text(
                      'Welcome back',
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to follow top traders and copy their moves.',
                      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 32),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _FieldLabel('Email'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: AppColors.textMuted),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter your email';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          _FieldLabel('Password'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _signIn(),
                            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Your password',
                              prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textMuted),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColors.textMuted,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter your password';
                              if (v.length < 6) return 'Min 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPassword,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text('Forgot password?',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Sign In'),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Text('or', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _isLoading ? null : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                                ),
                            icon: Icon(Icons.smartphone_rounded, size: 19, color: AppColors.primary),
                            label: Text('Sign in with phone number', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(kBuildLabel, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted.withOpacity(0.7))),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountTypeScreen())),
                        behavior: HitTestBehavior.opaque,
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
                            children: [
                              const TextSpan(text: "Don't have an account? "),
                              TextSpan(
                                text: 'Join now',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      );
}
