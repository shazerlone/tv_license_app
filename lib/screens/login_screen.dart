import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../state/session.dart';
import '../services/auth_api.dart';
import '../services/api_client.dart';
import '../widgets/millimore_logo.dart';
import 'account_type_screen.dart';
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
        final user = await AuthApi.login(email: email, password: _passwordController.text);
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        session.applyBackendSession(user);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
        return;
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

  void _soon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature is coming soon')));
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
                            decoration: const InputDecoration(
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
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textMuted),
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
                              onPressed: () => _soon('Password reset'),
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _SocialButton(label: 'Apple', icon: const _AppleIcon(), dark: true, onTap: () => _soon('Apple sign-in'))),
                        const SizedBox(width: 12),
                        Expanded(child: _SocialButton(label: 'Google', icon: const _GoogleIcon(), dark: false, onTap: () => _soon('Google sign-in'))),
                      ],
                    ),

                    const Spacer(),
                    const SizedBox(height: 24),
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

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool dark;
  final VoidCallback onTap;
  const _SocialButton({required this.label, required this.icon, required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: dark ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: dark ? null : Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: dark ? Colors.white : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _AppleIcon extends StatelessWidget {
  const _AppleIcon();
  @override
  Widget build(BuildContext context) => const Icon(Icons.apple, size: 22, color: Colors.white);
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) => SizedBox(width: 18, height: 18, child: CustomPaint(painter: _GoogleGPainter()));
}

/// Multi-colour Google "G".
class _GoogleGPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  double _deg(double d) => d * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.26;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - stroke / 2,
    );
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect, _deg(-16), _deg(76), false, arc(_blue));
    canvas.drawArc(rect, _deg(64), _deg(88), false, arc(_green));
    canvas.drawArc(rect, _deg(156), _deg(76), false, arc(_yellow));
    canvas.drawArc(rect, _deg(236), _deg(84), false, arc(_red));
    final cx = size.width / 2;
    final cy = size.height / 2;
    final barRect = Rect.fromLTRB(cx, cy - stroke / 2, rect.right + stroke / 2, cy + stroke / 2);
    canvas.drawRect(barRect, Paint()..color = _blue);
  }

  @override
  bool shouldRepaint(_GoogleGPainter old) => false;
}
