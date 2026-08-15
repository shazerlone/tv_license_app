import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../data/pairs.dart';
import '../services/price_service.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';
import '../services/realtime_service.dart';
import '../widgets/tradingview_chart.dart';

/// Market view for a single instrument: live TradingView chart, live price, and
/// a community chat for that pair (Exness/eToro-style).
class PairDetailScreen extends StatefulWidget {
  final TradingPair pair;
  const PairDetailScreen({super.key, required this.pair});

  @override
  State<PairDetailScreen> createState() => _PairDetailScreenState();
}

class _PairDetailScreenState extends State<PairDetailScreen> {
  Quote? _quote;
  Timer? _priceTimer;

  final _chat = <Map<String, dynamic>>[];
  final _msg = TextEditingController();
  bool _chatAvailable = true;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _refreshPrice();
    _priceTimer = Timer.periodic(const Duration(seconds: 12), (_) => _refreshPrice());
    _loadChat();
    // Live messages over the WS pair channel (once the backend exposes it).
    final rt = RealtimeService.current;
    rt?.subscribePair(widget.pair.symbol);
    _wsSub = rt?.pairEvents.listen((m) {
      if (m['ch'] != 'pair:${widget.pair.symbol}') return;
      final d = m['data'];
      if (d is Map) setState(() => _chat.add(d.cast<String, dynamic>()));
    });
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    _wsSub?.cancel();
    RealtimeService.current?.unsubscribePair(widget.pair.symbol);
    _msg.dispose();
    super.dispose();
  }

  Future<void> _refreshPrice() async {
    final q = await PriceService.quote(widget.pair);
    if (mounted && q != null) setState(() => _quote = q);
  }

  Future<void> _createAlert() async {
    final priceCtrl = TextEditingController(text: _quote != null ? _quote!.price.toStringAsFixed(_quote!.price >= 100 ? 2 : 4) : '');
    String direction = (_quote != null) ? 'above' : 'above';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(color: AppColors.background, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 18),
                Text('Alert me on ${widget.pair.symbol}', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                Row(children: [
                  for (final d in ['above', 'below'])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setSheet(() => direction = d),
                        child: Container(
                          margin: EdgeInsets.only(right: d == 'above' ? 10 : 0),
                          height: 46, alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: direction == d ? AppColors.primary.withOpacity(0.14) : AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: direction == d ? AppColors.primary : AppColors.border),
                          ),
                          child: Text(d == 'above' ? 'Rises above' : 'Falls below',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: direction == d ? AppColors.primary : AppColors.textSecondary)),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Target price'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final target = double.tryParse(priceCtrl.text.trim());
                      if (target == null || target <= 0) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await BackendApi.createAlert(symbol: widget.pair.symbol, direction: direction, targetPrice: target);
                        Navigator.pop(ctx);
                        messenger.showSnackBar(const SnackBar(content: Text('Alert set — we\'ll notify you')));
                      } on ApiException catch (e) {
                        messenger.showSnackBar(SnackBar(content: Text(
                          e.code == 'alert_already_met' ? 'That target is already met — pick the other direction.' : e.message,
                        )));
                      } catch (_) {
                        messenger.showSnackBar(const SnackBar(content: Text('Could not reach the server')));
                      }
                    },
                    child: Text('Set alert', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadChat() async {
    if (!kUseBackend) {
      setState(() => _chatAvailable = false);
      return;
    }
    try {
      final list = await BackendApi.pairChat(widget.pair.symbol);
      if (!mounted) return;
      setState(() {
        _chat
          ..clear()
          ..addAll(list);
      });
    } catch (_) {
      if (mounted) setState(() => _chatAvailable = false);
    }
  }

  Future<void> _send() async {
    final text = _msg.text.trim();
    if (text.isEmpty) return;
    _msg.clear();
    // optimistic
    setState(() => _chat.add({'author': 'You', 'text': text, 'byMe': true}));
    try {
      await BackendApi.sendPairChat(widget.pair.symbol, text);
    } catch (_) {
      if (mounted) setState(() => _chatAvailable = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    final up = (q?.changePercent ?? 0) >= 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.pair.symbol, style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(widget.pair.name, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          if (kUseBackend)
            IconButton(
              tooltip: 'Price alert',
              icon: Icon(Icons.notifications_active_outlined, color: AppColors.textPrimary),
              onPressed: _createAlert,
            ),
          if (q != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(q.price.toStringAsFixed(q.price >= 100 ? 2 : 4), style: GoogleFonts.robotoMono(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  if (q.changePercent != null)
                    Text('${up ? '+' : ''}${q.changePercent!.toStringAsFixed(2)}%', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: up ? AppColors.green : AppColors.red)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TradingViewChart(tvSymbol: widget.pair.tv, height: 300),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
            child: Row(children: [
              Icon(Icons.forum_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Live discussion', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: _chatBody()),
          _composer(),
        ],
      ),
    );
  }

  Widget _chatBody() {
    if (!_chatAvailable) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.forum_outlined, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('Community chat is rolling out for this pair', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('You\'ll be able to talk price action here with other traders.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textMuted)),
          ]),
        ),
      );
    }
    if (_chat.isEmpty) {
      return Center(child: Text('Be the first to say something 👋', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textMuted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      itemCount: _chat.length,
      itemBuilder: (_, i) {
        final m = _chat[i];
        final byMe = m['byMe'] == true;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!byMe) ...[
                Text('${m['author'] ?? 'trader'}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text('${m['text'] ?? ''}', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.textPrimary))),
            ],
          ),
        );
      },
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _msg,
              enabled: _chatAvailable,
              minLines: 1, maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: _chatAvailable ? 'Message…' : 'Chat unavailable',
                filled: true, fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _chatAvailable ? _send : null,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _chatAvailable ? AppColors.primary : AppColors.textMuted, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}
