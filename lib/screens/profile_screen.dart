import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/session.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final user = session.user;
    final name = user?.name ?? 'Guest';
    final isCreator = user?.isCreator ?? false;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.1),
                    image: user?.photoUrl != null ? DecorationImage(image: NetworkImage(user!.photoUrl!), fit: BoxFit.cover) : null,
                  ),
                  child: user?.photoUrl == null
                      ? Center(child: Text(name.isNotEmpty ? name[0] : '?', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primary)))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isCreator ? AppColors.primary : AppColors.green).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isCreator ? 'Creator' : 'Follower',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: isCreator ? AppColors.primary : AppColors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (isCreator) ...[
              _Group(children: [
                _Tile(icon: Icons.verified_outlined, title: 'Creator status', trailing: _StatusChip(user?.creatorStatus)),
                _Tile(icon: Icons.link_rounded, title: 'Connected platform', trailing: Text(user?.platform ?? '—', style: _trailStyle())),
                _Tile(icon: Icons.public_rounded, title: 'Market', trailing: Text(user?.market ?? '—', style: _trailStyle()), last: true),
              ]),
              const SizedBox(height: 16),
            ],

            _Group(children: [
              _Tile(icon: Icons.person_outline_rounded, title: 'Edit profile'),
              _Tile(icon: Icons.notifications_none_rounded, title: 'Notifications'),
              _Tile(icon: Icons.shield_outlined, title: 'Privacy & security', last: true),
            ]),
            const SizedBox(height: 16),
            _Group(children: [
              _Tile(icon: Icons.help_outline_rounded, title: 'Help & support'),
              _Tile(icon: Icons.info_outline_rounded, title: 'About millimore', last: true),
            ]),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  session.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                },
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
                label: Text('Sign out', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.red)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.red.withOpacity(0.3)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _trailStyle() => GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary);
}

class _StatusChip extends StatelessWidget {
  final CreatorStatus? status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final approved = status == CreatorStatus.approved;
    final color = approved ? AppColors.green : AppColors.primary;
    final label = approved ? 'Approved' : 'In review';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final bool last;
  const _Tile({required this.icon, required this.title, this.trailing, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
