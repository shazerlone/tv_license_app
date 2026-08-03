import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../state/app_state.dart';
import '../models/copy_models.dart';
import '../widgets/order_ticket.dart';
import '../widgets/live_reactions.dart';
import '../widgets/live_chat_feed.dart';

/// In-app Instagram / TikTok / YouTube-style go-live composer.
/// Camera fills the screen. Millimore is always on; connect YouTube to
/// simulcast. Place a trade on-stream → it shows as the copy overlay.
class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {
  final _titleController = TextEditingController(text: 'Live trading session');
  CameraController? _camera;
  List<CameraDescription> _cameras = [];
  int _camIndex = 0;
  bool _cameraReady = false;
  String? _camError;
  bool _showHistory = false;
  AppState? _store;
  final _reactions = LiveReactionsController();
  Timer? _heartTimer;
  Timer? _chatTimer;

  static const _chatUsers = ['alex_t', 'jade_fx', 'crypto_k', 'mark99', 'luna_t', 'trader_z', 'pip_hunter', 'gold_bug'];
  static const _chatLines = ['nice entry 🔥', 'what\'s your SL?', 'copied!', 'gold looking bullish', 'ty for the breakdown', 'following live', 'buy or wait?', 'this is clean', 'from YouTube 👋', 'love the setups'];

  @override
  void initState() {
    super.initState();
    _initCamera();
    _heartTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted && (_store?.isLive ?? false)) _reactions.burst(1 + math.Random().nextInt(2));
    });
    // Demo-only simulated chat. With the backend, chat arrives over the
    // broadcast WS channel (real viewers + YouTube ingest).
    if (!kUseBackend) {
      _chatTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
        if (!mounted || !(_store?.isLive ?? false)) return;
        final r = math.Random();
        final src = r.nextBool() ? ChatSource.youtube : ChatSource.millimore;
        _store!.addChat(LiveChatMessage(
          author: _chatUsers[r.nextInt(_chatUsers.length)],
          text: _chatLines[r.nextInt(_chatLines.length)],
          source: src,
        ));
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store == null) {
      _store = AppStateScope.of(context);
      _store!.startPriceFeed();
    }
  }

  Future<void> _initCamera() async {
    if (kIsWeb) {
      setState(() => _camError = 'web');
      return;
    }
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _camError = 'No camera found');
        return;
      }
      await _startController(0);
    } catch (e) {
      setState(() => _camError = 'Camera unavailable');
    }
  }

  Future<void> _startController(int index) async {
    await _camera?.dispose();
    final controller = CameraController(_cameras[index], ResolutionPreset.high, enableAudio: true);
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _camera = controller;
        _camIndex = index;
        _cameraReady = true;
        _camError = null;
      });
    } catch (e) {
      setState(() => _camError = 'Camera permission needed');
    }
  }

  void _flip() {
    if (_cameras.length < 2) return;
    _startController((_camIndex + 1) % _cameras.length);
  }

  /// Confirm, capture stats, end the broadcast, then show a recap.
  /// Returns true if the live actually ended.
  Future<bool> _endLive() async {
    final store = _store;
    if (store == null || !store.isBroadcasting) return false;
    final ok = await _confirmEnd(context);
    if (ok != true) return false;
    final peak = store.peakViewers;
    final dur = store.liveDurationLabel;
    final trades = store.closedLiveTrades.length + store.liveTrades.length;
    final booked = store.closedLiveTrades.fold<double>(0, (s, c) => s + c.pnl) +
        store.liveTrades.fold<double>(0, (s, t) => s + store.livePnl(t));
    store.endBroadcast();
    if (mounted) await _showRecap(peak, dur, trades, booked);
    return true;
  }

  Future<void> _showRecap(int peak, String duration, int trades, double booked) {
    final positive = booked >= 0;
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => Container(
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text('Live ended', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4)),
            const SizedBox(height: 4),
            Text('Nice session. Here\'s how it went.', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textMuted)),
            const SizedBox(height: 18),
            Row(children: [
              _RecapStat(label: 'Duration', value: duration),
              _RecapStat(label: 'Peak viewers', value: '$peak'),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _RecapStat(label: 'Trades', value: '$trades'),
              _RecapStat(label: 'Session P&L', value: '${positive ? '+' : '-'}\$${booked.abs().toStringAsFixed(2)}', color: positive ? AppColors.green : AppColors.red),
            ]),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _camera?.dispose();
    _heartTimer?.cancel();
    _chatTimer?.cancel();
    _reactions.dispose();
    _store?.stopPriceFeed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStateScope.of(context);
    final phase = store.phase;
    final live = phase == BroadcastPhase.live;
    final connecting = phase == BroadcastPhase.connecting;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview (or placeholder)
          _cameraReady && _camera != null
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _camera!.value.previewSize?.height ?? 1080,
                    height: _camera!.value.previewSize?.width ?? 1920,
                    child: CameraPreview(_camera!),
                  ),
                )
              : _PreviewPlaceholder(reason: _camError),

          // Scrims for readability
          const _Scrim(),

          // Floating heart reactions from viewers (over camera, under controls)
          Positioned.fill(child: IgnorePointer(child: LiveReactions(controller: _reactions))),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      _RoundBtn(icon: Icons.close_rounded, onTap: () async {
                        if (store.isBroadcasting) {
                          final ended = await _endLive();
                          if (ended && context.mounted) Navigator.pop(context);
                        } else {
                          Navigator.pop(context);
                        }
                      }),
                      const Spacer(),
                      if (live) _LivePill(viewers: store.viewers, duration: store.liveDurationLabel)
                      else if (connecting) _ConnectingPill(),
                      const Spacer(),
                      _RoundBtn(icon: Icons.cameraswitch_rounded, onTap: _flip),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _titleController,
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a title…',
                      hintStyle: GoogleFonts.inter(fontSize: 16, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.28),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Destinations row
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _DestChip(label: 'Millimore', icon: Icons.auto_graph_rounded, on: true, locked: true, onTap: () {}),
                      const SizedBox(width: 8),
                      _DestChip(label: store.isDestinationOn('youtube') ? 'YouTube · on' : 'YouTube', icon: Icons.smart_display_rounded, on: store.isDestinationOn('youtube'), onTap: () => _connectSheet(context, store, 'youtube', 'YouTube')),
                      const SizedBox(width: 8),
                      _DestChip(label: store.isDestinationOn('facebook') ? 'Facebook · on' : 'Facebook', icon: Icons.facebook_rounded, on: store.isDestinationOn('facebook'), onTap: () => _connectSheet(context, store, 'facebook', 'Facebook')),
                    ],
                  ),
                ),

                const Spacer(),
                // Live chat (Millimore + YouTube) — bottom-anchored, capped height
                // so it never covers the camera.
                if (live)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.26),
                    child: LiveChatFeed(
                      messages: store.liveChat,
                      onSend: (t) => store.sendHostChat(t, 'You'),
                    ),
                  ),

                // Live trade overlay preview (what viewers see) with floating P/L
                if (store.liveTrades.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Column(
                      children: store.liveTrades.take(3).map((t) {
                        final pnl = store.livePnl(t);
                        final positive = pnl >= 0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                          child: Row(children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: t.isPending ? AppColors.primary : AppColors.red, borderRadius: BorderRadius.circular(6)), child: Text(t.isPending ? 'PENDING' : 'LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
                            const SizedBox(width: 10),
                            Text(t.symbol, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(width: 8),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: (t.isBuy ? AppColors.green : AppColors.red).withOpacity(0.25), borderRadius: BorderRadius.circular(6)), child: Text(t.directionLabel, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: t.isBuy ? AppColors.green : AppColors.red))),
                            const Spacer(),
                            if (!t.isPending)
                              Text('${positive ? '+' : '-'}\$${pnl.abs().toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: positive ? AppColors.green : AppColors.red)),
                            const SizedBox(width: 10),
                            GestureDetector(onTap: () => store.closeLiveTrade(t.id), child: const Icon(Icons.close_rounded, size: 18, color: Colors.white70)),
                          ]),
                        );
                      }).toList(),
                    ),
                  ),

                // History (collapsible)
                if (_showHistory && store.closedLiveTrades.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                    child: SingleChildScrollView(
                      child: Column(
                        children: store.closedLiveTrades.map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Text(c.symbol, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
                            const SizedBox(width: 6),
                            Text(c.directionLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: c.isBuy ? AppColors.green : AppColors.red)),
                            const Spacer(),
                            Text('${c.isProfit ? '+' : '-'}\$${c.pnl.abs().toStringAsFixed(2)}', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.isProfit ? AppColors.green : AppColors.red)),
                          ]),
                        )).toList(),
                      ),
                    ),
                  ),

                // Place trade + history controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => OrderTicket.open(context),
                          child: Container(
                            height: 46, alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.add_chart_rounded, size: 18, color: Colors.white),
                              const SizedBox(width: 8),
                              Text('Place trade', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            ]),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => setState(() => _showHistory = !_showHistory),
                        child: Container(
                          height: 46, width: 46, alignment: Alignment.center,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24)),
                          child: Icon(_showHistory ? Icons.history_toggle_off_rounded : Icons.history_rounded, size: 22, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                // Go live / Connecting / End
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: connecting
                        ? _ConnectingBtn()
                        : live
                            ? _EndBtn(onTap: _endLive)
                            : _GoLiveBtn(onTap: () => store.startBroadcast(title: _titleController.text.trim().isEmpty ? 'Live trading' : _titleController.text.trim())),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _connectSheet(BuildContext context, AppState store, String id, String name) {
    final keyController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text('Connect $name', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Simulcast your live to $name alongside Millimore.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 18),
              // Auto connect (OAuth later)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () { store.toggleDestination(id); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name connected'))); },
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text('Connect $name account'),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or paste stream key', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))), const Expanded(child: Divider())]),
              const SizedBox(height: 12),
              TextField(
                controller: keyController,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                decoration: InputDecoration(hintText: 'Paste your $name stream key'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () { store.toggleDestination(id); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name key saved'))); },
                  child: const Text('Save key'),
                ),
              ),
              if (store.isDestinationOn(id)) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () { store.toggleDestination(id); Navigator.pop(context); },
                    child: Text('Disconnect $name', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.red)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── UI bits ───────────────────────────────────────────────────────────────────

class _PreviewPlaceholder extends StatelessWidget {
  final String? reason;
  const _PreviewPlaceholder({this.reason});

  @override
  Widget build(BuildContext context) {
    final msg = reason == 'web'
        ? 'Camera preview runs on the mobile app'
        : (reason ?? 'Starting camera…');
    return Container(
      color: const Color(0xFF0B1120),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_rounded, size: 44, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(msg, style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.45), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.6)],
            stops: const [0, 0.25, 0.55, 1],
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final int viewers;
  final String duration;
  const _LivePill({required this.viewers, required this.duration});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)), child: Text('LIVE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white))),
        const SizedBox(width: 8),
        const Icon(Icons.remove_red_eye_rounded, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Text('$viewers', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        const SizedBox(width: 8),
        Container(width: 1, height: 12, color: Colors.white24),
        const SizedBox(width: 8),
        Text(duration, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }
}

class _ConnectingPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 8),
        Text('Connecting…', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }
}

class _DestChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool on;
  final bool locked;
  final VoidCallback onTap;
  const _DestChip({required this.label, required this.icon, required this.on, this.locked = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? Colors.white : Colors.black.withOpacity(0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? Colors.white : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: on ? const Color(0xFF0B1120) : Colors.white),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: on ? const Color(0xFF0B1120) : Colors.white)),
          if (locked) ...[const SizedBox(width: 5), Icon(Icons.check_circle_rounded, size: 13, color: const Color(0xFF0B1120))],
        ]),
      ),
    );
  }
}


class _GoLiveBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _GoLiveBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54, alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(28)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.podcasts_rounded, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Text('Go Live', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        ]),
      ),
    );
  }
}

class _ConnectingBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54, alignment: Alignment.center,
      decoration: BoxDecoration(color: AppColors.red.withOpacity(0.6), borderRadius: BorderRadius.circular(28)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 10),
        Text('Connecting…', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
    );
  }
}

class _RecapStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _RecapStat({required this.label, required this.value, this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: color ?? AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmEnd(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('End your live?', style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      content: Text('Your stream will stop on Millimore and any connected platforms.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Keep live', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.textMuted))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('End live', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.red))),
      ],
    ),
  );
}

class _EndBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _EndBtn({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54, alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
        child: Text('End live', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0B1120))),
      ),
    );
  }
}
