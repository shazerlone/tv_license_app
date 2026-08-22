import 'package:flutter/material.dart';

/// A full-screen, pinch-to-zoom image viewer with a close button — the standard
/// social-media photo experience. Loads the image at full uploaded quality.
class FullScreenImage extends StatelessWidget {
  final String url;
  const FullScreenImage({super.key, required this.url});

  static void open(BuildContext context, String url) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => FullScreenImage(url: url),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Tap the backdrop to dismiss.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 44, height: 44,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
          ),
          // Close button.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Material(
              color: Colors.black.withOpacity(0.4),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
