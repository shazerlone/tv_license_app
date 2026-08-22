import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// A shimmering placeholder block. Compose these to mirror a screen's real
/// layout while it loads — far more premium than a bare spinner.
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  /// A circular skeleton (avatars).
  const Skeleton.circle(double size, {super.key})
      : width = size,
        height = size,
        radius = size / 2;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.isDark ? const Color(0xFF1B2436) : const Color(0xFFEEF2F7);
    final hi = AppColors.isDark ? const Color(0xFF243044) : const Color(0xFFF8FAFC);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 - 2 * (1 - t), 0),
              end: Alignment(1 - 2 * (1 - t) + 2, 0),
              colors: [base, hi, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// A vertical list of card skeletons — the default loading state for feeds and
/// lists.
class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  const SkeletonList({super.key, this.count = 6, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12)});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Skeleton.circle(44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Skeleton(width: 140, height: 13),
                  SizedBox(height: 10),
                  Skeleton(width: 90, height: 11),
                ],
              ),
            ),
            const Skeleton(width: 54, height: 30, radius: 8),
          ],
        ),
      ),
    );
  }
}

/// A quiet, centred branded loader for short waits where a skeleton doesn't fit
/// (dialogs, small regions).
class AppLoader extends StatelessWidget {
  final double size;
  const AppLoader({super.key, this.size = 26});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary),
      ),
    );
  }
}

/// A polished empty state: soft icon medallion, title, subtitle, optional CTA.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.10), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textMuted, height: 1.5)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 24)),
                child: Text(actionLabel!, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
