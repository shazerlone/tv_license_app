import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../services/backend_api.dart';
import '../services/realtime_service.dart';
import '../services/whep_player.dart';
import '../models/trader.dart';
import '../models/trade.dart';
import '../models/copy_models.dart';
import '../state/app_state.dart';
import '../state/session.dart';
import '../widgets/verified_badge.dart';
import '../widgets/add_account_sheet.dart';
import '../widgets/live_reactions.dart';
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
  int _viewers = 0; // real viewer count from the broadcast

  final List<_Msg> _messages = []; // real chat; demo-seeded only when !kUseBackend

  Trader get _trader => widget.trader ?? mockTraders[0];

  AppState? _store;
  String? _myUsername; // to suppress the echo of our own chat messages
  final _reactions = LiveReactionsController();
  Timer? _heartTimer;
  String? _broadcastId;
  StreamSubscription? _bcSub;

  // Real playback: WebRTC/WHEP preferred (sub-second), HLS fallback.
  WhepPlayer? _whep;
  bool _whepReady = false;
  VideoPlayerController? _video;
  bool _videoReady = false;
  bool _resolving = true; // connecting to the stream
  bool _videoFailed = false; // no live broadcast / init failed (backend mode)
  bool _cancelled = false; // widget disposed mid-connect

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    if (kUseBackend) {
      _initVideo();
    } else {
      // Demo mode only: seed sample chat + ambient hearts.
      _resolving = false;
      _messages.addAll([
        _Msg('alex_t', 'great setup on EURUSD!'),
        _Msg('jade_fx', 'following this one live'),
        _Msg('mark99', 'copied! 🔥'),
      ]);
      _viewers = 800 + math.Random().nextInt(4000);
      _heartTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
        if (mounted) _reactions.burst(1 + math.Random().nextInt(2));
      });
    }
  }

  /// Resolves the trader's live broadcast and plays its HLS URL. HLS ingest lags
  /// RTMP and can 404 for a few seconds right after going live, so we retry a
  /// few times with backoff before giving up.
  /// Defensive fix for a malformed Cloudflare HLS URL (doubled `customer-`
  /// prefix / doubled `.cloudflarestream.com` domain). Harmless when correct.
  String? _normalizeHls(String? u) {
    if (u == null) return null;
    return u
        .replaceAll('customer-customer-', 'customer-')
        .replaceAll('.cloudflarestream.com.cloudflarestream.com', '.cloudflarestream.com');
  }

  Future<void> _initVideo() async {
    final trader = widget.trader;
    if (trader == null) {
      if (mounted) setState(() { _resolving = false; _videoFailed = true; });
      return;
    }
    // Retry across ~30s: the input takes a moment to go live after go-live.
    for (var attempt = 0; attempt < 5 && !_cancelled; attempt++) {
      try {
        final b = await BackendApi.liveBroadcastForTrader(trader.id);
        if (b != null) {
          final id = b['id']?.toString();
          if (id != null && _broadcastId == null) {
            _broadcastId = id;
            _subscribeBroadcast(id);
            _loadChat(id);
          }
          if (b['viewers'] is num && mounted) setState(() => _viewers = (b['viewers'] as num).toInt());

          // 1) Preferred: WebRTC/WHEP — sub-second and reliable at go-live.
          final whep = b['whepUrl']?.toString();
          if (whep != null && whep.isNotEmpty) {
            if (await _tryWhep(whep)) return;
          }

          // 2) Fallback: HLS (higher latency; can 404 briefly after go-live).
          final hls = _normalizeHls(b['hlsUrl']?.toString());
          if (hls != null && hls.isNotEmpty) {
            if (await _tryHls(hls)) return;
          }
        }
      } catch (_) {/* retry */}
      await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
    }
    if (mounted && !_cancelled) setState(() { _resolving = false; _videoFailed = true; });
  }

  /// Connect over WebRTC/WHEP. Returns true once media is flowing.
  Future<bool> _tryWhep(String whepUrl) async {
    final player = WhepPlayer();
    final connected = Completer<bool>();
    player.onConnected = () { if (!connected.isCompleted) connected.complete(true); };
    player.onFailed = () { if (!connected.isCompleted) connected.complete(false); };
    try {
      await player.play(whepUrl);
    } catch (_) {
      await player.dispose();
      return false;
    }
    // Wait briefly for the first frame to arrive.
    final ok = await connected.future.timeout(const Duration(seconds: 6), onTimeout: () => false);
    if (!ok || _cancelled || !mounted) {
      await player.dispose();
      return false;
    }
    setState(() { _whep = player; _whepReady = true; _resolving = false; _videoFailed = false; });
    return true;
  }

  /// Play the HLS manifest. Returns true once initialized.
  Future<bool> _tryHls(String hls) async {
    final c = VideoPlayerController.networkUrl(Uri.parse(hls));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      return false;
    }
    c
      ..setLooping(false)
      ..play();
    if (!mounted || _cancelled) { await c.dispose(); return false; }
    setState(() { _video = c; _videoReady = true; _resolving = false; _videoFailed = false; });
    return true;
  }

  /// Subscribe to the broadcast room for real chat / viewers / reactions.
  void _subscribeBroadcast(String id) {
    RealtimeService.current?.subscribeBroadcast(id);
    _bcSub = RealtimeService.current?.broadcastEvents.listen((m) {
      if (m['ch'] != 'broadcast:$id' || !mounted) return;
      final type = m['type']?.toString() ?? '';
      final d = (m['data'] is Map) ? (m['data'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
      switch (type) {
        case 'chat':
          final author = (d['author'] ?? '').toString();
          // Our own message was already shown optimistically as "you" — skip the echo.
          if (_myUsername != null && author == _myUsername) break;
          setState(() => _messages.add(_Msg(author, (d['text'] ?? '').toString(), isHost: author == _trader.username)));
          break;
        case 'viewers':
          if (d['count'] is num) setState(() => _viewers = (d['count'] as num).toInt());
          break;
        case 'reaction':
          _reactions.burst(1 + math.Random().nextInt(2));
          break;
      }
    });
  }

  Future<void> _loadChat(String id) async {
    try {
      final rows = await BackendApi.broadcastChat(id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(rows.map((r) {
            final a = (r['author'] ?? '').toString();
            return _Msg(a, (r['text'] ?? '').toString(), isHost: a == _trader.username);
          }));
      });
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store == null) {
      _store = AppStateScope.of(context);
      _store!.startPriceFeed();
    }
    _myUsername ??= SessionScope.of(context).user?.name;
  }

  @override
  void dispose() {
    _chatController.dispose();
    _anim.dispose();
    _heartTimer?.cancel();
    _reactions.dispose();
    _bcSub?.cancel();
    final id = _broadcastId;
    if (id != null) RealtimeService.current?.unsubscribeBroadcast(id);
    _cancelled = true;
    _whep?.dispose();
    _video?.dispose();
    _store?.stopPriceFeed();
    super.dispose();
  }

  void _send() {
    final t = _chatController.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add(_Msg('you', t));
      _chatController.clear();
    });
    // Post to the real broadcast room (echo appears via the WS for others).
    final id = _broadcastId;
    if (kUseBackend && id != null) {
      BackendApi.sendBroadcastChat(id, t).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final trader = _trader;
    final store = AppStateScope.of(context);
    final subscribed = store.isSubscribed(trader.id);
    // Only real trades the creator placed on-stream (no mock fallback).
    final List<LiveTrade> overlay = store.liveTrades;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Real HLS video (or a connecting / unavailable state)
          Positioned.fill(child: _videoLayer()),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.55), Colors.transparent, Colors.black.withOpacity(0.85)],
                stops: const [0, 0.4, 1],
              ),
            ),
          ),

          // Floating heart reactions (over the video, under the controls)
          Positioned.fill(child: IgnorePointer(child: LiveReactions(controller: _reactions))),

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
                // Live trade overlay(s) — full detail: entry, SL, TP, floating P/L
                ...overlay.map((t) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _LiveTradeCard(
                        trade: t,
                        pnl: store.livePnl(t),
                        onCopy: () => _copyFromLive(context, store, trader, t.symbol, t.isBuy),
                      ),
                    )),
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
                        onTap: () => _reactions.burst(2),
                        child: Container(
                          width: 44, height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                          child: Icon(Icons.favorite_rounded, size: 20, color: AppColors.red),
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

  /// The video surface: real stream when ready, else a branded animated
  /// backdrop with a connecting spinner or an "unavailable" message.
  Widget _videoLayer() {
    if (_whepReady && _whep != null) {
      return ColoredBox(color: Colors.black, child: Center(child: _whep!.view()));
    }
    final v = _video;
    if (_videoReady && v != null && v.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: v.value.aspectRatio == 0 ? 16 / 9 : v.value.aspectRatio,
            child: VideoPlayer(v),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(animation: _anim, builder: (_, __) => CustomPaint(painter: _StreamPainter(progress: _anim.value))),
        if (_resolving)
          const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
        else if (_videoFailed)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_rounded, size: 40, color: Colors.white.withOpacity(0.7)),
                const SizedBox(height: 12),
                Text('Stream unavailable', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Not live right now — check back soon.', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    setState(() { _resolving = true; _videoFailed = false; _cancelled = false; });
                    _initVideo();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('Retry', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';

  Future<void> _copyFromLive(BuildContext context, AppState store, Trader trader, String pair, bool isBuy) async {
    var ok = store.copyFromLive(trader, pair: pair, isBuy: isBuy);
    if (!ok) {
      // No account — prompt to connect, then retry.
      final acc = await AddAccountSheet.open(context);
      if (acc == null) return;
      ok = store.copyFromLive(trader, pair: pair, isBuy: isBuy);
    }
    if (ok && context.mounted) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${trader.name}\'s $pair ${isBuy ? 'BUY' : 'SELL'}')));
    }
  }
}

class _LiveTradeCard extends StatelessWidget {
  final LiveTrade trade;
  final double pnl;
  final VoidCallback onCopy;
  const _LiveTradeCard({required this.trade, required this.pnl, required this.onCopy});

  String _p(double? v) {
    if (v == null) return '—';
    if (v >= 1000) return v.toStringAsFixed(2);
    if (v >= 100) return v.toStringAsFixed(3);
    return v.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    final isBuy = trade.isBuy;
    final pending = trade.isPending;
    final profit = pnl >= 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: pending ? AppColors.primary : AppColors.red, borderRadius: BorderRadius.circular(6)),
                child: Text(pending ? 'PENDING' : 'LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
              ),
              const SizedBox(width: 10),
              Text(trade.symbol, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: (isBuy ? AppColors.green : AppColors.red).withOpacity(0.25), borderRadius: BorderRadius.circular(6)),
                child: Text(isBuy ? 'BUY' : 'SELL', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: isBuy ? AppColors.green : AppColors.red)),
              ),
              const Spacer(),
              if (!pending)
                Text('${profit ? '+' : '-'}\$${pnl.abs().toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: profit ? AppColors.green : AppColors.red)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _leg('Entry', _p(trade.entryPrice), Colors.white),
              _leg('SL', _p(trade.sl), AppColors.red),
              _leg('TP', _p(trade.tp), AppColors.green),
              _leg('Lots', trade.lots.toStringAsFixed(2), Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onCopy,
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Text('Copy this trade', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF0B1120))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leg(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white54)),
          const SizedBox(height: 1),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
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
            if (msg.isHost)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(5)),
                  child: Text('HOST', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                ),
              ),
            TextSpan(text: '${msg.user}  ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: me ? AppColors.primary : (msg.isHost ? AppColors.red : Colors.white.withOpacity(0.85)))),
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
  final bool isHost;
  _Msg(this.user, this.text, {this.isHost = false});
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
