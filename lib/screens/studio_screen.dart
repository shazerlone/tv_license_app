import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/session.dart';
import 'go_live_screen.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final pending = session.user?.creatorStatus == CreatorStatus.pending;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Studio', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.6)),
            const SizedBox(height: 4),
            Text('Create, broadcast and manage your trading.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
            const SizedBox(height: 24),

            if (pending) _LockedBanner(),
            if (pending) const SizedBox(height: 20),

            // Primary actions
            Row(
              children: [
                Expanded(child: _BigAction(icon: Icons.podcasts_rounded, title: 'Go Live', sub: 'Stream to followers', color: AppColors.red, locked: pending, onTap: () {
                  if (pending) { _action(context, 'Go Live'); return; }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GoLiveScreen()));
                })),
                const SizedBox(width: 12),
                Expanded(child: _BigAction(icon: Icons.add_chart_rounded, title: 'Post Trade', sub: 'Share a setup', color: AppColors.primary, locked: pending, onTap: () => _action(context, 'Post Trade'))),
              ],
            ),
            const SizedBox(height: 20),

            Text('Manage', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            _Row(icon: Icons.link_rounded, title: 'Connected accounts', sub: session.user?.platform ?? 'Add a trading account', onTap: () => _action(context, 'Accounts')),
            _Row(icon: Icons.bar_chart_rounded, title: 'Earnings & payouts', sub: 'Track your revenue', onTap: () => _action(context, 'Earnings')),
            _Row(icon: Icons.groups_rounded, title: 'Followers', sub: 'See who copies you', onTap: () => _action(context, 'Followers')),
            _Row(icon: Icons.tune_rounded, title: 'Creator settings', sub: 'Fees, bio, visibility', onTap: () => _action(context, 'Settings'), last: true),
          ],
        ),
      ),
    );
  }

  void _action(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name — coming next')),
    );
  }
}

class _LockedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Going live and posting unlock once your account is verified (24–48h).',
                style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final bool locked;
  final VoidCallback onTap;
  const _BigAction({required this.icon, required this.title, required this.sub, required this.color, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 14),
              Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(sub, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool last;
  const _Row({required this.icon, required this.title, required this.sub, required this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    Text(sub, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
