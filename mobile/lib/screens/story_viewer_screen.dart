import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../models/story.dart';
import '../services/backend_api.dart';
import '../widgets/avatar.dart';

/// Full-screen story viewer: swipe between authors, tap to advance, auto-play
/// with progress bars, marks each story viewed. Instagram/WhatsApp-style.
class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> groups;
  final int initialGroup;
  const StoryViewerScreen({super.key, required this.groups, this.initialGroup = 0});

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late final PageController _pager;
  late int _group;
  int _idx = 0; // story within the current group
  double _progress = 0;
  Timer? _timer;
  VideoPlayerController? _video;
  final Set<String> _seen = {};
  static const _imageDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    _pager = PageController(initialPage: _group);
    _start();
  }

  Story get _story => widget.groups[_group].stories[_idx];

  void _start() {
    _timer?.cancel();
    _video?.dispose();
    _video = null;
    _progress = 0;
    _markViewed();
    if (_story.isVideo) {
      final c = VideoPlayerController.networkUrl(Uri.parse(_story.mediaUrl));
      _video = c;
      c.initialize().then((_) {
        if (!mounted) return;
        c
          ..setLooping(false)
          ..play();
        setState(() {});
        _tick(c.value.duration == Duration.zero ? const Duration(seconds: 10) : c.value.duration);
      });
    } else {
      _tick(_imageDuration);
    }
    setState(() {});
  }

  void _tick(Duration total) {
    _timer?.cancel();
    final start = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      final elapsed = DateTime.now().difference(start).inMilliseconds / total.inMilliseconds;
      if (elapsed >= 1) {
        t.cancel();
        _next();
      } else {
        setState(() => _progress = elapsed.clamp(0, 1));
      }
    });
  }

  Future<void> _markViewed() async {
    if (_seen.contains(_story.id)) return;
    _seen.add(_story.id);
    BackendApi.viewStory(_story.id).catchError((_) {});
  }

  void _next() {
    final stories = widget.groups[_group].stories;
    if (_idx < stories.length - 1) {
      setState(() => _idx++);
      _start();
    } else if (_group < widget.groups.length - 1) {
      _pager.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_idx > 0) {
      setState(() => _idx--);
      _start();
    } else if (_group > 0) {
      _pager.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  void _onGroupChanged(int g) {
    setState(() {
      _group = g;
      _idx = 0;
    });
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _video?.dispose();
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pager,
        itemCount: widget.groups.length,
        onPageChanged: _onGroupChanged,
        itemBuilder: (_, g) => _buildGroup(widget.groups[g], isActive: g == _group),
      ),
    );
  }

  Widget _buildGroup(StoryGroup group, {required bool isActive}) {
    final story = isActive ? _story : group.stories.first;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Media
        Center(
          child: story.isVideo && _video != null && _video!.value.isInitialized && isActive
              ? AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!))
              : Image.network(
                  story.mediaUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, c, p) => p == null ? c : const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48)),
                ),
        ),
        // Tap zones: left = prev, right = next
        Row(children: [
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _prev)),
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _next)),
        ]),
        // Top gradient + progress + author
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 10, right: 10, bottom: 12),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.55), Colors.transparent])),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < group.stories.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: !isActive ? 0 : (i < _idx ? 1 : (i == _idx ? _progress : 0)),
                              minHeight: 2.5,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Avatar(name: group.name.isEmpty ? '?' : group.name, photoUrl: group.photoUrl, size: 34),
                    const SizedBox(width: 10),
                    Expanded(child: Text(group.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                    if (story.kind == 'recap')
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                        child: Text('LIVE RECAP', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3)),
                      ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, color: Colors.white, size: 24)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Caption
        if (story.caption != null && story.caption!.isNotEmpty)
          Positioned(
            left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(10)),
              child: Text(story.caption!, style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.3)),
            ),
          ),
      ],
    );
  }
}
