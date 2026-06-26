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
  static const int _pageCount = 3;

  late final List<AnimationController> _textControllers;
  late final List<Animation<double>> _textFades;
  late final List<Animation<Offset>> _textSlides;

  @override
  void initState() {
    super.initState();
    _textControllers = List.generate(
      _pageCount,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 650),
      ),
    );
    _textFades = _textControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut))
        .toList();
    _textSlides = _textControllers
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();
    _textControllers[0].forward();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _textControllers[index].forward(from: 0);
  }

  void _next() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
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

  @override
  void dispose() {
    for (final c in _textControllers) {
      c.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  static const List<_SlideData> _slides = [
    _SlideData(
      label: 'COPY TRADING',
      headline: 'Follow traders\nwho actually win.',
      body:
          'Every position is verified straight from MT5 — no screenshots, no edits. Mirror a pro with a single tap and trade exactly as they do.',
    ),
    _SlideData(
      label: 'LIVE STREAMS',
      headline: 'Watch the move\nas it happens.',
      body:
          'Top traders stream their charts in real time. See the setup, hear the reasoning, and copy the entry before the candle closes.',
    ),
    _SlideData(
      label: 'CREATOR ECONOMY',
      headline: 'Turn your edge\ninto income.',
      body:
          'Connect your broker, publish a verified track record, and earn from every follower who copies your trades. Skill pays.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with brand mark + Skip, fixed height for stable layout.
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MiniWordmark(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _currentPage < _pageCount - 1 ? 1 : 0,
                      child: TextButton(
                        onPressed:
                            _currentPage < _pageCount - 1 ? _finish : null,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pageCount,
                itemBuilder: (_, i) => _OnboardingPage(
                  data: _slides[i],
                  index: i,
                  fade: _textFades[i],
                  slide: _textSlides[i],
                ),
              ),
            ),
            // Footer: indicator + primary action, consistent 24px gutters.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  _PageIndicator(count: _pageCount, current: _currentPage),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _currentPage == _pageCount - 1
                          ? 'Get Started'
                          : 'Continue',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  final String label;
  final String headline;
  final String body;
  const _SlideData({
    required this.label,
    required this.headline,
    required this.body,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _SlideData data;
  final int index;
  final Animation<double> fade;
  final Animation<Offset> slide;

  const _OnboardingPage({
    required this.data,
    required this.index,
    required this.fade,
    required this.slide,
  });

  Widget _buildVisual() {
    switch (index) {
      case 0:
        return const _CopyTradingVisual();
      case 1:
        return const _LiveStreamVisual();
      default:
        return const _EarnVisual();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Visual hero card takes the upper region.
          Expanded(
            flex: 55,
            child: _buildVisual(),
          ),
          const SizedBox(height: 32),
          // Text block takes the lower region, top-aligned.
          Expanded(
            flex: 45,
            child: FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: slide,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data.headline,
                      style: GoogleFonts.inter(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.0,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data.body,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══ Hero card wrapper ══════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  final Color background;
  final Color borderColor;
  final Widget child;
  const _HeroCard({
    required this.background,
    required this.borderColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: child,
      ),
    );
  }
}

// ══ Slide 1 — Copy trading candlestick chart ═════════════════════════

class _CopyTradingVisual extends StatefulWidget {
  const _CopyTradingVisual();
  @override
  State<_CopyTradingVisual> createState() => _CopyTradingVisualState();
}

class _CopyTradingVisualState extends State<_CopyTradingVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HeroCard(
      background: const Color(0xFFFBFCFE),
      borderColor: AppColors.border,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _a,
              builder: (_, __) => CustomPaint(
                painter: _CandlePainter(
                  progress: _a.value,
                  candles: _upTrend,
                  bullColor: AppColors.green,
                  bearColor: AppColors.red,
                  lineColor: AppColors.primary,
                  gridColor: AppColors.border.withOpacity(0.7),
                  dark: false,
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: _Pill(
              text: 'EUR/USD',
              textColor: AppColors.textSecondary,
              bg: Colors.white,
              border: AppColors.border,
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: _Pill(
              text: '+24.3%',
              textColor: AppColors.green,
              bg: AppColors.green.withOpacity(0.10),
              border: Colors.transparent,
              bold: true,
            ),
          ),
          Positioned(
            left: 16,
            bottom: 16,
            child: _VerifiedRow(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ══ Slide 2 — Live stream (dark candles) ════════════════════════════

class _LiveStreamVisual extends StatefulWidget {
  const _LiveStreamVisual();
  @override
  State<_LiveStreamVisual> createState() => _LiveStreamVisualState();
}

class _LiveStreamVisualState extends State<_LiveStreamVisual>
    with TickerProviderStateMixin {
  late final AnimationController _draw;
  late final Animation<double> _drawA;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _drawA = CurvedAnimation(parent: _draw, curve: Curves.easeOutCubic);
    _draw.forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _draw.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HeroCard(
      background: const Color(0xFF0B1120),
      borderColor: const Color(0xFF1E293B),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _drawA,
              builder: (_, __) => CustomPaint(
                painter: _CandlePainter(
                  progress: _drawA.value,
                  candles: _liveTrend,
                  bullColor: const Color(0xFF34D399),
                  bearColor: const Color(0xFFF87171),
                  lineColor: AppColors.primaryLight,
                  gridColor: Colors.white.withOpacity(0.05),
                  dark: true,
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Row(
              children: [
                FadeTransition(
                  opacity: _pulse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 6,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '12.4K watching',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.25),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.15)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'M',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Marcus Sterling',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(Icons.verified_rounded,
                    size: 14, color: AppColors.primaryLight),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══ Slide 3 — Earnings bars ══════════════════════════════════════

class _EarnVisual extends StatefulWidget {
  const _EarnVisual();
  @override
  State<_EarnVisual> createState() => _EarnVisualState();
}

class _EarnVisualState extends State<_EarnVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _HeroCard(
      background: const Color(0xFFFBFCFE),
      borderColor: AppColors.border,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _a,
              builder: (_, __) => CustomPaint(
                painter: _BarPainter(progress: _a.value),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total earnings',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$85,230',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _Pill(
                        text: '+12.6%',
                        textColor: AppColors.green,
                        bg: AppColors.green.withOpacity(0.10),
                        border: Colors.transparent,
                        bold: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══ Shared small widgets ═════════════════════════════════════

class _Pill extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color bg;
  final Color border;
  final bool bold;
  const _Pill({
    required this.text,
    required this.textColor,
    required this.bg,
    required this.border,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _VerifiedRow extends StatelessWidget {
  final Color color;
  const _VerifiedRow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          'Verified on MT5',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MiniWordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'millimore',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.8,
          ),
        ),
        Positioned(
          top: -3,
          left: 23,
          child: CustomPaint(
            size: const Size(7, 7),
            painter: _StarPainter(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

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
          width: active ? 26 : 7,
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

// ══ Painters ══════════════════════════════════════════════

class _Candle {
  final double open, high, low, close;
  const _Candle(this.open, this.high, this.low, this.close);
}

const List<_Candle> _upTrend = [
  _Candle(40, 44, 38, 43),
  _Candle(43, 45, 41, 42),
  _Candle(42, 47, 41, 46),
  _Candle(46, 49, 44, 45),
  _Candle(45, 51, 44, 50),
  _Candle(50, 53, 48, 49),
  _Candle(49, 56, 48, 55),
  _Candle(55, 58, 53, 54),
  _Candle(54, 62, 53, 61),
  _Candle(61, 65, 59, 64),
  _Candle(64, 70, 62, 69),
];

const List<_Candle> _liveTrend = [
  _Candle(50, 54, 47, 48),
  _Candle(48, 50, 44, 49),
  _Candle(49, 55, 48, 54),
  _Candle(54, 57, 51, 52),
  _Candle(52, 58, 51, 57),
  _Candle(57, 60, 54, 55),
  _Candle(55, 63, 54, 62),
  _Candle(62, 66, 60, 61),
  _Candle(61, 68, 60, 67),
  _Candle(67, 71, 64, 70),
  _Candle(70, 76, 68, 75),
];

class _CandlePainter extends CustomPainter {
  final double progress;
  final List<_Candle> candles;
  final Color bullColor;
  final Color bearColor;
  final Color lineColor;
  final Color gridColor;
  final bool dark;

  const _CandlePainter({
    required this.progress,
    required this.candles,
    required this.bullColor,
    required this.bearColor,
    required this.lineColor,
    required this.gridColor,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const padL = 18.0;
    const padR = 18.0;
    final padT = h * 0.20;
    final padB = h * 0.16;
    final chartH = h - padT - padB;
    final chartW = w - padL - padR;

    double minP = candles.first.low, maxP = candles.first.high;
    for (final c in candles) {
      minP = math.min(minP, c.low);
      maxP = math.max(maxP, c.high);
    }
    final range = maxP - minP;
    double mapY(double p) => padT + chartH * (1 - (p - minP) / range);

    // Horizontal gridlines.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = padT + chartH * i / 3;
      canvas.drawLine(Offset(padL, y), Offset(w - padR, y), gridPaint);
    }

    final n = candles.length;
    final slot = chartW / n;
    final bodyW = slot * 0.46;

    final visible = progress * n;

    final bodyPaint = Paint()..style = PaintingStyle.fill;
    final wickPaint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final closePoints = <Offset>[];

    for (int i = 0; i < n; i++) {
      final reveal = (visible - i).clamp(0.0, 1.0);
      if (reveal <= 0) break;

      final c = candles[i];
      final cx = padL + slot * (i + 0.5);
      final bull = c.close >= c.open;
      final color = bull ? bullColor : bearColor;

      final highY = mapY(c.high);
      final lowY = mapY(c.low);
      final openY = mapY(c.open);
      final closeY = mapY(c.close);

      // Animate body growing from open toward close.
      final animClose = openY + (closeY - openY) * reveal;
      final animHigh = openY + (highY - openY) * reveal;
      final animLow = openY + (lowY - openY) * reveal;

      wickPaint.color = color.withOpacity(0.55 * reveal);
      canvas.drawLine(Offset(cx, animHigh), Offset(cx, animLow), wickPaint);

      bodyPaint.color = color.withOpacity(0.92 * reveal);
      final top = math.min(openY, animClose);
      final bot = math.max(openY, animClose);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - bodyW / 2, top, cx + bodyW / 2,
              math.max(bot, top + 2)),
          const Radius.circular(2.5),
        ),
        bodyPaint,
      );

      if (reveal >= 1.0) closePoints.add(Offset(cx, closeY));
    }

    // Smooth trend line through closes.
    if (closePoints.length >= 2) {
      final linePaint = Paint()
        ..color = lineColor.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(closePoints.first.dx, closePoints.first.dy);
      for (int i = 0; i < closePoints.length - 1; i++) {
        final p0 = closePoints[i];
        final p1 = closePoints[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
      }
      canvas.drawPath(path, linePaint);

      // Glow dot at the leading close.
      final last = closePoints.last;
      canvas.drawCircle(
          last, 7, Paint()..color = lineColor.withOpacity(0.18));
      canvas.drawCircle(last, 3.5, Paint()..color = lineColor);
      canvas.drawCircle(
          last,
          3.5,
          Paint()
            ..color = dark ? const Color(0xFF0B1120) : Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_CandlePainter old) => old.progress != progress;
}

class _BarPainter extends CustomPainter {
  final double progress;
  const _BarPainter({required this.progress});

  static const List<double> _bars = [
    0.30, 0.42, 0.36, 0.55, 0.48, 0.66, 0.60, 0.82, 0.95
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const padL = 18.0;
    const padR = 18.0;
    final baseY = h * 0.86;
    final maxH = h * 0.46;
    final n = _bars.length;
    final slot = (w - padL - padR) / n;
    final barW = slot * 0.5;

    // Baseline.
    canvas.drawLine(
      Offset(padL, baseY),
      Offset(w - padR, baseY),
      Paint()
        ..color = AppColors.green.withOpacity(0.18)
        ..strokeWidth = 1,
    );

    final visible = progress * n;
    for (int i = 0; i < n; i++) {
      final reveal = (visible - i).clamp(0.0, 1.0);
      if (reveal <= 0) break;
      final cx = padL + slot * (i + 0.5);
      final barH = _bars[i] * maxH * reveal;
      final highlight = i >= n - 2;
      final paint = Paint()
        ..color = highlight
            ? AppColors.green.withOpacity(0.95)
            : AppColors.green.withOpacity(0.22 + i * 0.05);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, baseY - barH, barW, barH),
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.progress != progress;
}

class _StarPainter extends CustomPainter {
  final Color color;
  const _StarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.width / 2;
    final inner = size.width * 0.15;
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final oa = (i * 90 - 90) * math.pi / 180;
      final ia = (i * 90 - 45) * math.pi / 180;
      final ox = cx + outer * math.cos(oa);
      final oy = cy + outer * math.sin(oa);
      final ix = cx + inner * math.cos(ia);
      final iy = cy + inner * math.sin(ia);
      if (i == 0) {
        path.moveTo(ox, oy);
      } else {
        path.lineTo(ox, oy);
      }
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}
