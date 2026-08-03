import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/trader.dart';
import '../models/copy_models.dart';
import '../models/app_notification.dart';
import '../services/backend_api.dart';

enum BroadcastPhase { idle, connecting, live }

/// The app's reactive data store: subscriptions, saved posts, likes and
/// comments. Swap the in-memory maps for a backend later — the UI only talks
/// to this controller, so nothing else changes.
class AppState extends ChangeNotifier {
  // traderId -> subscribed (loaded from backend; empty until loadSocial()).
  final Set<String> _subscribed = kUseBackend ? {} : {'1', '2', '3'};
  // traderId -> notifications on
  final Set<String> _notify = kUseBackend ? {} : {'1'};
  // postId -> saved
  final Set<String> _saved = {};
  // postId -> liked
  final Map<String, bool> _liked = {};
  final Map<String, int> _likeCount = {};
  // postId -> comments
  final Map<String, List<Comment>> _comments = {};

  // ── Notifications ────────────────────────────────────────────────────────
  final List<AppNotification> _notifications = [];
  final Set<String> _liveNotified = {}; // traderIds we've already alerted for
  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadNotifications => _notifications.where((n) => !n.read).length;

  /// Pulls server notifications (docs/APP_REQUIREMENTS.md §6a). Endpoint may not
  /// exist yet — fails soft. Merges without duplicating by id.
  Future<void> loadNotifications() async {
    if (!kUseBackend) return;
    try {
      final raw = await BackendApi.notifications();
      final existing = _notifications.map((n) => n.id).toSet();
      final incoming = raw.where((n) => !existing.contains(n.id)).toList();
      if (incoming.isNotEmpty) {
        _notifications.insertAll(0, incoming);
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }
    } catch (_) {
      // no /notifications endpoint yet — ignore
    }
  }

  /// Client-derived "trader is live" alerts for followed traders (until the
  /// backend pushes real events). Deduped per trader per session.
  void notifyLiveTraders(Iterable<Trader> liveFollowed) {
    var added = false;
    for (final t in liveFollowed) {
      if (_liveNotified.contains(t.id)) continue;
      _liveNotified.add(t.id);
      _notifications.insert(
        0,
        AppNotification(
          id: 'live_${t.id}',
          type: AppNotificationType.live,
          title: '${t.name} is live',
          body: 'Tap to watch and copy trades in real time.',
          createdAt: DateTime.now(),
          traderId: t.id,
        ),
      );
      added = true;
    }
    if (added) notifyListeners();
  }

  /// Push a notification from a realtime event (WS user channel).
  void pushNotification(AppNotification n) {
    if (_notifications.any((x) => x.id == n.id)) return;
    _notifications.insert(0, n);
    notifyListeners();
  }

  void markNotificationsRead() {
    final unreadIds = _notifications.where((n) => !n.read).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
    if (kUseBackend) {
      // Only sync server-originated ids (client-derived 'live_*' ids aren't real).
      final serverIds = unreadIds.where((id) => !id.startsWith('live_')).toList();
      if (serverIds.isNotEmpty) BackendApi.markNotificationsRead(serverIds).catchError((_) {});
    }
  }

  /// Loads the real social graph (subscriptions) from the backend. Called once
  /// after sign-in / at home load. No-op in demo mode.
  Future<void> loadSocial() async {
    if (!kUseBackend) return;
    try {
      final subs = await BackendApi.subscriptions();
      _subscribed
        ..clear()
        ..addAll(subs.map((t) => t.id));
      notifyListeners();
    } catch (_) {
      // keep whatever we have
    }
  }

  // ── Subscriptions ──────────────────────────────────────────────────────────
  bool isSubscribed(String traderId) => _subscribed.contains(traderId);
  int get subscriptionCount => _subscribed.length;
  Set<String> get subscribedTraderIds => _subscribed;

  void subscribe(String traderId) {
    _subscribed.add(traderId);
    _notify.add(traderId);
    notifyListeners();
    if (kUseBackend) BackendApi.subscribe(traderId).catchError((_) {});
  }

  void unsubscribe(String traderId) {
    _subscribed.remove(traderId);
    _notify.remove(traderId);
    notifyListeners();
    if (kUseBackend) BackendApi.unsubscribe(traderId).catchError((_) {});
  }

  void toggleSubscribe(String traderId) =>
      isSubscribed(traderId) ? unsubscribe(traderId) : subscribe(traderId);

  bool isNotifying(String traderId) => _notify.contains(traderId);
  void toggleNotify(String traderId) {
    final on = !_notify.contains(traderId);
    on ? _notify.add(traderId) : _notify.remove(traderId);
    notifyListeners();
    if (kUseBackend) BackendApi.setNotify(traderId, on).catchError((_) {});
  }

  // ── Saved posts ────────────────────────────────────────────────────────────
  bool isSaved(String postId) => _saved.contains(postId);
  int get savedCount => _saved.length;
  Set<String> get savedPostIds => _saved;

  void toggleSave(String postId) {
    final saved = _saved.contains(postId);
    saved ? _saved.remove(postId) : _saved.add(postId);
    notifyListeners();
    if (kUseBackend) {
      (saved ? BackendApi.unsavePost(postId) : BackendApi.savePost(postId)).catchError((_) {});
    }
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
    if (kUseBackend) {
      (liked ? BackendApi.unlikePost(post.id) : BackendApi.likePost(post.id)).catchError((_) => 0);
    }
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

  /// Loads connected accounts from the backend (§4.3). No-op in demo mode.
  Future<void> loadAccounts() async {
    if (!kUseBackend) return;
    try {
      final list = await BackendApi.accounts();
      _accounts
        ..clear()
        ..addAll(list.map((a) => TradingAccount(
              id: a.id,
              brokerId: a.brokerId,
              brokerName: a.brokerName,
              accountNumber: a.accountNumber,
              server: a.server,
              currency: a.currency,
              balance: a.balance,
              connectedAt: DateTime.tryParse(a.connectedAt)?.toLocal() ?? DateTime.now(),
            )));
      notifyListeners();
    } catch (_) {}
  }

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
    if (kUseBackend) BackendApi.disconnectAccount(id).catchError((_) {});
  }

  // ── Copy engine ───────────────────────────────────────────────────────────
  final Map<String, CopyConfig> _copying = {};
  final List<CopyPosition> _positions = [];
  PortfolioSummary? _summary; // backend portfolio (milestone 4)

  bool isCopying(String traderId) => _copying.containsKey(traderId);
  CopyConfig? copyConfig(String traderId) => _copying[traderId];
  List<CopyConfig> get activeCopies => _copying.values.toList();
  int get copyingCount => _summary?.copyingCount ?? _copying.length;

  List<CopyPosition> get positions => List.unmodifiable(_positions);
  List<CopyPosition> get activePositions =>
      _positions.where((p) => p.status == PositionStatus.active).toList();
  List<CopyPosition> get closedPositions =>
      _positions.where((p) => p.status == PositionStatus.closed).toList();

  double get openPnl => _summary?.openPnl ?? activePositions.fold(0, (s, p) => s + p.pnlAmount);
  double get bookedProfit => _summary?.bookedProfit ??
      closedPositions.where((p) => p.pnlAmount >= 0).fold(0, (s, p) => s + p.pnlAmount);
  double get bookedLoss => _summary?.bookedLoss ??
      closedPositions.where((p) => p.pnlAmount < 0).fold(0, (s, p) => s + p.pnlAmount);
  double get netPnl => _summary?.netPnl ?? (openPnl + bookedProfit + bookedLoss);
  double get totalInvested => _summary?.invested ?? _copying.values.fold(0, (s, c) => s + c.amount);

  // Milestone 7 — margin (from portfolio summary; 0 until loaded)
  double get freeMargin => _summary?.freeMargin ?? 0;
  double get usedMargin => _summary?.usedMargin ?? 0;
  double get equity => _summary?.equity ?? 0;
  double? get marginLevel => _summary?.marginLevel;
  bool get hasMargin => _summary != null && (_summary!.usedMargin > 0 || _summary!.equity > 0);

  /// Loads the real copy engine (milestone 4): who you copy, positions, and the
  /// portfolio summary. No-op in demo mode.
  Future<void> loadCopyEngine() async {
    if (!kUseBackend) return;
    try {
      final configs = await BackendApi.copyConfigs();
      final pos = await BackendApi.positions();
      final summary = await BackendApi.portfolioSummary();
      _copying
        ..clear()
        ..addEntries(configs.map((c) => MapEntry(c.traderId, c)));
      _positions
        ..clear()
        ..addAll(pos);
      _summary = summary;
      notifyListeners();
    } catch (_) {
      // leave whatever we have
    }
  }

  void startCopy(Trader trader, {required String accountId, required double amount, required double risk, required bool autoCopy, double? leverage}) {
    _copying[trader.id] = CopyConfig(
      traderId: trader.id,
      accountId: accountId,
      amount: amount,
      risk: risk,
      autoCopy: autoCopy,
      startedAt: DateTime.now(),
    );
    if (kUseBackend) {
      BackendApi.startCopy(trader.id, accountId: accountId, amount: amount, risk: risk, autoCopy: autoCopy, leverage: leverage)
          .then((_) => loadCopyEngine())
          .catchError((_) {});
    } else {
      _seedPositions(trader, accountId, amount);
    }
    notifyListeners();
  }

  /// Awaitable copy-start that surfaces errors (e.g. `insufficient_balance`) to
  /// the caller. Prefer this from the copy UI so the user can be prompted to
  /// deposit. Returns true on success.
  Future<void> startCopyAsync(Trader trader, {String? accountId, required double amount, double? leverage, double risk = 1, bool autoCopy = true}) async {
    if (kUseBackend) {
      await BackendApi.startCopy(trader.id, accountId: accountId, amount: amount, leverage: leverage, risk: risk, autoCopy: autoCopy);
      await loadCopyEngine();
    } else {
      _copying[trader.id] = CopyConfig(traderId: trader.id, accountId: accountId ?? '', amount: amount, risk: risk, autoCopy: autoCopy, startedAt: DateTime.now());
      _seedPositions(trader, accountId ?? '', amount);
      notifyListeners();
    }
  }

  void stopCopy(String traderId) {
    _copying.remove(traderId);
    notifyListeners();
    if (kUseBackend) BackendApi.stopCopy(traderId).then((_) => loadCopyEngine()).catchError((_) {});
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

  /// Live prices from the WS `prices` channel (merges into the snapshot).
  void applyLivePrices(Map<String, double> prices) {
    if (prices.isEmpty) return;
    _prices.addAll(prices);
    notifyListeners();
  }

  /// Live position update from the WS `portfolio` channel — replace by id.
  void upsertLivePosition(CopyPosition p) {
    final i = _positions.indexWhere((x) => x.id == p.id);
    if (i >= 0) {
      _positions[i] = p;
    } else {
      _positions.insert(0, p);
    }
    notifyListeners();
  }

  Timer? _priceTimer;
  int _feedRefs = 0;

  void startPriceFeed() {
    _feedRefs++;
    // With the backend, prices arrive over the WS `prices` channel — load a
    // snapshot once and let the socket drive updates (no local simulation).
    if (kUseBackend) {
      BackendApi.prices().then((p) {
        if (p.isNotEmpty) applyLivePrices(p);
      }).catchError((_) {});
      return;
    }
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
