import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../state/app_state.dart';
import '../services/backend_api.dart';
import '../services/rtmp_broadcaster.dart';
import '../services/api_client.dart';
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
  final RtmpBroadcaster _broadcaster = RtmpBroadcaster();
  bool _cameraReady = false;
  bool _publishStarted = false; // guards one-shot RTMPS publish
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
      await _broadcaster.init();
      if (!mounted) return;
      setState(() {
        _cameraReady = true;
        _camError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _camError = 'Camera permission needed');
    }
  }

  void _flip() => _broadcaster.flip();

  /// Once the backend broadcast is live and returns the WHIP URL, start pushing
  /// the camera to Cloudflare over WebRTC (guarded so it only fires once).
  void _maybePublish(AppState store) {
    if (_publishStarted || !store.isBackendLive) return;
    final whip = store.liveWhipUrl;
    if (whip == null || whip.isEmpty || !_broadcaster.ready) return;
    _publishStarted = true;
    _broadcaster.publish(whipUrl: whip).catchError((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t start the live video — check your connection.')),
        );
      }
    });
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
    final bid = store.broadcastId; // capture before endBroadcast clears it
    await _broadcaster.stop();
    _publishStarted = false;
    store.endBroadcast();
    if (mounted) await _showRecap(peak, dur, trades, booked, bid);
    return true;
  }

  final GlobalKey _recapKey = GlobalKey();
  bool _sharingRecap = false;

  Future<void> _showRecap(int peak, String duration, int trades, double booked, String? broadcastId) {
    final positive = booked >= 0;
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              // The shareable recap card (rendered to an image for the story).
              RepaintBoundary(
                key: _recapKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF111C33)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Live session recap', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 16),
                      Row(children: [
                        _RecapStat(label: 'Duration', value: duration, onDark: true),
                        _RecapStat(label: 'Peak viewers', value: '$peak', onDark: true),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        _RecapStat(label: 'Trades', value: '$trades', onDark: true),
                        _RecapStat(label: 'Session P&L', value: '${positive ? '+' : '-'}\$${booked.abs().toStringAsFixed(2)}', color: positive ? const Color(0xFF4ADE80) : const Color(0xFFF87171), onDark: true),
                      ]),
                      const SizedBox(height: 14),
                      Text('Millimore', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.6))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _sharingRecap ? null : () async {
                    setSheet(() => _sharingRecap = true);
                    await _shareRecapToStory(broadcastId);
                    setSheet(() => _sharingRecap = false);
                  },
                  icon: _sharingRecap
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.auto_awesome_motion_rounded, size: 18, color: AppColors.primary),
                  label: Text(_sharingRecap ? 'Sharing…' : 'Share to your story', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))),
            ],
          ),
        ),
      ),
    );
  }

  /// Render the recap card to a PNG, upload it, and post it as a recap story.
  Future<void> _shareRecapToStory(String? broadcastId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary = _recapKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw 'no card';
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw 'render';
      final b64 = base64Encode(bytes.buffer.asUint8List());
      final url = await BackendApi.uploadMedia(contentType: 'image/png', data: b64, kind: 'story');
      await BackendApi.createStory(mediaUrl: url, mediaType: 'image', kind: 'recap', broadcastId: broadcastId);
      messenger.showSnackBar(const SnackBar(content: Text('Shared to your story')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not share to story')));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _broadcaster.dispose();
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
    // Start pushing the camera the moment the backend hands us the ingest URL.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePublish(store));

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live camera preview (or placeholder) — this is the actual encoder feed.
          _cameraReady
              ? Positioned.fill(child: _broadcaster.preview())
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
              // YouTube: OAuth connect links your channel so its live chat flows
              // into the in-app chat (M15). Other platforms use a stream key.
              if (id == 'youtube')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _connectYoutube(context, store),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Connect YouTube channel'),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () { store.toggleDestination(id); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name connected'))); },
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text('Connect $name account'),
                  ),
                ),
              const SizedBox(height: 12),
              Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(id == 'youtube' ? 'or simulcast with a stream key' : 'or paste stream key', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted))), const Expanded(child: Divider())]),
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
                  onPressed: () => _saveStreamKey(context, store, id, name, keyController.text.trim()),
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

  /// M15 — link the creator's YouTube channel so its live chat is ingested into
  /// the in-app chat. Returns a Google consent URL to open in a browser.
  Future<void> _connectYoutube(BuildContext context, AppState store) async {
    if (!kUseBackend) {
      store.toggleDestination('youtube');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('YouTube connected')));
      return;
    }
    try {
      final status = await BackendApi.youtubeStatus();
      if (status['connected'] == true) {
        store.toggleDestination('youtube');
        if (!context.mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('YouTube already connected')));
        return;
      }
      final url = await BackendApi.youtubeConnect();
      if (!context.mounted) return;
      Navigator.pop(context);
      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('YouTube connect is unavailable right now')));
        return;
      }
      await _showConsentUrl(context, url);
      store.toggleDestination('youtube');
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  /// M13 — add a simulcast destination (RTMP) with a pasted stream key. Outputs
  /// live on the active broadcast, so this only takes effect once you're live.
  Future<void> _saveStreamKey(BuildContext context, AppState store, String id, String name, String key) async {
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paste your stream key first')));
      return;
    }
    if (!kUseBackend) {
      store.toggleDestination(id);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name key saved')));
      return;
    }
    final broadcastId = store.broadcastId;
    if (broadcastId == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Go live first, then $name will simulcast')));
      return;
    }
    try {
      await BackendApi.addBroadcastOutput(broadcastId, platform: id, streamKey: key);
      store.toggleDestination(id);
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Now simulcasting to $name')));
    } on ApiException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach the server')));
    }
  }

  Future<void> _showConsentUrl(BuildContext context, String url) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Connect YouTube', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Open this link in your browser and approve access. Your live chat will then appear here automatically.',
                style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textSecondary, height: 1.45)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: SelectableText(url, style: GoogleFonts.robotoMono(fontSize: 12, color: AppColors.textPrimary)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text('Close', style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton.icon(
            onPressed: () { Clipboard.setData(ClipboardData(text: url)); Navigator.of(ctx).pop(); },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy link'),
          ),
        ],
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
  final bool onDark;
  const _RecapStat({required this.label, required this.value, this.color, this.onDark = false});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: onDark ? Colors.white.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: onDark ? Colors.white.withOpacity(0.15) : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: color ?? (onDark ? Colors.white : AppColors.textPrimary))),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: onDark ? Colors.white.withOpacity(0.6) : AppColors.textMuted)),
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
