import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../state/app_state.dart';

/// A real, working comments thread. Reads & writes through [AppState].
class CommentsSheet extends StatefulWidget {
  final Post post;
  const CommentsSheet({super.key, required this.post});

  static Future<void> open(BuildContext context, Post post) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(post: post),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(AppState store) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    store.addComment(widget.post, text);
    _controller.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final comments = store.commentsFor(widget.post);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  child: Row(
                    children: [
                      Text('${comments.length} comments',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close_rounded, size: 22, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: comments.isEmpty
                      ? Center(
                          child: Text('Be the first to comment',
                              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: comments.length,
                          itemBuilder: (_, i) => _CommentRow(comment: comments[i]),
                        ),
                ),
                _Composer(controller: _controller, focus: _focus, onSend: () => _send(store)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  final Comment comment;
  const _CommentRow({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (comment.byMe ? AppColors.green : AppColors.primary).withOpacity(0.1),
            ),
            child: Center(
              child: Text(comment.author[0],
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: comment.byMe ? AppColors.green : AppColors.primary)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.author, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    Text('@${comment.username} · ${comment.timeAgo}',
                        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(comment.text, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary, height: 1.45)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.favorite_border_rounded, size: 15, color: AppColors.textMuted),
                    const SizedBox(width: 16),
                    Text('Reply', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.focus, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.primary)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
