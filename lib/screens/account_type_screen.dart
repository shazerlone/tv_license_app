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
  Widget build(BuildContext context) {
    return _IconTile(
      color: AppColors.green,
      icon: Icons.auto_graph_rounded,
      badgeIcon: Icons.copy_all_rounded,
    );
  }
}

class _TraderVisual extends StatelessWidget {
  const _TraderVisual();
  @override
  Widget build(BuildContext context) {
    return _IconTile(
      color: AppColors.primary,
      icon: Icons.sensors_rounded,
      badgeIcon: Icons.verified_rounded,
    );
  }
}

class _IconTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final IconData badgeIcon;
  const _IconTile({required this.color, required this.icon, required this.badgeIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Center(child: Icon(icon, size: 34, color: color)),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(badgeIcon, size: 11, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
