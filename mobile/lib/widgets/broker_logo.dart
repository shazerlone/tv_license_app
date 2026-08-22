import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Shows a broker's logo from a CDN, falling back to a clean lettered tile
/// while loading or if the logo can't be fetched.
class BrokerLogo extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final double size;
  const BrokerLogo({super.key, required this.name, this.logoUrl, this.size = 46});

  @override
  Widget build(BuildContext context) {
    final fallback = _Fallback(name: name, size: size);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: AppColors.border),
      ),
      child: logoUrl == null
          ? fallback
          : Padding(
              padding: EdgeInsets.all(size * 0.16),
              child: Image.network(
                logoUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null ? child : fallback,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String name;
  final double size;
  const _Fallback({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withOpacity(0.1),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0] : '?',
        style: GoogleFonts.inter(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: AppColors.primary),
      ),
    );
  }
}
