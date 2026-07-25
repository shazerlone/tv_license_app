import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/copy_models.dart';

/// Translucent live chat overlay (IG/YouTube-live style). Shows aggregated
/// messages from Millimore + connected platforms, with a compose bar.
class LiveChatFeed extends StatefulWidget {
  final List<LiveChatMessage> messages;
  final ValueChanged<String> onSend;
  const LiveChatFeed({super.key, required this.messages, required this.onSend});

  @override
  State<LiveChatFeed> createState() => _LiveChatFeedState();
}

class _LiveChatFeedState extends State<LiveChatFeed> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final t = _controller.text.trim();
    if (t.isEmpty) return;
    widget.onSend(t);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.messages;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black, Colors.black],
              stops: [0, 0.18, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 60, 6),
              reverse: true,
              itemCount: msgs.length,
              itemBuilder: (_, i) => _ChatRow(msg: msgs[msgs.length - 1 - i]),
            ),
          ),
        ),
        // Compose bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  style: GoogleFonts.inter(fontSize: 13.5, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Reply to your viewers…',
                    hintStyle: GoogleFonts.inter(fontSize: 13.5, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.35),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _send,
                child: Container(
                  width: 40, height: 40,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  final LiveChatMessage msg;
  const _ChatRow({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SourceDot(source: msg.source, byHost: msg.byHost),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${msg.author}  ',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: msg.byHost ? AppColors.primary : Colors.white.withOpacity(0.85),
                    ),
                  ),
                  TextSpan(text: msg.text, style: GoogleFonts.inter(fontSize: 13, color: Colors.white, height: 1.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceDot extends StatelessWidget {
  final ChatSource source;
  final bool byHost;
  const _SourceDot({required this.source, required this.byHost});

  @override
  Widget build(BuildContext context) {
    if (byHost) {
      return Container(
        margin: const EdgeInsets.only(top: 1),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
        child: Text('HOST', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
      );
    }
    late final IconData icon;
    late final Color color;
    switch (source) {
      case ChatSource.youtube:
        icon = Icons.smart_display_rounded;
        color = const Color(0xFFFF0000);
        break;
      case ChatSource.facebook:
        icon = Icons.facebook_rounded;
        color = const Color(0xFF1877F2);
        break;
      case ChatSource.millimore:
        icon = Icons.auto_graph_rounded;
        color = AppColors.primary;
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Icon(icon, size: 13, color: color),
    );
  }
}
