import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'follower_register_screen.dart';
import 'trader_register_screen.dart';

class AccountTypeScreen extends StatefulWidget {
  const AccountTypeScreen({super.key});

  @override
  State<AccountTypeScreen> createState() => _AccountTypeScreenState();
}

class _AccountTypeScreenState extends State<AccountTypeScreen>
    with TickerProviderStateMixin {
  int? _selected;
  late final AnimationController _entryController;
  late final List<AnimationController> _cardControllers;
  late final Animation<double> _entryFade;
  late final List<Animation<Offset>> _cardSlides;
  late final List<Animation<double>> _cardFades;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _cardControllers = List.generate(
      2,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _cardSlides = List.generate(
      2,
      (i) => Tween<Offset>(
        begin: Offset(0, 0.3 + i * 0.1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _cardControllers[i], curve: Curves.easeOutCubic),
      ),
    );
    _cardFades = List.generate(
      2,
      (i) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardControllers[i], curve: Curves.easeOut),
      ),
    );
    _entryController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardControllers[0].forward();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _cardControllers[1].forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    for (final c in _cardControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _proceed() {
    if (_selected == null) return;
    if (_selected == 0) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FollowerRegisterScreen()),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TraderRegisterScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _entryFade,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _entryFade,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How do you\nwant to use\nmillimore?',
                      style: GoogleFonts.inter(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.0,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose your path — you can always switch later.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              SlideTransition(
                position: _cardSlides[0],
                child: FadeTransition(
                  opacity: _cardFades[0],
                  child: _TypeCard(
                    index: 0,
                    selected: _selected == 0,
                    title: 'Follower',
                    subtitle: 'Discover top traders, copy their moves, and grow your portfolio with zero guesswork.',
                    chip: 'Join free',
                    chipColor: AppColors.green,
                    visual: const _FollowerVisual(),
                    onTap: () => setState(() => _selected = 0),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SlideTransition(
                position: _cardSlides[1],
                child: FadeTransition(
                  opacity: _cardFades[1],
                  child: _TypeCard(
                    index: 1,
                    selected: _selected == 1,
                    title: 'Trader / Creator',
                    subtitle: 'Stream live, share verified trades, and monetise your edge. Requires PnL verification.',
                    chip: 'Apply',
                    chipColor: AppColors.primary,
                    visual: const _TraderVisual(),
                    onTap: () => setState(() => _selected = 1),
                  ),
                ),
              ),
              const Spacer(),
              AnimatedOpacity(
                opacity: _selected != null ? 1.0 : 0.35,
                duration: const Duration(milliseconds: 200),
                child: ElevatedButton(
                  onPressed: _selected != null ? _proceed : null,
                  child: Text(_selected == 1 ? 'Start Application' : 'Continue'),
                ),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final int index;
  final bool selected;
  final String title;
  final String subtitle;
  final String chip;
  final Color chipColor;
  final Widget visual;
  final VoidCallback onTap;

  const _TypeCard({
    required this.index,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.chipColor,
    required this.visual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? chipColor.withOpacity(0.04) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: selected ? chipColor : AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: chipColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          chip,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: chipColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(width: 80, height: 80, child: visual),
          ],
        ),
      ),
    );
  }
}

class _FollowerVisual extends StatelessWidget {
  const _FollowerVisual();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _FollowerPainter());
}

class _FollowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(16)),
      Paint()..color = AppColors.green.withOpacity(0.08),
    );
    final linePaint = Paint()
      ..color = AppColors.green
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pts = [
      Offset(size.width * 0.1, size.height * 0.75),
      Offset(size.width * 0.3, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.45),
      Offset(size.width * 0.7, size.height * 0.35),
      Offset(size.width * 0.9, size.height * 0.2),
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      final cx = (pts[i - 1].dx + pts[i].dx) / 2;
      path.cubicTo(cx, pts[i - 1].dy, cx, pts[i].dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, linePaint);
    for (final p in pts) {
      canvas.drawCircle(p, 3, Paint()..color = AppColors.green);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: 'Copy',
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.green),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.1, size.height * 0.84));
  }
  @override
  bool shouldRepaint(_FollowerPainter old) => false;
}

class _TraderVisual extends StatelessWidget {
  const _TraderVisual();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _TraderMiniPainter());
}

class _TraderMiniPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(16)),
      Paint()..color = AppColors.primary.withOpacity(0.06),
    );
    final rng = math.Random(7);
    const count = 5;
    final candleW = (size.width * 0.8) / count;
    for (int i = 0; i < count; i++) {
      final x = size.width * 0.1 + candleW * i + candleW / 2;
      final bull = rng.nextBool();
      final color = bull ? AppColors.green : AppColors.red;
      final top = size.height * (0.2 + rng.nextDouble() * 0.3);
      final bot = size.height * (0.55 + rng.nextDouble() * 0.25);
      final bodyH = (bot - top).abs().clamp(4.0, double.infinity);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - candleW * 0.3, top, candleW * 0.6, bodyH),
          const Radius.circular(2),
        ),
        Paint()..color = color.withOpacity(0.9),
      );
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '● LIVE',
        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.red),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width * 0.1, size.height * 0.05));
  }
  @override
  bool shouldRepaint(_TraderMiniPainter old) => false;
}
