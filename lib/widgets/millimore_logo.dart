import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class MillimoreLogo extends StatelessWidget {
  final double size;
  const MillimoreLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final starSize = size * 0.36;
    return SizedBox(
      height: size + starSize * 0.6,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomLeft,
        children: [
          Padding(
            padding: EdgeInsets.only(top: starSize * 0.6),
            child: Text(
              'millimore',
              style: GoogleFonts.inter(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -1.0,
                height: 1.0,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: size * 1.15,
            child: CustomPaint(
              size: Size(starSize, starSize),
              painter: FourPointStarPainter(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class FourPointStarPainter extends CustomPainter {
  final Color color;
  const FourPointStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = size.width / 2;
    final inner = size.width * 0.15;

    final path = Path();
    for (int i = 0; i < 4; i++) {
      final outerAngle = (i * 90 - 90) * math.pi / 180;
      final innerAngle = (i * 90 - 45) * math.pi / 180;
      final ox = cx + outer * math.cos(outerAngle);
      final oy = cy + outer * math.sin(outerAngle);
      final ix = cx + inner * math.cos(innerAngle);
      final iy = cy + inner * math.sin(innerAngle);
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
  bool shouldRepaint(FourPointStarPainter old) => old.color != color;
}
