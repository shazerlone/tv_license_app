import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Circular avatar that shows a network photo when available and falls back to
/// the person's initial. Used everywhere a trader/user face appears.
class Avatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  final Color? ringColor;
  final double ringWidth;

  const Avatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 44,
    this.ringColor,
    this.ringWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withOpacity(0.1),
        border: ringColor != null ? Border.all(color: ringColor!, width: ringWidth) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initial(letter),
              loadingBuilder: (_, child, progress) => progress == null ? child : _initial(letter),
            )
          : _initial(letter),
    );
  }

  Widget _initial(String letter) => Center(
        child: Text(
          letter,
          style: GoogleFonts.inter(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      );
}
