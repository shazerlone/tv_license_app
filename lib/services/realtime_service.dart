import 'dart:async';
import '../models/copy_models.dart';
import '../models/app_notification.dart';
import '../state/app_state.dart';
import '../state/session.dart';
import 'ws_client.dart';

/// Routes realtime WS events (contract §5) into [AppState] and [SessionController].
/// Broadcast-channel events are re-exposed as a stream for the live screens.
class RealtimeService {
  /// Set by the app shell so screens (e.g. live) can subscribe to broadcasts.
  static RealtimeService? current;

  RealtimeService(this._session, this._store);
  final SessionController _session;
  final AppState _store;

  WsClient? _ws;
  final _broadcast = StreamController<Map<String, dynamic>>.broadcast();
  final _pair = StreamController<Map<String, dynamic>>.broadcast();
  final _wallet = StreamController<Map<String, dynamic>>.broadcast();

  /// Broadcast-room events `{ ch:"broadcast:{id}", type, data }`.
  Stream<Map<String, dynamic>> get broadcastEvents => _broadcast.stream;

  /// Per-instrument community-chat events `{ ch:"pair:{symbol}", type, data }`.
  Stream<Map<String, dynamic>> get pairEvents => _pair.stream;

  /// Wallet events `{ type:"wallet.deposit"|"payout.status", data }` — the
  /// deposit-waiting screen listens to this for instant success.
  Stream<Map<String, dynamic>> get walletEvents => _wallet.stream;
  bool get connected => _ws != null;

  void connect(String token) {
    disconnect();
    final ws = WsClient(token)..connect();
    ws.subscribe(['prices', 'portfolio', 'user']);
    ws.messages.listen(_route);
    _ws = ws;
  }

  void subscribeBroadcast(String id) => _ws?.subscribe(['broadcast:$id']);
  void unsubscribeBroadcast(String id) => _ws?.unsubscribe(['broadcast:$id']);

  void subscribePair(String symbol) => _ws?.subscribe(['pair:$symbol']);
  void unsubscribePair(String symbol) => _ws?.unsubscribe(['pair:$symbol']);

  void disconnect() {
    _ws?.dispose();
    _ws = null;
  }

  void _route(Map<String, dynamic> m) {
    final ch = m['ch']?.toString() ?? '';
    final data = (m['data'] is Map) ? (m['data'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    if (ch == 'prices') {
      final prices = <String, double>{};
      (m['data'] as Map?)?.forEach((k, v) {
        if (v is num) prices[k.toString()] = v.toDouble();
      });
      _store.applyLivePrices(prices);
    } else if (ch == 'portfolio' && m['type'] == 'position') {
      _store.upsertLivePosition(CopyPosition.fromJson(data));
    } else if (ch == 'user') {
      _routeUser(m['type']?.toString() ?? '', data);
    } else if (ch.startsWith('broadcast:')) {
      _broadcast.add(m);
    } else if (ch.startsWith('pair:')) {
      _pair.add(m);
    }
  }

  void _routeUser(String type, Map<String, dynamic> d) {
    final now = DateTime.now();
    String id() => '${type}_${now.microsecondsSinceEpoch}';
    switch (type) {
      case 'creator.status':
        _mergeUser({'creatorStatus': d['creatorStatus']});
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.system,
          title: 'Verification ${d['creatorStatus']}',
          body: (d['reason'] ?? '').toString(), createdAt: now));
        break;
      case 'kyc.status':
        _mergeUser({'kycStatus': d['kycStatus']});
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.system,
          title: 'Identity ${d['kycStatus']}',
          body: (d['reason'] ?? '').toString(), createdAt: now));
        break;
      case 'trade.opened':
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.tradeOpened,
          title: '${d['name']} opened ${d['pair']}',
          body: '${d['isBuy'] == true ? 'BUY' : 'SELL'} @ ${d['entryPrice']}',
          traderId: d['traderId']?.toString(), createdAt: now));
        break;
      case 'trade.closed':
        final pct = (d['pnlPercent'] as num?)?.toDouble() ?? 0;
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.tradeClosed,
          title: 'Trade closed ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%',
          body: '${d['pair']}', traderId: d['traderId']?.toString(), createdAt: now));
        break;
      case 'copy.settled':
        _store.loadCopyEngine();
        _store.loadWallet();
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.tradeClosed,
          title: 'Copy settled',
          body: 'Net to you: ${d['netToCopier']} (fee ${d['fee']})', createdAt: now));
        break;
      case 'trader.live.started':
        _store.pushNotification(AppNotification(
          id: 'live_${d['traderId']}', type: AppNotificationType.live,
          title: '${d['name']} is live',
          body: 'Tap to watch and copy in real time.',
          traderId: d['traderId']?.toString(), createdAt: now));
        break;
      case 'wallet.deposit':
        // Deposit credited on-chain — refresh balance and notify the funnel.
        _store.loadWallet();
        _store.loadCopyEngine();
        _wallet.add({'type': 'wallet.deposit', 'data': d});
        final amt = (d['amount'] as num?)?.toDouble();
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.system,
          title: 'Deposit received',
          body: amt != null ? '+\$${amt.toStringAsFixed(2)} added to your balance' : 'Your deposit was credited.',
          createdAt: now));
        break;
      case 'social.subscribe':
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.subscribe,
          title: (d['title'] ?? '${d['actorName'] ?? 'Someone'} subscribed to you').toString(),
          body: 'Tap to see your subscribers.',
          traderId: d['traderId']?.toString(), createdAt: now));
        break;
      case 'social.like':
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.like,
          title: (d['title'] ?? '${d['actorName'] ?? 'Someone'} liked your post').toString(),
          body: '', createdAt: now));
        break;
      case 'social.comment':
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.comment,
          title: (d['title'] ?? '${d['actorName'] ?? 'Someone'} commented on your post').toString(),
          body: '', createdAt: now));
        break;
      case 'payout.status':
        // Rejected withdrawals refund the held balance — refresh either way.
        _store.loadWallet();
        _wallet.add({'type': 'payout.status', 'data': d});
        _store.pushNotification(AppNotification(
          id: id(), type: AppNotificationType.system,
          title: 'Payout ${d['status']}',
          body: (d['reason'] ?? '').toString(), createdAt: now));
        break;
    }
  }

  /// Merge a partial user update from a WS event into the session.
  void _mergeUser(Map<String, dynamic> patch) {
    final u = _session.user;
    if (u == null) return;
    _session.applyBackendSession(UserProfile.fromJson({...u.toJson(), ...patch}));
  }

  void dispose() {
    disconnect();
    _broadcast.close();
    _pair.close();
    _wallet.close();
  }
}
