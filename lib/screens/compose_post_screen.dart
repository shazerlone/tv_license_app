import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../config.dart';
import '../data/pairs.dart';
import '../models/post.dart';
import '../services/backend_api.dart';
import '../services/api_client.dart';
import '../services/price_service.dart';
import '../services/image_picker_service.dart';
import '../widgets/pair_picker.dart';
import 'pair_detail_screen.dart';
import 'trader_profile_screen.dart';

/// Creator composer — publish analysis, a copyable trade (with SL/TP), a lesson
/// or an update (POST /posts).
class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({super.key});

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  String _type = 'analysis'; // trade|analysis|lesson|update
  final _content = TextEditingController();
  final _title = TextEditingController();
  final List<TextEditingController> _points = [TextEditingController()];
  bool _posting = false;

  // Pair + live price (analysis & trade).
  TradingPair? _pair;
  Quote? _quote;
  bool _loadingQuote = false;

  // Trade specifics.
  String _side = 'buy'; // buy|sell
  String _entryType = 'market'; // market|limit
  final _entry = TextEditingController();
  bool _slPct = false; // false = price, true = percent
  bool _tpPct = false;
  final _sl = TextEditingController();
  final _tp = TextEditingController();

  // Image attachment.
  String? _imageUrl;
  bool _uploadingImage = false;

  static const _types = [
    ('analysis', 'Analysis', Icons.insights_rounded),
    ('trade', 'Trade', Icons.candlestick_chart_rounded),
    ('lesson', 'Lesson', Icons.school_rounded),
    ('update', 'Update', Icons.campaign_rounded),
  ];

  @override
  void dispose() {
    _content.dispose();
    _title.dispose();
    _entry.dispose();
    _sl.dispose();
    _tp.dispose();
    for (final c in _points) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _selectPair() async {
    final p = await showPairPicker(context);
    if (p == null) return;
    setState(() {
      _pair = p;
      _quote = null;
      _loadingQuote = true;
    });
    final q = await PriceService.quote(p);
    if (!mounted) return;
    setState(() {
      _quote = q;
      _loadingQuote = false;
      // Pre-fill the market entry price from the live quote.
      if (q != null && (_entry.text.trim().isEmpty || _entryType == 'market')) {
        _entry.text = _fmt(q.price);
      }
    });
  }

  String _fmt(double v) => v >= 100 ? v.toStringAsFixed(2) : v.toStringAsFixed(v >= 1 ? 4 : 5);

  Future<void> _pickImage() async {
    setState(() => _uploadingImage = true);
    try {
      final dataUrl = await ImagePickerService.pickImageAsDataUrl();
      if (dataUrl == null) {
        if (mounted) setState(() => _uploadingImage = false);
        return;
      }
      String url = dataUrl;
      if (kUseBackend && dataUrl.startsWith('data:')) {
        final comma = dataUrl.indexOf(',');
        final contentType = dataUrl.substring(5, comma).split(';').first;
        final data = dataUrl.substring(comma + 1);
        url = await BackendApi.uploadMedia(contentType: contentType, data: data, kind: 'post');
      }
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _uploadingImage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload the image')));
    }
  }

  /// Resolves a SL/TP as an absolute price given the entry, whether it's a
  /// percent, and the trade side.
  double? _resolveLevel(String raw, bool isPct, {required bool isSl}) {
    final v = double.tryParse(raw.trim());
    if (v == null) return null;
    if (!isPct) return v;
    final entry = double.tryParse(_entry.text.trim());
    if (entry == null) return null;
    final buy = _side == 'buy';
    // SL is adverse (buy → below, sell → above); TP is favourable.
    final down = isSl ? buy : !buy;
    return down ? entry * (1 - v / 100) : entry * (1 + v / 100);
  }

  Future<void> _publish() async {
    final content = _content.text.trim();
    final isTrade = _type == 'trade';
    if (content.isEmpty && !isTrade) {
      _snack('Write something to share');
      return;
    }
    if (isTrade && _pair == null) {
      _snack('Pick a pair for your trade');
      return;
    }
    final points = _points.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();

    Map<String, dynamic>? trade;
    if (isTrade) {
      final entry = double.tryParse(_entry.text.trim());
      final sl = _resolveLevel(_sl.text, _slPct, isSl: true);
      final tp = _resolveLevel(_tp.text, _tpPct, isSl: false);
      trade = {
        'side': _side,
        'entryType': _entryType,
        if (entry != null) 'entryPrice': entry,
        if (sl != null) 'sl': sl,
        if (tp != null) 'tp': tp,
        if (_slPct && _sl.text.trim().isNotEmpty) 'slPct': double.tryParse(_sl.text.trim()),
        if (_tpPct && _tp.text.trim().isNotEmpty) 'tpPct': double.tryParse(_tp.text.trim()),
      };
    }

    setState(() => _posting = true);
    if (kUseBackend) {
      final nav = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final api = await BackendApi.createPost(
          type: _type,
          content: content.isEmpty && isTrade ? '${_side.toUpperCase()} ${_pair!.symbol}' : content,
          pair: _pair?.symbol,
          title: _title.text.trim().isEmpty ? null : _title.text.trim(),
          points: points.isEmpty ? null : points,
          imageUrl: _imageUrl,
          trade: trade,
        );
        final post = Post.fromApi(api);
        SharedPreferences.getInstance().then((p) => p.setString('creator_trader_id', post.trader.id)).catchError((_) {});
        if (!mounted) return;
        nav.pop(true);
        nav.push(MaterialPageRoute(builder: (_) => TraderProfileScreen(trader: post.trader, isOwner: true)));
        messenger.showSnackBar(const SnackBar(content: Text('Posted 🎉')));
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _posting = false);
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() => _posting = false);
        messenger.showSnackBar(const SnackBar(content: Text('Could not reach the server')));
        return;
      }
    }
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) Navigator.pop(context, true);
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final showPair = _type == 'trade' || _type == 'analysis';
    final isTrade = _type == 'trade';
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
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
                    child: Row(children: [
                      Icon(t.$3, size: 16, color: active ? Colors.white : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(t.$2, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.textSecondary)),
                    ]),
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
            _PairSelector(pair: _pair, quote: _quote, loading: _loadingQuote, onTap: _selectPair),
            if (_pair != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PairDetailScreen(pair: _pair!))),
                  icon: Icon(Icons.show_chart_rounded, size: 18, color: AppColors.primary),
                  label: Text('Open live chart', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],

          if (isTrade) ...[
            _sideSelector(),
            const SizedBox(height: 12),
            _entryRow(),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _levelField('Stop loss', _sl, _slPct, (v) => setState(() => _slPct = v), AppColors.red)),
              const SizedBox(width: 12),
              Expanded(child: _levelField('Take profit', _tp, _tpPct, (v) => setState(() => _tpPct = v), AppColors.green)),
            ]),
            const SizedBox(height: 14),
          ],

          TextField(
            controller: _content,
            maxLines: 8,
            minLines: isTrade ? 3 : 5,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary, height: 1.5),
            decoration: InputDecoration(hintText: isTrade ? 'Add your reasoning (optional)…' : 'Share your analysis, setup or lesson…'),
          ),

          const SizedBox(height: 14),
          _imageAttachment(),

          if (showLesson) ...[
            const SizedBox(height: 20),
            Text('Key points', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            ..._points.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: e.value,
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
                        decoration: const InputDecoration(hintText: 'Add a takeaway', isDense: true),
                      ),
                    ),
                  ]),
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

  Widget _sideSelector() {
    Widget seg(String value, String label, Color color, IconData icon) {
      final active = _side == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _side = value),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? color.withOpacity(0.14) : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: active ? color : AppColors.border, width: active ? 1.4 : 1),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: active ? color : AppColors.textMuted),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w700, color: active ? color : AppColors.textSecondary)),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      seg('buy', 'Buy / Long', AppColors.green, Icons.trending_up_rounded),
      const SizedBox(width: 12),
      seg('sell', 'Sell / Short', AppColors.red, Icons.trending_down_rounded),
    ]);
  }

  Widget _entryRow() {
    return Row(children: [
      // market/limit toggle
      GestureDetector(
        onTap: () => setState(() => _entryType = _entryType == 'market' ? 'limit' : 'market'),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Text(_entryType == 'market' ? 'Market' : 'Limit', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Icon(Icons.unfold_more_rounded, size: 16, color: AppColors.textMuted),
          ]),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: TextField(
          controller: _entry,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: GoogleFonts.robotoMono(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: 'Entry price',
            suffixIcon: _entryType == 'market' && _quote != null
                ? TextButton(onPressed: () => setState(() => _entry.text = _fmt(_quote!.price)), child: Text('Live', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)))
                : null,
          ),
        ),
      ),
    ]);
  }

  Widget _levelField(String label, TextEditingController c, bool isPct, ValueChanged<bool> onMode, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const Spacer(),
          // price / % toggle
          GestureDetector(
            onTap: () => onMode(!isPct),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(isPct ? '%' : 'price', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: GoogleFonts.robotoMono(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          decoration: InputDecoration(hintText: isPct ? 'e.g. 1.5' : '0.00', isDense: true),
        ),
      ],
    );
  }

  Widget _imageAttachment() {
    if (_imageUrl != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.sm), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(Icons.image_rounded, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(child: Text('Setup image attached', style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          TextButton(onPressed: () => setState(() => _imageUrl = null), child: Text('Remove', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.red))),
        ]),
      );
    }
    return OutlinedButton.icon(
      onPressed: _uploadingImage ? null : _pickImage,
      icon: _uploadingImage
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.add_photo_alternate_outlined, size: 19, color: AppColors.primary),
      label: Text(_uploadingImage ? 'Uploading…' : 'Add chart / setup image', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primary)),
    );
  }
}

/// The pair selector row with the live price (or a prompt to pick).
class _PairSelector extends StatelessWidget {
  final TradingPair? pair;
  final Quote? quote;
  final bool loading;
  final VoidCallback onTap;
  const _PairSelector({required this.pair, required this.quote, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final up = (quote?.changePercent ?? 0) >= 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border), boxShadow: AppColors.softShadow),
        child: Row(children: [
          Icon(Icons.candlestick_chart_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: pair == null
                ? Text('Select a pair', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pair!.symbol, style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                      Text(pair!.name, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
          ),
          if (loading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else if (quote != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(quote!.price.toStringAsFixed(quote!.price >= 100 ? 2 : 4), style: GoogleFonts.robotoMono(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (quote!.changePercent != null)
                  Text('${up ? '+' : ''}${quote!.changePercent!.toStringAsFixed(2)}%', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: up ? AppColors.green : AppColors.red)),
              ],
            ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}
