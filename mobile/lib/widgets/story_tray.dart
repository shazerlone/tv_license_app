import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../models/story.dart';
import '../services/backend_api.dart';
import '../services/image_picker_service.dart';
import '../state/session.dart';
import '../screens/story_viewer_screen.dart';
import 'avatar.dart';

/// Horizontal story tray (rings). First item adds your own story; the rest are
/// authors you follow, own-first, unseen highlighted. Loads GET /stories.
class StoryTray extends StatefulWidget {
  const StoryTray({super.key});

  @override
  State<StoryTray> createState() => _StoryTrayState();
}

class _StoryTrayState extends State<StoryTray> {
  List<StoryGroup> _groups = const [];
  bool _loaded = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    if (kUseBackend) _load();
  }

  Future<void> _load() async {
    try {
      final raw = await BackendApi.stories();
      if (!mounted) return;
      setState(() {
        _groups = raw.map((e) => StoryGroup.fromJson(e)).toList();
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _addStory() async {
    if (_posting) return;
    try {
      final dataUrl = await ImagePickerService.pickImageAsDataUrl();
      if (dataUrl == null) return;
      setState(() => _posting = true);
      String url = dataUrl;
      if (dataUrl.startsWith('data:')) {
        final comma = dataUrl.indexOf(',');
        final contentType = dataUrl.substring(5, comma).split(';').first;
        final data = dataUrl.substring(comma + 1);
        url = await BackendApi.uploadMedia(contentType: contentType, data: data, kind: 'story');
      }
      await BackendApi.createStory(mediaUrl: url, mediaType: 'image');
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story posted')));
      _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not post the story')));
    }
  }

  void _open(int groupIndex) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StoryViewerScreen(groups: _groups, initialGroup: groupIndex)))
        .then((_) => _load()); // refresh seen-state on return
  }

  @override
  Widget build(BuildContext context) {
    if (!kUseBackend) return const SizedBox.shrink();
    final me = SessionScope.of(context).user;
    // Hide the whole tray until we know there's something (keeps home clean),
    // but always show the "add" bubble.
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _AddBubble(name: me?.name ?? 'You', photoUrl: me?.photoUrl, busy: _posting, onTap: _addStory),
          for (var i = 0; i < _groups.length; i++)
            _StoryBubble(group: _groups[i], onTap: () => _open(i)),
          if (!_loaded)
            for (var i = 0; i < 3; i++) const _SkeletonBubble(),
        ],
      ),
    );
  }
}

class _StoryBubble extends StatelessWidget {
  final StoryGroup group;
  final VoidCallback onTap;
  const _StoryBubble({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ring = group.hasUnseen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: ring ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFFA78BFA)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                border: ring ? null : Border.all(color: AppColors.border, width: 2),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.background),
                child: Avatar(name: group.name.isEmpty ? '?' : group.name, photoUrl: group.photoUrl, size: 54),
              ),
            ),
            const SizedBox(height: 4),
            Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _AddBubble extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool busy;
  final VoidCallback onTap;
  const _AddBubble({required this.name, this.photoUrl, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 6),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border, width: 2)),
                  child: busy
                      ? const SizedBox(width: 54, height: 54, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                      : Avatar(name: name.isEmpty ? '?' : name, photoUrl: photoUrl, size: 54),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 2)),
                    child: const Icon(Icons.add_rounded, size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Your story', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBubble extends StatelessWidget {
  const _SkeletonBubble();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 6),
      child: Column(children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface)),
        const SizedBox(height: 6),
        Container(width: 40, height: 8, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(4))),
      ]),
    );
  }
}
