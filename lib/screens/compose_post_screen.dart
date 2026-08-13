import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../models/post.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';
import 'trader_profile_screen.dart';

/// Creator composer — publish a trade idea / analysis / lesson (POST /posts).
class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({super.key});

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  String _type = 'analysis'; // trade|analysis|lesson|update
  final _content = TextEditingController();
  final _pair = TextEditingController();
  final _title = TextEditingController();
  final List<TextEditingController> _points = [TextEditingController()];
  bool _posting = false;

  static const _types = [
    ('analysis', 'Analysis', Icons.insights_rounded),
    ('trade', 'Trade', Icons.candlestick_chart_rounded),
    ('lesson', 'Lesson', Icons.school_rounded),
    ('update', 'Update', Icons.campaign_rounded),
  ];

  @override
  void dispose() {
    _content.dispose();
    _pair.dispose();
    _title.dispose();
    for (final c in _points) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _publish() async {
    final content = _content.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Write something to share')));
      return;
    }
    final points = _points.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    setState(() => _posting = true);

    if (kUseBackend) {
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final api = await BackendApi.createPost(
          type: _type,
          content: content,
          pair: _pair.text.trim().isEmpty ? null : _pair.text.trim(),
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          points: points.isEmpty ? null : points,
        );
        final post = Post.fromApi(api);
        // Remember the creator's own trader id so "My posts" works later.
        SharedPreferences.getInstance()
            .then((p) => p.setString('creator_trader_id', post.trader.id))
            .catchError((_) {});
        if (!mounted) return;
        // Close the composer (caller refreshes) and open the creator's own
        // profile so the new post is immediately visible + manageable.
        nav.pop(true);
        nav.push(MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: post.trader, isOwner: true)));
        messenger.showSnackBar(const SnackBar(content: Text('Posted 🎉')));
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() => _posting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
        return;
      }
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final showPair = _type == 'trade' || _type == 'analysis';
    final showLesson = _type == 'lesson';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('New post', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _posting ? null : _publish,
              child: _posting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Post', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // Type selector
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _types[i];
                final active = _type == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _type = t.$1),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? AppColors.primary : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(t.$3, size: 16, color: active ? Colors.white : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(t.$2, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          if (showLesson) ...[
            TextField(
              controller: _title,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Lesson title', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
            ),
            const Divider(),
          ],
          if (showPair) ...[
            TextField(
              controller: _pair,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Pair (e.g. XAU/USD)', prefixIcon: Icon(Icons.tag_rounded, size: 18)),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _content,
            maxLines: 8,
            minLines: 5,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary, height: 1.5),
            decoration: const InputDecoration(hintText: 'Share your analysis, setup or lesson…'),
          ),
          if (showLesson) ...[
            const SizedBox(height: 20),
            Text('Key points', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ..._points.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: e.value,
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                          decoration: const InputDecoration(hintText: 'Add a takeaway', isDense: true),
                        ),
                      ),
                    ],
                  ),
                )),
            TextButton.icon(
              onPressed: () => setState(() => _points.add(TextEditingController())),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add point'),
            ),
          ],
        ],
      ),
    );
  }
}
