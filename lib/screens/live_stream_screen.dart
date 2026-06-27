import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/trader.dart';
import '../models/trade.dart';
import '../state/app_state.dart';
import '../widgets/verified_badge.dart';
import 'copy_trading_screen.dart';

class LiveStreamScreen extends StatefulWidget {
  final Trader? trader;
  const LiveStreamScreen({super.key, this.trader});

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> with SingleTickerProviderStateMixin {
  final _chatController = TextEditingController();
  late final AnimationController _anim;
  late final int _viewers;

  final List<_Msg> _messages = [
    _Msg('alex_t', 'great setup on EURUSD!'),
    _Msg('jade_fx', 'following this one live'),
    _Msg('crypto_k', 'what is your SL here?'),
    _Msg('mark99', 'copied! 🔥'),
    _Msg('luna_t', 'clean analysis as always'),
  ];

  Trader get _trader => widget.trader ?? mockTraders[0];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _viewers = 800 + math.Random().nextInt(11000);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _send() {
    final t = _chatController.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_Msg('you', t));
      _chatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trader = _trader;
    final store = AppStateScope.of(context);
    final subscribed = store.isSubscribed(trader.id);
    final liveTrade = mockTrades.firstWhere(
      (t) => t.traderId == trader.id && t.status == TradeStatus.open,
      orElse: () => mockTrades.first,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // "Stream" — animated chart
          AnimatedBuilder(animation: _anim, builder: (_, __) => CustomPaint(painter: _StreamPainter(progress: _anim.value))),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.55), Colors.transparent, Colors.black.withOpacity(0.85)],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.15), border: Border.all(color: Colors.white, width: 1.5)),
                        child: Center(child: Text(trader.name[0], style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white))),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(children: [
                              Flexible(child: Text(trader.name, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
                              if (trader.isVerified) ...[const SizedBox(width: 4), const VerifiedBadge(size: 13)],
                            ]),
                            Text('@${trader.username}', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white70)),
                          ],
                        ),
                      ),
                      if (!subscribed)
                        GestureDetector(
                          onTap: () => store.subscribe(trader.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                            child: Text('Subscribe', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0B1120))),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // LIVE + viewers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)),
                        child: Text('LIVE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(6)),
                        child: Row(children: [
                          const Icon(Icons.remove_red_eye_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(_fmt(_viewers), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        ]),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Live trade overlay
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _LiveTradeCard(trade: liveTrade),
                ),
                const SizedBox(height: 12),
                // Chat
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _ChatLine(msg: _messages[i]),
                  ),
                ),
                // Input row
                Padding(
                  padding: EdgeInsets.fromLTRB(12, 6, 12, 8 + MediaQuery.of(context).viewInsets.bottom * 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatController,
                          onSubmitted: (_) => _send(),
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Say something...',
                            hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CopyTradingScreen(trader: trader))),
                        child: Container(
                          height: 44, padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24)),
                          child: Row(children: [
                            const Icon(Icons.copy_all_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Copy', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';
}

class _LiveTradeCard extends StatelessWidget {
  final Trade trade;
  const _LiveTradeCard({required this.trade});

  @override
  Widget build(BuildContext context) {
    final profit = trade.isProfit;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)),
            child: Text('LIVE TRADE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 12),
          Text(trade.pair, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: (trade.direction == TradeDirection.buy ? AppColors.green : AppColors.red).withOpacity(0.25), borderRadius: BorderRadius.circular(6)),
            child: Text(trade.directionLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: trade.direction == TradeDirection.buy ? AppColors.green : AppColors.red)),
          ),
          const Spacer(),
          Text(trade.formattedPnl, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: profit ? AppColors.green : AppColors.red)),
        ],
      ),
    );
  }
}

class _ChatLine extends StatelessWidget {
  final _Msg msg;
  const _ChatLine({required this.msg});

  @override
  Widget build(BuildContext context) {
    final me = msg.user == 'you';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '${msg.user}  ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: me ? AppColors.primary : Colors.white.withOpacity(0.85))),
            TextSpan(text: msg.text, style: GoogleFonts.inter(fontSize: 13, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _Msg {
  final String user;
  final String text;
  _Msg(this.user, this.text);
}

class _StreamPainter extends CustomPainter {
  final double progress;
  _StreamPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF0B1120));
    final grid = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 1;
    for (int i = 1; i < 12; i++) {
      final y = size.height * i / 12;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final rng = math.Random(3);
    const n = 22;
    final w = size.width / n;
    double price = size.height * 0.5;
    for (int i = 0; i < n; i++) {
      final x = w * i + w / 2;
      final open = price;
      price = (price + (rng.nextDouble() - 0.5) * size.height * 0.05).clamp(size.height * 0.3, size.height * 0.7);
      final bull = price <= open;
      final c = bull ? AppColors.green : AppColors.red;
      final top = math.min(open, price);
      final h = (open - price).abs().clamp(2.0, double.infinity);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - w * 0.3, top, w * 0.6, h), const Radius.circular(2)), Paint()..color = c.withOpacity(0.4));
    }
    // moving price dot
    final px = size.width * progress;
    canvas.drawCircle(Offset(px, size.height * 0.45), 4, Paint()..color = AppColors.primary);
  }

  @override
  bool shouldRepaint(_StreamPainter old) => old.progress != progress;
}
