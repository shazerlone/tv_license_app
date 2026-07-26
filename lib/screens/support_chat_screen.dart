import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Live chat support. A lightweight in-app help desk: quick-reply topics,
/// message bubbles and a simulated agent that responds. Wire the send handler
/// to the backend support channel when it lands.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportMsg {
  final String text;
  final bool fromUser;
  final DateTime at;
  _SupportMsg(this.text, this.fromUser) : at = DateTime.now();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_SupportMsg> _messages = [];
  bool _agentTyping = false;
  bool _showQuickReplies = true;

  final _quickReplies = const [
    'How do I connect my broker?',
    'Copy trading isn\'t working',
    'Payout & earnings',
    'Verify my creator account',
    'Report a problem',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_SupportMsg(
        'Hi 👋 You\'re chatting with Millimore Support. How can we help today?', false));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _send(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_SupportMsg(t, true));
      _controller.clear();
      _showQuickReplies = false;
      _agentTyping = true;
    });
    _scrollToBottom();
    Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      setState(() {
        _agentTyping = false;
        _messages.add(_SupportMsg(_replyFor(t), false));
      });
      _scrollToBottom();
    });
  }

  String _replyFor(String q) {
    final l = q.toLowerCase();
    if (l.contains('broker') || l.contains('connect') || l.contains('account')) {
      return 'To connect a broker, go to Profile → Accounts → Add account, pick your broker (XM, Exness, Vantage…) and enter your login server. We only ever use the investor (read-only) password.';
    }
    if (l.contains('copy')) {
      return 'Copy trading needs an active connected account with sufficient balance. Open Trades → check the account is "Connected" and copy size is set above the minimum. Want me to check your account status?';
    }
    if (l.contains('payout') || l.contains('earning') || l.contains('withdraw')) {
      return 'Creator earnings settle monthly and appear under Studio → Earnings. Payouts go to your linked method once you pass the minimum threshold.';
    }
    if (l.contains('verify') || l.contains('creator')) {
      return 'Creator verification reviews your live trading statement and usually completes in 24–48h. You can track it from the banner on your Home tab.';
    }
    return 'Thanks — a support specialist will pick this up shortly. Meanwhile, is there anything else I can help with? You can also email support@millimore.app.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 11, height: 11,
                    decoration: BoxDecoration(color: AppColors.green, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 2)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Millimore Support', style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(_agentTyping ? 'typing…' : 'Typically replies in a few minutes',
                    style: GoogleFonts.inter(fontSize: 11.5, color: _agentTyping ? AppColors.primary : AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_agentTyping ? 1 : 0),
              itemBuilder: (context, i) {
                if (_agentTyping && i == _messages.length) return const _TypingBubble();
                return _Bubble(msg: _messages[i]);
              },
            ),
          ),
          if (_showQuickReplies)
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickReplies.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _send(_quickReplies[i]),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Text(_quickReplies[i], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ),
              ),
            ),
          _Composer(controller: _controller, onSend: () => _send(_controller.text)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _SupportMsg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final user = msg.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: user ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
          border: user ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          msg.text,
          style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: user ? Colors.white : AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4), bottomRight: Radius.circular(16)),
          border: Border.all(color: AppColors.border),
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_c.value - i * 0.2) % 1.0;
              final o = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
              return Padding(
                padding: EdgeInsets.only(right: i < 2 ? 5 : 0),
                child: Container(width: 7, height: 7, decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(o.clamp(0.0, 1.0)), shape: BoxShape.circle)),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                minLines: 1,
                maxLines: 4,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Message support…',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
