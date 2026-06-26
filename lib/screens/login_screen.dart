import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/millimore_logo.dart';
import 'account_type_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  late final AnimationController _heroController;
  late final AnimationController _panelController;
  late final Animation<double> _heroFade;
  late final Animation<Offset> _panelSlide;
  late final Animation<double> _panelFade;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeOut),
    );
    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _panelController, curve: Curves.easeOutCubic),
    );
    _panelFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _panelController, curve: Curves.easeOut),
    );

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _panelController.forward();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _panelController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _heroFade,
            child: SizedBox(
              width: size.width,
              height: size.height * 0.52,
              child: const _LoginHero(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _panelSlide,
              child: FadeTransition(
                opacity: _panelFade,
                child: _LoginPanel(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  isLoading: _isLoading,
                  onTogglePassword: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  onSignIn: _signIn,
                  onCreateAccount: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AccountTypeScreen()),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHero extends StatefulWidget {
  const _LoginHero();

  @override
  State<_LoginHero> createState() => _LoginHeroState();
}

class _LoginHeroState extends State<_LoginHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ticker,
            builder: (_, __) => CustomPaint(
              painter: _MarketPainter(progress: _ticker.value),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 120,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.background,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const MillimoreLogo(size: 26),
                const SizedBox(height: 20),
                Text(
                  'Trade smarter.\nGrow together.',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.8,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'The creator economy for traders.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.55),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 24,
          top: 28,
          child: SafeArea(
            child: _LiveBadge(),
          ),
        ),
      ],
    );
  }
}

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.red.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'LIVE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.red,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketPainter extends CustomPainter {
  final double progress;
  const _MarketPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0B1120),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (int i = 1; i < 6; i++) {
      final y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (int i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final candles = _generateCandles(size);
    for (final c in candles) {
      _drawCandle(canvas, c);
    }

    final trendPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final pts = candles.map((c) => Offset(c.x, c.close)).toList();
    if (pts.isNotEmpty) {
      path.moveTo(pts.first.dx, pts.first.dy);
      for (int i = 1; i < pts.length; i++) {
        final cx = (pts[i - 1].dx + pts[i].dx) / 2;
        path.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
      }
    }

    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, size.width * (0.3 + 0.7 * progress), size.height));
    canvas.drawPath(path, trendPaint);

    final fillPath = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withOpacity(0.12),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.restore();
  }

  List<_Candle> _generateCandles(Size size) {
    final rng = math.Random(42);
    final candles = <_Candle>[];
    const count = 14;
    final candleW = size.width / count;
    double price = size.height * 0.55;

    for (int i = 0; i < count; i++) {
      final x = candleW * i + candleW / 2;
      final move = (rng.nextDouble() - 0.44) * size.height * 0.07;
      final open = price;
      price = (price + move).clamp(size.height * 0.2, size.height * 0.8);
      final close = price;
      final high = math.min(open, close) - rng.nextDouble() * 8;
      final low = math.max(open, close) + rng.nextDouble() * 8;
      candles.add(_Candle(x: x, open: open, close: close, high: high, low: low, width: candleW * 0.55));
    }
    return candles;
  }

  void _drawCandle(Canvas canvas, _Candle c) {
    final bull = c.close <= c.open;
    final color = bull ? AppColors.green : AppColors.red;
    final body = Rect.fromLTWH(
      c.x - c.width / 2,
      math.min(c.open, c.close),
      c.width,
      (c.open - c.close).abs().clamp(2.0, double.infinity),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2)),
      Paint()..color = color.withOpacity(0.85),
    );
    final wickPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(c.x, c.high), Offset(c.x, math.min(c.open, c.close)), wickPaint);
    canvas.drawLine(Offset(c.x, math.max(c.open, c.close)), Offset(c.x, c.low), wickPaint);
  }

  @override
  bool shouldRepaint(_MarketPainter old) => old.progress != progress;
}

class _Candle {
  final double x, open, close, high, low, width;
  const _Candle({
    required this.x,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.width,
  });
}

class _LoginPanel extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  const _LoginPanel({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onCreateAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Welcome back',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _SocialButton(
                      label: 'Apple',
                      icon: _AppleIcon(),
                      dark: true,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SocialButton(
                      label: 'Google',
                      icon: _GoogleIcon(),
                      dark: false,
                      onTap: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _OrDivider(),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Email address'),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onSignIn(),
                style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: onTogglePassword,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password';
                  if (v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : onSignIn,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign In'),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: onCreateAccount,
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                      children: [
                        const TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Join now',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
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
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool dark;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
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
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _AppleIconPainter()),
    );
  }
}

class _AppleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, h * 0.08);
    path.cubicTo(w * 0.62, h * 0.08, w * 0.72, h * 0.15, w * 0.72, h * 0.15);
    path.cubicTo(w * 0.72, h * 0.15, w * 0.82, h * 0.07, w * 0.85, h * 0.04);
    path.cubicTo(w * 0.73, h * -0.02, w * 0.62, h * 0.03, w * 0.62, h * 0.03);
    path.cubicTo(w * 0.62, h * 0.03, w * 0.62, h * 0.0, w * 0.6, h * 0.0);
    path.cubicTo(w * 0.55, h * 0.0, w * 0.5, h * 0.04, w * 0.5, h * 0.08);
    path.close();
    path.moveTo(w * 0.15, h * 0.32);
    path.cubicTo(w * 0.05, h * 0.5, w * 0.1, h * 0.72, w * 0.22, h * 0.88);
    path.cubicTo(w * 0.3, h * 0.98, w * 0.38, h * 1.0, w * 0.46, h * 0.98);
    path.cubicTo(w * 0.54, h * 0.96, w * 0.58, h * 0.9, w * 0.66, h * 0.9);
    path.cubicTo(w * 0.74, h * 0.9, w * 0.78, h * 0.96, w * 0.86, h * 0.98);
    path.cubicTo(w * 0.94, h * 1.0, w * 1.0, h * 0.94, w * 1.0, h * 0.86);
    path.cubicTo(w * 1.0, h * 0.78, w * 0.85, h * 0.64, w * 0.85, h * 0.52);
    path.cubicTo(w * 0.85, h * 0.4, w * 0.95, h * 0.28, w * 0.95, h * 0.18);
    path.cubicTo(w * 0.95, h * 0.1, w * 0.88, h * 0.06, w * 0.82, h * 0.08);
    path.cubicTo(w * 0.74, h * 0.1, w * 0.68, h * 0.18, w * 0.6, h * 0.18);
    path.cubicTo(w * 0.52, h * 0.18, w * 0.46, h * 0.12, w * 0.38, h * 0.12);
    path.cubicTo(w * 0.28, h * 0.12, w * 0.2, h * 0.2, w * 0.15, h * 0.32);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_AppleIconPainter old) => false;
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];
    final starts = [0.0, math.pi / 2, math.pi, 3 * math.pi / 2];
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        starts[i],
        math.pi / 2,
        false,
        Paint()
          ..color = colors[i]
          ..strokeWidth = size.width * 0.3
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_GoogleIconPainter old) => false;
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with email',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
