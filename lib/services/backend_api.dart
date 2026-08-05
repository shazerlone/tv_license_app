import 'api_client.dart';
import '../models/api_models.dart';
import '../models/app_notification.dart';
import '../models/copy_models.dart';

/// Typed access to Millimore backend Milestones 2 & 3
/// (brokers, accounts, creator verification, traders, feed, social).
/// Shapes mirror millimore-backend/openapi.json.
class BackendApi {
  static final _api = ApiClient.instance;

  static List<Map<String, dynamic>> _list(dynamic res, [String? key]) {
    final raw = key != null && res is Map ? res[key] : res;
    if (raw is List) return raw.map((e) => (e as Map).cast<String, dynamic>()).toList();
    return const [];
  }

  // ── Brokers (§4.3) ────────────────────────────────────────────────────────
  static Future<List<Broker>> brokers({String? country}) async {
    final res = await _api.get('/brokers${country != null ? '?country=$country' : ''}');
    return _list(res, res is Map ? 'items' : null).map(Broker.fromJson).toList();
  }

  // ── Trading accounts (§4.3) ───────────────────────────────────────────────
  static Future<List<ApiTradingAccount>> accounts() async {
    final res = await _api.get('/accounts');
    return _list(res, res is Map ? 'items' : null).map(ApiTradingAccount.fromJson).toList();
  }

  static Future<ApiTradingAccount> connectAccount({
    required String brokerId,
    required String accountNumber,
    required String server,
    required String password,
    String? currency,
  }) async {
    final res = await _api.post('/accounts', {
      'brokerId': brokerId,
      'accountNumber': accountNumber,
      'server': server,
      'password': password,
      if (currency != null) 'currency': currency,
    });
    final m = (res is Map && res['account'] is Map ? res['account'] : res) as Map;
    return ApiTradingAccount.fromJson(m.cast<String, dynamic>());
  }

  static Future<void> disconnectAccount(String id) => _api.delete('/accounts/$id');

  static Future<void> changeAccountPassword(String id, {required String current, required String next}) =>
      _api.post('/accounts/$id/password', {'current': current, 'next': next});

  // ── Creator verification (§4.2) ───────────────────────────────────────────
  static Future<CreatorStatusResult> creatorStatus() async {
    final res = await _api.get('/creator/status');
    return CreatorStatusResult.fromJson((res as Map).cast<String, dynamic>());
  }

  static Future<CreatorStatusResult> applyCreator({
    required String market,
    required String platform,
    required Map<String, dynamic> verification,
  }) async {
    final res = await _api.post('/creator/apply', {
      'market': market,
      'platform': platform,
      'verification': verification,
    });
    return CreatorStatusResult.fromJson((res as Map).cast<String, dynamic>());
  }

  // ── Traders / discover (§4.4) ─────────────────────────────────────────────
  static Future<TraderPage> traders({String? category, String? q, String? sort, String? cursor}) async {
    final params = <String, String>{
      if (category != null) 'category': category,
      if (q != null && q.isNotEmpty) 'q': q,
      if (sort != null) 'sort': sort,
      if (cursor != null) 'cursor': cursor,
    };
    final qs = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final res = await _api.get('/traders$qs');
    return TraderPage.fromJson((res as Map).cast<String, dynamic>());
  }

  static Future<ApiTrader> trader(String id) async {
    final res = await _api.get('/traders/$id');
    final m = (res is Map && res['trader'] is Map ? res['trader'] : res) as Map;
    return ApiTrader.fromJson(m.cast<String, dynamic>());
  }

  static Future<List<PublicTrade>> traderTrades(String id, {String status = 'active'}) async {
    final res = await _api.get('/traders/$id/trades?status=$status');
    return _list(res, res is Map ? 'items' : null).map(PublicTrade.fromJson).toList();
  }

  static Future<List<EquityPoint>> traderEquity(String id, {String range = '30d'}) async {
    final res = await _api.get('/traders/$id/equity?range=$range');
    return _list(res, res is Map ? 'items' : null).map(EquityPoint.fromJson).toList();
  }

  static Future<List<ApiPost>> traderPosts(String id) async {
    final res = await _api.get('/traders/$id/posts');
    return _list(res, res is Map ? 'items' : null).map(ApiPost.fromJson).toList();
  }

  static Future<List<Reel>> reels() async {
    final res = await _api.get('/discover/reels');
    return _list(res, res is Map ? 'items' : null).map(Reel.fromJson).toList();
  }

  // ── Feed & social (§4.5, §4.6) ────────────────────────────────────────────
  static Future<List<ApiPost>> feed({String? cursor}) async {
    final res = await _api.get('/feed${cursor != null ? '?cursor=$cursor' : ''}');
    return _list(res, res is Map ? 'items' : null).map(ApiPost.fromJson).toList();
  }

  static Future<List<ApiPost>> saved() async {
    final res = await _api.get('/saved');
    return _list(res, res is Map ? 'items' : null).map(ApiPost.fromJson).toList();
  }

  static Future<int> likePost(String id) async {
    final res = await _api.post('/posts/$id/like');
    return (res is Map && res['likes'] != null) ? _int(res['likes']) : 0;
  }

  static Future<int> unlikePost(String id) async {
    final res = await _api.delete('/posts/$id/like');
    return (res is Map && res['likes'] != null) ? _int(res['likes']) : 0;
  }

  static Future<void> savePost(String id) => _api.post('/posts/$id/save');
  static Future<void> unsavePost(String id) => _api.delete('/posts/$id/save');

  static Future<List<ApiComment>> comments(String postId) async {
    final res = await _api.get('/posts/$postId/comments');
    return _list(res, res is Map ? 'items' : null).map(ApiComment.fromJson).toList();
  }

  static Future<ApiComment> addComment(String postId, String text) async {
    final res = await _api.post('/posts/$postId/comments', {'text': text});
    final m = (res is Map && res['comment'] is Map ? res['comment'] : res) as Map;
    return ApiComment.fromJson(m.cast<String, dynamic>());
  }

  static Future<ApiPost> createPost({
    required String type,
    required String content,
    String? pair,
    String? title,
    List<String>? points,
  }) async {
    final res = await _api.post('/posts', {
      'type': type,
      'content': content,
      if (pair != null) 'pair': pair,
      if (title != null) 'title': title,
      if (points != null) 'points': points,
    });
    final m = (res is Map && res['post'] is Map ? res['post'] : res) as Map;
    return ApiPost.fromJson(m.cast<String, dynamic>());
  }

  // ── Subscriptions (§4.5) ──────────────────────────────────────────────────
  static Future<List<ApiTrader>> subscriptions() async {
    final res = await _api.get('/subscriptions');
    return _list(res, res is Map ? 'items' : null).map(ApiTrader.fromJson).toList();
  }

  static Future<void> subscribe(String traderId) => _api.post('/subscriptions/$traderId');
  static Future<void> unsubscribe(String traderId) => _api.delete('/subscriptions/$traderId');
  static Future<void> setNotify(String traderId, bool on) => _api.post('/subscriptions/$traderId/notify', {'on': on});

  // ── Notifications (§6a — may not be live yet) ─────────────────────────────
  static Future<List<AppNotification>> notifications({String? cursor}) async {
    final res = await _api.get('/notifications${cursor != null ? '?cursor=$cursor' : ''}');
    return _list(res, res is Map ? 'items' : null).map(AppNotification.fromJson).toList();
  }

  static Future<void> markNotificationsRead(List<String> ids) =>
      _api.post('/notifications/read', {'ids': ids});

  /// Register a device push token (§6b — FCM/APNs). Safe to call best-effort.
  static Future<void> registerDevice({required String platform, required String token, String? appVersion}) =>
      _api.post('/devices', {'platform': platform, 'token': token, if (appVersion != null) 'appVersion': appVersion});

  // ── Copy engine / portfolio / prices (milestone 4) ────────────────────────
  static Future<List<CopyConfig>> copyConfigs() async {
    final res = await _api.get('/copy');
    return _list(res, res is Map ? 'items' : null).map(CopyConfig.fromJson).toList();
  }

  static Future<CopyConfig> startCopy(String traderId, {String? accountId, required double amount, double? leverage, double? risk, bool? autoCopy}) async {
    final res = await _api.post('/copy/$traderId/start', {
      'amount': amount,
      if (accountId != null) 'accountId': accountId,
      if (leverage != null) 'leverage': leverage,
      if (risk != null) 'risk': risk,
      if (autoCopy != null) 'autoCopy': autoCopy,
    });
    return CopyConfig.fromJson((res as Map).cast<String, dynamic>());
  }

  static Future<void> stopCopy(String traderId) => _api.post('/copy/$traderId/stop');

  static Future<List<CopyPosition>> positions() async {
    final res = await _api.get('/positions');
    return _list(res, res is Map ? 'items' : null).map(CopyPosition.fromJson).toList();
  }

  static Future<PortfolioSummary> portfolioSummary() async {
    final res = await _api.get('/portfolio/summary');
    return PortfolioSummary.fromJson((res as Map).cast<String, dynamic>());
  }

  static Future<Map<String, double>> prices() async {
    final res = await _api.get('/prices');
    final m = <String, double>{};
    if (res is Map) {
      res.forEach((k, v) {
        if (v is num) m[k.toString()] = v.toDouble();
      });
    }
    return m;
  }

  static Future<List<String>> symbols() async {
    final res = await _api.get('/symbols');
    if (res is List) return res.map((e) => e.toString()).toList();
    return const [];
  }

  // ── Creator dashboard (§5b) ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> creatorStats() async {
    final res = await _api.get('/creator/stats');
    return (res as Map).cast<String, dynamic>();
  }

  static Future<List<ApiTrader>> creatorFollowers() async {
    final res = await _api.get('/creator/followers');
    return _list(res, res is Map ? 'items' : null).map(ApiTrader.fromJson).toList();
  }

  // ── Media uploads (§5b) ───────────────────────────────────────────────────
  /// Uploads a data URL / base64 payload and returns the hosted URL.
  static Future<String> uploadMedia({required String contentType, required String data, String? kind}) async {
    final res = await _api.post('/uploads', {'contentType': contentType, 'data': data, if (kind != null) 'kind': kind});
    return ((res as Map)['url']).toString();
  }

  // ── Creator earnings (§5b) ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> creatorEarnings() async {
    final res = await _api.get('/creator/earnings');
    return (res as Map).cast<String, dynamic>();
  }

  // ── Posts edit/delete ─────────────────────────────────────────────────────
  static Future<void> updatePost(String id, Map<String, dynamic> fields) => _api.patch('/posts/$id', fields);
  static Future<void> deletePost(String id) => _api.delete('/posts/$id');

  // ── Broadcasts / live streaming (milestone 5) ─────────────────────────────
  static Future<Map<String, dynamic>> createBroadcast(String title) async {
    final res = await _api.post('/broadcasts', {'title': title});
    return (res as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> startBroadcast(String id) async {
    final res = await _api.post('/broadcasts/$id/start');
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> endBroadcast(String id) async {
    final res = await _api.post('/broadcasts/$id/end');
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> getBroadcast(String id) async {
    final res = await _api.get('/broadcasts/$id');
    return (res as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> liveBroadcasts() async {
    final res = await _api.get('/broadcasts/live');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<List<Map<String, dynamic>>> broadcastChat(String id) async {
    final res = await _api.get('/broadcasts/$id/chat');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<void> sendBroadcastChat(String id, String text) => _api.post('/broadcasts/$id/chat', {'text': text});
  static Future<void> reactBroadcast(String id) => _api.post('/broadcasts/$id/react');
  static Future<Map<String, dynamic>> connectYouTube(String id, Map<String, dynamic> body) async {
    final res = await _api.post('/broadcasts/$id/destinations/youtube/connect', body);
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  static Future<void> disconnectDestination(String id, String platform) =>
      _api.post('/broadcasts/$id/destinations/$platform/disconnect');

  // ── Wallet / deposits / payouts (milestone 6) ─────────────────────────────
  static Future<Map<String, dynamic>> wallet() async {
    final res = await _api.get('/wallet');
    return (res as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> walletLedger() async {
    final res = await _api.get('/wallet/ledger');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<List<Map<String, dynamic>>> depositMethods() async {
    final res = await _api.get('/deposits/methods');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<List<Map<String, dynamic>>> deposits() async {
    final res = await _api.get('/deposits');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<Map<String, dynamic>> createDeposit({required double amount, String? method, String? asset}) async {
    final res = await _api.post('/deposits', {'amount': amount, if (method != null) 'method': method, if (asset != null) 'asset': asset});
    return (res as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> creatorPayouts() async {
    final res = await _api.get('/creator/payouts');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<Map<String, dynamic>> requestPayout({required double amount, String? method, String? note}) async {
    final res = await _api.post('/creator/payouts', {'amount': amount, if (method != null) 'method': method, if (note != null) 'note': note});
    return (res as Map).cast<String, dynamic>();
  }

  static Future<double> setCommission(double percent) async {
    final res = await _api.patch('/creator/commission', {'percent': percent});
    return ((res as Map)['commissionPercent'] as num?)?.toDouble() ?? percent;
  }

  static Future<double> getCommission() async {
    final res = await _api.get('/creator/commission');
    return ((res as Map)['commissionPercent'] as num?)?.toDouble() ?? 20;
  }

  // ── Milestone 7: leverage, KYC, payout methods, transactions ──────────────
  static Future<List<Map<String, dynamic>>> walletTransactions() async {
    final res = await _api.get('/wallet/transactions');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<List<Map<String, dynamic>>> payoutMethods() async {
    final res = await _api.get('/wallet/payout-methods');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<Map<String, dynamic>> addPayoutMethod(Map<String, dynamic> body) async {
    final res = await _api.post('/wallet/payout-methods', body);
    return (res as Map).cast<String, dynamic>();
  }

  static Future<void> deletePayoutMethod(String id) => _api.delete('/wallet/payout-methods/$id');

  static Future<Map<String, dynamic>> kycStatus() async {
    final res = await _api.get('/kyc');
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> startKyc() async {
    final res = await _api.post('/kyc/start');
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  // ── Announcements ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> announcements() async {
    final res = await _api.get('/announcements');
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{'items': [], 'unread': 0};
  }

  static Future<void> markAnnouncementRead(String id) => _api.post('/announcements/$id/read');

  // ── Referrals ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> referralMe() async {
    final res = await _api.get('/referrals/me');
    return (res as Map).cast<String, dynamic>();
  }

  static Future<List<Map<String, dynamic>>> referredUsers() async {
    final res = await _api.get('/referrals');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<void> applyReferral(String code) => _api.post('/referrals/apply', {'code': code});

  // ── Support tickets ───────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> supportTickets() async {
    final res = await _api.get('/support/tickets');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<Map<String, dynamic>> supportTicket(String id) async {
    final res = await _api.get('/support/tickets/$id');
    return (res as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> createTicket({required String subject, required String message, String? category, String? priority}) async {
    final res = await _api.post('/support/tickets', {
      'subject': subject,
      'message': message,
      if (category != null) 'category': category,
      if (priority != null) 'priority': priority,
    });
    return (res as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> replyTicket(String id, String body) async {
    final res = await _api.post('/support/tickets/$id/messages', {'body': body});
    return (res as Map).cast<String, dynamic>();
  }

  // ── Two-factor authentication (M14) ───────────────────────────────────────
  static Future<Map<String, dynamic>> twofaStatus() async {
    final res = await _api.get('/2fa');
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> twofaSetup() async {
    final res = await _api.post('/2fa/setup');
    return (res as Map).cast<String, dynamic>();
  }

  /// Returns the one-time backup codes to show the user.
  static Future<List<String>> twofaEnable(String code) async {
    final res = await _api.post('/2fa/enable', {'code': code});
    final codes = (res is Map) ? res['backupCodes'] : null;
    return (codes is List) ? codes.map((e) => e.toString()).toList() : <String>[];
  }

  static Future<void> twofaDisable(String code) => _api.post('/2fa/disable', {'code': code});

  // ── Multi-destination simulcast outputs (M13) ─────────────────────────────
  static Future<List<Map<String, dynamic>>> broadcastOutputs(String broadcastId) async {
    final res = await _api.get('/broadcasts/$broadcastId/outputs');
    return _list(res, res is Map ? 'items' : null);
  }

  static Future<Map<String, dynamic>> addBroadcastOutput(String broadcastId, {required String platform, required String streamKey, String? url}) async {
    final res = await _api.post('/broadcasts/$broadcastId/outputs', {
      'platform': platform,
      'streamKey': streamKey,
      if (url != null && url.isNotEmpty) 'url': url,
    });
    return (res as Map).cast<String, dynamic>();
  }

  static Future<void> setBroadcastOutputEnabled(String broadcastId, String outputId, bool enabled) =>
      _api.patch('/broadcasts/$broadcastId/outputs/$outputId', {'enabled': enabled});

  static Future<void> deleteBroadcastOutput(String broadcastId, String outputId) =>
      _api.delete('/broadcasts/$broadcastId/outputs/$outputId');

  // ── YouTube connect & live-chat ingest (M15) ──────────────────────────────
  static Future<Map<String, dynamic>> youtubeStatus() async {
    final res = await _api.get('/youtube/status');
    return (res is Map) ? res.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// Returns `{ url }` — open it in a browser/webview for Google consent.
  static Future<String?> youtubeConnect() async {
    final res = await _api.post('/youtube/connect');
    return (res is Map) ? res['url']?.toString() : null;
  }

  static Future<void> youtubeDisconnect() => _api.post('/youtube/disconnect');

  static int _int(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
}
