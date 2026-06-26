import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<AnimationController> _slideControllers;
  late final List<Animation<double>> _slideFades;
  late final List<Animation<Offset>> _slideOffsets;

  static const int _pageCount = 3;

  @override
  void initState() {
    super.initState();

    _slideControllers = List.generate(
      _pageCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      ),
    );

    _slideFades = _slideControllers.map((c) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      );
    }).toList();

    _slideOffsets = _slideControllers.map((c) {
      return Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic));
    }).toList();

    _slideControllers[0].forward();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _slideControllers[index].forward(from: 0);
  }

  Future<void> _finish() async {
    StorageService.markOnboardingSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _next() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  void dispose() {
    for (final c in _slideControllers) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: [
              _OnboardingPage(
                fadeAnim: _slideFades[0],
                slideAnim: _slideOffsets[0],
                visual: _CopyTradingVisual(),
                label: 'COPY TRADING',
                headline: 'Follow traders\nwho actually win.',
                body: 'Every trade is verified directly from MT5. No screenshots. No fakes. Just real, audited performance you can copy with one tap.',
              ),
              _OnboardingPage(
                fadeAnim: _slideFades[1],
                slideAnim: _slideOffsets[1],
                visual: _LiveStreamVisual(),
                label: 'LIVE STREAMS',
                headline: 'Watch the trade\nhappen live.',
                body: 'The best traders stream their screens in real time. See the setup, hear the reasoning, copy the entry — all before the move happens.',
              ),
              _OnboardingPage(
                fadeAnim: _slideFades[2],
                slideAnim: _slideOffsets[2],
                visual: _EarnVisual(),
                label: 'CREATOR ECONOMY',
                headline: 'Your edge is\nyour income.',
                body: 'Connect your broker, share your verified record, and earn from every follower who copies your trades. The market rewards skill.',
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: AppColors.background,
              padding: EdgeInsets.fromLTRB(
                  28, 20, 28, MediaQuery.of(context).padding.bottom + 32),
              child: Column(
                children: [
                  _PageIndicator(count: _pageCount, current: _currentPage),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_currentPage < _pageCount - 1)
                        Expanded(
                          child: TextButton(
                            onPressed: _finish,
                            child: Text(
                              'Skip',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      if (_currentPage < _pageCount - 1)
                        const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _next,
                          child: Text(
                            _currentPage == _pageCount - 1
                                ? 'Get Started'
                                : 'Continue',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final Widget visual;
  final String label;
  final String headline;
  final String body;

  const _OnboardingPage({
    required this.fadeAnim,
    required this.slideAnim,
    required this.visual,
    required this.label,
    required this.headline,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: size.height * 0.46,
          width: double.infinity,
          child: visual,
        ),
        Expanded(
          child: FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: slideAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      headline,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.0,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      body,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.65,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Slide 1: Copy Trading Visual ─────────────────────────────────────────────

class _CopyTradingVisual extends StatefulWidget {
  @override
  State<_CopyTradingVisual> createState() => _CopyTradingVisualState();
}

class _CopyTradingVisualState extends State<_CopyTradingVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F5FF),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          painter: _CopyTradingPainter(progress: _anim.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _CopyTradingPainter extends CustomPainter {
  final double progress;
  const _CopyTradingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final barData = [
      [0.10, 0.75, 0.58, 0.52, 0.80, 1],
      [0.22, 0.68, 0.50, 0.46, 0.72, 0],
      [0.34, 0.58, 0.40, 0.36, 0.65, 1],
      [0.46, 0.48, 0.28, 0.24, 0.55, 1],
      [0.58, 0.35, 0.18, 0.14, 0.42, 1],
      [0.70, 0.28, 0.14, 0.10, 0.34, 0],
      [0.82, 0.20, 0.08, 0.05, 0.26, 1],
    ];

    final barBodyPaint = Paint()..style = PaintingStyle.fill;
    final wickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barData.length; i++) {
      final p = ((progress - i * 0.09) / 0.37).clamp(0.0, 1.0);
      if (p <= 0) continue;

      final d = barData[i];
      final bullish = d[5] == 1;
      final color = bullish ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
      barBodyPaint.color = color.withOpacity(0.9);
      wickPaint.color = color.withOpacity(0.5);

      final bx = w * d[0];
      final bw = w * 0.048;
      final openY = h * d[1];
      final closeY = h * (d[1] + (d[2] - d[1]) * p);
      final highY = h * d[3];
      final lowY = h * d[4];

      canvas.drawLine(Offset(bx, highY), Offset(bx, lowY), wickPaint);

      final top = math.min(openY, closeY);
      final bot = math.max(openY, closeY);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(bx - bw / 2, top, bx + bw / 2, math.max(bot, top + 3)),
          const Radius.circular(3),
        ),
        barBodyPaint,
      );
    }

    // Rising trend line
    if (progress > 0.4) {
      final lp = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
      final linePaint = Paint()
        ..color = AppColors.primary.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      final path = Path()
        ..moveTo(w * 0.08, h * 0.78)
        ..lineTo(w * (0.08 + 0.78 * lp), h * (0.78 - 0.60 * lp));
      canvas.drawPath(path, linePaint);
    }

    // Return badge
    if (progress > 0.75) {
      final op = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);
      final bgP = Paint()
        ..color = const Color(0xFF22C55E).withOpacity(0.10 * op);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.60, h * 0.07, w * 0.32, h * 0.13),
          const Radius.circular(10),
        ),
        bgP,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '+18.45%',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF22C55E).withOpacity(op),
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(w * 0.62, h * 0.09));
    }
  }

  @override
  bool shouldRepaint(_CopyTradingPainter old) => old.progress != progress;
}

// ── Slide 2: Live Stream Visual ───────────────────────────────────────────────

class _LiveStreamVisual extends StatefulWidget {
  @override
  State<_LiveStreamVisual> createState() => _LiveStreamVisualState();
}

class _LiveStreamVisualState extends State<_LiveStreamVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080D1A),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _LiveStreamPainter(t: _controller.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _LiveStreamPainter extends CustomPainter {
  final double t;
  const _LiveStreamPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    for (int i = 0; i < 4; i++) {
      final phase = (t + i * 0.25) % 1.0;
      final radius = phase * math.min(w, h) * 0.46;
      final opacity = (1.0 - phase) * 0.18;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = AppColors.primary.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    const barCount = 36;
    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * math.pi;
      final wave = math.sin(angle * 3 + t * 2 * math.pi) * 0.5 + 0.5;
      final innerR = h * 0.13;
      final outerR = innerR + wave * h * 0.09 + 4;
      final x1 = cx + innerR * math.cos(angle);
      final y1 = cy + innerR * math.sin(angle);
      final x2 = cx + outerR * math.cos(angle);
      final y2 = cy + outerR * math.sin(angle);
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = AppColors.primary.withOpacity(0.25 + wave * 0.55)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      Offset(cx, cy),
      h * 0.12,
      Paint()..color = const Color(0xFF0D1526),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      h * 0.12,
      Paint()
        ..color = AppColors.primary.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.06, h * 0.07, w * 0.22, h * 0.08),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFEF4444),
    );

    TextPainter(
      text: const TextSpan(
        text: '  LIVE',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, Offset(w * 0.07, h * 0.082));

    TextPainter(
      text: TextSpan(
        text: '12.4K watching',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.45),
        ),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas, Offset(w * 0.06, h * 0.17));
  }

  @override
  bool shouldRepaint(_LiveStreamPainter old) => old.t != t;
}

// ── Slide 3: Earn Visual ──────────────────────────────────────────────────────

class _EarnVisual extends StatefulWidget {
  @override
  State<_EarnVisual> createState() => _EarnVisualState();
}

class _EarnVisualState extends State<_EarnVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F7F2),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => CustomPaint(
          painter: _EarnPainter(progress: _anim.value),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _EarnPainter extends CustomPainter {
  final double progress;
  const _EarnPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bars = [0.22, 0.35, 0.28, 0.50, 0.42, 0.65, 0.58, 0.88];
    final barW = w * 0.062;
    final baseY = h * 0.82;
    final maxH = h * 0.58;

    for (int i = 0; i < bars.length; i++) {
      final p = ((progress - i * 0.07) / 0.44).clamp(0.0, 1.0);
      if (p <= 0) continue;

      final bh = bars[i] * maxH * p;
      final xPos = w * 0.055 + i * (w * 0.117);
      final isHighlight = i == bars.length - 1;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(xPos, baseY - bh, barW, bh),
          const Radius.circular(5),
        ),
        Paint()
          ..color = isHighlight
              ? const Color(0xFF22C55E)
              : const Color(0xFF22C55E).withOpacity(0.20 + i * 0.09),
      );
    }

    canvas.drawLine(
      Offset(w * 0.04, baseY),
      Offset(w * 0.96, baseY),
      Paint()
        ..color = const Color(0xFF22C55E).withOpacity(0.15)
        ..strokeWidth = 1,
    );

    if (progress > 0.55) {
      final op = ((progress - 0.55) / 0.45).clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.22, h * 0.09, w * 0.56, h * 0.18),
          const Radius.circular(14),
        ),
        Paint()..color = const Color(0xFF22C55E).withOpacity(0.08 * op),
      );
      TextPainter(
        text: TextSpan(
          text: '\$85,230',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF22C55E).withOpacity(op),
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset(w * 0.28, h * 0.10));
      TextPainter(
        text: TextSpan(
          text: 'Total earnings this month',
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xFF22C55E).withOpacity(op * 0.55),
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset(w * 0.26, h * 0.215));
    }
  }

  @override
  bool shouldRepaint(_EarnPainter old) => old.progress != progress;
}

// ── Page Indicator ────────────────────────────────────────────────────────────

class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _PageIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 28 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
