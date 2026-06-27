import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/trader.dart';
import '../models/copy_models.dart';

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

  bool _isBroadcasting = false;
  bool get isBroadcasting => _isBroadcasting;

  int _viewers = 0;
  int get viewers => _viewers;

  // Connected simulcast destinations (besides Millimore, which is always on).
  final Set<String> _destinations = {};
  bool isDestinationOn(String id) => _destinations.contains(id);
  void toggleDestination(String id) {
    _destinations.contains(id) ? _destinations.remove(id) : _destinations.add(id);
    notifyListeners();
  }

  void startBroadcast() {
    _isBroadcasting = true;
    _viewers = 1 + math.Random().nextInt(40);
    notifyListeners();
  }

  void endBroadcast() {
    _isBroadcasting = false;
    _viewers = 0;
    notifyListeners();
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
