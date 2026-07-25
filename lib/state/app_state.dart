import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/trader.dart';
import '../models/copy_models.dart';

enum BroadcastPhase { idle, connecting, live }

/// The app's reactive data store: subscriptions, saved posts, likes and
/// comments. Swap the in-memory maps for a backend later — the UI only talks
/// to this controller, so nothing else changes.
class AppState extends ChangeNotifier {
  // traderId -> subscribed
  final Set<String> _subscribed = {'1', '2', '3'};
  // traderId -> notifications on
  final Set<String> _notify = {'1'};
  // postId -> saved
  final Set<String> _saved = {};
  // postId -> liked
  final Map<String, bool> _liked = {};
  final Map<String, int> _likeCount = {};
  // postId -> comments
  final Map<String, List<Comment>> _comments = {};

  // ── Subscriptions ──────────────────────────────────────────────────────────
  bool isSubscribed(String traderId) => _subscribed.contains(traderId);
  int get subscriptionCount => _subscribed.length;
  Set<String> get subscribedTraderIds => _subscribed;

  void subscribe(String traderId) {
    _subscribed.add(traderId);
    _notify.add(traderId);
    notifyListeners();
  }

  void unsubscribe(String traderId) {
    _subscribed.remove(traderId);
    _notify.remove(traderId);
    notifyListeners();
  }

  void toggleSubscribe(String traderId) =>
      isSubscribed(traderId) ? unsubscribe(traderId) : subscribe(traderId);

  bool isNotifying(String traderId) => _notify.contains(traderId);
  void toggleNotify(String traderId) {
    _notify.contains(traderId) ? _notify.remove(traderId) : _notify.add(traderId);
    notifyListeners();
  }

  // ── Saved posts ────────────────────────────────────────────────────────────
  bool isSaved(String postId) => _saved.contains(postId);
  int get savedCount => _saved.length;
  Set<String> get savedPostIds => _saved;

  void toggleSave(String postId) {
    _saved.contains(postId) ? _saved.remove(postId) : _saved.add(postId);
    notifyListeners();
  }

  // ── Likes ──────────────────────────────────────────────────────────────────
  bool isLiked(Post post) {
    return _liked.putIfAbsent(post.id, () => post.isLiked);
  }

  int likeCount(Post post) {
    return _likeCount.putIfAbsent(post.id, () => post.likes);
  }

  void toggleLike(Post post) {
    final liked = isLiked(post);
    _liked[post.id] = !liked;
    _likeCount[post.id] = likeCount(post) + (!liked ? 1 : -1);
    notifyListeners();
  }

  // ── Comments ──────────────────────────────────────────────────────────────
  List<Comment> commentsFor(Post post) {
    return _comments.putIfAbsent(post.id, () => _seedComments(post));
  }

  int commentCount(Post post) => commentsFor(post).length;

  void addComment(Post post, String text) {
    final list = commentsFor(post);
    list.insert(
      0,
      Comment(
        author: 'You',
        username: 'you',
        text: text,
        createdAt: DateTime.now(),
        byMe: true,
      ),
    );
    notifyListeners();
  }

  // ── Trading accounts ─────────────────────────────────────────────────────
  final List<TradingAccount> _accounts = [];
  List<TradingAccount> get accounts => List.unmodifiable(_accounts);
  bool get hasAccount => _accounts.isNotEmpty;

  TradingAccount addAccount({
    required String brokerId,
    required String brokerName,
    required String accountNumber,
    required String server,
    double balance = 5000,
  }) {
    final acc = TradingAccount(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      brokerId: brokerId,
      brokerName: brokerName,
      accountNumber: accountNumber,
      server: server,
      balance: balance,
      connectedAt: DateTime.now(),
    );
    _accounts.add(acc);
    notifyListeners();
    return acc;
  }

  void removeAccount(String id) {
    _accounts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  // ── Copy engine ───────────────────────────────────────────────────────────
  final Map<String, CopyConfig> _copying = {};
  final List<CopyPosition> _positions = [];

  bool isCopying(String traderId) => _copying.containsKey(traderId);
  CopyConfig? copyConfig(String traderId) => _copying[traderId];
  List<CopyConfig> get activeCopies => _copying.values.toList();
  int get copyingCount => _copying.length;

  List<CopyPosition> get positions => List.unmodifiable(_positions);
  List<CopyPosition> get activePositions =>
      _positions.where((p) => p.status == PositionStatus.active).toList();
  List<CopyPosition> get closedPositions =>
      _positions.where((p) => p.status == PositionStatus.closed).toList();

  double get openPnl => activePositions.fold(0, (s, p) => s + p.pnlAmount);
  double get bookedProfit =>
      closedPositions.where((p) => p.pnlAmount >= 0).fold(0, (s, p) => s + p.pnlAmount);
  double get bookedLoss =>
      closedPositions.where((p) => p.pnlAmount < 0).fold(0, (s, p) => s + p.pnlAmount);
  double get netPnl => openPnl + bookedProfit + bookedLoss;
  double get totalInvested => _copying.values.fold(0, (s, c) => s + c.amount);

  void startCopy(Trader trader, {required String accountId, required double amount, required double risk, required bool autoCopy}) {
    _copying[trader.id] = CopyConfig(
      traderId: trader.id,
      accountId: accountId,
      amount: amount,
      risk: risk,
      autoCopy: autoCopy,
      startedAt: DateTime.now(),
    );
    _seedPositions(trader, accountId, amount);
    notifyListeners();
  }

  void stopCopy(String traderId) {
    _copying.remove(traderId);
    notifyListeners();
  }

  void _seedPositions(Trader trader, String accountId, double amount) {
    final rng = math.Random(trader.id.hashCode ^ DateTime.now().millisecond);
    final pairs = trader.tags.where((t) => t.contains('/')).toList();
    final symbols = pairs.isNotEmpty ? pairs : ['EUR/USD', 'XAU/USD', 'GBP/USD'];

    // 2 active
    for (int i = 0; i < 2; i++) {
      final pct = (rng.nextDouble() * 3 - 1);
      _positions.insert(
        0,
        CopyPosition(
          id: 'pos_${DateTime.now().microsecondsSinceEpoch}_$i',
          traderId: trader.id,
          traderName: trader.name,
          pair: symbols[rng.nextInt(symbols.length)],
          isBuy: rng.nextBool(),
          status: PositionStatus.active,
          entryPrice: 1 + rng.nextDouble(),
          pnlAmount: amount * pct / 100,
          pnlPercent: pct,
          lots: (0.05 + rng.nextDouble() * 0.4),
          openedAt: DateTime.now().subtract(Duration(hours: rng.nextInt(20) + 1)),
          accountId: accountId,
        ),
      );
    }
    // 2 closed
    for (int i = 0; i < 2; i++) {
      final pct = (rng.nextDouble() * 4 - 1.3);
      _positions.add(
        CopyPosition(
          id: 'pos_c_${DateTime.now().microsecondsSinceEpoch}_$i',
          traderId: trader.id,
          traderName: trader.name,
          pair: symbols[rng.nextInt(symbols.length)],
          isBuy: rng.nextBool(),
          status: PositionStatus.closed,
          entryPrice: 1 + rng.nextDouble(),
          exitPrice: 1 + rng.nextDouble(),
          pnlAmount: amount * pct / 100,
          pnlPercent: pct,
          lots: (0.05 + rng.nextDouble() * 0.4),
          openedAt: DateTime.now().subtract(Duration(days: rng.nextInt(6) + 1)),
          closedAt: DateTime.now().subtract(Duration(hours: rng.nextInt(20) + 1)),
          accountId: accountId,
        ),
      );
    }
  }

  // ── Live broadcasting (creator) ─────────────────────────────────────────────
  // Backend (Cloudflare Stream Live) will supply the real ingest URL + key and
  // manage simulcast Outputs to YouTube / Facebook.
  final String streamKey = 'mlm_${(math.Random().nextInt(900000) + 100000)}_live';
  String get ingestUrl => 'rtmps://live.millimore.app:443/live';

  BroadcastPhase _phase = BroadcastPhase.idle;
  BroadcastPhase get phase => _phase;
  bool get isBroadcasting => _phase != BroadcastPhase.idle;
  bool get isLive => _phase == BroadcastPhase.live;

  int _viewers = 0;
  int get viewers => _viewers;
  int _peakViewers = 0;
  int get peakViewers => _peakViewers;

  DateTime? _liveStart;
  Duration get liveDuration => _liveStart == null ? Duration.zero : DateTime.now().difference(_liveStart!);
  String get liveDurationLabel {
    final d = liveDuration;
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    final two = (int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  Timer? _viewerTimer;

  // Connected simulcast destinations (besides Millimore, which is always on).
  final Set<String> _destinations = {};
  bool isDestinationOn(String id) => _destinations.contains(id);
  void toggleDestination(String id) {
    _destinations.contains(id) ? _destinations.remove(id) : _destinations.add(id);
    notifyListeners();
  }

  /// Begins the connecting → live handshake (mirrors a real RTMP connect).
  void startBroadcast() {
    if (_phase != BroadcastPhase.idle) return;
    _phase = BroadcastPhase.connecting;
    notifyListeners();
    Timer(const Duration(milliseconds: 1600), () {
      if (_phase != BroadcastPhase.connecting) return;
      _phase = BroadcastPhase.live;
      _liveStart = DateTime.now();
      _viewers = 1 + math.Random().nextInt(20);
      _peakViewers = _viewers;
      startPriceFeed(); // keep duration/P&L ticking each second
      _viewerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _viewers = (_viewers + math.Random().nextInt(5) - 1).clamp(0, 1 << 30);
        if (_viewers > _peakViewers) _peakViewers = _viewers;
        notifyListeners();
      });
      notifyListeners();
    });
  }

  void endBroadcast() {
    final wasLive = _phase != BroadcastPhase.idle;
    _phase = BroadcastPhase.idle;
    _viewers = 0;
    _liveStart = null;
    _viewerTimer?.cancel();
    _viewerTimer = null;
    _liveTrades.clear();
    _liveChat.clear();
    if (wasLive) stopPriceFeed();
    notifyListeners();
  }

  // ── Live chat (Millimore + YouTube/Facebook aggregated) ─────────────────────
  final List<LiveChatMessage> _liveChat = [];
  List<LiveChatMessage> get liveChat => List.unmodifiable(_liveChat);

  void addChat(LiveChatMessage m) {
    _liveChat.add(m);
    if (_liveChat.length > 100) _liveChat.removeAt(0);
    notifyListeners();
  }

  void sendHostChat(String text, String hostName) {
    if (text.trim().isEmpty) return;
    addChat(LiveChatMessage(author: hostName, text: text.trim(), byHost: true));
  }

  // ── Live price feed (simulated; becomes real MT prices via backend) ─────────
  final Map<String, double> _prices = {
    'XAU/USD': 2015.0,
    'EUR/USD': 1.0850,
    'GBP/USD': 1.2650,
    'USD/JPY': 149.50,
    'BTC/USD': 67500.0,
    'US30': 38500.0,
  };
  List<String> get symbols => _prices.keys.toList();
  double priceOf(String s) => _prices[s] ?? 1.0;

  Timer? _priceTimer;
  int _feedRefs = 0;

  void startPriceFeed() {
    _feedRefs++;
    _priceTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final r = math.Random();
      _prices.updateAll((k, v) => v * (1 + (r.nextDouble() - 0.5) * 0.0009));
      notifyListeners();
    });
  }

  void stopPriceFeed() {
    _feedRefs--;
    if (_feedRefs <= 0) {
      _feedRefs = 0;
      _priceTimer?.cancel();
      _priceTimer = null;
    }
  }

  int _contract(String s) {
    if (s == 'XAU/USD') return 100;
    if (s == 'BTC/USD') return 1;
    if (s == 'US30') return 1;
    if (s == 'USD/JPY') return 1000;
    return 100000;
  }

  /// Floating dollar P/L for an open live trade at the current price.
  double livePnl(LiveTrade t) {
    if (t.isPending) return 0;
    final cur = priceOf(t.symbol);
    final dir = t.isBuy ? 1 : -1;
    return (cur - t.entryPrice) * dir * t.lots * _contract(t.symbol);
  }

  // Live trades the broadcaster places on-stream (the overlay source).
  final List<LiveTrade> _liveTrades = [];
  List<LiveTrade> get liveTrades => List.unmodifiable(_liveTrades);

  final List<ClosedTrade> _closedLiveTrades = [];
  List<ClosedTrade> get closedLiveTrades => List.unmodifiable(_closedLiveTrades);

  void placeLiveOrder({
    required String symbol,
    required bool isBuy,
    required LiveOrderType orderType,
    double lots = 0.10,
    double? sl,
    double? tp,
    double? limitPrice,
  }) {
    startPriceFeed();
    final entry = orderType == LiveOrderType.market ? priceOf(symbol) : (limitPrice ?? priceOf(symbol));
    _liveTrades.insert(
      0,
      LiveTrade(
        id: 'lt_${DateTime.now().microsecondsSinceEpoch}',
        symbol: symbol,
        isBuy: isBuy,
        orderType: orderType,
        entryPrice: entry,
        lots: lots,
        sl: sl,
        tp: tp,
        limitPrice: limitPrice,
        openedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void closeLiveTrade(String id) {
    final idx = _liveTrades.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final t = _liveTrades[idx];
    _closedLiveTrades.insert(
      0,
      ClosedTrade(
        symbol: t.symbol,
        isBuy: t.isBuy,
        pnl: livePnl(t),
        lots: t.lots,
        openedAt: t.openedAt,
        closedAt: DateTime.now(),
      ),
    );
    _liveTrades.removeAt(idx);
    notifyListeners();
  }

  /// A viewer copies a trade directly from a live stream. Returns false if the
  /// viewer has no connected account (caller should prompt to add one).
  bool copyFromLive(Trader trader, {required String pair, required bool isBuy, double amount = 500}) {
    if (!hasAccount) return false;
    final rng = math.Random();
    final pct = rng.nextDouble() * 1.5 - 0.3;
    _positions.insert(
      0,
      CopyPosition(
        id: 'pos_live_${DateTime.now().microsecondsSinceEpoch}',
        traderId: trader.id,
        traderName: trader.name,
        pair: pair,
        isBuy: isBuy,
        status: PositionStatus.active,
        entryPrice: 1 + rng.nextDouble(),
        pnlAmount: amount * pct / 100,
        pnlPercent: pct,
        lots: 0.1 + rng.nextDouble() * 0.3,
        openedAt: DateTime.now(),
        accountId: _accounts.first.id,
      ),
    );
    notifyListeners();
    return true;
  }

  List<Comment> _seedComments(Post post) {
    // A little realistic seed so the thread isn't empty.
    return [
      Comment(author: 'Priya Nair', username: 'priyatrades', text: 'Great breakdown, thanks for sharing 🙏', createdAt: DateTime.now().subtract(const Duration(minutes: 12))),
      Comment(author: 'Daniel Kim', username: 'dkfx', text: 'Watching this level too. Patient entry is key.', createdAt: DateTime.now().subtract(const Duration(minutes: 40))),
      Comment(author: 'Sofia Rossi', username: 'sofiafx', text: 'Copied 👀 let\'s see how it plays out', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
    ];
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState controller,
    required super.child,
  }) : super(notifier: controller);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }
}
