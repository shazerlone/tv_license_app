import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A floating hearts reaction layer (TikTok/IG-live style). Call
/// [LiveReactionsController.burst] to spawn hearts. Put the [LiveReactions]
/// widget high in a Stack so hearts float over the video.
class LiveReactionsController extends ChangeNotifier {
  final List<int> _hearts = [];
  List<int> get hearts => _hearts;
  int _seq = 0;

  void burst([int count = 1]) {
    for (int i = 0; i < count; i++) {
      _hearts.add(_seq++);
    }
    notifyListeners();
  }

  void remove(int id) {
    _hearts.remove(id);
    notifyListeners();
  }
}

class LiveReactions extends StatelessWidget {
  final LiveReactionsController controller;
  const LiveReactions({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Stack(
          children: controller.hearts
              .map((id) => _Heart(key: ValueKey(id), onDone: () => controller.remove(id)))
              .toList(),
        );
      },
    );
  }
}

class _Heart extends StatefulWidget {
  final VoidCallback onDone;
  const _Heart({super.key, required this.onDone});

  @override
  State<_Heart> createState() => _HeartState();
}

class _HeartState extends State<_Heart> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final double _startX;
  late final double _wobble;
  late final double _size;
  late final Color _color;

  static final _rng = math.Random();
  static const _palette = [AppColors.red, AppColors.primary, AppColors.green, Color(0xFFF59E0B)];

  @override
  void initState() {
    super.initState();
    _startX = 8 + _rng.nextDouble() * 30; // from right edge inward
    _wobble = 20 + _rng.nextDouble() * 40;
    _size = 22 + _rng.nextDouble() * 16;
    _color = _palette[_rng.nextInt(_palette.length)];
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: 2200 + _rng.nextInt(900)))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final rise = 60 + t * 320;
        final sway = math.sin(t * math.pi * 2) * _wobble;
        final opacity = t < 0.15 ? t / 0.15 : (1 - (t - 0.15) / 0.85).clamp(0.0, 1.0);
        return Positioned(
          right: _startX + sway,
          bottom: 120 + rise,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: 0.6 + t * 0.6,
              child: Icon(Icons.favorite_rounded, size: _size, color: _color),
            ),
          ),
        );
      },
    );
  }
}
