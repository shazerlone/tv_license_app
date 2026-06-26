import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class MillimoreLogo extends StatelessWidget {
  final double size;
  const MillimoreLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'millimore',
          style: GoogleFonts.inter(
            fontSize: size,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -1.0,
            height: 1.0,
          ),
        ),
        Positioned(
          top: -size * 0.22,
          left: size * 1.08,
          child: Text(
            '✶',
            style: TextStyle(
              fontSize: size * 0.34,
              color: AppColors.primary,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}
